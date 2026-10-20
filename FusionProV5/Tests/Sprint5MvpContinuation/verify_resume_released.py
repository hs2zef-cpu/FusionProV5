"""TEST ONLY / NOT FOR PRODUCTION / NO BROKER ACCESS.
Read-only forensic probe and pre-run gate. NEVER launches MT5.
Python/source evidence is explicitly NOT post-fix MQL execution evidence.
"""
from pathlib import Path
from copy import deepcopy
import base64, contextlib, hashlib, io, json, re, sqlite3, subprocess, sys, zlib
from types import SimpleNamespace as NS
import verify_native_copy_prerun as prior
import verify_governance_refresh as gov
import verify_event_freshness_layering as layering
import verify_operator_time_binding as window

ROOT=prior.ROOT; HERE=prior.HERE; COMMON=prior.COMMON; DATA=prior.DATA
CORE=layering.CORE; SUITE=layering.SUITE
OLD_RUN='4de6f69b8813436a8f272d895b8e2cf0'
RUN='d2c6f9539b124ae7bf03a8d4f1806c72'
SEED=COMMON/('TEST_ONLY_MVP_CONTINUATION_'+RUN+'.sqlite')
PRESET=DATA/'MQL5/Presets'/(SEED.name+'.set')
checks=[]

def sha(p): return prior.sha(p)
def check(name,ok,kind='STATIC_NOT_MQL_EXECUTION'):
    checks.append(dict(id=name,passed=bool(ok),evidence_class=kind))
def baseline():
    b=json.loads((HERE/'RESUME_RELEASED_BASELINE.json').read_text())
    return json.loads(zlib.decompress(base64.b64decode(b['data'])))
def read_rows(path):
    # Never connect to the real deployment store, even read-only.
    assert path.name.startswith('TEST_ONLY_MVP_CONTINUATION_')
    wal=Path(str(path)+'-wal')
    assert not wal.exists() or wal.stat().st_size==0, 'Uncheckpointed WAL: refuse immutable read'
    c=sqlite3.connect(path.as_uri()+'?mode=ro&immutable=1',uri=True)
    c.row_factory=sqlite3.Row
    try:
        c.execute('PRAGMA query_only=ON')
        return [dict(r) for r in c.execute('SELECT * FROM swv5_authority_rows ORDER BY domain_key,record_key')]
    finally:c.close()

# Evaluate serialization FIELD ORDER directly extracted from accepted MQL
# canonical serializers. Scalar lexemes come from the real typed bundle;
# this is a Python structural check, NOT native MQL validation.
SERIAL_SOURCE='\n'.join(p.read_text(encoding='utf-8-sig') for p in (ROOT/'FusionProV5/ExecutionLayer/Contracts').glob('*.mqh'))
def canonical(kind,name,obj):
    primitives=dict(String='s',UInt='u',Int='i',Datetime='i',Bool='b',Double='d')
    if kind in primitives:return prior.field(name,primitives[kind],obj)
    body=prior.function(prior.clean(SERIAL_SOURCE),'SWV5S5_Canonical'+kind)
    for macro,child in re.findall(r'#define\s+(\w+)\(n,v\)\s+if\(!SWV5S5_Canonical(\w+)\(n,v,f\)',body):
        body=re.sub(re.escape(macro)+r'\("([^"]+)",\s*(\w+(?:\.\w+)+)\)',
                    lambda m:'SWV5S5_Canonical'+child+'("'+m[1]+'",'+m[2]+',f)',body)
    calls=re.findall(r'SWV5S5_Canonical(\w+)\("([^"]+)",\s*(\w+(?:\.\w+)+),\s*\w+\)',body)
    assert calls, kind
    result=''
    for child,key,access in calls:
        value=obj
        for part in access.split('.')[1:]: value=value[part]
        result+=canonical(child,key,value)
    return prior.field(name,'x',result)
def typed_lexemes(payload):
    return {n:typed_lexemes(v) if t=='x' else v for n,t,v in gov.raw_fields(payload)}

