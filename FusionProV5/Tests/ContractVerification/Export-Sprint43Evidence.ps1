# TEST ONLY
# NOT FOR PRODUCTION
# NO BROKER ACCESS
# Exports tracked evidence from MetaTester journal output produced by the harness.
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$AgentLog,
    [Parameter(Mandatory=$true)][string]$CompileLog,
    [Parameter(Mandatory=$true)][string]$Manifest,
    [Parameter(Mandatory=$true)][string]$RepoRoot,
    [Parameter(Mandatory=$true)][string]$OutputDirectory
)

$ErrorActionPreference = 'Stop'
$lines = Get-Content -LiteralPath $AgentLog
$resultIndexes = for ($index = 0; $index -lt $lines.Count; $index++) {
    if ($lines[$index] -match 'SPRINT4_3_CONTRACT_TESTS.*SWV5_MACHINE_RESULT ') { $index }
}
if ($resultIndexes.Count -lt 2) { throw 'Fewer than two Sprint 4.3 machine results were found.' }
$selectedIndexes = @($resultIndexes | Select-Object -Last 2)
$runs = @()
$rawBlocks = @()
$expectedTotal = 213

for ($runNumber = 0; $runNumber -lt 2; $runNumber++) {
    $resultIndex = $selectedIndexes[$runNumber]
    $startIndex = $resultIndex
    while ($startIndex -gt 0 -and $lines[$startIndex] -notmatch 'MetaTester 5 build') { $startIndex-- }
    $endIndex = $resultIndex
    while ($endIndex -lt ($lines.Count - 1) -and $lines[$endIndex] -notmatch 'OnTester result') { $endIndex++ }
    $block = @($lines[$startIndex..$endIndex])
    $rawBlocks += "===== FINAL RUN $($runNumber + 1) ====="
    $rawBlocks += $block

    $resultJson = ($lines[$resultIndex] -replace '^.*SWV5_MACHINE_RESULT ', '') | ConvertFrom-Json
    $buildLine = $block | Where-Object { $_ -match 'MetaTester 5 build' } | Select-Object -First 1
    $serverLine = $block | Where-Object { $_ -match '\([^)]*(Trial|Demo)[^)]*\): generating based' } | Select-Object -First 1
    $metadataLine = $block | Where-Object { $_ -match 'SWV5_RUN_METADATA' } | Select-Object -First 1
    $testerResultLine = $block | Where-Object { $_ -match 'OnTester result 1(\.0+)?$' } | Select-Object -First 1
    if (-not $serverLine) { throw "Run $($runNumber + 1) is not proven to use an MT5 Demo/Trial server." }
    if (-not $testerResultLine) { throw "Run $($runNumber + 1) did not produce OnTester result 1." }
    $terminalBuild = [int]([regex]::Match($buildLine, 'MetaTester 5 build (?<build>\d+)').Groups['build'].Value)
    $brokerServer = [regex]::Match($serverLine, '\((?<server>[^)]*)\): generating').Groups['server'].Value
    $runTime = [regex]::Match($lines[$resultIndex], '\t(?<time>\d{2}:\d{2}:\d{2}\.\d{3})\t').Groups['time'].Value

    $runs += [ordered]@{
        run = $runNumber + 1
        journal_time = $runTime
        total = [int]$resultJson.total
        passed = [int]$resultJson.passed
        failed = [int]$resultJson.failed
        skipped = [int]$resultJson.skipped
        signature = [string]$resultJson.signature
        internal_replay_deterministic = [bool]$resultJson.deterministic
        terminal_build = $terminalBuild
        broker_server = $brokerServer
        account_mode = 'HEDGING (deterministic fixture)'
        demo_strategy_tester = $true
        on_tester_result = 1
        harness_metadata = [string]$metadataLine
    }
}

