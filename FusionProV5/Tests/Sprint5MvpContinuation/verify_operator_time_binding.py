"""TEST ONLY / NO MT5 LAUNCH. Source-extracted Python guards + pre-run audit.
NOT execution evidence for the new MQL binary. Deployment DB is file-hashed
only; immutable seed/donor are queried read-only. No writable SQLite here.
"""
from pathlib import Path
from types import SimpleNamespace as NS
from copy import deepcopy
import ast, contextlib, hashlib, io, json, math, re, subprocess
from datetime import datetime, timezone
import verify_native_copy_prerun as prior
import verify_event_freshness_layering as layering
import verify_governance_refresh as gov

ROOT=prior.ROOT;HERE=prior.HERE;COMMON=prior.COMMON;DATA=prior.DATA
RUN='4de6f69b8813436a8f272d895b8e2cf0'
SEED=COMMON/('TEST_ONLY_MVP_CONTINUATION_'+RUN+'.sqlite')
PRESET=DATA/'MQL5/Presets'/(SEED.name+'.set')
PROFILE=layering.CORE.with_name('SW_V5_S5_MvpDeploymentProfile.mqh')
FLAT=PROFILE.with_name('SW_V5_S5_MvpContinuationFlatAuthority.mqh')
CORE=layering.CORE;SUITE=layering.SUITE;WRAPPER=layering.WRAPPER
checks=[]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest().upper()
def check(name,ok,kind='STATIC_SOURCE_NOT_MQL_EXECUTION'):checks.append(dict(id=name,passed=bool(ok),evidence_class=kind))
def bare(p):return prior.clean(p.read_text(encoding='utf-8-sig'))
def compact(s):return re.sub(r'\s+','',s)
def expression(s):
    s=s.replace('(datetime)','').replace('&&',' and ').replace('||',' or ')
    s=re.sub(r'!(?!=)',' not ',s).strip()
    tree=ast.parse('('+s+')',mode='eval')
    allowed=(ast.Expression,ast.BoolOp,ast.Or,ast.And,ast.UnaryOp,ast.Not,ast.Compare,ast.Eq,ast.NotEq,ast.Lt,ast.LtE,ast.Gt,ast.GtE,
             ast.Call,ast.Name,ast.Load,ast.Constant,ast.BinOp,ast.Sub,ast.Add,ast.Attribute)
    if any(not isinstance(x,allowed) for x in ast.walk(tree)):raise ValueError('Source guard outside evaluator allowlist')
    return compile(tree,'source-extracted MQL predicate, Python evaluation only','eval')
def ev(code,env):return bool(eval(code,{'__builtins__':{}},env))

