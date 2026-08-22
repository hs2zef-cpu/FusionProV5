param(
  [string]$RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
)

$ErrorActionPreference = 'Stop'
$contracts = Join-Path $RepositoryRoot 'FusionProV5\ExecutionLayer\Contracts'
$tests = Join-Path $RepositoryRoot 'FusionProV5\Tests\Sprint5PhaseB'
$production = Join-Path $RepositoryRoot 'FusionProV5\ProductionArchitecture'
$failures = [System.Collections.Generic.List[string]]::new()

function Fail([string]$message) { $failures.Add($message) }

$headers = @(Get-ChildItem -LiteralPath $contracts -Filter '*.mqh' -File | Sort-Object Name)
$expected = @(
  'SW_V5_S5_Common.mqh','SW_V5_S5_Canonical.mqh','SW_V5_S5_IngressContract.mqh',
  'SW_V5_S5_ProducerTrustContract.mqh','SW_V5_S5_IngressLedgerContract.mqh',
  'SW_V5_S5_RequestSequenceContract.mqh','SW_V5_S5_RequestBindingContract.mqh',
  'SW_V5_S5_RuntimePublicationContract.mqh','SW_V5_S5_SubmissionAuthorityContract.mqh',
  'SW_V5_S5_AdmissionSnapshotContract.mqh','SW_V5_S5_AdmissionContract.mqh',
  'SW_V5_S5_OrchestrationContract.mqh','SW_V5_S5_Contracts.mqh'
)
foreach ($name in $expected) {
  if (-not (Test-Path -LiteralPath (Join-Path $contracts $name))) { Fail "missing contract: $name" }
}

$forbidden = @(
  'OrderSend','OrderSendAsync','CTrade','PositionGet','PositionSelect','OrderGet',
  'HistoryOrder','HistoryDeal','AccountInfo','SymbolInfo','MarketBook','CopyTicks',
  'CopyRates','CopyBuffer','iCustom','OnTradeTransaction','OnTick','TimeCurrent',
  'TimeTradeServer','GlobalVariable','FileOpen','DatabaseOpen','SocketCreate','WebRequest'
)
foreach ($file in $headers) {
  $text = Get-Content -LiteralPath $file.FullName -Raw
  foreach ($token in $forbidden) {
    if ($text -match [regex]::Escape($token)) { Fail "forbidden token $token in $($file.Name)" }
  }
}

$productionText = (Get-ChildItem -LiteralPath $production -Filter '*.mqh' -File |
  ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw }) -join "`n"
if ($productionText -match 'ExecutionLayer|SW_V5_S5_') { Fail 'ProductionArchitecture depends on Sprint 5' }

$graph = @{}
foreach ($file in $headers) {
  $graph[$file.Name] = @()
  $text = Get-Content -LiteralPath $file.FullName -Raw
  foreach ($m in [regex]::Matches($text, '#include\s+"([^"]+)"')) {
    $leaf = Split-Path $m.Groups[1].Value -Leaf
    if ($expected -contains $leaf) { $graph[$file.Name] += $leaf }
  }
}
$visiting = @{}; $visited = @{}
function Visit([string]$node) {
  if ($visiting[$node]) { Fail "include cycle at $node"; return }
  if ($visited[$node]) { return }
  $visiting[$node] = $true
  foreach ($next in $graph[$node]) { Visit $next }
  $visiting[$node] = $false; $visited[$node] = $true
}
foreach ($node in $graph.Keys) { Visit $node }

$requiredTokens = @(
  'SWV5-SHA256-UTF8-V1','SWV5-SPRINT5-INGRESS-ID-V1','SWV5-SPRINT5-INGRESS-PAYLOAD-V1',
  'SWV5-SPRINT5-PRODUCER-TRUST-V1','SWV5-SPRINT5-INGRESS-LEDGER-V1',
  'SWV5-SPRINT5-REQUEST-BINDING-V1','SWV5-SPRINT5-ATTEMPT-V1','SWV5-SPRINT5-IDEMPOTENCY-V1',
  'SWV5-SPRINT5-REQUEST-SEQUENCE-AUTHORITY-V1','SWV5-SPRINT5-PERMIT-ID-V1',
  'SWV5-SPRINT5-SUBMISSION-PERMIT-V1','SWV5-SPRINT5-REQUEST-SET-PUBLICATION-V1',
  'SWV5-SPRINT5-CHECKPOINT-PUBLICATION-V1','SWV5-SPRINT5-ADMISSION-SNAPSHOT-V1',
  'SWV5-SPRINT5-INVOCATION-CLAIM-V1','CLAIM_GRANTED_NOW','SPRINT5_RISK_EXPIRED_EXCLUSIVE'
)
$allContractText = ($headers | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw }) -join "`n"
foreach ($token in $requiredTokens) {
  if ($allContractText -notmatch [regex]::Escape($token)) { Fail "coverage token missing: $token" }
}

$sha = [System.Security.Cryptography.SHA256]::Create()
try {
  $empty = ([BitConverter]::ToString($sha.ComputeHash([byte[]]::new(0)))).Replace('-', '').ToLowerInvariant()
  $abc = ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes('abc')))).Replace('-', '').ToLowerInvariant()
} finally { $sha.Dispose() }
if ($empty -ne 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855') { Fail 'trusted SHA-256 empty vector failed' }
if ($abc -ne 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad') { Fail 'trusted SHA-256 abc vector failed' }

$inventory = Get-Content -LiteralPath (Join-Path $tests 'TEST_INVENTORY.md') -Raw
foreach ($id in @('CAN-','ING-','TRU-','LED-','SEQ-','BND-','PUB-','PER-','CLM-','ADM-','MUT-','ORC-')) {
  if ($inventory -notmatch [regex]::Escape($id)) { Fail "test inventory domain missing: $id" }
}

if ($failures.Count -gt 0) {
  $failures | ForEach-Object { Write-Host "FAIL: $_" }
  exit 1
}
Write-Host "PASS: expected contract headers = $($expected.Count)"
Write-Host 'PASS: forbidden API scan'
Write-Host 'PASS: dependency direction and include-cycle scan'
Write-Host 'PASS: contract/domain coverage scan'
Write-Host "PASS: trusted SHA-256 vectors empty=$empty abc=$abc"
Write-Host 'PASS: Phase B test inventory domains'
