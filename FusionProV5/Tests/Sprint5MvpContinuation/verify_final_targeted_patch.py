"""TEST ONLY. Final targeted patch/pre-run audit. NEVER launches MT5.
No writable SQLite connection except private :memory: oracle. Native MQL
assertions remain pending operator execution; Python is not MQL evidence.
"""
from pathlib import Path
import ast, contextlib, hashlib, io, json, re, sqlite3, subprocess
from datetime import datetime, timezone
import verify_native_copy_prerun as prior
import verify_event_freshness_layering as layering
import verify_governance_refresh as gov

HERE=prior.HERE; ROOT=prior.ROOT; COMMON=prior.COMMON; DATA=prior.DATA
RUN='8e6c2b6183a44fedb58c28d730aa1140'
SEED=COMMON/('TEST_ONLY_MVP_CONTINUATION_'+RUN+'.sqlite')
PRESET=DATA/'MQL5/Presets'/(SEED.name+'.set')
CORE=layering.CORE; SUITE=layering.SUITE
FLAT=CORE.with_name('SW_V5_S5_MvpContinuationFlatAuthority.mqh')
checks=[]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest().upper()
def check(name,ok,kind='STATIC_SOURCE_NOT_MQL_EXECUTION'):
    checks.append(dict(id=name,passed=bool(ok),evidence_class=kind))
def bare(p):return prior.clean(p.read_text(encoding='utf-8-sig'))
def compact(s):return re.sub(r'\s+','',s)

