param([string]$RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path)

# TEST ONLY / NOT FOR PRODUCTION / NO BROKER ACCESS
# Scanner data below is the sole permitted occurrence of the denied API names.

$ErrorActionPreference = 'Stop'
$scope = @(
  (Join-Path $RepositoryRoot 'FusionProV5\ExecutionLayer\PersistenceReference'),
  (Join-Path $RepositoryRoot 'FusionProV5\Tests\Sprint5PhaseD')
)
$denied = @(
  'DatabaseOpen','DatabaseClose','DatabaseExecute','DatabasePrepare','DatabaseRead',
  'DatabaseTransactionBegin','DatabaseTransactionCommit','DatabaseTransactionRollback',
  'GlobalVariable','FileOpen','OrderSend','OrderSendAsync','CTrade','PositionGet',
  'PositionSelect','OrderGet','HistoryOrder','HistoryDeal','AccountInfo','SymbolInfo',
  'CopyBuffer','CopyRates','CopyTicks','iCustom','TimeCurrent','TimeTradeServer',
  'TimeLocal','WebRequest','Socket','OnTick','OnTimer','OnTradeTransaction'
)
$violations = [System.Collections.Generic.List[string]]::new()
foreach ($root in $scope) {
  Get-ChildItem -LiteralPath $root -Recurse -File -Include *.mqh,*.mq5,*.py |
    Where-Object { $_.Name -ne 'verify_phase_d_static.ps1' } |
    ForEach-Object {
      $path = $_.FullName
      foreach ($pattern in $denied) {
        $matches = Select-String -LiteralPath $path -SimpleMatch $pattern
        foreach ($match in $matches) { $violations.Add("${path}:$($match.LineNumber):$pattern") }
      }
    }
}
if ($violations.Count -gt 0) {
  $violations | ForEach-Object { Write-Error $_ }
  exit 1
}
Write-Output '{"status":"PASS","executable_forbidden_api_matches":0,"scope":"Phase D reference and tests"}'
