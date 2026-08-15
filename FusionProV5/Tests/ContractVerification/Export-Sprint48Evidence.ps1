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
    [string]$ExporterTestResults,
    [int]$ExpectedTestTotal,
    [string]$ExpectedDeterministicSignature,
    [string]$ExpectedSuiteIdentity = 'SPRINT4.8-V5-FULL',
    [ValidatePattern('^[0-9a-fA-F]{40}$')][string]$TestedSourceSha,
    [ValidatePattern('^[0-9a-fA-F]{40}$')][string]$ExpectedSourceTreeSha,
    [ValidatePattern('^[0-9a-fA-F]{64}$')][string]$ExpectedArchitectureCompileLogSha256,
    [ValidatePattern('^[0-9a-fA-F]{64}$')][string]$ExpectedTestCompileLogSha256,
    [ValidatePattern('^[0-9a-fA-F]{64}$')][string]$ExpectedRun1LogSha256,
    [ValidatePattern('^[0-9a-fA-F]{64}$')][string]$ExpectedRun2LogSha256,
    [ValidatePattern('^[0-9a-fA-F]{64}$')][string]$ExpectedCompiledTestEx5Sha256,
    [ValidatePattern('^[0-9a-fA-F]{64}$')][string]$ExpectedExporterTestResultsSha256,
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
$ExpectedSchema = 'SWV5-CONTRACT-TEST-RESULT-V5'
$ExpectedPolicy = 'SWV5-PRODUCTION-V5'
$ExpectedBuild = '6090'
$ExpectedServer = 'Exness-MT5Trial6'
$ManifestRelative = 'SOMWANG_XAU_M15_FUSION_PRO_V5_SPRINT4_3_CONTRACT_TESTS.mq5'
$ConfigIniRelative = 'FusionProV5/Tests/ContractVerification/sprint4_8_b11_full_once.ini'
$ConfigSetRelative = 'FusionProV5/Tests/ContractVerification/sprint4_8_b11_full_once.set'
$TestIdInventoryRelative = 'FusionProV5/Tests/ContractVerification/TEST_ID_INVENTORY.txt'
$CredibilityIdInventoryRelative = 'FusionProV5/Tests/ContractVerification/TEST_CREDIBILITY_ID_INVENTORY.txt'
$ExporterTestInventoryRelative = 'FusionProV5/Tests/ContractVerification/EXPORTER_TEST_ID_INVENTORY.txt'
$ExporterRelative = 'FusionProV5/Tests/ContractVerification/Export-Sprint48Evidence.ps1'
$ExporterTestScriptRelative = 'FusionProV5/Tests/ContractVerification/Test-Export-Sprint48Evidence.ps1'

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
function Assert-Sha256Claim([string]$Value,[string]$Label) {
    if ([string]::IsNullOrWhiteSpace($Value) -or $Value -notmatch '^[0-9a-f]{64}$') { Fail "$Label is not a canonical SHA-256 claim" }
    return $Value
}
function Get-SourceIdentity([string]$Root,[string]$Source,[string]$Label) {
    $commit=Invoke-GitText @('-C',$Root,'rev-parse',"${Source}^{commit}")
    if($commit-ne$Source.ToLowerInvariant()){Fail "$Label tested source commit mismatch"}
    $tree=Invoke-GitText @('-C',$Root,'rev-parse',"${commit}^{tree}")
    if($tree-notmatch'^[0-9a-f]{40,64}$'){Fail "$Label derived source tree is invalid"}
    return [pscustomobject]@{Commit=$commit;Tree=$tree}
}
function Get-VerificationSourceDigest([string]$Source,[string]$Tree,[object]$Inputs) {
    $lines=@(
      'format=SWV5-SPRINT48-B11-VERIFICATION-SOURCE-V5',
      "tested_source_commit=$Source","source_tree=$Tree",
      "architecture_compile_raw_sha256=$($Inputs.architecture_compile_raw_sha256)",
      "test_compile_raw_sha256=$($Inputs.test_compile_raw_sha256)",
      "run_1_raw_sha256=$($Inputs.run_1_raw_sha256)","run_2_raw_sha256=$($Inputs.run_2_raw_sha256)",
      "exporter_test_results_raw_sha256=$($Inputs.exporter_test_results_raw_sha256)",
      "run_1_signature=$($Inputs.run_1_signature)","run_2_signature=$($Inputs.run_2_signature)",
      "schema=$($Inputs.schema)","production_policy=$($Inputs.production_policy)","suite=$($Inputs.suite)",
      "terminal_build=$($Inputs.terminal_build)","server=$($Inputs.server)",
      "account_mode=$($Inputs.account_mode)","ontester=$($Inputs.ontester)",
      "test_manifest_git_blob_sha256=$($Inputs.test_manifest_git_blob_sha256)",
      "credibility_inventory_git_blob_sha256=$($Inputs.credibility_inventory_git_blob_sha256)",
      "run_config_ini_sha256=$($Inputs.run_config_ini_sha256)","run_config_set_sha256=$($Inputs.run_config_set_sha256)",
      "compiled_test_ex5_sha256=$($Inputs.compiled_test_ex5_sha256)",
      "exporter_git_blob_sha256=$($Inputs.exporter_git_blob_sha256)",
      "exporter_test_script_git_blob_sha256=$($Inputs.exporter_test_script_git_blob_sha256)"
    )
    return Get-Sha256Bytes $Utf8NoBom.GetBytes(($lines -join "`n"))
}
function Read-Compile([string]$Path,[string]$Label) {
    $text = Read-RawText $Path
    $matches = [regex]::Matches($text,"Result:\s*(\d+) errors,\s*(\d+) warnings,\s*(\d+) ms elapsed,\s*cpu='([^']+)'")
    if ($matches.Count -ne 1) { Fail "$Label compile log must contain exactly one complete Result line" }
    if ([int]$matches[0].Groups[1].Value -ne 0 -or [int]$matches[0].Groups[2].Value -ne 0) { Fail "$Label compile is not 0 errors / 0 warnings" }
    if ($matches[0].Groups[4].Value -ne 'X64 Regular') { Fail "$Label compile is not X64 Regular" }
    return [pscustomobject]@{ errors=0; warnings=0; elapsed_ms=[int]$matches[0].Groups[3].Value; cpu=$matches[0].Groups[4].Value }
}
function Get-ExpectedIds([string]$Repo,[string]$Revision,[string]$RelativePath,[string]$Label) {
    $text=Normalize-Lf (Get-GitBlobText $Repo $Revision $RelativePath);$ids=@()
    foreach($raw in $text -split "`n"){$line=$raw.Trim();if($line-eq''-or$line.StartsWith('#')){continue};if($line-match'^(.*-)(\d+)\.\.(\d+)$'){$prefix=$Matches[1];$start=[int]$Matches[2];$end=[int]$Matches[3];$width=$Matches[2].Length;if($end-lt$start){Fail 'invalid test-ID inventory range'};for($n=$start;$n-le$end;$n++){$ids += $prefix+$n.ToString('D'+$width)}}elseif($line-match'^[A-Za-z0-9][A-Za-z0-9._-]*$'){$ids += $line}else{Fail "invalid test-ID inventory line: $line"}}
    if($ids.Count-eq0-or@($ids|Sort-Object -Unique).Count-ne$ids.Count){Fail "$Label inventory is empty or contains duplicate IDs"}
    return ,$ids
}
function Get-ExpectedTestIds([string]$Repo,[string]$Revision) { return ,(Get-ExpectedIds $Repo $Revision $TestIdInventoryRelative 'MQL test-ID') }
function Get-ExpectedExporterTestIds([string]$Repo,[string]$Revision) { return ,(Get-ExpectedIds $Repo $Revision $ExporterTestInventoryRelative 'exporter test-ID') }

