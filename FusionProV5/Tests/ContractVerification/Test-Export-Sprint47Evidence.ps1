# TEST ONLY
# NOT FOR PRODUCTION
# NO BROKER ACCESS
# Offline controlled-fixture tests for Export-Sprint47Evidence.ps1.

[CmdletBinding()]
param([string]$ExporterPath)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$Utf8NoBom = [Text.UTF8Encoding]::new($false)
$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
if ([string]::IsNullOrWhiteSpace($ExporterPath)) { $ExporterPath = Join-Path $scriptDirectory 'Export-Sprint47Evidence.ps1' }
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('SWV5-S47-EXPORT-' + [guid]::NewGuid().ToString('N'))
$passed = 0
$failed = 0
$records = @()

function Write-Lf([string]$Path, [string]$Text) {
    $parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    $canonical = (($Text -replace "`r`n", "`n" -replace "`r", "`n").TrimEnd("`n")) + "`n"
    [IO.File]::WriteAllText($Path, $canonical, $Utf8NoBom)
}

function Get-Sha([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Invoke-CheckedGit([string[]]$Arguments) {
    $saved = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $result = & git @Arguments 2>&1
    $exitCode = $LASTEXITCODE
    $ErrorActionPreference = $saved
    if ($exitCode -ne 0) { throw "fixture git command failed: git $($Arguments -join ' '): $($result -join ' ')" }
    return (($result | ForEach-Object { "$_" }) -join "`n").Trim()
}

function Record([string]$Id, [string]$Name, [bool]$Condition) {
    if ($Condition) { $script:passed++ } else { $script:failed++ }
    $script:records += [pscustomobject][ordered]@{ id=$Id; name=$Name; passed=$Condition }
}

function Invoke-Exporter([string]$Path, [string[]]$Arguments, [string]$OutputName) {
    $outputPath = Join-Path $tempRoot $OutputName
    $saved = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Path @Arguments *> $outputPath
    $exitCode = $LASTEXITCODE
    $ErrorActionPreference = $saved
    return [pscustomobject]@{ ExitCode=$exitCode; OutputPath=$outputPath }
}

try {
    if (-not (Test-Path -LiteralPath $ExporterPath -PathType Leaf)) { throw "exporter missing: $ExporterPath" }
    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
    $repo = Join-Path $tempRoot 'repo'
    New-Item -ItemType Directory -Path $repo -Force | Out-Null
    Invoke-CheckedGit @('-C',$repo,'init','--quiet') | Out-Null

    $testDir = Join-Path $repo 'FusionProV5\Tests\ContractVerification'
    $inventory = Join-Path $testDir 'TEST_INVENTORY.md'
    $matrix = Join-Path $testDir 'TEST_CREDIBILITY_MATRIX.md'
    $fixtureExporter = Join-Path $testDir 'Export-Sprint47Evidence.ps1'
    $manifest = Join-Path $repo 'Manifest.mq5'
    $source = Join-Path $testDir 'Source.mqh'
    Write-Lf (Join-Path $repo '.gitattributes') "* text=auto`n*.md text eol=lf`n*.txt text eol=lf`n*.json text eol=lf`nFusionProV5/Evidence/** text eol=lf"
    Write-Lf $inventory @'
| Domain | IDs | Total |
|---|---|---:|
| Fixture | FX-01 through FX-05 | 5 |
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
    Write-Lf $matrix $matrixValid
    Write-Lf $manifest '// fixture manifest'
    Write-Lf $source '// fixture verification source'
    Copy-Item -LiteralPath $ExporterPath -Destination $fixtureExporter
    Invoke-CheckedGit @('-C',$repo,'add','.') | Out-Null
    Invoke-CheckedGit @('-C',$repo,'-c','user.name=SWV5 Test','-c','user.email=swv5-test@example.invalid','commit','--quiet','-m','fixture source') | Out-Null
    $sourceCommit = Invoke-CheckedGit @('-C',$repo,'rev-parse','HEAD')

    $archLog = Join-Path $tempRoot 'architecture.log'
    $testLog = Join-Path $tempRoot 'tests.log'
    $run1Log = Join-Path $tempRoot 'run1.log'
    $run2Log = Join-Path $tempRoot 'run2.log'
    $compileOk = "Result: 0 errors, 0 warnings, 100 ms elapsed, cpu='X64 Regular'"
    $machine = 'SWV5_MACHINE_RESULT {"schema":"SWV5-CONTRACT-TEST-RESULT-V4","contract_policy":"SWV5-PRODUCTION-V4","implementation":"ISWV5-SEMANTIC-REFERENCE","total":5,"passed":5,"failed":0,"skipped":0,"signature":"123456789","deterministic":true}'
    $runBase = @"
SWV5_EVIDENCE_CONTEXT terminal_build=5555 demo_server=Fixture-Trial account_mode=HEDGING run_timestamp=2026-08-12T10:00:00+07:00 tester=StrategyTester
SWV5_RUN_METADATA suite=SPRINT4.7-FULL fixture_account_mode=HEDGING fixture_broker=TEST-BROKER fixture_server=TEST-SERVER broker_access=false
$machine
SWV5_ONTESTER_SUCCESS result=1
"@

    function Set-RawBaseline {
        Write-Lf $archLog $compileOk
        Write-Lf $testLog $compileOk
        Write-Lf $run1Log $runBase
        Write-Lf $run2Log $runBase.Replace('10:00:00','10:01:00')
    }

    function Get-GenerateArguments([string]$Commit, [string]$Output) {
        return @(
            '-Mode','Generate','-RepositoryRoot',$repo,'-OutputDirectory',$Output,
            '-ArchitectureCompileLog',$archLog,'-TestCompileLog',$testLog,
            '-Run1Log',$run1Log,'-Run2Log',$run2Log,'-TestedSourceSha',$Commit,
            '-ExpectedTerminalBuild','5555','-ExpectedDemoServerPattern','^Fixture-Trial$',
            '-ExpectedArchitectureCompileLogSha256',(Get-Sha $archLog),
            '-ExpectedTestCompileLogSha256',(Get-Sha $testLog),
            '-ExpectedRun1LogSha256',(Get-Sha $run1Log),
            '-ExpectedRun2LogSha256',(Get-Sha $run2Log),
            '-InventoryPath',$inventory,'-CredibilityMatrixPath',$matrix,
            '-ManifestPath',$manifest,'-VerificationSourcePaths',$source
        )
    }

    function Run-NegativeGenerate([string]$Id, [string]$Name, [string]$Commit, [scriptblock]$Arrange, [scriptblock]$AdjustArguments = $null) {
        Invoke-CheckedGit @('-C',$repo,'checkout','--quiet','--force',$Commit) | Out-Null
        Set-RawBaseline
        & $Arrange
        $output = Join-Path $tempRoot $Id
        $arguments = Get-GenerateArguments $Commit $output
        if ($null -ne $AdjustArguments) { $arguments = & $AdjustArguments $arguments }
        $result = Invoke-Exporter $fixtureExporter $arguments "$Id.out"
        Record $Id $Name ($result.ExitCode -ne 0)
    }

    Set-RawBaseline
    $outputA = Join-Path $repo 'OutA'
    $outputB = Join-Path $repo 'OutB'
    $validA = Invoke-Exporter $fixtureExporter (Get-GenerateArguments $sourceCommit $outputA) 'valid-a.out'
    Record 'EXP47-01' 'valid explicit-input generation succeeds' ($validA.ExitCode -eq 0)
    $validB = Invoke-Exporter $fixtureExporter (Get-GenerateArguments $sourceCommit $outputB) 'valid-b.out'
    $names = @('contract_test_results.json','VERIFICATION_REPORT.md','COMPILE_REPORT.md','sprint4_7_tester_evidence.txt')
    $byteIdentical = $validB.ExitCode -eq 0
    foreach ($name in $names) {
        $byteIdentical = $byteIdentical -and ((Get-Sha (Join-Path $outputA $name)) -eq (Get-Sha (Join-Path $outputB $name)))
    }
    Record 'EXP47-02' 'repeated generation is byte-identical' $byteIdentical

    $lfOnly = $true
    $oneFinalNewline = $true
    foreach ($name in $names) {
        $bytes = [IO.File]::ReadAllBytes((Join-Path $outputA $name))
        for ($index=0; $index -lt $bytes.Length; $index++) { if ($bytes[$index] -eq 13) { $lfOnly=$false } }
        $oneFinalNewline = $oneFinalNewline -and $bytes.Length -ge 2 -and $bytes[$bytes.Length-1] -eq 10 -and $bytes[$bytes.Length-2] -ne 10
    }
    Record 'EXP47-03' 'generated text is LF on Windows' $lfOnly
    Record 'EXP47-04' 'generated text has exactly one final newline' $oneFinalNewline

    $evidenceDir = Join-Path $repo 'FusionProV5\Evidence\Sprint4_7'
    Set-RawBaseline
    $generateEvidence = Invoke-Exporter $fixtureExporter (Get-GenerateArguments $sourceCommit $evidenceDir) 'evidence-generate.out'
    Invoke-CheckedGit @('-C',$repo,'add','FusionProV5/Evidence/Sprint4_7/contract_test_results.json','FusionProV5/Evidence/Sprint4_7/VERIFICATION_REPORT.md','FusionProV5/Evidence/Sprint4_7/COMPILE_REPORT.md','FusionProV5/Evidence/Sprint4_7/sprint4_7_tester_evidence.txt') | Out-Null
    $blobManifest = Join-Path $evidenceDir 'evidence_blob_manifest.json'
    $indexBuild = Invoke-Exporter $fixtureExporter @('-Mode','IndexManifest','-RepositoryRoot',$repo,'-OutputDirectory',$evidenceDir,'-TestedSourceSha',$sourceCommit) 'index-build.out'
    Invoke-CheckedGit @('-C',$repo,'add','FusionProV5/Evidence/Sprint4_7/evidence_blob_manifest.json') | Out-Null
    $indexVerify = Invoke-Exporter $fixtureExporter @('-Mode','VerifyIndex','-RepositoryRoot',$repo,'-EvidenceManifestPath',$blobManifest) 'index-verify.out'
    Record 'EXP47-05' 'staged index blob hashes equal claims' ($generateEvidence.ExitCode -eq 0 -and $indexBuild.ExitCode -eq 0 -and $indexVerify.ExitCode -eq 0)

    $indexClaims = Get-Content -LiteralPath $blobManifest -Raw | ConvertFrom-Json
    Invoke-CheckedGit @('-C',$repo,'-c','user.name=SWV5 Test','-c','user.email=swv5-test@example.invalid','commit','--quiet','-m','fixture evidence') | Out-Null
    $evidenceCommit = Invoke-CheckedGit @('-C',$repo,'rev-parse','HEAD')
    $commitVerify = Invoke-Exporter $fixtureExporter @('-Mode','VerifyCommit','-RepositoryRoot',$repo,'-EvidenceManifestPath',$blobManifest,'-EvidenceCommitSha',$evidenceCommit) 'commit-verify.out'
    Record 'EXP47-06' 'committed blob hashes equal staged claims' ($commitVerify.ExitCode -eq 0)

    $fresh = Join-Path $tempRoot 'fresh'
    Invoke-CheckedGit @('clone','--quiet','--no-hardlinks',$repo,$fresh) | Out-Null
    $freshExporter = Join-Path $fresh 'FusionProV5\Tests\ContractVerification\Export-Sprint47Evidence.ps1'
    $freshManifest = Join-Path $fresh 'FusionProV5\Evidence\Sprint4_7\evidence_blob_manifest.json'
    $freshVerify = Invoke-Exporter $freshExporter @('-Mode','VerifyCommit','-RepositoryRoot',$fresh,'-EvidenceManifestPath',$freshManifest,'-EvidenceCommitSha',$evidenceCommit) 'fresh-verify.out'
    Record 'EXP47-07' 'fresh checkout reproduces committed hashes' ($freshVerify.ExitCode -eq 0)

    $freshReport = Join-Path $fresh 'FusionProV5\Evidence\Sprint4_7\VERIFICATION_REPORT.md'
    $reportText = Get-Content -LiteralPath $freshReport -Raw
    [IO.File]::WriteAllText($freshReport, (($reportText -replace "`r?`n","`r`n").TrimEnd("`r","`n") + "`r`n"), $Utf8NoBom)
    $crlfVerify = Invoke-Exporter $freshExporter @('-Mode','VerifyCommit','-RepositoryRoot',$fresh,'-EvidenceManifestPath',$freshManifest,'-EvidenceCommitSha',$evidenceCommit) 'crlf-verify.out'
    Record 'EXP47-08' 'working-tree CRLF cannot change committed-blob claim' ($crlfVerify.ExitCode -eq 0)

    Invoke-CheckedGit @('-C',$repo,'restore','--source',$evidenceCommit,'--staged','--worktree','.') | Out-Null
    Add-Content -LiteralPath (Join-Path $evidenceDir 'VERIFICATION_REPORT.md') -Value 'manual mutation'
    Invoke-CheckedGit @('-C',$repo,'add','FusionProV5/Evidence/Sprint4_7/VERIFICATION_REPORT.md') | Out-Null
    $mutationVerify = Invoke-Exporter $fixtureExporter @('-Mode','VerifyIndex','-RepositoryRoot',$repo,'-EvidenceManifestPath',$blobManifest) 'mutation-verify.out'
    Record 'EXP47-09' 'manual post-export mutation is detected' ($mutationVerify.ExitCode -ne 0)

    Invoke-CheckedGit @('-C',$repo,'restore','--source',$evidenceCommit,'--staged','--worktree','.') | Out-Null
    $manifestObject = Get-Content -LiteralPath $blobManifest -Raw | ConvertFrom-Json
    $manifestObject.evidence_files[0].sha256 = ('0' * 64)
    Write-Lf $blobManifest ($manifestObject | ConvertTo-Json -Depth 8)
    Invoke-CheckedGit @('-C',$repo,'add','FusionProV5/Evidence/Sprint4_7/evidence_blob_manifest.json') | Out-Null
    $staleVerify = Invoke-Exporter $fixtureExporter @('-Mode','VerifyIndex','-RepositoryRoot',$repo,'-EvidenceManifestPath',$blobManifest) 'stale-verify.out'
    Record 'EXP47-10' 'stale claimed evidence hash is rejected' ($staleVerify.ExitCode -ne 0)

    Run-NegativeGenerate 'EXP47-11' 'wrong source SHA rejected' $sourceCommit { } { param($a) $index=[Array]::IndexOf($a,'-TestedSourceSha'); $a[$index+1]='0000000000000000000000000000000000000000'; return $a }
    Run-NegativeGenerate 'EXP47-12' 'raw-input hash mismatch rejected' $sourceCommit { } { param($a) $index=[Array]::IndexOf($a,'-ExpectedRun1LogSha256'); $a[$index+1]=('0'*64); return $a }
    Run-NegativeGenerate 'EXP47-13' 'duplicate machine-result ambiguity rejected' $sourceCommit { Add-Content -LiteralPath $run1Log -Value $machine }

    Invoke-CheckedGit @('-C',$repo,'checkout','--quiet','--force',$sourceCommit) | Out-Null
    Write-Lf $matrix ($matrixValid.Replace('| `INVARIANT_BEHAVIOR` | 1 | YES |','| `INVARIANT_BEHAVIOR` | 0 | YES |').Replace('| `WEAK_FALSE_POSITIVE` | 0 | NO |','| `WEAK_FALSE_POSITIVE` | 1 | NO |'))
    Invoke-CheckedGit @('-C',$repo,'add','FusionProV5/Tests/ContractVerification/TEST_CREDIBILITY_MATRIX.md') | Out-Null
    Invoke-CheckedGit @('-C',$repo,'-c','user.name=SWV5 Test','-c','user.email=swv5-test@example.invalid','commit','--quiet','-m','weak fixture') | Out-Null
    $weakCommit = Invoke-CheckedGit @('-C',$repo,'rev-parse','HEAD')
    Run-NegativeGenerate 'EXP47-14' 'WEAK_FALSE_POSITIVE above zero rejected' $weakCommit { }

    Invoke-CheckedGit @('-C',$repo,'checkout','--quiet','--force',$sourceCommit) | Out-Null
    Write-Lf $matrix ($matrixValid.Replace('| `INVARIANT_BEHAVIOR` | 1 | YES |','| `INVARIANT_BEHAVIOR` | 0 | YES |'))
    Invoke-CheckedGit @('-C',$repo,'add','FusionProV5/Tests/ContractVerification/TEST_CREDIBILITY_MATRIX.md') | Out-Null
    Invoke-CheckedGit @('-C',$repo,'-c','user.name=SWV5 Test','-c','user.email=swv5-test@example.invalid','commit','--quiet','-m','mismatch fixture') | Out-Null
    $mismatchCommit = Invoke-CheckedGit @('-C',$repo,'rev-parse','HEAD')
    Run-NegativeGenerate 'EXP47-15' 'inventory and credibility sum mismatch rejected' $mismatchCommit { }

    Run-NegativeGenerate 'EXP47-16' 'deterministic signature mismatch rejected' $sourceCommit { Write-Lf $run2Log ($runBase.Replace('"123456789"','"987654321"').Replace('10:00:00','10:01:00')) }
    Run-NegativeGenerate 'EXP47-17' 'compile warning rejected' $sourceCommit { Write-Lf $testLog "Result: 0 errors, 1 warnings, 100 ms elapsed, cpu='X64 Regular'" }
    Run-NegativeGenerate 'EXP47-18' 'compile error rejected' $sourceCommit { Write-Lf $archLog "Result: 1 errors, 0 warnings, 100 ms elapsed, cpu='X64 Regular'" }
    Run-NegativeGenerate 'EXP47-19' 'skipped test rejected' $sourceCommit { Write-Lf $run1Log ($runBase.Replace('"passed":5,"failed":0,"skipped":0','"passed":4,"failed":0,"skipped":1')) }
    Run-NegativeGenerate 'EXP47-20' 'failed test rejected' $sourceCommit { Write-Lf $run1Log ($runBase.Replace('"passed":5,"failed":0','"passed":4,"failed":1')) }
    Run-NegativeGenerate 'EXP47-21' 'missing machine result rejected' $sourceCommit { Write-Lf $run1Log ($runBase.Replace($machine,'')) }
    Run-NegativeGenerate 'EXP47-22' 'run total mismatch rejected' $sourceCommit { Write-Lf $run2Log ($runBase.Replace('"total":5,"passed":5','"total":6,"passed":6').Replace('10:00:00','10:01:00')) }
    Run-NegativeGenerate 'EXP47-23' 'missing OnTester success rejected' $sourceCommit { Write-Lf $run1Log ($runBase.Replace('SWV5_ONTESTER_SUCCESS result=1','')) }
    Run-NegativeGenerate 'EXP47-24' 'non-Demo/Trial server rejected' $sourceCommit { Write-Lf $run1Log ($runBase.Replace('demo_server=Fixture-Trial','demo_server=Fixture-Live')) }
    Run-NegativeGenerate 'EXP47-25' 'missing explicit raw input rejected' $sourceCommit { } { param($a) $index=[Array]::IndexOf($a,'-Run2Log'); $a[$index+1]=(Join-Path $tempRoot 'missing-run2.log'); return $a }
    Run-NegativeGenerate 'EXP47-26' 'verification source outside repository rejected' $sourceCommit { } { param($a) $index=[Array]::IndexOf($a,'-VerificationSourcePaths'); $a[$index+1]=$archLog; return $a }

    [pscustomobject][ordered]@{ schema='SWV5-SPRINT47-EXPORTER-OFFLINE-TEST-V1'; total=26; passed=$passed; failed=$failed; skipped=0; cases=$records } | ConvertTo-Json -Depth 6
    if ($failed -ne 0 -or $passed -ne 26) { exit 1 }
    exit 0
} finally {
    if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force }
}
