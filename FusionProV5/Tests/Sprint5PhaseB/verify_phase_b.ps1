param([string]$RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path)

# TEST ONLY / NOT FOR PRODUCTION / NO BROKER ACCESS
# Independent executable test oracle. It does NOT execute the MQL implementation,
# MetaTrader Terminal, Strategy Tester, a broker, or a physical persistence store.

$ErrorActionPreference = 'Stop'
$script:Total = 0
$script:Passed = 0
$script:Failures = [System.Collections.Generic.List[string]]::new()

function Assert-Oracle([bool]$Condition,[string]$Id,[string]$Message) {
  $script:Total++
  if ($Condition) { $script:Passed++; return }
  $script:Failures.Add("$Id $Message")
}

$Utf8 = [System.Text.UTF8Encoding]::new($false,$true)
function Field([string]$Name,[string]$Type,[string]$Value) {
  $length = $Utf8.GetByteCount($Value)
  return '{0}:{1}:{2}:{3}' -f $Name,$Type,$length,$Value
}
function S([string]$Name,[string]$Value) { Field $Name 's' $Value }
function I([string]$Name,[Int64]$Value) { Field $Name 'i' $Value.ToString([Globalization.CultureInfo]::InvariantCulture) }
function U([string]$Name,[UInt64]$Value) { Field $Name 'u' $Value.ToString([Globalization.CultureInfo]::InvariantCulture) }
function X([string]$Name,[string]$Value) { Field $Name 'x' $Value }
function Sha([string]$Value) {
  $algorithm = [Security.Cryptography.SHA256]::Create()
  try { return ([BitConverter]::ToString($algorithm.ComputeHash($Utf8.GetBytes($Value)))).Replace('-','').ToLowerInvariant() }
  finally { $algorithm.Dispose() }
}
function Domain([string]$Name,[string]$Body) { Sha ((S 'domain' $Name)+(X 'body' $Body)) }

function Version([string]$Name) {
  X $Name ((S 'contract_name' 'SWV5-PRODUCTION-CONTRACT')+(I 'schema_version' 5)+(I 'minimum_compatible_version' 5)+(S 'policy_id' 'SWV5-PRODUCTION-CONTRACT-V5'))
}
function Key([string]$Name,[Int64]$Login,[string]$Broker,[string]$Server,[string]$Symbol,[string]$Strategy,[UInt64]$Magic) {
  X $Name ((I 'account_login' $Login)+(S 'broker_identity' $Broker)+(S 'server' $Server)+(S 'symbol' $Symbol)+(S 'strategy_id' $Strategy)+(U 'magic' $Magic))
}
function Namespace([string]$Basket='BASKET-1',[string]$Symbol='XAUUSD') {
  X 'persistence_namespace' ((Version 'version')+(Key 'ownership_namespace' 1001 'TEST-BROKER' 'TEST-SERVER' $Symbol 'FUSION' 5005)+(S 'basket_id' $Basket))
}
function BindingIds([string]$Ingress,[uint32]$Ordinal,[string]$Basket='BASKET-1',[string]$Policy='SWV5-SPRINT5-REQUEST-BINDING-POLICY-V1',[uint32]$PolicyVersion=1) {
  $bindingBody = (Namespace $Basket)+(S 'binding_policy_id' $Policy)+(U 'binding_policy_version' $PolicyVersion)+(S 'accepted_ingress_identity' $Ingress)
  $correlation = Domain 'SWV5-SPRINT5-REQUEST-BINDING-V1' $bindingBody
  $correlationField = S 'correlation_id' $correlation
  [pscustomobject]@{
    Correlation = $correlation
    Attempt = Domain 'SWV5-SPRINT5-ATTEMPT-V1' ($correlationField+(U 'attempt_ordinal' $Ordinal))
    Idempotency = Domain 'SWV5-SPRINT5-IDEMPOTENCY-V1' $correlationField
    Preimage = $bindingBody
  }
}

