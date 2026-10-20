# TEST ONLY / NOT FOR PRODUCTION / NO BROKER MUTATION.
# Prepares a NEW copy and test-only binary/preset; never starts MT5 or an EA.
$ErrorActionPreference='Stop'
$expected='BEC62E7435D29D5511A41BF85C74AE443994C5804B3A9574AF90D861FE674EF6'
$common='C:\Users\Nutthakrit\AppData\Roaming\MetaQuotes\Terminal\Common\Files'
$real=Join-Path $common 'fusion_v5_mvp_demo_authority.sqlite'
$immutable=Join-Path $common 'TEST_ONLY_MVP_CONTINUATION_3f39a13e0c314df2bcd8452ae9de5e4c.sqlite'
if((Get-FileHash -LiteralPath $real -Algorithm SHA256).Hash -ne $expected){throw 'Original DB hash mismatch: STOP'}
if((Get-FileHash -LiteralPath $immutable -Algorithm SHA256).Hash -ne $expected){throw 'Immutable donor hash mismatch: STOP'}
if((Test-Path -LiteralPath ($immutable+'-wal')) -and (Get-Item -LiteralPath ($immutable+'-wal')).Length -ne 0){throw 'Immutable donor has uncheckpointed WAL: STOP'}
foreach($suffix in @('-wal','-shm')){if(Test-Path -LiteralPath ($real+$suffix)){throw 'Original WAL/SHM exists: STOP'}}
$copyName='TEST_ONLY_MVP_CONTINUATION_'+[guid]::NewGuid().ToString('N')+'.sqlite'
$copy=Join-Path $common $copyName
if(Test-Path -LiteralPath $copy){throw 'Unique copy already exists: STOP'}
Copy-Item -LiteralPath $immutable -Destination $copy
if((Get-FileHash -LiteralPath $copy -Algorithm SHA256).Hash -ne $expected){throw 'Initial copy is not byte-identical: STOP'}
$source=Join-Path $PSScriptRoot 'SW_V5_S5_MVP_CONTINUATION_NATIVE_COPY_ASSERTIONS.mq5'
$binary=[IO.Path]::ChangeExtension($source,'.ex5')
$log=Get-Content -LiteralPath ([IO.Path]::ChangeExtension($source,'.log')) | Select-String '^Result:' | Select-Object -Last 1
if(!$log -or $log -notmatch '^Result: 0 errors, 0 warnings.*X64 Regular' -or (Get-Item $binary).LastWriteTime -lt (Get-Item $source).LastWriteTime){throw 'Compile is absent/stale: STOP'}
$data='C:\Users\Nutthakrit\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075'
$experts=Join-Path $data 'MQL5\Experts\FusionProV5Tests'
$presets=Join-Path $data 'MQL5\Presets'
New-Item -ItemType Directory -Path $experts,$presets -Force | Out-Null
$dest=Join-Path $experts ([IO.Path]::GetFileName($binary))
Copy-Item -LiteralPath $binary -Destination $dest
$preset=Join-Path $presets ($copyName+'.set')
@(
 'explicit_test_only_marker=TEST_ONLY_AUTHORIZED_UNCOMMITTED_DRAFT'
 ('initial_copy_relative_path='+$copyName)
 ('expected_initial_copy_sha256='+$expected.ToLowerInvariant())
 'execute_test_copy_once=true'
 'operator_confirmed_test_copy=true'
) | Set-Content -LiteralPath $preset -Encoding Unicode
if((Get-FileHash -LiteralPath $real -Algorithm SHA256).Hash -ne $expected){throw 'Original changed during preparation: STOP'}
[ordered]@{
 classification='TEST_ONLY_PREPARATION_NOT_EXECUTED'
 original_sha256=$expected
 copy_path=$copy
 copy_sha256=(Get-FileHash -LiteralPath $copy -Algorithm SHA256).Hash
 preset_path=$preset
 preset_sha256=(Get-FileHash -LiteralPath $preset -Algorithm SHA256).Hash
 installed_binary=$dest
 binary_sha256=(Get-FileHash -LiteralPath $dest -Algorithm SHA256).Hash
 source_sha256=(Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash
 no_terminal_launch=$true
} | ConvertTo-Json