def probe():
    path=COMMON/('TEST_ONLY_MVP_CONTINUATION_'+OLD_RUN+'.sqlite.RETEST.RESUME_RELEASED.sqlite')
    rows=read_rows(path)
    current=next(r for r in rows if r['domain_key']=='MVP_HARD_KILL_STATE' and r['record_key']=='CURRENT')
    hk=prior.decode(current['payload'])['hard_kill'];ref=hk['release_authority_reference']
    complete=next(r for r in rows if r['domain_key']=='MVP_HARD_KILL_COMPLETE_RELEASE' and r['record_key']==ref['authority_record_id'])
    typed=typed_lexemes(gov.nested(complete['payload'],'released'))
    projection=canonical('HardKillState','hard_kill',typed)
    decoded=prior.decode(complete['payload']); released=decoded['released']; record=decoded['authority']
    check('FORENSIC/current-payload-digest',prior.digest(current['domain_key'],current['payload'])==current['payload_digest'],'IMMUTABLE_RO_PHYSICAL')
    check('FORENSIC/current-CAS-revision',gov.token(current)==current['store_revision'],'IMMUTABLE_RO_PHYSICAL')
    check('FORENSIC/complete-payload-digest',prior.digest(complete['domain_key'],complete['payload'])==complete['payload_digest'],'IMMUTABLE_RO_PHYSICAL')
    check('FORENSIC/complete-CAS-revision',gov.token(complete)==complete['store_revision'],'IMMUTABLE_RO_PHYSICAL')
    check('FORENSIC/typed-bundle-projects-byte-exact-CURRENT',projection==current['payload'],'SOURCE_SERIALIZER_PYTHON_REAL_ROW')
    first=gov.raw_fields(current['payload'])[0]
    check('FORENSIC/first-reader-prefix-mismatch',first[:2]==('hard_kill','x') and not current['payload'].startswith('contract_version:x:'),'SOURCE_READER_PYTHON_REAL_ROW')
    rawpath=DATA/'MQL5/Logs/20261014.log';raw=rawpath.read_text(encoding='utf-16')
    start=raw.rfind('CONTINUATION_NATIVE_COPY|START|');end=raw.index('CONTINUATION_NATIVE_COPY|COMPLETE|',start)
    end=raw.find('\n',end);native=raw[start:end]
    check('FORENSIC/actual-latest-native-baseline','passed=213|failed=1|skipped=0|total=214' in native and
          re.findall(r'CONTINUATION_ASSERT\|([^\r\n|]+)\|FAIL',native)==['RESUME_RELEASED'] and
          'original_unchanged=true' in native and 'forbidden_transport_calls=0' in native,'PRE_FIX_NATIVE_JOURNAL')
    # First equality was never reached: the raw codec fails on its first read.
    return dict(copy=prior.artifact(path),current={k:v for k,v in current.items() if k not in ('payload','namespace_digest')},
        complete={k:v for k,v in complete.items() if k not in ('payload','namespace_digest')},
        first_failing_predicate='reader.ReadNested("contract_version",nested)',expected_prefix='contract_version:x:',actual_prefix=current['payload'][:35],
        source_decoder='SW_V5_S5_MvpAuthorityRecordCodec.mqh:1254',category='payload codec/envelope mismatch, NOT corruption or A1/A2 binding',
        A1=record['operator_identity'],approved_at=record['approved_at'],released_at=record['released_at'],
        raw_journal=prior.artifact(rawpath),historical_counts=dict(passed=213,failed=1,skipped=0,total=214),
        beforeimage_limit='Old native run did not export an INTERRUPT_AFTER_RELEASED physical beforeimage. Current row/complete bundle are internally byte-exact, digest/CAS-valid; timestamp/revision match the original release. No retrospective two-snapshot claim. New native regression captures the exact beforeimage and activation proof.',
        release_timestamps=dict(current=current['updated_at'],complete=complete['updated_at'],original_release=record['released_at']))

