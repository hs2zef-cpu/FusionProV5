"""TEST ONLY: read-only physical triage and offline model/source assertions.

Never starts MT5, installs a binary, opens a deployment DB for write, or grants
clock-resume authority. No MQL execution result is inferred from these checks.
"""
from pathlib import Path
from copy import deepcopy
import contextlib
import hashlib
import io
import json
import re
import sqlite3
import subprocess
import uuid
import verify_governance_refresh as governance
from verify_native_copy_prerun import ROOT, HERE, COMMON, COPY, ORIGINAL, EXPECTED, DATA, decode, digest, function, clean

KEY = ('MVP_OWNERSHIP_LEASE','LEASE_CLOCK_CURRENT')
SUITE = HERE/'SW_V5_S5_MvpContinuationAssertions.mqh'
CORE = ROOT/'FusionProV5/ExecutionLayer/RuntimeAuthority/SW_V5_S5_MvpAttendedContinuation.mqh'
OLD_EXECUTED = 'B70132E9D5BA2CF2882971FBAD5DA1DD2D752A9FF83E1529FD00891DE1557C09'
checks=[]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def check(name, value, kind):
    checks.append(dict(id=name,passed=bool(value),evidence_class=kind))


def rows(path):
    wal=Path(str(path)+'-wal')
    if wal.exists() and wal.stat().st_size:
        raise RuntimeError('Uncheckpointed WAL: cannot inspect immutable main file as complete evidence')
    c=sqlite3.connect(path.as_uri()+'?mode=ro&immutable=1',uri=True)
    c.row_factory=sqlite3.Row;c.execute('PRAGMA query_only=ON')
    try:
        return {(r['domain_key'],r['record_key']):dict(r) for r in c.execute('SELECT * FROM swv5_authority_rows ORDER BY domain_key,record_key')}
    finally:
        c.close()


def clock_only(prior, current):
    """Independent exact-row comparison; not production resume authorization."""
    if set(prior)!=set(current) or KEY not in prior:return False
    if any(prior[k]!=current[k] for k in prior if k!=KEY):return False
    try:
        old,new=decode(prior[KEY]['payload']),decode(current[KEY]['payload'])
        stable=('clock_id','clock_authority','broker_identity','server','account_login','source_symbol','source','physical_format')
        if any(old[k]!=new[k] for k in stable):return False
        row=current[KEY]
        return (new['source_symbol']=='XAUUSD' and new['source']==1 and new['clock_authority']==1 and
                new['clock_sequence']>old['clock_sequence'] and new['observed_at']>=old['observed_at'] and
                new['platform_observation_id'] and new['platform_observation_id']!=old['platform_observation_id'] and
                row['logical_revision']==new['clock_sequence'] and row['state']==1 and row['updated_at']==new['observed_at'] and
                row['payload_digest']==digest(KEY[0],row['payload']) and row['store_revision']==governance.token(row))
    except (KeyError, ValueError):
        return False


