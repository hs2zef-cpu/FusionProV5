# Build metadata only. DOES NOT launch MT5, attach an EA or authorize D1.
param([switch]$MetadataOnly)
$ErrorActionPreference='Stop'
$repo=(Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$sha=(& git -C $repo rev-parse HEAD).Trim()
if($LASTEXITCODE -ne 0 -or $sha -notmatch '^[0-9a-f]{40}$'){throw 'Source identity unavailable'}
$dirty=(& git -C $repo status --porcelain)
$clean=if(!$dirty){'true'}else{'false'}
$generated=Join-Path $PSScriptRoot 'SW_V5_S5_MvpAttendedBuild.generated.mqh'
# Generated build output, not manually authored source. Dirty builds cannot D1.
[IO.File]::WriteAllText($generated,"// GENERATED BUILD METADATA / NO AUTHORITY`r`n#define SWV5S5_MVP_ATTENDED_BUILT_SOURCE `"$sha`"`r`n#define SWV5S5_MVP_ATTENDED_CLEAN_SOURCE $clean`r`n",[Text.UTF8Encoding]::new($false))
Write-Output "ATTENDED_BUILD|source=$sha|clean=$clean|runtime_executed=false"
if(!$MetadataOnly){
  $source=Join-Path $PSScriptRoot 'SW_V5_S5_MVP_CONTROLLED_DEMO_RUNNER.mq5'
  Start-Process -FilePath 'C:\Program Files\MetaTrader 5\metaeditor64.exe' -ArgumentList ('/compile:"'+$source+'"'),'/log' -WindowStyle Hidden -Wait
  $result=Get-Content -LiteralPath ([IO.Path]::ChangeExtension($source,'.log')) | Select-String '^Result:' | Select-Object -Last 1
  Write-Output $result
  if(!$result -or $result -notmatch '^Result: 0 errors, 0 warnings.*X64 Regular'){throw 'Attended build compile failed'}
}
