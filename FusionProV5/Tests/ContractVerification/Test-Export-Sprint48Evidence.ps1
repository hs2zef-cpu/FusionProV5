# TEST ONLY
# NOT FOR PRODUCTION
# NO BROKER ACCESS
# Offline controlled-fixture regression tests for Export-Sprint48Evidence.ps1.

[CmdletBinding()]
param([string]$ExporterPath)

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
    $inventory=Join-Path $testDir 'TEST_INVENTORY.md';$matrix=Join-Path $testDir 'TEST_CREDIBILITY_MATRIX.md'
    $manifest=Join-Path $repo 'SOMWANG_XAU_M15_FUSION_PRO_V5_SPRINT4_3_CONTRACT_TESTS.mq5'
    $ini=Join-Path $testDir 'sprint4_8_b6_full_once.ini';$set=Join-Path $testDir 'sprint4_8_b6_full_once.set'
    Write-Lf (Join-Path $repo '.gitattributes') "* text=auto`n*.md text eol=lf`n*.txt text eol=lf`n*.json text eol=lf`nFusionProV5/Evidence/** text eol=lf"
    Write-Lf $inventory "| Domain | IDs | Total |`n|---|---|---:|`n| Fixture | FX-001 through FX-846 | 846 |`n| **Total** |  | **846** |"
    $matrixValid=@'
