"""TEST ONLY / NO MT5 / NO BROKER ACCESS.

Read-only native failure triage plus static mutation controls and an independent
Python/SQLite in-memory oracle. These are NOT post-fix MQL execution results.
No production DB is opened for write; no existing mutable clone is reused.
"""
from pathlib import Path
from copy import deepcopy
import hashlib
import json
import re
import sqlite3
import subprocess
from verify_native_copy_prerun import ROOT, HERE, COMMON, COPY, ORIGINAL, EXPECTED, NAMESPACE, decode, field, digest, function, clean
import verify_native_copy_prerun as prerun

GOV = ROOT / 'FusionProV5/ExecutionLayer/RuntimeAuthority/SW_V5_S5_MvpReconciliationGovernanceAuthorities.mqh'
CORE = ROOT / 'FusionProV5/ExecutionLayer/RuntimeAuthority/SW_V5_S5_MvpAttendedContinuation.mqh'
EXPERTS = Path(r'C:\Users\Nutthakrit\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Logs\20261013.log')
JOURNAL = EXPERTS.parents[2] / 'logs/20261013.log'
DOMAIN = 'MVP_RECONCILIATION_GOVERNANCE_BUNDLE'
BDOMAIN = 'SWV5-S5-MVP-RECONCILIATION-GOVERNANCE-V1'
checks = []


def check(name, value, category):
    checks.append(dict(id=name, passed=bool(value), evidence_class=category))


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def raw_fields(payload):
    raw = payload.encode(); offset = 0; result = []
    while offset < len(raw):
        parts = []
        for _ in range(3):
            end = raw.index(b':', offset); parts.append(raw[offset:end].decode()); offset = end + 1
        name, token, length = parts; size = int(length)
        if str(size) != length or size < 0 or offset + size > len(raw):
            raise ValueError('Non-canonical field')
        result.append((name, token, raw[offset:offset + size].decode())); offset += size
    if len({n for n, _, _ in result}) != len(result):
        raise ValueError('Duplicate field')
    return result


def update(payload, values=None, remove=(), rename=None):
    values = values or {}; rename = rename or {}
    return ''.join(field(rename.get(n, n), t, values.get(n, v)) for n, t, v in raw_fields(payload) if n not in remove)


def nested(payload, key):
    return next(v for n, t, v in raw_fields(payload) if n == key and t == 'x')


POLICY_NAMES = {
    'correlation': {'order_identity': 'broker_order_identity_required', 'deal_order': 'deal_order_link_required',
                    'position_link': 'position_identifier_link_required', 'ordered_deals': 'ordered_deal_set_required',
                    'magic_scope': 'magic_is_strategy_scope_only', 'comment_non_authoritative': 'comment_is_non_authoritative'},
    'capability': {'correlation': 'correlation_capability', 'query_complete': 'query_completeness',
                   'visibility': 'visibility_watermark', 'visibility_lag': 'visibility_lag_seconds'},
    'negative': {'capability_id': 'capability_proof_id', 'capability_version': 'capability_proof_version',
                 'capability_digest': 'capability_proof_digest', 'visibility_lag': 'visibility_lag_seconds'}}
PDOMAINS = {'correlation': 'SWV5-SPRINT5-PHASE-F-CORRELATION-POLICY-V1',
            'capability': 'SWV5-SPRINT5-PHASE-F-CAPABILITY-PROOF-V1',
            'negative': 'SWV5-SPRINT5-PHASE-F-NEGATIVE-POLICY-V1'}


def policy_digest(payload, name):
    return digest(PDOMAINS[name], update(payload, remove=('version', 'digest'), rename=POLICY_NAMES[name]))


def profile_digest(payload):
    scope=nested(payload,'namespace'); s=decode(scope)
    canonical_scope=(field('version','x',nested(scope,'contract_version')) +
                     field('ownership_namespace','x',nested(scope,'ownership_namespace')) +
                     field('basket_id','s',s['basket_id']['value']))
    account=update(nested(payload,'account'),rename={'contract_version':'version'})
    body=update(payload,{'namespace':canonical_scope,'account':account},remove=('version','profile_digest'),
                rename={'namespace':'persistence_namespace','account':'account_namespace','broker':'broker_identity','login':'account_login'})
    return digest('SWV5-SPRINT5-PHASE-F-P-BROKER-PROFILE-V1',body)


