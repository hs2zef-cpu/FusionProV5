"""TEST ONLY / NOT FOR PRODUCTION / NO BROKER ACCESS.
Non-native pre-run audit only. Never launches MT5 or opens any DB for writing.
Pure input-refusal cases evaluate extracted MQL expressions; NOT MQL results.
"""
from pathlib import Path
import argparse, ast, hashlib, json, re, sqlite3, subprocess

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
COMMON=Path(r'C:\Users\Nutthakrit\AppData\Roaming\MetaQuotes\Terminal\Common\Files')
DATA=Path(r'C:\Users\Nutthakrit\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075')
NAME='SW_V5_S5_MVP_CONTINUATION_RESUME_CLOCK_DIAGNOSTIC'
VISIBLE_NAME='TEST_ONLY_'+NAME
RUN='9ee7fc055411445882dc75714db10333'
TARGET='TEST_ONLY_MVP_RESUME_CLOCK_DIAGNOSTIC_'+RUN+'.sqlite'
PRESET='TEST_ONLY_RESUME_CLOCK_DIAGNOSTIC_'+RUN+'.set'
MARKER='TEST_ONLY_RESUME_CLOCK_DIAGNOSTIC_NO_EXECUTION'
EXPECTED='BEC62E7435D29D5511A41BF85C74AE443994C5804B3A9574AF90D861FE674EF6'
NS='58408af3c3381470aa50161762e4f1102eec5d214448495a79d732cd31d90d8c'
ORIGINAL=COMMON/'fusion_v5_mvp_demo_authority.sqlite'
DONOR=COMMON/'TEST_ONLY_MVP_CONTINUATION_3f39a13e0c314df2bcd8452ae9de5e4c.sqlite'
OLD=DATA/'MQL5/Experts/FusionProV5Tests/SW_V5_S5_MVP_CONTINUATION_NATIVE_COPY_ASSERTIONS.ex5'
OLD_HASH='B70132E9D5BA2CF2882971FBAD5DA1DD2D752A9FF83E1529FD00891DE1557C09'
checks=[]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest().upper()
def check(name,ok,kind='STATIC_SOURCE'):checks.append(dict(id=name,passed=bool(ok),evidence_class=kind))
def clean(text):return re.sub(r'/\*.*?\*/|//[^\n]*','',text,flags=re.S)
def balanced(text,start,opening='{',closing='}'):
    level=0;quoted=False;escape=False
    for i in range(start,len(text)):
        c=text[i]
        if quoted:
            if escape:escape=False
            elif c=='\\':escape=True
            elif c=='"':quoted=False
            continue
        if c=='"':quoted=True;continue
        if c==opening:level+=1
        elif c==closing:
            level-=1
            if level==0:return i
    raise ValueError('Unbalanced source')
def function(text,name):
    m=re.search(r'\b'+re.escape(name)+r'\s*\([^;{}]*\)\s*(?:const\s*)?\{',text)
    if not m:raise ValueError('Function not found: '+name)
    start=text.index('{',m.start());return text[start+1:balanced(text,start)]
def klass(text,name):
    m=re.search(r'\bclass\s+'+name+r'\b[^;{]*\{',text)
    start=text.index('{',m.start());return text[start+1:balanced(text,start)]

def preprocess(path,defines=None,files=None):
    """Include/conditional reachability audit, not an MQL compiler.
    Keeps macro bodies/tokens; unsupported condition directives fail audit.
    """
    if defines is None:defines=set()
    if files is None:files=set()
    files.add(path.resolve());out=[];stack=[];active=True
    for line in path.read_text(encoding='utf-8-sig').splitlines():
        m=re.match(r'\s*#(\w+)\s*(.*)',line)
        if not m:
            if active:out.append(line)
            continue
        op,arg=m.groups()
        if op in ('ifdef','ifndef'):
            condition=(arg.strip() in defines) == (op=='ifdef')
            stack.append((active,condition));active=active and condition
        elif op=='else':
            parent,condition=stack[-1];active=parent and not condition
        elif op=='endif':
            parent,_=stack.pop();active=parent
        elif active and op=='include':
            inc=re.fullmatch(r'"([^"]+)"',arg.strip())
            if not inc:raise ValueError('Unsupported include: '+line)
            out.append(preprocess((path.parent/inc[1].replace('\\','/')).resolve(),defines,files))
        elif active and op=='define':
            defines.add(re.match(r'\w+',arg).group());out.append(line)
        elif active and op=='undef':defines.discard(arg.strip())
        elif op in ('if','elif'):raise ValueError('Unsupported conditional: '+line)
        elif active:out.append(line)
    if stack:raise ValueError('Unclosed preprocessor conditional')
    return '\n'.join(out)