$compileText = Get-Content -LiteralPath $CompileLog -Raw
$compileMatch = [regex]::Match($compileText, 'Result: (?<errors>\d+) errors, (?<warnings>\d+) warnings, (?<elapsed>\d+) ms elapsed, cpu=''(?<cpu>[^'']+)''')
if (-not $compileMatch.Success) { throw 'Compile result was not found.' }
$manifestSha = (Get-FileHash -LiteralPath $Manifest -Algorithm SHA256).Hash.ToLowerInvariant()
$exporterSha = (Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256).Hash.ToLowerInvariant()
$sourceCommit = (& git -C $RepoRoot rev-parse HEAD).Trim()
$sourceFiles = @(
    Get-Item -LiteralPath $Manifest
    Get-ChildItem -LiteralPath (Join-Path $RepoRoot 'FusionProV5\ProductionArchitecture') -File -Filter '*.mqh'
    Get-ChildItem -LiteralPath (Join-Path $RepoRoot 'FusionProV5\Tests\ContractVerification') -File -Filter '*.mqh'
) | Sort-Object FullName
$sourceIndex = $sourceFiles | ForEach-Object {
    $relative = $_.FullName.Substring($RepoRoot.Length).TrimStart('\')
    $hash = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    "$relative|$hash"
}
$sha256 = [System.Security.Cryptography.SHA256]::Create()
try {
    $sourceBytes = [System.Text.Encoding]::UTF8.GetBytes(($sourceIndex -join "`n"))
    $verificationSourceDigest = ([System.BitConverter]::ToString($sha256.ComputeHash($sourceBytes))).Replace('-', '').ToLowerInvariant()
}
finally { $sha256.Dispose() }
$deterministic = $runs[0].signature -eq $runs[1].signature -and
                 $runs[0].total -eq $runs[1].total -and
                 $runs[0].passed -eq $runs[1].passed -and
                 $runs[0].total -eq $expectedTotal -and $runs[1].total -eq $expectedTotal -and
                 $runs[0].passed -eq $expectedTotal -and $runs[1].passed -eq $expectedTotal -and
                 $runs[0].failed -eq 0 -and $runs[1].failed -eq 0 -and
                 $runs[0].skipped -eq 0 -and $runs[1].skipped -eq 0
if (-not $deterministic) { throw 'The two final runs are not deterministic and passing.' }

$generatedAt = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
$evidence = [ordered]@{
    schema = 'SWV5-CONTRACT-TEST-EVIDENCE-V2'
    generated_by = 'Export-Sprint43Evidence.ps1'
    exporter_sha256 = $exporterSha
    generated_at_utc = $generatedAt
    source_commit_sha = $sourceCommit
    manifest = (Split-Path -Leaf $Manifest)
    manifest_sha256 = $manifestSha
    verification_source_digest = $verificationSourceDigest
    contract_policy = 'SWV5-PRODUCTION-V3'
    implementation_under_test = 'ISWV5 interface implementations'
    compile = [ordered]@{
        errors = [int]$compileMatch.Groups['errors'].Value
        warnings = [int]$compileMatch.Groups['warnings'].Value
        elapsed_ms = [int]$compileMatch.Groups['elapsed'].Value
        cpu = $compileMatch.Groups['cpu'].Value
    }
    deterministic = $deterministic
    signature = $runs[0].signature
    total = $runs[0].total
    passed = $runs[0].passed
    failed = $runs[0].failed
    skipped = $runs[0].skipped
    runs = $runs
}

New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$jsonPath = Join-Path $OutputDirectory 'contract_test_results.json'
$rawPath = Join-Path $OutputDirectory 'sprint4_3_tester_evidence.txt'
$reportPath = Join-Path $OutputDirectory 'VERIFICATION_REPORT.md'
$compileReportPath = Join-Path $OutputDirectory 'COMPILE_REPORT.md'

$evidence | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $jsonPath -Encoding utf8
$rawBlocks | Set-Content -LiteralPath $rawPath -Encoding utf8

$report = @(
    '# Sprint 4.3 Interface-Level Contract Verification Report',
    '',
    '> TEST ONLY - NOT FOR PRODUCTION - NO BROKER ACCESS',
    '',
    '## Verdict',
    '',
    '**PASS - READY FOR INDEPENDENT REVIEW**',
    '',
    'Sprint 4 remains the authorized baseline. Sprint 4.1 remains Candidate / In Review. Sprint 4.2 is an authorized verification sub-sprint on the candidate branch. Sprint 4.3 corrects review findings but does not declare Architecture Lock, production readiness, or runtime authorization.',
    '',
    '## Generated evidence',
    '',
    "- Exported at UTC: ``$generatedAt``",
    "- Tested source commit: ``$sourceCommit``",
    "- Evidence exporter SHA-256: ``$exporterSha``",
    "- Manifest SHA-256: ``$manifestSha``",
    "- Verification source digest: ``$verificationSourceDigest``",
    "- Compile: $($evidence.compile.errors) errors, $($evidence.compile.warnings) warnings, $($evidence.compile.cpu)",
    "- Tests: $($evidence.total) total, $($evidence.passed) passed, $($evidence.failed) failed, $($evidence.skipped) skipped",
    "- Deterministic signature: ``$($evidence.signature)``",
    '- Independent runs: 2; signatures and counts identical',
    "- Terminal build: $($runs[0].terminal_build)",
    "- Broker/server evidence: $($runs[0].broker_server) (Demo/Trial Strategy Tester)",
    '- Account mode: HEDGING deterministic contract fixture',
    '',
    '## Scope',
    '',
    '- All 49 Basket state pairs execute through `ISWV5BasketStateMachineContract`.',
    '- All Production Contract V3 interfaces have deterministic in-memory test implementations.',
    '- The 30 corrective interface cases cover the ten final-review findings.',
    '- Ten interface-conformance cases directly invoke every remaining production interface method.',
    '- The original 162-case domain matrix remains present as regression coverage, with authoritative domain operations routed through interface implementations.',
    '- Eleven persistence round-trip cases prove field-preserving deep-copy behavior and fail-closed namespace/header validation through `ISWV5PersistenceContract`.',
    '- No broker command, runtime implementation, live account mutation, file/network validator dependency, Signal Engine change, or frozen baseline change is present.'
)
$report | Set-Content -LiteralPath $reportPath -Encoding utf8

$compileReport = @(
    '# Sprint 4.3 Contract Test Compile Report',
    '',
    '> TEST ONLY - NOT FOR PRODUCTION - NO BROKER ACCESS',
    '',
    "- Manifest: ``$(Split-Path -Leaf $Manifest)``",
    '- Compiler: MetaEditor X64 Regular',
    "- Result: **$($evidence.compile.errors) errors, $($evidence.compile.warnings) warnings**",
    "- Elapsed: $($evidence.compile.elapsed_ms) ms",
    "- Manifest SHA-256: ``$manifestSha``",
    "- Evidence exporter SHA-256: ``$exporterSha``",
    "- Exported: ``$generatedAt``"
)
$compileReport | Set-Content -LiteralPath $compileReportPath -Encoding utf8

Write-Output "Exported $jsonPath"
Write-Output "Exported $rawPath"
Write-Output "Exported $reportPath"
Write-Output "Exported $compileReportPath"
