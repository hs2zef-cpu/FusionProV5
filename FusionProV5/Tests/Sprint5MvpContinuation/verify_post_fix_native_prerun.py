"""TEST ONLY full post-fix PRE-RUN audit. Never starts MT5 or executes an EA.
Existing original/donor files are hashed/read-only. No SQLite writes occur.
This stage explicitly supersedes the previous HOLD-old-native-binary assertion;
it instead REQUIRES a fresh installed binary, never waives source/provenance.
"""
from pathlib import Path
import contextlib, hashlib, io, json, re, subprocess
from datetime import datetime,timezone,timedelta
import verify_native_copy_prerun as prior
import verify_event_freshness_layering as layering
import verify_governance_refresh as governance

HERE=prior.HERE;ROOT=prior.ROOT;COMMON=prior.COMMON;DATA=prior.DATA
RUN='18ca78330eee422ba9751e6dca5e562e'
SEED=COMMON/('TEST_ONLY_MVP_CONTINUATION_'+RUN+'.sqlite')
DONOR=prior.COPY
PRESET=DATA/'MQL5/Presets'/(SEED.name+'.set')
EA=prior.EA
OLD='B70132E9D5BA2CF2882971FBAD5DA1DD2D752A9FF83E1529FD00891DE1557C09'
checks=[]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest().upper()
def check(name,ok,kind='STATIC_PRE_RUN_NOT_EXECUTION'):checks.append(dict(id=name,passed=bool(ok),evidence_class=kind))
def main():
    before={str(p):prior.db_artifact(p) for p in (prior.ORIGINAL,DONOR,SEED)}
    check('DB/original-hash',sha(prior.ORIGINAL)==prior.EXPECTED,'READ_ONLY_FILE_HASH')
    check('DB/donor-hash',sha(DONOR)==prior.EXPECTED,'READ_ONLY_FILE_HASH')
    check('DB/fresh-readonly-seed-identical',SEED!=DONOR and SEED!=prior.ORIGINAL and sha(SEED)==sha(DONOR),'READ_ONLY_FILE_HASH')
    check('DB/original-seed-no-sidecars',all(not Path(str(p)+s).exists() for p in (prior.ORIGINAL,SEED) for s in ('-wal','-shm')),'READ_ONLY_METADATA')
    wal=Path(str(DONOR)+'-wal');check('DB/donor-no-uncheckpointed-wal',not wal.exists() or wal.stat().st_size==0,'READ_ONLY_METADATA')
    check('RUN/new-guid-and-seed-name',bool(re.fullmatch('[0-9a-f]{32}',RUN)) and RUN in SEED.name and RUN not in DONOR.name)
    values=dict(l.split('=',1) for l in PRESET.read_text(encoding='utf-8-sig').splitlines() if '=' in l)
    expected=dict(explicit_test_only_marker='TEST_ONLY_AUTHORIZED_UNCOMMITTED_DRAFT',initial_copy_relative_path=SEED.name,
                  expected_initial_copy_sha256=prior.EXPECTED.lower(),execute_test_copy_once='true',operator_confirmed_test_copy='true')
    check('PRESET/exact-new-run-inputs',values==expected,'READ_ONLY_PRESET')
    check('PRESET/installed-identical',sha(PRESET)==sha(HERE/(SEED.name+'.set')),'READ_ONLY_FILE_HASH')
    source=HERE/(EA+'.mq5');built=HERE/(EA+'.ex5');installed=DATA/'MQL5/Experts/FusionProV5Tests'/(EA+'.ex5')
    code=prior.clean(source.read_text(encoding='utf-8-sig'))
    prior.checks.clear();refusal=prior.isolated_guard_tests(code)
    isolation=prior.source_safety(code,installed)
    for item in prior.checks:check(item['id'],item['passed'],'SOURCE_EXTRACTED_REFUSAL_AND_ISOLATION_NOT_MQL_EXECUTION')
    prior.checks.clear();prior_copy=prior.COPY
    try:
        prior.COPY=SEED;physical=prior.physical_prestate()
    finally:prior.COPY=prior_copy
    for item in prior.checks:check(item['id'],item['passed'],'READ_ONLY_IMMUTABLE_SEED')
    log=HERE/(EA+'.log');result=re.findall(r'^Result:.*',log.read_text(encoding='utf-16'),re.M)[-1]
    check('COMPILE/x64-regular-zero-errors-warnings',bool(re.fullmatch(r"Result: 0 errors, 0 warnings, .*cpu='X64 Regular'",result)),'METAEDITOR_COMPILE_NOT_EXECUTION')
    check('BINARY/compiled-installed-exact',sha(built)==sha(installed),'READ_ONLY_FILE_HASH')
    check('BINARY/different-from-old-executed',sha(built)!=OLD,'READ_ONLY_FILE_HASH')
    check('BINARY/compiled-after-manifest',built.stat().st_mtime>=source.stat().st_mtime,'READ_ONLY_METADATA')
    suite=prior.clean((HERE/'SW_V5_S5_MvpContinuationAssertions.mqh').read_text(encoding='utf-8-sig'))
    start=prior.function(suite,'Start');finish=prior.function(suite,'FinishLaterTick');clone=prior.function(suite,'Clone')
    check('COVERAGE/alias-and-distinct-in-entry', 'GovernanceClockBinding(false);GovernanceClockBinding(true);' in start)
    check('COVERAGE/boundary-control-and-mutation-in-entry','ReleaseBoundaryMutation(false);ReleaseBoundaryMutation(true);' in start and
          'ReleaseBoundaryCase(after_pending,false,control_basis)' in suite and 'ReleaseBoundaryCase(after_pending,true,mutated_basis)' in suite)
    check('COVERAGE/periodic-and-stored-clock-in-entry','PeriodicEpochStructural();' in start and 'ClockDiagnosticNegatives();' in start)
    check('COVERAGE/all-existing-partial-stages',all('"'+x+'"' in start for x in ('CLOCK','HEARTBEAT','TRUST','GOVERNANCE','ACTIVE','FLAT','PENDING','RELEASED','INACTIVE')) and 'Resume(stages[x]);' in start)
    check('COVERAGE/later-clock-new-attempt-and-preflight','RESUME_CLOCK_NEW_ACK_LATER_TICK_NEW_CLOCK_COMPLETE' in finish and
          'LATER_NATIVE_TICK_PREFLIGHT_COMPLETE_ZERO_SUBMISSION' in finish and 'TimeCurrent()<=m_clock_partial_time' in finish)
    check('COVERAGE/zero-transport-at-completion','Check(test_forbidden_transport_calls==0' in finish and 'test_forbidden_transport_calls' in prior.function(code,'OnTick'))
    check('ORIGIN/every-clone-fixed-hash-seed','SWV5S5_TestContinuationFileSha(m_copy,digest)' in clone and
          prior.EXPECTED.lower() in clone and 'FileCopy(m_copy,FILE_COMMON,name,FILE_COMMON)' in clone and suite.count('FileCopy(')==1)
    check('ORIGIN/preset-seed-configured-before-suite','test_suite.ConfigureCopy(initial_copy_relative_path)' in prior.function(code,'OnInit') and 'm_copy=path;' in suite)
    check('TARGET/never-overwrite-existing-clones','FileIsExist(name,FILE_COMMON)' in clone and 'FileIsExist(name+"-wal",FILE_COMMON)' in clone and
          'FileIsExist(name+"-shm",FILE_COMMON)' in clone and 'FILE_REWRITE' not in clone)
    # Existing source chooses the mutable prefix on the authorized native tick.
    # Do not invent a different preassigned MAIN path or modify MQL wiring.
    mutable_prefix='TEST_ONLY_MVP_CONTINUATION_RETEST_'
    existing_mutable=sorted(str(p) for p in COMMON.glob(mutable_prefix+'*'))
    check('TARGET/fresh-runtime-target-family-absent',not existing_mutable,'READ_ONLY_METADATA')
    check('TARGET/current-source-runtime-unique-prefix','m_run_prefix="'+mutable_prefix+'"+IntegerToString((long)TimeCurrent())+"_"+IntegerToString((long)GetMicrosecondCount())' in start)
    for suffix in ('.MAIN.sqlite','.PERIODIC.sqlite','.RESUME_CLOCK.sqlite','.BOUND_ACTIVE.sqlite','.BOUND_PENDING.sqlite'):
        check('TARGET/no-old-seed-target/'+suffix,not Path(str(SEED)+suffix).exists(),'READ_ONLY_METADATA')
    # Current source must match the exact already-reviewed layering patch.
    freeze=json.loads((HERE/'EVENT_FRESHNESS_LAYERING_EVIDENCE.json').read_text())
    for name,wanted in freeze['current_sources'].items():
        check('SOURCE/no-MQL-change/'+Path(name).name,sha(ROOT/name)==wanted,'READ_ONLY_SOURCE_HASH')
    # Repeat all prior source/oracle/isolation checks, recording the one old
    # workflow expectation superseded by this explicit build/install request.
    layering.checks.clear();buf=io.StringIO()
    with contextlib.redirect_stdout(buf):layering.main()
    current=json.loads(buf.getvalue());superseded=[]
    for item in current['checks']:
        if item['id']=='native-full/old-install-held':
            superseded.append(item|{'reason':'Fusion now explicitly requires new matching installed EX5, checked above.'});continue
        check('REGRESSION/'+item['id'],item['passed'],item['evidence_class'])
    check('PROVENANCE/formerly-stale-native-gate-now-pass',bool(current['held_full_native_build_gates']) and
          all(c['passed'] for c in current['held_full_native_build_gates']),'CURRENT_SOURCE_PROVENANCE')
    check('REGRESSION/governance-all-54-pass',current['full_governance_regression_summary']['passed']==54 and
          current['full_governance_regression_summary']['failed']==0,'STATIC_AND_PYTHON_ORACLE_NOT_MQL_EXECUTION')
    check('DB/all-before-after-identical',before=={str(p):prior.db_artifact(p) for p in (prior.ORIGINAL,DONOR,SEED)},'READ_ONLY_FILE_HASH')
    check('GIT/diff-check',subprocess.run(['git','diff','--check'],cwd=ROOT,capture_output=True).returncode==0,'GIT')
    git={k:subprocess.check_output(['git',*args],cwd=ROOT,text=True).strip() for k,args in
         [('branch',['branch','--show-current']),('HEAD',['rev-parse','HEAD']),('tree',['rev-parse','HEAD^{tree}']),
          ('main',['rev-parse','main']),('status',['status','--short'])]}
    check('GIT/canonical-branch-head',git['branch']=='sprint5-phase-f-entry-contract' and git['HEAD']=='d926f2e6b1aa4ea7b4b0936293d2fa47a2ce7ba8','GIT')
    check('GIT/main-unchanged',git['main']=='32b79ca71ffc331e15e48a57c52be1352e3dbe7e','GIT')
    print(json.dumps(dict(classification='FULL_POST_FIX_PRE_RUN_ONLY_NOT_EXECUTED',time_bangkok=datetime.now(timezone(timedelta(hours=7))).isoformat(),
          checks=checks,summary=dict(total=len(checks),passed=sum(c['passed'] for c in checks),failed=sum(not c['passed'] for c in checks),post_fix_native_executions=0),
          run_id=RUN,fixture_inputs=values,preset=prior.artifact(PRESET),seed=prior.artifact(SEED),
          mutable_target_pattern=str(COMMON/(mutable_prefix+'<native_time>_<counter>.MAIN.sqlite')),
          mutable_target_family_existing_files=existing_mutable,mutable_target_name_note='Exact runtime name emitted by CONTINUATION_COPY_PATH after A; seed is read-only.',
          source=prior.artifact(source),compiled=prior.artifact(built),installed=prior.artifact(installed),compile_result=result,
          prestate=physical,refusal=refusal,isolation=isolation,database_before=before,
          regressions=dict(active_layering_checks=101,governance=current['full_governance_regression_summary'],
             formerly_stale_gate=current['held_full_native_build_gates'],superseded_old_hold=superseded),
          git=git,verifier_sha256=sha(Path(__file__))),indent=2))
    return int(any(not c['passed'] for c in checks))
if __name__=='__main__':raise SystemExit(main())