def gate_eval(source,marker,target,run_id):
    body=function(source,'ResumeClockDiagnosticInputsValid')
    env=dict(marker=marker,target=target,run_id=run_id,StringLen=len,
             StringFind=lambda s,t:s.find(t),StringGetCharacter=lambda s,p:ord(s[p]))
    def expression(text):
        text=re.sub(r'!(?!=)',' not ',text.replace('&&',' and ').replace('||',' or ')).strip()
        tree=ast.parse('('+text+')',mode='eval')
        allowed=(ast.Expression,ast.BoolOp,ast.And,ast.Or,ast.UnaryOp,ast.Not,ast.Compare,
                 ast.Eq,ast.NotEq,ast.Gt,ast.GtE,ast.Lt,ast.LtE,ast.Name,ast.Load,ast.Call,
                 ast.Constant,ast.BinOp,ast.Add)
        if any(not isinstance(n,allowed) for n in ast.walk(tree)):raise ValueError('Unsafe gate expression')
        return eval(compile(tree,'extracted MQL gate','eval'),{'__builtins__':{}},env)
    # Walk actual simple if/for/return source; no separately copied gate oracle.
    def fragment(text):
        cursor=0
        while cursor<len(text):
            if text[cursor].isspace():cursor+=1;continue
            tail=text[cursor:]
            if tail.startswith('if('):
                start=cursor+2;end=balanced(text,start,'(',')')
                if not text[end+1:].lstrip().startswith('return false;'):raise ValueError('Unsupported gate if')
                if expression(text[start+1:end]):return False
                cursor=text.index(';',end)+1
            elif tail.startswith('for('):
                start=cursor+3;end=balanced(text,start,'(',')')
                init,condition,increment=text[start+1:end].split(';')
                if init!='int p=0' or increment!='p++':raise ValueError('Unsupported gate loop')
                bstart=text.index('{',end);bend=balanced(text,bstart)
                env['p']=0
                while expression(condition):
                    if env['p']>64:raise ValueError('Loop bound')
                    if fragment(text[bstart+1:bend]) is False:return False
                    env['p']+=1
                cursor=bend+1
            elif tail.startswith('const int c='):
                end=text.index(';',cursor);env['c']=expression(text[cursor+len('const int c='):end].replace('(int)',''));cursor=end+1
            elif tail.startswith('return '):return bool(expression(text[cursor+7:text.index(';',cursor)]))
            else:raise ValueError('Unsupported gate statement '+tail[:80])
        return None
    return fragment(body)