| Category | Count | Merge-gating evidence |
|---|---:|---|
| `MERGE_GATING_BEHAVIOR` | 69 | YES |
| `STATE_TRANSITION` | 107 | YES |
| `NEGATIVE_FAIL_CLOSED` | 543 | YES |
| `ROUND_TRIP` | 7 | YES |
| `INVARIANT_BEHAVIOR` | 47 | YES |
| `SUPPORTING_PURE_FUNCTION` | 59 | NO |
| `CONFORMANCE_ONLY` | 14 | NO |
| `WEAK_FALSE_POSITIVE` | 0 | NO |
'@
    Write-Lf $matrix $matrixValid;Write-Lf $manifest '// fixture manifest';Write-Lf $ini '[Tester]';Write-Lf $set 'Fixture=true'
    Git @('-C',$repo,'add','.')|Out-Null;Git @('-C',$repo,'-c','user.name=SWV5 Test','-c','user.email=swv5-test@example.invalid','commit','--quiet','-m','fixture source')|Out-Null
    $sourceCommit=Git @('-C',$repo,'rev-parse','HEAD');$sourceTree=Git @('-C',$repo,'rev-parse','HEAD^{tree}')
    $manifestBlob=Git @('-C',$repo,'rev-parse',"${sourceCommit}:SOMWANG_XAU_M15_FUSION_PRO_V5_SPRINT4_3_CONTRACT_TESTS.mq5")
    $iniBlob=Git @('-C',$repo,'rev-parse',"${sourceCommit}:FusionProV5/Tests/ContractVerification/sprint4_8_b6_full_once.ini")
    $setBlob=Git @('-C',$repo,'rev-parse',"${sourceCommit}:FusionProV5/Tests/ContractVerification/sprint4_8_b6_full_once.set")
    function Get-BlobSha([string]$Blob){$start=[Diagnostics.ProcessStartInfo]::new('git.exe',"-C `"$repo`" cat-file blob $Blob");$start.UseShellExecute=$false;$start.RedirectStandardOutput=$true;$p=[Diagnostics.Process]::new();$p.StartInfo=$start;$p.Start()|Out-Null;$m=[IO.MemoryStream]::new();try{$p.StandardOutput.BaseStream.CopyTo($m);$p.WaitForExit();return Get-ShaBytes $m.ToArray()}finally{$m.Dispose();$p.Dispose()}}

    $archLog=Join-Path $tempRoot 'architecture.log';$testLog=Join-Path $tempRoot 'tests.log';$run1Log=Join-Path $tempRoot 'run1.log';$run2Log=Join-Path $tempRoot 'run2.log';$ex5=Join-Path $tempRoot 'tests.ex5'
    $compileOk="Result: 0 errors, 0 warnings, 100 ms elapsed, cpu='X64 Regular'"
    $machine='SWV5_MACHINE_RESULT {"schema":"SWV5-CONTRACT-TEST-RESULT-V5","contract_policy":"SWV5-PRODUCTION-V5","suite":"SPRINT4.8-V5-FULL","total":846,"passed":846,"failed":0,"skipped":0,"signature":"12393352988365616976","deterministic":true}'
    $runBase=@"
AB 0 10:00:00.001 authorized (agent build 6090)
AB 0 10:00:00.002 EURUSD,M1 (Exness-MT5Trial6): testing of Fixture.ex5
SWV5_RUN_METADATA suite=SPRINT4.8-V5-FULL fixture_account_mode=HEDGING fixture_broker=TEST-BROKER fixture_server=TEST-SERVER broker_access=false
$machine
SWV5_ONTESTER_SUCCESS result=1
AB 0 10:00:00.003 OnTester result 1
"@
    function Set-Baseline {Write-Lf $archLog $compileOk;Write-Lf $testLog $compileOk;Write-Lf $run1Log $runBase;Write-Lf $run2Log ($runBase.Replace('10:00:00','10:01:00'));[IO.File]::WriteAllBytes($ex5,[byte[]](1,4,8,16,32,64))}
    function Get-Digest([string]$Commit,[string]$Tree){
        $lines=@('format=SWV5-SPRINT48-PHASE-D-VERIFICATION-SOURCE-V1',"tested_source_commit=$Commit","source_tree=$Tree","architecture_compile_raw_sha256=$(Get-Sha $archLog)","test_compile_raw_sha256=$(Get-Sha $testLog)","run_1_raw_sha256=$(Get-Sha $run1Log)","run_2_raw_sha256=$(Get-Sha $run2Log)",'run_1_signature=12393352988365616976','run_2_signature=12393352988365616976','schema=SWV5-CONTRACT-TEST-RESULT-V5','production_policy=SWV5-PRODUCTION-V5','suite=SPRINT4.8-V5-FULL','terminal_build=6090','server=Exness-MT5Trial6','account_mode=HEDGING','ontester=1',"test_manifest_git_blob_sha256=$(Get-BlobSha $manifestBlob)","run_config_ini_sha256=$(Get-BlobSha $iniBlob)","run_config_set_sha256=$(Get-BlobSha $setBlob)","compiled_test_ex5_sha256=$(Get-Sha $ex5)")
        return Get-ShaBytes $Utf8NoBom.GetBytes(($lines-join"`n"))
    }
    function Get-Args([string]$Commit,[string]$Tree,[string]$Output){return @('-Mode','Generate','-RepositoryRoot',$repo,'-OutputDirectory',$Output,'-ArchitectureCompileLog',$archLog,'-TestCompileLog',$testLog,'-Run1Log',$run1Log,'-Run2Log',$run2Log,'-CompiledTestEx5',$ex5,'-TestedSourceSha',$Commit,'-ExpectedSourceTreeSha',$Tree,'-ExpectedArchitectureCompileLogSha256',(Get-Sha $archLog),'-ExpectedTestCompileLogSha256',(Get-Sha $testLog),'-ExpectedRun1LogSha256',(Get-Sha $run1Log),'-ExpectedRun2LogSha256',(Get-Sha $run2Log),'-ExpectedCompiledTestEx5Sha256',(Get-Sha $ex5),'-ExpectedVerificationSourceDigest',(Get-Digest $Commit $Tree))}
    function Negative([string]$Id,[string]$Name,[scriptblock]$Arrange,[scriptblock]$Adjust=$null){Git @('-C',$repo,'checkout','--quiet','--force',$sourceCommit)|Out-Null;Set-Baseline;&$Arrange;$a=Get-Args $sourceCommit $sourceTree (Join-Path $tempRoot $Id);if($null-ne$Adjust){$a=&$Adjust $a};$r=Invoke-Exporter $a "$Id.out";Record $Id $Name ($r.ExitCode-ne 0)}

    Set-Baseline;$outA=Join-Path $repo 'OutA';$outB=Join-Path $repo 'OutB';$a=Invoke-Exporter (Get-Args $sourceCommit $sourceTree $outA) 'valid-a.out';Record 'EXP48-01' 'valid explicit generation' ($a.ExitCode-eq 0)
    $b=Invoke-Exporter (Get-Args $sourceCommit $sourceTree $outB) 'valid-b.out';$names=@('COMPILE_REPORT.md','VERIFICATION_REPORT.md','contract_test_results.json','sprint4_8_tester_evidence.txt');$same=$b.ExitCode-eq 0;foreach($n in $names){$same=$same-and((Get-Sha(Join-Path $outA $n))-eq(Get-Sha(Join-Path $outB $n)))};Record 'EXP48-02' 'repeated generation byte-identical' $same
    $bom=$false;$lf=$true;$final=$true;foreach($n in $names){$bytes=[IO.File]::ReadAllBytes((Join-Path $outA $n));$bom=$bom-or($bytes.Length-ge3-and$bytes[0]-eq239-and$bytes[1]-eq187-and$bytes[2]-eq191);$lf=$lf-and-not($bytes-contains13);$final=$final-and$bytes.Length-ge2-and$bytes[-1]-eq10-and$bytes[-2]-ne10};Record 'EXP48-03' 'UTF-8 has no BOM' (-not$bom);Record 'EXP48-04' 'LF-only output' $lf;Record 'EXP48-05' 'exactly one final LF' $final
    $report=Get-Content -LiteralPath (Join-Path $outA 'VERIFICATION_REPORT.md') -Raw;Record 'EXP48-06' 'source fields expand to values' ($report.Contains($sourceCommit)-and-not$report.Contains('$source'))
    $json=Get-Content -LiteralPath (Join-Path $outA 'contract_test_results.json') -Raw|ConvertFrom-Json;Record 'EXP48-07' 'machine result preserves source identity' ($json.tested_source_commit-eq$sourceCommit-and$json.source_tree-eq$sourceTree)

    $evidence=Join-Path $repo 'FusionProV5\Evidence\Sprint4_8';Set-Baseline;$g=Invoke-Exporter (Get-Args $sourceCommit $sourceTree $evidence) 'evidence.out';Git @('-C',$repo,'add','FusionProV5/Evidence/Sprint4_8/COMPILE_REPORT.md','FusionProV5/Evidence/Sprint4_8/VERIFICATION_REPORT.md','FusionProV5/Evidence/Sprint4_8/contract_test_results.json','FusionProV5/Evidence/Sprint4_8/sprint4_8_tester_evidence.txt')|Out-Null
    $blobManifest=Join-Path $evidence 'evidence_blob_manifest.json';$im=Invoke-Exporter @('-Mode','IndexManifest','-RepositoryRoot',$repo,'-OutputDirectory',$evidence,'-TestedSourceSha',$sourceCommit,'-ExpectedSourceTreeSha',$sourceTree) 'index-manifest.out';Git @('-C',$repo,'add','FusionProV5/Evidence/Sprint4_8/evidence_blob_manifest.json')|Out-Null;$iv=Invoke-Exporter @('-Mode','VerifyIndex','-RepositoryRoot',$repo,'-EvidenceManifestPath',$blobManifest,'-TestedSourceSha',$sourceCommit,'-ExpectedSourceTreeSha',$sourceTree) 'index-verify.out';Record 'EXP48-08' 'index manifest verifies staged blobs' ($g.ExitCode-eq0-and$im.ExitCode-eq0-and$iv.ExitCode-eq0)
    $mo=Get-Content -LiteralPath $blobManifest -Raw|ConvertFrom-Json;Record 'EXP48-09' 'manifest excludes itself' (-not(@($mo.evidence_files.path)-match'evidence_blob_manifest'));Record 'EXP48-10' 'manifest has exact semantic set' (@($mo.evidence_files).Count-eq4)
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
    Negative 'EXP48-23' 'skipped count rejected' {Write-Lf $run1Log ($runBase.Replace('"passed":846,"failed":0,"skipped":0','"passed":845,"failed":0,"skipped":1'))}
    Negative 'EXP48-24' 'failed count rejected' {Write-Lf $run1Log ($runBase.Replace('"passed":846,"failed":0','"passed":845,"failed":1'))}
    Negative 'EXP48-25' 'total mismatch rejected' {Write-Lf $run1Log ($runBase.Replace('"total":846,"passed":846','"total":845,"passed":845'))}
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

    Git @('-C',$repo,'checkout','--quiet','--force',$sourceCommit)|Out-Null;Write-Lf $matrix ($matrixValid.Replace('| `WEAK_FALSE_POSITIVE` | 0 | NO |','| `WEAK_FALSE_POSITIVE` | 1 | NO |'));Git @('-C',$repo,'add','FusionProV5/Tests/ContractVerification/TEST_CREDIBILITY_MATRIX.md')|Out-Null;Git @('-C',$repo,'-c','user.name=SWV5 Test','-c','user.email=swv5-test@example.invalid','commit','--quiet','-m','weak')|Out-Null;$weak=Git @('-C',$repo,'rev-parse','HEAD');$weakTree=Git @('-C',$repo,'rev-parse','HEAD^{tree}');Set-Baseline;$wr=Invoke-Exporter (Get-Args $weak $weakTree (Join-Path $tempRoot 'weak')) 'weak.out';Record 'EXP48-42' 'weak credibility count rejected' ($wr.ExitCode-ne0)
    Git @('-C',$repo,'checkout','--quiet','--force',$sourceCommit)|Out-Null;Write-Lf $inventory ($((Get-Content -LiteralPath $inventory -Raw).Replace('**846**','**845**')));Git @('-C',$repo,'add','FusionProV5/Tests/ContractVerification/TEST_INVENTORY.md')|Out-Null;Git @('-C',$repo,'-c','user.name=SWV5 Test','-c','user.email=swv5-test@example.invalid','commit','--quiet','-m','inventory mismatch')|Out-Null;$bad=Git @('-C',$repo,'rev-parse','HEAD');$badTree=Git @('-C',$repo,'rev-parse','HEAD^{tree}');Set-Baseline;$br=Invoke-Exporter (Get-Args $bad $badTree (Join-Path $tempRoot 'bad-inventory')) 'inventory.out';Record 'EXP48-43' 'inventory mismatch rejected' ($br.ExitCode-ne0)

    Git @('-C',$repo,'checkout','--quiet','--force',$evidenceCommit)|Out-Null;Git @('-C',$repo,'rm','--cached','--quiet','FusionProV5/Evidence/Sprint4_8/COMPILE_REPORT.md')|Out-Null;$missing=Invoke-Exporter @('-Mode','VerifyIndex','-RepositoryRoot',$repo,'-EvidenceManifestPath',$blobManifest,'-TestedSourceSha',$sourceCommit,'-ExpectedSourceTreeSha',$sourceTree) 'missing-evidence.out';Record 'EXP48-44' 'missing staged evidence file rejected' ($missing.ExitCode-ne0)
    Git @('-C',$repo,'restore','--source',$evidenceCommit,'--staged','--worktree','.')|Out-Null;Write-Lf (Join-Path $evidence 'unexpected.txt') 'unexpected evidence artifact';Git @('-C',$repo,'add','FusionProV5/Evidence/Sprint4_8/unexpected.txt')|Out-Null;$unexpected=Invoke-Exporter @('-Mode','VerifyIndex','-RepositoryRoot',$repo,'-EvidenceManifestPath',$blobManifest,'-TestedSourceSha',$sourceCommit,'-ExpectedSourceTreeSha',$sourceTree) 'unexpected-evidence.out';Record 'EXP48-45' 'unexpected evidence file rejected' ($unexpected.ExitCode-ne0)

    [pscustomobject][ordered]@{schema='SWV5-SPRINT48-EXPORTER-OFFLINE-TEST-V1';total=45;passed=$passed;failed=$failed;skipped=0;cases=$records}|ConvertTo-Json -Depth 6
    if($failed-ne0-or$passed-ne45){exit 1};exit 0
} finally {if(Test-Path -LiteralPath $tempRoot){Remove-Item -LiteralPath $tempRoot -Recurse -Force}}