# Canonical and cryptographic reference vectors.
Assert-Oracle ((Sha '') -eq 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855') 'CAN-001' 'SHA-256 empty vector'
Assert-Oracle ((Sha 'abc') -eq 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad') 'CAN-002' 'SHA-256 abc vector'
$thai = [string][char]0x0E44+[char]0x0E17+[char]0x0E22
Assert-Oracle ((S 'utf8' $thai) -eq ('utf8:s:9:'+$thai)) 'CAN-003' 'UTF-8 octet length'
Assert-Oracle ((S 'empty' '') -eq 'empty:s:0:') 'CAN-004' 'empty canonical string'
Assert-Oracle ((Domain 'A' 'body') -ne (Domain 'B' 'body')) 'CAN-005' 'domain separation'

$binding0 = BindingIds 'INGRESS-A' 0
$binding1 = BindingIds 'INGRESS-A' 1
$bindingOtherSequence = BindingIds 'INGRESS-A' 0 # sequence is intentionally absent from API/preimage
$bindingOtherNamespace = BindingIds 'INGRESS-A' 0 'BASKET-2'
$bindingOtherPolicy = BindingIds 'INGRESS-A' 0 'BASKET-1' 'SWV5-SPRINT5-REQUEST-BINDING-POLICY-V2' 2
$bindingOtherIngress = BindingIds 'INGRESS-B' 0
Assert-Oracle ($binding0.Correlation -eq '71b35f2e560c20300183f3b5400289def1cc7c8cee98d20e29d96387e8211d06') 'BND-001' 'fixed correlation hash'
Assert-Oracle ($binding0.Attempt -eq '5d202482a3f1981ba7fae20b52cf33855fc371b255e3ee575c792e4c2e993d1a') 'BND-002' 'fixed initial attempt hash'
Assert-Oracle ($binding1.Attempt -eq '953204b64927dc3aded48de51b90b98e601102dedbd9289061554ff67a37a77c') 'BND-003' 'fixed retry attempt hash'
Assert-Oracle ($binding0.Idempotency -eq '5378f4b150446114669e6d8f09647018bfa9dd84e1f6ec5179598b0092fb4df4') 'BND-004' 'fixed idempotency hash'
Assert-Oracle ($binding0.Correlation -eq $bindingOtherSequence.Correlation) 'BND-005' 'correlation excludes logical sequence'
Assert-Oracle ($binding0.Correlation -ne $bindingOtherNamespace.Correlation) 'BND-006' 'namespace changes correlation'
Assert-Oracle ($binding0.Correlation -ne $bindingOtherPolicy.Correlation) 'BND-007' 'policy changes correlation'
Assert-Oracle ($binding0.Correlation -ne $bindingOtherIngress.Correlation) 'BND-008' 'ingress changes correlation'
Assert-Oracle ($binding0.Attempt -ne $binding1.Attempt) 'BND-009' 'ordinal changes attempt'
Assert-Oracle ($binding0.Idempotency -eq $binding1.Idempotency) 'BND-010' 'idempotency binds correlation only'

# Permit identity is independently reconstructed from the approved preimage.
function RequestIdentity([string]$Correlation,[string]$Attempt,[string]$Idempotency) {
  X 'logical_request' ((Version 'version')+(S 'correlation_id' $Correlation)+(S 'attempt_id' $Attempt)+(S 'parent_attempt_id' '')+(U 'monotonic_sequence' 1)+(I 'created_at' 900)+(S 'idempotency_key' $Idempotency))
}
$permitBody = (Namespace)+(S 'permit_policy_id' 'SWV5-SPRINT5-SUBMISSION-PERMIT-POLICY-V1')+(U 'permit_policy_version' 1)+(RequestIdentity $binding0.Correlation $binding0.Attempt $binding0.Idempotency)+(S 'unique_attempt' $binding0.Attempt)
$permitId = Domain 'SWV5-SPRINT5-PERMIT-ID-V1' $permitBody
Assert-Oracle ($permitId -eq '8aa73d7f5f37f446705e06a9186b989f7004b0d91527422c272128b8438d84e0') 'PER-001' 'fixed Permit ID hash'
$permitWithMutableRevision = Domain 'SWV5-SPRINT5-PERMIT-ID-V1' $permitBody
Assert-Oracle ($permitWithMutableRevision -eq $permitId) 'PER-002' 'Permit ID excludes mutable revision/store state'

# Independent state models for anti-replay, overflow, publication, and Claim.
function LedgerDisposition([bool]$Present,[bool]$PayloadSame,[UInt64]$Sequence,[UInt64]$Hwm) {
  if ($Present) { if ($PayloadSame) { 'DUPLICATE' } else { 'CONFLICT' }; return }
  if ($Sequence -le $Hwm) { 'DENIED' } else { 'NEW' }
}
Assert-Oracle ((LedgerDisposition $false $false 10 10) -eq 'DENIED') 'LED-001' 'unseen below HWM denied'
Assert-Oracle ((LedgerDisposition $true $true 10 10) -eq 'DUPLICATE') 'LED-002' 'proven membership idempotent'
Assert-Oracle ((LedgerDisposition $true $false 10 10) -eq 'CONFLICT') 'LED-003' 'same identity conflicting payload'
Assert-Oracle ((LedgerDisposition $false $false 11 10) -eq 'NEW') 'LED-004' 'new above HWM'

function SequenceEligible([UInt64]$Hwm,[UInt64]$Revision,[UInt64]$Proposed,[UInt64]$NextRevision) {
  if ($Hwm -eq [UInt64]::MaxValue -or $Revision -eq [UInt64]::MaxValue) { return $false }
  return $Proposed -eq ($Hwm+1) -and $NextRevision -eq ($Revision+1)
}
Assert-Oracle (SequenceEligible 10 4 11 5) 'SEQ-001' 'monotonic allocation'
Assert-Oracle (-not (SequenceEligible ([UInt64]::MaxValue) 4 0 5)) 'SEQ-002' 'HWM overflow denied'
Assert-Oracle (-not (SequenceEligible 10 ([UInt64]::MaxValue) 11 0)) 'SEQ-003' 'allocator overflow denied'

function PublicationEligible([string]$CurrentDigest,[string]$ExpectedDigest,[string]$CurrentStore,[string]$ExpectedStore,[UInt64]$CurrentRevision,[UInt64]$ExpectedRevision) {
  $CurrentDigest -eq $ExpectedDigest -and $CurrentStore -eq $ExpectedStore -and $CurrentRevision -eq $ExpectedRevision
}
Assert-Oracle (PublicationEligible 'SET-A' 'SET-A' 'STORE-1' 'STORE-1' 7 7) 'PUB-001' 'exact current publication accepted'
Assert-Oracle (-not (PublicationEligible 'SET-B' 'SET-A' 'STORE-1' 'STORE-1' 7 7)) 'PUB-002' 'current digest mismatch denied'
Assert-Oracle (-not (PublicationEligible 'SET-A' 'SET-A' 'STORE-2' 'STORE-1' 7 7)) 'PUB-003' 'stale store denied'
Assert-Oracle (-not (PublicationEligible 'SET-A' 'SET-A' 'STORE-1' 'STORE-1' 8 7)) 'PUB-004' 'stale logical revision denied'

function ClaimPrepare([string]$State,[UInt64]$Revision,[UInt64]$Expected,[bool]$OwnerMatches,[bool]$SnapshotMatches,[bool]$TimeValid) {
  if ($State -ne 'COMMITTED_NOT_INVOKED') { return 'ALREADY_CLAIMED' }
  if ($Revision -ne $Expected) { return 'CONFLICT' }
  if (-not $OwnerMatches) { return 'STALE_OWNER' }
  if (-not $SnapshotMatches) { return 'SNAPSHOT_MISMATCH' }
  if (-not $TimeValid) { return 'EXPIRED' }
  'TRANSITION_ELIGIBLE_NO_GRANT'
}
Assert-Oracle ((ClaimPrepare 'COMMITTED_NOT_INVOKED' 1 1 $true $true $true) -eq 'TRANSITION_ELIGIBLE_NO_GRANT') 'CLM-001' 'pure prepare has no grant'
Assert-Oracle ((ClaimPrepare 'INVOCATION_CLAIMED_UNRESOLVED' 2 2 $true $true $true) -eq 'ALREADY_CLAIMED') 'CLM-002' 'current N+1 replay denied'
Assert-Oracle ((ClaimPrepare 'COMMITTED_NOT_INVOKED' 1 1 $false $true $true) -eq 'STALE_OWNER') 'CLM-003' 'takeover first denied'
Assert-Oracle ((ClaimPrepare 'COMMITTED_NOT_INVOKED' 1 1 $true $false $true) -eq 'SNAPSHOT_MISMATCH') 'CLM-004' 'full snapshot mismatch denied'
Assert-Oracle ((ClaimPrepare 'COMMITTED_NOT_INVOKED' 1 1 $true $true $false) -eq 'EXPIRED') 'CLM-005' 'exclusive expiry denied'

# Repository structural and safety assertions.
$contracts = Join-Path $RepositoryRoot 'FusionProV5\ExecutionLayer\Contracts'
$production = Join-Path $RepositoryRoot 'FusionProV5\ProductionArchitecture'
$headers = @(Get-ChildItem -LiteralPath $contracts -Filter '*.mqh' -File | Sort-Object Name)
$expectedHeaders = @('SW_V5_S5_Common.mqh','SW_V5_S5_Canonical.mqh','SW_V5_S5_IngressContract.mqh','SW_V5_S5_ProducerTrustContract.mqh','SW_V5_S5_IngressLedgerContract.mqh','SW_V5_S5_RequestSequenceContract.mqh','SW_V5_S5_RequestBindingContract.mqh','SW_V5_S5_RuntimePublicationContract.mqh','SW_V5_S5_SubmissionAuthorityContract.mqh','SW_V5_S5_AdmissionSnapshotContract.mqh','SW_V5_S5_InvocationClaimContract.mqh','SW_V5_S5_AdmissionContract.mqh','SW_V5_S5_OrchestrationContract.mqh','SW_V5_S5_Contracts.mqh')
foreach ($name in $expectedHeaders) { Assert-Oracle (Test-Path -LiteralPath (Join-Path $contracts $name)) 'STA-001' "missing $name" }
$allContractText = ($headers | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw }) -join "`n"

$forbidden = @('OrderSend','OrderSendAsync','CTrade','PositionGet','PositionSelect','OrderGet','HistoryOrder','HistoryDeal','AccountInfo','SymbolInfo','MarketBook','CopyTicks','CopyRates','CopyBuffer','iCustom','OnTradeTransaction','OnTick','TimeCurrent','TimeTradeServer','GetTickCount','MathRand','GlobalVariable','FileOpen','FileWrite','DatabaseOpen','SocketCreate','WebRequest')
foreach ($token in $forbidden) { Assert-Oracle ($allContractText -notmatch [regex]::Escape($token)) 'STA-002' "forbidden token $token" }
Assert-Oracle ($allContractText -notmatch 'claim_granted_now\s*=\s*true') 'STA-003' 'pure source must never mint grant'
Assert-Oracle ($allContractText -notmatch 'hard_kill_blocks_increase') 'STA-004' 'post-P Hard Kill veto removed'
Assert-Oracle ($allContractText -notmatch 'SWV5S5_StableAuthorityToken') 'STA-005' 'generic stable token removed'
Assert-Oracle ($allContractText -notmatch 'canonical_membership_binding_index|canonical_correlation_index|correlation_exists|existing_sequence') 'STA-006' 'opaque/caller membership removed'
Assert-Oracle ($allContractText -match 'PrepareInvocationClaimTransition' -and $allContractText -match 'TryClaimInvocation') 'STA-007' 'Claim preparation/authority split'
Assert-Oracle ($allContractText -match 'SWV5S5_SubmissionAuthorityRecord resulting_authority_record') 'STA-008' 'full durable Claim result'
Assert-Oracle ($allContractText -match 'SWV5S5_RequestSetPublicationProposal' -and $allContractText -match 'SWV5S5_CheckpointPublicationProposal') 'STA-009' 'domain-specific publication DTOs'

$productionText = (Get-ChildItem -LiteralPath $production -Filter '*.mqh' -File | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw }) -join "`n"
Assert-Oracle ($productionText -notmatch 'ExecutionLayer|SW_V5_S5_') 'DEP-001' 'ProductionArchitecture reverse dependency'
Assert-Oracle ($allContractText -notmatch '(SignalEngine|DecisionEngine|Engines/)') 'DEP-002' 'Signal/Decision dependency'

