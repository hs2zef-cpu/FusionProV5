param([switch]$RunTester,[switch]$SkipCompile)
# TEST ONLY / NO BROKER ACCESS. Never launches the attended production runner.
$ErrorActionPreference='Stop'
$repo=(Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$editor='C:\Program Files\MetaTrader 5\metaeditor64.exe'
$terminal='C:\Program Files\MetaTrader 5\terminal64.exe'
$data=Join-Path $env:APPDATA 'MetaQuotes/Terminal/D0E8209F77C8CF37AD8BF550E51FF075'
$agent=Join-Path $env:APPDATA 'MetaQuotes/Tester/D0E8209F77C8CF37AD8BF550E51FF075/Agent-127.0.0.1-3000/logs'
$folders=@('Sprint5MvpRuntime','Sprint5MvpOwnershipAcquisition','Sprint5MvpControlledDemo','Sprint5MvpD1Authorities','Sprint5PhaseFBrokerAdapter')
if(!$SkipCompile){
  foreach($folder in $folders){
    foreach($source in Get-ChildItem -LiteralPath (Join-Path $repo "FusionProV5/Tests/$folder") -Filter '*.mq5' -File){
      Start-Process -FilePath $editor -ArgumentList ('/compile:"'+$source.FullName+'"'),'/log' -WindowStyle Hidden -Wait
      $log=[IO.Path]::ChangeExtension($source.FullName,'.log')
      $result=Get-Content -LiteralPath $log | Select-String '^Result:' | Select-Object -Last 1
      Write-Output ("COMPILE|"+$source.Name+"|"+$result)
      if(!$result -or $result -notmatch '^Result: 0 errors, 0 warnings.*X64 Regular'){
        throw "Compile gate failed: $($source.FullName)"
      }
    }
  }
}
if(!$RunTester){return}
$runs=@(
 @('Sprint5MvpD1Authorities/mvp_basket_authority_offline_tester.ini','MVP_BASKET_AUTHORITY_SUMMARY',36),
 @('Sprint5MvpD1Authorities/mvp_d1_authority_offline_tester.ini','MVP_D1_AUTHORITY_SUMMARY',96),
 @('Sprint5MvpD1Authorities/mvp_hard_kill_activation_offline_tester.ini','MVP_HK_ACTIVATION_SUMMARY',26),
 @('Sprint5MvpControlledDemo/controlled_demo_offline_tester.ini','CONTROLLED_DEMO_SUMMARY',59),
 @('Sprint5MvpRuntime/mvp_runtime_offline_tester.ini','MVP_RUNTIME_SUMMARY',88),
 @('Sprint5MvpOwnershipAcquisition/ownership_acquisition_offline_tester.ini','OWNERSHIP_ACQUISITION_SUMMARY',32),
 @('Sprint5MvpRuntime/mvp_authority_round_trip_offline_tester.ini','MVP_AUTHORITY_ROUND_TRIP_SUMMARY',31),
 @('Sprint5MvpRuntime/mvp_utf8_codec_offline_tester.ini','MVP_UTF8_CODEC_SUMMARY',10),
 @('Sprint5MvpRuntime/phase_f_broker_mql_regression.ini','S5F_BROKER_MQL_RESULT',48)
)
foreach($run in $runs){
  if(Get-Process -Name terminal64 -ErrorAction SilentlyContinue){throw 'Existing terminal: stop without interacting with it.'}
  $config=Join-Path $repo ('FusionProV5/Tests/'+$run[0]); $settings=Get-Content -LiteralPath $config -Raw
  if($settings -notmatch '\[Tester\]' -or $settings -notmatch 'ShutdownTerminal=1' -or
     $settings -match '\[Experts\]|\[StartUp\]|Login=|Password=|Server='){throw 'Unsafe tester configuration.'}
  $expert=([regex]::Match($settings,'(?m)^Expert=(.+)$')).Groups[1].Value.Trim()
  $filename=[IO.Path]::GetFileName($expert)
  $source=Get-ChildItem -LiteralPath (Join-Path $repo 'FusionProV5/Tests') -Recurse -File -Filter ([IO.Path]::ChangeExtension($filename,'.mq5'))
  if(@($source).Count -ne 1 -or $source.Name -notmatch 'TESTS|ASSERTIONS'){throw 'Not an allowlisted offline assertion manifest.'}
  Copy-Item -LiteralPath ([IO.Path]::ChangeExtension($source.FullName,'.ex5')) -Destination (Join-Path $data ('MQL5/Experts/'+$expert))
  $started=Get-Date
  Start-Process -FilePath $terminal -ArgumentList ('/config:"'+$config+'"') -WindowStyle Hidden -Wait
  $journal=Get-ChildItem -LiteralPath $agent -Filter '*.log' | Sort-Object LastWriteTime | Select-Object -Last 1
  $lines=Get-Content -LiteralPath $journal.FullName
  $wallStart=$started.ToString('HH:mm:ss.fff')
  $freshLines=$lines | Where-Object {$_ -match '^CS\s+\d+\s+(\d\d:\d\d:\d\d\.\d\d\d)' -and $Matches[1] -ge $wallStart}
  $summary=$freshLines | Select-String ([regex]::Escape($run[1])+'\|') | Select-Object -Last 1
  Write-Output ("TESTER|"+$started.ToString('o')+"|"+$summary)
  Copy-Item -LiteralPath $journal.FullName -Destination (Join-Path $PSScriptRoot ($run[1]+'.raw.log'))
  if(!$summary -or $summary -notmatch 'failed=0' -or $summary -notmatch 'skipped=0' -or
     $summary -notmatch ('passed='+$run[2]+'\|')){throw "Tester gate failed: $($run[1])"}
}