function Test-ExporterOfflineResultObject([object]$Result,[string]$Repo,[string]$Source,[string]$Label) {
    $ids=Get-ExpectedExporterTestIds $Repo $Source
    $exporterSha=Get-GitBlobSha256 $Repo $Source $ExporterRelative
    $scriptSha=Get-GitBlobSha256 $Repo $Source $ExporterTestScriptRelative
    if($Result.schema-ne'SWV5-SPRINT48-EXPORTER-OFFLINE-TEST-V4' -or
       $Result.exporter_path-ne$ExporterRelative -or
       $Result.generated_from-ne'Test-Export-Sprint48Evidence.ps1 - offline controlled fixture V4' -or
       $Result.exporter_sha256-ne$exporterSha -or
       $Result.test_script_sha256-ne$scriptSha -or [int]$Result.total-ne$ids.Count -or [int]$Result.passed-ne$ids.Count -or
       [int]$Result.failed-ne0 -or [int]$Result.skipped-ne0){Fail "$Label offline exporter result identity/count mismatch"}
    $cases=@($Result.cases);if($cases.Count-ne$ids.Count){Fail "$Label offline exporter case count mismatch"}
    $seen=@{};for($i=0;$i-lt$ids.Count;$i++){$case=$cases[$i];$id=[string]$case.id;if($id-ne$ids[$i]-or$seen.ContainsKey($id)-or-not[bool]$case.passed){Fail "$Label offline exporter case mismatch at $i"};$seen[$id]=$true}
    $signatureText=@($cases|ForEach-Object{$_.id+'|'+$_.name+'|'+[bool]$_.passed})-join"`n"
    if([string]$Result.signature-ne(Get-Sha256Bytes $Utf8NoBom.GetBytes($signatureText))){Fail "$Label offline exporter signature mismatch"}
    return [pscustomobject]@{Object=$Result;Ids=$ids;ExporterSha=$exporterSha;TestScriptSha=$scriptSha}
}
function Read-ExporterOfflineResult([string]$Path,[string]$Repo,[string]$Source,[string]$Label) {
    try{$result=(Read-RawText $Path)|ConvertFrom-Json}catch{Fail "$Label offline exporter result is invalid JSON"}
    return Test-ExporterOfflineResultObject $result $Repo $Source $Label
}
function Read-RunText([string]$Text,[string]$Label,[string]$RawSha,[string[]]$ExpectedIds) {
    $normalized = Normalize-Lf $Text
    $machines = [regex]::Matches($normalized,'SWV5_MACHINE_RESULT\s+(\{[^\r\n]+\})')
    if ($machines.Count -ne 1) { Fail "$Label must contain exactly one SWV5_MACHINE_RESULT" }
    try { $machine = $machines[0].Groups[1].Value | ConvertFrom-Json } catch { Fail "$Label machine result is invalid JSON" }
    $expected = [ordered]@{ schema=$ExpectedSchema; contract_policy=$ExpectedPolicy; suite=$ExpectedSuiteIdentity; total=$ExpectedTestTotal; passed=$ExpectedTestTotal; failed=0; skipped=0; signature=$ExpectedDeterministicSignature }
    foreach ($name in $expected.Keys) {
        $property = $machine.PSObject.Properties[$name]; if ($null -eq $property -or [string]$property.Value -ne [string]$expected[$name]) { Fail "$Label $name mismatch" }
    }
    if (-not [bool]$machine.deterministic) { Fail "$Label deterministic flag is false" }
    $records=[regex]::Matches($normalized,'SWV5_TEST\s+id=([^\s]+)\s+domain=([^\s]+)\s+outcome=(PASS|FAIL|SKIP)\s+expected=([^\s]*)\s+actual=([^\s]*)\s+detail=([^\r\n]*)')
    $expectedCopies=2;$expectedRecordCount=$ExpectedIds.Count*$expectedCopies
    if($records.Count-ne$expectedRecordCount){Fail "$Label exact test-record count mismatch"}
    for($copy=0;$copy-lt$expectedCopies;$copy++){
        $seen=@{};$pass=0;$fail=0;$skip=0
        for($index=0;$index-lt$ExpectedIds.Count;$index++){$record=$records[$copy*$ExpectedIds.Count+$index];$id=$record.Groups[1].Value;$outcome=$record.Groups[3].Value;if([string]::IsNullOrWhiteSpace($id)-or$seen.ContainsKey($id)){Fail "$Label empty or duplicate test ID"};$seen[$id]=$true;if($id-ne$ExpectedIds[$index]){Fail "$Label missing, unexpected, or reordered test ID at record $index"};switch($outcome){'PASS'{$pass++}'FAIL'{$fail++}'SKIP'{$skip++}default{Fail "$Label invalid test outcome"}}}
        if($seen.Count-ne$ExpectedIds.Count-or$pass-ne[int]$machine.passed-or$fail-ne[int]$machine.failed-or$skip-ne[int]$machine.skipped-or($pass+$fail+$skip)-ne[int]$machine.total){Fail "$Label record/summary cross-check mismatch"}
    }
    $metadata = [regex]::Matches($normalized,'SWV5_RUN_METADATA\s+suite=([^\s]+)\s+fixture_account_mode=([^\s]+)\s+fixture_broker=([^\s]+)\s+fixture_server=([^\s]+)\s+broker_access=([^\s]+)')
    if ($metadata.Count -ne 1 -or $metadata[0].Groups[1].Value -ne $ExpectedSuiteIdentity -or $metadata[0].Groups[2].Value -ne 'HEDGING' -or $metadata[0].Groups[5].Value -ne 'false') { Fail "$Label metadata mismatch" }
    $builds = [regex]::Matches($normalized,'authorized \(agent build (\d+)\)'); if ($builds.Count -ne 1 -or $builds[0].Groups[1].Value -ne $ExpectedBuild) { Fail "$Label terminal build mismatch" }
    $servers = [regex]::Matches($normalized,'EURUSD,M1 \(([^)]+)\): testing of'); if ($servers.Count -ne 1 -or $servers[0].Groups[1].Value -ne $ExpectedServer) { Fail "$Label Demo/Trial server mismatch" }
    if ([regex]::Matches($normalized,'SWV5_ONTESTER_SUCCESS\s+result=1').Count -ne 1 -or [regex]::Matches($normalized,'OnTester result 1').Count -ne 1) { Fail "$Label OnTester result mismatch" }
    $clocks = [regex]::Matches($normalized,'(?m)^[A-Z]{2}\s+0\s+(\d{2}:\d{2}:\d{2}\.\d{3})\s+')
    if ($clocks.Count -eq 0) { Fail "$Label contains no raw tester clock" }
    return [pscustomobject]@{ Machine=$machine; Build=$ExpectedBuild; Server=$ExpectedServer; AccountMode='HEDGING'; OnTester=1; RawSha256=$RawSha; FirstRawClock=$clocks[0].Groups[1].Value; LastRawClock=$clocks[$clocks.Count-1].Groups[1].Value; Text=$normalized }
}
function Read-Run([string]$Path,[string]$Label,[string]$RawSha,[string[]]$ExpectedIds) {
    return Read-RunText (Read-RawText $Path) $Label $RawSha $ExpectedIds
}
function Get-Credibility([string]$Repo,[string]$Revision) {
    $inventory = Get-GitBlobText $Repo $Revision 'FusionProV5/Tests/ContractVerification/TEST_INVENTORY.md'
    $matrix = Get-GitBlobText $Repo $Revision 'FusionProV5/Tests/ContractVerification/TEST_CREDIBILITY_MATRIX.md'
    $authority = Normalize-Lf (Get-GitBlobText $Repo $Revision $CredibilityIdInventoryRelative)
    $expectedIds = Get-ExpectedTestIds $Repo $Revision
    $totalMatch = [regex]::Match($inventory,'(?m)^\|\s*\*\*Total\*\*\s*\|\s*\|\s*\*\*(\d+)\*\*')
    if (-not $totalMatch.Success -or [int]$totalMatch.Groups[1].Value -ne $ExpectedTestTotal) { Fail 'credibility inventory total mismatch' }
    $known = @('MERGE_GATING_BEHAVIOR','STATE_TRANSITION','NEGATIVE_FAIL_CLOSED','ROUND_TRIP','INVARIANT_BEHAVIOR','SUPPORTING_PURE_FUNCTION','CONFORMANCE_ONLY','WEAK_FALSE_POSITIVE')
    $actual = [ordered]@{}; foreach($category in $known){$actual[$category]=0}
    $mappedIds=@();$seen=@{}
    foreach($raw in $authority -split "`n"){
        $line=$raw.Trim();if($line-eq''-or$line.StartsWith('#')){continue}
        if($line-notmatch'^([^|]+)\|([^|]+)$'){Fail "invalid credibility authority line: $line"}
        $category=$Matches[1];$spec=$Matches[2]
        if($known-notcontains$category){Fail "unknown credibility category: $category"}
        $expanded=@()
        if($spec-match'^(.*-)(\d+)\.\.(\d+)$'){$prefix=$Matches[1];$start=[int]$Matches[2];$end=[int]$Matches[3];$width=$Matches[2].Length;if($end-lt$start){Fail 'invalid credibility test-ID range'};for($n=$start;$n-le$end;$n++){$expanded+=$prefix+$n.ToString('D'+$width)}}
        elseif($spec-match'^[A-Za-z0-9][A-Za-z0-9._-]*$'){$expanded=@($spec)}else{Fail "invalid credibility test ID: $spec"}
        foreach($id in $expanded){if($seen.ContainsKey($id)){Fail "duplicate credibility classification ID: $id"};$seen[$id]=$category;$mappedIds+=$id;$actual[$category]++}
    }
    if($mappedIds.Count-ne$expectedIds.Count){Fail 'credibility authority count differs from executable inventory'}
    for($i=0;$i-lt$expectedIds.Count;$i++){if($mappedIds[$i]-ne$expectedIds[$i]){Fail "credibility authority missing, phantom, or reordered ID at $i"}}
    foreach ($category in $known) {
        $match = [regex]::Match($matrix,"(?m)^\|\s*``$category``\s*\|\s*(\d+)\s*\|")
        if (-not $match.Success -or [int]$match.Groups[1].Value -ne $actual[$category]) { Fail "credibility headline/per-ID category $category mismatch" }
    }
    if (($actual.Values | Measure-Object -Sum).Sum -ne $ExpectedTestTotal -or $actual.WEAK_FALSE_POSITIVE -ne 0) { Fail 'credibility sum or weak count mismatch' }
    return [pscustomobject]$actual
}
function Get-DefaultEvidencePaths([string]$Output) {
    return @((Join-Path $Output 'COMPILE_REPORT.md'),(Join-Path $Output 'VERIFICATION_REPORT.md'),(Join-Path $Output 'contract_test_results.json'),(Join-Path $Output 'sprint4_8_tester_evidence.txt'),(Join-Path $Output 'exporter_test_results.json'))
}
function Assert-EvidenceTreeSet([string]$Root,[string]$Revision,[string]$DirectoryRelative,[bool]$IncludeManifest) {
    $DirectoryRelative=$DirectoryRelative.Replace('\','/').TrimEnd('/')
    $listed = if($Revision -eq 'INDEX'){Invoke-GitText @('-C',$Root,'ls-files','--cached','--',$DirectoryRelative)}else{Invoke-GitText @('-C',$Root,'ls-tree','-r','--name-only',$Revision,'--',$DirectoryRelative)}
    $actual=@($listed -split "`n"|Where-Object{-not[string]::IsNullOrWhiteSpace($_)}|Sort-Object)
    $expected=@("$DirectoryRelative/COMPILE_REPORT.md","$DirectoryRelative/VERIFICATION_REPORT.md","$DirectoryRelative/contract_test_results.json","$DirectoryRelative/sprint4_8_tester_evidence.txt","$DirectoryRelative/exporter_test_results.json")
    if($IncludeManifest){$expected += "$DirectoryRelative/evidence_blob_manifest.json"}
    if(($actual-join'|')-ne(($expected|Sort-Object)-join'|')){Fail 'unexpected or missing evidence-directory file'}
}
function Read-BlobManifest([string]$Root,[string]$Revision,[string]$RelativePath) {
    try { $manifest = (Get-GitBlobText $Root $Revision $RelativePath) | ConvertFrom-Json } catch { Fail 'evidence blob manifest is invalid JSON' }
    if ($manifest.schema -ne 'SWV5-SPRINT48-BLOB-MANIFEST-V1' -or $manifest.hash_authority -ne 'GIT_BLOB_BYTES_SHA256' -or $manifest.self_hash_policy -ne 'MANIFEST_EXCLUDED') { Fail 'evidence blob manifest policy mismatch' }
    if (@($manifest.evidence_files).Count -ne 5) { Fail 'evidence blob manifest must contain exactly five semantic files' }
    return $manifest
}
function Verify-BlobManifest([string]$Root,[string]$Revision,[object]$Manifest) {
    $expectedNames = @('COMPILE_REPORT.md','VERIFICATION_REPORT.md','contract_test_results.json','sprint4_8_tester_evidence.txt','exporter_test_results.json')
    $actualNames = @($Manifest.evidence_files | ForEach-Object { Split-Path -Leaf ([string]$_.path) } | Sort-Object)
    if (($actualNames -join '|') -ne (($expectedNames | Sort-Object) -join '|')) { Fail 'manifest evidence file set mismatch' }
    foreach ($entry in @($Manifest.evidence_files)) {
        if ($entry.path -match 'evidence_blob_manifest\.json$') { Fail 'manifest must not hash itself' }
        if ([string]$entry.sha256 -notmatch '^[0-9a-f]{64}$') { Fail "invalid repository hash for $($entry.path)" }
        if ((Get-GitBlobSha256 $Root $Revision ([string]$entry.path)) -ne [string]$entry.sha256) { Fail "repository blob SHA-256 mismatch for $($entry.path)" }
    }
}

function Get-EvidenceEntry([object]$Manifest,[string]$Name) {
    $entries=@($Manifest.evidence_files|Where-Object{(Split-Path -Leaf ([string]$_.path))-eq$Name})
    if($entries.Count-ne1){Fail "evidence artifact $Name is missing or duplicated"};return $entries[0]
}
function Get-EvidenceText([string]$Root,[string]$Revision,[object]$Manifest,[string]$Name) {
    $entry=Get-EvidenceEntry $Manifest $Name
    return Normalize-Lf (Get-GitBlobText $Root $Revision ([string]$entry.path))
}
function Rebuild-VerificationSourceDigest([string]$Root,[string]$Source,[string]$Tree,[object]$Contract,[object]$Run1,[object]$Run2,[object]$OfflineValidated,[string]$OfflineBlobSha,[string]$Label) {
    $property=$Contract.PSObject.Properties['verification_source_inputs'];if($null-eq$property){Fail "$Label verification-source inputs are missing"};$inputs=$property.Value
    foreach($name in @('architecture_compile_raw_sha256','test_compile_raw_sha256','run_1_raw_sha256','run_2_raw_sha256','exporter_test_results_raw_sha256','test_manifest_git_blob_sha256','credibility_inventory_git_blob_sha256','run_config_ini_sha256','run_config_set_sha256','compiled_test_ex5_sha256','exporter_git_blob_sha256','exporter_test_script_git_blob_sha256')){
        $claim=$inputs.PSObject.Properties[$name];if($null-eq$claim){Fail "$Label verification-source input $name is missing"};Assert-Sha256Claim ([string]$claim.Value) "$Label $name"|Out-Null
    }
    if($inputs.architecture_compile_raw_sha256-ne$Contract.raw_inputs.architecture_compile_log_sha256-or
       $inputs.test_compile_raw_sha256-ne$Contract.raw_inputs.test_compile_log_sha256-or
       $inputs.run_1_raw_sha256-ne$Contract.raw_inputs.run_1_sha256-or$inputs.run_2_raw_sha256-ne$Contract.raw_inputs.run_2_sha256-or
       $inputs.exporter_test_results_raw_sha256-ne$OfflineBlobSha-or
       $inputs.compiled_test_ex5_sha256-ne$Contract.raw_inputs.compiled_test_ex5_sha256-or
       [string]$inputs.run_1_signature-ne[string]$Run1.Machine.signature-or[string]$inputs.run_2_signature-ne[string]$Run2.Machine.signature-or
       $inputs.schema-ne$ExpectedSchema-or$inputs.production_policy-ne$ExpectedPolicy-or$inputs.suite-ne$ExpectedSuiteIdentity-or
       [string]$inputs.terminal_build-ne$ExpectedBuild-or$inputs.server-ne$ExpectedServer-or$inputs.account_mode-ne'HEDGING'-or[int]$inputs.ontester-ne1){Fail "$Label canonical verification-source semantic input mismatch"}
    $derivedManifest=Get-GitBlobSha256 $Root $Source $ManifestRelative
    $derivedCredibility=Get-GitBlobSha256 $Root $Source $CredibilityIdInventoryRelative
    $derivedIni=Get-GitBlobSha256 $Root $Source $ConfigIniRelative
    $derivedSet=Get-GitBlobSha256 $Root $Source $ConfigSetRelative
    if($inputs.test_manifest_git_blob_sha256-ne$derivedManifest-or$inputs.credibility_inventory_git_blob_sha256-ne$derivedCredibility-or$inputs.run_config_ini_sha256-ne$derivedIni-or
       $inputs.run_config_set_sha256-ne$derivedSet-or$inputs.exporter_git_blob_sha256-ne$OfflineValidated.ExporterSha-or
       $inputs.exporter_test_script_git_blob_sha256-ne$OfflineValidated.TestScriptSha){Fail "$Label repository-derived verification-source input mismatch"}
    return Get-VerificationSourceDigest $Source $Tree $inputs
}
function Validate-EvidenceSemantics([string]$Root,[string]$Revision,[object]$Manifest,[string]$Source,[string]$Tree,[string]$Label,[string]$ContentRoot='') {
    $identity=Get-SourceIdentity $Root $Source $Label
    if($Tree-ne$identity.Tree){Fail "$Label claimed source tree differs from Git-derived tree"}
    $Source=$identity.Commit;$Tree=$identity.Tree
    $expectedIds=Get-ExpectedTestIds $Root $Source
    if(-not[string]::IsNullOrWhiteSpace($ContentRoot)){
        $contractText=Normalize-Lf (Read-RawText (Resolve-RequiredFile (Join-Path $ContentRoot 'contract_test_results.json') "$Label contract result"))
        $compileText=Normalize-Lf (Read-RawText (Resolve-RequiredFile (Join-Path $ContentRoot 'COMPILE_REPORT.md') "$Label compile report"))
        $reportText=Normalize-Lf (Read-RawText (Resolve-RequiredFile (Join-Path $ContentRoot 'VERIFICATION_REPORT.md') "$Label verification report"))
        $testerText=Normalize-Lf (Read-RawText (Resolve-RequiredFile (Join-Path $ContentRoot 'sprint4_8_tester_evidence.txt') "$Label tester evidence"))
        $offlineFile=Resolve-RequiredFile (Join-Path $ContentRoot 'exporter_test_results.json') "$Label offline result"
        $offlineText=Normalize-Lf (Read-RawText $offlineFile);$offlineBlobSha=Get-FileSha256 $offlineFile
    }else{
        $contractText=Get-EvidenceText $Root $Revision $Manifest 'contract_test_results.json'
        $compileText=Get-EvidenceText $Root $Revision $Manifest 'COMPILE_REPORT.md'
        $reportText=Get-EvidenceText $Root $Revision $Manifest 'VERIFICATION_REPORT.md'
        $testerText=Get-EvidenceText $Root $Revision $Manifest 'sprint4_8_tester_evidence.txt'
        $offlineText=Get-EvidenceText $Root $Revision $Manifest 'exporter_test_results.json'
        $offlineBlobSha=Get-GitBlobSha256 $Root $Revision ([string](Get-EvidenceEntry $Manifest 'exporter_test_results.json').path)
    }
    try{$contract=$contractText|ConvertFrom-Json}catch{Fail "$Label contract result JSON is invalid"}
    if($contract.verdict-ne'PASS' -or $contract.tested_source_commit-ne$Source -or $contract.source_tree-ne$Tree -or
       $contract.result_schema-ne$ExpectedSchema -or $contract.production_policy-ne$ExpectedPolicy -or
       $contract.suite-ne'SPRINT4.8-V5-FULL' -or -not[bool]$contract.deterministic -or
       [int]$contract.executable-ne$expectedIds.Count -or [int]$contract.exact_test_record_count-ne$expectedIds.Count -or
       -not[bool]$contract.exact_test_ids_verified){Fail "$Label contract result identity/summary mismatch"}
    if(@($contract.runs).Count-ne2){Fail "$Label must contain exactly two run summaries"}
    $ExpectedTestTotal=$expectedIds.Count;$ExpectedDeterministicSignature=[string]$contract.runs[0].signature;$ExpectedSuiteIdentity='SPRINT4.8-V5-FULL'
    foreach($run in @($contract.runs)){if([int]$run.total-ne$ExpectedTestTotal-or[int]$run.passed-ne$ExpectedTestTotal-or[int]$run.failed-ne0-or[int]$run.skipped-ne0-or[string]$run.signature-ne$ExpectedDeterministicSignature){Fail "$Label run summary mismatch"}}
    if($compileText-notmatch'Architecture: 0 errors / 0 warnings / X64 Regular' -or $compileText-notmatch'Contract tests: 0 errors / 0 warnings / X64 Regular'){Fail "$Label compile report mismatch"}
    foreach($required in @("Architecture raw SHA-256: ``$($contract.raw_inputs.architecture_compile_log_sha256)``","Test compile raw SHA-256: ``$($contract.raw_inputs.test_compile_log_sha256)``","Compiled test EX5 raw SHA-256: ``$($contract.raw_inputs.compiled_test_ex5_sha256)``","Exporter offline result raw SHA-256: ``$($contract.raw_inputs.exporter_test_results_sha256)``")){if(-not$compileText.Contains($required)){Fail "$Label compile/raw-hash cross-check failed"}}
    foreach($required in @($Source,$Tree,[string]$contract.verification_source_digest,$ExpectedDeterministicSignature,"Run 1: $ExpectedTestTotal/$ExpectedTestTotal passed","Run 2: $ExpectedTestTotal/$ExpectedTestTotal passed")){if(-not$reportText.Contains($required)){Fail "$Label verification report cross-check failed"}}
    foreach($required in @("TESTED_SOURCE_COMMIT=$Source","SOURCE_TREE=$Tree","VERIFICATION_SOURCE_DIGEST=$($contract.verification_source_digest)","ARCHITECTURE_COMPILE_RAW_SHA256=$($contract.raw_inputs.architecture_compile_log_sha256)","TEST_COMPILE_RAW_SHA256=$($contract.raw_inputs.test_compile_log_sha256)","RUN_1_RAW_SHA256=$($contract.raw_inputs.run_1_sha256)","RUN_2_RAW_SHA256=$($contract.raw_inputs.run_2_sha256)","COMPILED_TEST_EX5_RAW_SHA256=$($contract.raw_inputs.compiled_test_ex5_sha256)","EXPORTER_TEST_RESULTS_RAW_SHA256=$($contract.raw_inputs.exporter_test_results_sha256)")){if(-not$testerText.Contains($required)){Fail "$Label tester evidence header mismatch"}}
    $streams=[regex]::Match($testerText,'(?s)=== RUN 1 RAW TEXT ===\n(.*?)\n=== RUN 2 RAW TEXT ===\n(.*)\z')
    if(-not$streams.Success){Fail "$Label tester evidence does not contain exactly two labeled raw runs"}
    $run1=Read-RunText $streams.Groups[1].Value "$Label Run 1" ([string]$contract.raw_inputs.run_1_sha256) $expectedIds
    $run2=Read-RunText $streams.Groups[2].Value.TrimEnd("`n") "$Label Run 2" ([string]$contract.raw_inputs.run_2_sha256) $expectedIds
    foreach($field in @('total','passed','failed','skipped','signature','schema','contract_policy','suite')){if([string]$run1.Machine.$field-ne[string]$run2.Machine.$field){Fail "$Label deterministic stream mismatch: $field"}}
    try{$offline=$offlineText|ConvertFrom-Json}catch{Fail "$Label offline result JSON is invalid"}
    $offlineValidated=Test-ExporterOfflineResultObject $offline $Root $Source $Label
    if($contract.exporter_sha256-ne$offlineValidated.ExporterSha -or
       $contract.exporter_test_script_sha256-ne$offlineValidated.TestScriptSha -or
       $contract.exporter_offline_test_result_sha256-ne$offlineBlobSha -or
       [int]$contract.exporter_offline_test_total-ne$offlineValidated.Ids.Count -or
       $contract.raw_inputs.exporter_test_results_sha256-ne$offlineBlobSha){Fail "$Label exporter evidence cross-check mismatch"}
    $rebuiltVerificationDigest=Rebuild-VerificationSourceDigest $Root $Source $Tree $contract $run1 $run2 $offlineValidated $offlineBlobSha $Label
    if([string]$contract.verification_source_digest-ne$rebuiltVerificationDigest){Fail "$Label verification-source digest reconstruction mismatch"}
    $credibility=Get-Credibility $Root $Source
    foreach($category in @('MERGE_GATING_BEHAVIOR','STATE_TRANSITION','NEGATIVE_FAIL_CLOSED','ROUND_TRIP','INVARIANT_BEHAVIOR','SUPPORTING_PURE_FUNCTION','CONFORMANCE_ONLY','WEAK_FALSE_POSITIVE')){
       if([int]$contract.credibility.$category-ne[int]$credibility.$category){Fail "$Label credibility per-ID-derived category mismatch: $category"}
    }
    if([int]$contract.behavioral-ne($credibility.MERGE_GATING_BEHAVIOR+$credibility.STATE_TRANSITION+$credibility.NEGATIVE_FAIL_CLOSED+$credibility.ROUND_TRIP+$credibility.INVARIANT_BEHAVIOR)-or
       [int]$contract.weak-ne0){Fail "$Label credibility cross-check mismatch"}
    return [pscustomobject]@{Total=$ExpectedTestTotal;Signature=$ExpectedDeterministicSignature;OfflineTotal=$offlineValidated.Ids.Count}
}

try {
    $repo = (Resolve-Path -LiteralPath $RepositoryRoot).Path
    Invoke-GitText @('-C',$repo,'rev-parse','--is-inside-work-tree') | Out-Null
    if ($Mode -eq 'Generate') {
        foreach ($pair in @(@($OutputDirectory,'OutputDirectory'),@($ArchitectureCompileLog,'ArchitectureCompileLog'),@($TestCompileLog,'TestCompileLog'),@($Run1Log,'Run1Log'),@($Run2Log,'Run2Log'),@($CompiledTestEx5,'CompiledTestEx5'),@($ExporterTestResults,'ExporterTestResults'),@($ExpectedDeterministicSignature,'ExpectedDeterministicSignature'),@($TestedSourceSha,'TestedSourceSha'),@($ExpectedSourceTreeSha,'ExpectedSourceTreeSha'),@($ExpectedArchitectureCompileLogSha256,'ExpectedArchitectureCompileLogSha256'),@($ExpectedTestCompileLogSha256,'ExpectedTestCompileLogSha256'),@($ExpectedRun1LogSha256,'ExpectedRun1LogSha256'),@($ExpectedRun2LogSha256,'ExpectedRun2LogSha256'),@($ExpectedCompiledTestEx5Sha256,'ExpectedCompiledTestEx5Sha256'),@($ExpectedExporterTestResultsSha256,'ExpectedExporterTestResultsSha256'),@($ExpectedVerificationSourceDigest,'ExpectedVerificationSourceDigest'))) { Require-Value $pair[0] $pair[1] };if($ExpectedTestTotal-le0){Fail 'ExpectedTestTotal is required and positive'}
        $source = Invoke-GitText @('-C',$repo,'rev-parse',"${TestedSourceSha}^{commit}"); if ($source -ne $TestedSourceSha.ToLowerInvariant()) { Fail 'tested source SHA mismatch' }
        $tree = Invoke-GitText @('-C',$repo,'rev-parse',"${source}^{tree}"); if ($tree -ne $ExpectedSourceTreeSha.ToLowerInvariant()) { Fail 'source tree mismatch' }
        $archPath=Resolve-RequiredFile $ArchitectureCompileLog 'architecture compile log'; $testPath=Resolve-RequiredFile $TestCompileLog 'test compile log'; $run1Path=Resolve-RequiredFile $Run1Log 'Run 1 log'; $run2Path=Resolve-RequiredFile $Run2Log 'Run 2 log'; $ex5Path=Resolve-RequiredFile $CompiledTestEx5 'compiled test EX5'; $offlinePath=Resolve-RequiredFile $ExporterTestResults 'exporter offline-test result'
        if ($run1Path -eq $run2Path) { Fail 'Run 1 and Run 2 must be distinct explicit inputs' }
        $rawArch=Assert-ExpectedRawHash $archPath $ExpectedArchitectureCompileLogSha256 'architecture compile log'; $rawTest=Assert-ExpectedRawHash $testPath $ExpectedTestCompileLogSha256 'test compile log'; $rawRun1=Assert-ExpectedRawHash $run1Path $ExpectedRun1LogSha256 'Run 1 log'; $rawRun2=Assert-ExpectedRawHash $run2Path $ExpectedRun2LogSha256 'Run 2 log'; $ex5Sha=Assert-ExpectedRawHash $ex5Path $ExpectedCompiledTestEx5Sha256 'compiled test EX5'; $offlineRawSha=Assert-ExpectedRawHash $offlinePath $ExpectedExporterTestResultsSha256 'exporter offline-test result'
        $expectedIds=Get-ExpectedTestIds $repo $source;if($expectedIds.Count-ne$ExpectedTestTotal){Fail 'expected test-ID inventory count mismatch'}
        $arch=Read-Compile $archPath 'architecture'; $test=Read-Compile $testPath 'test'; $run1=Read-Run $run1Path 'Run 1' $rawRun1 $expectedIds; $run2=Read-Run $run2Path 'Run 2' $rawRun2 $expectedIds
        foreach ($field in @('total','passed','failed','skipped','signature','schema','contract_policy','suite')) { if ([string]$run1.Machine.$field -ne [string]$run2.Machine.$field) { Fail "run determinism mismatch: $field" } }
        $credibility=Get-Credibility $repo $source
        $offline=Read-ExporterOfflineResult $offlinePath $repo $source 'Generate'
        $manifestSha=Get-GitBlobSha256 $repo $source $ManifestRelative; $credibilitySha=Get-GitBlobSha256 $repo $source $CredibilityIdInventoryRelative; $iniSha=Get-GitBlobSha256 $repo $source $ConfigIniRelative; $setSha=Get-GitBlobSha256 $repo $source $ConfigSetRelative
        $verificationInputs=[ordered]@{architecture_compile_raw_sha256=$rawArch;test_compile_raw_sha256=$rawTest;run_1_raw_sha256=$rawRun1;run_2_raw_sha256=$rawRun2;exporter_test_results_raw_sha256=$offlineRawSha;run_1_signature=$ExpectedDeterministicSignature;run_2_signature=$ExpectedDeterministicSignature;schema=$ExpectedSchema;production_policy=$ExpectedPolicy;suite=$ExpectedSuiteIdentity;terminal_build=$ExpectedBuild;server=$ExpectedServer;account_mode='HEDGING';ontester=1;test_manifest_git_blob_sha256=$manifestSha;credibility_inventory_git_blob_sha256=$credibilitySha;run_config_ini_sha256=$iniSha;run_config_set_sha256=$setSha;compiled_test_ex5_sha256=$ex5Sha;exporter_git_blob_sha256=$offline.ExporterSha;exporter_test_script_git_blob_sha256=$offline.TestScriptSha}
        $verificationDigest=Get-VerificationSourceDigest $source $tree $verificationInputs; if ($verificationDigest -ne $ExpectedVerificationSourceDigest.ToLowerInvariant()) { Fail 'verification-source digest mismatch' }
        $exporterSha=$offline.ExporterSha; if((Get-FileSha256 $PSCommandPath)-ne$exporterSha){Fail 'executing exporter does not match tested source blob'}; $sourceTimestamp=Invoke-GitText @('-C',$repo,'show','-s','--format=%cI',$source)
        $behavioral=$credibility.MERGE_GATING_BEHAVIOR+$credibility.STATE_TRANSITION+$credibility.NEGATIVE_FAIL_CLOSED+$credibility.ROUND_TRIP+$credibility.INVARIANT_BEHAVIOR
        $result=[ordered]@{ schema='SWV5-SPRINT48-EVIDENCE-V1'; verdict='PASS'; tested_source_commit=$source; source_tree=$tree; source_commit_timestamp=$sourceTimestamp; verification_source_digest=$verificationDigest; verification_source_inputs=$verificationInputs; exporter_sha256=$exporterSha; exporter_test_script_sha256=$offline.TestScriptSha; exporter_offline_test_result_sha256=$offlineRawSha; exporter_offline_test_total=$offline.Ids.Count; hash_authority='GIT_BLOB_BYTES_SHA256'; raw_input_hash_authority='EXACT_EXTERNAL_FILE_BYTES_SHA256'; repository_hash_manifest='evidence_blob_manifest.json'; result_schema=$ExpectedSchema; production_policy=$ExpectedPolicy; suite=$ExpectedSuiteIdentity; architecture_compile=$arch; test_compile=$test; raw_inputs=[ordered]@{architecture_compile_log_sha256=$rawArch;test_compile_log_sha256=$rawTest;run_1_sha256=$rawRun1;run_2_sha256=$rawRun2;compiled_test_ex5_sha256=$ex5Sha;exporter_test_results_sha256=$offlineRawSha}; runs=@([ordered]@{number=1;total=$ExpectedTestTotal;passed=$ExpectedTestTotal;failed=0;skipped=0;signature=$ExpectedDeterministicSignature;build=6090;server=$ExpectedServer;account_mode='HEDGING';ontester=1;first_raw_clock=$run1.FirstRawClock;last_raw_clock=$run1.LastRawClock},[ordered]@{number=2;total=$ExpectedTestTotal;passed=$ExpectedTestTotal;failed=0;skipped=0;signature=$ExpectedDeterministicSignature;build=6090;server=$ExpectedServer;account_mode='HEDGING';ontester=1;first_raw_clock=$run2.FirstRawClock;last_raw_clock=$run2.LastRawClock}); deterministic=$true; exact_test_record_count=$ExpectedTestTotal; exact_test_ids_verified=$true; credibility=$credibility; behavioral=$behavioral; supporting=$credibility.SUPPORTING_PURE_FUNCTION; conformance=$credibility.CONFORMANCE_ONLY; weak=$credibility.WEAK_FALSE_POSITIVE; executable=$ExpectedTestTotal }
        $output=[IO.Path]::GetFullPath($OutputDirectory)
        Write-DeterministicText (Join-Path $output 'contract_test_results.json') ($result | ConvertTo-Json -Depth 10)
        Write-DeterministicText (Join-Path $output 'COMPILE_REPORT.md') (@('# Sprint 4.8 Compile Report','',"Tested source: ``$source``","Source tree: ``$tree``",'',"Architecture: 0 errors / 0 warnings / X64 Regular / build $ExpectedBuild","Architecture raw SHA-256: ``$rawArch``",'',"Contract tests: 0 errors / 0 warnings / X64 Regular / build $ExpectedBuild","Test compile raw SHA-256: ``$rawTest``","Compiled test EX5 raw SHA-256: ``$ex5Sha``","Exporter offline result raw SHA-256: ``$offlineRawSha``",'',"Verification-source digest: ``$verificationDigest``",'Repository evidence hash authority: GIT_BLOB_BYTES_SHA256','Raw-input hash authority: EXACT_EXTERNAL_FILE_BYTES_SHA256') -join "`n")
        Write-DeterministicText (Join-Path $output 'VERIFICATION_REPORT.md') (@('# Sprint 4.8 Immutable Verification Report','','Verdict: PASS',"Tested source: ``$source``","Source tree: ``$tree``","Source timestamp: ``$sourceTimestamp``","Verification-source digest: ``$verificationDigest``",'',"Run 1: $ExpectedTestTotal/$ExpectedTestTotal passed, 0 failed, 0 skipped, signature ``$ExpectedDeterministicSignature``","Run 2: $ExpectedTestTotal/$ExpectedTestTotal passed, 0 failed, 0 skipped, signature ``$ExpectedDeterministicSignature``",'Exact per-case records and canonical test IDs: VERIFIED','Determinism: IDENTICAL',"Schema: ``$ExpectedSchema``","Policy: ``$ExpectedPolicy``","Suite: ``$ExpectedSuiteIdentity``","Environment: MetaTrader build $ExpectedBuild, ``$ExpectedServer``, HEDGING test fixture, OnTester 1",'',"Credibility: $behavioral behavioral, $($credibility.SUPPORTING_PURE_FUNCTION) supporting, $($credibility.CONFORMANCE_ONLY) conformance, 0 weak, $ExpectedTestTotal executable",'',"Exporter SHA-256: ``$exporterSha``",'Repository evidence hash authority: GIT_BLOB_BYTES_SHA256','Raw-input hash authority: EXACT_EXTERNAL_FILE_BYTES_SHA256','','Governance: Production Contract V5 and Sprint 4.8 remain Candidate / In Review / Unlocked. No Architecture Lock, runtime authorization, production-readiness claim, or merge authorization is made.') -join "`n")
        Write-DeterministicText (Join-Path $output 'sprint4_8_tester_evidence.txt') (@('SPRINT 4.8 IMMUTABLE TESTER EVIDENCE',"TESTED_SOURCE_COMMIT=$source","SOURCE_TREE=$tree","VERIFICATION_SOURCE_DIGEST=$verificationDigest","ARCHITECTURE_COMPILE_RAW_SHA256=$rawArch","TEST_COMPILE_RAW_SHA256=$rawTest","RUN_1_RAW_SHA256=$rawRun1","RUN_2_RAW_SHA256=$rawRun2","COMPILED_TEST_EX5_RAW_SHA256=$ex5Sha","EXPORTER_TEST_RESULTS_RAW_SHA256=$offlineRawSha",'RAW_INPUT_ENCODING=UTF-16LE_NO_BOM','PACKAGED_ENCODING=UTF-8_NO_BOM_LF','=== RUN 1 RAW TEXT ===',$run1.Text.TrimEnd("`n"),'=== RUN 2 RAW TEXT ===',$run2.Text.TrimEnd("`n")) -join "`n")
        Write-DeterministicText (Join-Path $output 'exporter_test_results.json') (Read-RawText $offlinePath)
        Validate-EvidenceSemantics $repo 'WORKTREE' $null $source $tree 'Generate' $output | Out-Null
        [pscustomobject]$result | ConvertTo-Json -Depth 10
    } elseif ($Mode -eq 'IndexManifest') {
        Require-Value $OutputDirectory 'OutputDirectory'; Require-Value $TestedSourceSha 'TestedSourceSha'; Require-Value $ExpectedSourceTreeSha 'ExpectedSourceTreeSha'
        $source=Invoke-GitText @('-C',$repo,'rev-parse',"${TestedSourceSha}^{commit}"); $tree=Invoke-GitText @('-C',$repo,'rev-parse',"${source}^{tree}")
        if ($source -ne $TestedSourceSha.ToLowerInvariant() -or $tree -ne $ExpectedSourceTreeSha.ToLowerInvariant()) { Fail 'source identity mismatch for manifest' }
        $output=[IO.Path]::GetFullPath($OutputDirectory); if (-not $EvidencePaths -or $EvidencePaths.Count -eq 0) { $EvidencePaths=Get-DefaultEvidencePaths $output }
        $outputRelative=Get-RepositoryRelativePath $repo $output; Assert-EvidenceTreeSet $repo 'INDEX' $outputRelative $false
        $entries=@(); foreach($path in $EvidencePaths){$resolved=Resolve-RequiredFile $path 'semantic evidence file';$relative=Get-RepositoryRelativePath $repo $resolved;$entries+=[pscustomobject][ordered]@{path=$relative;sha256=Get-GitBlobSha256 $repo 'INDEX' $relative}}
        $entries=@($entries|Sort-Object path); if($entries.Count -ne 5){Fail 'manifest requires exactly five semantic evidence files'}
        $manifest=[ordered]@{schema='SWV5-SPRINT48-BLOB-MANIFEST-V1';tested_source_commit=$source;source_tree=$tree;hash_authority='GIT_BLOB_BYTES_SHA256';source='GIT_INDEX';line_endings='LF';final_newline='EXACTLY_ONE';self_hash_policy='MANIFEST_EXCLUDED';evidence_files=$entries}
        if(-not $EvidenceManifestPath){$EvidenceManifestPath=Join-Path $output 'evidence_blob_manifest.json'}; Write-DeterministicText $EvidenceManifestPath ($manifest|ConvertTo-Json -Depth 8); [pscustomobject]$manifest|ConvertTo-Json -Depth 8
    } elseif ($Mode -eq 'VerifyIndex') {
        Require-Value $EvidenceManifestPath 'EvidenceManifestPath'; Require-Value $TestedSourceSha 'TestedSourceSha'; Require-Value $ExpectedSourceTreeSha 'ExpectedSourceTreeSha'; $relative=Get-RepositoryRelativePath $repo (Resolve-RequiredFile $EvidenceManifestPath 'evidence blob manifest'); Assert-EvidenceTreeSet $repo 'INDEX' (Split-Path -Parent $relative) $true; $manifest=Read-BlobManifest $repo 'INDEX' $relative; Verify-BlobManifest $repo 'INDEX' $manifest
        $identity=Get-SourceIdentity $repo $TestedSourceSha 'VerifyIndex';if($ExpectedSourceTreeSha.ToLowerInvariant()-ne$identity.Tree-or$manifest.tested_source_commit-ne$identity.Commit-or$manifest.source_tree-ne$identity.Tree){Fail 'manifest source identity differs from Git-derived source identity'}; $semantic=Validate-EvidenceSemantics $repo 'INDEX' $manifest $identity.Commit $identity.Tree 'VerifyIndex'; [pscustomobject][ordered]@{mode='VerifyIndex';verdict='PASS';files=5;tested_source_commit=$identity.Commit;source_tree=$identity.Tree;tests=$semantic.Total;signature=$semantic.Signature;exporter_tests=$semantic.OfflineTotal}|ConvertTo-Json
    } else {
        Require-Value $EvidenceManifestPath 'EvidenceManifestPath'; Require-Value $EvidenceCommitSha 'EvidenceCommitSha'; Require-Value $TestedSourceSha 'TestedSourceSha'; Require-Value $ExpectedSourceTreeSha 'ExpectedSourceTreeSha'; $commit=Invoke-GitText @('-C',$repo,'rev-parse',"${EvidenceCommitSha}^{commit}"); $relative=Get-RepositoryRelativePath $repo $EvidenceManifestPath; Assert-EvidenceTreeSet $repo $commit (Split-Path -Parent $relative) $true; $manifest=Read-BlobManifest $repo $commit $relative; Verify-BlobManifest $repo $commit $manifest
        $identity=Get-SourceIdentity $repo $TestedSourceSha 'VerifyCommit';$parent=Invoke-GitText @('-C',$repo,'rev-parse',"${commit}^"); if($parent-ne$identity.Commit-or$ExpectedSourceTreeSha.ToLowerInvariant()-ne$identity.Tree-or$manifest.tested_source_commit-ne$identity.Commit-or$manifest.source_tree-ne$identity.Tree){Fail 'evidence commit linkage or Git-derived source identity mismatch'}; $semantic=Validate-EvidenceSemantics $repo $commit $manifest $identity.Commit $identity.Tree 'VerifyCommit'; [pscustomobject][ordered]@{mode='VerifyCommit';verdict='PASS';files=5;tested_source_commit=$identity.Commit;source_tree=$identity.Tree;evidence_commit=$commit;tests=$semantic.Total;signature=$semantic.Signature;exporter_tests=$semantic.OfflineTotal}|ConvertTo-Json
    }
    exit 0
} catch { Write-Error $_.Exception.Message; exit 1 }
