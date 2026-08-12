# TEST ONLY
# NOT FOR PRODUCTION
# NO BROKER ACCESS
# Deterministic, explicit-input Sprint 4.8 evidence exporter and Git-blob verifier.

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
    [string]$CompiledTestEx5,
    [ValidatePattern('^[0-9a-fA-F]{40}$')][string]$TestedSourceSha,
    [ValidatePattern('^[0-9a-fA-F]{40}$')][string]$ExpectedSourceTreeSha,
    [ValidatePattern('^[0-9a-fA-F]{64}$')][string]$ExpectedArchitectureCompileLogSha256,
    [ValidatePattern('^[0-9a-fA-F]{64}$')][string]$ExpectedTestCompileLogSha256,
    [ValidatePattern('^[0-9a-fA-F]{64}$')][string]$ExpectedRun1LogSha256,
    [ValidatePattern('^[0-9a-fA-F]{64}$')][string]$ExpectedRun2LogSha256,
    [ValidatePattern('^[0-9a-fA-F]{64}$')][string]$ExpectedCompiledTestEx5Sha256,
    [ValidatePattern('^[0-9a-fA-F]{64}$')][string]$ExpectedVerificationSourceDigest,
    [string]$InventoryPath,
    [string]$CredibilityMatrixPath,
    [string]$EvidenceManifestPath,
    [string[]]$EvidencePaths,
    [ValidatePattern('^[0-9a-fA-F]{40}$')][string]$EvidenceCommitSha
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$Utf8NoBom = [Text.UTF8Encoding]::new($false)
$Utf8Strict = [Text.UTF8Encoding]::new($false, $true)
$ExpectedSignature = '12393352988365616976'
$ExpectedSchema = 'SWV5-CONTRACT-TEST-RESULT-V5'
$ExpectedPolicy = 'SWV5-PRODUCTION-V5'
$ExpectedSuite = 'SPRINT4.8-V5-FULL'
$ExpectedBuild = '6090'
$ExpectedServer = 'Exness-MT5Trial6'
$ManifestRelative = 'SOMWANG_XAU_M15_FUSION_PRO_V5_SPRINT4_3_CONTRACT_TESTS.mq5'
$ConfigIniRelative = 'FusionProV5/Tests/ContractVerification/sprint4_8_b6_full_once.ini'
$ConfigSetRelative = 'FusionProV5/Tests/ContractVerification/sprint4_8_b6_full_once.set'