def zero_time_oracle():
    # Real SQLite execution, but deliberately private memory only. The donor
    # is read as immutable/query_only; the deployment DB is never connected.
    c=sqlite3.connect(prior.COPY.as_uri()+'?mode=ro&immutable=1',uri=True)
    c.row_factory=sqlite3.Row;c.execute('PRAGMA query_only=ON')
    try:r=dict(c.execute("SELECT * FROM swv5_authority_rows WHERE domain_key='MVP_OWNERSHIP_LEASE' AND record_key='LEASE_CLOCK_CURRENT'").fetchone())
    finally:c.close()
    proposed=r.copy();proposed['logical_revision']+=1
    proposed['payload']=gov.update(r['payload'],{'observed_at':0})
    proposed['payload_digest']=prior.digest(r['domain_key'],proposed['payload'])
    body=''.join(prior.field(k,t,proposed[k]) for k,t in [('namespace_digest','s'),('domain_key','s'),('record_key','s'),('logical_revision','u'),('payload_digest','s')])
    proposed['store_revision']=prior.digest('SWV5-S5-MVP-STORE-REVISION-V1',body)
    store=bare(CORE.with_name('SW_V5_S5_MvpSqliteAuthorityStore.mqh'))
    condition=prior.first_if_condition(prior.function(store,'CompareAndSet'))
    expression=re.sub(r'!(?!=)',' not ',condition.replace('||',' or ').replace('&&',' and '))
    tree=ast.parse('('+expression+')',mode='eval')
    allowed=(ast.Expression,ast.BoolOp,ast.Or,ast.And,ast.UnaryOp,ast.Not,ast.Compare,ast.Eq,ast.NotEq,ast.LtE,ast.Call,ast.Name,ast.Load,ast.Constant,ast.BinOp,ast.Add)
    if any(not isinstance(n,allowed) for n in ast.walk(tree)):raise ValueError('CAS guard outside evaluator allowlist')
    code=compile(tree,'actual source-extracted CAS precondition','eval')
    env=dict(VerifyMetadata=lambda:True,domain_key=r['domain_key'],record_key=r['record_key'],
             proposed_revision=proposed['logical_revision'],expected_revision=r['logical_revision'],
             SWV5S5_IsDigest64Lower=lambda s:bool(re.fullmatch('[0-9a-f]{64}',s)),
             proposed_payload_digest=proposed['payload_digest'],proposed_payload=proposed['payload'],updated_at=0)
    check('ZERO_TIME/old-zero-physical-time-rejected',eval(code,{'__builtins__':{}},env),'SOURCE_EXTRACTED_PYTHON_GUARD')
    env['updated_at']=r['updated_at']
    check('ZERO_TIME/new-positive-physical-time-admitted',not eval(code,{'__builtins__':{}},env),'SOURCE_EXTRACTED_PYTHON_GUARD')
    db=sqlite3.connect(':memory:');db.row_factory=sqlite3.Row
    columns=list(r)
    db.execute('CREATE TABLE rows('+','.join(columns)+')')
    db.execute('INSERT INTO rows VALUES('+','.join('?' for _ in columns)+')',tuple(r[k] for k in columns))
    setfields=['logical_revision','store_revision','payload_digest','payload','updated_at']
    keys=['namespace_digest','domain_key','record_key','logical_revision','store_revision','payload_digest','state']
    sql='UPDATE rows SET '+','.join(k+'=?' for k in setfields)+' WHERE '+' AND '.join(k+'=?' for k in keys)
    values=tuple(proposed[k] for k in setfields)+tuple(r[k] for k in keys)
    changed=db.execute(sql,values).rowcount;readback=dict(db.execute('SELECT * FROM rows').fetchone())
    check('ZERO_TIME/memory-SQLite-exact-CAS-readback',changed==1 and readback==proposed,'SQLITE_MEMORY_ORACLE_NOT_MQL_EXECUTION')
    check('ZERO_TIME/stale-CAS-rejected',db.execute(sql,values).rowcount==0,'SQLITE_MEMORY_ORACLE_NOT_MQL_EXECUTION')
    old=prior.decode(r['payload']);new=prior.decode(readback['payload'])
    check('ZERO_TIME/payload-time-only-mutated',[k for k in old if old[k]!=new[k]]==['observed_at'] and readback['updated_at']==r['updated_at']>0,'SQLITE_MEMORY_ORACLE_NOT_MQL_EXECUTION')
    diagnostic=prior.function(bare(layering.OWNER),'CurrentFreshObservationDiagnostic')
    check('ZERO_TIME/time-validator-exact-negative','CONT_CLOCK_REQUIRE(current.observed_at>0,"PRESTATE_CLOCK_TIME_INVALID")' in diagnostic and new['observed_at']==0)
    db.close()
    return dict(classification='SOURCE_EXTRACTED_CAS_GUARD_AND_SQLITE_MEMORY_ORACLE_NOT_NATIVE_MQL',
                source_CAS_guard=condition,changed_fields=['observed_at'],updated_at=readback['updated_at'],CAS_rows=changed,
                clock_validator='PRESTATE_CLOCK_TIME_INVALID',native_execution='PENDING')

