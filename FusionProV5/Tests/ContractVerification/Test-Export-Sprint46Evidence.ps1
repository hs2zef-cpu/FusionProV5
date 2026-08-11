# TEST ONLY
# NOT FOR PRODUCTION
# NO BROKER ACCESS
# Offline controlled-fixture tests for Export-Sprint46Evidence.ps1.

[CmdletBinding()]
param(
    [string]$ExporterPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
if ([string]::IsNullOrWhiteSpace($ExporterPath)) { $ExporterPath = Join-Path $scriptDirectory 'Export-Sprint46Evidence.ps1' }
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('SWV5-S46-EXPORT-' + [guid]::NewGuid().ToString('N'))
$passed = 0
$failed = 0
$records = @()

function Write-Utf8([string]$Path, [string]$Text) {
    $parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    Set-Content -LiteralPath $Path -Value $Text -Encoding UTF8
}

function Invoke-CheckedGit([string[]]$Arguments) {
    & git @Arguments | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "fixture git command failed: git $($Arguments -join ' ')" }
}

try {
    if (-not (Test-Path -LiteralPath $ExporterPath -PathType Leaf)) { throw "exporter missing: $ExporterPath" }
    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
    $repo = Join-Path $tempRoot 'repo'
    New-Item -ItemType Directory -Path $repo -Force | Out-Null
    Invoke-CheckedGit @('-C', $repo, 'init', '--quiet')

    $inventory = Join-Path $repo 'FusionProV5\Tests\ContractVerification\TEST_INVENTORY.md'
    $matrix = Join-Path $repo 'FusionProV5\Tests\ContractVerification\TEST_CREDIBILITY_MATRIX.md'
    $manifest = Join-Path $repo 'Manifest.mq5'
    $source = Join-Path $repo 'Source.mqh'
    $inventoryText = @'
| Domain | IDs | Total |
|---|---|---:|
| Fixture | FX-01–FX-05 | 5 |
| **Total** |  | **5** |
'@
    $matrixValid = @'
| Category | Count | Merge-gating evidence |
|---|---:|---|
| `MERGE_GATING_BEHAVIOR` | 1 | YES |
| `STATE_TRANSITION` | 1 | YES |
| `NEGATIVE_FAIL_CLOSED` | 1 | YES |
| `ROUND_TRIP` | 1 | YES |
| `INVARIANT_BEHAVIOR` | 1 | YES |
| `SUPPORTING_PURE_FUNCTION` | 0 | NO |
| `CONFORMANCE_ONLY` | 0 | NO |
| `WEAK_FALSE_POSITIVE` | 0 | NO |
'@
    $matrixMismatch = $matrixValid.Replace('| `INVARIANT_BEHAVIOR` | 1 | YES |', '| `INVARIANT_BEHAVIOR` | 0 | YES |')
    $matrixWeak = $matrixValid.Replace('| `INVARIANT_BEHAVIOR` | 1 | YES |', '| `INVARIANT_BEHAVIOR` | 0 | YES |').Replace('| `WEAK_FALSE_POSITIVE` | 0 | NO |', '| `WEAK_FALSE_POSITIVE` | 1 | NO |')
    Write-Utf8 $inventory $inventoryText
    Write-Utf8 $matrix $matrixValid
    Write-Utf8 $manifest '// fixture manifest'
    Write-Utf8 $source '// fixture verification source'
    Invoke-CheckedGit @('-C', $repo, 'add', '.')
    Invoke-CheckedGit @('-C', $repo, '-c', 'user.name=SWV5 Test', '-c', 'user.email=swv5-test@example.invalid', 'commit', '--quiet', '-m', 'valid fixture')
    $validCommit = (& git -C $repo rev-parse HEAD).Trim()

    Write-Utf8 $matrix $matrixMismatch
    Invoke-CheckedGit @('-C', $repo, 'add', '.')
    Invoke-CheckedGit @('-C', $repo, '-c', 'user.name=SWV5 Test', '-c', 'user.email=swv5-test@example.invalid', 'commit', '--quiet', '-m', 'mismatch fixture')
    $mismatchCommit = (& git -C $repo rev-parse HEAD).Trim()

    Write-Utf8 $matrix $matrixWeak
    Invoke-CheckedGit @('-C', $repo, 'add', '.')
    Invoke-CheckedGit @('-C', $repo, '-c', 'user.name=SWV5 Test', '-c', 'user.email=swv5-test@example.invalid', 'commit', '--quiet', '-m', 'weak fixture')
    $weakCommit = (& git -C $repo rev-parse HEAD).Trim()

    $archLog = Join-Path $tempRoot 'architecture.log'
    $testLog = Join-Path $tempRoot 'tests.log'
    $run1Log = Join-Path $tempRoot 'run1.log'
    $run2Log = Join-Path $tempRoot 'run2.log'
    $compileOk = 'Result: 0 errors, 0 warnings, 100 ms elapsed, cpu=''X64 Regular'''
    $machine = 'SWV5_MACHINE_RESULT {"schema":"SWV5-CONTRACT-TEST-RESULT-V4","contract_policy":"SWV5-PRODUCTION-V4","implementation":"ISWV5-SEMANTIC-REFERENCE","total":5,"passed":5,"failed":0,"skipped":0,"signature":"123456789","deterministic":true}'
    $runBase = @"
SWV5_EVIDENCE_CONTEXT terminal_build=5555 demo_server=Fixture-Demo account_mode=HEDGING run_timestamp=2026-08-11T10:00:00+07:00 tester=StrategyTester
SWV5_RUN_METADATA suite=SPRINT4.6-FULL fixture_account_mode=HEDGING fixture_broker=TEST-BROKER fixture_server=TEST-SERVER broker_access=false
$machine
SWV5_ONTESTER_SUCCESS result=1
"@

    function Set-BaselineFiles {
        Write-Utf8 $archLog $compileOk
        Write-Utf8 $testLog $compileOk
        Write-Utf8 $run1Log $runBase
        Write-Utf8 $run2Log $runBase.Replace('10:00:00', '10:01:00')
    }

    function Checkout-Fixture([string]$Commit) {
        Invoke-CheckedGit @('-C', $repo, 'checkout', '--quiet', '--detach', $Commit)
    }

    function Run-Case([int]$Number, [string]$Name, [bool]$ExpectSuccess, [string]$Commit, [scriptblock]$Arrange, [string]$SuppliedSha = '') {
        Checkout-Fixture $Commit
        Set-BaselineFiles
        & $Arrange
        if ([string]::IsNullOrWhiteSpace($SuppliedSha)) { $SuppliedSha = $Commit }
        $arguments = @(
            '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $ExporterPath,
            '-ArchitectureCompileLog', $archLog,
            '-TestCompileLog', $testLog,
            '-Run1Log', $run1Log,
            '-Run2Log', $run2Log,
            '-TestedSourceSha', $SuppliedSha,
            '-RepositoryRoot', $repo,
            '-ExpectedTerminalBuild', '5555',
            '-ExpectedDemoServerPattern', '^Fixture-Demo$',
            '-InventoryPath', $inventory,
            '-CredibilityMatrixPath', $matrix,
            '-ManifestPath', $manifest,
            '-VerificationSourcePaths', $source,
            '-ValidationOnly'
        )
        $savedPreference = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        & powershell.exe @arguments *> (Join-Path $tempRoot "case-$Number.out")
        $caseExitCode = $LASTEXITCODE
        $ErrorActionPreference = $savedPreference
        $actualSuccess = $caseExitCode -eq 0
        $casePassed = $actualSuccess -eq $ExpectSuccess
        if ($casePassed) { $script:passed++ } else { $script:failed++ }
        $script:records += [pscustomobject]@{ id = ('EXP-{0:d2}' -f $Number); name = $Name; passed = $casePassed; expected_success = $ExpectSuccess; actual_success = $actualSuccess }
    }

    Run-Case 1 'two valid matching runs' $true $validCommit { }
    Run-Case 2 'Run 1 failure count' $false $validCommit { Write-Utf8 $run1Log $runBase.Replace('"passed":5,"failed":0', '"passed":4,"failed":1') }
    Run-Case 3 'skipped count' $false $validCommit { Write-Utf8 $run1Log $runBase.Replace('"total":5,"passed":5,"failed":0,"skipped":0', '"total":5,"passed":4,"failed":0,"skipped":1') }
    Run-Case 4 'mismatched signatures' $false $validCommit { Write-Utf8 $run2Log $runBase.Replace('"signature":"123456789"', '"signature":"987654321"').Replace('10:00:00', '10:01:00') }
    Run-Case 5 'mismatched totals' $false $validCommit { Write-Utf8 $run2Log $runBase.Replace('"total":5,"passed":5', '"total":6,"passed":6').Replace('10:00:00', '10:01:00') }
    Run-Case 6 'missing machine result' $false $validCommit { Write-Utf8 $run1Log $runBase.Replace($machine, '') }
    Run-Case 7 'duplicate machine result' $false $validCommit { Write-Utf8 $run1Log ($runBase + "`n" + $machine) }
    Run-Case 8 'wrong source SHA' $false $validCommit { } '0000000000000000000000000000000000000000'
    Run-Case 9 'compile warning' $false $validCommit { Write-Utf8 $testLog 'Result: 0 errors, 1 warnings, 100 ms elapsed' }
    Run-Case 10 'compile error' $false $validCommit { Write-Utf8 $archLog 'Result: 1 errors, 0 warnings, 100 ms elapsed' }
    Run-Case 11 'credibility sum mismatch' $false $mismatchCommit { }
    Run-Case 12 'weak false-positive nonzero' $false $weakCommit { }
    Run-Case 13 'missing OnTester success' $false $validCommit { Write-Utf8 $run1Log $runBase.Replace('SWV5_ONTESTER_SUCCESS result=1', '') }
    Run-Case 14 'missing Demo tester identity' $false $validCommit { Write-Utf8 $run1Log $runBase.Replace('demo_server=Fixture-Demo', 'demo_server=Fixture-Live') }
    Run-Case 15 'explicit input missing' $false $validCommit { Remove-Item -LiteralPath $run2Log -Force }

    [pscustomobject]@{ total = 15; passed = $passed; failed = $failed; skipped = 0; cases = $records } | ConvertTo-Json -Depth 5
    if ($failed -ne 0) { exit 1 }
    exit 0
} finally {
    if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force }
}
