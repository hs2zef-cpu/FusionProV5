# TEST ONLY
# NOT FOR PRODUCTION
# NO BROKER ACCESS
# Deterministic, explicit-input Sprint 4.7 evidence exporter and Git-blob verifier.

[CmdletBinding()]
param(
    [ValidateSet('Generate','IndexManifest','VerifyIndex','VerifyCommit')]
    [string]$Mode = 'Generate',
    [Parameter(Mandatory = $true)][string]$RepositoryRoot,
    [string]$OutputDirectory,
    [string]$ArchitectureCompileLog,
    [string]$TestCompileLog,
    [string]$Run1Log,
    [string]$Run2Log,
    [ValidatePattern('^[0-9a-fA-F]{40}$')][string]$TestedSourceSha,
    [string]$ExpectedTerminalBuild,
    [string]$ExpectedDemoServerPattern,
    [ValidatePattern('^[0-9a-fA-F]{64}$')][string]$ExpectedArchitectureCompileLogSha256,
    [ValidatePattern('^[0-9a-fA-F]{64}$')][string]$ExpectedTestCompileLogSha256,
    [ValidatePattern('^[0-9a-fA-F]{64}$')][string]$ExpectedRun1LogSha256,
    [ValidatePattern('^[0-9a-fA-F]{64}$')][string]$ExpectedRun2LogSha256,
    [string]$InventoryPath,
    [string]$CredibilityMatrixPath,
    [string]$ManifestPath,
    [string[]]$VerificationSourcePaths,
    [string[]]$EvidencePaths,
    [string]$EvidenceManifestPath,
    [ValidatePattern('^[0-9a-fA-F]{40}$')][string]$EvidenceCommitSha
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$Utf8NoBom = [Text.UTF8Encoding]::new($false)
$Utf8Strict = [Text.UTF8Encoding]::new($false, $true)

function Fail([string]$Message) {
    throw "SPRINT47_EXPORT_VALIDATION_FAILED: $Message"
}

function Require-Value([string]$Value, [string]$Label) {
    if ([string]::IsNullOrWhiteSpace($Value)) { Fail "$Label is required for mode $Mode" }
}

function Resolve-RequiredFile([string]$Path, [string]$Label) {
    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        Fail "$Label is missing: $Path"
    }
    return (Resolve-Path -LiteralPath $Path).Path
}

function Invoke-GitText([string[]]$Arguments) {
    $result = & git @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) {
        Fail ("git {0} failed: {1}" -f ($Arguments -join ' '), ($result -join "`n"))
    }
    return (($result | ForEach-Object { "$_" }) -join "`n").Trim()
}

