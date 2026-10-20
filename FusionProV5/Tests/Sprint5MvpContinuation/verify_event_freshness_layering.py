"""TEST ONLY / NOT FOR PRODUCTION. NO MT5 LAUNCH / NO BROKER MUTATION.
Separates actual historical native diagnostic, static mutations, independent
Python clock oracle, MetaEditor compilation and pending MQL execution gates.
"""
from pathlib import Path
from copy import deepcopy
import contextlib, hashlib, io, json, re, subprocess
import verify_governance_refresh as gov
import verify_option_r_adjudication as clock_model
import verify_resume_clock_diagnostic as diagnostic

ROOT=diagnostic.ROOT;HERE=diagnostic.HERE;COMMON=diagnostic.COMMON
CORE=ROOT/'FusionProV5/ExecutionLayer/RuntimeAuthority/SW_V5_S5_MvpAttendedContinuation.mqh'
OWNER=ROOT/'FusionProV5/ExecutionLayer/RuntimeAuthority/SW_V5_S5_MvpOwnershipAuthority.mqh'
SUITE=HERE/'SW_V5_S5_MvpContinuationAssertions.mqh'
WRAPPER=HERE/'SW_V5_S5_MVP_ATTENDED_AUTHORITY_CONTINUATION.mq5'
checks=[]
def check(name,ok,category='STATIC_SOURCE'):checks.append(dict(id=name,passed=bool(ok),evidence_class=category))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest().upper()
def event_guard(core):
    run=diagnostic.function(diagnostic.clean(core),'Run')
    return ('!i.acknowledged || !clock_authority.CurrentFreshObservation(event_clock)' in run and
            'stored_payload!=event_payload' in run and 'at<event_clock.observed_at' in run and
            'op.authenticated_at!=event_clock.observed_at' in run and
            run.index('CurrentFreshObservation(event_clock)')<run.index('store.Open(')<run.index('owner.HeartbeatAttended'))
def clock_rows(path):
    fields=gov.raw_fields(path.read_text(encoding='utf-8'));rows={}
    for name,kind,payload in fields:
        if kind!='x':continue
        d=gov.decode(payload);rows[(d['domain'],d['key'])]=dict(domain_key=d['domain'],record_key=d['key'],
            logical_revision=d['revision'],store_revision=d['store_revision'],state=d['state'],
            payload_digest=d['payload_digest'],payload=d['payload'],updated_at=d['updated_at'])
    count=next(int(value) for name,kind,value in fields if name=='count')
    if len(rows)!=count:raise ValueError('Incomplete snapshot')
    return rows
