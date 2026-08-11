# TEST ONLY
# NOT FOR PRODUCTION
# NO BROKER ACCESS
# Explicit-input, offline Sprint 4.6 evidence validator/exporter.

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ArchitectureCompileLog,
    [Parameter(Mandatory = $true)][string]$TestCompileLog,
    [Parameter(Mandatory = $true)][string]$Run1Log,
    [Parameter(Mandatory = $true)][string]$Run2Log,
    [Parameter(Mandatory = $true)][ValidatePattern('^[0-9a-fA-F]{40}$')][string]$TestedSourceSha,
    [Parameter(Mandatory = $true)][string]$RepositoryRoot,
    [Parameter(Mandatory = $true)][string]$ExpectedTerminalBuild,
    [Parameter(Mandatory = $true)][string]$ExpectedDemoServerPattern,
    [string]$InventoryPath,
    [string]$CredibilityMatrixPath,
    [string]$ManifestPath,
    [string[]]$VerificationSourcePaths,
    [string]$OutputDirectory,
    [switch]$ValidationOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Fail([string]$Message) {
    throw "SPRINT46_EXPORT_VALIDATION_FAILED: $Message"
}

function Resolve-RequiredFile([string]$Path, [string]$Label) {
    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        Fail "$Label is missing: $Path"
    }
    return (Resolve-Path -LiteralPath $Path).Path
}

function Invoke-Git([string[]]$Arguments) {
    $result = & git @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) {
        Fail ("git {0} failed: {1}" -f ($Arguments -join ' '), ($result -join [Environment]::NewLine))
    }
    return (($result | ForEach-Object { "$_" }) -join "`n").Trim()
}