def guard_tests():
    profile=bare(PROFILE);operator=prior.function(profile,'SWV5S5_MvpOperatorInvocationValid').split('return ',1)[1].split(';',1)[0]
    life=int(re.search(r'SWV5S5_MVP_MANUAL_AUTHORITY_LIFETIME_SECONDS\s*=\s*(\d+)',profile).group(1))
    op=NS(operator_id='OPERATOR',authority_role='FUSION_DEMO_MVP_OPERATOR',authentication_reference='FRESH_A',authenticated_at=1000)
    code=expression(operator)
    def valid(v,t):return ev(code,dict(invocation=v,now=t,SWV5S5_MVP_OPERATOR_ROLE='FUSION_DEMO_MVP_OPERATOR',SWV5S5_MVP_MANUAL_AUTHORITY_LIFETIME_SECONDS=life))
    for label,t,want in [('same',1000,True),('later-1',1001,True),('later-3',1003,True),('last-second',4599,True),('before-A',999,False),('horizon',4600,False),('after-horizon',4601,False)]:
        check('OPERATOR/'+label,valid(op,t)==want,'SOURCE_EXTRACTED_PYTHON_GUARD')
    for key,value in [('operator_id',''),('authority_role','WRONG'),('authentication_reference',''),('authenticated_at',0)]:
        changed=deepcopy(op);setattr(changed,key,value);check('OPERATOR/invalid-'+key,not valid(changed,1001),'SOURCE_EXTRACTED_PYTHON_GUARD')
    check('POLICY/existing-3600-seconds',life==3600)
    head=subprocess.check_output(['git','show','HEAD:'+PROFILE.relative_to(ROOT).as_posix()],cwd=ROOT,text=True)
    check('PROFILE/account-profile-validator-unchanged',prior.function(profile,'SWV5S5_MvpProfileMatches')==prior.function(prior.clean(head),'SWV5S5_MvpProfileMatches'))
    check('PROFILE/only-invocation-validity-body-changed',compact(profile.replace(prior.function(profile,'SWV5S5_MvpOperatorInvocationValid'),
          prior.function(prior.clean(head),'SWV5S5_MvpOperatorInvocationValid'),1))==compact(prior.clean(head)))
    mutant=operator.replace('now>=invocation.authenticated_at','now==invocation.authenticated_at')
    mcode=expression(mutant)
    check('MC/actual-operator-exact-second-reversion-killed',valid(op,1001) and not ev(mcode,dict(invocation=op,now=1001,SWV5S5_MVP_OPERATOR_ROLE=op.authority_role,SWV5S5_MVP_MANUAL_AUTHORITY_LIFETIME_SECONDS=life)), 'SOURCE_MUTATION_PYTHON_NOT_MQL_MUTANT')
    broker=prior.function(bare(FLAT),'SWV5S5_MvpContinuationBrokerZero')
    source=broker.split('const bool accepted=',1)[1].split(';',1)[0];bc=expression(source)
    prof=NS(broker_identity='Exness Technologies Ltd',server='Exness-MT5Trial6',account_login=1234,symbol='XAUUSD')
    account=deepcopy(prof)
    observation=NS(profile=prof,observed_at=1002,positions_query_succeeded=True,active_orders_query_succeeded=True,
                   enumeration_complete=True,row_failures=0,total_positions=0,total_active_orders=0,total_exposure_volume=0.0,snapshot_digest='DIGEST')
    def zero(o,captured=True,start=1002,now=1003):
        env=dict(captured=captured,observed=o,account=account,at=1000,capture_started=start,TimeCurrent=lambda:now,
          SWV5S5_MvpProfileMatches=lambda p,mode:p.symbol=='XAUUSD',ACCOUNT_TRADE_MODE_DEMO=0,MathIsValidNumber=math.isfinite,
          SWV5S5_MvpBootstrapBrokerDigest=lambda o,d:True,digest='DIGEST')
        return ev(bc,env)
    check('BROKER/later-real-zero-valid',zero(observation),'SOURCE_GUARD_STUBBED_DIGEST_NOT_NATIVE')
    same=deepcopy(observation);same.observed_at=1000
    check('BROKER/same-real-zero-valid',zero(same,start=1000,now=1000),'SOURCE_GUARD_STUBBED_DIGEST_NOT_NATIVE')
    negatives=[('observed_at',999),('observed_at',1001),('observed_at',1004),('positions_query_succeeded',False),('active_orders_query_succeeded',False),
               ('enumeration_complete',False),('row_failures',1),('total_positions',1),('total_active_orders',1),('total_exposure_volume',0.01),
               ('total_exposure_volume',float('nan')),('snapshot_digest','WRONG')]
    for n,(key,value) in enumerate(negatives):
        o=deepcopy(observation);setattr(o,key,value);check('BROKER/negative-'+key+'-'+str(n),not zero(o),'SOURCE_GUARD_STUBBED_DIGEST_NOT_NATIVE')
    for key,value in [('broker_identity','FOREIGN'),('server','FOREIGN'),('account_login',9999),('symbol','OTHER')]:
        o=deepcopy(observation);setattr(o.profile,key,value);check('BROKER/wrong-'+key,not zero(o),'SOURCE_GUARD_STUBBED_DIGEST_NOT_NATIVE')
    check('BROKER/capture-failure',not zero(observation,captured=False),'SOURCE_GUARD_STUBBED_DIGEST_NOT_NATIVE')
    # Evaluate the ACTUAL final-clock rejection predicate, stubbing read-only
    # physical I/O/digest calls. Structural validation is checked separately.
    finish=prior.function(bare(CORE),'FinishFinalization')
    marker=finish.index('if(!clock_authority.CurrentFreshObservation')
    condition=prior.delimited(finish,finish.index('(',marker))[0];fc=expression(condition)
    final=NS(clock_id='CLOCK',clock_authority=1,clock_sequence=5,observed_at=1003)
    def final_reject(**kw):
        c=deepcopy(final)
        for k in ('clock_id','clock_authority','clock_sequence','observed_at'):
            if k in kw:setattr(c,k,kw[k])
        invocation=deepcopy(op)
        return ev(fc,dict(clock_authority=NS(CurrentFreshObservation=lambda out:kw.get('fresh',True),LoadStored=lambda *args:kw.get('loaded',True)),
           final_clock=c,stored=c,clock_row=None,found=kw.get('found',True),SWV5S5_MvpLeaseClockPayload=lambda *args:True,
           a='PAYLOAD',b=kw.get('payload','PAYLOAD'),digest='',m_prepared_flat=NS(clock_id='CLOCK',clock_authority=1),
           m_initial_event_sequence=4,m_initial_event_time=1000,m_observation_horizon=1002,op=invocation,
           SWV5S5_MvpOperatorInvocationValid=valid))
    check('FINAL_CLOCK/real-later-accepted',not final_reject(),'SOURCE_GUARD_STUBBED_READ_ONLY_IO_NOT_MQL')
    for label,kw in [('no-fresh',dict(fresh=False)),('read-failure',dict(loaded=False)),('missing',dict(found=False)),('wrong-payload',dict(payload='OTHER')),
        ('old-sequence',dict(clock_sequence=4)),('skipped-sequence',dict(clock_sequence=6)),('same-time',dict(observed_at=1000)),
        ('before-observation',dict(observed_at=1001)),('wrong-id',dict(clock_id='OTHER')),('wrong-authority',dict(clock_authority=0)),('expired-A',dict(observed_at=4600))]:
        check('FINAL_CLOCK/'+label,final_reject(**kw),'SOURCE_GUARD_STUBBED_READ_ONLY_IO_NOT_MQL')
    release=prior.function(bare(PROFILE.with_name('SW_V5_S5_MvpDemoAuthorityProviders.mqh')),'SWV5S5_MvpHardKillReleaseValid')
    begin=release.index('evidence.broker_evidence.observed_at>=evidence.operator_identity.authenticated_at')
    end=release.index(' &&',release.index('context.clock_time<evidence.expires_at',begin))
    chronology=expression(release[begin:end])
    def ordered(broker_time=1002,persistence_time=1002,exposure_time=1002,approved=1003,released=1003,now=1003,expiry=4603):
        evidence=NS(operator_identity=NS(authenticated_at=1000),broker_evidence=NS(observed_at=broker_time),
            persistence_evidence=NS(observed_at=persistence_time),exposure_evidence=NS(observed_at=exposure_time),
            approved_at=approved,released_at=released,expires_at=expiry)
        return ev(chronology,dict(evidence=evidence,context=NS(clock_time=now))) and valid(op,now)
    for label,kw,wanted in [('T0-T1-T2',{},True),('evidence-at-T2',dict(broker_time=1003,persistence_time=1003,exposure_time=1003),True),
        ('observation-before-A',dict(broker_time=999),False),('observation-after-T2',dict(broker_time=1004),False),
        ('persistence-after-T2',dict(persistence_time=1004),False),('exposure-after-T2',dict(exposure_time=1004),False),
        ('approval-after-release',dict(approved=1004),False),('release-after-context',dict(released=1004),False),
        ('expiry-at-context',dict(expiry=1003),False),('old-T0-context',dict(now=1000),False)]:
        check('SHARED_RELEASE_CHRONOLOGY/'+label,ordered(**kw)==wanted,'SOURCE_EXTRACTED_TEMPORAL_GUARD_NOT_MQL')
    return dict(operator_expression=operator,finite_lifetime=life,broker_expression=source,final_clock_rejection=condition)