def main():
    hashes={str(p):sha(p) for p in (diagnostic.ORIGINAL,diagnostic.DONOR)}
    core=CORE.read_text(encoding='utf-8-sig');s=diagnostic.clean(core);suite=diagnostic.clean(SUITE.read_text(encoding='utf-8-sig'))
    structural=diagnostic.function(s,'LoadStructuralPreState');classify=diagnostic.function(s,'ClassifyStoredPreState')
    partial=diagnostic.function(s,'ClassifyClockOnlyHistoricalPartial');run=diagnostic.function(s,'Run')
    check('structure/verified-stored-clock','clock_authority.LoadStored(clock,clock_row,found)' in structural)
    check('structure/no-event-freshness-or-ack',not re.search(r'CurrentFreshObservation|m_fresh|i\.acknowledged|OperatorInvocationValid',structural))
    check('structure/read-only-and-no-grant','ConfigureReadOnly' in classify and 'm_result.accepted=true' not in classify and 'NEW_ATTENDED_ATTEMPT_REQUIRED' in classify)
    check('structure/profile-exact',all(x in structural for x in ('clock.clock_id==expected_clock_id','clock.broker_identity==profile.broker_identity',
          'clock.server==profile.server','clock.account_login==profile.account_login','clock.source_symbol==profile.symbol',
          'clock.clock_authority==SWV5_TIME_AUTHORITY_BROKER_SERVER')))
    check('structure/clock-physical-target-exact','SWV5S5_MvpContinuationRowExact(exact_clock,clock_row)' in structural and 'clock_row.updated_at==clock.observed_at' in structural)
    check('structure/ownership-clock-monotonic','clock.clock_sequence>=lease.heartbeat_clock_sequence' in structural and 'clock.observed_at>=lease.heartbeat_at' in structural)
    check('structure/authority-predicates-retained',all(x in structural for x in ('ReadLease','ScopeOwner','ReadTrust','account_owner.ValidateCurrent',
          'ReadGovernance','EmptyExecutionAndBasketDiagnostic','RowsAllowedDiagnostic','LoadExpiredInactive','ResumeProofValid')))
    check('structure/native-diagnostic-time-not-rewritten-clock','context.clock_time=at;' in structural and 'clock.observed_at=at' not in structural)
    check('structure/complete-readset-exact','SWV5S5_MvpContinuationRowExact(read_set[x],final_rows[x])' in structural and
          'SWV5S5_MvpContinuationRowExact(structural_rows[x],mutation_rows[x])' in run)
    check('history/clock-only-exact','new_clock.clock_sequence!=old_clock.clock_sequence+1' in partial and 'changes!=1' in partial and
          'ClassifyStoredPreState' in partial and 'CLOCK_ONLY_HISTORICAL_PARTIAL' in partial and 'm_result.accepted=true' not in partial)
    check('history/no-fixed-deployment-baseline',diagnostic.EXPECTED not in s and 'ClassifyClockOnlyHistoricalPartial' not in run)
    check('event/current-fresh-before-write',event_guard(core))
    mutants={
        'MC-CONT-EVENT-FRESHNESS-BYPASS':core.replace('!clock_authority.CurrentFreshObservation(event_clock)','false'),
        'MC-CONT-NEW-ACK-BYPASS':core.replace('!i.acknowledged ||','false ||'),
        'MC-CONT-PROFILE-EVENT-BYPASS':core.replace('at<event_clock.observed_at','false'),
        'MC-CONT-CLOCK-PAYLOAD-BYPASS':core.replace('stored_payload!=event_payload','false')}
    for name,mutant in mutants.items():check(name,not event_guard(mutant),'STATIC_MUTATION_CONTROL_NOT_MQL_EXECUTION')
    check('fixtures/old-event-negative-detects-ready-hook',all(x in suite for x in ('RESUME_CLOCK_OLD_EVENT_CANNOT_MUTATE_MC_EVENT_FRESHNESS',
          'CONTINUATION_NEW_ATTENDED_EVENT_FRESHNESS_REQUIRED','test_fired_stop_stage==""','SameRows(before,after)')))
    check('fixtures/clock-restart-lifecycle',all(x in suite for x in ('reopened.ConfigureReadOnly','!reopened.CurrentFreshObservation(fresh)',
          'ClassifyClockOnlyHistoricalPartial','RESUME_CLOCK_NO_NEW_ACK_ZERO_PUBLICATION','RESUME_CLOCK_NEW_ACK_LATER_TICK_NEW_CLOCK_COMPLETE')))
    check('fixtures/periodic-not-fabricated-live-time',all(x in suite for x in ('PERIODIC_EPOCH_1_ACTUAL_CONTINUATION_REQUIRED',
          'TEST_ONLY_PERIODIC_MODEL_CLOCK_ADVANCE','PERIODIC_EPOCH_2_EXPIRED_STRUCTURAL_NO_GRANT_NO_RECONSTRUCTED_FRESHNESS',
          'PERIODIC_EPOCH_2_NEW_EVENT_REQUIRED','PERIODIC_EPOCH_2_MAY_BEGIN_MODEL_ONLY_NO_AUTHORITY_MUTATION')))
    check('fixtures/clock-negative-cold-classifier','STORED_CLOCK_STRUCTURAL_NEGATIVE_' in suite and 'ZERO_TIME' in suite and
          'CLOCK_FOREIGN_PROFILE_SELF_CONSISTENT_ENCODING' in suite and 'CLOCK_NEGATIVE_FUTURE_TIME_NO_PUBLICATION' in suite)
    check('fixtures/boundary-differential-preserved',clock_model.boundary_guard(SUITE.read_text(encoding='utf-8-sig')))
    owner=OWNER.read_text(encoding='utf-8-sig');head=subprocess.check_output(['git','show','HEAD:'+OWNER.relative_to(ROOT).as_posix()],cwd=ROOT,text=True)
    for name in ('LoadVerified','CurrentFreshObservation','ObserveAcceptedEvent','ObserveFromCurrentSymbolOnTick'):
        check('clock/ordinary-unchanged/'+name,diagnostic.function(diagnostic.clean(owner),name)==diagnostic.function(diagnostic.clean(head),name))
    wrapper=diagnostic.clean(WRAPPER.read_text(encoding='utf-8-sig'));tick=diagnostic.function(wrapper,'OnTick')
    initial=tick[tick.index('if(!g_ack || g_consumed'):]
    publisher=diagnostic.function(wrapper,'PublishAcceptedContinuationTick')
    check('wrapper/actual-A-consumed-before-publication',initial.index('g_consumed=true; g_ack=false;')<initial.index('PublishAcceptedContinuationTick') and
          publisher.count('ObserveFromCurrentSymbolOnTick')==1)
    check('wrapper/structure-then-new-event-binding',initial.index('ClassifyStoredPreState')<initial.index('PublishAcceptedContinuationTick')<initial.index('CurrentFreshObservation')<initial.index('continuation.Run'))
    check('architecture/no-checkpoint-or-R-plus',not re.search(r'MVP_CONTINUATION_CLOCK_CHECKPOINT|MvpContinuationClockCheckpoint|CONTINUATION_WRITE_AHEAD_INTENT',s))
    # Actual previously executed native evidence, lossless snapshots (read only).
    prefix=COMMON/diagnostic.TARGET;before_file=Path(str(prefix)+'.before.rows');after_file=Path(str(prefix)+'.after.rows');classified_file=Path(str(prefix)+'.classified.rows')
    before=clock_rows(before_file);after=clock_rows(after_file);classified=clock_rows(classified_file)
    key=('MVP_OWNERSHIP_LEASE','LEASE_CLOCK_CURRENT');changed=[k for k in before if before[k]!=after.get(k)]
    old=gov.decode(before[key]['payload']);new=gov.decode(after[key]['payload'])
    check('native-diagnostic/clock-only-snapshots',set(before)==set(after)==set(classified) and changed==[key] and after==classified,'ACTUAL_PRIOR_NATIVE_SNAPSHOT')
    check('native-diagnostic/sequence-plus-one',new['clock_sequence']==old['clock_sequence']+1 and new['observed_at']>old['observed_at'],'ACTUAL_PRIOR_NATIVE_SNAPSHOT')
    log=diagnostic.DATA/'MQL5/Logs/20261013.log';text=log.read_text(encoding='utf-16');lines=[l for l in text.splitlines() if 'RESUME_CLOCK_DIAGNOSTIC|' in l]
    check('native-diagnostic/exact-cold-failure',all(x in '\n'.join(lines) for x in ('INTERRUPT_AFTER_CLOCK_PUBLICATION','required=true|actual=false',
          'reason=PRESTATE_CLOCK_EVENT_LOCAL_FRESHNESS_MISSING','freshness_reconstructed=false|second_publication=false',
          'COMPLETE|fixture_valid=true|forbidden_transport_calls=0')),'ACTUAL_PRIOR_NATIVE_LOG_NOT_POST_FIX_EXECUTION')
    # Independent clock oracle, not MQL. Profile exactness supplements the
    # unchanged physical LoadVerified reference; no original-clock baseline.
    def accepts(row):
        c=gov.decode(row['payload']);c.pop('physical_format',None)
        return clock_model.ordinary(row,c) and all(c[k]==new[k] for k in ('clock_id','broker_identity','server','account_login','source_symbol','clock_authority'))
    cases=[('valid-cold',deepcopy(after[key]),True)]
    for label,field,value in [('wrong-id','clock_id','WRONG'),('wrong-broker','broker_identity','FOREIGN'),('wrong-server','server','FOREIGN'),
                             ('wrong-account','account_login',new['account_login']+1),('wrong-symbol','source_symbol','OTHER'),
                             ('wrong-authority','clock_authority',0),('zero-sequence','clock_sequence',0),('zero-time','observed_at',0)]:
        row=deepcopy(after[key]);row['payload']=gov.update(row['payload'],{field:value});row['payload_digest']=gov.digest(key[0],row['payload']);row['store_revision']=gov.token(row)
        cases.append((label,row,False))
    for label in ('malformed','wrong-digest','wrong-store-revision','wrong-sequence-relation'):
        row=deepcopy(after[key])
        if label=='malformed':row['payload']+='!'
        if label=='wrong-digest':row['payload_digest']='0'*64
        if label=='wrong-store-revision':row['store_revision']='0'*64
        if label=='wrong-sequence-relation':row['logical_revision']+=1;row['store_revision']=gov.token(row)
        cases.append((label,row,False))
    for label,row,wanted in cases:
        try:actual=accepts(row)
        except (ValueError,KeyError):actual=False
        check('python-clock-oracle/'+label,actual==wanted,'INDEPENDENT_PYTHON_ORACLE_NOT_MQL_EXECUTION')
    # Keep existing full offline Governance/CAS/alias model checks; record its
    # intentionally stale full-native-build provenance gate separately.
    gov.checks.clear();buffer=io.StringIO()
    with contextlib.redirect_stdout(buffer):gov.main()
    previous=json.loads(buffer.getvalue());held='PROVENANCE/compiled-not-older-than-includes'
    for item in previous['checks']:
        if item['id']==held:continue
        check('governance-regression/'+item['id'],item['passed'],item['evidence_class'])
    build_gates=[x for x in previous['checks'] if x['id']==held]
    compiles={}
    for name in ('SW_V5_S5_MVP_ATTENDED_AUTHORITY_CONTINUATION','SW_V5_S5_MVP_CONTINUATION_ASSERTIONS'):
        path=HERE/(name+'.log');result=re.findall('^Result:.*',path.read_text(encoding='utf-16'),re.M)[-1]
        check('compile/'+name,'0 errors, 0 warnings' in result and "cpu='X64 Regular'" in result and
              all(path.stat().st_mtime>=p.stat().st_mtime for p in (CORE,SUITE,WRAPPER)),'METAEDITOR_COMPILE_NOT_EXECUTION')
        compiles[name]=dict(result=result,ex5_sha256=sha(HERE/(name+'.ex5')))
    # Fusion now authorizes the rebuilt full native harness, not the earlier
    # diagnostic-phase HOLD of B7. Require the real installed/current match.
    check('native-full/installed-current-binary',sha(diagnostic.OLD)==sha(HERE/'SW_V5_S5_MVP_CONTINUATION_NATIVE_COPY_ASSERTIONS.ex5') and
          sha(diagnostic.OLD)!=diagnostic.OLD_HASH,'READ_ONLY_FILE_HASH')
    check('db/original-donor-unchanged',hashes=={str(p):sha(p) for p in (diagnostic.ORIGINAL,diagnostic.DONOR)} and all(h==diagnostic.EXPECTED for h in hashes.values()),'READ_ONLY_FILE_HASH')
    check('git/diff-check',subprocess.run(['git','diff','--check'],cwd=ROOT,capture_output=True).returncode==0,'GIT')
    print(json.dumps(dict(classification='SOURCE_FIX_COMPILED_EXECUTION_GATES_OPEN',checks=checks,
          summary=dict(total=len(checks),passed=sum(c['passed'] for c in checks),failed=sum(not c['passed'] for c in checks),post_fix_MQL_executions=0),
          historical_native_diagnostic=dict(clock_before=old['clock_sequence'],clock_after=new['clock_sequence'],
              changed_domains=[k[0] for k in changed],before_sha256=sha(before_file),after_sha256=sha(after_file),classified_sha256=sha(classified_file),
              raw_experts_sha256=sha(log),predicate='PRESTATE_CLOCK_EVENT_LOCAL_FRESHNESS_MISSING'),
          full_governance_regression_summary=previous['summary'],held_full_native_build_gates=build_gates,compiles=compiles,
          original_donor_sha256=hashes,governance_source_sha256=sha(gov.GOV),
          current_sources={str(p.relative_to(ROOT)):sha(p) for p in (CORE,OWNER,SUITE,WRAPPER)},verifier_sha256=sha(Path(__file__)),
          native_rebuild_install=False,option_R_baseline_relaxation=False,
          open_gates=['Expanded RESUME_CLOCK MQL lifecycle','Boundary exact interruption + actual differential',
              'Governance alias MQL regressions','Periodic MQL structural fixture','Clock-negative MQL execution',
              'Full continuation execution','Full-native rebuild/install/new preset/pre-run gate']),indent=2))
    return int(any(not c['passed'] for c in checks))
if __name__=='__main__':raise SystemExit(main())
