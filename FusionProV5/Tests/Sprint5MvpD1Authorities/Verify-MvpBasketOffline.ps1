param([switch]$RunTester,[switch]$SkipCompile,[switch]$AccountOnly,[switch]$LaunchOnly)
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
 @('Sprint5MvpControlledDemo/attended_launch_offline_tester.ini','ATTENDED_LAUNCH_SUMMARY',47),
 @('Sprint5MvpD1Authorities/mvp_account_authority_offline_tester.ini','MVP_ACCOUNT_AUTHORITY_SUMMARY',61),
 @('Sprint5MvpD1Authorities/mvp_basket_authority_offline_tester.ini','MVP_BASKET_AUTHORITY_SUMMARY',36),
 @('Sprint5MvpD1Authorities/mvp_basket_restart_offline_tester.ini','MVP_BASKET_RESTART_SUMMARY',4),
 @('Sprint5MvpD1Authorities/mvp_d1_authority_offline_tester.ini','MVP_D1_AUTHORITY_SUMMARY',96),
 @('Sprint5MvpD1Authorities/mvp_hard_kill_activation_offline_tester.ini','MVP_HK_ACTIVATION_SUMMARY',26),
 @('Sprint5MvpControlledDemo/controlled_demo_offline_tester.ini','CONTROLLED_DEMO_SUMMARY',59),
 @('Sprint5MvpRuntime/mvp_runtime_offline_tester.ini','MVP_RUNTIME_SUMMARY',88),
 @('Sprint5MvpOwnershipAcquisition/ownership_acquisition_offline_tester.ini','OWNERSHIP_ACQUISITION_SUMMARY',32),
 @('Sprint5MvpRuntime/mvp_authority_round_trip_offline_tester.ini','MVP_AUTHORITY_ROUND_TRIP_SUMMARY',31),
 @('Sprint5MvpRuntime/mvp_utf8_codec_offline_tester.ini','MVP_UTF8_CODEC_SUMMARY',10),
 @('Sprint5MvpRuntime/phase_f_broker_mql_regression.ini','S5F_BROKER_MQL_RESULT',48)
)
if($AccountOnly){$runs=@($runs | Where-Object {$_[1] -eq 'MVP_ACCOUNT_AUTHORITY_SUMMARY'})}
if($LaunchOnly){$runs=@($runs | Where-Object {$_[1] -eq 'ATTENDED_LAUNCH_SUMMARY'})}
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
  # MT5 can hand off to a successor process before the invoking process exits.
  # Do not read a buffered journal or start another run while it is still active.
  $waited=0
  while(Get-Process -Name terminal64,metatester64 -ErrorAction SilentlyContinue){
    if($waited -ge 1200){throw 'Offline tester did not exit; preserve it and stop.'}
    Start-Sleep -Seconds 1; $waited++
  }
  $summary=$null
  do {
    $journals=Get-ChildItem -LiteralPath $agent -Filter '*.log' | Where-Object {$_.BaseName -ge $started.ToString('yyyyMMdd',[cultureinfo]::InvariantCulture)}
    $freshLines=@(foreach($journal in $journals){
      foreach($line in Get-Content -LiteralPath $journal.FullName){
        if($line -match '^CS\s+\d+\s+(\d\d:\d\d:\d\d\.\d\d\d)'){
          $lineAt=[datetime]::ParseExact($journal.BaseName+' '+$Matches[1],'yyyyMMdd HH:mm:ss.fff',[cultureinfo]::InvariantCulture)
          if($lineAt -ge $started){$line}
        }
      }
    })
    $summary=$freshLines | Select-String ([regex]::Escape($run[1])+'\|') | Select-Object -Last 1
    if(!$summary){
      if($waited -ge 1200){throw 'No fresh tester summary; preserve processes and stop.'}
      Start-Sleep -Seconds 1; $waited++
    }
  } while(!$summary)
  while(Get-Process -Name terminal64,metatester64 -ErrorAction SilentlyContinue){
    if($waited -ge 1200){throw 'Tester summary exists but processes did not exit; stop.'}
    Start-Sleep -Seconds 1; $waited++
  }
  Write-Output ("TESTER|"+$started.ToString('o')+"|"+$summary)
  foreach($journal in $journals){
    Copy-Item -LiteralPath $journal.FullName -Destination (Join-Path $PSScriptRoot ($run[1]+'.'+$journal.BaseName+'.raw.log'))
  }
  if(!$summary -or $summary -notmatch 'failed=0' -or $summary -notmatch 'skipped=0' -or
     $summary -notmatch ('passed='+$run[2]+'\|')){throw "Tester gate failed: $($run[1])"}
}