def seal(payload):
    for name in ('correlation', 'capability', 'negative'):
        p = nested(payload, name)
        if name == 'negative':
            p = update(p, {'capability_digest': decode(nested(payload, 'capability'))['digest']})
        p = update(p, {'digest': policy_digest(p, name)})
        payload = update(payload, {name: p})
    return update(payload, {'bundle_digest': digest(BDOMAIN, update(payload, remove=('bundle_digest',)))})


def token(row):
    body = (field('namespace_digest', 's', NAMESPACE) + field('domain_key', 's', row['domain_key']) +
            field('record_key', 's', row['record_key']) + field('logical_revision', 'u', row['logical_revision']) +
            field('payload_digest', 's', row['payload_digest']))
    return digest('SWV5-S5-MVP-STORE-REVISION-V1', body)


def structural(row, expected_profile, approval, proof):
    """Independent oracle: old expiry is not current eligibility."""
    try:
        b = decode(row['payload']); c, p, n = b['correlation'], b['capability'], b['negative']
        production = {'contract_name': 'SWV5-PRODUCTION', 'schema_version': 5, 'minimum_compatible_version': 5, 'policy_id': 'SWV5-PRODUCTION-V5'}
        phase_f = {'contract_name': 'SWV5-SPRINT5-PHASE-F-RECONCILIATION', 'schema_version': 1,
                   'minimum_compatible_version': 1, 'policy_id': 'SWV5-SPRINT5-PHASE-F-ENTRY-V1'}
        if row['state'] != 1 or not 0 < row['logical_revision'] < 2**64-1 or row['store_revision'] != token(row): return False
        if b['version'] != production or any(x['version'] != phase_f for x in (b['profile'], c, p, n)): return False
        if nested(row['payload'], 'profile') != expected_profile or b['valid_from'] <= 0 or b['valid_until'] <= b['valid_from']: return False
        if profile_digest(expected_profile)!=b['profile']['profile_digest']: return False
        if c['policy_id']!='SWV5-SPRINT5-BROKER-CORRELATION-PROOF-V1' or n['policy_id']!='SWV5-SPRINT5-AUTHORITATIVE-NEGATIVE-EVIDENCE-V1': return False
        if p['artifact_id']!='SWV5-SPRINT5-INDEPENDENT-QUERY-CAPABILITY-PROOF-V1': return False
        if row['updated_at'] != b['valid_from'] or row['payload_digest'] != b['bundle_digest']: return False
        if digest(BDOMAIN, update(row['payload'], remove=('bundle_digest',))) != b['bundle_digest']: return False
        if any(policy_digest(nested(row['payload'], name), name) != b[name]['digest'] for name in PDOMAINS): return False
        if any(x['approval_reference'] != approval or x['issuing_component'] != 5 or x['authority_source'] != 6 for x in (c,p,n)): return False
        if any(x['profile_id'] != b['profile']['profile_id'] or x['profile_digest'] != b['profile']['profile_digest'] for x in (c,p,n)): return False
        if c['policy_version'] != 1 or n['policy_version'] != 1 or p['artifact_version'] != 1: return False
        if not all(c[x] for x in ('order_identity','deal_order','position_link','ordered_deals','magic_scope','comment_non_authoritative')): return False
        if p['proof_source_reference'] != proof or not p['correlation'] or p['query_complete'] or p['visibility'] or p['visibility_lag'] != 0: return False
        if any(x['approved_at'] != b['valid_from'] for x in (c,p,n)) or b['operator']['authenticated_at'] != b['valid_from']: return False
        if p['valid_from'] != b['valid_from'] or p['valid_until'] != b['valid_until']: return False
        if n['capability_id'] != p['artifact_id'] or n['capability_version'] != p['artifact_version'] or n['capability_digest'] != p['digest']: return False
        if any(n[k] != v for k,v in {'broker_flags':15,'execution_flags':16,'stable_observations':2,'stability_seconds':1,
                                     'visibility_lag':0,'connection_generation':1,'restart_generation':1}.items()): return False
        identity = field('profile','s',b['profile']['profile_digest']) + field('approval','s',approval) + field('sequence','u',b['sequence'])
        return b['sequence'] > 0 and b['bundle_id'] == 'MVP-RECONCILIATION-GOVERNANCE-' + digest(BDOMAIN+'-ID',identity)
    except (ValueError, KeyError, StopIteration):
        return False