def main():
    baseline=json.loads((HERE/'FINAL_TARGETED_PATCH_BASELINE.json').read_text())['files']
    before={str(p):prior.db_artifact(p) for p in (prior.ORIGINAL,prior.COPY,SEED)}
    changed=[r['path'] for r in baseline if sha(Path(r['path']))!=r['sha256']]
    expected={str(p) for p in (CORE,FLAT,SUITE)}
    check('SCOPE/only-three-approved-MQL-source-changes',set(changed)==expected,'SOURCE_HASH_BASELINE')
    check('DB/prior-native-test-clones-preserved',all(sha(Path(r['path']))==r['sha256'] for r in baseline if 'RETEST_' in r['path']),'READ_ONLY_HASH')
    check('DB/real-donor-fresh-seed-exact',all(sha(p)==prior.EXPECTED for p in (prior.ORIGINAL,prior.COPY,SEED)),'READ_ONLY_HASH')
    check('DB/real-and-new-seed-no-sidecars',all(not Path(str(p)+s).exists() for p in (prior.ORIGINAL,SEED) for s in ('-wal','-shm')),'READ_ONLY_METADATA')
    wal=Path(str(prior.COPY)+'-wal')
    check('DB/donor-no-uncheckpointed-WAL',not wal.exists() or wal.stat().st_size==0,'READ_ONLY_METADATA')
    check('TARGET/all-new-mutable-targets-absent',not list(COMMON.glob(SEED.name+'.RETEST*')),'READ_ONLY_METADATA')
    values=dict(line.split('=',1) for line in PRESET.read_text(encoding='utf-8-sig').splitlines() if '=' in line)
    check('PRESET/exact-fresh-TEST_ONLY-inputs',values==dict(explicit_test_only_marker='TEST_ONLY_AUTHORIZED_UNCOMMITTED_DRAFT',
          initial_copy_relative_path=SEED.name,expected_initial_copy_sha256=prior.EXPECTED.lower(),execute_test_copy_once='true',operator_confirmed_test_copy='true'))
    check('PRESET/installed-byte-identical',sha(PRESET)==sha(HERE/PRESET.name),'READ_ONLY_HASH')
    ea=HERE/(prior.EA+'.mq5');harness=bare(ea);suite=bare(SUITE);core=bare(CORE);flat=bare(FLAT)
    prior.checks.clear();refusal=prior.isolated_guard_tests(harness)
    installed=DATA/'MQL5/Experts/FusionProV5Tests'/(prior.EA+'.ex5')
    isolation=prior.source_safety(harness,installed)
    for c in prior.checks:check(c['id'],c['passed'],'SOURCE_EXTRACTED_REFUSAL_AND_ISOLATION')
    prior.checks.clear();oldcopy=prior.COPY
    try:prior.COPY=SEED;prestate=prior.physical_prestate()
    finally:prior.COPY=oldcopy
    for c in prior.checks:check(c['id'],c['passed'],'READ_ONLY_IMMUTABLE_SEED')
    start=prior.function(suite,'Start');finish=prior.function(suite,'FinishLaterTick');execute=prior.function(suite,'Execute')
    positive=prior.function(suite,'MainAssertions');resume=prior.function(suite,'Resume');clone=prior.function(suite,'Clone')
    check('MAIN/freshness-specific-deferred-second-phase','result.reason=="CONTINUATION_NEW_ATTENDED_EVENT_FRESHNESS_REQUIRED"' in start and
          'broker.calls==0 && ClockOnlyPartial(m_main,main_before,main_partial)' in start)
    check('MAIN/later-native-tick-and-new-ack',all(s in finish for s in ('event_time>m_main_first_event','tick.time!=event_time','next.acknowledged=true','Execute(next,main_broker,main_result)')))
    check('MAIN/second-phase-consumed-before-execute',finish.index('m_main_second_phase=false;')<finish.index('Execute(next,main_broker,main_result)') and finish.count('Execute(next,main_broker,main_result)')==1)
    check('MAIN/new-publication-object-and-unique-event-id','SWV5S5_MvpLeaseClockAuthority clock;' in execute and 'ObserveFromCurrentSymbolOnTick' in execute and 'GetMicrosecondCount()' in execute)
    check('MAIN/four-original-positive-predicates-preserved',all(s in positive for s in (
          'ok && result.accepted && !result.partial_continuation','result.final_latch_generation==result.initial_latch_generation+2 && result.release_generation==2',
          'result.broker_submission_calls==0 && broker.calls==2','owner.ReadCompletedOnly(m_input,result) && result.already_complete',
          'REAL_SQLITE_CONTINUATION_COMPLETE','MONOTONIC_GENERATIONS','TWO_BROKER_OBSERVATIONS_ZERO_SUBMISSION','COMPLETED_REPLAY_READBACK_ONLY')))
    check('PREFLIGHT/completed-main-snapshot-then-strictly-later-tick',finish.index('MainAssertions(complete,main_broker,main_result)')<finish.index('Rows(m_main,m_rows)')<finish.index('m_t0=TimeCurrent();return false;')<finish.index('NativePreflight(m_main,result)'))
    check('PREFLIGHT/accepted-result-and-complete-row-equality',all(s in finish for s in ('result.accepted','PREFLIGHT_COMPLETE_ZERO_SUBMISSION','SameRows(m_rows,after)','!result.permit_committed','!result.claim_attempted','!result.adapter_invoked_same_event')))
    check('TARGET/seed-specific-run-id-prefix','m_run_prefix=m_copy+".RETEST";' in start)
    check('TARGET/no-overwrite-and-donor-hash-gate',all(s in clone for s in ('FileIsExist(name,FILE_COMMON)','FileIsExist(name+"-wal",FILE_COMMON)','FileIsExist(name+"-shm",FILE_COMMON)','SWV5S5_TestContinuationFileSha(m_copy,digest)','FileCopy(m_copy,FILE_COMMON,name,FILE_COMMON)')) and suite.count('FileCopy(')==1)
    check('TRUST_GOV/detail-before-early-return',resume.index('Print("CONTINUATION_PARTIAL_DETAIL|"')<resume.index('if(!interrupted)') and '|hook_fired=' in resume)
    run=prior.function(core,'Run')
    for stage in ('OWNERSHIP_HEARTBEAT','TRUST_REFRESH','GOVERNANCE_REFRESH'):
        check('DIAGNOSTIC/attempt-and-result/'+stage,'CONTINUATION_STAGE_TRACE|ATTEMPT|id=' in run and
              run.count('"|stage='+stage+'"')==2 and 'CONTINUATION_STAGE_TRACE|STOP|stage=' in core)
    check('DIAGNOSTIC/fresh-gate-fact-and-skipped-stages','|fresh_event_acquired=' in run and '|profile_time=' in run and '|heartbeat=NOT_ATTEMPTED|trust=NOT_ATTEMPTED|governance=NOT_ATTEMPTED' in run)
    predicate=prior.function(flat,'SWV5S5_MvpContinuationBrokerZero')
    fields=['capture','profile','broker_identity','server','account_login','observed_at','positions_query_succeeded','active_orders_query_succeeded','enumeration_complete',
            'row_failures','total_positions','total_active_orders','finite_exposure','total_exposure_volume','snapshot_digest']
    check('DIAGNOSTIC/all-broker-rejecting-fields',all('rejecting_field="'+s+'"' in predicate for s in fields))
    check('DIAGNOSTIC/exact-values-no-retime-or-recapture',all(s in predicate for s in ('|expected_clock_time=','|positions_query=','|orders_query=','|exposure=','|complete=','|row_failures=','|pending_request_predicate=NOT_INCLUDED')) and
          predicate.count('broker.Capture(')==1 and not re.search(r'observed\.observed_at\s*=(?!=)',predicate))
    check('DIAGNOSTIC/native-before-synthetic-injection',suite.index('Print("CONTINUATION_NATIVE_BROKER_CAPTURE|')<suite.index('if(fault==1)'))
    check('ZERO_TIME/MQL-CAS-readback-and-exact-time-reason',all(s in suite for s in ('fault==14 ? prior.updated_at : bad.observed_at','decoded.observed_at==0',
          'readback.updated_at==prior.updated_at && readback.updated_at>0','CLOCK_ZERO_TIME_CAS_COMMITTED_VALID_METADATA_INVALID_PAYLOAD',
          'reason=="PRESTATE_CLOCK_TIME_INVALID"','CLOCK_ZERO_TIME_REJECTED_BY_TIME_VALIDATOR_NOT_CAS')))
    oracle=zero_time_oracle()
    # Original production predicate is retained verbatim except extraction of
    # the single capture result and test-only logging AFTER evaluation.
    wanted='''captured && SWV5S5_MvpProfileMatches(observed.profile,ACCOUNT_TRADE_MODE_DEMO) &&
      observed.profile.broker_identity==account.broker_identity && observed.profile.server==account.server &&
      observed.profile.account_login==account.account_login && observed.observed_at==at &&
      observed.positions_query_succeeded && observed.active_orders_query_succeeded && observed.enumeration_complete &&
      observed.row_failures==0 && observed.total_positions==0 && observed.total_active_orders==0 &&
      MathIsValidNumber(observed.total_exposure_volume) && observed.total_exposure_volume==0.0 &&
      SWV5S5_MvpBootstrapBrokerDigest(observed,digest) && digest==observed.snapshot_digest'''
    actual=predicate.split('const bool accepted=',1)[1].split(';',1)[0]
    check('RUNTIME/broker-zero-all-original-conjuncts-unchanged',compact(wanted)==compact(actual))
    # Assertions that previously passed are historical evidence, never relabeled
    # as post-fix execution. Their IDs/families and strong boundaries remain.
    log=DATA/'MQL5/Logs/20261014.log';raw=log.read_text(encoding='utf-16')
    begin=raw.index('CONTINUATION_NATIVE_COPY|START|native_time=1791980150')
    end=raw.index('CONTINUATION_NATIVE_COPY|COMPLETE|',begin);end=raw.find('\n',end)
    historical=raw[begin:end];passed=re.findall(r'CONTINUATION_ASSERT\|([^\r\n|]+)\|PASS',historical)
    failed=re.findall(r'CONTINUATION_ASSERT\|([^\r\n|]+)\|FAIL',historical)
    check('BASELINE/actual-prior-149-pass-10-fail',len(passed)==149 and len(failed)==10 and 'passed=149|failed=10|skipped=0|total=159' in historical,'HISTORICAL_NATIVE_NOT_POST_FIX')
    def preserved(test_id):
        if '"'+test_id+'"' in suite:return True
        return any(test_id.startswith(p) and '"'+p+'"' in suite for p in ('CLOCK_DIAG_EQUIVALENT_POSITIVE_','CLOCK_NEGATIVE_','STORED_CLOCK_STRUCTURAL_NEGATIVE_',
                   'PARTIAL_','PARTIAL_FAIL_CLOSED_','RESUME_','NEGATIVE-','HEARTBEAT_', 'OPERATIONAL_ROW_REJECTED_'))
    missing=[s for s in passed if not preserved(s)]
    check('BASELINE/all-149-assertion-ID-families-retained',not missing)
    check('COVERAGE/original-entry-components-retained',all(s in start for s in ('GovernanceClockBinding(false);GovernanceClockBinding(true);',
          'GovernanceRowNegatives();','ClockDiagnosticNegatives();','PeriodicEpochStructural();','HeartbeatIdentityNegatives();OperationalRowNegatives();ReleaseBoundaryMutation(false);ReleaseBoundaryMutation(true);',
          'for(int f=1;f<=11;f++)Negative','Resume(stages[x]);')))
    # Run previous available non-native regressions. The old HOLD installed-B7
    # workflow check alone is superseded by the newly authorized installed EX5.
    layering.checks.clear();out=io.StringIO()
    with contextlib.redirect_stdout(out):layering.main()
    regression=json.loads(out.getvalue());superseded=[]
    for item in regression['checks']:
        if item['id']=='native-full/old-install-held':
            superseded.append(item);continue
        check('REGRESSION/'+item['id'],item['passed'],item['evidence_class'])
    check('PROVENANCE/former-stale-build-gate-now-PASS',bool(regression['held_full_native_build_gates']) and all(c['passed'] for c in regression['held_full_native_build_gates']),'SOURCE_BUILD_PROVENANCE')
    compile_results={}
    for name in ('SW_V5_S5_MVP_ATTENDED_AUTHORITY_CONTINUATION','SW_V5_S5_MVP_CONTINUATION_ASSERTIONS',prior.EA):
        logpath=HERE/(name+'.log');line=re.findall(r'^Result:.*',logpath.read_text(encoding='utf-16'),re.M)[-1]
        check('COMPILE/'+name,bool(re.fullmatch(r"Result: 0 errors, 0 warnings, .*cpu='X64 Regular'",line)) and
              all(logpath.stat().st_mtime>=p.stat().st_mtime for p in (CORE,FLAT,SUITE)),'METAEDITOR_NOT_EXECUTION')
        compile_results[name]=dict(result=line,ex5=prior.artifact(HERE/(name+'.ex5')))
    built=HERE/(prior.EA+'.ex5')
    check('BINARY/installed-exact-current-compile',sha(built)==sha(installed),'READ_ONLY_HASH')
    check('BINARY/new-vs-both-previous-executed',sha(built) not in ('67C32333E865D1FD7BF6DC577F0ED14DF2AF6A27CD401F1C58E49D18D8105C8B','B70132E9D5BA2CF2882971FBAD5DA1DD2D752A9FF83E1529FD00891DE1557C09'),'READ_ONLY_HASH')
    check('DB/all-before-after-exact',before=={str(p):prior.db_artifact(p) for p in (prior.ORIGINAL,prior.COPY,SEED)},'READ_ONLY_HASH')
    check('DB/historical-targets-still-exact',all(sha(Path(r['path']))==r['sha256'] for r in baseline if 'RETEST_' in r['path']),'READ_ONLY_HASH')
    check('GIT/diff-check',subprocess.run(['git','diff','--check'],cwd=ROOT,capture_output=True).returncode==0,'GIT')
    git={k:subprocess.check_output(['git',*args],cwd=ROOT,text=True).strip() for k,args in [('branch',['branch','--show-current']),('HEAD',['rev-parse','HEAD']),('tree',['rev-parse','HEAD^{tree}']),('main',['rev-parse','main']),('status',['status','--short'])]}
    check('GIT/canonical-source-unchanged',git['branch']=='sprint5-phase-f-entry-contract' and git['HEAD']=='d926f2e6b1aa4ea7b4b0936293d2fa47a2ce7ba8' and git['tree']=='46c09cfbed423df9c93b7f63aaf4b901af5b83fd','GIT')
    check('GIT/main-unchanged',git['main']=='32b79ca71ffc331e15e48a57c52be1352e3dbe7e','GIT')
    output=dict(classification='FINAL_TARGETED_PATCH_PRE_RUN_ONLY_NATIVE_EXECUTION_PENDING',time_utc=datetime.now(timezone.utc).isoformat(),
          summary=dict(total=len(checks),passed=sum(c['passed'] for c in checks),failed=sum(not c['passed'] for c in checks),post_patch_native_executions=0),checks=checks,
          source_baseline=prior.artifact(HERE/'FINAL_TARGETED_PATCH_BASELINE.json'),changed_MQL_files=changed,source_digest=isolation['source_digest'],
          original_donor_seed=before,seed=prior.artifact(SEED),preset=prior.artifact(PRESET),preset_inputs=values,
          mutable_MAIN_target=str(COMMON/(SEED.name+'.RETEST.MAIN.sqlite')),all_mutable_targets_pattern=str(COMMON/(SEED.name+'.RETEST*')),
          original_failures=failed,previous_149_pass_ids=passed,missing_preserved_ids=missing,historical_run_sha256=hashlib.sha256(historical.encode()).hexdigest(),
          historical_log=prior.artifact(log),raw_historical_run=historical,post_patch_native_result='NOT EXECUTED',
          unknown_failures=['PARTIAL_TRUST','PARTIAL_GOVERNANCE','RESUME_FLAT','RESUME_PENDING'],
          unknown_failure_disposition='Diagnostic-only: classify on next native run; no speculative fix/no proven production blocker.',
          zero_time_oracle=oracle,refusal=refusal,isolation=isolation,prestate=prestate,compile=compile_results,installed=prior.artifact(installed),
          active_layering_summary=dict(total=len(regression['checks'])-len(superseded),passed=sum(c['passed'] for c in regression['checks'] if c['id']!='native-full/old-install-held')),
          governance_summary=regression['full_governance_regression_summary'],superseded_old_binary_hold=superseded,git=git,verifier_sha256=sha(Path(__file__)))
    print(json.dumps(output,indent=2))
    return int(any(not c['passed'] for c in checks))
if __name__=='__main__':raise SystemExit(main())