function Fail([string]$Message) { throw "SPRINT48_EXPORT_VALIDATION_FAILED: $Message" }
function Require-Value([string]$Value,[string]$Label) {
    if ([string]::IsNullOrWhiteSpace($Value)) { Fail "$Label is required for mode $Mode" }
}
function Resolve-RequiredFile([string]$Path,[string]$Label) {
    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path -PathType Leaf)) { Fail "$Label is missing: $Path" }
    return (Resolve-Path -LiteralPath $Path).Path
}
function Invoke-GitText([string[]]$Arguments) {
    $result = & git @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) { Fail ("git {0} failed: {1}" -f ($Arguments -join ' '),($result -join "`n")) }
    return (($result | ForEach-Object { "$_" }) -join "`n").Trim()
}
function Get-RepositoryRelativePath([string]$Root,[string]$Path) {
    $rootFull = [IO.Path]::GetFullPath($Root).TrimEnd('\','/')
    $pathFull = [IO.Path]::GetFullPath($Path)
    if (-not $pathFull.StartsWith($rootFull + [IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) {
        Fail "repository content is outside repository root: $pathFull"
    }
    return $pathFull.Substring($rootFull.Length + 1).Replace('\','/')
}
function Get-Sha256Bytes([byte[]]$Bytes) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($Bytes))).Replace('-','').ToLowerInvariant() }
    finally { $sha.Dispose() }
}
function Get-FileSha256([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
function Get-GitBlobBytes([string]$Root,[string]$Revision,[string]$RelativePath) {
    $spec = if ($Revision -eq 'INDEX') { ":$RelativePath" } else { "${Revision}:$RelativePath" }
    $blobId = Invoke-GitText @('-C',$Root,'rev-parse',$spec)
    if ($blobId -notmatch '^[0-9a-fA-F]{40,64}$') { Fail "invalid Git blob identity for $spec" }
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = 'git.exe'
    $start.Arguments = "-C `"$Root`" cat-file blob $blobId"
    $start.UseShellExecute = $false
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $process = [Diagnostics.Process]::new(); $process.StartInfo = $start
    if (-not $process.Start()) { Fail "cannot start git cat-file for $spec" }
    $memory = [IO.MemoryStream]::new()
    try {
        $process.StandardOutput.BaseStream.CopyTo($memory); $errorText = $process.StandardError.ReadToEnd(); $process.WaitForExit()
        if ($process.ExitCode -ne 0) { Fail "git cat-file failed for $spec`: $errorText" }
        return ,$memory.ToArray()
    } finally { $memory.Dispose(); $process.Dispose() }
}
function Get-GitBlobSha256([string]$Root,[string]$Revision,[string]$RelativePath) {
    return Get-Sha256Bytes (Get-GitBlobBytes $Root $Revision $RelativePath)
}
function Get-GitBlobText([string]$Root,[string]$Revision,[string]$RelativePath) {
    try { return $Utf8Strict.GetString((Get-GitBlobBytes $Root $Revision $RelativePath)) }
    catch { Fail "$Revision`:$RelativePath is not valid UTF-8 text" }
}
function Normalize-Lf([string]$Text) { return ($Text -replace "`r`n","`n" -replace "`r","`n") }
function Write-DeterministicText([string]$Path,[string]$Text) {
    $parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    $canonical = (Normalize-Lf $Text).TrimEnd("`n") + "`n"
    [IO.File]::WriteAllText($Path,$canonical,$Utf8NoBom)
}
function Read-RawText([string]$Path) {
    $bytes = [IO.File]::ReadAllBytes($Path)
    if ($bytes.Length -ge 2 -and $bytes[0] -eq 0xff -and $bytes[1] -eq 0xfe) { return [Text.Encoding]::Unicode.GetString($bytes,2,$bytes.Length-2) }
    if ($bytes.Length -ge 2 -and $bytes[0] -eq 0xfe -and $bytes[1] -eq 0xff) { return [Text.Encoding]::BigEndianUnicode.GetString($bytes,2,$bytes.Length-2) }
    $sample = [Math]::Min($bytes.Length,256); $zeroOdd = 0
    for ($i=1; $i -lt $sample; $i+=2) { if ($bytes[$i] -eq 0) { $zeroOdd++ } }
    if ($sample -gt 8 -and $zeroOdd -gt [int]($sample/8)) { return [Text.Encoding]::Unicode.GetString($bytes) }
    try { return $Utf8Strict.GetString($bytes) } catch { Fail "raw input is neither strict UTF-8 nor UTF-16 text: $Path" }
}
function Assert-ExpectedRawHash([string]$Path,[string]$Expected,[string]$Label) {
    Require-Value $Expected "$Label expected SHA-256"; $actual = Get-FileSha256 $Path
    if ($actual -ne $Expected.ToLowerInvariant()) { Fail "$Label raw-input SHA-256 mismatch" }
    return $actual
}
function Read-Compile([string]$Path,[string]$Label) {
    $text = Read-RawText $Path
    $matches = [regex]::Matches($text,"Result:\s*(\d+) errors,\s*(\d+) warnings,\s*(\d+) ms elapsed,\s*cpu='([^']+)'")
    if ($matches.Count -ne 1) { Fail "$Label compile log must contain exactly one complete Result line" }
    if ([int]$matches[0].Groups[1].Value -ne 0 -or [int]$matches[0].Groups[2].Value -ne 0) { Fail "$Label compile is not 0 errors / 0 warnings" }
    if ($matches[0].Groups[4].Value -ne 'X64 Regular') { Fail "$Label compile is not X64 Regular" }
    return [pscustomobject]@{ errors=0; warnings=0; elapsed_ms=[int]$matches[0].Groups[3].Value; cpu=$matches[0].Groups[4].Value }
}
function Read-Run([string]$Path,[string]$Label,[string]$RawSha) {
    $text = Read-RawText $Path; $normalized = Normalize-Lf $text
    $machines = [regex]::Matches($normalized,'SWV5_MACHINE_RESULT\s+(\{[^\r\n]+\})')
    if ($machines.Count -ne 1) { Fail "$Label must contain exactly one SWV5_MACHINE_RESULT" }
    try { $machine = $machines[0].Groups[1].Value | ConvertFrom-Json } catch { Fail "$Label machine result is invalid JSON" }
    $expected = [ordered]@{ schema=$ExpectedSchema; contract_policy=$ExpectedPolicy; suite=$ExpectedSuite; total=846; passed=846; failed=0; skipped=0; signature=$ExpectedSignature }
    foreach ($name in $expected.Keys) {
        $property = $machine.PSObject.Properties[$name]; if ($null -eq $property -or [string]$property.Value -ne [string]$expected[$name]) { Fail "$Label $name mismatch" }
    }
    if (-not [bool]$machine.deterministic) { Fail "$Label deterministic flag is false" }
    $metadata = [regex]::Matches($normalized,'SWV5_RUN_METADATA\s+suite=([^\s]+)\s+fixture_account_mode=([^\s]+)\s+fixture_broker=([^\s]+)\s+fixture_server=([^\s]+)\s+broker_access=([^\s]+)')
    if ($metadata.Count -ne 1 -or $metadata[0].Groups[1].Value -ne $ExpectedSuite -or $metadata[0].Groups[2].Value -ne 'HEDGING' -or $metadata[0].Groups[5].Value -ne 'false') { Fail "$Label metadata mismatch" }
    $builds = [regex]::Matches($normalized,'authorized \(agent build (\d+)\)'); if ($builds.Count -ne 1 -or $builds[0].Groups[1].Value -ne $ExpectedBuild) { Fail "$Label terminal build mismatch" }
    $servers = [regex]::Matches($normalized,'EURUSD,M1 \(([^)]+)\): testing of'); if ($servers.Count -ne 1 -or $servers[0].Groups[1].Value -ne $ExpectedServer) { Fail "$Label Demo/Trial server mismatch" }
    if ([regex]::Matches($normalized,'SWV5_ONTESTER_SUCCESS\s+result=1').Count -ne 1 -or [regex]::Matches($normalized,'OnTester result 1').Count -ne 1) { Fail "$Label OnTester result mismatch" }
    $clocks = [regex]::Matches($normalized,'(?m)^[A-Z]{2}\s+0\s+(\d{2}:\d{2}:\d{2}\.\d{3})\s+')
    if ($clocks.Count -eq 0) { Fail "$Label contains no raw tester clock" }
    return [pscustomobject]@{ Machine=$machine; Build=$ExpectedBuild; Server=$ExpectedServer; AccountMode='HEDGING'; OnTester=1; RawSha256=$RawSha; FirstRawClock=$clocks[0].Groups[1].Value; LastRawClock=$clocks[$clocks.Count-1].Groups[1].Value; Text=$normalized }
}
function Get-Credibility([string]$Repo,[string]$Revision) {
    $inventory = Get-GitBlobText $Repo $Revision 'FusionProV5/Tests/ContractVerification/TEST_INVENTORY.md'
    $matrix = Get-GitBlobText $Repo $Revision 'FusionProV5/Tests/ContractVerification/TEST_CREDIBILITY_MATRIX.md'
    $totalMatch = [regex]::Match($inventory,'(?m)^\|\s*\*\*Total\*\*\s*\|\s*\|\s*\*\*(\d+)\*\*')
    if (-not $totalMatch.Success -or [int]$totalMatch.Groups[1].Value -ne 846) { Fail 'credibility inventory total mismatch' }
    $required = [ordered]@{ MERGE_GATING_BEHAVIOR=69; STATE_TRANSITION=107; NEGATIVE_FAIL_CLOSED=543; ROUND_TRIP=7; INVARIANT_BEHAVIOR=47; SUPPORTING_PURE_FUNCTION=59; CONFORMANCE_ONLY=14; WEAK_FALSE_POSITIVE=0 }
    $actual = [ordered]@{}
    foreach ($category in $required.Keys) {
        $match = [regex]::Match($matrix,"(?m)^\|\s*``$category``\s*\|\s*(\d+)\s*\|")
        if (-not $match.Success -or [int]$match.Groups[1].Value -ne $required[$category]) { Fail "credibility category $category mismatch" }
        $actual[$category] = [int]$match.Groups[1].Value
    }
    if (($actual.Values | Measure-Object -Sum).Sum -ne 846 -or $actual.WEAK_FALSE_POSITIVE -ne 0) { Fail 'credibility sum or weak count mismatch' }
    return $actual
}
function Get-DefaultEvidencePaths([string]$Output) {
    return @((Join-Path $Output 'COMPILE_REPORT.md'),(Join-Path $Output 'VERIFICATION_REPORT.md'),(Join-Path $Output 'contract_test_results.json'),(Join-Path $Output 'sprint4_8_tester_evidence.txt'))
}
function Assert-EvidenceTreeSet([string]$Root,[string]$Revision,[string]$DirectoryRelative,[bool]$IncludeManifest) {
    $DirectoryRelative=$DirectoryRelative.Replace('\','/').TrimEnd('/')
    $listed = if($Revision -eq 'INDEX'){Invoke-GitText @('-C',$Root,'ls-files','--cached','--',$DirectoryRelative)}else{Invoke-GitText @('-C',$Root,'ls-tree','-r','--name-only',$Revision,'--',$DirectoryRelative)}
    $actual=@($listed -split "`n"|Where-Object{-not[string]::IsNullOrWhiteSpace($_)}|Sort-Object)
    $expected=@("$DirectoryRelative/COMPILE_REPORT.md","$DirectoryRelative/VERIFICATION_REPORT.md","$DirectoryRelative/contract_test_results.json","$DirectoryRelative/sprint4_8_tester_evidence.txt")
    if($IncludeManifest){$expected += "$DirectoryRelative/evidence_blob_manifest.json"}
    if(($actual-join'|')-ne(($expected|Sort-Object)-join'|')){Fail 'unexpected or missing evidence-directory file'}
}
function Read-BlobManifest([string]$Root,[string]$Revision,[string]$RelativePath) {
    try { $manifest = (Get-GitBlobText $Root $Revision $RelativePath) | ConvertFrom-Json } catch { Fail 'evidence blob manifest is invalid JSON' }
    if ($manifest.schema -ne 'SWV5-SPRINT48-BLOB-MANIFEST-V1' -or $manifest.hash_authority -ne 'GIT_BLOB_BYTES_SHA256' -or $manifest.self_hash_policy -ne 'MANIFEST_EXCLUDED') { Fail 'evidence blob manifest policy mismatch' }
    if (@($manifest.evidence_files).Count -ne 4) { Fail 'evidence blob manifest must contain exactly four semantic files' }
    return $manifest
}
function Verify-BlobManifest([string]$Root,[string]$Revision,[object]$Manifest) {
    $expectedNames = @('COMPILE_REPORT.md','VERIFICATION_REPORT.md','contract_test_results.json','sprint4_8_tester_evidence.txt')
    $actualNames = @($Manifest.evidence_files | ForEach-Object { Split-Path -Leaf ([string]$_.path) } | Sort-Object)
    if (($actualNames -join '|') -ne (($expectedNames | Sort-Object) -join '|')) { Fail 'manifest evidence file set mismatch' }
    foreach ($entry in @($Manifest.evidence_files)) {
        if ($entry.path -match 'evidence_blob_manifest\.json$') { Fail 'manifest must not hash itself' }
        if ([string]$entry.sha256 -notmatch '^[0-9a-f]{64}$') { Fail "invalid repository hash for $($entry.path)" }
        if ((Get-GitBlobSha256 $Root $Revision ([string]$entry.path)) -ne [string]$entry.sha256) { Fail "repository blob SHA-256 mismatch for $($entry.path)" }
    }
}

try {
    $repo = (Resolve-Path -LiteralPath $RepositoryRoot).Path
    Invoke-GitText @('-C',$repo,'rev-parse','--is-inside-work-tree') | Out-Null
    if ($Mode -eq 'Generate') {
        foreach ($pair in @(@($OutputDirectory,'OutputDirectory'),@($ArchitectureCompileLog,'ArchitectureCompileLog'),@($TestCompileLog,'TestCompileLog'),@($Run1Log,'Run1Log'),@($Run2Log,'Run2Log'),@($CompiledTestEx5,'CompiledTestEx5'),@($TestedSourceSha,'TestedSourceSha'),@($ExpectedSourceTreeSha,'ExpectedSourceTreeSha'),@($ExpectedArchitectureCompileLogSha256,'ExpectedArchitectureCompileLogSha256'),@($ExpectedTestCompileLogSha256,'ExpectedTestCompileLogSha256'),@($ExpectedRun1LogSha256,'ExpectedRun1LogSha256'),@($ExpectedRun2LogSha256,'ExpectedRun2LogSha256'),@($ExpectedCompiledTestEx5Sha256,'ExpectedCompiledTestEx5Sha256'),@($ExpectedVerificationSourceDigest,'ExpectedVerificationSourceDigest'))) { Require-Value $pair[0] $pair[1] }
        $source = Invoke-GitText @('-C',$repo,'rev-parse',"${TestedSourceSha}^{commit}"); if ($source -ne $TestedSourceSha.ToLowerInvariant()) { Fail 'tested source SHA mismatch' }
        $tree = Invoke-GitText @('-C',$repo,'rev-parse',"${source}^{tree}"); if ($tree -ne $ExpectedSourceTreeSha.ToLowerInvariant()) { Fail 'source tree mismatch' }
        $archPath=Resolve-RequiredFile $ArchitectureCompileLog 'architecture compile log'; $testPath=Resolve-RequiredFile $TestCompileLog 'test compile log'; $run1Path=Resolve-RequiredFile $Run1Log 'Run 1 log'; $run2Path=Resolve-RequiredFile $Run2Log 'Run 2 log'; $ex5Path=Resolve-RequiredFile $CompiledTestEx5 'compiled test EX5'
        if ($run1Path -eq $run2Path) { Fail 'Run 1 and Run 2 must be distinct explicit inputs' }
        $rawArch=Assert-ExpectedRawHash $archPath $ExpectedArchitectureCompileLogSha256 'architecture compile log'; $rawTest=Assert-ExpectedRawHash $testPath $ExpectedTestCompileLogSha256 'test compile log'; $rawRun1=Assert-ExpectedRawHash $run1Path $ExpectedRun1LogSha256 'Run 1 log'; $rawRun2=Assert-ExpectedRawHash $run2Path $ExpectedRun2LogSha256 'Run 2 log'; $ex5Sha=Assert-ExpectedRawHash $ex5Path $ExpectedCompiledTestEx5Sha256 'compiled test EX5'
        $arch=Read-Compile $archPath 'architecture'; $test=Read-Compile $testPath 'test'; $run1=Read-Run $run1Path 'Run 1' $rawRun1; $run2=Read-Run $run2Path 'Run 2' $rawRun2
        foreach ($field in @('total','passed','failed','skipped','signature','schema','contract_policy','suite')) { if ([string]$run1.Machine.$field -ne [string]$run2.Machine.$field) { Fail "run determinism mismatch: $field" } }
        $credibility=Get-Credibility $repo $source
        $manifestSha=Get-GitBlobSha256 $repo $source $ManifestRelative; $iniSha=Get-GitBlobSha256 $repo $source $ConfigIniRelative; $setSha=Get-GitBlobSha256 $repo $source $ConfigSetRelative
        $digestLines=@('format=SWV5-SPRINT48-PHASE-D-VERIFICATION-SOURCE-V1',"tested_source_commit=$source","source_tree=$tree","architecture_compile_raw_sha256=$rawArch","test_compile_raw_sha256=$rawTest","run_1_raw_sha256=$rawRun1","run_2_raw_sha256=$rawRun2","run_1_signature=$ExpectedSignature","run_2_signature=$ExpectedSignature","schema=$ExpectedSchema","production_policy=$ExpectedPolicy","suite=$ExpectedSuite","terminal_build=$ExpectedBuild","server=$ExpectedServer",'account_mode=HEDGING','ontester=1',"test_manifest_git_blob_sha256=$manifestSha","run_config_ini_sha256=$iniSha","run_config_set_sha256=$setSha","compiled_test_ex5_sha256=$ex5Sha")
        $verificationDigest=Get-Sha256Bytes $Utf8NoBom.GetBytes(($digestLines -join "`n")); if ($verificationDigest -ne $ExpectedVerificationSourceDigest.ToLowerInvariant()) { Fail 'verification-source digest mismatch' }
        $exporterSha=Get-FileSha256 $PSCommandPath; $sourceTimestamp=Invoke-GitText @('-C',$repo,'show','-s','--format=%cI',$source)
        $result=[ordered]@{ schema='SWV5-SPRINT48-EVIDENCE-V1'; verdict='PASS'; tested_source_commit=$source; source_tree=$tree; source_commit_timestamp=$sourceTimestamp; verification_source_digest=$verificationDigest; exporter_sha256=$exporterSha; hash_authority='GIT_BLOB_BYTES_SHA256'; raw_input_hash_authority='EXACT_EXTERNAL_FILE_BYTES_SHA256'; repository_hash_manifest='evidence_blob_manifest.json'; result_schema=$ExpectedSchema; production_policy=$ExpectedPolicy; suite=$ExpectedSuite; architecture_compile=$arch; test_compile=$test; raw_inputs=[ordered]@{architecture_compile_log_sha256=$rawArch;test_compile_log_sha256=$rawTest;run_1_sha256=$rawRun1;run_2_sha256=$rawRun2}; runs=@([ordered]@{number=1;total=846;passed=846;failed=0;skipped=0;signature=$ExpectedSignature;build=6090;server=$ExpectedServer;account_mode='HEDGING';ontester=1;first_raw_clock=$run1.FirstRawClock;last_raw_clock=$run1.LastRawClock},[ordered]@{number=2;total=846;passed=846;failed=0;skipped=0;signature=$ExpectedSignature;build=6090;server=$ExpectedServer;account_mode='HEDGING';ontester=1;first_raw_clock=$run2.FirstRawClock;last_raw_clock=$run2.LastRawClock}); deterministic=$true; credibility=$credibility; behavioral=773; supporting=59; conformance=14; weak=0; executable=846 }
        $output=[IO.Path]::GetFullPath($OutputDirectory)
        Write-DeterministicText (Join-Path $output 'contract_test_results.json') ($result | ConvertTo-Json -Depth 10)
        Write-DeterministicText (Join-Path $output 'COMPILE_REPORT.md') (@('# Sprint 4.8 Compile Report','',"Tested source: ``$source``","Source tree: ``$tree``",'',"Architecture: 0 errors / 0 warnings / X64 Regular / build $ExpectedBuild","Architecture raw SHA-256: ``$rawArch``",'',"Contract tests: 0 errors / 0 warnings / X64 Regular / build $ExpectedBuild","Test compile raw SHA-256: ``$rawTest``",'',"Verification-source digest: ``$verificationDigest``",'Repository evidence hash authority: GIT_BLOB_BYTES_SHA256','Raw-input hash authority: EXACT_EXTERNAL_FILE_BYTES_SHA256') -join "`n")
        Write-DeterministicText (Join-Path $output 'VERIFICATION_REPORT.md') (@('# Sprint 4.8 Immutable Verification Report','','Verdict: PASS',"Tested source: ``$source``","Source tree: ``$tree``","Source timestamp: ``$sourceTimestamp``","Verification-source digest: ``$verificationDigest``",'',"Run 1: 846/846 passed, 0 failed, 0 skipped, signature ``$ExpectedSignature``","Run 2: 846/846 passed, 0 failed, 0 skipped, signature ``$ExpectedSignature``",'Determinism: IDENTICAL',"Schema: ``$ExpectedSchema``","Policy: ``$ExpectedPolicy``","Suite: ``$ExpectedSuite``","Environment: MetaTrader build $ExpectedBuild, ``$ExpectedServer``, HEDGING test fixture, OnTester 1",'',"Credibility: 773 behavioral, 59 supporting, 14 conformance, 0 weak, 846 executable",'',"Exporter SHA-256: ``$exporterSha``",'Repository evidence hash authority: GIT_BLOB_BYTES_SHA256','Raw-input hash authority: EXACT_EXTERNAL_FILE_BYTES_SHA256','','Governance: Production Contract V5 and Sprint 4.8 remain Candidate / In Review / Unlocked. No Architecture Lock, runtime authorization, production-readiness claim, or merge authorization is made.') -join "`n")
        Write-DeterministicText (Join-Path $output 'sprint4_8_tester_evidence.txt') (@('SPRINT 4.8 IMMUTABLE TESTER EVIDENCE',"TESTED_SOURCE_COMMIT=$source","SOURCE_TREE=$tree","VERIFICATION_SOURCE_DIGEST=$verificationDigest","RUN_1_RAW_SHA256=$rawRun1","RUN_2_RAW_SHA256=$rawRun2",'RAW_INPUT_ENCODING=UTF-16LE_NO_BOM','PACKAGED_ENCODING=UTF-8_NO_BOM_LF','=== RUN 1 RAW TEXT ===',$run1.Text.TrimEnd("`n"),'=== RUN 2 RAW TEXT ===',$run2.Text.TrimEnd("`n")) -join "`n")
        [pscustomobject]$result | ConvertTo-Json -Depth 10
    } elseif ($Mode -eq 'IndexManifest') {
        Require-Value $OutputDirectory 'OutputDirectory'; Require-Value $TestedSourceSha 'TestedSourceSha'; Require-Value $ExpectedSourceTreeSha 'ExpectedSourceTreeSha'
        $source=Invoke-GitText @('-C',$repo,'rev-parse',"${TestedSourceSha}^{commit}"); $tree=Invoke-GitText @('-C',$repo,'rev-parse',"${source}^{tree}")
        if ($source -ne $TestedSourceSha.ToLowerInvariant() -or $tree -ne $ExpectedSourceTreeSha.ToLowerInvariant()) { Fail 'source identity mismatch for manifest' }
        $output=[IO.Path]::GetFullPath($OutputDirectory); if (-not $EvidencePaths -or $EvidencePaths.Count -eq 0) { $EvidencePaths=Get-DefaultEvidencePaths $output }
        $outputRelative=Get-RepositoryRelativePath $repo $output; Assert-EvidenceTreeSet $repo 'INDEX' $outputRelative $false
        $entries=@(); foreach($path in $EvidencePaths){$resolved=Resolve-RequiredFile $path 'semantic evidence file';$relative=Get-RepositoryRelativePath $repo $resolved;$entries+=[pscustomobject][ordered]@{path=$relative;sha256=Get-GitBlobSha256 $repo 'INDEX' $relative}}
        $entries=@($entries|Sort-Object path); if($entries.Count -ne 4){Fail 'manifest requires exactly four semantic evidence files'}
        $manifest=[ordered]@{schema='SWV5-SPRINT48-BLOB-MANIFEST-V1';tested_source_commit=$source;source_tree=$tree;hash_authority='GIT_BLOB_BYTES_SHA256';source='GIT_INDEX';line_endings='LF';final_newline='EXACTLY_ONE';self_hash_policy='MANIFEST_EXCLUDED';evidence_files=$entries}
        if(-not $EvidenceManifestPath){$EvidenceManifestPath=Join-Path $output 'evidence_blob_manifest.json'}; Write-DeterministicText $EvidenceManifestPath ($manifest|ConvertTo-Json -Depth 8); [pscustomobject]$manifest|ConvertTo-Json -Depth 8
    } elseif ($Mode -eq 'VerifyIndex') {
        Require-Value $EvidenceManifestPath 'EvidenceManifestPath'; Require-Value $TestedSourceSha 'TestedSourceSha'; Require-Value $ExpectedSourceTreeSha 'ExpectedSourceTreeSha'; $relative=Get-RepositoryRelativePath $repo (Resolve-RequiredFile $EvidenceManifestPath 'evidence blob manifest'); Assert-EvidenceTreeSet $repo 'INDEX' (Split-Path -Parent $relative) $true; $manifest=Read-BlobManifest $repo 'INDEX' $relative; Verify-BlobManifest $repo 'INDEX' $manifest
        if($manifest.tested_source_commit -ne $TestedSourceSha.ToLowerInvariant() -or $manifest.source_tree -ne $ExpectedSourceTreeSha.ToLowerInvariant()){Fail 'manifest source identity mismatch'}; [pscustomobject][ordered]@{mode='VerifyIndex';verdict='PASS';files=4;tested_source_commit=$manifest.tested_source_commit}|ConvertTo-Json
    } else {
        Require-Value $EvidenceManifestPath 'EvidenceManifestPath'; Require-Value $EvidenceCommitSha 'EvidenceCommitSha'; Require-Value $TestedSourceSha 'TestedSourceSha'; Require-Value $ExpectedSourceTreeSha 'ExpectedSourceTreeSha'; $commit=Invoke-GitText @('-C',$repo,'rev-parse',"${EvidenceCommitSha}^{commit}"); $relative=Get-RepositoryRelativePath $repo $EvidenceManifestPath; Assert-EvidenceTreeSet $repo $commit (Split-Path -Parent $relative) $true; $manifest=Read-BlobManifest $repo $commit $relative; Verify-BlobManifest $repo $commit $manifest
        $parent=Invoke-GitText @('-C',$repo,'rev-parse',"${commit}^"); if($parent -ne $TestedSourceSha.ToLowerInvariant() -or $manifest.tested_source_commit -ne $TestedSourceSha.ToLowerInvariant() -or $manifest.source_tree -ne $ExpectedSourceTreeSha.ToLowerInvariant()){Fail 'evidence commit linkage mismatch'}; [pscustomobject][ordered]@{mode='VerifyCommit';verdict='PASS';files=4;tested_source_commit=$manifest.tested_source_commit;evidence_commit=$commit}|ConvertTo-Json
    }
    exit 0
} catch { Write-Error $_.Exception.Message; exit 1 }
