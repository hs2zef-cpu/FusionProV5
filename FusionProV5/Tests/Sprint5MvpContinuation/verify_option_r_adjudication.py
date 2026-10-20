"""TEST ONLY: source-extracted clock predicates, source/mutation controls.

No MT5, no native reproduction, no installation, no SQLite writes. Modeled
event-local state is test data and never grants or reconstructs runtime authority.
"""
from copy import deepcopy
from pathlib import Path
from types import SimpleNamespace
import ast
import hashlib
import json
import re
import sqlite3
import subprocess
import verify_governance_refresh as gov
from verify_native_copy_prerun import ROOT, HERE, COPY, ORIGINAL, EXPECTED, DATA, function, clean, field, digest, decode

OWNER=ROOT/'FusionProV5/ExecutionLayer/RuntimeAuthority/SW_V5_S5_MvpOwnershipAuthority.mqh'
CORE=ROOT/'FusionProV5/ExecutionLayer/RuntimeAuthority/SW_V5_S5_MvpAttendedContinuation.mqh'
FLAT=ROOT/'FusionProV5/ExecutionLayer/RuntimeAuthority/SW_V5_S5_MvpContinuationFlatAuthority.mqh'
SUITE=HERE/'SW_V5_S5_MvpContinuationAssertions.mqh'
KEY=('MVP_OWNERSHIP_LEASE','LEASE_CLOCK_CURRENT')
checks=[]


def check(name, condition, kind):
    checks.append(dict(id=name,passed=bool(condition),evidence_class=kind))


def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest().upper()
def ns(value):return SimpleNamespace(**value)


def clock_id(c):
    if not c.broker_identity or not c.server or c.account_login<=0 or c.source_symbol!='XAUUSD':return None
    return 'SWV5-MQL5-TIMECURRENT-LAST-KNOWN-SERVER-V1/'+c.broker_identity+'/'+c.server+'/'+str(c.account_login)+'/XAUUSD'


def valid(c):
    return (clock_id(c)==c.clock_id and c.clock_authority==1 and c.observed_at>0 and c.clock_sequence>0 and
            c.source_symbol=='XAUUSD' and c.source==1 and bool(c.platform_observation_id))


def payload(c):
    fields=[('physical_format','s','SWV5-MVP-LEASE-CLOCK-PHYSICAL-V1'),('clock_id','s',c.clock_id),
            ('clock_authority','i',c.clock_authority),('observed_at','i',c.observed_at),('clock_sequence','u',c.clock_sequence),
            ('broker_identity','s',c.broker_identity),('server','s',c.server),('account_login','i',c.account_login),
            ('source_symbol','s',c.source_symbol),('source','i',c.source),('platform_observation_id','s',c.platform_observation_id)]
    body=''.join(field(*x) for x in fields)
    return body,digest(KEY[0],body)


def source_predicates(source):
    body=function(clean(source),'CurrentFreshObservationDiagnostic')
    return [(condition,reason) for condition,reason in re.findall(r'^\s*CONT_CLOCK_REQUIRE\((.*),"([^"]+)"\);',body,flags=re.M)]