def released_guard_tests():
    body=prior.function(prior.clean(CORE.read_text(encoding='utf-8-sig')),'CompleteRelease')
    start=body.index('if(!SWV5S5_MvpIssueContinuationRelease')
    condition=prior.delimited(body,body.index('(',start))[0].replace('(int)','')
    code=window.expression(condition)
    def rejected(expr=code,**fault):
        return window.ev(expr,dict(flat=None,evidence=None,expected=NS(authority_record_id='A1'),
            store=NS(ReadRow=lambda *a:fault.get('read',True)),SWV5S5_MvpIssueContinuationRelease=lambda *a:fault.get('issue',True),
            SWV5S5_MVP_DOMAIN_RELEASE_COMPLETE='COMPLETE',complete=NS(logical_revision=fault.get('revision',1),
            state=fault.get('state',3),payload='BUNDLE'),found=fault.get('found',True),SWV5_HARD_KILL_RELEASED=3,
            current=NS(payload=fault.get('current_payload','CANONICAL')),
            SWV5S5_MvpContinuationRowValid=lambda s,r:fault.get('complete_integrity' if r.payload=='BUNDLE' else 'current_integrity',True),
            SWV5S5_MvpDecodeReleaseBundle=lambda *a:fault.get('decode',True),released=None,
            record=NS(authority_record_id=fault.get('record_id','A1')),
            SWV5S5_CanonicalHardKillState=lambda *a:fault.get('canonical',True),payload='CANONICAL',
            SWV5S5_MvpCompleteReleaseValid=lambda *a:fault.get('history',True),context=None))
    check('BUNDLE_GUARD/positive',not rejected(),'SOURCE_EXTRACTED_GUARD_STUBBED_IO_AND_VALIDATORS')
    cases=[('issue',False),('read',False),('revision',2),('state',2),('complete_integrity',False),('current_integrity',False),
           ('decode',False),('found',False),('record_id','OTHER'),('canonical',False),('current_payload','OTHER'),('history',False)]
    for key,value in cases:check('BUNDLE_GUARD/'+key,rejected(**{key:value}),'SOURCE_EXTRACTED_GUARD_STUBBED_IO_AND_VALIDATORS')
    removals=[('missing-row','!found','found',False),('revision','complete.logical_revision!=1','revision',2),
        ('state','complete.state!=SWV5_HARD_KILL_RELEASED','state',2),
        ('complete-integrity','!SWV5S5_MvpContinuationRowValid(store,complete)','complete_integrity',False),
        ('current-integrity','!SWV5S5_MvpContinuationRowValid(store,current)','current_integrity',False),
        ('decode','!SWV5S5_MvpDecodeReleaseBundle(complete.payload,released,record)','decode',False),
        ('record-id','record.authority_record_id!=expected.authority_record_id','record_id','OTHER'),
        ('canonical-equality','payload!=current.payload','current_payload','OTHER'),
        ('historical-validity','!SWV5S5_MvpCompleteReleaseValid(context,released,record)','history',False)]
    for name,term,key,value in removals:
        assert term in condition
        mutant=window.expression(condition.replace(term,'false',1).replace('false','False'))
        check('MC_RELEASED/'+name,rejected(**{key:value}) and not rejected(expr=mutant,**{key:value}),
              'PYTHON_SOURCE_GUARD_MUTATION_NOT_MQL_MUTANT')
    check('RELEASED/no-current-codec-or-A2-rebind',
        'MvpCodecDecode_SWV5_HardKillState(current.payload' not in body and
        'SWV5S5_MvpDecodeReleaseBundle(complete.payload,released,record)' in body and
        not re.search(r'released\.[\w.]+\s*=(?!=)',body))
    branch=body[body.index('if(current.state=='):body.index('SWV5S5_MvpAuthorityRow physical')]
    check('RELEASED/read-only-load-no-historical-write',not re.search(r'CompareAndSet|PrepareMutation|InsertRow|\.op\s*=|operator_identity\s*=',branch) and 'op,' not in branch)
    check('RELEASED/activation-continues-through-existing-guards',
          'TryActivateInactiveAfterValidatedRelease(store,context,op,true,released,lease,current' in body and
          'SWV5S5_MvpContinuationBoundRowsCurrent' in body)
    return dict(rejection_condition=condition,mutation_controls=len(removals),
                limitations='I/O and historical validation calls are stubbed for predicate isolation, not claimed as executed MQL.')