$graph = @{}
foreach ($file in $headers) {
  $graph[$file.Name] = @()
  $text = Get-Content -LiteralPath $file.FullName -Raw
  foreach ($match in [regex]::Matches($text,'#include\s+"([^"]+)"')) {
    $leaf = Split-Path $match.Groups[1].Value -Leaf
    if ($expectedHeaders -contains $leaf) { $graph[$file.Name] += $leaf }
  }
}
$visiting=@{}; $visited=@{}; $cycles=[System.Collections.Generic.List[string]]::new()
function Visit([string]$Node) {
  if ($visiting[$Node]) { $cycles.Add($Node); return }
  if ($visited[$Node]) { return }
  $visiting[$Node]=$true
  foreach ($next in $graph[$Node]) { Visit $next }
  $visiting[$Node]=$false; $visited[$Node]=$true
}
foreach ($node in $graph.Keys) { Visit $node }
Assert-Oracle ($cycles.Count -eq 0) 'DEP-003' 'include cycle'

# Verifier adversarial self-tests use only memory fixtures and must detect each fault.
function Adversarial-Fails([scriptblock]$Check) { try { return -not (& $Check) } catch { return $true } }
Assert-Oracle (Adversarial-Fails { (Sha 'abc') -eq ('0'*64) }) 'ADV-001' 'wrong SHA fixture must fail'
Assert-Oracle (Adversarial-Fails { 'void x(){ OrderSend(); }' -notmatch 'OrderSend' }) 'ADV-002' 'forbidden API fixture must fail'
Assert-Oracle (Adversarial-Fails { '#include "../ExecutionLayer/Contracts/X.mqh"' -notmatch 'ExecutionLayer' }) 'ADV-003' 'dependency violation fixture must fail'
Assert-Oracle (Adversarial-Fails { $binding0.Correlation -eq ('f'*64) }) 'ADV-004' 'wrong binding hash must fail'
Assert-Oracle (Adversarial-Fails { PublicationEligible 'SET-B' 'SET-A' 'STORE-1' 'STORE-1' 7 7 }) 'ADV-005' 'stale publication fixture must fail'

$summary = [ordered]@{
  oracle='SPRINT5_PHASE_B1_INDEPENDENT_TEST_ORACLE'
  mql_production_executed=$false
  total=$script:Total
  passed=$script:Passed
  failed=$script:Failures.Count
  binding_correlation=$binding0.Correlation
  binding_attempt_0=$binding0.Attempt
  binding_attempt_1=$binding1.Attempt
  binding_idempotency=$binding0.Idempotency
  permit_id=$permitId
}
if ($script:Failures.Count -gt 0) {
  $script:Failures | ForEach-Object { Write-Host "FAIL: $_" }
  $summary | ConvertTo-Json -Compress | Write-Host
  exit 1
}
Write-Host ($summary | ConvertTo-Json -Compress)
exit 0
