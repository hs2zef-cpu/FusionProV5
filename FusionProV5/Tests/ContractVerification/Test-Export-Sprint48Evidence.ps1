# TEST ONLY
# NOT FOR PRODUCTION
# NO BROKER ACCESS
# Offline controlled-fixture regression tests for Export-Sprint48Evidence.ps1.

[CmdletBinding()]
param(
    [string]$ExporterPath,
    [string]$ResultPath
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

function Write-Lf([string]$Path,[string]$Text) {
    $parent=Split-Path -Parent $Path; if(-not(Test-Path -LiteralPath $parent)){New-Item -ItemType Directory -Path $parent -Force|Out-Null}
    $canonical=(($Text -replace "`r`n","`n" -replace "`r","`n").TrimEnd("`n"))+"`n"
    [IO.File]::WriteAllText($Path,$canonical,$Utf8NoBom)
}
function Get-Sha([string]$Path){return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()}
function Get-ShaBytes([byte[]]$Bytes){$sha=[Security.Cryptography.SHA256]::Create();try{return ([BitConverter]::ToString($sha.ComputeHash($Bytes))).Replace('-','').ToLowerInvariant()}finally{$sha.Dispose()}}
function Git([string[]]$Arguments){$saved=$ErrorActionPreference;$ErrorActionPreference='Continue';$r=& git.exe @Arguments 2>&1;$code=$LASTEXITCODE;$ErrorActionPreference=$saved;if($code-ne 0){throw "fixture git failed: git $($Arguments-join' '): $($r-join' ')"};return (($r|ForEach-Object{"$_"})-join"`n").Trim()}
function Record([string]$Id,[string]$Name,[bool]$Condition){if($Condition){$script:passed++}else{$script:failed++};$script:records += [pscustomobject][ordered]@{id=$Id;name=$Name;passed=$Condition}}
function Invoke-Exporter([string[]]$Arguments,[string]$Name){$out=Join-Path $tempRoot $Name;$saved=$ErrorActionPreference;$ErrorActionPreference='Continue';& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $fixtureExporter @Arguments *> $out;$code=$LASTEXITCODE;$ErrorActionPreference=$saved;return [pscustomobject]@{ExitCode=$code;Output=$out}}
function Blob-Sha([string]$Commit,[string]$Relative){$bytes=& git.exe -C $repo show "${Commit}:$Relative" --no-textconv | Out-String; if($LASTEXITCODE-ne 0){throw 'blob read failed'}; $temp=Join-Path $tempRoot 'blob.tmp'; & git.exe -C $repo cat-file blob (& git.exe -C $repo rev-parse "${Commit}:$Relative") | Set-Content -LiteralPath $temp -Encoding Byte; return (Get-Sha $temp)}

try {
    if(-not(Test-Path -LiteralPath $ExporterPath -PathType Leaf)){throw "exporter missing: $ExporterPath"}
    New-Item -ItemType Directory -Path $tempRoot -Force|Out-Null
    $repo=Join-Path $tempRoot 'repo';New-Item -ItemType Directory -Path $repo|Out-Null;Git @('-C',$repo,'init','--quiet')|Out-Null
    $testDir=Join-Path $repo 'FusionProV5\Tests\ContractVerification';New-Item -ItemType Directory -Path $testDir -Force|Out-Null
    $fixtureExporter=Join-Path $testDir 'Export-Sprint48Evidence.ps1';Copy-Item -LiteralPath $ExporterPath -Destination $fixtureExporter
    $fixtureTestScript=Join-Path $testDir 'Test-Export-Sprint48Evidence.ps1';Copy-Item -LiteralPath $PSCommandPath -Destination $fixtureTestScript
    $inventory=Join-Path $testDir 'TEST_INVENTORY.md';$matrix=Join-Path $testDir 'TEST_CREDIBILITY_MATRIX.md'
    $manifest=Join-Path $repo 'SOMWANG_XAU_M15_FUSION_PRO_V5_SPRINT4_3_CONTRACT_TESTS.mq5'
    $ini=Join-Path $testDir 'sprint4_8_b10_full_once.ini';$set=Join-Path $testDir 'sprint4_8_b10_full_once.set'
    Write-Lf (Join-Path $repo '.gitattributes') "* text=auto`n*.md text eol=lf`n*.txt text eol=lf`n*.json text eol=lf`nFusionProV5/Evidence/** text eol=lf"
    Write-Lf $inventory "| Domain | IDs | Total |`n|---|---|---:|`n| Fixture | FX-001 through FX-934 | 934 |`n| **Total** |  | **934** |"
    Write-Lf (Join-Path $testDir 'TEST_ID_INVENTORY.txt') "# fixture canonical IDs`nFX-001..934"
    $exporterIds=@();foreach($n in 1..41){$exporterIds+='EXP48-'+$n.ToString('D2')};foreach($n in 46..64){$exporterIds+='EXP48-'+$n.ToString('D2')};$exporterIds+='EXP48-67';foreach($n in 42..45){$exporterIds+='EXP48-'+$n.ToString('D2')};foreach($n in 65..66){$exporterIds+='EXP48-'+$n.ToString('D2')};foreach($n in 68..73){$exporterIds+='EXP48-'+$n.ToString('D2')}
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
    Write-Lf $matrix $matrixValid;Write-Lf $manifest '// fixture manifest';Write-Lf $ini '[Tester]';Write-Lf $set 'Fixture=true'
    Git @('-C',$repo,'add','.')|Out-Null;Git @('-C',$repo,'-c','user.name=SWV5 Test','-c','user.email=swv5-test@example.invalid','commit','--quiet','-m','fixture source')|Out-Null
    $sourceCommit=Git @('-C',$repo,'rev-parse','HEAD');$sourceTree=Git @('-C',$repo,'rev-parse','HEAD^{tree}')
    $manifestBlob=Git @('-C',$repo,'rev-parse',"${sourceCommit}:SOMWANG_XAU_M15_FUSION_PRO_V5_SPRINT4_3_CONTRACT_TESTS.mq5")
    $iniBlob=Git @('-C',$repo,'rev-parse',"${sourceCommit}:FusionProV5/Tests/ContractVerification/sprint4_8_b10_full_once.ini")
    $setBlob=Git @('-C',$repo,'rev-parse',"${sourceCommit}:FusionProV5/Tests/ContractVerification/sprint4_8_b10_full_once.set")
    $exporterBlob=Git @('-C',$repo,'rev-parse',"${sourceCommit}:FusionProV5/Tests/ContractVerification/Export-Sprint48Evidence.ps1")
    $exporterTestBlob=Git @('-C',$repo,'rev-parse',"${sourceCommit}:FusionProV5/Tests/ContractVerification/Test-Export-Sprint48Evidence.ps1")
    function Get-BlobSha([string]$Blob){$start=[Diagnostics.ProcessStartInfo]::new('git.exe',"-C `"$repo`" cat-file blob $Blob");$start.UseShellExecute=$false;$start.RedirectStandardOutput=$true;$p=[Diagnostics.Process]::new();$p.StartInfo=$start;$p.Start()|Out-Null;$m=[IO.MemoryStream]::new();try{$p.StandardOutput.BaseStream.CopyTo($m);$p.WaitForExit();return Get-ShaBytes $m.ToArray()}finally{$m.Dispose();$p.Dispose()}}

    $fixtureExporterSha=Get-BlobSha $exporterBlob;$fixtureTestScriptSha=Get-BlobSha $exporterTestBlob
    $archLog=Join-Path $tempRoot 'architecture.log';$testLog=Join-Path $tempRoot 'tests.log';$run1Log=Join-Path $tempRoot 'run1.log';$run2Log=Join-Path $tempRoot 'run2.log';$ex5=Join-Path $tempRoot 'tests.ex5';$offlineResult=Join-Path $tempRoot 'exporter_test_results.json'
    $compileOk="Result: 0 errors, 0 warnings, 100 ms elapsed, cpu='X64 Regular'"
    $machine='SWV5_MACHINE_RESULT {"schema":"SWV5-CONTRACT-TEST-RESULT-V5","contract_policy":"SWV5-PRODUCTION-V5","suite":"SPRINT4.8-V5-FULL","total":934,"passed":934,"failed":0,"skipped":0,"signature":"12393352988365616976","deterministic":true}'
    $caseLines=@();for($n=1;$n-le934;$n++){$caseLines += ('SWV5_TEST id=FX-'+$n.ToString('D3')+' domain=FIXTURE outcome=PASS expected=pass actual=pass detail=')};$caseBlock=($caseLines-join"`n")
    $runBase=@"
AB 0 10:00:00.001 authorized (agent build 6090)
AB 0 10:00:00.002 EURUSD,M1 (Exness-MT5Trial6): testing of Fixture.ex5
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
        $value=[ordered]@{schema='SWV5-SPRINT48-EXPORTER-OFFLINE-TEST-V3';exporter_path='FusionProV5/Tests/ContractVerification/Export-Sprint48Evidence.ps1';exporter_sha256=$fixtureExporterSha;test_script_sha256=$fixtureTestScriptSha;generated_from='Test-Export-Sprint48Evidence.ps1 - offline controlled fixture V3';total=$fixtureCases.Count;passed=$fixtureCases.Count;failed=0;skipped=0;signature=$signature;cases=$fixtureCases}
        Write-Lf $offlineResult ($value|ConvertTo-Json -Depth 6)
    }
    function Set-Baseline {Write-Lf $archLog $compileOk;Write-Lf $testLog $compileOk;Write-Lf $run1Log $runBase;Write-Lf $run2Log ($runBase.Replace('10:00:00','10:01:00'));[IO.File]::WriteAllBytes($ex5,[byte[]](1,4,8,16,32,64));Set-OfflineBaseline}
    function Get-Digest([string]$Commit,[string]$Tree){
        $lines=@('format=SWV5-SPRINT48-B10-VERIFICATION-SOURCE-V4',"tested_source_commit=$Commit","source_tree=$Tree","architecture_compile_raw_sha256=$(Get-Sha $archLog)","test_compile_raw_sha256=$(Get-Sha $testLog)","run_1_raw_sha256=$(Get-Sha $run1Log)","run_2_raw_sha256=$(Get-Sha $run2Log)","exporter_test_results_raw_sha256=$(Get-Sha $offlineResult)",'run_1_signature=12393352988365616976','run_2_signature=12393352988365616976','schema=SWV5-CONTRACT-TEST-RESULT-V5','production_policy=SWV5-PRODUCTION-V5','suite=SPRINT4.8-V5-FULL','terminal_build=6090','server=Exness-MT5Trial6','account_mode=HEDGING','ontester=1',"test_manifest_git_blob_sha256=$(Get-BlobSha $manifestBlob)","run_config_ini_sha256=$(Get-BlobSha $iniBlob)","run_config_set_sha256=$(Get-BlobSha $setBlob)","compiled_test_ex5_sha256=$(Get-Sha $ex5)","exporter_git_blob_sha256=$fixtureExporterSha","exporter_test_script_git_blob_sha256=$fixtureTestScriptSha")
        return Get-ShaBytes $Utf8NoBom.GetBytes(($lines-join"`n"))
    }
    function Get-DigestFromInputs([string]$Commit,[string]$Tree,[object]$Inputs){
        $lines=@('format=SWV5-SPRINT48-B10-VERIFICATION-SOURCE-V4',"tested_source_commit=$Commit","source_tree=$Tree","architecture_compile_raw_sha256=$($Inputs.architecture_compile_raw_sha256)","test_compile_raw_sha256=$($Inputs.test_compile_raw_sha256)","run_1_raw_sha256=$($Inputs.run_1_raw_sha256)","run_2_raw_sha256=$($Inputs.run_2_raw_sha256)","exporter_test_results_raw_sha256=$($Inputs.exporter_test_results_raw_sha256)","run_1_signature=$($Inputs.run_1_signature)","run_2_signature=$($Inputs.run_2_signature)","schema=$($Inputs.schema)","production_policy=$($Inputs.production_policy)","suite=$($Inputs.suite)","terminal_build=$($Inputs.terminal_build)","server=$($Inputs.server)","account_mode=$($Inputs.account_mode)","ontester=$($Inputs.ontester)","test_manifest_git_blob_sha256=$($Inputs.test_manifest_git_blob_sha256)","run_config_ini_sha256=$($Inputs.run_config_ini_sha256)","run_config_set_sha256=$($Inputs.run_config_set_sha256)","compiled_test_ex5_sha256=$($Inputs.compiled_test_ex5_sha256)","exporter_git_blob_sha256=$($Inputs.exporter_git_blob_sha256)","exporter_test_script_git_blob_sha256=$($Inputs.exporter_test_script_git_blob_sha256)")
        return Get-ShaBytes $Utf8NoBom.GetBytes(($lines-join"`n"))
    }
    function Get-Args([string]$Commit,[string]$Tree,[string]$Output){return @('-Mode','Generate','-RepositoryRoot',$repo,'-OutputDirectory',$Output,'-ArchitectureCompileLog',$archLog,'-TestCompileLog',$testLog,'-Run1Log',$run1Log,'-Run2Log',$run2Log,'-CompiledTestEx5',$ex5,'-ExporterTestResults',$offlineResult,'-ExpectedTestTotal','934','-ExpectedDeterministicSignature','12393352988365616976','-TestedSourceSha',$Commit,'-ExpectedSourceTreeSha',$Tree,'-ExpectedArchitectureCompileLogSha256',(Get-Sha $archLog),'-ExpectedTestCompileLogSha256',(Get-Sha $testLog),'-ExpectedRun1LogSha256',(Get-Sha $run1Log),'-ExpectedRun2LogSha256',(Get-Sha $run2Log),'-ExpectedCompiledTestEx5Sha256',(Get-Sha $ex5),'-ExpectedExporterTestResultsSha256',(Get-Sha $offlineResult),'-ExpectedVerificationSourceDigest',(Get-Digest $Commit $Tree))}
    function Negative([string]$Id,[string]$Name,[scriptblock]$Arrange,[scriptblock]$Adjust=$null){Git @('-C',$repo,'checkout','--quiet','--force',$sourceCommit)|Out-Null;Set-Baseline;&$Arrange;$a=Get-Args $sourceCommit $sourceTree (Join-Path $tempRoot $Id);if($null-ne$Adjust){$a=&$Adjust $a};$r=Invoke-Exporter $a "$Id.out";Record $Id $Name ($r.ExitCode-ne 0)}

    Set-Baseline;$outA=Join-Path $repo 'OutA';$outB=Join-Path $repo 'OutB';$a=Invoke-Exporter (Get-Args $sourceCommit $sourceTree $outA) 'valid-a.out';Record 'EXP48-01' 'valid explicit generation' ($a.ExitCode-eq 0)
    $b=Invoke-Exporter (Get-Args $sourceCommit $sourceTree $outB) 'valid-b.out';$names=@('COMPILE_REPORT.md','VERIFICATION_REPORT.md','contract_test_results.json','sprint4_8_tester_evidence.txt','exporter_test_results.json');$same=$b.ExitCode-eq 0;foreach($n in $names){$same=$same-and((Get-Sha(Join-Path $outA $n))-eq(Get-Sha(Join-Path $outB $n)))};Record 'EXP48-02' 'repeated generation byte-identical' $same
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

    $final=[pscustomobject][ordered]@{schema='SWV5-SPRINT48-EXPORTER-OFFLINE-TEST-V3';exporter_path='FusionProV5/Tests/ContractVerification/Export-Sprint48Evidence.ps1';exporter_sha256=(Get-Sha $ExporterPath);test_script_sha256=(Get-Sha $PSCommandPath);generated_from='Test-Export-Sprint48Evidence.ps1 - offline controlled fixture V3';total=73;passed=$passed;failed=$failed;skipped=0;signature=(Get-ShaBytes $Utf8NoBom.GetBytes((@($records|ForEach-Object{$_.id+'|'+$_.name+'|'+$_.passed})-join"`n")));cases=$records}
    $finalJson=$final|ConvertTo-Json -Depth 6;if(-not[string]::IsNullOrWhiteSpace($ResultPath)){Write-Lf $ResultPath $finalJson};$finalJson
    if($failed-ne0-or$passed-ne73){exit 1};exit 0
} finally {if(Test-Path -LiteralPath $tempRoot){Remove-Item -LiteralPath $tempRoot -Recurse -Force}}