def main():
    baseline=json.loads((HERE/'OPERATOR_TIME_BINDING_BASELINE.json').read_text())['files']
    before={str(p):prior.db_artifact(p) for p in (prior.ORIGINAL,prior.COPY,SEED)}
    changed=[r['path'] for r in baseline if sha(Path(r['path']))!=r['sha256']]
    check('SCOPE/only-approved-existing-MQL-files',set(changed)=={str(p) for p in (PROFILE,CORE,FLAT,SUITE,WRAPPER)},'PRE_PATCH_HASH_BASELINE')
    old_targets=[r for r in baseline if str(COMMON) in r['path']]
    check('DB/all-original-donor-old-targets-preserved',all(sha(Path(r['path']))==r['sha256'] for r in old_targets),'READ_ONLY_HASH')
    check('DB/real-donor-fresh-seed-identical',all(sha(p)==prior.EXPECTED for p in (prior.ORIGINAL,prior.COPY,SEED)),'READ_ONLY_HASH')
    check('DB/original-and-fresh-seed-no-sidecars',all(not Path(str(p)+s).exists() for p in (prior.ORIGINAL,SEED) for s in ('-wal','-shm')),'READ_ONLY_METADATA')
    check('TARGET/new-mutable-family-absent',not list(COMMON.glob(SEED.name+'.RETEST*')),'READ_ONLY_METADATA')
    values=dict(l.split('=',1) for l in PRESET.read_text(encoding='utf-8-sig').splitlines() if '=' in l)
    check('PRESET/exact-fresh-inputs',values==dict(explicit_test_only_marker='TEST_ONLY_AUTHORIZED_UNCOMMITTED_DRAFT',initial_copy_relative_path=SEED.name,
       expected_initial_copy_sha256=prior.EXPECTED.lower(),execute_test_copy_once='true',operator_confirmed_test_copy='true'))
    check('PRESET/installed-identical',sha(PRESET)==sha(HERE/PRESET.name),'READ_ONLY_HASH')
    source=HERE/(prior.EA+'.mq5');installed=DATA/'MQL5/Experts/FusionProV5Tests'/(prior.EA+'.ex5')
    prior.checks.clear();refusal=prior.isolated_guard_tests(bare(source));isolation=prior.source_safety(bare(source),installed)
    for item in prior.checks:check(item['id'],item['passed'],'SOURCE_REFUSAL_AND_ISOLATION_NOT_NATIVE')
    prior.checks.clear();oldcopy=prior.COPY
    try:prior.COPY=SEED;prestate=prior.physical_prestate()
    finally:prior.COPY=oldcopy
    for item in prior.checks:check(item['id'],item['passed'],'IMMUTABLE_READ_ONLY_SEED')
    guards=guard_tests()
    core=bare(CORE);suite=bare(SUITE);wrapper=bare(WRAPPER)
    run=prior.function(core,'Run');finish=prior.function(core,'FinishFinalization');prepare=prior.function(core,'Flat')
    jobs=prior.function(suite,'FinishJobs');start=prior.function(suite,'Start');later=prior.function(suite,'FinishLaterTick')
    check('A/initial-event-exact-and-fresh','op.authenticated_at!=event_clock.observed_at' in run and
          'CurrentFreshObservation(event_clock)' in run and 'at<event_clock.observed_at' in run)
    check('A/wait-is-memory-only','m_attended_op=op' in core and 'm_waiting_finalization=true' in core and
          'm_waiting_finalization=false;m_initial_event_time=0' in core)
    check('A/finalization-exact-op-payload-and-input','SWV5S5_MvpOperatorPayload(m_attended_op,b,digest) || a!=b' in finish and
          all(s in finish for s in ('i.path!=m_attended_input.path','i.namespace_digest!=m_attended_input.namespace_digest','i.continuation_id!=m_attended_input.continuation_id')))
    check('TIME/no-observation-backdating',all(s in prepare for s in ('flat.broker.observed_at=observation.observed_at','flat.exposure.observed_at=observation.observed_at',
          'const datetime persistence_observed_at=TimeCurrent()','flat.persistence.observed_at=persistence_observed_at')) and
          not re.search(r'(?:broker|persistence|exposure)\.observed_at\s*=',finish))
    check('TIME/preparation-no-durable-flat-or-release',not re.search(r'CompareAndSet|PrepareMutation|StageContinuationPending|PersistApproved',prepare) and 'return AwaitFinalClock' in run)
    check('TIME/finalization-accepted-not-TimeCurrent-context','context.clock_time=final_clock.observed_at' in finish and 'context.clock_time=TimeCurrent' not in finish and 'CurrentFreshObservation(final_clock)' in finish)
    check('TIME/wait-nonclock-exact-and-atomic-CAS','SWV5S5_MvpContinuationRowExact(rows[x],m_finalization_rows[x])' in finish and
          'CompareAndSetWithExactSnapshot(mutation,false,none,rows' in finish)
    publisher=prior.function(wrapper,'PublishAcceptedContinuationTick');tick=prior.function(wrapper,'OnTick')
    check('CLOCK/one-existing-production-publisher-route',wrapper.count('ObserveFromCurrentSymbolOnTick(')==1 and 'clock.ObserveFromCurrentSymbolOnTick' in publisher and
          'tick.time==now' in publisher and tick.count('PublishAcceptedContinuationTick(')==2)
    check('LATCH/no-retry-and-consume-before-final-publication',tick.index('g_finalization_dispatched=true')<tick.index('PublishAcceptedContinuationTick(final_clock') and
          'OnTimer' not in wrapper and 'g_operator=op' in tick and 'if(!g_ack || g_consumed' in tick)
    check('LATCH/expired-A-denied-before-clock-publication',tick.index('SWV5S5_MvpOperatorInvocationValid(g_operator,TimeCurrent())')<tick.index('PublishAcceptedContinuationTick(final_clock'))
    check('TEST/no-compensating-MAIN-new-attempt','m_main_second_phase' not in suite and 'm_job_kind[m_last_job]="MAIN"' in start)
    check('TEST/queued-job-one-later-native-tick','m_job_tick[j]>=m_tick_id' in jobs and jobs.index('m_job_active[j]=false')<jobs.index('ObserveFromCurrentSymbolOnTick') and 'tick.time!=native_time' in jobs)
    check('TEST/no-recapture-at-finalization','m_job_broker[j].calls==captures_before' in jobs and 'broker.Capture(' not in finish)
    check('TEST/waiting-is-not-negative-rejection','Check(rejected && !Waiting(result),id)' in suite)
    check('TEST/boundary-control-mutant-both-required','m_boundary_pass[base] && m_boundary_pass[base+1]' in jobs and
          'm_boundary_basis[base]==m_boundary_basis[base+1]' in jobs and 'release_invoked && !accepted' in suite and 'release_invoked && accepted' in suite)
    check('TEST/all-native-regression-families-scheduled',all('"'+s+'"' in start for s in ('HEARTBEAT','TRUST','GOVERNANCE','FLAT','PENDING','RELEASED','INACTIVE')) and
          all(s in jobs for s in ('RESUME_FIRST','RESUME_COMPLETE','CLOCK_COMPLETE','StringFind(m_job_kind[j],"BOUND_")==0')) and
          all(s in suite for s in ('BOUND_PENDING_CONTROL','BOUND_PENDING_MUTATED','BOUND_ACTIVE_CONTROL','BOUND_ACTIVE_MUTATED')))
    check('TEST/preflight-later-native-tick-and-all-rows-exact','m_tick_id<=m_main_completion_tick' in later and 'PREFLIGHT_COMPLETE_ZERO_SUBMISSION' in later and 'SameRows(m_rows,after)' in later)
    for test_id in ('OPERATOR_WINDOW_BEFORE_AUTH_REJECTED','OPERATOR_WINDOW_HORIZON_REJECTED','NEG_WRONG_OPERATOR','NEG_WRONG_REFERENCE','OBSERVATION_BEFORE_A_REJECTED',
                   'OBSERVATION_AFTER_FINAL_CLOCK_REJECTED','PERSISTENCE_AFTER_FINAL_CLOCK_REJECTED','NEG_NO_FINAL_CLOCK','NEG_COLD_RESTART','CLOCK_ZERO_TIME_REJECTED_BY_TIME_VALIDATOR_NOT_CAS'):
        check('TEST/required-executable-assertion/'+test_id,test_id in suite)
    for filename in ('SW_V5_S5_MvpDemoAuthorityProviders.mqh','SW_V5_S5_MvpHardKillReleasePhysical.mqh','SW_V5_S5_MvpHardKillActivationAuthority.mqh','SW_V5_S5_MvpManualProvisioningAuthorities.mqh'):
        p=PROFILE.with_name(filename);r=next(r for r in baseline if r['path']==str(p))
        check('SHARED/ordering-DTO-digests-unchanged/'+filename,sha(p)==r['sha256'],'SOURCE_HASH')
    # Active prior regressions, with the old B7-installed HOLD expectation alone
    # superseded by this explicit build/install authorization, not source gates.
    layering.checks.clear();buf=io.StringIO()
    with contextlib.redirect_stdout(buf):layering.main()
    regression=json.loads(buf.getvalue());superseded=[]
    for item in regression['checks']:
        if item['id']=='native-full/old-install-held':superseded.append(item);continue
        check('REGRESSION/'+item['id'],item['passed'],item['evidence_class'])
    check('PROVENANCE/current-full-build-not-stale',all(x['passed'] for x in regression['held_full_native_build_gates']),'BUILD_PROVENANCE')
    runtime_dir=HERE.parent/'Sprint5MvpRuntime';process_results={}
    for script in ('verify_mvp_runtime.py','verify_mvp_mutation_controls.py'):
        p=subprocess.run([__import__('sys').executable,str(runtime_dir/script)],cwd=ROOT,capture_output=True,text=True)
        process_results[script]=dict(exit_code=p.returncode,output=p.stdout,stderr=p.stderr)
        check('RUNTIME/'+script,p.returncode==0 and '|FAIL' not in p.stdout and '|SURVIVED' not in p.stdout,'PYTHON_ORACLE_NOT_MQL')
    compile_results={}
    paths=[HERE/(n+'.mq5') for n in ('SW_V5_S5_MVP_ATTENDED_AUTHORITY_CONTINUATION','SW_V5_S5_MVP_CONTINUATION_ASSERTIONS',prior.EA)]
    paths.append(runtime_dir/'SOMWANG_XAU_M15_FUSION_PRO_V5_MVP_RUNTIME_TESTS.mq5')
    for p in paths:
        line=re.findall(r'^Result:.*',p.with_suffix('.log').read_text(encoding='utf-16'),re.M)[-1]
        check('COMPILE/'+p.stem,bool(re.fullmatch(r"Result: 0 errors, 0 warnings, .*cpu='X64 Regular'",line)) and
              p.with_suffix('.log').stat().st_mtime>=max(SUITE.stat().st_mtime,PROFILE.stat().st_mtime,CORE.stat().st_mtime),'METAEDITOR_NOT_EXECUTION')
        compile_results[p.stem]=dict(result=line,ex5=prior.artifact(p.with_suffix('.ex5')))
    built=source.with_suffix('.ex5')
    check('BINARY/installed-current-and-new',sha(installed)==sha(built) and sha(built)!='292DA9F9E5719609587E29A48157FB33716D5BD48926A09C93038B11F1218838','READ_ONLY_HASH')
    check('DB/all-before-after-exact',before=={str(p):prior.db_artifact(p) for p in (prior.ORIGINAL,prior.COPY,SEED)} and
          all(sha(Path(r['path']))==r['sha256'] for r in old_targets),'READ_ONLY_HASH')
    check('GIT/diff-check',subprocess.run(['git','diff','--check'],cwd=ROOT,capture_output=True).returncode==0,'GIT')
    git={k:subprocess.check_output(['git',*args],cwd=ROOT,text=True).strip() for k,args in [('branch',['branch','--show-current']),('HEAD',['rev-parse','HEAD']),('tree',['rev-parse','HEAD^{tree}']),('main',['rev-parse','main']),('status',['status','--short'])]}
    check('GIT/frozen-production-contracts-unchanged',subprocess.run(['git','diff','--quiet','HEAD','--','FusionProV5/ProductionArchitecture'],cwd=ROOT).returncode==0,'GIT')
    check('GIT/canonical-base-and-main',git['branch']=='sprint5-phase-f-entry-contract' and git['HEAD']=='d926f2e6b1aa4ea7b4b0936293d2fa47a2ce7ba8' and git['main']=='32b79ca71ffc331e15e48a57c52be1352e3dbe7e','GIT')
    rawpath=DATA/'MQL5/Logs/20261014.log';raw=rawpath.read_text(encoding='utf-16');pos=raw.rfind('CONTINUATION_NATIVE_COPY|START|');end=raw.find('CONTINUATION_NATIVE_COPY|COMPLETE|',pos);end=raw.find('\n',end);historical=raw[pos:end]
    check('BASELINE/latest-native-153-8-preserved','passed=153|failed=8|skipped=0|total=161' in historical and 'original_unchanged=true' in historical,'HISTORICAL_NATIVE_NOT_POST_PATCH')
    print(json.dumps(dict(classification='OPERATOR_TIME_BINDING_PRE_RUN_ONLY_NATIVE_EXECUTION_PENDING',time_utc=datetime.now(timezone.utc).isoformat(),
       summary=dict(total=len(checks),passed=sum(c['passed'] for c in checks),failed=sum(not c['passed'] for c in checks),post_patch_MQL_executions=0),checks=checks,
       guards=guards,source_changes=changed,runtime_test_sources=[prior.artifact(runtime_dir/n) for n in
          ('SW_V5_S5_MvpRuntimeAssertions.mqh','verify_mvp_runtime.py','verify_mvp_mutation_controls.py')],
       source_digest=isolation['source_digest'],refusal=refusal,isolation=isolation,prestate=prestate,
       original_donor_seed=before,preset=prior.artifact(PRESET),inputs=values,installed=prior.artifact(installed),compile=compile_results,
       new_MAIN_target=str(COMMON/(SEED.name+'.RETEST.MAIN.sqlite')),runtime_python=process_results,
       layering_summary=regression['summary'],governance_summary=regression['full_governance_regression_summary'],superseded_old_binary_hold=superseded,
       historical_native_failures=re.findall(r'CONTINUATION_ASSERT\|([^\r\n|]+)\|FAIL',historical),historical_log_path=str(rawpath),
       historical_run_summary='passed=153|failed=8|skipped=0|total=161',historical_log_sha256=sha(rawpath),git=git,verifier_sha256=sha(Path(__file__))),indent=2))
    return int(any(not c['passed'] for c in checks))
if __name__=='__main__':raise SystemExit(main())