def evaluate(predicates,row,last,has_event=True,exists=True,read_ok=True):
    env={'m_fresh_since_open':has_event,'m_fresh':ns(last),'row':ns(row),'found':False,'current':ns(last),
         'expected_id':'','payload':'','digest':'','revision':'','SWV5S5_MVP_DOMAIN_OWNERSHIP':KEY[0],
         'SWV5S5_MVP_OWNERSHIP_CLOCK_KEY':KEY[1],'SWV5_TIME_AUTHORITY_BROKER_SERVER':1,
         'SWV5S5_MVP_SYMBOL':'XAUUSD','SWV5S5_MVP_CLOCK_SOURCE_CURRENT_SYMBOL_ONTICK':1,
         'SWV5S5_MvpLeaseClockObservationValid':valid}
    def read(*args):env['found']=exists;return read_ok
    def decode_clock(body,unused):
        try:
            raw=gov.raw_fields(body)
            if [n for n,_,_ in raw]!=[n for n,_,_ in gov.raw_fields(payload(ns(last))[0])]:return False
            c=decode(body)
            if c.pop('physical_format')!='SWV5-MVP-LEASE-CLOCK-PHYSICAL-V1':return False
            env['current']=ns(c);return True
        except (ValueError,KeyError):return False
    def derive_id(broker,server,login,symbol,unused):
        env['expected_id']=clock_id(ns(dict(broker_identity=broker,server=server,account_login=login,source_symbol=symbol)))
        return env['expected_id'] is not None
    def encode(c,*args):env['payload'],env['digest']=payload(c);return True
    def revision(*args):env['revision']=gov.token(row);return True
    env.update(m_store=SimpleNamespace(ReadRow=read,DeriveStoreRevision=revision),
               SWV5S5_MvpDecodeLeaseClockPayload=decode_clock,SWV5S5_MvpLeaseClockId=derive_id,SWV5S5_MvpLeaseClockPayload=encode)
    for condition,reason in predicates:
        text=re.sub(r'!(?!=)',' not ',condition.replace('&&',' and ').replace('||',' or ')).strip()
        tree=ast.parse('('+text+')',mode='eval')
        allowed=(ast.Expression,ast.BoolOp,ast.And,ast.Or,ast.UnaryOp,ast.Not,ast.Compare,ast.Eq,ast.NotEq,
                 ast.Gt,ast.GtE,ast.Lt,ast.LtE,ast.Name,ast.Load,ast.Attribute,ast.Call,ast.Constant)
        if any(not isinstance(n,allowed) for n in ast.walk(tree)):raise ValueError('Unsupported diagnostic expression')
        if not eval(compile(tree,'source-extracted MQL clock predicate','eval'),{'__builtins__':{}},env):return False,reason
    return True,''


def ordinary(row,last,has_event=True,exists=True,read_ok=True):
    if not has_event or not valid(ns(last)) or not read_ok or not exists:return False
    try:
        c=decode(row['payload']);c.pop('physical_format');c=ns(c);body,d=payload(c)
        return (row['logical_revision']>0 and row['state']==1 and valid(c) and row['payload']==body and row['payload_digest']==d and
                c.clock_sequence==row['logical_revision'] and gov.token(row)==row['store_revision'] and
                c.clock_sequence==last['clock_sequence'] and c.platform_observation_id==last['platform_observation_id'])
    except (KeyError,ValueError):return False


def boundary_guard(source):
    body=function(clean(source),'ReleaseBoundaryCase');pair=function(clean(source),'ReleaseBoundaryMutation')
    return (all(x in body for x in ('test_fired_stop_stage','BOUNDARY_EXPECTED_LATER_RELEASE_ABSENT',
                                   'BOUNDARY_PARTIAL_PREFLIGHT_DENIED_ZERO_MUTATION','BOUNDARY_FIXTURE_LEASE_READ_DECODE_FAILED',
                                   'release_invoked=false','release_invoked && !accepted','release_invoked && accepted',
                                   'governance.payload,governance.updated_at,changed)','changed_count==1')) and
            re.search(r'release_invoked=true;\s*accepted=SWV5S5_MvpPersistApprovedContinuationRelease',body) is not None and
            'Check(control && mutated && control_basis!="" && control_basis==mutated_basis' in pair)


