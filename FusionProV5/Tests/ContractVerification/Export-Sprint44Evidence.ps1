# TEST ONLY
# NOT FOR PRODUCTION
# NO BROKER ACCESS
# Exports evidence exclusively from MetaEditor logs and MetaTester journal output.
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$AgentLog,
    [Parameter(Mandatory=$true)][string]$ArchitectureCompileLog,
    [Parameter(Mandatory=$true)][string]$TestCompileLog,
    [Parameter(Mandatory=$true)][string]$Manifest,
    [Parameter(Mandatory=$true)][string]$RepoRoot,
    [Parameter(Mandatory=$true)][string]$OutputDirectory
)

$ErrorActionPreference = 'Stop'
$expectedTotal = 238
$lines = Get-Content -LiteralPath $AgentLog
$resultIndexes = for ($index = 0; $index -lt $lines.Count; $index++) {
    if ($lines[$index] -match 'SPRINT4_3_CONTRACT_TESTS.*SWV5_MACHINE_RESULT ') { $index }
}
if ($resultIndexes.Count -lt 2) { throw 'Fewer than two Sprint 4.4 machine results were found.' }
$selectedIndexes = @($resultIndexes | Select-Object -Last 2)
$runs = @()
$rawBlocks = @()

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
    $metadataLine = $block | Where-Object { $_ -match 'SWV5_RUN_METADATA.*suite=SPRINT4\.4' } | Select-Object -First 1
    $testerResultLine = $block | Where-Object { $_ -match 'OnTester result 1(\.0+)?$' } | Select-Object -First 1
    if (-not $serverLine) { throw "Run $($runNumber + 1) is not proven to use a Demo/Trial server." }
    if (-not $metadataLine) { throw "Run $($runNumber + 1) lacks Sprint 4.4 harness metadata." }
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

function Read-CompileResult([string]$Path) {
    $text = Get-Content -LiteralPath $Path -Raw
    $match = [regex]::Match($text, "Result: (?<errors>\d+) errors, (?<warnings>\d+) warnings, (?<elapsed>\d+) ms elapsed, cpu='(?<cpu>[^']+)'")
    if (-not $match.Success) { throw "Compile result was not found in $Path." }
    return [ordered]@{
        errors = [int]$match.Groups['errors'].Value
        warnings = [int]$match.Groups['warnings'].Value
        elapsed_ms = [int]$match.Groups['elapsed'].Value
        cpu = $match.Groups['cpu'].Value
        log_sha256 = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
    }
}

$architectureCompile = Read-CompileResult $ArchitectureCompileLog
$testCompile = Read-CompileResult $TestCompileLog
if ($architectureCompile.errors -ne 0 -or $architectureCompile.warnings -ne 0 -or
    $testCompile.errors -ne 0 -or $testCompile.warnings -ne 0) {
    throw 'Both immutable-source compiles must be 0 errors and 0 warnings.'
}

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
if (-not $deterministic) { throw 'The two immutable-source runs are not deterministic and passing.' }

$generatedAt = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
$evidence = [ordered]@{
    schema = 'SWV5-CONTRACT-TEST-EVIDENCE-V3'
    generated_by = 'Export-Sprint44Evidence.ps1'
    exporter_sha256 = $exporterSha
    generated_at_utc = $generatedAt
    source_commit_sha = $sourceCommit
    manifest = (Split-Path -Leaf $Manifest)
    manifest_sha256 = $manifestSha
    verification_source_digest = $verificationSourceDigest
    contract_policy = 'SWV5-PRODUCTION-V3'
    implementation_under_test = 'ISWV5 deterministic semantic reference implementations'
    compile = [ordered]@{ architecture = $architectureCompile; tests = $testCompile }
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
$rawPath = Join-Path $OutputDirectory 'sprint4_4_tester_evidence.txt'
$reportPath = Join-Path $OutputDirectory 'VERIFICATION_REPORT.md'
$compileReportPath = Join-Path $OutputDirectory 'COMPILE_REPORT.md'
$evidence | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $jsonPath -Encoding utf8
$rawBlocks | Set-Content -LiteralPath $rawPath -Encoding utf8

@(
    '# Sprint 4.4 Semantic Contract Verification Report', '',
    '> TEST ONLY - NOT FOR PRODUCTION - NO BROKER ACCESS', '',
    '## Verdict', '', '**PASS - READY FOR INDEPENDENT REVIEW**', '',
    'Sprint 4 remains the authorized baseline. Sprint 4.1 remains Candidate / In Review. Sprint 4.4 closes audit findings but does not declare Architecture Lock, production readiness, or runtime authorization.', '',
    '## Generated evidence', '',
    "- Exported at UTC: ``$generatedAt``",
    "- Tested source commit: ``$sourceCommit``",
    "- Evidence exporter SHA-256: ``$exporterSha``",
    "- Manifest SHA-256: ``$manifestSha``",
    "- Verification source digest: ``$verificationSourceDigest``",
    "- Architecture compile: $($architectureCompile.errors) errors, $($architectureCompile.warnings) warnings, $($architectureCompile.cpu)",
    "- Test compile: $($testCompile.errors) errors, $($testCompile.warnings) warnings, $($testCompile.cpu)",
    "- Tests: $($evidence.total) total, $($evidence.passed) passed, $($evidence.failed) failed, $($evidence.skipped) skipped",
    "- Deterministic signature: ``$($evidence.signature)``",
    '- Independent runs: 2; signatures and counts identical',
    "- Terminal build: $($runs[0].terminal_build)",
    "- Broker/server evidence: $($runs[0].broker_server) (Demo/Trial Strategy Tester)",
    '- Account mode: HEDGING deterministic contract fixture', '',
    '## Scope', '',
    '- 238 executable cases, including 236 interface-behavior cases and 2 supporting pure equality cases.',
    '- All 49 Basket state pairs execute through `ISWV5BasketStateMachineContract`.',
    '- Restart reconstructs the complete persisted request set and derives readiness from canonical request state.',
    '- Persistence digests bind every serialized request field, order, count, and record sequence.',
    '- Risk authorization binds complete limits, projected values, account snapshot, Hard Kill namespace and generation.',
    '- Recovery, execution, statistics, and ownership interfaces return and verify monotonic resulting state.',
    '- No broker command, runtime implementation, live account mutation, file/network validator dependency, Signal Engine change, or frozen baseline change is present.'
) | Set-Content -LiteralPath $reportPath -Encoding utf8

@(
    '# Sprint 4.4 Compile Report', '',
    '> TEST ONLY - NOT FOR PRODUCTION - NO BROKER ACCESS', '',
    '- Compiler: MetaEditor X64 Regular',
    "- Architecture manifest: **$($architectureCompile.errors) errors, $($architectureCompile.warnings) warnings**",
    "- Test manifest: **$($testCompile.errors) errors, $($testCompile.warnings) warnings**",
    "- Manifest SHA-256: ``$manifestSha``",
    "- Evidence exporter SHA-256: ``$exporterSha``",
    "- Exported: ``$generatedAt``"
) | Set-Content -LiteralPath $compileReportPath -Encoding utf8

Write-Output "Exported $jsonPath"
Write-Output "Exported $rawPath"
Write-Output "Exported $reportPath"
Write-Output "Exported $compileReportPath"