def audit():
    before={str(p):prior.db_artifact(p) for p in (prior.ORIGINAL,prior.COPY,SEED)}
    records=baseline();changed=[r['path'] for r in records if sha(Path(r['path']))!=r['sha256']]
    check('SCOPE/exactly-two-preexisting-files-changed',set(changed)=={str(CORE),str(SUITE)},'PRE_PATCH_HASH_BASELINE_737_FILES')
    check('DB/real-donor-seed-exact',all(sha(p)==prior.EXPECTED for p in (prior.ORIGINAL,prior.COPY,SEED)),'FILE_HASH_ONLY_REAL_DB')
    check('DB/real-and-seed-no-sidecars',all(not Path(str(p)+s).exists() for p in (prior.ORIGINAL,SEED) for s in ('-wal','-shm')))
    check('TARGET/fresh-mutable-family-absent',not list(COMMON.glob(SEED.name+'.RETEST*')))
    values=dict(l.split('=',1) for l in PRESET.read_text(encoding='utf-8-sig').splitlines() if '=' in l)
    check('PRESET/exact-new-run',values==dict(explicit_test_only_marker='TEST_ONLY_AUTHORIZED_UNCOMMITTED_DRAFT',
        initial_copy_relative_path=SEED.name,expected_initial_copy_sha256=prior.EXPECTED.lower(),execute_test_copy_once='true',operator_confirmed_test_copy='true'))
    check('PRESET/installed-identical',sha(PRESET)==sha(HERE/PRESET.name))
    harness=HERE/(prior.EA+'.mq5');installed=DATA/'MQL5/Experts/FusionProV5Tests'/(prior.EA+'.ex5')
    prior.checks.clear();refusals=prior.isolated_guard_tests(prior.clean(harness.read_text(encoding='utf-8-sig')))
    isolation=prior.source_safety(prior.clean(harness.read_text(encoding='utf-8-sig')),installed)
    for c in prior.checks:check(c['id'],c['passed'],'ISOLATED_REFUSAL_STATIC_NOT_NATIVE')
    prior.checks.clear();copy=prior.COPY
    try:prior.COPY=SEED;prestate=prior.physical_prestate()
    finally:prior.COPY=copy
    for c in prior.checks:check(c['id'],c['passed'],'IMMUTABLE_RO_TEST_SEED')
    forensic=probe();guards=released_guard_tests()
    window.checks.clear();operator_guards=window.guard_tests()
    for c in window.checks:check('REGRESSION/'+c['id'],c['passed'],c['evidence_class'])
    layering.checks.clear();buf=io.StringIO()
    with contextlib.redirect_stdout(buf):layering.main()
    layer=json.loads(buf.getvalue())
    for c in layer['checks']:check('LAYER/'+c['id'],c['passed'],c['evidence_class'])
    check('BUILD/include-and-installed-current',all(c['passed'] for c in layer['held_full_native_build_gates']))
    suite=prior.clean(SUITE.read_text(encoding='utf-8-sig'))
    for label in ('RELEASED_RESTART_A1_NOT_RECONSTRUCTED_ZERO_MUTATION','RELEASED_A1_HISTORICAL_BUNDLE_PHYSICALLY_VALID','RELEASED_CANONICAL_ENVELOPE_IS_NOT_TYPED_CODEC',
        'RELEASED_RESTART_RECONSTRUCTS_NEITHER_A1_NOR_A2_ZERO_MUTATION','RELEASED_AFTER_A2_AND_T2_BYTES_DIGEST_REVISION_EXACT',
        'RELEASED_A2_DISTINCT_FRESH_INVOCATION_AFTER_A1_RELEASE','RELEASED_A1_COMPLETE_BUNDLE_UNREWRITTEN_AFTER_INACTIVE',
        'RELEASED_A1_HISTORY_A2_ACTIVATION_ONLY_REAL_LATER_T2_INACTIVE','RELEASED_A1_A2_ZERO_SUBMISSION_AND_TRANSPORT'):
        check('NATIVE_TEST_PRESENT/'+label,label in suite)
    jobs=prior.function(suite,'FinishJobs');resume=prior.function(suite,'Resume')
    check('NATIVE/regression-wired-after-interrupt-and-before-A2','CaptureReleasedBeforeRestart(i)' in resume and
        resume.index('CaptureReleasedBeforeRestart(i)')<resume.index('Execute(i,broker,result)',resume.index('if(stage!="INACTIVE")')))
    check('NATIVE/beforeimage-checked-before-finalization',jobs.index('ReleasedBeforeFinalization(j)')<jobs.index('else if(published || no_publication)ok='))
    check('NATIVE/actual-completion-proof-checked','ReleasedAfterFinalization(j,ok,result,accepted)' in jobs)
    cold=prior.function(suite,'ReleasedBeforeFinalization')
    check('NATIVE/cold-restart-uses-real-A2-not-synthetic',
        'attempt=m_job_op[job]' in cold and '!cold.Run(m_job_input[job],attempt,cold_clock,platform,broker,denied)' in cold and
        'cold_clock.CurrentFreshObservation(fresh)' in cold and 'SameRows(before,after)' in cold)
    for name in ('RESUME_FIRST','RESUME_COMPLETE','CLOCK_COMPLETE','BOUND_','NEG_COLD_RESTART'):
        check('NATIVE/existing-job-family-preserved/'+name,name in jobs)
    for name in ('CLOCK','HEARTBEAT','TRUST','GOVERNANCE','ACTIVE','FLAT','PENDING','RELEASED','INACTIVE'):
        check('NATIVE/existing-resume-scheduled/'+name,'"'+name+'"' in prior.function(suite,'Start'))
    runtime=HERE.parent/'Sprint5MvpRuntime';runs={}
    for name in ('verify_mvp_runtime.py','verify_mvp_mutation_controls.py'):
        r=subprocess.run([sys.executable,str(runtime/name)],cwd=ROOT,text=True,capture_output=True)
        runs[name]=dict(exit_code=r.returncode,stdout=r.stdout,stderr=r.stderr)
        check('RUNTIME/'+name,r.returncode==0 and '|FAIL' not in r.stdout and '|SURVIVED' not in r.stdout,'PYTHON_NOT_MQL')
    compiles={}
    paths=[HERE/(n+'.mq5') for n in ('SW_V5_S5_MVP_ATTENDED_AUTHORITY_CONTINUATION','SW_V5_S5_MVP_CONTINUATION_ASSERTIONS',prior.EA)]
    paths.append(runtime/'SOMWANG_XAU_M15_FUSION_PRO_V5_MVP_RUNTIME_TESTS.mq5')
    for p in paths:
        line=re.findall(r'^Result:.*',p.with_suffix('.log').read_text(encoding='utf-16'),re.M)[-1]
        check('COMPILE/'+p.stem,bool(re.fullmatch(r"Result: 0 errors, 0 warnings, .*cpu='X64 Regular'",line)) and
              p.with_suffix('.log').stat().st_mtime>=max(CORE.stat().st_mtime,SUITE.stat().st_mtime),'METAEDITOR_COMPILE_NOT_EXECUTION')
        compiles[p.stem]=dict(result=line,artifact=prior.artifact(p.with_suffix('.ex5')))
    check('EX5/new-and-installed',sha(installed)==sha(harness.with_suffix('.ex5')) and
        sha(installed)!='BFA0D7EC4F86C9C853853E38DE2EB24639DB906F1E04BA2222ED63D637C4D023')
    check('GIT/diff-check',subprocess.run(['git','diff','--check'],cwd=ROOT,capture_output=True).returncode==0,'GIT')
    git={k:subprocess.check_output(['git',*args],cwd=ROOT,text=True).strip() for k,args in
         [('branch',['branch','--show-current']),('HEAD',['rev-parse','HEAD']),('tree',['rev-parse','HEAD^{tree}']),('main',['rev-parse','main']),('status',['status','--short'])]}
    check('GIT/unchanged-base-main',git['branch']=='sprint5-phase-f-entry-contract' and git['HEAD']=='d926f2e6b1aa4ea7b4b0936293d2fa47a2ce7ba8' and
        git['tree']=='46c09cfbed423df9c93b7f63aaf4b901af5b83fd' and git['main']=='32b79ca71ffc331e15e48a57c52be1352e3dbe7e','GIT')
    check('DB/before-after-identical',before=={str(p):prior.db_artifact(p) for p in (prior.ORIGINAL,prior.COPY,SEED)},'FILE_HASH_METADATA')
    check('DB/all-old-copies-and-donor-preserved',all(sha(Path(r['path']))==r['sha256'] for r in records if str(COMMON) in r['path']),'PRE_PATCH_OLD_COPY_HASHES')
    return dict(classification='RESUME_RELEASED_PRE_RUN_ONLY_POST_FIX_NATIVE_EXECUTION_PENDING',
        summary=dict(total=len(checks),passed=sum(c['passed'] for c in checks),failed=sum(not c['passed'] for c in checks),post_fix_MQL_executions=0),
        checks=checks,forensic=forensic,released_guards=guards,operator_guards=operator_guards,runtime=runs,
        layering=layer['summary'],governance=layer['full_governance_regression_summary'],
        governance_metadata_note='unresolved_prior_failures in the imported legacy summary describes its archived 60/19 native baseline only; the latest actual baseline is 213/1 with RESUME_RELEASED alone. It is not a new post-fix execution result.',compile=compiles,
        refusal=refusals,isolation=isolation,prestate=prestate,files_changed_this_patch=changed,
        original_donor_seed=before,preset=prior.artifact(PRESET),inputs=values,installed=prior.artifact(installed),
        run_target=str(COMMON/(SEED.name+'.RETEST.MAIN.sqlite')),git=git,verifier_sha256=sha(Path(__file__)))

if __name__=='__main__':
    # TEST ONLY: a repeated pre-run can select a genuinely unused artifact
    # family without rewriting source fixtures or reusing executed clones.
    if '--run-id' in sys.argv:
        RUN=sys.argv[sys.argv.index('--run-id')+1]
        if not re.fullmatch(r'[0-9a-f]{32}',RUN):raise SystemExit('Invalid TEST_ONLY run ID')
        SEED=COMMON/('TEST_ONLY_MVP_CONTINUATION_'+RUN+'.sqlite')
        PRESET=DATA/'MQL5/Presets'/(SEED.name+'.set')
    if '--audit' in sys.argv: result=audit()
    else:
        result=dict(probe=probe(),summary=dict(total=len(checks),passed=sum(c['passed'] for c in checks),failed=sum(not c['passed'] for c in checks)),checks=checks)
    print(json.dumps(result,indent=2))
    raise SystemExit(int(any(not c['passed'] for c in checks)))