def main():
    previous_checks=deepcopy(governance.checks)
    before={str(p):sha(p) for p in (ORIGINAL,COPY)}
    source=clean(CORE.read_text(encoding='utf-8-sig'));suite=clean(SUITE.read_text(encoding='utf-8-sig'))
    check('preserve/governance-alias-and-ordinary-expiry',governance.source_guard(governance.GOV.read_text(encoding='utf-8-sig'),CORE.read_text(encoding='utf-8-sig')),'STATIC_SOURCE')
    execute=function(suite,'Execute');resume=function(suite,'Resume');boundary=function(suite,'ReleaseBoundaryMutation');clock_check=function(suite,'ClockOnlyPartial')
    check('mql/alias-and-distinct-regressions-present',all(x in suite for x in ('GovernanceClockBinding(false);GovernanceClockBinding(true);','GOV_CLOCK_EXACT_ACCEPTED_EVENT_REFRESH_DISTINCT_CAS','GOV_CLOCK_EXACT_ACCEPTED_EVENT_REFRESH_ALIASED_CAS')),'STATIC_MQL_TEST_LOGIC_NOT_EXECUTION')
    check('mql/partial-stage-is-exact-not-any-failure','result.reason=="PARTIAL_CONTINUATION/TEST_INTERRUPTION_"+stage' in resume,'STATIC_MQL_TEST_LOGIC_NOT_EXECUTION')
    check('mql/clock-other-rows-exact','else if(!SWV5S5_MvpContinuationRowExact(prior[x],current[x]))return false;' in clock_check and 'return changes==1;' in clock_check,'STATIC_MQL_TEST_LOGIC_NOT_EXECUTION')
    check('mql/clock-load-readonly-physical-proof','authority.ConfigureReadOnly(path,m_ns)' in clock_check and 'authority.LoadStored(verified,row,found)' in clock_check,'STATIC_MQL_TEST_LOGIC_NOT_EXECUTION')
    check('mql/boundary-exact-intended-interruption','r.reason=="PARTIAL_CONTINUATION/TEST_INTERRUPTION_"+test_stop_stage' in boundary,'STATIC_MQL_TEST_LOGIC_NOT_EXECUTION')
    check('mql/boundary-binding-valid-before-mutation','Check(ready,"BOUNDARY_INTENDED_STAGE_AND_FRESH_BINDING_PROVEN")' in boundary and boundary.index('if(!ready)return;')<boundary.index('const bool mutated='),'STATIC_MQL_TEST_LOGIC_NOT_EXECUTION')
    check('mql/boundary-validity-not-destroyed','governance.payload,governance.updated_at,changed)' in boundary and 'governance_owner.Load(context.clock_time' in boundary,'STATIC_MQL_TEST_LOGIC_NOT_EXECUTION')
    check('mql/boundary-only-one-valid-row-changes','changed_count==1' in boundary and 'SWV5S5_MvpContinuationPhysicalInvariants(store,context,flat)' in boundary,'STATIC_MQL_TEST_LOGIC_NOT_EXECUTION')
    check('mql/boundary-reason-is-stale-binding','BOUNDARY_STALE_AUTHORITY_NOT_GOVERNANCE_INVALIDITY' in boundary and 'STALE_BOUND_AUTHORITY' in boundary,'STATIC_MQL_TEST_LOGIC_NOT_EXECUTION')
    check('runtime/no-profile-clock-tolerance-added','if(at!=clock.observed_at)' in source and 'PROFILE_EVENT_TIME' in source,'STATIC_SOURCE')
    check('runtime/exact-first-prestate-boundary-reported',all('"'+x+'"' in source for x in ('FRESH_ACCEPTED_CLOCK','OPERATOR_EVENT','PROFILE_CAPTURE','OWNERSHIP_PHYSICAL','TRUST_PHYSICAL','ACCOUNT_PHYSICAL_PROFILE','GOVERNANCE_STRUCTURAL','HARD_KILL_PHYSICAL')),'STATIC_SOURCE')
    base=rows(COPY);physical=[]
    for suffix in ('.RESUME_CLOCK.sqlite','.BOUND_PENDING.sqlite'):
        path=Path(str(COPY)+suffix);current=rows(path);old,new=decode(base[KEY]['payload']),decode(current[KEY]['payload'])
        changes=[list(k) for k in base if current.get(k)!=base[k]]
        check('physical/'+suffix+'/only-clock-valid-advancement',clock_only(base,current),'READ_ONLY_EXISTING_NATIVE_SQLITE')
        for k in base:
            if k==KEY:continue
            bad=deepcopy(current);bad[k]['updated_at']+=1
            check('oracle/'+suffix+'/additional-mutation-rejected/'+k[0]+'/'+k[1],not clock_only(base,bad),'PYTHON_ORACLE_NOT_MQL_EXECUTION')
        for name,values in (('nonmonotonic-sequence',{'clock_sequence':old['clock_sequence']}),
                            ('nonmonotonic-time',{'observed_at':old['observed_at']-1}),
                            ('foreign-server',{'server':'FOREIGN'}),('foreign-symbol',{'source_symbol':'OTHER'})):
            bad=deepcopy(current);payload=governance.update(bad[KEY]['payload'],values);b=decode(payload)
            bad[KEY].update(payload=payload,payload_digest=digest(KEY[0],payload),logical_revision=b['clock_sequence'],updated_at=b['observed_at'])
            bad[KEY]['store_revision']=governance.token(bad[KEY])
            check('oracle/'+suffix+'/'+name+'-rejects',not clock_only(base,bad),'PYTHON_ORACLE_NOT_MQL_EXECUTION')
        physical.append(dict(path=str(path),sha256=sha(path),rows=len(current),changed_keys=changes,
                             previous_clock_sequence=old['clock_sequence'],clock_sequence=new['clock_sequence'],
                             previous_observed_at=old['observed_at'],observed_at=new['observed_at'],
                             all_other_authority_rows_exact=all(base[k]==current[k] for k in base if k!=KEY),
                             account_binding_unchanged=old['account_login']==new['account_login']))
    # A persisted clock alone does not provide the old complete-row snapshot or
    # a durable continuation stage. The current CLOCK injection is test memory.
    clock_hook=execute[execute.index('if(test_stop_stage=="CLOCK")'):execute.index('SWV5S5_MvpOperatorInvocation op;')]
    proof_gap=not re.search(r'\b(?:CompareAndSet\w*|Run|Persist\w*|Publish\w*)\s*\(',clock_hook)
    check('triage/clock-hook-has-no-durable-stage-record',proof_gap,'STATIC_SOURCE_GAP_CONFIRMED_NOT_A_PASS_FOR_RESUME')
    check('triage/resume-previously-published-second-clock',decode(rows(Path(str(COPY)+'.RESUME_CLOCK.sqlite'))[KEY]['payload'])['clock_sequence']==decode(base[KEY]['payload'])['clock_sequence']+2,'READ_ONLY_EXISTING_NATIVE_SQLITE')
    wrapper=(HERE/'SW_V5_S5_MVP_ATTENDED_AUTHORITY_CONTINUATION.mq5').read_text(encoding='utf-8-sig')
    check('event/fresh-A-consumed-before-publication',wrapper.index('g_consumed=true; g_ack=false;')<wrapper.index('clock.ObserveFromCurrentSymbolOnTick') and 'if(!g_ack || g_consumed' in wrapper,'STATIC_SOURCE')
    check('event/new-operator-time-bound-to-new-accepted-clock','op.authenticated_at=at.observed_at;' in execute and 'op.authenticated_at=accepted.observed_at;' in wrapper,'STATIC_SOURCE')
    # Execute all previous offline model/static checks without installing/running
    # anything. The old native build's age is deliberately reported as a gate.
    governance.checks.clear();buffer=io.StringIO()
    with contextlib.redirect_stdout(buffer):old_result=governance.main()
    prior_offline=json.loads(buffer.getvalue());governance.checks[:]=previous_checks
    pending=[x['id'] for x in prior_offline['checks'] if not x['passed']]
    compiled={}
    for name in ('SW_V5_S5_MVP_ATTENDED_AUTHORITY_CONTINUATION','SW_V5_S5_MVP_CONTINUATION_ASSERTIONS'):
        log=HERE/(name+'.log');result=re.findall(r'^Result:.*',log.read_text(encoding='utf-16'),flags=re.M)[-1]
        fresh=all(log.stat().st_mtime>=p.stat().st_mtime for p in (CORE,SUITE))
        check('compile/'+name,fresh and bool(re.fullmatch(r"Result: 0 errors, 0 warnings, .*cpu='X64 Regular'",result)),'METAEDITOR_COMPILE_NOT_MQL_EXECUTION')
        compiled[name]=dict(result=result,ex5_sha256=sha(HERE/(name+'.ex5')))
    installed=DATA/'MQL5/Experts/FusionProV5Tests/SW_V5_S5_MVP_CONTINUATION_NATIVE_COPY_ASSERTIONS.ex5'
    built=HERE/'SW_V5_S5_MVP_CONTINUATION_NATIVE_COPY_ASSERTIONS.ex5'
    check('hold/installed-native-binary-not-replaced',sha(installed)==OLD_EXECUTED,'READ_ONLY_BINARY_PROVENANCE')
    run_id=uuid.uuid4().hex;planned=COMMON/('TEST_ONLY_MVP_CONTINUATION_'+run_id+'.sqlite')
    check('plan/new-target-absent',not any(Path(str(planned)+s).exists() for s in ('','-wal','-shm')),'PLANNED_ONLY_NOT_CREATED')
    check('preserve/original-and-donor-exact',before=={str(p):sha(p) for p in (ORIGINAL,COPY)} and all(x==EXPECTED for x in before.values()),'READ_ONLY_FILE_HASH')
    diff=subprocess.run(['git','diff','--check'],cwd=ROOT,capture_output=True,text=True)
    check('git/diff-check',diff.returncode==0,'GIT')
    output=dict(evidence_class='NON_NATIVE_TRIAGE_ONLY_NO_MQL_EXECUTION_NO_NATIVE_INSTALL',
                verifier_sha256=sha(Path(__file__)),checks=checks,
                core_source_sha256=sha(CORE),assertion_source_sha256=sha(SUITE),governance_source_sha256=sha(governance.GOV),
                current_include_source_digest=prior_offline['source_isolation']['source_digest'],
                summary=dict(total=len(checks),passed=sum(x['passed'] for x in checks),failed=sum(not x['passed'] for x in checks),MQL_executions=0),
                physical_clock_only_evidence=physical,previous_offline_summary=prior_offline['summary'],previous_offline_pending=pending,
                non_native_compile=compiled,installed_native_sha256=sha(installed),repository_native_sha256=sha(built),
                native_build_current=False,native_install_authorized=False,original_and_donor_sha256=before,
                new_target_plan=dict(run_id=run_id,path=str(planned),created=False,preset_created=False),
                open_gates=['Exact original PRE_STATE failing predicate was not logged; diagnostics now preserve and report it.',
                            'No durable CLOCK partial-stage record or preserved complete prior snapshot exists in the deployed draft.',
                            'Real MQL CLOCK resume / ACTIVE-to-PENDING / PENDING-release assertions have not executed after correction.',
                            'Native rebuild/install/full pre-run gate are intentionally held until sections 1-6 are green.'])
    print(json.dumps(output,indent=2))
    return int(any(not x['passed'] for x in checks))


if __name__=='__main__':
    raise SystemExit(main())
