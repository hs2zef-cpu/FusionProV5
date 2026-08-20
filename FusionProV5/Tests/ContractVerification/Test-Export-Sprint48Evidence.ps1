# TEST ONLY
# NOT FOR PRODUCTION
# NO BROKER ACCESS
# Offline controlled-fixture regression tests for Export-Sprint48Evidence.ps1.

[CmdletBinding()]
param(
    [string]$ExporterPath,
    [string]$ResultPath,
    [string]$DiagnosticDirectory,
    [string]$CredibilityProofPath,
    [switch]$CredibilityOnly,
    [switch]$DeterminismOnly,
    [switch]$IdentityDiagnosticOnly,
    [switch]$BuildParserOnly,
    [switch]$ServerParserOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$Utf8NoBom = [Text.UTF8Encoding]::new($false)
$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
if ([string]::IsNullOrWhiteSpace($ExporterPath)) { $ExporterPath = Join-Path $scriptDirectory 'Export-Sprint48Evidence.ps1' }
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('SWV5-S48-EXPORT-' + [guid]::NewGuid().ToString('N'))
$passed = 0
$failed = 0
$records = @()
$scriptSucceeded = $false
$primaryError = $null
$failureContext = $null
$requiredArtifactHashCalls = 0
$requiredEvidenceNames = @('COMPILE_REPORT.md','VERIFICATION_REPORT.md','contract_test_results.json','sprint4_8_tester_evidence.txt','exporter_test_results.json')
$identityProvenance = $null
$diagnosticProbe = $null
$credibilityProof = $null
$canonicalBuilderInvocations = 0
$fixtureCommitMessage = 'SWV5 deterministic fixture source'
$fixtureGitAuthorName = 'SWV5 Deterministic Fixture'
$fixtureGitAuthorEmail = 'swv5-fixture@example.invalid'
$fixtureGitTimestamp = '2000-01-01T00:00:00+00:00'

function Write-Lf([string]$Path,[string]$Text) {
    $parent=Split-Path -Parent $Path; if(-not(Test-Path -LiteralPath $parent)){New-Item -ItemType Directory -Path $parent -Force|Out-Null}
    $canonical=(($Text -replace "`r`n","`n" -replace "`r","`n").TrimEnd("`n"))+"`n"
    [IO.File]::WriteAllText($Path,$canonical,$Utf8NoBom)
}
function ConvertTo-CanonicalJsonText([object]$Value,[int]$Depth=10) {
    $json=$Value|ConvertTo-Json -Depth $Depth
    return (($json-replace"`r`n","`n"-replace"`r","`n").TrimEnd("`n"))+"`n"
}
function Get-CanonicalJsonBytes([object]$Value,[int]$Depth=10){return $Utf8NoBom.GetBytes((ConvertTo-CanonicalJsonText $Value $Depth))}
function Get-Sha([string]$Path){return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()}
function Get-ShaBytes([byte[]]$Bytes){$sha=[Security.Cryptography.SHA256]::Create();try{return ([BitConverter]::ToString($sha.ComputeHash($Bytes))).Replace('-','').ToLowerInvariant()}finally{$sha.Dispose()}}
function Git([string[]]$Arguments){$saved=$ErrorActionPreference;$ErrorActionPreference='Continue';$r=& git.exe @Arguments 2>&1;$code=$LASTEXITCODE;$ErrorActionPreference=$saved;if($code-ne 0){throw "fixture git failed: git $($Arguments-join' '): $($r-join' ')"};return (($r|ForEach-Object{"$_"})-join"`n").Trim()}
function Record([string]$Id,[string]$Name,[bool]$Condition){if($Condition){$script:passed++}else{$script:failed++};$script:records += [pscustomobject][ordered]@{id=$Id;name=$Name;passed=$Condition}}
function Invoke-Exporter([string[]]$Arguments,[string]$Name,[string]$CaptureDirectory=$tempRoot){if(-not(Test-Path -LiteralPath $CaptureDirectory -PathType Container)){New-Item -ItemType Directory -Path $CaptureDirectory -Force|Out-Null};$out=Join-Path $CaptureDirectory $Name;$saved=$ErrorActionPreference;$ErrorActionPreference='Continue';& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $fixtureExporter @Arguments *> $out;$code=$LASTEXITCODE;$ErrorActionPreference=$saved;return [pscustomobject]@{ExitCode=$code;Output=$out;Arguments=@($Arguments);Exporter=$fixtureExporter}}
function Blob-Sha([string]$Commit,[string]$Relative){$bytes=& git.exe -C $repo show "${Commit}:$Relative" --no-textconv | Out-String; if($LASTEXITCODE-ne 0){throw 'blob read failed'}; $temp=Join-Path $tempRoot 'blob.tmp'; & git.exe -C $repo cat-file blob (& git.exe -C $repo rev-parse "${Commit}:$Relative") | Set-Content -LiteralPath $temp -Encoding Byte; return (Get-Sha $temp)}

function Resolve-CanonicalOutputDirectory([string]$Path) {
    try {
        if ([string]::IsNullOrWhiteSpace($Path)) { throw 'empty path' }
        return [IO.Path]::GetFullPath($Path)
    } catch {
        throw "INVALID_OUTPUT_DIRECTORY|path=$Path|error=$($_.Exception.Message)"
    }
}
function Assert-ExecutingFileIdentity([string]$ActualPath,[string]$ExpectedSha256,[string]$AuthorityLabel) {
    if([string]::IsNullOrWhiteSpace($ExpectedSha256)){throw "IDENTITY_EXPECTED_SHA_REQUIRED|authority=$AuthorityLabel|path=$ActualPath"}
    if($ExpectedSha256-notmatch'^[0-9a-fA-F]{64}$'){throw "IDENTITY_EXPECTED_SHA_INVALID|authority=$AuthorityLabel|expected=$ExpectedSha256|path=$ActualPath"}
    if(-not(Test-Path -LiteralPath $ActualPath -PathType Leaf)){throw "IDENTITY_EXECUTING_FILE_MISSING|authority=$AuthorityLabel|path=$ActualPath"}
    $canonical=[IO.Path]::GetFullPath($ActualPath)
    $actual=Get-Sha $canonical
    if($actual-ne$ExpectedSha256.ToLowerInvariant()){throw "EXECUTING_FILE_IDENTITY_MISMATCH|authority=$AuthorityLabel|expected=$($ExpectedSha256.ToLowerInvariant())|actual=$actual|path=$canonical"}
    return [pscustomobject][ordered]@{authority=$AuthorityLabel;expected_sha256=$ExpectedSha256.ToLowerInvariant();actual_sha256=$actual;execution_path=$canonical}
}
function Test-IsPathWithin([string]$Candidate,[string]$Parent) {
    $candidatePath=[IO.Path]::GetFullPath($Candidate).TrimEnd([IO.Path]::DirectorySeparatorChar,[IO.Path]::AltDirectorySeparatorChar)
    $parentPath=[IO.Path]::GetFullPath($Parent).TrimEnd([IO.Path]::DirectorySeparatorChar,[IO.Path]::AltDirectorySeparatorChar)
    return $candidatePath.Equals($parentPath,[StringComparison]::OrdinalIgnoreCase)-or$candidatePath.StartsWith($parentPath+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)
}
function Assert-ExternalDiagnosticRoot([string]$DiagnosticRoot,[string]$DisposableRoot) {
    $canonical=Resolve-CanonicalOutputDirectory $DiagnosticRoot
    if(-not[string]::IsNullOrWhiteSpace($DisposableRoot)-and(Test-IsPathWithin $canonical $DisposableRoot)){throw "DIAGNOSTIC_ROOT_INSIDE_DISPOSABLE_WORKSPACE|diagnostic=$canonical|disposable=$([IO.Path]::GetFullPath($DisposableRoot))"}
    return $canonical
}
function Get-ProducedFileInventory([string]$OutputDirectory) {
    $canonical=Resolve-CanonicalOutputDirectory $OutputDirectory
    if(-not(Test-Path -LiteralPath $canonical -PathType Container)){return @()}
    return @(Get-ChildItem -LiteralPath $canonical -File | Sort-Object Name | ForEach-Object{"$($_.Name)|$($_.Length)"})
}
function Get-RequiredArtifactHash([string]$OutputDirectory,[string]$Name,[string]$TestId) {
    $script:requiredArtifactHashCalls++
    $canonical=Resolve-CanonicalOutputDirectory $OutputDirectory
    $path=Join-Path $canonical $Name
    if(-not(Test-Path -LiteralPath $path -PathType Leaf)){
        $script:failureContext=[ordered]@{failing_test_id=$TestId;stage='required_output_gate';exit_code=0;output_directory=$canonical;diagnostic_stream='';invocation=@();produced_files=@(Get-ProducedFileInventory $canonical);missing_artifact=$Name}
        throw "GENERATE_SUCCEEDED_BUT_REQUIRED_OUTPUT_MISSING|test_id=$TestId|artifact=$Name|output=$canonical"
    }
    return Get-Sha $path
}
function Get-RequiredEvidenceHashes([string]$OutputDirectory,[string]$TestId) {
    $hashes=[ordered]@{}
    foreach($name in $requiredEvidenceNames){$hashes[$name]=Get-RequiredArtifactHash $OutputDirectory $name $TestId}
    return $hashes
}
function Assert-GenerateSucceeded([object]$Result,[string]$TestId,[string]$OutputDirectory) {
    $canonical=Resolve-CanonicalOutputDirectory $OutputDirectory
    if([int]$Result.ExitCode-ne0){
        $captured=if(Test-Path -LiteralPath $Result.Output -PathType Leaf){Get-Content -LiteralPath $Result.Output -Raw}else{'<diagnostic stream missing>'}
        $script:failureContext=[ordered]@{failing_test_id=$TestId;stage='generate';exit_code=[int]$Result.ExitCode;output_directory=$canonical;diagnostic_stream=[string]$Result.Output;invocation=@($Result.Arguments);exporter=[string]$Result.Exporter;produced_files=@(Get-ProducedFileInventory $canonical);primary_error=$captured}
        throw "BASELINE_GENERATE_FAILED|test_id=$TestId|exit_code=$($Result.ExitCode)|diagnostic=$($Result.Output)|error=$captured"
    }
}
function Write-FailureDiagnostic([string]$Root,[object]$Context,[object]$ErrorRecord,[string]$DisposableRoot='') {
    $canonical=Assert-ExternalDiagnosticRoot $Root $DisposableRoot
    New-Item -ItemType Directory -Path $canonical -Force|Out-Null
    $summary=[ordered]@{schema='SWV5-SPRINT48-HARNESS-FAILURE-V2';primary_error=[string]$ErrorRecord;failing_test_id=if($null-ne$Context){[string]$Context.failing_test_id}else{'HARNESS'};stage=if($null-ne$Context){[string]$Context.stage}else{'unclassified'};exit_code=if($null-ne$Context){$Context.exit_code}else{$null};exporter_path=if($null-ne$Context){[string]$Context.exporter}else{''};output_directory=if($null-ne$Context){[string]$Context.output_directory}else{''};diagnostic_stream=if($null-ne$Context){[string]$Context.diagnostic_stream}else{''};invocation=if($null-ne$Context){@($Context.invocation)}else{@()};arguments=if($null-ne$Context){@($Context.invocation)}else{@()};produced_files=if($null-ne$Context){@($Context.produced_files)}else{@()};captured_output_file='generate_all_streams.txt'}
    Write-Lf (Join-Path $canonical 'failure_summary.json') ($summary|ConvertTo-Json -Depth 6)
    Write-Lf (Join-Path $canonical 'produced_file_inventory.txt') (@($summary.produced_files)-join"`n")
    Write-Lf (Join-Path $canonical 'baseline_generate_invocation.txt') (@($summary.invocation)-join"`n")
    if($summary.diagnostic_stream-and(Test-Path -LiteralPath $summary.diagnostic_stream -PathType Leaf)){Copy-Item -LiteralPath $summary.diagnostic_stream -Destination (Join-Path $canonical 'generate_all_streams.txt') -Force}
    return $canonical
}
function Invoke-SafeCleanup([string]$Path,[object]$Primary,[scriptblock]$CleanupAction=$null) {
    try {if($null-ne$CleanupAction){&$CleanupAction}elseif(Test-Path -LiteralPath $Path){Remove-Item -LiteralPath $Path -Recurse -Force};return $null}
    catch {if($null-eq$Primary){throw};return $_}
}
function Write-GitBlobFile([string]$Repository,[string]$Blob,[string]$Path) {
    $start=[Diagnostics.ProcessStartInfo]::new('git.exe',"-C `"$Repository`" cat-file blob $Blob");$start.UseShellExecute=$false;$start.RedirectStandardOutput=$true
    $process=[Diagnostics.Process]::new();$process.StartInfo=$start;$process.Start()|Out-Null
    $file=[IO.File]::Open($Path,[IO.FileMode]::Create,[IO.FileAccess]::Write,[IO.FileShare]::None)
    try{$process.StandardOutput.BaseStream.CopyTo($file);$process.WaitForExit();if($process.ExitCode-ne0){throw "git blob materialization failed: $Blob"}}finally{$file.Dispose();$process.Dispose()}
}
function Get-GitBlobBytes([string]$Repository,[string]$Blob) {
    $start=[Diagnostics.ProcessStartInfo]::new('git.exe',"-C `"$Repository`" cat-file blob $Blob");$start.UseShellExecute=$false;$start.RedirectStandardOutput=$true
    $process=[Diagnostics.Process]::new();$process.StartInfo=$start;$process.Start()|Out-Null;$memory=[IO.MemoryStream]::new()
    try{$process.StandardOutput.BaseStream.CopyTo($memory);$process.WaitForExit();if($process.ExitCode-ne0){throw "git blob read failed: $Blob"};return $memory.ToArray()}finally{$memory.Dispose();$process.Dispose()}
}
function Commit-DeterministicFixture([string]$Repository) {
    $names=@('GIT_AUTHOR_NAME','GIT_AUTHOR_EMAIL','GIT_AUTHOR_DATE','GIT_COMMITTER_NAME','GIT_COMMITTER_EMAIL','GIT_COMMITTER_DATE')
    $saved=[ordered]@{};foreach($name in $names){$saved[$name]=[Environment]::GetEnvironmentVariable($name,'Process')}
    try {
        [Environment]::SetEnvironmentVariable('GIT_AUTHOR_NAME',$fixtureGitAuthorName,'Process')
        [Environment]::SetEnvironmentVariable('GIT_AUTHOR_EMAIL',$fixtureGitAuthorEmail,'Process')
        [Environment]::SetEnvironmentVariable('GIT_AUTHOR_DATE',$fixtureGitTimestamp,'Process')
        [Environment]::SetEnvironmentVariable('GIT_COMMITTER_NAME',$fixtureGitAuthorName,'Process')
        [Environment]::SetEnvironmentVariable('GIT_COMMITTER_EMAIL',$fixtureGitAuthorEmail,'Process')
        [Environment]::SetEnvironmentVariable('GIT_COMMITTER_DATE',$fixtureGitTimestamp,'Process')
        Git @('-C',$Repository,'-c','commit.gpgSign=false','commit','--quiet','--no-gpg-sign','-m',$fixtureCommitMessage)|Out-Null
        return Git @('-C',$Repository,'rev-parse','HEAD')
    } finally {foreach($name in $names){[Environment]::SetEnvironmentVariable($name,$saved[$name],'Process')}}
}
function New-IndependentFixtureReplica([string]$Root,[string]$SourceRepository,[string]$SourceCommit) {
    New-Item -ItemType Directory -Path $Root -Force|Out-Null;Git @('-C',$Root,'init','--quiet')|Out-Null
    $paths=@((Git @('-C',$SourceRepository,'ls-tree','-r','--name-only',$SourceCommit))-split"`n"|Where-Object{$_-ne''})
    $blobs=@()
    foreach($relative in $paths){
        if([IO.Path]::IsPathRooted($relative)-or@($relative-split'[/\\]')-contains'..'){throw "FIXTURE_REPLICA_UNSAFE_PATH|path=$relative"}
        $blob=Git @('-C',$SourceRepository,'rev-parse',"${SourceCommit}:$relative")
        $target=Join-Path $Root ($relative-replace'/',[IO.Path]::DirectorySeparatorChar);$parent=Split-Path -Parent $target;if(-not(Test-Path -LiteralPath $parent)){New-Item -ItemType Directory -Path $parent -Force|Out-Null}
        Write-GitBlobFile $SourceRepository $blob $target
        $blobs += [pscustomobject][ordered]@{path=$relative;blob=$blob}
    }
    Git @('-C',$Root,'add','.')|Out-Null;$commit=Commit-DeterministicFixture $Root;$tree=Git @('-C',$Root,'rev-parse',"${commit}^{tree}")
    return [pscustomobject][ordered]@{root=$Root;commit=$commit;tree=$tree;blobs=$blobs;author_date=Git @('-C',$Root,'show','-s','--format=%aI',$commit);committer_date=Git @('-C',$Root,'show','-s','--format=%cI',$commit)}
}
function Get-ExplicitFixtureSources([string]$Repository,[string]$Commit) {
    $paths=@((Git @('-C',$Repository,'ls-tree','-r','--name-only',$Commit))-split"`n"|Where-Object{$_-ne''})
    return @($paths|ForEach-Object{$blob=Git @('-C',$Repository,'rev-parse',"${Commit}:$_");[pscustomobject][ordered]@{path=$_;bytes=[byte[]](Get-GitBlobBytes $Repository $blob)}})
}
function New-ExplicitFixtureRepository([string]$Root,[object[]]$Sources) {
    New-Item -ItemType Directory -Path $Root -Force|Out-Null;Git @('-C',$Root,'init','--quiet')|Out-Null
    foreach($source in @($Sources|Sort-Object path)){
        $relative=[string]$source.path
        if([IO.Path]::IsPathRooted($relative)-or@($relative-split'[/\\]')-contains'..'){throw "EXPLICIT_FIXTURE_UNSAFE_PATH|path=$relative"}
        $target=Join-Path $Root ($relative-replace'/',[IO.Path]::DirectorySeparatorChar);$parent=Split-Path -Parent $target;if(-not(Test-Path -LiteralPath $parent)){New-Item -ItemType Directory -Path $parent -Force|Out-Null}
        [IO.File]::WriteAllBytes($target,[byte[]]$source.bytes)
    }
    Git @('-C',$Root,'add','.')|Out-Null;$commit=Commit-DeterministicFixture $Root;$tree=Git @('-C',$Root,'rev-parse',"${commit}^{tree}")
    $entries=@()
    foreach($source in @($Sources|Sort-Object path)){
        $relative=[string]$source.path;$blob=Git @('-C',$Root,'rev-parse',"${commit}:$relative");$materialized=Join-Path $Root ($relative-replace'/',[IO.Path]::DirectorySeparatorChar)
        $entries += [pscustomobject][ordered]@{path=$relative;source_sha256=Get-ShaBytes ([byte[]]$source.bytes);blob=$blob;blob_sha256=Get-ShaBytes (Get-GitBlobBytes $Root $blob);materialized_sha256=Get-Sha $materialized}
    }
    return [pscustomobject][ordered]@{root=$Root;tree=$tree;commit=$commit;entries=$entries;author_date=Git @('-C',$Root,'show','-s','--format=%aI',$commit);committer_date=Git @('-C',$Root,'show','-s','--format=%cI',$commit)}
}

try {
    if(-not(Test-Path -LiteralPath $ExporterPath -PathType Leaf)){throw "exporter missing: $ExporterPath"}
    $activeHarnessPath=[IO.Path]::GetFullPath($PSCommandPath)
    $activeTestScriptSha=Get-Sha $activeHarnessPath
    New-Item -ItemType Directory -Path $tempRoot -Force|Out-Null
    $repo=Join-Path $tempRoot 'repo';New-Item -ItemType Directory -Path $repo|Out-Null;Git @('-C',$repo,'init','--quiet')|Out-Null
    $testDir=Join-Path $repo 'FusionProV5\Tests\ContractVerification';New-Item -ItemType Directory -Path $testDir -Force|Out-Null
    $fixtureExporter=Join-Path $testDir 'Export-Sprint48Evidence.ps1';Copy-Item -LiteralPath $ExporterPath -Destination $fixtureExporter
    $fixtureTestScript=Join-Path $testDir 'Test-Export-Sprint48Evidence.ps1';Copy-Item -LiteralPath $PSCommandPath -Destination $fixtureTestScript
    $fixtureExporterSourceSha=Get-Sha $fixtureExporter
    $fixtureTestSourceSha=Get-Sha $fixtureTestScript
    if($fixtureTestSourceSha-ne$activeTestScriptSha){throw "ACTIVE_HARNESS_FIXTURE_SOURCE_MISMATCH|active=$activeTestScriptSha|fixture_source=$fixtureTestSourceSha"}
    $inventory=Join-Path $testDir 'TEST_INVENTORY.md';$matrix=Join-Path $testDir 'TEST_CREDIBILITY_MATRIX.md';$credibilityInventory=Join-Path $testDir 'TEST_CREDIBILITY_ID_INVENTORY.txt'
    $manifest=Join-Path $repo 'SOMWANG_XAU_M15_FUSION_PRO_V5_SPRINT4_3_CONTRACT_TESTS.mq5'
    $ini=Join-Path $testDir 'sprint4_8_b11_full_once.ini';$set=Join-Path $testDir 'sprint4_8_b11_full_once.set'
    Write-Lf (Join-Path $repo '.gitattributes') "* text=auto`n*.md text eol=lf`n*.txt text eol=lf`n*.json text eol=lf`n*.ps1 text eol=lf`nFusionProV5/Evidence/** text eol=lf"
    Write-Lf $inventory "| Domain | IDs | Total |`n|---|---|---:|`n| Fixture | FX-001 through FX-934 | 934 |`n| **Total** |  | **934** |"
    Write-Lf (Join-Path $testDir 'TEST_ID_INVENTORY.txt') "# fixture canonical IDs`nFX-001..934"
    $exporterIds=@();foreach($n in 1..41){$exporterIds+='EXP48-'+$n.ToString('D2')};foreach($n in 46..64){$exporterIds+='EXP48-'+$n.ToString('D2')};$exporterIds+='EXP48-67';foreach($n in 42..45){$exporterIds+='EXP48-'+$n.ToString('D2')};foreach($n in 65..66){$exporterIds+='EXP48-'+$n.ToString('D2')};foreach($n in 68..140){$exporterIds+='EXP48-'+$n.ToString('D2')}
    Write-Lf (Join-Path $testDir 'EXPORTER_TEST_ID_INVENTORY.txt') ("# exact exporter regression execution order`n"+($exporterIds-join"`n"))
    $matrixValid=@'
| Category | Count | Merge-gating evidence |
|---|---:|---|
| `MERGE_GATING_BEHAVIOR` | 85 | YES |
| `STATE_TRANSITION` | 109 | YES |
| `NEGATIVE_FAIL_CLOSED` | 606 | YES |
| `ROUND_TRIP` | 10 | YES |
| `INVARIANT_BEHAVIOR` | 48 | YES |
| `SUPPORTING_PURE_FUNCTION` | 62 | NO |
| `CONFORMANCE_ONLY` | 14 | NO |
| `WEAK_FALSE_POSITIVE` | 0 | NO |
'@
    $credibilityValid=@'
# canonical per-ID credibility authority
MERGE_GATING_BEHAVIOR|FX-001..085
STATE_TRANSITION|FX-086..194
NEGATIVE_FAIL_CLOSED|FX-195..800
ROUND_TRIP|FX-801..810
INVARIANT_BEHAVIOR|FX-811..858
SUPPORTING_PURE_FUNCTION|FX-859..920
CONFORMANCE_ONLY|FX-921..934
'@
    Write-Lf $matrix $matrixValid;Write-Lf $credibilityInventory $credibilityValid;Write-Lf $manifest '// fixture manifest';Write-Lf $ini "[Tester]`nSymbol=EURUSD`nPeriod=M1";Write-Lf $set 'Fixture=true'
    Git @('-C',$repo,'add','.')|Out-Null
    $sourceCommit=Commit-DeterministicFixture $repo
    $sourceTree=Git @('-C',$repo,'rev-parse',"${sourceCommit}^{tree}")
    $sourceBlobManifest=@((Git @('-C',$repo,'ls-tree','-r','--name-only',$sourceCommit))-split"`n"|Where-Object{$_-ne''}|ForEach-Object{[pscustomobject][ordered]@{path=$_;blob=Git @('-C',$repo,'rev-parse',"${sourceCommit}:$_")}})
    $sourceAuthorDate=Git @('-C',$repo,'show','-s','--format=%aI',$sourceCommit)
    $sourceCommitterDate=Git @('-C',$repo,'show','-s','--format=%cI',$sourceCommit)
    $fixtureReplica=New-IndependentFixtureReplica (Join-Path $tempRoot 'fixture-replica-b') $repo $sourceCommit
    $manifestBlob=Git @('-C',$repo,'rev-parse',"${sourceCommit}:SOMWANG_XAU_M15_FUSION_PRO_V5_SPRINT4_3_CONTRACT_TESTS.mq5")
    $iniBlob=Git @('-C',$repo,'rev-parse',"${sourceCommit}:FusionProV5/Tests/ContractVerification/sprint4_8_b11_full_once.ini")
    $setBlob=Git @('-C',$repo,'rev-parse',"${sourceCommit}:FusionProV5/Tests/ContractVerification/sprint4_8_b11_full_once.set")
    $credibilityBlob=Git @('-C',$repo,'rev-parse',"${sourceCommit}:FusionProV5/Tests/ContractVerification/TEST_CREDIBILITY_ID_INVENTORY.txt")
    $exporterRepositoryPath='FusionProV5/Tests/ContractVerification/Export-Sprint48Evidence.ps1'
    $testScriptRepositoryPath='FusionProV5/Tests/ContractVerification/Test-Export-Sprint48Evidence.ps1'
    $exporterBlob=Git @('-C',$repo,'rev-parse',"${sourceCommit}:$exporterRepositoryPath")
    $exporterTestBlob=Git @('-C',$repo,'rev-parse',"${sourceCommit}:$testScriptRepositoryPath")
    function Get-BlobSha([string]$Blob){$start=[Diagnostics.ProcessStartInfo]::new('git.exe',"-C `"$repo`" cat-file blob $Blob");$start.UseShellExecute=$false;$start.RedirectStandardOutput=$true;$p=[Diagnostics.Process]::new();$p.StartInfo=$start;$p.Start()|Out-Null;$m=[IO.MemoryStream]::new();try{$p.StandardOutput.BaseStream.CopyTo($m);$p.WaitForExit();if($p.ExitCode-ne0){throw "git blob hash read failed: $Blob"};return Get-ShaBytes $m.ToArray()}finally{$m.Dispose();$p.Dispose()}}
    $fixtureExporterSha=Get-BlobSha $exporterBlob
    $fixtureTestScriptSha=Get-BlobSha $exporterTestBlob
    if($fixtureExporterSourceSha-ne$fixtureExporterSha){throw "FIXTURE_EXPORTER_SOURCE_BLOB_IDENTITY_MISMATCH|source=$fixtureExporterSourceSha|blob=$fixtureExporterSha"}
    if($fixtureTestSourceSha-ne$fixtureTestScriptSha){throw "FIXTURE_TEST_SCRIPT_SOURCE_BLOB_IDENTITY_MISMATCH|source=$fixtureTestSourceSha|blob=$fixtureTestScriptSha"}
    # Execute the exact committed blob bytes. A Windows checkout may materialize
    # CRLF working bytes even though the source-bound Git blob is LF.
    Write-GitBlobFile $repo $exporterBlob $fixtureExporter
    Write-GitBlobFile $repo $exporterTestBlob $fixtureTestScript
    $executingFixtureExporterIdentity=Assert-ExecutingFileIdentity $fixtureExporter $fixtureExporterSha 'fixture_exporter_git_blob'
    $materializedFixtureTestIdentity=Assert-ExecutingFileIdentity $fixtureTestScript $fixtureTestScriptSha 'fixture_test_script_git_blob'
    $activeHarnessIdentity=Assert-ExecutingFileIdentity $activeHarnessPath $fixtureTestScriptSha 'active_harness_fixture_git_blob'
    $identityProvenance=[ordered]@{
        fixture_commit=$sourceCommit
        fixture_tree=$sourceTree
        fixture_commit_message=$fixtureCommitMessage
        fixture_author=[ordered]@{name=$fixtureGitAuthorName;email=$fixtureGitAuthorEmail;timestamp=$fixtureGitTimestamp}
        fixture_committer=[ordered]@{name=$fixtureGitAuthorName;email=$fixtureGitAuthorEmail;timestamp=$fixtureGitTimestamp}
        exporter=[ordered]@{repository_path=$exporterRepositoryPath;git_blob_object=$exporterBlob;expected_git_blob_sha256=$fixtureExporterSha;source_byte_sha256=$fixtureExporterSourceSha;executed_file_sha256=$executingFixtureExporterIdentity.actual_sha256}
        test_script=[ordered]@{repository_path=$testScriptRepositoryPath;git_blob_object=$exporterTestBlob;active_test_script_sha256=$activeTestScriptSha;fixture_source_sha256=$fixtureTestSourceSha;expected_git_blob_sha256=$fixtureTestScriptSha;materialized_file_sha256=$materializedFixtureTestIdentity.actual_sha256}
    }
    $actualRuntimeContext=[pscustomobject][ordered]@{
        execution_path=$activeHarnessPath
        materialized_path=[IO.Path]::GetFullPath($fixtureTestScript)
        output_path=if([string]::IsNullOrWhiteSpace($ResultPath)){Join-Path $tempRoot 'console-result.json'}else{[IO.Path]::GetFullPath($ResultPath)}
        diagnostic_path=if([string]::IsNullOrWhiteSpace($DiagnosticDirectory)){Join-Path $tempRoot 'diagnostic'}else{[IO.Path]::GetFullPath($DiagnosticDirectory)}
        workspace_path=[IO.Path]::GetFullPath($tempRoot)
        process_id=$PID
    }
    function New-FixtureCanonicalProvenance([object]$Authority) {
        $exporterEntry=@($Authority.entries|Where-Object{$_.path-eq$exporterRepositoryPath});$testEntry=@($Authority.entries|Where-Object{$_.path-eq$testScriptRepositoryPath})
        if($exporterEntry.Count-ne1-or$testEntry.Count-ne1){throw 'FIXTURE_AUTHORITY_REQUIRED_ENTRY_MISSING'}
        return [ordered]@{
            fixture_commit=$Authority.commit
            fixture_tree=$Authority.tree
            fixture_commit_message=$fixtureCommitMessage
            fixture_author=[ordered]@{name=$fixtureGitAuthorName;email=$fixtureGitAuthorEmail;timestamp=$fixtureGitTimestamp}
            fixture_committer=[ordered]@{name=$fixtureGitAuthorName;email=$fixtureGitAuthorEmail;timestamp=$fixtureGitTimestamp}
            exporter=[ordered]@{repository_path=$exporterRepositoryPath;git_blob_object=$exporterEntry[0].blob;expected_git_blob_sha256=$exporterEntry[0].blob_sha256;source_byte_sha256=$exporterEntry[0].source_sha256;executed_file_sha256=$exporterEntry[0].materialized_sha256}
            test_script=[ordered]@{repository_path=$testScriptRepositoryPath;git_blob_object=$testEntry[0].blob;active_test_script_sha256=$testEntry[0].source_sha256;fixture_source_sha256=$testEntry[0].source_sha256;expected_git_blob_sha256=$testEntry[0].blob_sha256;materialized_file_sha256=$testEntry[0].materialized_sha256}
        }
    }
    function New-CanonicalExporterResult([object[]]$Cases,[object]$Provenance=$identityProvenance,[string]$TestScriptSha=$fixtureTestScriptSha,[string]$ActiveSha=$activeTestScriptSha,[object]$RuntimeContext=$actualRuntimeContext) {
        if($null-eq$RuntimeContext){throw 'CANONICAL_BUILDER_RUNTIME_CONTEXT_REQUIRED'}
        foreach($name in @('execution_path','materialized_path','output_path','diagnostic_path','workspace_path','process_id')){if($null-eq$RuntimeContext.psobject.Properties[$name]-or[string]::IsNullOrWhiteSpace([string]$RuntimeContext.$name)){throw "CANONICAL_BUILDER_RUNTIME_CONTEXT_FIELD_REQUIRED|field=$name"}}
        $script:canonicalBuilderInvocations++
        $caseArray=@($Cases)
        $caseSignature=Get-ShaBytes $Utf8NoBom.GetBytes((@($caseArray|ForEach-Object{$_.id+'|'+$_.name+'|'+[bool]$_.passed})-join"`n"))
        return [pscustomobject][ordered]@{
            schema='SWV5-SPRINT48-EXPORTER-OFFLINE-TEST-V4'
            exporter_path=$exporterRepositoryPath
            exporter_sha256=$fixtureExporterSha
            test_script_sha256=$TestScriptSha
            active_test_script_sha256=$ActiveSha
            identity_provenance=$Provenance
            generated_from='Test-Export-Sprint48Evidence.ps1 - offline controlled fixture V4'
            total=$caseArray.Count
            passed=@($caseArray|Where-Object{$_.passed}).Count
            failed=@($caseArray|Where-Object{-not$_.passed}).Count
            skipped=0
            signature=$caseSignature
            cases=$caseArray
        }
    }
    $archLog=Join-Path $tempRoot 'architecture.log';$testLog=Join-Path $tempRoot 'tests.log';$run1Log=Join-Path $tempRoot 'run1.log';$run2Log=Join-Path $tempRoot 'run2.log';$ex5=Join-Path $tempRoot 'tests.ex5';$offlineResult=Join-Path $tempRoot 'exporter_test_results.json'
    $compileOk="Result: 0 errors, 0 warnings, 100 ms elapsed, cpu='X64 Regular'"
    $machine='SWV5_MACHINE_RESULT {"schema":"SWV5-CONTRACT-TEST-RESULT-V5","contract_policy":"SWV5-PRODUCTION-V5","suite":"SPRINT4.8-V5-FULL","total":934,"passed":934,"failed":0,"skipped":0,"signature":"12393352988365616976","deterministic":true}'
    $caseLines=@();for($n=1;$n-le934;$n++){$caseLines += ('SWV5_TEST id=FX-'+$n.ToString('D3')+' domain=FIXTURE outcome=PASS expected=pass actual=pass detail=')};$caseBlock=($caseLines-join"`n")
    $metaTesterLine='AB 0 10:00:00.000 Startup MetaTester 5 build 6090, 31 Jul 2026'
    $agentAuthorizationLine='AB 0 10:00:00.001 Network authorized (agent build 6090)'
    $loginBuildLine='AB 0 10:00:00.001 127.0.0.1 login (build 6090)'
    $serverGenerationLine='AB 0 10:00:00.002 Tester EURUSD,M1 (Exness-MT5Trial6): generating based on real ticks'
    $serverTestingLine='AB 0 10:00:00.002 Tester EURUSD,M1 (Exness-MT5Trial6): testing of Fixture.ex5'
    $runBase=@"
$metaTesterLine
$loginBuildLine
$serverGenerationLine
AB 0 10:00:00.002 Tester EURUSD,M1: testing of Fixture.ex5 started with inputs:
SWV5_RUN_METADATA suite=SPRINT4.8-V5-FULL fixture_account_mode=HEDGING fixture_broker=TEST-BROKER fixture_server=TEST-SERVER broker_access=false
$caseBlock
$caseBlock
$machine
SWV5_ONTESTER_SUCCESS result=1
AB 0 10:00:00.003 OnTester result 1
"@
    function Set-OfflineBaseline {
        $fixtureCases=@();foreach($id in $exporterIds){$fixtureCases += [pscustomobject][ordered]@{id=$id;name='source-bound fixture result';passed=$true}}
        $signature=Get-ShaBytes $Utf8NoBom.GetBytes((@($fixtureCases|ForEach-Object{$_.id+'|'+$_.name+'|'+$_.passed})-join"`n"))
        $value=[ordered]@{schema='SWV5-SPRINT48-EXPORTER-OFFLINE-TEST-V4';exporter_path='FusionProV5/Tests/ContractVerification/Export-Sprint48Evidence.ps1';exporter_sha256=$fixtureExporterSha;test_script_sha256=$fixtureTestScriptSha;generated_from='Test-Export-Sprint48Evidence.ps1 - offline controlled fixture V4';total=$fixtureCases.Count;passed=$fixtureCases.Count;failed=0;skipped=0;signature=$signature;cases=$fixtureCases}
        Write-Lf $offlineResult ($value|ConvertTo-Json -Depth 6)
    }
    function Set-Baseline {Write-Lf $archLog $compileOk;Write-Lf $testLog $compileOk;Write-Lf $run1Log $runBase;Write-Lf $run2Log ($runBase.Replace('10:00:00','10:01:00'));[IO.File]::WriteAllBytes($ex5,[byte[]](1,4,8,16,32,64));Set-OfflineBaseline}
    function Get-Digest([string]$Commit,[string]$Tree,[string]$CredibilitySha='',[string]$TerminalBuild='6090',[string]$Server='Exness-MT5Trial6'){
        $sourceCredibilityBlob=Git @('-C',$repo,'rev-parse',"${Commit}:FusionProV5/Tests/ContractVerification/TEST_CREDIBILITY_ID_INVENTORY.txt")
        if([string]::IsNullOrWhiteSpace($CredibilitySha)){$CredibilitySha=Get-BlobSha $sourceCredibilityBlob}
        $lines=@('format=SWV5-SPRINT48-B11-VERIFICATION-SOURCE-V5',"tested_source_commit=$Commit","source_tree=$Tree","architecture_compile_raw_sha256=$(Get-Sha $archLog)","test_compile_raw_sha256=$(Get-Sha $testLog)","run_1_raw_sha256=$(Get-Sha $run1Log)","run_2_raw_sha256=$(Get-Sha $run2Log)","exporter_test_results_raw_sha256=$(Get-Sha $offlineResult)",'run_1_signature=12393352988365616976','run_2_signature=12393352988365616976','schema=SWV5-CONTRACT-TEST-RESULT-V5','production_policy=SWV5-PRODUCTION-V5','suite=SPRINT4.8-V5-FULL',"terminal_build=$TerminalBuild","server=$Server",'account_mode=HEDGING','ontester=1',"test_manifest_git_blob_sha256=$(Get-BlobSha $manifestBlob)","credibility_inventory_git_blob_sha256=$CredibilitySha","run_config_ini_sha256=$(Get-BlobSha $iniBlob)","run_config_set_sha256=$(Get-BlobSha $setBlob)","compiled_test_ex5_sha256=$(Get-Sha $ex5)","exporter_git_blob_sha256=$fixtureExporterSha","exporter_test_script_git_blob_sha256=$fixtureTestScriptSha")
        return Get-ShaBytes $Utf8NoBom.GetBytes(($lines-join"`n"))
    }
    function Get-DigestFromInputs([string]$Commit,[string]$Tree,[object]$Inputs){
        $lines=@('format=SWV5-SPRINT48-B11-VERIFICATION-SOURCE-V5',"tested_source_commit=$Commit","source_tree=$Tree","architecture_compile_raw_sha256=$($Inputs.architecture_compile_raw_sha256)","test_compile_raw_sha256=$($Inputs.test_compile_raw_sha256)","run_1_raw_sha256=$($Inputs.run_1_raw_sha256)","run_2_raw_sha256=$($Inputs.run_2_raw_sha256)","exporter_test_results_raw_sha256=$($Inputs.exporter_test_results_raw_sha256)","run_1_signature=$($Inputs.run_1_signature)","run_2_signature=$($Inputs.run_2_signature)","schema=$($Inputs.schema)","production_policy=$($Inputs.production_policy)","suite=$($Inputs.suite)","terminal_build=$($Inputs.terminal_build)","server=$($Inputs.server)","account_mode=$($Inputs.account_mode)","ontester=$($Inputs.ontester)","test_manifest_git_blob_sha256=$($Inputs.test_manifest_git_blob_sha256)","credibility_inventory_git_blob_sha256=$($Inputs.credibility_inventory_git_blob_sha256)","run_config_ini_sha256=$($Inputs.run_config_ini_sha256)","run_config_set_sha256=$($Inputs.run_config_set_sha256)","compiled_test_ex5_sha256=$($Inputs.compiled_test_ex5_sha256)","exporter_git_blob_sha256=$($Inputs.exporter_git_blob_sha256)","exporter_test_script_git_blob_sha256=$($Inputs.exporter_test_script_git_blob_sha256)")
        return Get-ShaBytes $Utf8NoBom.GetBytes(($lines-join"`n"))
    }
    function Get-Args([string]$Commit,[string]$Tree,[string]$Output){return @('-Mode','Generate','-RepositoryRoot',$repo,'-OutputDirectory',$Output,'-ArchitectureCompileLog',$archLog,'-TestCompileLog',$testLog,'-Run1Log',$run1Log,'-Run2Log',$run2Log,'-CompiledTestEx5',$ex5,'-ExporterTestResults',$offlineResult,'-ExpectedTestTotal','934','-ExpectedDeterministicSignature','12393352988365616976','-TestedSourceSha',$Commit,'-ExpectedSourceTreeSha',$Tree,'-ExpectedArchitectureCompileLogSha256',(Get-Sha $archLog),'-ExpectedTestCompileLogSha256',(Get-Sha $testLog),'-ExpectedRun1LogSha256',(Get-Sha $run1Log),'-ExpectedRun2LogSha256',(Get-Sha $run2Log),'-ExpectedCompiledTestEx5Sha256',(Get-Sha $ex5),'-ExpectedExporterTestResultsSha256',(Get-Sha $offlineResult),'-ExpectedVerificationSourceDigest',(Get-Digest $Commit $Tree))}
    function Negative([string]$Id,[string]$Name,[scriptblock]$Arrange,[scriptblock]$Adjust=$null){Git @('-C',$repo,'checkout','--quiet','--force',$sourceCommit)|Out-Null;Set-Baseline;&$Arrange;$a=Get-Args $sourceCommit $sourceTree (Join-Path $tempRoot $Id);if($null-ne$Adjust){$a=&$Adjust $a};$r=Invoke-Exporter $a "$Id.out";Record $Id $Name ($r.ExitCode-ne 0)}
    function Run-BuildParserTests {
        Git @('-C',$repo,'checkout','--quiet','--force',$sourceCommit)|Out-Null;Set-Baseline
        $d3Style=Invoke-Exporter (Get-Args $sourceCommit $sourceTree (Join-Path $tempRoot 'EXP48-83')) 'EXP48-83.out'
        Record 'EXP48-83' 'D3-style MetaTester authority without agent-authorization record passes' ($d3Style.ExitCode-eq0)

        Git @('-C',$repo,'checkout','--quiet','--force',$sourceCommit)|Out-Null;Set-Baseline
        Write-Lf $run1Log ($runBase.Replace($metaTesterLine,$metaTesterLine+"`n"+$metaTesterLine))
        $duplicate=Invoke-Exporter (Get-Args $sourceCommit $sourceTree (Join-Path $tempRoot 'EXP48-84')) 'EXP48-84.out'
        Record 'EXP48-84' 'duplicate identical authoritative build records pass' ($duplicate.ExitCode-eq0)

        Negative 'EXP48-85' 'consistently wrong MetaTester and login build rejected' {Write-Lf $run1Log ($runBase.Replace('build 6090','build 6089'))}
        Negative 'EXP48-86' 'conflicting MetaTester and login build identities rejected' {Write-Lf $run1Log ($runBase.Replace($loginBuildLine,$loginBuildLine.Replace('6090','6089')))}
        Negative 'EXP48-87' 'login-only build evidence without MetaTester authority rejected' {Write-Lf $run1Log ($runBase.Replace($metaTesterLine+"`n",''))}
        Negative 'EXP48-88' 'malformed MetaTester build record rejected' {Write-Lf $run1Log ($runBase.Replace('MetaTester 5 build 6090','MetaTester 5 build X6090'))}
        Negative 'EXP48-89' 'unrelated payload containing 6090 without supported build record rejected' {Write-Lf $run1Log ("AB 0 09:59:59.999 Payload unrelated_value=6090`n"+$runBase.Replace($metaTesterLine+"`n",'').Replace($loginBuildLine+"`n",''))}

        Git @('-C',$repo,'checkout','--quiet','--force',$sourceCommit)|Out-Null;Set-Baseline
        Write-Lf $run2Log ($runBase.Replace('build 6090','build 6089').Replace('10:00:00','10:01:00'))
        $runDisagreement=Invoke-Exporter (Get-Args $sourceCommit $sourceTree (Join-Path $tempRoot 'EXP48-90')) 'EXP48-90.out'
        Record 'EXP48-90' 'Run 1 and Run 2 resolved build disagreement rejected' ($runDisagreement.ExitCode-ne0)

        Negative 'EXP48-91' 'raw resolved build and machine semantic build disagreement rejected' {Write-Lf $run1Log ($runBase.Replace('"deterministic":true}','"deterministic":true,"terminal_build":6089}'))}
        Negative 'EXP48-92' 'raw resolved build and verification-source canonical build disagreement rejected' {} {param($a)$i=[Array]::IndexOf($a,'-ExpectedVerificationSourceDigest');$a[$i+1]=Get-Digest $sourceCommit $sourceTree '' '6089';return $a}
    }

    function Run-ServerParserTests {
        Git @('-C',$repo,'checkout','--quiet','--force',$sourceCommit)|Out-Null;Set-Baseline
        $d3Server=Invoke-Exporter (Get-Args $sourceCommit $sourceTree (Join-Path $tempRoot 'EXP48-93')) 'EXP48-93.out'
        Record 'EXP48-93' 'D3 generating-based-on-real-ticks server authority passes' ($d3Server.ExitCode-eq0)

        Git @('-C',$repo,'checkout','--quiet','--force',$sourceCommit)|Out-Null;Set-Baseline
        Write-Lf $run1Log ($runBase.Replace($serverGenerationLine,$serverTestingLine))
        $legacyServer=Invoke-Exporter (Get-Args $sourceCommit $sourceTree (Join-Path $tempRoot 'EXP48-94')) 'EXP48-94.out'
        Record 'EXP48-94' 'legacy structured testing-of server authority passes' ($legacyServer.ExitCode-eq0)

        Git @('-C',$repo,'checkout','--quiet','--force',$sourceCommit)|Out-Null;Set-Baseline
        Write-Lf $run1Log ($runBase.Replace($serverGenerationLine,$serverGenerationLine+"`n"+$serverTestingLine))
        $duplicateServer=Invoke-Exporter (Get-Args $sourceCommit $sourceTree (Join-Path $tempRoot 'EXP48-95')) 'EXP48-95.out'
        Record 'EXP48-95' 'duplicate identical authoritative server records pass' ($duplicateServer.ExitCode-eq0)

        Negative 'EXP48-96' 'conflicting recognized server identities rejected' {Write-Lf $run1Log ($runBase.Replace($serverGenerationLine,$serverGenerationLine+"`n"+$serverTestingLine.Replace('Exness-MT5Trial6','Other-MT5Trial')))}
        Negative 'EXP48-97' 'consistently wrong Trial server rejected' {Write-Lf $run1Log ($runBase.Replace('Exness-MT5Trial6','Other-MT5Trial'))}
        Negative 'EXP48-98' 'missing authoritative server record rejected' {Write-Lf $run1Log ($runBase.Replace($serverGenerationLine+"`n",''))}
        Negative 'EXP48-99' 'server record missing closing parenthesis rejected' {Write-Lf $run1Log ($runBase.Replace('(Exness-MT5Trial6): generating','(Exness-MT5Trial6: generating'))}
        Negative 'EXP48-100' 'empty server token rejected' {Write-Lf $run1Log ($runBase.Replace('(Exness-MT5Trial6): generating','(): generating'))}
        Negative 'EXP48-101' 'truncated structured server record rejected' {Write-Lf $run1Log ($runBase.Replace('generating based on real ticks','generating based on real'))}
        Negative 'EXP48-102' 'unrelated text containing expected server is not authority' {Write-Lf $run1Log ("AB 0 09:59:59.999 Payload expected_server=Exness-MT5Trial6`n"+$runBase.Replace($serverGenerationLine+"`n",''))}

        Git @('-C',$repo,'checkout','--quiet','--force',$sourceCommit)|Out-Null;Set-Baseline
        Write-Lf $run2Log ($runBase.Replace('Exness-MT5Trial6','Other-MT5Trial').Replace('10:00:00','10:01:00'))
        $serverDisagreement=Invoke-Exporter (Get-Args $sourceCommit $sourceTree (Join-Path $tempRoot 'EXP48-103')) 'EXP48-103.out'
        Record 'EXP48-103' 'Run 1 and Run 2 resolved server disagreement rejected' ($serverDisagreement.ExitCode-ne0)

        Negative 'EXP48-104' 'raw resolved server and machine semantic server disagreement rejected' {Write-Lf $run1Log ($runBase.Replace('"deterministic":true}','"deterministic":true,"server":"Other-MT5Trial"}'))}
        Negative 'EXP48-105' 'raw resolved server and verification-source canonical server disagreement rejected' {} {param($a)$i=[Array]::IndexOf($a,'-ExpectedVerificationSourceDigest');$a[$i+1]=Get-Digest $sourceCommit $sourceTree '' '6090' 'Other-MT5Trial';return $a}
        Negative 'EXP48-106' 'valid server token from non-Trial environment rejected' {Write-Lf $run1Log ($runBase.Replace('Exness-MT5Trial6','Exness-MT5Real6'))}
        Negative 'EXP48-107' 'server record instrument differing from source-bound run config rejected' {Write-Lf $run1Log ($runBase.Replace('EURUSD,M1 (Exness-MT5Trial6)','XAUUSD,M15 (Exness-MT5Trial6)'))}
    }

    function Run-HarnessSafetyTests {
        $savedContext=$script:failureContext
        $mockDiagnostic=Join-Path $tempRoot 'EXP48-108-primary.out';Write-Lf $mockDiagnostic 'PRIMARY_GENERATE_ERROR: source bytes differ from Git blob'
        $mockFailure=[pscustomobject]@{ExitCode=17;Output=$mockDiagnostic;Arguments=@('-Mode','Generate','-OutputDirectory','mock');Exporter='mock-exporter.ps1'}
        $errorText='';try{Assert-GenerateSucceeded $mockFailure 'EXP48-108' (Join-Path $tempRoot 'EXP48-108-output')}catch{$errorText=$_.Exception.Message}
        Record 'EXP48-108' 'Generate failure preserves primary error and exit code' ($errorText.Contains('BASELINE_GENERATE_FAILED')-and$errorText.Contains('exit_code=17')-and$errorText.Contains('PRIMARY_GENERATE_ERROR'))

        $missingCompile=Join-Path $tempRoot 'EXP48-109-output';New-Item -ItemType Directory -Path $missingCompile -Force|Out-Null
        foreach($name in $requiredEvidenceNames|Where-Object{$_-ne'COMPILE_REPORT.md'}){Write-Lf (Join-Path $missingCompile $name) 'fixture'}
        $errorText='';try{Get-RequiredEvidenceHashes $missingCompile 'EXP48-109'|Out-Null}catch{$errorText=$_.Exception.Message}
        Record 'EXP48-109' 'claimed-success Generate missing COMPILE_REPORT fails explicitly' ($errorText.Contains('GENERATE_SUCCEEDED_BUT_REQUIRED_OUTPUT_MISSING')-and$errorText.Contains('artifact=COMPILE_REPORT.md'))

        $partial=Join-Path $tempRoot 'EXP48-110-output';New-Item -ItemType Directory -Path $partial -Force|Out-Null
        foreach($name in $requiredEvidenceNames|Where-Object{$_-ne'VERIFICATION_REPORT.md'}){Write-Lf (Join-Path $partial $name) 'fixture'}
        $errorText='';try{Get-RequiredEvidenceHashes $partial 'EXP48-110'|Out-Null}catch{$errorText=$_.Exception.Message}
        Record 'EXP48-110' 'partial evidence set reports exact missing artifact' ($errorText.Contains('GENERATE_SUCCEEDED_BUT_REQUIRED_OUTPUT_MISSING')-and$errorText.Contains('artifact=VERIFICATION_REPORT.md'))

        $beforeHashes=$script:requiredArtifactHashCalls;$errorText='';try{Assert-GenerateSucceeded $mockFailure 'EXP48-111' (Join-Path $tempRoot 'EXP48-111-output')}catch{$errorText=$_.Exception.Message}
        Record 'EXP48-111' 'hash step is unreachable after Generate failure' ($errorText.Contains('BASELINE_GENERATE_FAILED')-and$script:requiredArtifactHashCalls-eq$beforeHashes)

        $primary='PRIMARY_GENERATE_ERROR';$cleanupError=Invoke-SafeCleanup '' $primary {throw 'SECONDARY_CLEANUP_ERROR'}
        Record 'EXP48-112' 'cleanup failure cannot mask primary Generate error' ($primary-eq'PRIMARY_GENERATE_ERROR'-and"$cleanupError"-match'SECONDARY_CLEANUP_ERROR')

        Git @('-C',$repo,'checkout','--quiet','--force',$sourceCommit)|Out-Null;Set-Baseline
        $caseTemp=Join-Path $tempRoot 'EXP48-113-disposable';New-Item -ItemType Directory -Path $caseTemp -Force|Out-Null
        $diagnosticTarget=Join-Path ([IO.Path]::GetTempPath()) ('SWV5-S48-EXP48-113-DIAGNOSTIC-'+[guid]::NewGuid().ToString('N'))
        $caseOutput=Join-Path $caseTemp 'output';$failureArgs=Get-Args $sourceCommit $sourceTree $caseOutput;$hashIndex=[Array]::IndexOf($failureArgs,'-ExpectedRun1LogSha256');$failureArgs[$hashIndex+1]='0'*64
        $failedGenerate=Invoke-Exporter $failureArgs 'generate_all_streams.txt' $caseTemp
        $probePrimary=$null;try{Assert-GenerateSucceeded $failedGenerate 'EXP48-113' $caseOutput}catch{$probePrimary=$_}
        $probeContext=$script:failureContext
        $preservedRoot=Write-FailureDiagnostic $diagnosticTarget $probeContext $probePrimary $caseTemp
        $probeCleanupError=Invoke-SafeCleanup $caseTemp $probePrimary
        $summaryPath=Join-Path $preservedRoot 'failure_summary.json';$streamPath=Join-Path $preservedRoot 'generate_all_streams.txt'
        $summary=Get-Content -LiteralPath $summaryPath -Raw|ConvertFrom-Json;$preservedOutput=Get-Content -LiteralPath $streamPath -Raw
        $diagnosticOk=$null-ne$probePrimary-and$null-eq$probeCleanupError-and-not(Test-Path -LiteralPath $caseTemp)-and(Test-Path -LiteralPath $preservedRoot -PathType Container)-and-not(Test-IsPathWithin $preservedRoot $caseTemp)-and$summary.exporter_path-eq[IO.Path]::GetFullPath($fixtureExporter)-and$summary.failing_test_id-eq'EXP48-113'-and$summary.stage-eq'generate'-and[int]$summary.exit_code-ne0-and$summary.primary_error.Contains('BASELINE_GENERATE_FAILED')-and$preservedOutput.Contains('SPRINT48_EXPORT_VALIDATION_FAILED')
        $script:diagnosticProbe=[ordered]@{root=$preservedRoot;disposable=$caseTemp;summary=$summary;preserved_output=$preservedOutput;passed=$diagnosticOk}
        Record 'EXP48-113' 'failed case preserves authoritative diagnostic bundle outside cleaned workspace' $diagnosticOk

        $cleanupTarget=Join-Path $tempRoot 'EXP48-114-cleanup';New-Item -ItemType Directory -Path $cleanupTarget -Force|Out-Null;Write-Lf (Join-Path $cleanupTarget 'temporary.txt') 'temporary';Invoke-SafeCleanup $cleanupTarget $null|Out-Null
        Record 'EXP48-114' 'successful case may clean temporary workspace' (-not(Test-Path -LiteralPath $cleanupTarget))

        $errorText='';try{Resolve-CanonicalOutputDirectory ([string][char]0)|Out-Null}catch{$errorText=$_.Exception.Message}
        Record 'EXP48-115' 'malformed output path fails deterministically' $errorText.StartsWith('INVALID_OUTPUT_DIRECTORY|')

        Git @('-C',$repo,'checkout','--quiet','--force',$sourceCommit)|Out-Null;Set-Baseline
        $specialOutput=Resolve-CanonicalOutputDirectory (Join-Path $tempRoot 'EXP48-116 space & [special]')
        $specialArgs=Get-Args $sourceCommit $sourceTree $specialOutput;$special=Invoke-Exporter $specialArgs 'EXP48-116.out';$specialError=''
        try{Assert-GenerateSucceeded $special 'EXP48-116' $specialOutput;$specialHashes=Get-RequiredEvidenceHashes $specialOutput 'EXP48-116'}catch{$specialError=$_.Exception.Message;$specialHashes=$null}
        Record 'EXP48-116' 'spaces and special Windows output path preserve argument semantics' ($specialError-eq''-and$null-ne$specialHashes-and$specialHashes.Count-eq$requiredEvidenceNames.Count)

        $outputIndex=[Array]::IndexOf($specialArgs,'-OutputDirectory');$argumentOutput=Resolve-CanonicalOutputDirectory $specialArgs[$outputIndex+1]
        Record 'EXP48-117' 'baseline output directory resolution equals exporter target' ($argumentOutput-eq$specialOutput-and(Get-ProducedFileInventory $specialOutput).Count-eq$requiredEvidenceNames.Count)
        $script:failureContext=$savedContext
    }

    function Run-IdentityAuthorityTests {
        $exporterIdentity=$null;$identityError='';try{$exporterIdentity=Assert-ExecutingFileIdentity $fixtureExporter $fixtureExporterSha 'EXP48-118-fixture-exporter'}catch{$identityError=$_.Exception.Message}
        Record 'EXP48-118' 'executing fixture exporter exact SHA equals source Git blob' ($identityError-eq''-and$exporterIdentity.actual_sha256-eq$fixtureExporterSha)

        $crlfExporter=Join-Path $tempRoot 'EXP48-119-exporter-crlf.ps1';$exporterText=[IO.File]::ReadAllText($fixtureExporter);[IO.File]::WriteAllText($crlfExporter,(($exporterText-replace"`r?`n","`r`n").TrimEnd("`r","`n")+"`r`n"),$Utf8NoBom)
        $generateStarted=$false;$identityError='';try{Assert-ExecutingFileIdentity $crlfExporter $fixtureExporterSha 'EXP48-119-exporter-crlf'|Out-Null;$generateStarted=$true}catch{$identityError=$_.Exception.Message}
        Record 'EXP48-119' 'CRLF exporter mismatch fails before Generate starts' (-not$generateStarted-and$identityError.Contains('EXECUTING_FILE_IDENTITY_MISMATCH'))

        $activeIdentity=$null;$identityError='';try{$activeIdentity=Assert-ExecutingFileIdentity $activeHarnessPath $fixtureTestScriptSha 'EXP48-120-active-harness'}catch{$identityError=$_.Exception.Message}
        Record 'EXP48-120' 'active and fixture test-script exact byte identity passes' ($identityError-eq''-and$activeIdentity.actual_sha256-eq$fixtureTestSourceSha-and$fixtureTestSourceSha-eq$fixtureTestScriptSha)

        $crlfHarness=Join-Path $tempRoot 'EXP48-121-harness-crlf.ps1';$harnessText=[IO.File]::ReadAllText($fixtureTestScript);[IO.File]::WriteAllText($crlfHarness,(($harnessText-replace"`r?`n","`r`n").TrimEnd("`r","`n")+"`r`n"),$Utf8NoBom)
        $identityError='';try{Assert-ExecutingFileIdentity $crlfHarness $fixtureTestScriptSha 'EXP48-121-test-script-crlf'|Out-Null}catch{$identityError=$_.Exception.Message}
        Record 'EXP48-121' 'CRLF test-script mismatch is rejected' $identityError.Contains('EXECUTING_FILE_IDENTITY_MISMATCH')

        Record 'EXP48-122' 'fixture source test-script bytes equal Git blob bytes' ($fixtureTestSourceSha-eq$fixtureTestScriptSha-and$activeTestScriptSha-eq$fixtureTestSourceSha)
        $materializedIdentity=Assert-ExecutingFileIdentity $fixtureTestScript $fixtureTestScriptSha 'EXP48-123-materialized-test-script'
        Record 'EXP48-123' 'materialized test-script bytes equal Git blob bytes' ($materializedIdentity.actual_sha256-eq$fixtureTestScriptSha)

        $identityError='';try{Assert-ExecutingFileIdentity $activeHarnessPath '' 'EXP48-124-missing-authority'|Out-Null}catch{$identityError=$_.Exception.Message}
        Record 'EXP48-124' 'identity assertion requires independently supplied expected SHA' $identityError.Contains('IDENTITY_EXPECTED_SHA_REQUIRED')

        $probeSummary=$script:diagnosticProbe.summary
        Record 'EXP48-125' 'diagnostic summary serializes resolved exporter path' ($probeSummary.schema-eq'SWV5-SPRINT48-HARNESS-FAILURE-V2'-and$probeSummary.exporter_path-eq[IO.Path]::GetFullPath($fixtureExporter))

        $insideRoot=Join-Path $tempRoot 'EXP48-126-inside';$outsideRoot=Join-Path ([IO.Path]::GetTempPath()) ('SWV5-S48-EXP48-126-'+[guid]::NewGuid().ToString('N'));$insideError=''
        try{Assert-ExternalDiagnosticRoot $insideRoot $tempRoot|Out-Null}catch{$insideError=$_.Exception.Message}
        $outsideCanonical=Assert-ExternalDiagnosticRoot $outsideRoot $tempRoot
        Record 'EXP48-126' 'diagnostic root must be outside disposable workspace' ($insideError.Contains('DIAGNOSTIC_ROOT_INSIDE_DISPOSABLE_WORKSPACE')-and-not(Test-IsPathWithin $outsideCanonical $tempRoot))

        $probeRoot=[string]$script:diagnosticProbe.root;$probeDisposable=[string]$script:diagnosticProbe.disposable
        $survives=-not(Test-Path -LiteralPath $probeDisposable)-and(Test-Path -LiteralPath (Join-Path $probeRoot 'failure_summary.json') -PathType Leaf)-and(Test-Path -LiteralPath (Join-Path $probeRoot 'generate_all_streams.txt') -PathType Leaf)-and$script:diagnosticProbe.preserved_output.Contains('SPRINT48_EXPORT_VALIDATION_FAILED')
        Record 'EXP48-127' 'diagnostic bundle survives disposable cleanup end to end' $survives
        Invoke-SafeCleanup $probeRoot $null|Out-Null
    }

    function New-VolatileRuntimeContext([string]$Root,[int]$ProcessId) {
        return [pscustomobject][ordered]@{execution_path=Join-Path $Root 'execution\Test-Export-Sprint48Evidence.ps1';materialized_path=Join-Path $Root 'materialized\Test-Export-Sprint48Evidence.ps1';output_path=Join-Path $Root 'output\exporter_test_results.json';diagnostic_path=Join-Path $Root 'diagnostic\failure_summary.json';workspace_path=$Root;process_id=$ProcessId}
    }
    function Test-RuntimeContextAbsent([string]$Json,[object]$Context) {
        foreach($name in @('execution_path','materialized_path','output_path','diagnostic_path','workspace_path','process_id')){
            $value=[string]$Context.$name;$escaped=($value|ConvertTo-Json -Compress).Trim('"')
            if($Json.Contains($value)-or$Json.Contains($escaped)){return $false}
        }
        return $true
    }
    function Write-CredibilityProof {
        if(-not[string]::IsNullOrWhiteSpace($CredibilityProofPath)){
            $proof=[pscustomobject][ordered]@{schema='SWV5-SPRINT48-B116-CREDIBILITY-PROOF-V1';run_workspace=[IO.Path]::GetFullPath($tempRoot);proof=$script:credibilityProof}
            Write-Lf $CredibilityProofPath (ConvertTo-CanonicalJsonText $proof 12)
        }
    }
    function Run-CredibilityClosureTests([bool]$IncludeSerializationTest) {
        $probeCases=@([pscustomobject][ordered]@{id='PROBE-001';name='canonical ordering probe one';passed=$true},[pscustomobject][ordered]@{id='PROBE-002';name='canonical ordering probe two';passed=$true})
        $rootA=[IO.Path]::GetFullPath((Join-Path ([IO.Path]::GetTempPath()) ('SWV5_B116_A_'+[guid]::NewGuid().ToString('N'))))
        $rootB=[IO.Path]::GetFullPath((Join-Path ([IO.Path]::GetTempPath()) ('SWV5_B116_B_'+[guid]::NewGuid().ToString('N'))))
        $runtimeA=New-VolatileRuntimeContext $rootA 13701;$runtimeB=New-VolatileRuntimeContext $rootB 13702
        $scenarioA=[pscustomobject][ordered]@{cases=$probeCases;provenance=$identityProvenance;test_script_sha=$fixtureTestScriptSha;active_sha=$activeTestScriptSha;runtime_context=$runtimeA}
        $scenarioB=[pscustomobject][ordered]@{cases=@($probeCases|ForEach-Object{[pscustomobject][ordered]@{id=$_.id;name=$_.name;passed=[bool]$_.passed}});provenance=$identityProvenance;test_script_sha=$fixtureTestScriptSha;active_sha=$activeTestScriptSha;runtime_context=$runtimeB}
        $stableA=ConvertTo-CanonicalJsonText ([pscustomobject][ordered]@{cases=$scenarioA.cases;provenance=$scenarioA.provenance;test_script_sha=$scenarioA.test_script_sha;active_sha=$scenarioA.active_sha}) 12
        $stableB=ConvertTo-CanonicalJsonText ([pscustomobject][ordered]@{cases=$scenarioB.cases;provenance=$scenarioB.provenance;test_script_sha=$scenarioB.test_script_sha;active_sha=$scenarioB.active_sha}) 12
        $before=$script:canonicalBuilderInvocations
        $canonicalA=ConvertTo-CanonicalJsonText (New-CanonicalExporterResult $scenarioA.cases $scenarioA.provenance $scenarioA.test_script_sha $scenarioA.active_sha $scenarioA.runtime_context) 12
        $afterA=$script:canonicalBuilderInvocations
        $canonicalB=ConvertTo-CanonicalJsonText (New-CanonicalExporterResult $scenarioB.cases $scenarioB.provenance $scenarioB.test_script_sha $scenarioB.active_sha $scenarioB.runtime_context) 12
        $afterB=$script:canonicalBuilderInvocations
        $shaA=Get-ShaBytes $Utf8NoBom.GetBytes($canonicalA);$shaB=Get-ShaBytes $Utf8NoBom.GetBytes($canonicalB)
        $volatileDifferent=$runtimeA.workspace_path-ne$runtimeB.workspace_path-and$runtimeA.execution_path-ne$runtimeB.execution_path-and$runtimeA.output_path-ne$runtimeB.output_path-and$runtimeA.diagnostic_path-ne$runtimeB.diagnostic_path
        $builderInvoked=$afterA-eq($before+1)-and$afterB-eq($afterA+1)
        $stablePresent=$canonicalA.Contains($exporterRepositoryPath)-and$canonicalA.Contains($sourceCommit)-and$canonicalA.Contains($sourceTree)-and$canonicalA.Contains($fixtureTestScriptSha)
        $pathsAbsent=(Test-RuntimeContextAbsent $canonicalA $runtimeA)-and(Test-RuntimeContextAbsent $canonicalB $runtimeB)
        Record 'EXP48-137' 'real builder isolates differing complete volatile runtime contexts' ($volatileDifferent-and$stableA-eq$stableB-and$builderInvoked-and$canonicalA-eq$canonicalB-and$shaA-eq$shaB-and$pathsAbsent-and$stablePresent)
        if($IncludeSerializationTest){$canonicalBytes=$Utf8NoBom.GetBytes($canonicalA);$hasBom=$canonicalBytes.Length-ge3-and$canonicalBytes[0]-eq239-and$canonicalBytes[1]-eq187-and$canonicalBytes[2]-eq191;Record 'EXP48-138' 'canonical JSON is UTF-8 no BOM LF-only with exactly one final LF' (-not$hasBom-and-not($canonicalBytes-contains13)-and$canonicalBytes[-1]-eq10-and$canonicalBytes[-2]-ne10)}

        $affectedPath=$testScriptRepositoryPath
        $baseSources=Get-ExplicitFixtureSources $repo $sourceCommit
        $mutatedSources=@();$mutationDescription='append harmless TEST ONLY PowerShell comment: # B11.6 deterministic source mutation probe'
        foreach($source in $baseSources){
            $bytes=[byte[]]$source.bytes
            if($source.path-eq$affectedPath){$baseText=$Utf8NoBom.GetString($bytes);$bytes=$Utf8NoBom.GetBytes(($baseText.TrimEnd("`r","`n")+"`n# B11.6 deterministic source mutation probe`n"))}
            else{$copy=[byte[]]::new($bytes.Length);[Array]::Copy($bytes,$copy,$bytes.Length);$bytes=$copy}
            $mutatedSources += [pscustomobject][ordered]@{path=$source.path;bytes=$bytes}
        }
        $baseAuthority=New-ExplicitFixtureRepository (Join-Path $tempRoot 'mutation-base') $baseSources
        $mutatedAuthority=New-ExplicitFixtureRepository (Join-Path $tempRoot 'mutation-changed') $mutatedSources
        $baseEntry=@($baseAuthority.entries|Where-Object{$_.path-eq$affectedPath})[0];$mutatedEntry=@($mutatedAuthority.entries|Where-Object{$_.path-eq$affectedPath})[0]
        $baseProvenance=New-FixtureCanonicalProvenance $baseAuthority;$mutatedProvenance=New-FixtureCanonicalProvenance $mutatedAuthority
        $baseCanonical=ConvertTo-CanonicalJsonText (New-CanonicalExporterResult $probeCases $baseProvenance $baseEntry.blob_sha256 $baseEntry.source_sha256 $runtimeA) 12
        $mutatedCanonical=ConvertTo-CanonicalJsonText (New-CanonicalExporterResult $probeCases $mutatedProvenance $mutatedEntry.blob_sha256 $mutatedEntry.source_sha256 $runtimeB) 12
        $baseCanonicalSha=Get-ShaBytes $Utf8NoBom.GetBytes($baseCanonical);$mutatedCanonicalSha=Get-ShaBytes $Utf8NoBom.GetBytes($mutatedCanonical)
        $unrelatedBase=@($baseAuthority.entries|Where-Object{$_.path-ne$affectedPath});$unrelatedMutated=@($mutatedAuthority.entries|Where-Object{$_.path-ne$affectedPath});$unrelatedEqual=$unrelatedBase.Count-eq$unrelatedMutated.Count
        if($unrelatedEqual){for($i=0;$i-lt$unrelatedBase.Count;$i++){$unrelatedEqual=$unrelatedEqual-and$unrelatedBase[$i].path-eq$unrelatedMutated[$i].path-and$unrelatedBase[$i].blob-eq$unrelatedMutated[$i].blob}}
        $baseMaterialized=$baseEntry.source_sha256-eq$baseEntry.blob_sha256-and$baseEntry.blob_sha256-eq$baseEntry.materialized_sha256
        $mutatedMaterialized=$mutatedEntry.source_sha256-eq$mutatedEntry.blob_sha256-and$mutatedEntry.blob_sha256-eq$mutatedEntry.materialized_sha256
        $identityBase=ConvertTo-CanonicalJsonText $baseProvenance 12;$identityMutated=ConvertTo-CanonicalJsonText $mutatedProvenance 12
        $mutationPass=$baseEntry.source_sha256-ne$mutatedEntry.source_sha256-and$baseEntry.blob-ne$mutatedEntry.blob-and$baseAuthority.tree-ne$mutatedAuthority.tree-and$baseAuthority.commit-ne$mutatedAuthority.commit-and$identityBase-ne$identityMutated-and$baseCanonical-ne$mutatedCanonical-and$baseCanonicalSha-ne$mutatedCanonicalSha-and$unrelatedEqual-and$baseMaterialized-and$mutatedMaterialized
        Record 'EXP48-139' 'real source-byte mutation rebuilds distinct blob tree commit and canonical result' $mutationPass

        $negativeProvenance=($identityProvenance|ConvertTo-Json -Depth 12|ConvertFrom-Json);$negativeProvenance.fixture_tree=$mutatedAuthority.tree
        $negativeCanonical=ConvertTo-CanonicalJsonText (New-CanonicalExporterResult $probeCases $negativeProvenance $fixtureTestScriptSha $activeTestScriptSha $runtimeA) 12;$negativeSha=Get-ShaBytes $Utf8NoBom.GetBytes($negativeCanonical)
        Record 'EXP48-140' 'canonical source-bound field negative control changes bytes and SHA' ($canonicalA-ne$negativeCanonical-and$shaA-ne$negativeSha)

        $script:credibilityProof=[ordered]@{
            diagnostic_isolation=[ordered]@{runtime_a=$runtimeA;runtime_b=$runtimeB;stable_inputs_equal=($stableA-eq$stableB);builder_invoked_a=($afterA-eq($before+1));builder_invoked_b=($afterB-eq($afterA+1));canonical_sha_a=$shaA;canonical_sha_b=$shaB;canonical_bytes_equal=($canonicalA-eq$canonicalB);paths_absent=$pathsAbsent;stable_provenance_present=$stablePresent;negative_control_sha=$negativeSha;negative_control_differs=($shaA-ne$negativeSha)}
            source_mutation=[ordered]@{logical_path=$affectedPath;description=$mutationDescription;base=[ordered]@{source_sha256=$baseEntry.source_sha256;blob=$baseEntry.blob;tree=$baseAuthority.tree;commit=$baseAuthority.commit;materialized_sha256=$baseEntry.materialized_sha256;canonical_result_sha256=$baseCanonicalSha};mutated=[ordered]@{source_sha256=$mutatedEntry.source_sha256;blob=$mutatedEntry.blob;tree=$mutatedAuthority.tree;commit=$mutatedAuthority.commit;materialized_sha256=$mutatedEntry.materialized_sha256;canonical_result_sha256=$mutatedCanonicalSha};inequalities=[ordered]@{source_sha=($baseEntry.source_sha256-ne$mutatedEntry.source_sha256);blob=($baseEntry.blob-ne$mutatedEntry.blob);tree=($baseAuthority.tree-ne$mutatedAuthority.tree);commit=($baseAuthority.commit-ne$mutatedAuthority.commit);canonical_identity=($identityBase-ne$identityMutated);canonical_bytes=($baseCanonical-ne$mutatedCanonical);canonical_sha=($baseCanonicalSha-ne$mutatedCanonicalSha);unrelated_blobs_equal=$unrelatedEqual}}
        }
    }
    function Run-DeterminismTests {
        $replicaBlobs=@($fixtureReplica.blobs);$blobEquality=$sourceBlobManifest.Count-eq$replicaBlobs.Count
        if($blobEquality){for($i=0;$i-lt$sourceBlobManifest.Count;$i++){$blobEquality=$blobEquality-and$sourceBlobManifest[$i].path-eq$replicaBlobs[$i].path-and$sourceBlobManifest[$i].blob-eq$replicaBlobs[$i].blob}}
        Record 'EXP48-128' 'identical explicit fixture bytes produce identical Git blobs' $blobEquality
        Record 'EXP48-129' 'independent explicit fixture construction produces identical tree' ($sourceTree-eq$fixtureReplica.tree)
        Record 'EXP48-130' 'independent explicit fixture construction produces identical commit' ($sourceCommit-eq$fixtureReplica.commit)
        Record 'EXP48-131' 'independent temporary roots do not affect fixture commit' (([IO.Path]::GetFullPath($repo))-ne([IO.Path]::GetFullPath($fixtureReplica.root))-and$sourceCommit-eq$fixtureReplica.commit)
        $fixedInstant=[DateTimeOffset]::Parse($fixtureGitTimestamp).ToUniversalTime();$timestampsFixed=@($sourceAuthorDate,$sourceCommitterDate,$fixtureReplica.author_date,$fixtureReplica.committer_date)|ForEach-Object{[DateTimeOffset]::Parse([string]$_).ToUniversalTime()}|Where-Object{$_-ne$fixedInstant}|Measure-Object
        Record 'EXP48-132' 'fixed synthetic author and committer timestamps exclude wall-clock authority' ($timestampsFixed.Count-eq0)
        $probeCases=@([pscustomobject][ordered]@{id='PROBE-001';name='canonical ordering probe one';passed=$true},[pscustomobject][ordered]@{id='PROBE-002';name='canonical ordering probe two';passed=$true})
        $canonicalA=ConvertTo-CanonicalJsonText (New-CanonicalExporterResult $probeCases $identityProvenance $fixtureTestScriptSha $activeTestScriptSha $actualRuntimeContext) 12;$canonicalB=ConvertTo-CanonicalJsonText (New-CanonicalExporterResult @($probeCases|ForEach-Object{[pscustomobject][ordered]@{id=$_.id;name=$_.name;passed=[bool]$_.passed}}) $identityProvenance $fixtureTestScriptSha $activeTestScriptSha $actualRuntimeContext) 12
        $volatilePattern='(?i)([A-Z]:\\|AppData|\\Temp\\|SWV5-S48-EXPORT-[0-9a-f]{32}|[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}|execution_path|materialized_path|active_execution_path|process_id|hostname|username)'
        Record 'EXP48-133' 'canonical result excludes absolute temporary and GUID execution paths' (-not[regex]::IsMatch($canonicalA,$volatilePattern))
        Record 'EXP48-134' 'independent canonical result construction produces identical JSON bytes' ($canonicalA-eq$canonicalB)
        Record 'EXP48-135' 'independent canonical result construction produces identical raw SHA-256' ((Get-ShaBytes $Utf8NoBom.GetBytes($canonicalA))-eq(Get-ShaBytes $Utf8NoBom.GetBytes($canonicalB)))
        $parsed=$canonicalA|ConvertFrom-Json;$propertyOrder=@($parsed.psobject.Properties.Name)-join'|';$expectedOrder='schema|exporter_path|exporter_sha256|test_script_sha256|active_test_script_sha256|identity_provenance|generated_from|total|passed|failed|skipped|signature|cases'
        Record 'EXP48-136' 'canonical property order and test-case order are exact' ($propertyOrder-eq$expectedOrder-and(@($parsed.cases.id)-join'|')-eq'PROBE-001|PROBE-002')
        Run-CredibilityClosureTests $true
    }

    if($CredibilityOnly){
        Run-CredibilityClosureTests $false;Write-CredibilityProof
        $targeted=New-CanonicalExporterResult $records $identityProvenance $fixtureTestScriptSha $activeTestScriptSha $actualRuntimeContext
        $targetedJson=ConvertTo-CanonicalJsonText $targeted 12;if(-not[string]::IsNullOrWhiteSpace($ResultPath)){[IO.File]::WriteAllText($ResultPath,$targetedJson,$Utf8NoBom)};$targetedJson
        if($failed-ne0-or$passed-ne3){throw "CREDIBILITY_SUITE_FAILED|passed=$passed|failed=$failed"};$scriptSucceeded=$true;return
    }

    if($DeterminismOnly){
        Run-DeterminismTests;Write-CredibilityProof
        $targeted=New-CanonicalExporterResult $records
        $targetedJson=ConvertTo-CanonicalJsonText $targeted 10;if(-not[string]::IsNullOrWhiteSpace($ResultPath)){[IO.File]::WriteAllText($ResultPath,$targetedJson,$Utf8NoBom)};$targetedJson
        if($failed-ne0-or$passed-ne13){throw "DETERMINISM_SUITE_FAILED|passed=$passed|failed=$failed"};$scriptSucceeded=$true;return
    }

    if($IdentityDiagnosticOnly){
        Run-HarnessSafetyTests
        Run-IdentityAuthorityTests
        $targeted=[pscustomobject][ordered]@{schema='SWV5-SPRINT48-IDENTITY-DIAGNOSTIC-TEST-V1';total=20;passed=$passed;failed=$failed;skipped=0;identity_provenance=$identityProvenance;cases=$records}
        $targetedJson=$targeted|ConvertTo-Json -Depth 8;if(-not[string]::IsNullOrWhiteSpace($ResultPath)){Write-Lf $ResultPath $targetedJson};$targetedJson
        if($failed-ne0-or$passed-ne20){throw "IDENTITY_DIAGNOSTIC_SUITE_FAILED|passed=$passed|failed=$failed"};$scriptSucceeded=$true;return
    }
    if($BuildParserOnly){
        Run-BuildParserTests
        $targeted=[pscustomobject][ordered]@{schema='SWV5-SPRINT48-BUILD-PARSER-TEST-V1';total=10;passed=$passed;failed=$failed;skipped=0;cases=$records}
        $targetedJson=$targeted|ConvertTo-Json -Depth 6;if(-not[string]::IsNullOrWhiteSpace($ResultPath)){Write-Lf $ResultPath $targetedJson};$targetedJson
        if($failed-ne0-or$passed-ne10){throw "BUILD_PARSER_SUITE_FAILED|passed=$passed|failed=$failed"};$scriptSucceeded=$true;return
    }
    if($ServerParserOnly){
        Run-ServerParserTests
        $targeted=[pscustomobject][ordered]@{schema='SWV5-SPRINT48-SERVER-PARSER-TEST-V1';total=15;passed=$passed;failed=$failed;skipped=0;cases=$records}
        $targetedJson=$targeted|ConvertTo-Json -Depth 6;if(-not[string]::IsNullOrWhiteSpace($ResultPath)){Write-Lf $ResultPath $targetedJson};$targetedJson
        if($failed-ne0-or$passed-ne15){throw "SERVER_PARSER_SUITE_FAILED|passed=$passed|failed=$failed"};$scriptSucceeded=$true;return
    }

    Set-Baseline;$outA=Resolve-CanonicalOutputDirectory (Join-Path $repo 'OutA');$outB=Resolve-CanonicalOutputDirectory (Join-Path $repo 'OutB')
    $a=Invoke-Exporter (Get-Args $sourceCommit $sourceTree $outA) 'valid-a.out';Assert-GenerateSucceeded $a 'EXP48-01' $outA;$hashesA=Get-RequiredEvidenceHashes $outA 'EXP48-01';Record 'EXP48-01' 'valid explicit generation' $true
    $b=Invoke-Exporter (Get-Args $sourceCommit $sourceTree $outB) 'valid-b.out';Assert-GenerateSucceeded $b 'EXP48-02' $outB;$hashesB=Get-RequiredEvidenceHashes $outB 'EXP48-02';$names=$requiredEvidenceNames;$same=$true;foreach($n in $names){$same=$same-and($hashesA[$n]-eq$hashesB[$n])};Record 'EXP48-02' 'repeated generation byte-identical' $same
    $bom=$false;$lf=$true;$final=$true;foreach($n in $names){$bytes=[IO.File]::ReadAllBytes((Join-Path $outA $n));$bom=$bom-or($bytes.Length-ge3-and$bytes[0]-eq239-and$bytes[1]-eq187-and$bytes[2]-eq191);$lf=$lf-and-not($bytes-contains13);$final=$final-and$bytes.Length-ge2-and$bytes[-1]-eq10-and$bytes[-2]-ne10};Record 'EXP48-03' 'UTF-8 has no BOM' (-not$bom);Record 'EXP48-04' 'LF-only output' $lf;Record 'EXP48-05' 'exactly one final LF' $final
    $report=Get-Content -LiteralPath (Join-Path $outA 'VERIFICATION_REPORT.md') -Raw;Record 'EXP48-06' 'source fields expand to values' ($report.Contains($sourceCommit)-and-not$report.Contains('$source'))
    $json=Get-Content -LiteralPath (Join-Path $outA 'contract_test_results.json') -Raw|ConvertFrom-Json;Record 'EXP48-07' 'machine result preserves source identity' ($json.tested_source_commit-eq$sourceCommit-and$json.source_tree-eq$sourceTree)

    $evidence=Join-Path $repo 'FusionProV5\Evidence\Sprint4_8';Set-Baseline;$g=Invoke-Exporter (Get-Args $sourceCommit $sourceTree $evidence) 'evidence.out';Git @('-C',$repo,'add','FusionProV5/Evidence/Sprint4_8/COMPILE_REPORT.md','FusionProV5/Evidence/Sprint4_8/VERIFICATION_REPORT.md','FusionProV5/Evidence/Sprint4_8/contract_test_results.json','FusionProV5/Evidence/Sprint4_8/sprint4_8_tester_evidence.txt','FusionProV5/Evidence/Sprint4_8/exporter_test_results.json')|Out-Null
    $blobManifest=Join-Path $evidence 'evidence_blob_manifest.json';$im=Invoke-Exporter @('-Mode','IndexManifest','-RepositoryRoot',$repo,'-OutputDirectory',$evidence,'-TestedSourceSha',$sourceCommit,'-ExpectedSourceTreeSha',$sourceTree) 'index-manifest.out';Git @('-C',$repo,'add','FusionProV5/Evidence/Sprint4_8/evidence_blob_manifest.json')|Out-Null;$iv=Invoke-Exporter @('-Mode','VerifyIndex','-RepositoryRoot',$repo,'-EvidenceManifestPath',$blobManifest,'-TestedSourceSha',$sourceCommit,'-ExpectedSourceTreeSha',$sourceTree) 'index-verify.out';Record 'EXP48-08' 'index manifest verifies staged blobs' ($g.ExitCode-eq0-and$im.ExitCode-eq0-and$iv.ExitCode-eq0)
    $mo=Get-Content -LiteralPath $blobManifest -Raw|ConvertFrom-Json;Record 'EXP48-09' 'manifest excludes itself' (-not(@($mo.evidence_files.path)-match'evidence_blob_manifest'));Record 'EXP48-10' 'manifest has exact semantic set' (@($mo.evidence_files).Count-eq5)
    Git @('-C',$repo,'-c','user.name=SWV5 Test','-c','user.email=swv5-test@example.invalid','commit','--quiet','-m','fixture evidence')|Out-Null;$evidenceCommit=Git @('-C',$repo,'rev-parse','HEAD');$cv=Invoke-Exporter @('-Mode','VerifyCommit','-RepositoryRoot',$repo,'-EvidenceManifestPath',$blobManifest,'-EvidenceCommitSha',$evidenceCommit,'-TestedSourceSha',$sourceCommit,'-ExpectedSourceTreeSha',$sourceTree) 'commit-verify.out';Record 'EXP48-11' 'committed blobs verify' ($cv.ExitCode-eq0)
    $fresh=Join-Path $tempRoot 'fresh';Git @('clone','--quiet','--no-hardlinks',$repo,$fresh)|Out-Null;$fv=Invoke-Exporter @('-Mode','VerifyCommit','-RepositoryRoot',$fresh,'-EvidenceManifestPath',(Join-Path $fresh 'FusionProV5\Evidence\Sprint4_8\evidence_blob_manifest.json'),'-EvidenceCommitSha',$evidenceCommit,'-TestedSourceSha',$sourceCommit,'-ExpectedSourceTreeSha',$sourceTree) 'fresh.out';Record 'EXP48-12' 'fresh clone reproduces commit evidence' ($fv.ExitCode-eq0)
    $freshReport=Join-Path $fresh 'FusionProV5\Evidence\Sprint4_8\VERIFICATION_REPORT.md';$t=Get-Content -LiteralPath $freshReport -Raw;[IO.File]::WriteAllText($freshReport,(($t-replace"`r?`n","`r`n").TrimEnd("`r","`n")+"`r`n"),$Utf8NoBom);$cr=Invoke-Exporter @('-Mode','VerifyCommit','-RepositoryRoot',$fresh,'-EvidenceManifestPath',(Join-Path $fresh 'FusionProV5\Evidence\Sprint4_8\evidence_blob_manifest.json'),'-EvidenceCommitSha',$evidenceCommit,'-TestedSourceSha',$sourceCommit,'-ExpectedSourceTreeSha',$sourceTree) 'crlf.out';Record 'EXP48-13' 'working CRLF cannot alter commit blob' ($cr.ExitCode-eq0)
    Git @('-C',$repo,'restore','--source',$evidenceCommit,'--staged','--worktree','.')|Out-Null;Add-Content -LiteralPath (Join-Path $evidence 'VERIFICATION_REPORT.md') 'mutation';Git @('-C',$repo,'add','FusionProV5/Evidence/Sprint4_8/VERIFICATION_REPORT.md')|Out-Null;$mv=Invoke-Exporter @('-Mode','VerifyIndex','-RepositoryRoot',$repo,'-EvidenceManifestPath',$blobManifest,'-TestedSourceSha',$sourceCommit,'-ExpectedSourceTreeSha',$sourceTree) 'mutation.out';Record 'EXP48-14' 'post-export mutation rejected' ($mv.ExitCode-ne0)
    Git @('-C',$repo,'restore','--source',$evidenceCommit,'--staged','--worktree','.')|Out-Null;$mo=Get-Content -LiteralPath $blobManifest -Raw|ConvertFrom-Json;$mo.evidence_files[0].sha256='0'*64;Write-Lf $blobManifest ($mo|ConvertTo-Json -Depth 8);Git @('-C',$repo,'add','FusionProV5/Evidence/Sprint4_8/evidence_blob_manifest.json')|Out-Null;$sv=Invoke-Exporter @('-Mode','VerifyIndex','-RepositoryRoot',$repo,'-EvidenceManifestPath',$blobManifest,'-TestedSourceSha',$sourceCommit,'-ExpectedSourceTreeSha',$sourceTree) 'stale.out';Record 'EXP48-15' 'stale claim rejected' ($sv.ExitCode-ne0)

    Negative 'EXP48-16' 'wrong source rejected' {} {param($a)$i=[Array]::IndexOf($a,'-TestedSourceSha');$a[$i+1]='0'*40;return $a}
    Negative 'EXP48-17' 'wrong tree rejected' {} {param($a)$i=[Array]::IndexOf($a,'-ExpectedSourceTreeSha');$a[$i+1]='0'*40;return $a}
    Negative 'EXP48-18' 'Run 1 raw hash mismatch rejected' {} {param($a)$i=[Array]::IndexOf($a,'-ExpectedRun1LogSha256');$a[$i+1]='0'*64;return $a}
    Negative 'EXP48-19' 'duplicate machine result rejected' {Add-Content -LiteralPath $run1Log $machine}
    Negative 'EXP48-20' 'signature mismatch rejected' {Write-Lf $run2Log ($runBase.Replace('12393352988365616976','1').Replace('10:00:00','10:01:00'))}
    Negative 'EXP48-21' 'compile warning rejected' {Write-Lf $testLog "Result: 0 errors, 1 warnings, 100 ms elapsed, cpu='X64 Regular'"}
    Negative 'EXP48-22' 'compile error rejected' {Write-Lf $archLog "Result: 1 errors, 0 warnings, 100 ms elapsed, cpu='X64 Regular'"}
    Negative 'EXP48-23' 'skipped count rejected' {Write-Lf $run1Log ($runBase.Replace('"passed":934,"failed":0,"skipped":0','"passed":933,"failed":0,"skipped":1'))}
    Negative 'EXP48-24' 'failed count rejected' {Write-Lf $run1Log ($runBase.Replace('"passed":934,"failed":0','"passed":933,"failed":1'))}
    Negative 'EXP48-25' 'total mismatch rejected' {Write-Lf $run1Log ($runBase.Replace('"total":934,"passed":934','"total":933,"passed":933'))}
    Negative 'EXP48-26' 'schema mismatch rejected' {Write-Lf $run1Log ($runBase.Replace('SWV5-CONTRACT-TEST-RESULT-V5','SWV5-CONTRACT-TEST-RESULT-V4'))}
    Negative 'EXP48-27' 'policy mismatch rejected' {Write-Lf $run1Log ($runBase.Replace('SWV5-PRODUCTION-V5','SWV5-PRODUCTION-V4'))}
    Negative 'EXP48-28' 'suite mismatch rejected' {Write-Lf $run1Log ($runBase.Replace('SPRINT4.8-V5-FULL','SPRINT4.8-WRONG'))}
    Negative 'EXP48-29' 'terminal build mismatch rejected' {Write-Lf $run1Log ($runBase.Replace('build 6090','build 6089'))}
    Negative 'EXP48-30' 'Demo server mismatch rejected' {Write-Lf $run1Log ($runBase.Replace('Exness-MT5Trial6','Live-Server'))}
    Negative 'EXP48-31' 'OnTester mismatch rejected' {Write-Lf $run1Log ($runBase.Replace('SWV5_ONTESTER_SUCCESS result=1','SWV5_ONTESTER_SUCCESS result=0'))}
    Negative 'EXP48-32' 'missing explicit run rejected' {} {param($a)$i=[Array]::IndexOf($a,'-Run2Log');$a[$i+1]=Join-Path $tempRoot 'missing.log';return $a}
    Negative 'EXP48-33' 'compiled artifact hash mismatch rejected' {} {param($a)$i=[Array]::IndexOf($a,'-ExpectedCompiledTestEx5Sha256');$a[$i+1]='0'*64;return $a}
    Negative 'EXP48-34' 'verification digest mismatch rejected' {} {param($a)$i=[Array]::IndexOf($a,'-ExpectedVerificationSourceDigest');$a[$i+1]='0'*64;return $a}
    Negative 'EXP48-35' 'same run file rejected' {} {param($a)$i=[Array]::IndexOf($a,'-Run2Log');$a[$i+1]=$run1Log;$i=[Array]::IndexOf($a,'-ExpectedRun2LogSha256');$a[$i+1]=Get-Sha $run1Log;return $a}
    Negative 'EXP48-36' 'deterministic false rejected' {Write-Lf $run1Log ($runBase.Replace('"deterministic":true','"deterministic":false'))}
    Negative 'EXP48-37' 'account mode mismatch rejected' {Write-Lf $run1Log ($runBase.Replace('fixture_account_mode=HEDGING','fixture_account_mode=NETTING'))}
    Negative 'EXP48-38' 'broker access true rejected' {Write-Lf $run1Log ($runBase.Replace('broker_access=false','broker_access=true'))}
    Negative 'EXP48-39' 'architecture raw hash mismatch rejected' {} {param($a)$i=[Array]::IndexOf($a,'-ExpectedArchitectureCompileLogSha256');$a[$i+1]='0'*64;return $a}
    Negative 'EXP48-40' 'test compile raw hash mismatch rejected' {} {param($a)$i=[Array]::IndexOf($a,'-ExpectedTestCompileLogSha256');$a[$i+1]='0'*64;return $a}
    Negative 'EXP48-41' 'Run 2 raw hash mismatch rejected' {} {param($a)$i=[Array]::IndexOf($a,'-ExpectedRun2LogSha256');$a[$i+1]='0'*64;return $a}
    Negative 'EXP48-46' 'summary with zero test records rejected' {Write-Lf $run1Log ($runBase.Replace($caseBlock+"`n"+$caseBlock+"`n",''))}
    $caseBlockMinusLast=($caseLines[0..($caseLines.Count-2)]-join"`n")
    Negative 'EXP48-47' 'only second deterministic stream truncated to 933 records is rejected' {Write-Lf $run1Log ($runBase.Replace($caseBlock+"`n"+$caseBlock,$caseBlock+"`n"+$caseBlockMinusLast))}
    Negative 'EXP48-48' 'duplicate test ID rejected' {Write-Lf $run1Log ($runBase.Replace('id=FX-002 domain=FIXTURE','id=FX-001 domain=FIXTURE'))}
    Negative 'EXP48-49' 'missing expected ID rejected' {Write-Lf $run1Log ($runBase.Replace('SWV5_TEST id=FX-100 domain=FIXTURE outcome=PASS expected=pass actual=pass detail=', ''))}
    Negative 'EXP48-50' 'unexpected test ID rejected' {Write-Lf $run1Log ($runBase.Replace('id=FX-100 domain=FIXTURE','id=FX-999 domain=FIXTURE'))}
    Negative 'EXP48-51' 'FAIL record contradicting summary rejected' {Write-Lf $run1Log ($runBase.Replace('id=FX-100 domain=FIXTURE outcome=PASS','id=FX-100 domain=FIXTURE outcome=FAIL'))}
    Negative 'EXP48-52' 'SKIP record rejected' {Write-Lf $run1Log ($runBase.Replace('id=FX-100 domain=FIXTURE outcome=PASS','id=FX-100 domain=FIXTURE outcome=SKIP'))}
    Negative 'EXP48-53' 'record count and summary disagreement rejected' {Write-Lf $run1Log ($runBase.Replace('"total":934,"passed":934','"total":933,"passed":933'))}
    Negative 'EXP48-54' 'wrong suite metadata rejected' {Write-Lf $run1Log ($runBase.Replace('suite=SPRINT4.8-V5-FULL','suite=WRONG-SUITE'))}
    Negative 'EXP48-55' 'reordered records rejected' {Write-Lf $run1Log ($runBase.Replace("SWV5_TEST id=FX-001 domain=FIXTURE outcome=PASS expected=pass actual=pass detail=`nSWV5_TEST id=FX-002 domain=FIXTURE outcome=PASS expected=pass actual=pass detail=","SWV5_TEST id=FX-002 domain=FIXTURE outcome=PASS expected=pass actual=pass detail=`nSWV5_TEST id=FX-001 domain=FIXTURE outcome=PASS expected=pass actual=pass detail="))}

    Git @('-C',$repo,'checkout','--quiet','--force',$sourceCommit)|Out-Null
    Add-Content -LiteralPath (Join-Path $testDir 'TEST_ID_INVENTORY.txt') 'FX-935'
    Git @('-C',$repo,'add','FusionProV5/Tests/ContractVerification/TEST_ID_INVENTORY.txt')|Out-Null
    Git @('-C',$repo,'-c','user.name=SWV5 Test','-c','user.email=swv5-test@example.invalid','commit','--quiet','-m','newer source inventory')|Out-Null
    $newerSource=Git @('-C',$repo,'rev-parse','HEAD');$newerTree=Git @('-C',$repo,'rev-parse','HEAD^{tree}');Set-Baseline
    $oldStreamArgs=Get-Args $newerSource $newerTree (Join-Path $tempRoot 'old-stream')
    $expectedTotalIndex=[Array]::IndexOf($oldStreamArgs,'-ExpectedTestTotal');$oldStreamArgs[$expectedTotalIndex+1]='935'
    $oldStreamResult=Invoke-Exporter $oldStreamArgs 'old-stream.out'
    Record 'EXP48-56' 'old 934-ID stream rejected against newer source inventory' ($oldStreamResult.ExitCode-ne0)

    Negative 'EXP48-57' 'only first deterministic stream truncated to 933 records is rejected' {Write-Lf $run1Log ($runBase.Replace($caseBlock+"`n"+$caseBlock,$caseBlockMinusLast+"`n"+$caseBlock))}
    Negative 'EXP48-58' 'offline result with wrong exporter SHA is rejected' {$o=Get-Content -LiteralPath $offlineResult -Raw|ConvertFrom-Json;$o.exporter_sha256='0'*64;Write-Lf $offlineResult ($o|ConvertTo-Json -Depth 6)}
    Negative 'EXP48-59' 'offline result with wrong test-script SHA is rejected' {$o=Get-Content -LiteralPath $offlineResult -Raw|ConvertFrom-Json;$o.test_script_sha256='0'*64;Write-Lf $offlineResult ($o|ConvertTo-Json -Depth 6)}
    Negative 'EXP48-60' 'offline result with duplicate test ID is rejected' {$o=Get-Content -LiteralPath $offlineResult -Raw|ConvertFrom-Json;$o.cases[1].id=$o.cases[0].id;Write-Lf $offlineResult ($o|ConvertTo-Json -Depth 6)}
    Negative 'EXP48-61' 'offline result with failed case is rejected' {$o=Get-Content -LiteralPath $offlineResult -Raw|ConvertFrom-Json;$o.cases[0].passed=$false;$o.passed--; $o.failed++;Write-Lf $offlineResult ($o|ConvertTo-Json -Depth 6)}
    Negative 'EXP48-62' 'offline result with skipped count is rejected' {$o=Get-Content -LiteralPath $offlineResult -Raw|ConvertFrom-Json;$o.passed--; $o.skipped++;Write-Lf $offlineResult ($o|ConvertTo-Json -Depth 6)}
    Negative 'EXP48-63' 'offline result with fabricated totals is rejected' {$o=Get-Content -LiteralPath $offlineResult -Raw|ConvertFrom-Json;$o.total++;$o.passed++;Write-Lf $offlineResult ($o|ConvertTo-Json -Depth 6)}
    Git @('-C',$repo,'checkout','--quiet','--force',$sourceCommit)|Out-Null;Set-Baseline;$missingOfflineArgs=Get-Args $sourceCommit $sourceTree (Join-Path $tempRoot 'EXP48-64');Remove-Item -LiteralPath $offlineResult -Force;$missingOffline=Invoke-Exporter $missingOfflineArgs 'EXP48-64.out';Record 'EXP48-64' 'missing offline result artifact is rejected' ($missingOffline.ExitCode-ne0)
    Negative 'EXP48-67' 'offline result missing one canonical case is rejected' {$o=Get-Content -LiteralPath $offlineResult -Raw|ConvertFrom-Json;$o.cases=@($o.cases)[0..($o.cases.Count-2)];$o.total--; $o.passed--; $o.signature=Get-ShaBytes $Utf8NoBom.GetBytes((@($o.cases|ForEach-Object{$_.id+'|'+$_.name+'|'+[bool]$_.passed})-join"`n"));Write-Lf $offlineResult ($o|ConvertTo-Json -Depth 6)}

    Git @('-C',$repo,'checkout','--quiet','--force',$sourceCommit)|Out-Null;Write-Lf $matrix ($matrixValid.Replace('| `WEAK_FALSE_POSITIVE` | 0 | NO |','| `WEAK_FALSE_POSITIVE` | 1 | NO |'));Git @('-C',$repo,'add','FusionProV5/Tests/ContractVerification/TEST_CREDIBILITY_MATRIX.md')|Out-Null;Git @('-C',$repo,'-c','user.name=SWV5 Test','-c','user.email=swv5-test@example.invalid','commit','--quiet','-m','weak')|Out-Null;$weak=Git @('-C',$repo,'rev-parse','HEAD');$weakTree=Git @('-C',$repo,'rev-parse','HEAD^{tree}');Set-Baseline;$wr=Invoke-Exporter (Get-Args $weak $weakTree (Join-Path $tempRoot 'weak')) 'weak.out';Record 'EXP48-42' 'weak credibility count rejected' ($wr.ExitCode-ne0)
    Git @('-C',$repo,'checkout','--quiet','--force',$sourceCommit)|Out-Null;Write-Lf $inventory ($((Get-Content -LiteralPath $inventory -Raw).Replace('**934**','**933**')));Git @('-C',$repo,'add','FusionProV5/Tests/ContractVerification/TEST_INVENTORY.md')|Out-Null;Git @('-C',$repo,'-c','user.name=SWV5 Test','-c','user.email=swv5-test@example.invalid','commit','--quiet','-m','inventory mismatch')|Out-Null;$bad=Git @('-C',$repo,'rev-parse','HEAD');$badTree=Git @('-C',$repo,'rev-parse','HEAD^{tree}');Set-Baseline;$br=Invoke-Exporter (Get-Args $bad $badTree (Join-Path $tempRoot 'bad-inventory')) 'inventory.out';Record 'EXP48-43' 'inventory mismatch rejected' ($br.ExitCode-ne0)

    Git @('-C',$repo,'checkout','--quiet','--force',$evidenceCommit)|Out-Null;Git @('-C',$repo,'rm','--cached','--quiet','FusionProV5/Evidence/Sprint4_8/COMPILE_REPORT.md')|Out-Null;$missing=Invoke-Exporter @('-Mode','VerifyIndex','-RepositoryRoot',$repo,'-EvidenceManifestPath',$blobManifest,'-TestedSourceSha',$sourceCommit,'-ExpectedSourceTreeSha',$sourceTree) 'missing-evidence.out';Record 'EXP48-44' 'missing staged evidence file rejected' ($missing.ExitCode-ne0)
    Git @('-C',$repo,'restore','--source',$evidenceCommit,'--staged','--worktree','.')|Out-Null;Write-Lf (Join-Path $evidence 'unexpected.txt') 'unexpected evidence artifact';Git @('-C',$repo,'add','FusionProV5/Evidence/Sprint4_8/unexpected.txt')|Out-Null;$unexpected=Invoke-Exporter @('-Mode','VerifyIndex','-RepositoryRoot',$repo,'-EvidenceManifestPath',$blobManifest,'-TestedSourceSha',$sourceCommit,'-ExpectedSourceTreeSha',$sourceTree) 'unexpected-evidence.out';Record 'EXP48-45' 'unexpected evidence file rejected' ($unexpected.ExitCode-ne0)

    Git @('-C',$repo,'checkout','--quiet','--force',$sourceCommit)|Out-Null;Set-Baseline
    $semanticEvidence=Join-Path $repo 'FusionProV5\Evidence\Sprint4_8';$sg=Invoke-Exporter (Get-Args $sourceCommit $sourceTree $semanticEvidence) 'semantic-fixture.out'
    $semanticRaw=Join-Path $semanticEvidence 'sprint4_8_tester_evidence.txt';$semanticText=Get-Content -LiteralPath $semanticRaw -Raw
    $semanticText=[regex]::Replace($semanticText,[regex]::Escape('SWV5_TEST id=FX-934 domain=FIXTURE outcome=PASS expected=pass actual=pass detail='),'',1)
    Write-Lf $semanticRaw $semanticText
    Git @('-C',$repo,'add','FusionProV5/Evidence/Sprint4_8/COMPILE_REPORT.md','FusionProV5/Evidence/Sprint4_8/VERIFICATION_REPORT.md','FusionProV5/Evidence/Sprint4_8/contract_test_results.json','FusionProV5/Evidence/Sprint4_8/sprint4_8_tester_evidence.txt','FusionProV5/Evidence/Sprint4_8/exporter_test_results.json')|Out-Null
    $semanticManifest=Join-Path $semanticEvidence 'evidence_blob_manifest.json';$sim=Invoke-Exporter @('-Mode','IndexManifest','-RepositoryRoot',$repo,'-OutputDirectory',$semanticEvidence,'-TestedSourceSha',$sourceCommit,'-ExpectedSourceTreeSha',$sourceTree) 'semantic-index.out'
    Git @('-C',$repo,'add','FusionProV5/Evidence/Sprint4_8/evidence_blob_manifest.json')|Out-Null
    $siv=Invoke-Exporter @('-Mode','VerifyIndex','-RepositoryRoot',$repo,'-EvidenceManifestPath',$semanticManifest,'-TestedSourceSha',$sourceCommit,'-ExpectedSourceTreeSha',$sourceTree) 'semantic-index-verify.out'
    Record 'EXP48-65' 'VerifyIndex rejects hash-valid semantically fabricated evidence' ($sg.ExitCode-eq0-and$sim.ExitCode-eq0-and$siv.ExitCode-ne0)
    Git @('-C',$repo,'-c','user.name=SWV5 Test','-c','user.email=swv5-test@example.invalid','commit','--quiet','-m','semantically fabricated evidence')|Out-Null
    $semanticCommit=Git @('-C',$repo,'rev-parse','HEAD');$scv=Invoke-Exporter @('-Mode','VerifyCommit','-RepositoryRoot',$repo,'-EvidenceManifestPath',$semanticManifest,'-EvidenceCommitSha',$semanticCommit,'-TestedSourceSha',$sourceCommit,'-ExpectedSourceTreeSha',$sourceTree) 'semantic-commit-verify.out'
    Record 'EXP48-66' 'VerifyCommit rejects hash-valid semantically fabricated evidence' ($scv.ExitCode-ne0)

    # Root-of-trust attack: every evidence file and the manifest consistently
    # claim a fabricated tree and matching fabricated digest. Git derivation
    # must reject the package before those repeated claims can become authority.
    Git @('-C',$repo,'checkout','--quiet','--force',$sourceCommit)|Out-Null;Set-Baseline
    $treeAttack=Join-Path $repo 'FusionProV5\Evidence\Sprint4_8';$tg=Invoke-Exporter (Get-Args $sourceCommit $sourceTree $treeAttack) 'tree-attack-generate.out'
    $treeResultPath=Join-Path $treeAttack 'contract_test_results.json';$treeResult=Get-Content -LiteralPath $treeResultPath -Raw|ConvertFrom-Json;$realDigest=[string]$treeResult.verification_source_digest;$fakeTree='f'*40;$fakeDigest=Get-DigestFromInputs $sourceCommit $fakeTree $treeResult.verification_source_inputs;$treeResult.source_tree=$fakeTree;$treeResult.verification_source_digest=$fakeDigest;Write-Lf $treeResultPath ($treeResult|ConvertTo-Json -Depth 12)
    foreach($name in @('COMPILE_REPORT.md','VERIFICATION_REPORT.md','sprint4_8_tester_evidence.txt')){$p=Join-Path $treeAttack $name;$t=Get-Content -LiteralPath $p -Raw;$t=$t.Replace($sourceTree,$fakeTree).Replace($realDigest,$fakeDigest);Write-Lf $p $t}
    Git @('-C',$repo,'add','FusionProV5/Evidence/Sprint4_8/COMPILE_REPORT.md','FusionProV5/Evidence/Sprint4_8/VERIFICATION_REPORT.md','FusionProV5/Evidence/Sprint4_8/contract_test_results.json','FusionProV5/Evidence/Sprint4_8/sprint4_8_tester_evidence.txt','FusionProV5/Evidence/Sprint4_8/exporter_test_results.json')|Out-Null
    $treeManifest=Join-Path $treeAttack 'evidence_blob_manifest.json';$tim=Invoke-Exporter @('-Mode','IndexManifest','-RepositoryRoot',$repo,'-OutputDirectory',$treeAttack,'-TestedSourceSha',$sourceCommit,'-ExpectedSourceTreeSha',$sourceTree) 'tree-attack-manifest.out';$treeManifestObject=Get-Content -LiteralPath $treeManifest -Raw|ConvertFrom-Json;$treeManifestObject.source_tree=$fakeTree;Write-Lf $treeManifest ($treeManifestObject|ConvertTo-Json -Depth 8);Git @('-C',$repo,'add','FusionProV5/Evidence/Sprint4_8/evidence_blob_manifest.json')|Out-Null
    $tiv=Invoke-Exporter @('-Mode','VerifyIndex','-RepositoryRoot',$repo,'-EvidenceManifestPath',$treeManifest,'-TestedSourceSha',$sourceCommit,'-ExpectedSourceTreeSha',$sourceTree) 'tree-attack-index.out';Record 'EXP48-68' 'VerifyIndex rejects self-consistent fabricated source tree' ($tg.ExitCode-eq0-and$tim.ExitCode-eq0-and$tiv.ExitCode-ne0)
    Git @('-C',$repo,'-c','user.name=SWV5 Test','-c','user.email=swv5-test@example.invalid','commit','--quiet','-m','fabricated tree evidence')|Out-Null;$treeCommit=Git @('-C',$repo,'rev-parse','HEAD');$tcv=Invoke-Exporter @('-Mode','VerifyCommit','-RepositoryRoot',$repo,'-EvidenceManifestPath',$treeManifest,'-EvidenceCommitSha',$treeCommit,'-TestedSourceSha',$sourceCommit,'-ExpectedSourceTreeSha',$sourceTree) 'tree-attack-commit.out';Record 'EXP48-69' 'VerifyCommit rejects self-consistent fabricated source tree' ($tcv.ExitCode-ne0)

    # Direct digest forgery with otherwise unchanged semantic evidence.
    Git @('-C',$repo,'checkout','--quiet','--force',$sourceCommit)|Out-Null;Set-Baseline
    $digestAttack=Join-Path $repo 'FusionProV5\Evidence\Sprint4_8';$dg=Invoke-Exporter (Get-Args $sourceCommit $sourceTree $digestAttack) 'digest-attack-generate.out';$digestResultPath=Join-Path $digestAttack 'contract_test_results.json';$digestResult=Get-Content -LiteralPath $digestResultPath -Raw|ConvertFrom-Json;$oldDigest=[string]$digestResult.verification_source_digest;$forgedDigest='a'*64;$digestResult.verification_source_digest=$forgedDigest;Write-Lf $digestResultPath ($digestResult|ConvertTo-Json -Depth 12)
    foreach($name in @('COMPILE_REPORT.md','VERIFICATION_REPORT.md','sprint4_8_tester_evidence.txt')){$p=Join-Path $digestAttack $name;$t=Get-Content -LiteralPath $p -Raw;Write-Lf $p ($t.Replace($oldDigest,$forgedDigest))}
    Git @('-C',$repo,'add','FusionProV5/Evidence/Sprint4_8/COMPILE_REPORT.md','FusionProV5/Evidence/Sprint4_8/VERIFICATION_REPORT.md','FusionProV5/Evidence/Sprint4_8/contract_test_results.json','FusionProV5/Evidence/Sprint4_8/sprint4_8_tester_evidence.txt','FusionProV5/Evidence/Sprint4_8/exporter_test_results.json')|Out-Null;$digestManifest=Join-Path $digestAttack 'evidence_blob_manifest.json';$dim=Invoke-Exporter @('-Mode','IndexManifest','-RepositoryRoot',$repo,'-OutputDirectory',$digestAttack,'-TestedSourceSha',$sourceCommit,'-ExpectedSourceTreeSha',$sourceTree) 'digest-attack-manifest.out';Git @('-C',$repo,'add','FusionProV5/Evidence/Sprint4_8/evidence_blob_manifest.json')|Out-Null;$div=Invoke-Exporter @('-Mode','VerifyIndex','-RepositoryRoot',$repo,'-EvidenceManifestPath',$digestManifest,'-TestedSourceSha',$sourceCommit,'-ExpectedSourceTreeSha',$sourceTree) 'digest-attack-index.out';Record 'EXP48-70' 'VerifyIndex rejects direct verification digest forgery' ($dg.ExitCode-eq0-and$dim.ExitCode-eq0-and$div.ExitCode-ne0)
    Git @('-C',$repo,'-c','user.name=SWV5 Test','-c','user.email=swv5-test@example.invalid','commit','--quiet','-m','forged digest evidence')|Out-Null;$digestCommit=Git @('-C',$repo,'rev-parse','HEAD');$dcv=Invoke-Exporter @('-Mode','VerifyCommit','-RepositoryRoot',$repo,'-EvidenceManifestPath',$digestManifest,'-EvidenceCommitSha',$digestCommit,'-TestedSourceSha',$sourceCommit,'-ExpectedSourceTreeSha',$sourceTree) 'digest-attack-commit.out';Record 'EXP48-71' 'VerifyCommit rejects direct verification digest forgery' ($dcv.ExitCode-ne0)

    # Recomputed digest over a forged independently derivable source-blob input.
    Git @('-C',$repo,'checkout','--quiet','--force',$sourceCommit)|Out-Null;Set-Baseline
    $inputAttack=Join-Path $repo 'FusionProV5\Evidence\Sprint4_8';$ig=Invoke-Exporter (Get-Args $sourceCommit $sourceTree $inputAttack) 'input-attack-generate.out';$inputResultPath=Join-Path $inputAttack 'contract_test_results.json';$inputResult=Get-Content -LiteralPath $inputResultPath -Raw|ConvertFrom-Json;$priorDigest=[string]$inputResult.verification_source_digest;$inputResult.verification_source_inputs.test_manifest_git_blob_sha256='b'*64;$recomputedFake=Get-DigestFromInputs $sourceCommit $sourceTree $inputResult.verification_source_inputs;$inputResult.verification_source_digest=$recomputedFake;Write-Lf $inputResultPath ($inputResult|ConvertTo-Json -Depth 12)
    foreach($name in @('COMPILE_REPORT.md','VERIFICATION_REPORT.md','sprint4_8_tester_evidence.txt')){$p=Join-Path $inputAttack $name;$t=Get-Content -LiteralPath $p -Raw;Write-Lf $p ($t.Replace($priorDigest,$recomputedFake))}
    Git @('-C',$repo,'add','FusionProV5/Evidence/Sprint4_8/COMPILE_REPORT.md','FusionProV5/Evidence/Sprint4_8/VERIFICATION_REPORT.md','FusionProV5/Evidence/Sprint4_8/contract_test_results.json','FusionProV5/Evidence/Sprint4_8/sprint4_8_tester_evidence.txt','FusionProV5/Evidence/Sprint4_8/exporter_test_results.json')|Out-Null;$inputManifest=Join-Path $inputAttack 'evidence_blob_manifest.json';$iim=Invoke-Exporter @('-Mode','IndexManifest','-RepositoryRoot',$repo,'-OutputDirectory',$inputAttack,'-TestedSourceSha',$sourceCommit,'-ExpectedSourceTreeSha',$sourceTree) 'input-attack-manifest.out';Git @('-C',$repo,'add','FusionProV5/Evidence/Sprint4_8/evidence_blob_manifest.json')|Out-Null;$iiv=Invoke-Exporter @('-Mode','VerifyIndex','-RepositoryRoot',$repo,'-EvidenceManifestPath',$inputManifest,'-TestedSourceSha',$sourceCommit,'-ExpectedSourceTreeSha',$sourceTree) 'input-attack-index.out';Record 'EXP48-72' 'VerifyIndex rejects recomputed digest over forged source-blob input' ($ig.ExitCode-eq0-and$iim.ExitCode-eq0-and$iiv.ExitCode-ne0)
    Git @('-C',$repo,'-c','user.name=SWV5 Test','-c','user.email=swv5-test@example.invalid','commit','--quiet','-m','forged digest input evidence')|Out-Null;$inputCommit=Git @('-C',$repo,'rev-parse','HEAD');$icv=Invoke-Exporter @('-Mode','VerifyCommit','-RepositoryRoot',$repo,'-EvidenceManifestPath',$inputManifest,'-EvidenceCommitSha',$inputCommit,'-TestedSourceSha',$sourceCommit,'-ExpectedSourceTreeSha',$sourceTree) 'input-attack-commit.out';Record 'EXP48-73' 'VerifyCommit rejects recomputed digest over forged source-blob input' ($icv.ExitCode-ne0)

    function Credibility-Source-Negative([string]$Id,[string]$Name,[string]$CredibilityText,[string]$MatrixText,[bool]$BindOldAuthority=$false){
        Git @('-C',$repo,'checkout','--quiet','--force',$sourceCommit)|Out-Null
        Write-Lf $credibilityInventory $CredibilityText;Write-Lf $matrix $MatrixText
        Git @('-C',$repo,'add','FusionProV5/Tests/ContractVerification/TEST_CREDIBILITY_ID_INVENTORY.txt','FusionProV5/Tests/ContractVerification/TEST_CREDIBILITY_MATRIX.md')|Out-Null
        Git @('-C',$repo,'-c','user.name=SWV5 Test','-c','user.email=swv5-test@example.invalid','commit','--quiet','-m',$Id)|Out-Null
        $candidate=Git @('-C',$repo,'rev-parse','HEAD');$candidateTree=Git @('-C',$repo,'rev-parse','HEAD^{tree}');Set-Baseline
        $args=Get-Args $candidate $candidateTree (Join-Path $tempRoot $Id)
        if($BindOldAuthority){$i=[Array]::IndexOf($args,'-ExpectedVerificationSourceDigest');$args[$i+1]=Get-Digest $candidate $candidateTree (Get-BlobSha $credibilityBlob)}
        $result=Invoke-Exporter $args "$Id.out";Record $Id $Name ($result.ExitCode-ne0)
    }
    Credibility-Source-Negative 'EXP48-74' 'headline category total changed with stable per-ID authority is rejected' $credibilityValid ($matrixValid.Replace('| `MERGE_GATING_BEHAVIOR` | 85 | YES |','| `MERGE_GATING_BEHAVIOR` | 84 | YES |'))
    $swapMergeState=$credibilityValid.Replace('MERGE_GATING_BEHAVIOR|FX-001..085',"STATE_TRANSITION|FX-001`nMERGE_GATING_BEHAVIOR|FX-002..086").Replace('STATE_TRANSITION|FX-086..194','STATE_TRANSITION|FX-087..194')
    Credibility-Source-Negative 'EXP48-75' 'balanced per-ID change is rejected when source-bound authority differs' $swapMergeState $matrixValid $true
    Credibility-Source-Negative 'EXP48-76' 'duplicate credibility classification ID is rejected' ($credibilityValid+"`nCONFORMANCE_ONLY|FX-934") $matrixValid
    Credibility-Source-Negative 'EXP48-77' 'missing executable credibility classification is rejected' ($credibilityValid.Replace('CONFORMANCE_ONLY|FX-921..934','CONFORMANCE_ONLY|FX-921..933')) $matrixValid
    Credibility-Source-Negative 'EXP48-78' 'phantom credibility classification ID is rejected' ($credibilityValid.Replace('CONFORMANCE_ONLY|FX-921..934',"CONFORMANCE_ONLY|FX-921..933`nCONFORMANCE_ONLY|FX-999")) $matrixValid
    Credibility-Source-Negative 'EXP48-79' 'unknown credibility category is rejected' ($credibilityValid.Replace('CONFORMANCE_ONLY|FX-921..934','UNKNOWN_CATEGORY|FX-921..934')) $matrixValid
    $roundTripSwap=$credibilityValid.Replace('ROUND_TRIP|FX-801..810',"SUPPORTING_PURE_FUNCTION|FX-801`nROUND_TRIP|FX-802..810").Replace('SUPPORTING_PURE_FUNCTION|FX-859..920',"ROUND_TRIP|FX-859`nSUPPORTING_PURE_FUNCTION|FX-860..920")
    Credibility-Source-Negative 'EXP48-80' 'supporting ID cannot gain round-trip credit outside bound authority' $roundTripSwap $matrixValid $true
    $weakPerId=$credibilityValid.Replace('CONFORMANCE_ONLY|FX-921..934',"WEAK_FALSE_POSITIVE|FX-921`nCONFORMANCE_ONLY|FX-922..934")
    Credibility-Source-Negative 'EXP48-81' 'weak headline zero with one per-ID weak classification is rejected' $weakPerId $matrixValid
    $balancedWrong=$credibilityValid.Replace('NEGATIVE_FAIL_CLOSED|FX-195..800',"INVARIANT_BEHAVIOR|FX-195`nNEGATIVE_FAIL_CLOSED|FX-196..800").Replace('INVARIANT_BEHAVIOR|FX-811..858',"NEGATIVE_FAIL_CLOSED|FX-811`nINVARIANT_BEHAVIOR|FX-812..858")
    Credibility-Source-Negative 'EXP48-82' 'internally balanced totals with wrong per-ID mapping are rejected' $balancedWrong $matrixValid $true

    Run-BuildParserTests
    Run-ServerParserTests
    Run-HarnessSafetyTests
    Run-IdentityAuthorityTests
    Run-DeterminismTests
    Write-CredibilityProof

    $final=New-CanonicalExporterResult $records
    $finalJson=ConvertTo-CanonicalJsonText $final 10;if(-not[string]::IsNullOrWhiteSpace($ResultPath)){[IO.File]::WriteAllText($ResultPath,$finalJson,$Utf8NoBom)};$finalJson
    if($failed-ne0-or$passed-ne$exporterIds.Count){throw "EXPORTER_OFFLINE_SUITE_FAILED|expected=$($exporterIds.Count)|passed=$passed|failed=$failed"}
    $scriptSucceeded=$true
} catch {
    $primaryError=$_
    throw
} finally {
    if(-not$scriptSucceeded){
        try{
            if([string]::IsNullOrWhiteSpace($DiagnosticDirectory)){
                $diagnosticParent=if(-not[string]::IsNullOrWhiteSpace($ResultPath)){Split-Path -Parent ([IO.Path]::GetFullPath($ResultPath))}else{[IO.Path]::GetTempPath()}
                $DiagnosticDirectory=Join-Path $diagnosticParent 'SWV5-S48-EXPORT-DIAGNOSTIC'
            }
            $preserved=Write-FailureDiagnostic $DiagnosticDirectory $failureContext $primaryError $tempRoot
            Write-Warning "HARNESS_PRIMARY_FAILURE_PRESERVED|path=$preserved"
        }catch{Write-Warning "DIAGNOSTIC_PRESERVATION_FAILED_WITH_PRIMARY_RETAINED|$($_.Exception.Message)"}
    }
    $cleanupError=Invoke-SafeCleanup $tempRoot $primaryError
    if($null-ne$cleanupError){Write-Warning "CLEANUP_FAILED_WITH_PRIMARY_RETAINED|$($cleanupError.Exception.Message)"}
}