function Get-RepositoryRelativePath([string]$Root, [string]$Path) {
    $rootFull = [IO.Path]::GetFullPath($Root).TrimEnd('\', '/')
    $pathFull = [IO.Path]::GetFullPath($Path)
    if (-not $pathFull.StartsWith($rootFull + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        Fail "tracked input is outside repository root: $pathFull"
    }
    return $pathFull.Substring($rootFull.Length + 1).Replace('\', '/')
}

function Assert-FileMatchesCommit([string]$Root, [string]$Path, [string]$Commit) {
    $relative = Get-RepositoryRelativePath $Root $Path
    $expectedBlob = Invoke-Git @('-C', $Root, 'rev-parse', "${Commit}:$relative")
    $actualBlob = Invoke-Git @('-C', $Root, 'hash-object', '--', $Path)
    if ($actualBlob -ne $expectedBlob) {
        Fail "$relative does not match tested source commit $Commit"
    }
    return $relative
}

function Get-Sha256([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Assert-CleanCompile([string]$Path, [string]$Label) {
    $text = Get-Content -LiteralPath $Path -Raw
    $results = [regex]::Matches($text, 'Result:\s*(\d+) errors,\s*(\d+) warnings')
    if ($results.Count -ne 1) {
        Fail "$Label compile log must contain exactly one Result line"
    }
    if ([int]$results[0].Groups[1].Value -ne 0 -or [int]$results[0].Groups[2].Value -ne 0) {
        Fail "$Label compile is not 0 errors / 0 warnings"
    }
}

function Read-Run([string]$Path, [string]$Label) {
    $text = Get-Content -LiteralPath $Path -Raw
    $matches = [regex]::Matches($text, 'SWV5_MACHINE_RESULT\s+(\{[^\r\n]+\})')
    if ($matches.Count -ne 1) {
        Fail "$Label must contain exactly one final SWV5_MACHINE_RESULT"
    }
    try {
        $machine = $matches[0].Groups[1].Value | ConvertFrom-Json
    } catch {
        Fail "$Label contains invalid machine-result JSON"
    }
    if ($text -notmatch 'SWV5_RUN_METADATA\s+suite=SPRINT4\.6-FULL(?:\s|$)') {
        Fail "$Label is not an intentional Sprint 4.6 full-suite run"
    }
    if ($text -notmatch 'SWV5_ONTESTER_SUCCESS\s+result=1(?:\s|$)') {
        Fail "$Label does not contain OnTester success"
    }
    $contexts = [regex]::Matches($text, 'SWV5_EVIDENCE_CONTEXT\s+terminal_build=(\d+)\s+demo_server=([^\s]+)\s+account_mode=([^\s]+)\s+run_timestamp=([^\s]+)\s+tester=([^\s]+)')
    if ($contexts.Count -ne 1) {
        Fail "$Label must contain exactly one explicit evidence context"
    }
    $context = $contexts[0]
    if ($context.Groups[1].Value -ne $ExpectedTerminalBuild) {
        Fail "$Label terminal build differs from the expected build"
    }
    $server = $context.Groups[2].Value
    if ($server -notmatch '(?i)(demo|trial)' -or $server -notmatch $ExpectedDemoServerPattern) {
        Fail "$Label does not identify the expected Demo/Trial server"
    }
    if ($context.Groups[3].Value -ne 'HEDGING') {
        Fail "$Label account-mode fixture is not HEDGING"
    }
    if ($context.Groups[5].Value -ne 'StrategyTester') {
        Fail "$Label is not identified as Strategy Tester evidence"
    }
    $timestampValue = [datetime]::MinValue
    if (-not [datetime]::TryParse($context.Groups[4].Value, [ref]$timestampValue)) {
        Fail "$Label run timestamp is invalid"
    }
    foreach ($field in @('total', 'passed', 'failed', 'skipped', 'signature', 'deterministic')) {
        if ($null -eq $machine.PSObject.Properties[$field]) {
            Fail "$Label machine result lacks $field"
        }
    }
    if ([int]$machine.failed -ne 0 -or [int]$machine.skipped -ne 0 -or [int]$machine.passed -ne [int]$machine.total) {
        Fail "$Label is not an all-pass, zero-skip run"
    }
    if (-not [bool]$machine.deterministic) {
        Fail "$Label reports nondeterministic execution"
    }
    return [pscustomobject]@{
        Machine = $machine
        TerminalBuild = $context.Groups[1].Value
        DemoServer = $server
        AccountMode = $context.Groups[3].Value
        Timestamp = $context.Groups[4].Value
        Sha256 = Get-Sha256 $Path
    }
}

try {
    $repo = (Resolve-Path -LiteralPath $RepositoryRoot).Path
    $architectureLog = Resolve-RequiredFile $ArchitectureCompileLog 'architecture compile log'
    $testLog = Resolve-RequiredFile $TestCompileLog 'test compile log'
    $run1Path = Resolve-RequiredFile $Run1Log 'Run 1 log'
    $run2Path = Resolve-RequiredFile $Run2Log 'Run 2 log'

    if ($run1Path -eq $run2Path) { Fail 'Run 1 and Run 2 must be two explicit, distinct inputs' }
    Invoke-Git @('-C', $repo, 'cat-file', '-e', "${TestedSourceSha}^{commit}") | Out-Null
    $resolvedCommit = Invoke-Git @('-C', $repo, 'rev-parse', $TestedSourceSha)

    if (-not $InventoryPath) { $InventoryPath = Join-Path $repo 'FusionProV5\Tests\ContractVerification\TEST_INVENTORY.md' }
    if (-not $CredibilityMatrixPath) { $CredibilityMatrixPath = Join-Path $repo 'FusionProV5\Tests\ContractVerification\TEST_CREDIBILITY_MATRIX.md' }
    if (-not $ManifestPath) { $ManifestPath = Join-Path $repo 'SOMWANG_XAU_M15_FUSION_PRO_V5_SPRINT4_3_CONTRACT_TESTS.mq5' }
    if (-not $VerificationSourcePaths -or $VerificationSourcePaths.Count -eq 0) {
        $VerificationSourcePaths = @(
            (Join-Path $repo 'FusionProV5\Tests\ContractVerification\SW_V5_ContractTestRunner.mqh'),
            (Join-Path $repo 'FusionProV5\Tests\ContractVerification\SW_V5_InterfaceContractImplementations.mqh'),
            (Join-Path $repo 'FusionProV5\Tests\ContractVerification\SW_V5_ReferenceValidators.mqh'),
            (Join-Path $repo 'FusionProV5\Tests\ContractVerification\SW_V5_TestFixtures.mqh')
        )
    }

    $inventory = Resolve-RequiredFile $InventoryPath 'test inventory'
    $matrix = Resolve-RequiredFile $CredibilityMatrixPath 'credibility matrix'
    $manifest = Resolve-RequiredFile $ManifestPath 'test manifest'
    Assert-FileMatchesCommit $repo $inventory $resolvedCommit | Out-Null
    Assert-FileMatchesCommit $repo $matrix $resolvedCommit | Out-Null
    Assert-FileMatchesCommit $repo $manifest $resolvedCommit | Out-Null

    $sourceEntries = @()
    foreach ($source in $VerificationSourcePaths) {
        $resolvedSource = Resolve-RequiredFile $source 'verification source'
        $relativeSource = Assert-FileMatchesCommit $repo $resolvedSource $resolvedCommit
        $sourceEntries += [pscustomobject]@{ path = $relativeSource; sha256 = Get-Sha256 $resolvedSource }
    }
    $sourceEntries = @($sourceEntries | Sort-Object path)

    Assert-CleanCompile $architectureLog 'architecture'
    Assert-CleanCompile $testLog 'test'
    $run1 = Read-Run $run1Path 'Run 1'
    $run2 = Read-Run $run2Path 'Run 2'

    if ([int]$run1.Machine.total -ne [int]$run2.Machine.total) { Fail 'run totals differ' }
    if ([string]$run1.Machine.signature -ne [string]$run2.Machine.signature) { Fail 'run signatures differ' }

    $inventoryText = Get-Content -LiteralPath $inventory -Raw
    $inventoryMatch = [regex]::Match($inventoryText, '(?m)^\|\s*\*\*Total\*\*\s*\|\s*\|\s*\*\*(\d+)\*\*')
    if (-not $inventoryMatch.Success) { Fail 'committed inventory total is missing or ambiguous' }
    $inventoryTotal = [int]$inventoryMatch.Groups[1].Value
    if ($inventoryTotal -ne [int]$run1.Machine.total) { Fail 'run total does not match committed inventory total' }

    $matrixText = Get-Content -LiteralPath $matrix -Raw
    $categoryNames = @('MERGE_GATING_BEHAVIOR','STATE_TRANSITION','NEGATIVE_FAIL_CLOSED','ROUND_TRIP','INVARIANT_BEHAVIOR','SUPPORTING_PURE_FUNCTION','CONFORMANCE_ONLY','WEAK_FALSE_POSITIVE')
    $categories = [ordered]@{}
    foreach ($category in $categoryNames) {
        $categoryMatch = [regex]::Match($matrixText, "(?m)^\|\s*``$category``\s*\|\s*(\d+)\s*\|")
        if (-not $categoryMatch.Success) { Fail "credibility category $category is missing" }
        $categories[$category] = [int]$categoryMatch.Groups[1].Value
    }
    $categorySum = ($categories.Values | Measure-Object -Sum).Sum
    if ($categorySum -ne $inventoryTotal) { Fail 'credibility category sum does not equal executable total' }
    if ($categories['WEAK_FALSE_POSITIVE'] -ne 0) { Fail 'WEAK_FALSE_POSITIVE must be zero' }

    $sourceDigestMaterial = ($sourceEntries | ForEach-Object { "$($_.path)=$($_.sha256)" }) -join "`n"
    $sha256 = [Security.Cryptography.SHA256]::Create()
    try {
        $verificationDigest = ([BitConverter]::ToString($sha256.ComputeHash([Text.Encoding]::UTF8.GetBytes($sourceDigestMaterial)))).Replace('-', '').ToLowerInvariant()
    } finally {
        $sha256.Dispose()
    }
    $provenance = [ordered]@{
        schema = 'SWV5-SPRINT46-EVIDENCE-V1'
        verdict = 'PASS'
        tested_source_sha = $resolvedCommit
        exporter_sha256 = Get-Sha256 $PSCommandPath
        manifest_sha256 = Get-Sha256 $manifest
        verification_source_digest = $verificationDigest
        architecture_compile_log_sha256 = Get-Sha256 $architectureLog
        test_compile_log_sha256 = Get-Sha256 $testLog
        raw_run_1_sha256 = $run1.Sha256
        raw_run_2_sha256 = $run2.Sha256
        total = $inventoryTotal
        passed = [int]$run1.Machine.passed
        failed = 0
        skipped = 0
        deterministic_signature = [string]$run1.Machine.signature
        terminal_build = $run1.TerminalBuild
        demo_server = $run1.DemoServer
        account_mode = $run1.AccountMode
        run_1_timestamp = $run1.Timestamp
        run_2_timestamp = $run2.Timestamp
        credibility = $categories
        verification_sources = $sourceEntries
    }

    if (-not $ValidationOnly) {
        if ([string]::IsNullOrWhiteSpace($OutputDirectory)) { Fail 'OutputDirectory is required unless ValidationOnly is set' }
        $output = [IO.Path]::GetFullPath($OutputDirectory)
        if (-not (Test-Path -LiteralPath $output)) { New-Item -ItemType Directory -Path $output -Force | Out-Null }
        $provenance | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $output 'contract_test_results.json') -Encoding UTF8
        @("# Sprint 4.6 Verification Report", '', 'Verdict: PASS', "Tested source: $resolvedCommit", "Tests: $inventoryTotal / $inventoryTotal passed", "Signature: $($run1.Machine.signature)", "Exporter SHA-256: $($provenance.exporter_sha256)") | Set-Content -LiteralPath (Join-Path $output 'VERIFICATION_REPORT.md') -Encoding UTF8
        @("# Sprint 4.6 Compile Report", '', 'Architecture: 0 errors / 0 warnings', 'Contract tests: 0 errors / 0 warnings', "Architecture log SHA-256: $($provenance.architecture_compile_log_sha256)", "Test log SHA-256: $($provenance.test_compile_log_sha256)") | Set-Content -LiteralPath (Join-Path $output 'COMPILE_REPORT.md') -Encoding UTF8
        @('=== RUN 1 ===', (Get-Content -LiteralPath $run1Path -Raw), '=== RUN 2 ===', (Get-Content -LiteralPath $run2Path -Raw)) | Set-Content -LiteralPath (Join-Path $output 'sprint4_6_tester_evidence.txt') -Encoding UTF8
    }

    [pscustomobject]$provenance | ConvertTo-Json -Depth 8
    exit 0
} catch {
    Write-Error $_.Exception.Message
    exit 1
}