def source_guard(source, core):
    s = clean(source); private = s.index('bool LoadCurrentStructural(')
    refresh = function(s, 'RefreshCurrent'); ordinary = function(s, 'Load')
    head = subprocess.check_output(['git','show','HEAD:'+str(GOV.relative_to(ROOT)).replace('\\','/')],cwd=ROOT,text=True)
    return (s.rfind('private:',0,private) > s.rfind('public:',0,private) and
            len(re.findall(r'\bLoadCurrentStructural\s*\(',s)) == 2 and
            'LoadCurrentStructural(profile,approval,proof,current,row)' in refresh and
            'LoadCurrentStructural' not in ordinary and ordinary == function(clean(head),'Load') and
            function(s,'SWV5S5_MvpGovernanceValid') == function(clean(head),'SWV5S5_MvpGovernanceValid') and
            'prior_expected_row=expected_row' in refresh and
            refresh.index('prior_expected_row=expected_row') < refresh.index('ZeroMemory(committed)') and
            all('row.'+f+'!=prior_expected_row.'+f in refresh for f in ('logical_revision','store_revision','payload_digest','state','payload','updated_at','domain_key','record_key')) and
            'CompareAndSetWithGuard(' in refresh and 'return Load(clock.observed_at,profile,verified,readback,found)' in refresh and
            'readback.logical_revision==row.logical_revision+1' in refresh and
            len(re.findall(r'\.RefreshCurrent\s*\(',clean(core))) == 1)