function Get-RepositoryRelativePath([string]$Root, [string]$Path) {
    $rootFull = [IO.Path]::GetFullPath($Root).TrimEnd('\', '/')
    $pathFull = [IO.Path]::GetFullPath($Path)
    if (-not $pathFull.StartsWith($rootFull + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        Fail "repository content is outside repository root: $pathFull"
    }
    return $pathFull.Substring($rootFull.Length + 1).Replace('\', '/')
}

function Get-Sha256Bytes([byte[]]$Bytes) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        return ([BitConverter]::ToString($sha.ComputeHash($Bytes))).Replace('-', '').ToLowerInvariant()
    } finally {
        $sha.Dispose()
    }
}

function Get-FileSha256([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-GitBlobBytes([string]$Root, [string]$Revision, [string]$RelativePath) {
    $spec = if ($Revision -eq 'INDEX') { ":$RelativePath" } else { "${Revision}:$RelativePath" }
    $blobId = Invoke-GitText @('-C', $Root, 'rev-parse', $spec)
    if ($blobId -notmatch '^[0-9a-fA-F]{40,64}$') { Fail "invalid Git blob identity for $spec" }

    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = 'git.exe'
    $start.Arguments = "-C `"$Root`" cat-file blob $blobId"
    $start.UseShellExecute = $false
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    if (-not $process.Start()) { Fail "cannot start git cat-file for $spec" }
    $memory = [IO.MemoryStream]::new()
    try {
        $process.StandardOutput.BaseStream.CopyTo($memory)
        $errorText = $process.StandardError.ReadToEnd()
        $process.WaitForExit()
        if ($process.ExitCode -ne 0) { Fail "git cat-file failed for $spec`: $errorText" }
        return ,$memory.ToArray()
    } finally {
        $memory.Dispose()
        $process.Dispose()
    }
}

function Get-GitBlobSha256([string]$Root, [string]$Revision, [string]$RelativePath) {
    return Get-Sha256Bytes (Get-GitBlobBytes $Root $Revision $RelativePath)
}

function Get-GitBlobText([string]$Root, [string]$Revision, [string]$RelativePath) {
    try {
        return $Utf8Strict.GetString((Get-GitBlobBytes $Root $Revision $RelativePath))
    } catch {
        Fail "$Revision`:$RelativePath is not valid UTF-8 text"
    }
}

function Normalize-Lf([string]$Text) {
    return ($Text -replace "`r`n", "`n" -replace "`r", "`n")
}

function Write-DeterministicText([string]$Path, [string]$Text) {
    $parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    $canonical = (Normalize-Lf $Text).TrimEnd("`n") + "`n"
    [IO.File]::WriteAllText($Path, $canonical, $Utf8NoBom)
}

function Assert-ExpectedRawHash([string]$Path, [string]$Expected, [string]$Label) {
    Require-Value $Expected "$Label expected SHA-256"
    $actual = Get-FileSha256 $Path
    if ($actual -ne $Expected.ToLowerInvariant()) { Fail "$Label raw-input SHA-256 mismatch" }
    return $actual
}

function Assert-CleanCompile([string]$Path, [string]$Label) {
    $text = Get-Content -LiteralPath $Path -Raw
    $matches = [regex]::Matches($text, 'Result:\s*(\d+) errors,\s*(\d+) warnings')
    if ($matches.Count -ne 1) { Fail "$Label compile log must contain exactly one Result line" }
    if ([int]$matches[0].Groups[1].Value -ne 0 -or [int]$matches[0].Groups[2].Value -ne 0) {
        Fail "$Label compile is not 0 errors / 0 warnings"
    }
}

function Read-Run([string]$Path, [string]$Label, [string]$RawSha) {
    $text = Get-Content -LiteralPath $Path -Raw
    $machineMatches = [regex]::Matches($text, 'SWV5_MACHINE_RESULT\s+(\{[^\r\n]+\})')
    if ($machineMatches.Count -ne 1) { Fail "$Label must contain exactly one final SWV5_MACHINE_RESULT" }
    try { $machine = $machineMatches[0].Groups[1].Value | ConvertFrom-Json } catch { Fail "$Label machine result is invalid JSON" }
    if ($text -notmatch 'SWV5_RUN_METADATA\s+suite=SPRINT4\.7-FULL(?:\s|$)') { Fail "$Label is not an intentional Sprint 4.7 full-suite run" }
    if ($text -notmatch 'SWV5_ONTESTER_SUCCESS\s+result=1(?:\s|$)') { Fail "$Label does not contain OnTester success" }
    $contexts = [regex]::Matches($text, 'SWV5_EVIDENCE_CONTEXT\s+terminal_build=(\d+)\s+demo_server=([^\s]+)\s+account_mode=([^\s]+)\s+run_timestamp=([^\s]+)\s+tester=([^\s]+)')
    if ($contexts.Count -ne 1) { Fail "$Label must contain exactly one evidence context" }
    $context = $contexts[0]
    if ($context.Groups[1].Value -ne $ExpectedTerminalBuild) { Fail "$Label terminal build differs from expected" }
    if ($context.Groups[2].Value -notmatch '(?i)(demo|trial)' -or $context.Groups[2].Value -notmatch $ExpectedDemoServerPattern) {
        Fail "$Label does not identify the expected Demo/Trial server"
    }
    if ($context.Groups[3].Value -ne 'HEDGING') { Fail "$Label account mode is not HEDGING" }
    if ($context.Groups[5].Value -ne 'StrategyTester') { Fail "$Label is not Strategy Tester evidence" }
    $timestamp = [datetime]::MinValue
    if (-not [datetime]::TryParse($context.Groups[4].Value, [ref]$timestamp)) { Fail "$Label timestamp is invalid" }
    foreach ($field in @('total','passed','failed','skipped','signature','deterministic')) {
        if ($null -eq $machine.PSObject.Properties[$field]) { Fail "$Label machine result lacks $field" }
    }
    if ([int]$machine.failed -ne 0 -or [int]$machine.skipped -ne 0 -or [int]$machine.passed -ne [int]$machine.total) {
        Fail "$Label is not all-pass with zero skips"
    }
    if (-not [bool]$machine.deterministic) { Fail "$Label is nondeterministic" }
    return [pscustomobject]@{
        Machine = $machine
        TerminalBuild = $context.Groups[1].Value
        DemoServer = $context.Groups[2].Value
        AccountMode = $context.Groups[3].Value
        Timestamp = $context.Groups[4].Value
        RawSha256 = $RawSha
        Text = Normalize-Lf $text
    }
}

function Get-DefaultEvidencePaths([string]$Output) {
    return @(
        (Join-Path $Output 'contract_test_results.json'),
        (Join-Path $Output 'VERIFICATION_REPORT.md'),
        (Join-Path $Output 'COMPILE_REPORT.md'),
        (Join-Path $Output 'sprint4_7_tester_evidence.txt')
    )
}

function Read-BlobManifest([string]$Root, [string]$Revision, [string]$RelativePath) {
    try { $manifest = (Get-GitBlobText $Root $Revision $RelativePath) | ConvertFrom-Json } catch { Fail "evidence blob manifest is invalid JSON" }
    if ($manifest.schema -ne 'SWV5-SPRINT47-BLOB-MANIFEST-V1') { Fail 'evidence blob manifest schema mismatch' }
    if ($manifest.hash_authority -ne 'GIT_BLOB_BYTES_SHA256') { Fail 'evidence blob hash authority is ambiguous' }
    if ($manifest.self_hash_policy -ne 'MANIFEST_EXCLUDED') { Fail 'evidence blob manifest is circular' }
    if ($null -eq $manifest.evidence_files -or @($manifest.evidence_files).Count -eq 0) { Fail 'evidence blob manifest has no evidence files' }
    return $manifest
}

function Verify-BlobManifest([string]$Root, [string]$Revision, [object]$Manifest) {
    foreach ($entry in @($Manifest.evidence_files)) {
        if ($entry.path -match '(^|/)evidence_blob_manifest\.json$') { Fail 'manifest must not hash itself' }
        if ([string]$entry.sha256 -notmatch '^[0-9a-f]{64}$') { Fail "invalid claimed repository hash for $($entry.path)" }
        $actual = Get-GitBlobSha256 $Root $Revision ([string]$entry.path)
        if ($actual -ne [string]$entry.sha256) { Fail "repository blob SHA-256 mismatch for $($entry.path)" }
    }
}

try {
    $repo = (Resolve-Path -LiteralPath $RepositoryRoot).Path
    Invoke-GitText @('-C', $repo, 'rev-parse', '--is-inside-work-tree') | Out-Null

    if ($Mode -eq 'Generate') {
        Require-Value $OutputDirectory 'OutputDirectory'
        Require-Value $ArchitectureCompileLog 'ArchitectureCompileLog'
        Require-Value $TestCompileLog 'TestCompileLog'
        Require-Value $Run1Log 'Run1Log'
        Require-Value $Run2Log 'Run2Log'
        Require-Value $TestedSourceSha 'TestedSourceSha'
        Require-Value $ExpectedTerminalBuild 'ExpectedTerminalBuild'
        Require-Value $ExpectedDemoServerPattern 'ExpectedDemoServerPattern'

        $resolvedCommit = Invoke-GitText @('-C', $repo, 'rev-parse', "${TestedSourceSha}^{commit}")
        $architectureLog = Resolve-RequiredFile $ArchitectureCompileLog 'architecture compile log'
        $testLog = Resolve-RequiredFile $TestCompileLog 'test compile log'
        $run1Path = Resolve-RequiredFile $Run1Log 'Run 1 log'
        $run2Path = Resolve-RequiredFile $Run2Log 'Run 2 log'
        if ($run1Path -eq $run2Path) { Fail 'Run 1 and Run 2 must be distinct explicit inputs' }

        $rawArch = Assert-ExpectedRawHash $architectureLog $ExpectedArchitectureCompileLogSha256 'architecture compile log'
        $rawTest = Assert-ExpectedRawHash $testLog $ExpectedTestCompileLogSha256 'test compile log'
        $rawRun1 = Assert-ExpectedRawHash $run1Path $ExpectedRun1LogSha256 'Run 1 log'
        $rawRun2 = Assert-ExpectedRawHash $run2Path $ExpectedRun2LogSha256 'Run 2 log'
        Assert-CleanCompile $architectureLog 'architecture'
        Assert-CleanCompile $testLog 'test'
        $run1 = Read-Run $run1Path 'Run 1' $rawRun1
        $run2 = Read-Run $run2Path 'Run 2' $rawRun2
        if ([int]$run1.Machine.total -ne [int]$run2.Machine.total) { Fail 'run totals differ' }
        if ([string]$run1.Machine.signature -ne [string]$run2.Machine.signature) { Fail 'run signatures differ' }

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

        $inventoryRelative = Get-RepositoryRelativePath $repo (Resolve-RequiredFile $InventoryPath 'test inventory')
        $matrixRelative = Get-RepositoryRelativePath $repo (Resolve-RequiredFile $CredibilityMatrixPath 'credibility matrix')
        $manifestRelative = Get-RepositoryRelativePath $repo (Resolve-RequiredFile $ManifestPath 'test manifest')
        $exporterRelative = Get-RepositoryRelativePath $repo $PSCommandPath
        $inventoryText = Get-GitBlobText $repo $resolvedCommit $inventoryRelative
        $matrixText = Get-GitBlobText $repo $resolvedCommit $matrixRelative
        Get-GitBlobBytes $repo $resolvedCommit $manifestRelative | Out-Null
        Get-GitBlobBytes $repo $resolvedCommit $exporterRelative | Out-Null

        $inventoryMatch = [regex]::Match($inventoryText, '(?m)^\|\s*\*\*Total\*\*\s*\|\s*\|\s*\*\*(\d+)\*\*')
        if (-not $inventoryMatch.Success) { Fail 'inventory total is missing or ambiguous' }
        $inventoryTotal = [int]$inventoryMatch.Groups[1].Value
        if ($inventoryTotal -ne [int]$run1.Machine.total) { Fail 'run total does not match inventory total' }

        $categoryNames = @('MERGE_GATING_BEHAVIOR','STATE_TRANSITION','NEGATIVE_FAIL_CLOSED','ROUND_TRIP','INVARIANT_BEHAVIOR','SUPPORTING_PURE_FUNCTION','CONFORMANCE_ONLY','WEAK_FALSE_POSITIVE')
        $categories = [ordered]@{}
        foreach ($category in $categoryNames) {
            $match = [regex]::Match($matrixText, "(?m)^\|\s*``$category``\s*\|\s*(\d+)\s*\|")
            if (-not $match.Success) { Fail "credibility category $category is missing" }
            $categories[$category] = [int]$match.Groups[1].Value
        }
        if (($categories.Values | Measure-Object -Sum).Sum -ne $inventoryTotal) { Fail 'credibility category sum does not equal inventory total' }
        if ($categories['WEAK_FALSE_POSITIVE'] -ne 0) { Fail 'WEAK_FALSE_POSITIVE must be zero' }

        $sources = @()
        foreach ($sourcePath in $VerificationSourcePaths) {
            $relative = Get-RepositoryRelativePath $repo (Resolve-RequiredFile $sourcePath 'verification source')
            $sources += [pscustomobject][ordered]@{ path = $relative; git_blob_sha256 = Get-GitBlobSha256 $repo $resolvedCommit $relative }
        }
        $sources = @($sources | Sort-Object path)
        $digestMaterial = ($sources | ForEach-Object { "$($_.path)=$($_.git_blob_sha256)" }) -join "`n"
        $verificationDigest = Get-Sha256Bytes $Utf8NoBom.GetBytes($digestMaterial)

        $result = [ordered]@{
            schema = 'SWV5-SPRINT47-EVIDENCE-V1'
            verdict = 'PASS'
            tested_source_sha = $resolvedCommit
            hash_authority = 'COMMITTED_GIT_BLOB_CONTENT'
            raw_input_hash_authority = 'EXACT_EXTERNAL_FILE_BYTES'
            line_endings = 'LF'
            final_newline = 'EXACTLY_ONE'
            repository_hash_manifest = 'evidence_blob_manifest.json'
            exporter_git_blob_sha256 = Get-GitBlobSha256 $repo $resolvedCommit $exporterRelative
            test_manifest_git_blob_sha256 = Get-GitBlobSha256 $repo $resolvedCommit $manifestRelative
            verification_source_digest = $verificationDigest
            raw_inputs = [ordered]@{
                architecture_compile_log_sha256 = $rawArch
                test_compile_log_sha256 = $rawTest
                run_1_sha256 = $rawRun1
                run_2_sha256 = $rawRun2
            }
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
            verification_sources = $sources
        }

        $output = [IO.Path]::GetFullPath($OutputDirectory)
        Write-DeterministicText (Join-Path $output 'contract_test_results.json') ($result | ConvertTo-Json -Depth 10)
        Write-DeterministicText (Join-Path $output 'VERIFICATION_REPORT.md') (@(
            '# Sprint 4.7 Verification Report', '', 'Verdict: PASS', "Tested source: $resolvedCommit",
            "Tests: $inventoryTotal / $inventoryTotal passed", "Signature: $($run1.Machine.signature)",
            'Repository hash authority: committed Git blob bytes (SHA-256)',
            'Raw input hash authority: exact external file bytes (SHA-256)'
        ) -join "`n")
        Write-DeterministicText (Join-Path $output 'COMPILE_REPORT.md') (@(
            '# Sprint 4.7 Compile Report', '', 'Architecture: 0 errors / 0 warnings',
            'Contract tests: 0 errors / 0 warnings', "Raw architecture log SHA-256: $rawArch",
            "Raw test log SHA-256: $rawTest"
        ) -join "`n")
        Write-DeterministicText (Join-Path $output 'sprint4_7_tester_evidence.txt') (@(
            '=== RUN 1 RAW INPUT ===', $run1.Text.TrimEnd("`n"),
            '=== RUN 2 RAW INPUT ===', $run2.Text.TrimEnd("`n")
        ) -join "`n")
        [pscustomobject]$result | ConvertTo-Json -Depth 10
    }
    elseif ($Mode -eq 'IndexManifest') {
        Require-Value $OutputDirectory 'OutputDirectory'
        Require-Value $TestedSourceSha 'TestedSourceSha'
        $resolvedSource = Invoke-GitText @('-C', $repo, 'rev-parse', "${TestedSourceSha}^{commit}")
        $output = [IO.Path]::GetFullPath($OutputDirectory)
        if (-not $EvidencePaths -or $EvidencePaths.Count -eq 0) { $EvidencePaths = Get-DefaultEvidencePaths $output }
        $entries = @()
        foreach ($path in $EvidencePaths) {
            $resolved = Resolve-RequiredFile $path 'generated evidence file'
            $relative = Get-RepositoryRelativePath $repo $resolved
            $entries += [pscustomobject][ordered]@{ path = $relative; sha256 = Get-GitBlobSha256 $repo 'INDEX' $relative }
        }
        $entries = @($entries | Sort-Object path)
        $manifest = [ordered]@{
            schema = 'SWV5-SPRINT47-BLOB-MANIFEST-V1'
            tested_source_sha = $resolvedSource
            hash_authority = 'GIT_BLOB_BYTES_SHA256'
            source = 'GIT_INDEX'
            line_endings = 'LF'
            final_newline = 'EXACTLY_ONE'
            dependency_order = @('generate semantic evidence','stage evidence files','hash Git index blobs','write this non-circular manifest','stage manifest','verify index','commit','verify commit blobs')
            self_hash_policy = 'MANIFEST_EXCLUDED'
            evidence_files = $entries
        }
        if (-not $EvidenceManifestPath) { $EvidenceManifestPath = Join-Path $output 'evidence_blob_manifest.json' }
        Write-DeterministicText $EvidenceManifestPath ($manifest | ConvertTo-Json -Depth 8)
        [pscustomobject]$manifest | ConvertTo-Json -Depth 8
    }
    elseif ($Mode -eq 'VerifyIndex') {
        Require-Value $EvidenceManifestPath 'EvidenceManifestPath'
        $relative = Get-RepositoryRelativePath $repo (Resolve-RequiredFile $EvidenceManifestPath 'evidence blob manifest')
        $manifest = Read-BlobManifest $repo 'INDEX' $relative
        Verify-BlobManifest $repo 'INDEX' $manifest
        Invoke-GitText @('-C', $repo, 'cat-file', '-e', "$($manifest.tested_source_sha)^{commit}") | Out-Null
        [pscustomobject][ordered]@{ mode='VerifyIndex'; verdict='PASS'; tested_source_sha=$manifest.tested_source_sha; files=@($manifest.evidence_files).Count } | ConvertTo-Json
    }
    else {
        Require-Value $EvidenceManifestPath 'EvidenceManifestPath'
        Require-Value $EvidenceCommitSha 'EvidenceCommitSha'
        $resolvedEvidenceCommit = Invoke-GitText @('-C', $repo, 'rev-parse', "${EvidenceCommitSha}^{commit}")
        $relative = Get-RepositoryRelativePath $repo $EvidenceManifestPath
        $manifest = Read-BlobManifest $repo $resolvedEvidenceCommit $relative
        Verify-BlobManifest $repo $resolvedEvidenceCommit $manifest
        Invoke-GitText @('-C', $repo, 'merge-base', '--is-ancestor', $manifest.tested_source_sha, $resolvedEvidenceCommit) | Out-Null
        [pscustomobject][ordered]@{ mode='VerifyCommit'; verdict='PASS'; tested_source_sha=$manifest.tested_source_sha; evidence_commit_sha=$resolvedEvidenceCommit; files=@($manifest.evidence_files).Count } | ConvertTo-Json
    }
    exit 0
} catch {
    Write-Error $_.Exception.Message
    exit 1
}
