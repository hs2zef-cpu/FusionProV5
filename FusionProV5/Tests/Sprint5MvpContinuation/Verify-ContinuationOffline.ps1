param([switch]$SkipCompile)
# TEST ONLY. Never launches an administrative wrapper or opens the real DB.
$ErrorActionPreference='Stop'
$repo=(Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$real='C:\Users\Nutthakrit\AppData\Roaming\MetaQuotes\Terminal\Common\Files\fusion_v5_mvp_demo_authority.sqlite'
$expected='BEC62E7435D29D5511A41BF85C74AE443994C5804B3A9574AF90D861FE674EF6'
$snapshot='C:\Users\Nutthakrit\AppData\Local\Temp\FusionGovernanceBasketReadback_53cdba65db92400f99caed8a6aa491f8\fusion_v5_mvp_demo_authority.sqlite'
$common='C:\Users\Nutthakrit\AppData\Roaming\MetaQuotes\Terminal\Common\Files'
$fixture=Join-Path $common 'TEST_ONLY_MVP_CONTINUATION_FIXTURE.sqlite'
$terminal='C:\Program Files\MetaTrader 5\terminal64.exe'
$editor='C:\Program Files\MetaTrader 5\metaeditor64.exe'
$data=Join-Path $env:APPDATA 'MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075'
$agent=Join-Path $env:APPDATA 'MetaQuotes\Tester\D0E8209F77C8CF37AD8BF550E51FF075\Agent-127.0.0.1-3000\logs'
if((Get-FileHash -LiteralPath $real -Algorithm SHA256).Hash -ne $expected -or
   (Get-FileHash -LiteralPath $snapshot -Algorithm SHA256).Hash -ne $expected){throw 'Real DB or immutable fixture changed; STOP'}
if(Get-Process -Name terminal64,metatester64 -ErrorAction SilentlyContinue){throw 'Existing terminal/tester: preserve it and STOP'}
Copy-Item -LiteralPath $snapshot -Destination $fixture
if((Get-FileHash -LiteralPath $fixture -Algorithm SHA256).Hash -ne $expected){throw 'COPY is not byte-identical'}
Write-Output "COPY|sha256=$expected|real_db_mutated=false"
$source=Join-Path $PSScriptRoot 'SW_V5_S5_MVP_CONTINUATION_ASSERTIONS.mq5'
if(!$SkipCompile){
  Start-Process -FilePath $editor -ArgumentList ('/compile:"'+$source+'"'),'/log' -WindowStyle Hidden -Wait
  $result=Get-Content -LiteralPath ([IO.Path]::ChangeExtension($source,'.log')) | Select-String '^Result:' | Select-Object -Last 1
  Write-Output "COMPILE|$result"
  if(!$result -or $result -notmatch '^Result: 0 errors, 0 warnings.*X64 Regular'){throw 'Compile gate failed'}
}
$config=Join-Path $PSScriptRoot 'continuation_offline_tester.ini'
$settings=Get-Content -LiteralPath $config -Raw
if($settings -notmatch '\[Tester\]' -or $settings -notmatch 'ShutdownTerminal=1' -or
   $settings -match '\[Experts\]|\[StartUp\]|Login=|Password=|Server='){throw 'Unsafe tester configuration'}
$dest=Join-Path $data 'MQL5\Experts\FusionProV5Tests\SW_V5_S5_MVP_CONTINUATION_ASSERTIONS.ex5'
Copy-Item -LiteralPath ([IO.Path]::ChangeExtension($source,'.ex5')) -Destination $dest
$started=Get-Date
Start-Process -FilePath $terminal -ArgumentList ('/config:"'+$config+'"') -WindowStyle Hidden -Wait
$waited=0
while(Get-Process -Name terminal64,metatester64 -ErrorAction SilentlyContinue){
  if($waited -ge 1200){throw 'Tester did not exit; preserve it and STOP'}
  Start-Sleep -Seconds 1;$waited++
}
$fresh=@(foreach($journal in Get-ChildItem -LiteralPath $agent -Filter '*.log'){
  if($journal.BaseName -lt $started.ToString('yyyyMMdd')){continue}
  foreach($line in Get-Content -LiteralPath $journal.FullName){
    if($line -match '^CS\s+\d+\s+(\d\d:\d\d:\d\d\.\d\d\d)'){
      $at=[datetime]::ParseExact($journal.BaseName+' '+$Matches[1],'yyyyMMdd HH:mm:ss.fff',[cultureinfo]::InvariantCulture)
      if($at -ge $started){$line}
    }
  }
})
$summary=$fresh | Select-String 'CONTINUATION_SUMMARY\|' | Select-Object -Last 1
$fresh | Select-String 'CONTINUATION_ASSERT\|.*FAIL|CONTINUATION_DETAIL|CONTINUATION_RESUME_DETAIL|CONTINUATION_NATIVE_LATER_TICK|CONTINUATION_SUMMARY' | ForEach-Object {Write-Output $_}
foreach($journal in Get-ChildItem -LiteralPath $agent -Filter '*.log' | Where-Object {$_.BaseName -ge $started.ToString('yyyyMMdd')}){
  Copy-Item -LiteralPath $journal.FullName -Destination (Join-Path $PSScriptRoot ('continuation.'+$journal.BaseName+'.raw.log'))
}
if((Get-FileHash -LiteralPath $real -Algorithm SHA256).Hash -ne $expected){throw 'REAL DB changed; STOP'}
Write-Output "REAL_DB_UNCHANGED|sha256=$expected"
if(!$summary -or $summary -notmatch 'failed=0\|skipped=0'){throw 'Fresh executable suite did not pass'}