def main():
    before = {str(p):sha(p) for p in (ORIGINAL,COPY)}
    check('fixture/immutable-and-original-hash', all(x==EXPECTED for x in before.values()), 'READ_ONLY_PHYSICAL')
    check('fixture/no-uncheckpointed-wal', all(not Path(str(p)+'-wal').exists() or Path(str(p)+'-wal').stat().st_size==0 for p in (ORIGINAL,COPY)), 'READ_ONLY_PHYSICAL')
    source = GOV.read_text(encoding='utf-8-sig'); core = CORE.read_text(encoding='utf-8-sig')
    prerun.checks.clear()
    harness=clean((HERE/'SW_V5_S5_MVP_CONTINUATION_NATIVE_COPY_ASSERTIONS.mq5').read_text(encoding='utf-8-sig'))
    refusal=prerun.isolated_guard_tests(harness)
    # Audit the new REPOSITORY build, not the still-installed pre-fix binary.
    isolation=prerun.source_safety(harness,HERE/'SW_V5_S5_MVP_CONTINUATION_NATIVE_COPY_ASSERTIONS.ex5')
    for item in prerun.checks:
        check(item['id'],item['passed'],'SOURCE_ISOLATION_AND_EXTRACTED_GUARD_NOT_MQL_EXECUTION')
    check('static/private-structural-single-refresh-caller-and-ordinary-unchanged',source_guard(source,core),'STATIC_SOURCE')
    mutants = {
        'MC-GOV-EXPIRED-ELIGIBILITY-BYPASS':source.replace('SWV5S5_MvpGovernanceValid(bundle,now)', 'LoadCurrentStructural(expected,"approval","proof",bundle,row)'),
        'MC-GOV-STRUCTURAL-PUBLIC':source.replace('private:\n   SWV5S5_MvpSqliteAuthorityStore m_store;', 'public:\n   SWV5S5_MvpSqliteAuthorityStore m_store;',1),
        'MC-GOV-PRIOR-ALIAS':source.replace('const SWV5S5_MvpAuthorityRow prior_expected_row=expected_row;', 'SWV5S5_MvpAuthorityRow prior_expected_row;'),
        'MC-GOV-CAS-BYPASS':source.replace('row.store_revision!=prior_expected_row.store_revision','false'),
        'MC-GOV-READBACK-BYPASS':source.replace('return Load(clock.observed_at,profile,verified,readback,found)', 'return true')}
    for name, mutant in mutants.items():
        check(name, not source_guard(mutant,core), 'STATIC_MUTATION_CONTROL_NOT_MQL_MUTANT_EXECUTION')
    # Source-exact reference alias mechanics: the production caller used row twice.
    row = {'logical_revision':1,'store_revision':'nonempty'}; aliased = row
    row.clear()
    check('alias/old-output-clear-destroys-prior-CAS',aliased.get('logical_revision',0)==0,'REFERENCE_ALIAS_MODEL')
    row = {'logical_revision':1,'store_revision':'nonempty'}; preserved = deepcopy(row); row.clear()
    check('alias/copied-prior-survives-output-clear',preserved['logical_revision']==1,'REFERENCE_ALIAS_MODEL')
    # Logical copy from the hash-checked immutable donor into private memory.
    # A serialized WAL-header database cannot be deserialized as a fileless WAL
    # database; the native SQLite backup API avoids editing that header/donor.
    donor = sqlite3.connect(COPY.as_uri()+'?mode=ro&immutable=1',uri=True)
    donor.execute('PRAGMA query_only=ON')
    db = sqlite3.connect(':memory:'); donor.backup(db); donor.close(); db.row_factory=sqlite3.Row
    original_rows = [dict(x) for x in db.execute('SELECT * FROM swv5_authority_rows ORDER BY domain_key,record_key')]
    prior = next(x for x in original_rows if x['domain_key']==DOMAIN and x['record_key']=='CURRENT')
    b=decode(prior['payload']); profile=nested(prior['payload'],'profile'); approval=b['correlation']['approval_reference']; proof=b['capability']['proof_source_reference']
    at=1791882921
    check('oracle/expired-prior-structural-read',structural(prior,profile,approval,proof) and b['valid_until']==1791817607 and b['valid_until']<at,'PYTHON_SQLITE_ORACLE_NOT_MQL_EXECUTION')
    check('oracle/ordinary-expired-ineligible',not (b['valid_from']<=at<b['valid_until']),'PYTHON_SQLITE_ORACLE_NOT_MQL_EXECUTION')
    for name, changed in [('corrupt',prior['payload']+'!'),
                          ('capability',seal(update(prior['payload'],{'capability':update(nested(prior['payload'],'capability'),{'query_complete':'1'})}))),
                          ('policy-version',seal(update(prior['payload'],{'correlation':update(nested(prior['payload'],'correlation'),{'policy_version':'2'})})))]:
        r=deepcopy(prior);r['payload']=changed
        if name!='corrupt':r['payload_digest']=decode(changed)['bundle_digest'];r['store_revision']=token(r)
        check('oracle/'+name+'-rejects',not structural(r,profile,approval,proof),'PYTHON_SQLITE_ORACLE_NOT_MQL_EXECUTION')
    check('oracle/profile-rejects',not structural(prior,update(profile,{'server':'FOREIGN'}),approval,proof),'PYTHON_SQLITE_ORACLE_NOT_MQL_EXECUTION')
    values={'valid_from':at,'valid_until':at+3600,'sequence':4}
    op=update(nested(prior['payload'],'operator'),{'authenticated_at':at})
    values['operator']=op
    for name in PDOMAINS:
        changes={'approved_at':at}
        if name=='capability':changes.update(valid_from=at,valid_until=at+3600)
        values[name]=update(nested(prior['payload'],name),changes)
    identity=field('profile','s',b['profile']['profile_digest'])+field('approval','s',approval)+field('sequence','u',4)
    values['bundle_id']='MVP-RECONCILIATION-GOVERNANCE-'+digest(BDOMAIN+'-ID',identity)
    payload=seal(update(prior['payload'],values)); new=deepcopy(prior)
    new.update(payload=payload,payload_digest=decode(payload)['bundle_digest'],logical_revision=2,updated_at=at);new['store_revision']=token(new)
    check('oracle/new-finite-bundle-valid',structural(new,profile,approval,proof) and decode(payload)['valid_from']<=at<decode(payload)['valid_until'],'PYTHON_SQLITE_ORACLE_NOT_MQL_EXECUTION')
    def cas(expected, proposed):
        sql='UPDATE swv5_authority_rows SET logical_revision=?,store_revision=?,payload_digest=?,payload=?,updated_at=? WHERE namespace_digest=? AND domain_key=? AND record_key=? AND logical_revision=? AND store_revision=? AND payload_digest=? AND state=?'
        return db.execute(sql,(proposed['logical_revision'],proposed['store_revision'],proposed['payload_digest'],proposed['payload'],proposed['updated_at'],NAMESPACE,DOMAIN,'CURRENT',expected['logical_revision'],expected['store_revision'],expected['payload_digest'],expected['state'])).rowcount
    check('oracle/exact-prior-CAS-and-readback',cas(prior,new)==1 and dict(db.execute('SELECT * FROM swv5_authority_rows WHERE domain_key=? AND record_key=?',(DOMAIN,'CURRENT')).fetchone())==new,'PYTHON_SQLITE_ORACLE_NOT_MQL_EXECUTION')
    check('oracle/stale-prior-CAS-rejected',cas(prior,new)==0,'PYTHON_SQLITE_ORACLE_NOT_MQL_EXECUTION')
    captured=[dict(x) for x in db.execute('SELECT * FROM swv5_authority_rows ORDER BY domain_key,record_key')]
    changed=deepcopy(new);changed['logical_revision']+=1;changed['store_revision']=token(changed)
    check('oracle/boundary-valid-row-mutation',cas(new,changed)==1 and structural(changed,profile,approval,proof),'PYTHON_SQLITE_ORACLE_NOT_MQL_EXECUTION')
    current=[dict(x) for x in db.execute('SELECT * FROM swv5_authority_rows ORDER BY domain_key,record_key')]
    # Independent full-snapshot boundary expectation, not execution of MQL release.
    check('oracle/stale-complete-snapshot-rejected',captured!=current,'PYTHON_SQLITE_ORACLE_NOT_MQL_EXECUTION')
    db.close()
    text=EXPERTS.read_text(encoding='utf-16');start=text.rfind('CONTINUATION_NATIVE_COPY|START|')
    end=text.find('CONTINUATION_NATIVE_COPY|COMPLETE|',start)
    run=text[start:end+text[end:].find('\n')]
    failures=re.findall(r'CONTINUATION_ASSERT\|([^\r\n|]+)\|FAIL',run)
    check('native/preserved-60-pass-19-fail-summary',len(failures)==19 and 'passed=60|failed=19|skipped=0|total=79' in run,'PRE_FIX_NATIVE_EVIDENCE')
    check('native/direct-expired-refresh-passed-before-fix','GOV_CLOCK_EXACT_ACCEPTED_EVENT_REFRESH|PASS' in run,'PRE_FIX_NATIVE_EVIDENCE')
    classification=[];boundary_seen=0
    for name in failures:
        category='B';reason='Downstream: continuation never obtained refreshed Governance/ACTIVE/flat release authority.'
        if name=='REAL_SQLITE_CONTINUATION_COMPLETE' or name in ('RESUME_HEARTBEAT','RESUME_TRUST','RESUME_GOVERNANCE','RESUME_ACTIVE','RESUME_FLAT','RESUME_PENDING','RESUME_RELEASED'):
            category='A';reason='Run detail stops at GOVERNANCE_REFRESH / GOVERNANCE_FAILED; alias destroys prior row before CAS validation.'
        if name=='BOUNDARY_MUTATE_VALID_GOVERNANCE_ROW':
            boundary_seen+=1
            if boundary_seen==2:category='UNRESOLVED';reason='PENDING fixture never renewed Ownership/Trust; failure precedes Governance refresh, not proven to be its cascade.'
        if name in ('RESUME_CLOCK','BOUNDARY_INTERRUPT'):
            category='UNRESOLVED';reason='Stopped before Governance refresh (PRE_STATE/no lease renewal). Raw evidence lacks exact failed predicate; do not invent a causal classification.'
        classification.append(dict(ordinal=len(classification)+1,test_id=name,category=category,reason=reason))
    assertions=(HERE/'SW_V5_S5_MvpContinuationAssertions.mqh').read_text(encoding='utf-8-sig')
    check('fixtures/boundary-must-reach-exact-stage','r.reason=="PARTIAL_CONTINUATION/TEST_INTERRUPTION_"+test_stop_stage' in assertions,'STATIC_SOURCE')
    check('fixtures/no-delete-or-overwrite', 'FileDelete(' not in function(clean(assertions),'Clone') and 'FileIsExist(name' in assertions,'STATIC_SOURCE')
    check('fixtures/all-mutable-paths-use-fresh-prefix','i.path=m_copy+' not in assertions and 'const string path=m_copy+' not in assertions and 'm_main=m_run_prefix+' in assertions,'STATIC_SOURCE')
    check('fixtures/new-alias-and-corrupt-capability-tests',all(x in assertions for x in ('GOV_CLOCK_EXACT_ACCEPTED_EVENT_REFRESH_ALIASED_CAS','GOV_REFRESH_CORRUPT_ROW_REJECTED','GOV_REFRESH_CAPABILITY_COERCION_REJECTED','GOV_REFRESH_POLICY_VERSION_REJECTED')),'STATIC_SOURCE')
    compiled={}
    for name in ('SW_V5_S5_MVP_ATTENDED_AUTHORITY_CONTINUATION','SW_V5_S5_MVP_CONTINUATION_ASSERTIONS','SW_V5_S5_MVP_CONTINUATION_NATIVE_COPY_ASSERTIONS'):
        log=HERE/(name+'.log');result=re.findall(r'^Result:.*',log.read_text(encoding='utf-16'),flags=re.M)[-1]
        check('compile/'+name, bool(re.fullmatch(r"Result: 0 errors, 0 warnings, .*cpu='X64 Regular'",result)) and log.stat().st_mtime>=GOV.stat().st_mtime,'METAEDITOR_COMPILE_NOT_EXECUTION')
        compiled[name]=dict(result=result,ex5_sha256=sha(HERE/(name+'.ex5')))
    diff=subprocess.run(['git','diff','--check'],cwd=ROOT,capture_output=True,text=True)
    check('git/diff-check',diff.returncode==0,'GIT')
    check('fixture/original-and-donor-unchanged',before=={str(p):sha(p) for p in (ORIGINAL,COPY)},'READ_ONLY_PHYSICAL')
    output=dict(evidence_class='POST_FIX_STATIC_AND_PYTHON_ORACLE_ONLY_NATIVE_RETEST_NOT_EXECUTED',
                verifier_sha256=sha(Path(__file__)),
                root_cause='Prior expected_row/committed reference alias; output ZeroMemory erased prior CAS, not old expiry rejection.',
                original_and_donor=before,source_sha256=sha(GOV),native_experts_path=str(EXPERTS),native_experts_sha256=sha(EXPERTS),
                native_journal_path=str(JOURNAL),native_journal_sha256=sha(JOURNAL),preserved_native_run=run,
                prior_failures=classification,compile=compiled,checks=checks,source_isolation=isolation,early_refusal=refusal,
                summary=dict(total=len(checks),passed=sum(x['passed'] for x in checks),failed=sum(not x['passed'] for x in checks),
                             post_fix_MQL_executions=0,unresolved_prior_failures=sum(x['category']=='UNRESOLVED' for x in classification)))
    print(json.dumps(output,indent=2))
    return int(any(not x['passed'] for x in checks))


if __name__=='__main__':
    raise SystemExit(main())