def main():
    before={str(p):sha(p) for p in (ORIGINAL,COPY)}
    owner=OWNER.read_text(encoding='utf-8-sig');core=CORE.read_text(encoding='utf-8-sig');suite=SUITE.read_text(encoding='utf-8-sig')
    old=subprocess.check_output(['git','show','HEAD:'+OWNER.relative_to(ROOT).as_posix()],cwd=ROOT,text=True)
    for name in ('CurrentFreshObservation','LoadVerified','ObserveAcceptedEvent','ObserveFromCurrentSymbolOnTick'):
        check('clock/ordinary-body-unchanged/'+name,function(clean(owner),name)==function(clean(old),name),'STATIC_SOURCE')
    diag=function(clean(owner),'CurrentFreshObservationDiagnostic')
    check('clock/diagnostic-no-write-or-publication',not re.search(r'\b(?:CompareAndSet\w*|ObserveAcceptedEvent|ObserveFromCurrentSymbolOnTick|Open|Configure)\s*\(',diag) and
          not re.search(r'm_fresh(?:_since_open)?\s*=',diag),'STATIC_SOURCE')
    predicates=source_predicates(owner)
    connection=sqlite3.connect(COPY.as_uri()+'?mode=ro&immutable=1',uri=True);connection.row_factory=sqlite3.Row;connection.execute('PRAGMA query_only=ON')
    base=dict(connection.execute('SELECT * FROM swv5_authority_rows WHERE domain_key=? AND record_key=?',KEY).fetchone());connection.close()
    last=decode(base['payload']);last.pop('physical_format')
    cases=[('valid',deepcopy(base),True,True,True),('cold',deepcopy(base),False,True,True),
           ('missing',deepcopy(base),True,False,True),('read-failure',deepcopy(base),True,True,False)]
    mutations={'id':{'clock_id':last['clock_id']+'-WRONG'},'broker':{'broker_identity':'FOREIGN'},'server':{'server':'FOREIGN'},
               'account':{'account_login':last['account_login']+1},'symbol':{'source_symbol':'OTHER'},'authority':{'clock_authority':0},
               'zero-sequence':{'clock_sequence':0},'zero-time':{'observed_at':0},'event-sequence':{'clock_sequence':last['clock_sequence']+1},
               'event-id':{'platform_observation_id':'OTHER_EVENT'}}
    for name,values in mutations.items():
        r=deepcopy(base);c=last|values;r['payload'],r['payload_digest']=payload(ns(c));r['logical_revision']=c['clock_sequence']
        r['store_revision']=gov.token(r);cases.append((name,r,True,True,True))
    for name in ('malformed','digest','revision','state'):
        r=deepcopy(base)
        if name=='malformed':r['payload']+='!'
        if name=='digest':r['payload_digest']='0'*64
        if name=='revision':r['store_revision']='0'*64
        if name=='state':r['state']=0
        cases.append((name,r,True,True,True))
    results=[]
    for name,row,fresh,exists,read in cases:
        actual,reason=evaluate(predicates,row,last,fresh,exists,read);reference=ordinary(row,last,fresh,exists,read)
        check('source-extracted-clock/'+name,actual==reference and (actual or reason.startswith('PRESTATE_CLOCK_')),
              'SOURCE_EXTRACTED_PREDICATE_FIXTURE_NOT_MQL_OR_RESUME_REPRODUCTION')
        results.append(dict(case=name,accepted=actual,reason=reason,ordinary_reference_accepts=reference))
    check('boundary/invocation-injection-and-differential-guard',boundary_guard(suite),'STATIC_MQL_TEST_LOGIC')
    mutants={
        'MC-BOUND-INVOKED-BYPASS':suite.replace('release_invoked && !accepted','!accepted'),
        'MC-BOUND-INJECTION-FIRED-BYPASS':suite.replace('test_fired_stop_stage==','test_unverified_stop_stage=='),
        'MC-BOUND-CONTROL-CREDIT-BYPASS':suite.replace('Check(control && mutated &&','Check(mutated &&'),
        'MC-BOUND-MUTATION-TIME-INVALIDATES-GOVERNANCE':suite.replace('governance.payload,governance.updated_at,changed)','governance.payload,TimeCurrent(),changed)')}
    # The injection mutation must remove all evidence of the positively fired hook from this fixture.
    mutants['MC-BOUND-INJECTION-FIRED-BYPASS']=suite.replace('test_fired_stop_stage','test_unverified_stop_stage')
    for name,mutant in mutants.items():check(name,not boundary_guard(mutant),'STATIC_MUTATION_CONTROL_NOT_COMPILED_MUTANT')
    gsource=gov.GOV.read_text(encoding='utf-8-sig')
    check('governance/alias-and-expiry-preserved',gov.source_guard(gsource,core),'STATIC_SOURCE')
    mutant=gsource.replace('SWV5S5_MvpGovernanceValid(bundle,now)','LoadCurrentStructural(expected,"approval","proof",bundle,row)')
    check('MC-GOV-EXPIRED-ELIGIBILITY-BYPASS',not gov.source_guard(mutant,core),'STATIC_MUTATION_CONTROL_NOT_COMPILED_MUTANT')
    files=list((ROOT/'FusionProV5/ExecutionLayer/RuntimeAuthority').glob('*.mqh'))
    runtime='\n'.join(clean(p.read_text(encoding='utf-8-sig')) for p in files)
    check('architecture/no-clock-checkpoint-or-intent',not re.search(r'MVP_CONTINUATION_CLOCK_CHECKPOINT|MvpContinuationClockCheckpoint|CONTINUATION_WRITE_AHEAD_INTENT',runtime),'STATIC_SOURCE')
    check('architecture/profile-event-equality-not-relaxed','if(at!=clock.observed_at)' in core,'STATIC_SOURCE')
    check('mql/clock-negative-table-present',all('"'+s+'"' in suite for s in ('ID','BROKER','SERVER','ACCOUNT','SYMBOL','AUTHORITY','MALFORMED','DIGEST','STORE_REVISION','ZERO_SEQUENCE','BACKWARD_SEQUENCE','BACKWARD_TIME','DUPLICATE_OBSERVATION','FUTURE_TIME')),'STATIC_MQL_TEST_LOGIC')
    check('mql/future-and-monotonic-publication-guards','broker_server_time<prior.observed_at' in function(clean(owner),'ObserveAcceptedEvent') and
          'platform_observation_id==prior.platform_observation_id' in function(clean(owner),'ObserveAcceptedEvent') and
          'prior.clock_sequence+1' in function(clean(owner),'ObserveAcceptedEvent'),'STATIC_SOURCE')
    compiles={}
    for name in ('SW_V5_S5_MVP_ATTENDED_AUTHORITY_CONTINUATION','SW_V5_S5_MVP_CONTINUATION_ASSERTIONS'):
        log=HERE/(name+'.log');result=re.findall(r'^Result:.*',log.read_text(encoding='utf-16'),flags=re.M)[-1]
        fresh=all(log.stat().st_mtime>=p.stat().st_mtime for p in (OWNER,CORE,FLAT,SUITE))
        check('compile/'+name,fresh and bool(re.fullmatch(r"Result: 0 errors, 0 warnings, .*cpu='X64 Regular'",result)),'METAEDITOR_COMPILE_NOT_EXECUTION')
        compiles[name]=dict(result=result,ex5_sha256=sha(HERE/(name+'.ex5')))
    installed=DATA/'MQL5/Experts/FusionProV5Tests/SW_V5_S5_MVP_CONTINUATION_NATIVE_COPY_ASSERTIONS.ex5'
    check('native/old-install-untouched',sha(installed)=='B70132E9D5BA2CF2882971FBAD5DA1DD2D752A9FF83E1529FD00891DE1557C09','READ_ONLY_BINARY_HASH')
    check('db/original-and-donor-unchanged',before=={str(p):sha(p) for p in (ORIGINAL,COPY)} and all(x==EXPECTED for x in before.values()),'READ_ONLY_FILE_HASH')
    check('git/diff-check',subprocess.run(['git','diff','--check'],cwd=ROOT,capture_output=True).returncode==0,'GIT')
    print(json.dumps(dict(classification='DIAGNOSTIC_PREPARATION_ONLY_ROOT_CAUSE_STILL_UNPROVEN',
                         verifier_sha256=sha(Path(__file__)),checks=checks,diagnostic_fixture_results=results,
                         summary=dict(total=len(checks),passed=sum(x['passed'] for x in checks),failed=sum(not x['passed'] for x in checks),MQL_executions=0),
                         actual_resume_clock_predicate=None,option_R_implemented=False,checkpoint_implemented=False,
                         fresh_native_reproduction_clone_created=False,compiles=compiles,installed_native_sha256=sha(installed),
                         original_and_donor_sha256=before,source_hashes={str(p.relative_to(ROOT)):sha(p) for p in (OWNER,CORE,FLAT,SUITE)}),indent=2))
    return int(any(not x['passed'] for x in checks))


if __name__=='__main__':raise SystemExit(main())