def main():
    args=argparse.ArgumentParser();args.add_argument('--require-installed',action='store_true');opts=args.parse_args()
    source=HERE/(NAME+'.mq5');ea=source.read_text(encoding='utf-8-sig');code=clean(ea)
    files=set();expanded=preprocess(source,files=files);compiled=clean(expanded)
    core=klass(compiled,'SWV5S5_MvpAttendedContinuation');run=function(core,'Run')
    check('classifier/shared-production-draft-called','.Run(input_state,op,clock,platform,broker,result)' in code)
    check('classifier/no-predicate-copy-in-harness','PRESTATE_REQUIRE' not in code and 'CurrentFreshObservationDiagnostic' not in code)
    check('classifier/no-mutating-tail',all(s not in run for s in ('HeartbeatAttended','Provision(', 'RefreshCurrent(', 'ContinuationActivate(',
          'StageContinuationPending(', 'PersistApprovedContinuationRelease(', 'TryActivateInactiveAfterValidatedRelease(', 'BrokerZero(')))
    check('classifier/no-flat-method',not re.search(r'\bbool\s+Flat\s*\(',core))
    check('classifier/read-only-store-open','store.OpenReadOnly(i.path,i.namespace_digest)' in run and 'store.Open(' not in run)
    check('classifier/predicates-retained','CurrentFreshObservationDiagnostic' in run and 'if(at!=clock.observed_at)' in run and
          'EmptyExecutionAndBasketDiagnostic' in run and 'RowsAllowedDiagnostic' in run and 'ResumeProofValid' in run)
    ordinary=clean(preprocess(ROOT/'FusionProV5/ExecutionLayer/RuntimeAuthority/SW_V5_S5_MvpAttendedContinuation.mqh'))
    ordinary_run=function(klass(ordinary,'SWV5S5_MvpAttendedContinuation'),'Run')
    check('ordinary/diagnostic-mode-absent', 'TEST_ONLY_PRESTATE_ACCEPTED_NO_AUTHORITY' not in ordinary_run and
          'owner.HeartbeatAttended' in ordinary_run and 'g_owner.RefreshCurrent' in ordinary_run and
          'store.Open(i.path,i.namespace_digest)' in ordinary_run)
    check('architecture/no-checkpoint-or-R-intent',not re.search(r'MVP_CONTINUATION_CLOCK_CHECKPOINT|MvpContinuationClockCheckpoint|CONTINUATION_WRITE_AHEAD_INTENT',compiled))
    # Existing completed-history readback can set accepted=true as a historical
    # report, never execution authority. The diagnostic endpoint itself does
    # not set it, and the compiled mutating tail is independently excluded.
    endpoint=run[run.index('"TEST_ONLY_PRESTATE_ACCEPTED_NO_AUTHORITY"'):]
    check('classifier/no-grant','m_result.accepted=true' not in endpoint and run.count('m_result.accepted=true')==1 and
          'm_result.already_complete=true; m_result.reason="ALREADY_COMPLETE_READBACK_ONLY"' in run)
    helpers=['ScopeOwner','ReadLease','ReadGovernance','ReadTrust','ResumeProofValid','EmptyExecutionAndBasketDiagnostic',
             'RowsAllowedDiagnostic','RowsAllowed','ReadCompletedOnly']
    forbidden=r'\b(?:CompareAndSet\w*|Provision|RefreshCurrent|HeartbeatAttended|TryActivateInactiveAfterValidatedRelease|OrderSend|OrderSendAsync|Submit)\s*\('
    check('classifier/helper-methods-read-only',all(not re.search(forbidden,function(core,n)) for n in helpers))
    check('includes/no-launcher-or-full-suite',not any(p.name in ('SW_V5_S5_MvpAttendedLaunch.mqh','SW_V5_S5_MvpContinuationAssertions.mqh') for p in files))
    check('transport/compile-time-traps',all('#define '+n+' FUSION_TEST_ONLY_FORBIDDEN_SEND' in expanded for n in ('OrderSend','OrderSendAsync')))
    check('harness/no-execution-calls',not re.search(forbidden,code))
    check('harness/no-authority-grant-calls',not re.search(r'\.\s*(?:Heartbeat\w*|Provision|RefreshCurrent|Try\w*|Submit|Claim)\s*\(',code))
    check('harness/broker-fail-trap', 'test_forbidden_transport_calls++;ZeroMemory(observation);return false;' in code)
    publish=function(code,'DiagnosticPublishThenDestroy');cold=function(code,'DiagnosticClassifyCold')
    check('clock/single-native-publication',code.count('.ObserveFromCurrentSymbolOnTick(')==1 and '.ObserveAcceptedEvent(' not in code)
    check('clock/publication-is-production-path', 'publisher.ObserveFromCurrentSymbolOnTick' in publish)
    check('restart/publisher-closed-before-return',publish.index('publisher.Close();')<publish.index('INJECTION_FIRED'))
    check('restart/separate-function-new-objects','DiagnosticClassifyCold()' in code and 'MvpLeaseClockAuthority clock;' in cold and
          'ConfigureReadOnly' in cold and 'LoadStored' in cold and 'publisher' not in cold and 'ObserveFrom' not in cold)
    check('restart/no-local-freshness-reconstruction',not re.search(r'm_fresh(?:_since_open)?\s*=',code))
    check('snapshot/full-canonical-exports','MvpContinuationRowsPayload(rows,body)' in code and all(s in code for s in
          ('".before.rows"','".after.rows"','".classified.rows"')))
    check('snapshot/full-non-clock-equality','x!=clock_index && !SWV5S5_MvpContinuationRowExact(before[x],after[x])' in code)
    check('snapshot/exact-sequence-time-id',all(s in code for s in ('old_clock.clock_sequence+1','new_clock.observed_at<=old_clock.observed_at',
          'new_clock.platform_observation_id==old_clock.platform_observation_id','DiagnosticSameRows(after,classified)')))
    check('snapshot/operational-absence','MvpContinuationInventoryAllowedDiagnostic' in code and 'requests.view.header.request_count!=0' in code)
    check('result/no-rejection-false-pass','if(result.reason=="")return false;' in cold and 'return test_forbidden_transport_calls==0;' in cold and
          'DiagnosticPublishThenDestroy()' in code and 'CLOCK_ONLY_PROVEN' in code)
    check('result/exact-failing-facts','name=m_fresh_since_open|required=true|actual=' in expanded and 'event_local_sequence=' in expanded)
    init=function(code,'OnInit');event=function(code,'OnChartEvent');tick=function(code,'OnTick');gate=function(code,'DiagnosticGate')
    check('oneshot/attach-and-preset-no-write',all(not re.search(r'FileCopy|FILE_WRITE|DiagnosticRunOnce|\.Configure\(',x) for x in (init,event,gate)))
    check('oneshot/ack-required','diagnostic_consumed || !diagnostic_ack' in tick and 'lparam==65 && !diagnostic_consumed && !diagnostic_ack' in event)
    check('oneshot/consumed-before-first-write',tick.index('diagnostic_consumed=true;diagnostic_ack=false;')<tick.index('DiagnosticRunOnce()'))
    check('oneshot/no-timer-or-retry','OnTimer' not in code and code.count('DiagnosticRunOnce();')==1 and 'NO_RETRY' in code)
    check('paths/production-db-never-opened','fusion_v5_mvp_demo_authority.sqlite' not in code and 'const string diagnostic_donor=' in code)
    check('paths/no-existing-target-overwrite', 'DiagnosticNoTargetArtifacts()' in code and 'FILE_REWRITE' not in code)
    gsource=clean((HERE/'SW_V5_S5_MvpResumeClockDiagnosticGate.mqh').read_text())
    cases=[('valid',MARKER,TARGET,RUN,True),('production-filename',MARKER,'fusion_v5_mvp_demo_authority.sqlite',RUN,False),
           ('marker-missing','',TARGET,RUN,False),('marker-invalid','TEST_ONLY',TARGET,RUN,False),
           ('traversal',MARKER,'..\\'+TARGET,RUN,False),('absolute',MARKER,str(COMMON/TARGET),RUN,False),
           ('slash',MARKER,'dir/'+TARGET,RUN,False),('colon',MARKER,':'+TARGET,RUN,False),
           ('old-clone',MARKER,DONOR.name,RUN,False),('run-missing',MARKER,TARGET,'',False),
           ('run-too-short',MARKER,TARGET,RUN[:-1],False),('run-nonhex',MARKER,TARGET,'x'*32,False),
           ('run-uppercase',MARKER,TARGET,RUN.upper(),False),('wrong-extension',MARKER,TARGET+'.bak',RUN,False),
           ('different-run',MARKER,TARGET,'0'*32,False)]
    refusals=[]
    for name,marker,target,rid,wanted in cases:
        accepted=gate_eval(gsource,marker,target,rid);check('gate/'+name,accepted==wanted,'SOURCE_EXTRACTED_PURE_MQL_GATE_NOT_NATIVE')
        refusals.append(dict(case=name,accepted=accepted,expected=wanted))
    check('gate/domination-before-any-durable-write',function(code,'DiagnosticRunOnce').lstrip().startswith('if(!DiagnosticGate())return false;'))
    check('gate/production-refusal-before-io','ResumeClockDiagnosticInputsValid' in gate and gate.index('ResumeClockDiagnosticInputsValid')<gate.index('TestContinuationFileSha'))
    hashes={str(p):sha(p) for p in (ORIGINAL,DONOR)}
    check('integrity/original-donor',all(h==EXPECTED for h in hashes.values()),'READ_ONLY_FILE_HASH')
    check('integrity/original-sidecars-absent',all(not Path(str(ORIGINAL)+s).exists() for s in ('-wal','-shm')),'READ_ONLY_METADATA')
    check('integrity/donor-wal-empty',not Path(str(DONOR)+'-wal').exists() or Path(str(DONOR)+'-wal').stat().st_size==0,'READ_ONLY_METADATA')
    check('integrity/target-absent',all(not Path(str(COMMON/TARGET)+s).exists() for s in ('','-wal','-shm','.before.rows','.after.rows','.classified.rows')),'READ_ONLY_METADATA')
    con=sqlite3.connect(DONOR.as_uri()+'?mode=ro&immutable=1',uri=True);con.execute('PRAGMA query_only=ON')
    metadata=con.execute('SELECT namespace_digest FROM swv5_store_metadata').fetchall();row_count=con.execute('SELECT count(*) FROM swv5_authority_rows').fetchone()[0];con.close()
    check('integrity/donor-namespace',metadata==[(NS,)],'READ_ONLY_IMMUTABLE_DONOR_SQLITE')
    check('integrity/old-native-binary-untouched',sha(OLD)==OLD_HASH,'READ_ONLY_FILE_HASH')
    preset=HERE/PRESET;values=dict(line.split('=',1) for line in preset.read_text(encoding='utf-8-sig').splitlines() if '=' in line)
    check('preset/exact-inputs',values==dict(explicit_test_only_marker=MARKER,diagnostic_target_relative_path=TARGET,
          diagnostic_run_id=RUN,operator_confirmed_diagnostic_only='true'),'READ_ONLY_PRESET')
    log=HERE/(NAME+'.log');compile_result=re.findall(r'^Result:.*',log.read_text(encoding='utf-16'),re.M)[-1]
    binary=HERE/(NAME+'.ex5');fresh=all(log.stat().st_mtime>=p.stat().st_mtime for p in files)
    check('compile/native-diagnostic',fresh and '0 errors, 0 warnings' in compile_result and "cpu='X64 Regular'" in compile_result,'METAEDITOR_COMPILE_NOT_EXECUTION')
    installed=DATA/'MQL5/Experts/FusionProV5Tests'/(VISIBLE_NAME+'.ex5');installed_preset=DATA/'MQL5/Presets'/PRESET
    if opts.require_installed:
        check('install/binary-exact',installed.exists() and sha(installed)==sha(binary),'READ_ONLY_FILE_HASH')
        check('install/preset-exact',installed_preset.exists() and sha(installed_preset)==sha(preset),'READ_ONLY_FILE_HASH')
    check('git/diff-check',subprocess.run(['git','diff','--check'],cwd=ROOT,capture_output=True).returncode==0,'GIT')
    check('git/branch',subprocess.check_output(['git','branch','--show-current'],cwd=ROOT,text=True).strip()=='sprint5-phase-f-entry-contract','GIT')
    check('git/head',subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()=='d926f2e6b1aa4ea7b4b0936293d2fa47a2ce7ba8','GIT')
    check('git/main-unchanged',subprocess.check_output(['git','rev-parse','main'],cwd=ROOT,text=True).strip()=='32b79ca71ffc331e15e48a57c52be1352e3dbe7e','GIT')
    check('integrity/end-hashes-unchanged',hashes=={str(p):sha(p) for p in (ORIGINAL,DONOR)},'READ_ONLY_FILE_HASH')
    sources={str(p.relative_to(ROOT)):sha(p) for p in sorted(files)}
    digest=hashlib.sha256('\n'.join(k+'\0'+v for k,v in sorted(sources.items())).encode()).hexdigest().upper()
    print(json.dumps(dict(classification='NON_NATIVE_PRE_RUN_AUDIT_NOT_EXECUTED',checks=checks,
          summary=dict(total=len(checks),passed=sum(c['passed'] for c in checks),failed=sum(not c['passed'] for c in checks),native_executions=0),
          refusal_cases=refusals,source_path=str(source),source_sha256=sha(source),verification_source_digest=digest,
          dependency_hashes=sources,compile_result=compile_result,compiled_ex5=str(binary),compiled_ex5_sha256=sha(binary),
          installed_ex5=str(installed),installed_ex5_sha256=sha(installed) if installed.exists() else None,
          preset_path=str(installed_preset),preset_sha256=sha(installed_preset) if installed_preset.exists() else None,
          original_donor_hashes=hashes,donor_row_count=row_count,namespace=NS,diagnostic_target=str(COMMON/TARGET),
          diagnostic_target_created=False,option_R_implemented=False,verifier_sha256=sha(Path(__file__))),indent=2))
    return int(any(not c['passed'] for c in checks))
if __name__=='__main__':raise SystemExit(main())
