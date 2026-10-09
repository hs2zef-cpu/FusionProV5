"""TEST ONLY. Structural/isolation evidence, never MQL behavior or Broker execution."""
from pathlib import Path
import re
import subprocess

repo = Path(__file__).resolve().parents[3]
root = repo / "FusionProV5"
control = root / "ExecutionLayer/ControlledDemo"
runtime = root / "ExecutionLayer/RuntimeAuthority"
tests = Path(__file__).resolve().parent
baseline = "3d0224e7a0d8bd42a0b9eec91e8bdf3f8c048dd7"
def read(path): return path.read_text(encoding="utf-8")
def code(text): return re.sub(r'//[^\n]*|/\*.*?\*/|"(?:\\.|[^"\\])*"', '', text, flags=re.S)
def git(*args): return subprocess.check_output(["git", *args], cwd=repo, text=True)
checks = []
def check(name, ok):
    checks.append((name, bool(ok)))
    print(f"ATTENDED_SOURCE|{name}|{'PASS' if ok else 'FAIL'}")

launch = read(control / "SW_V5_S5_MvpAttendedLaunch.mqh")
gate = read(control / "SW_V5_S5_MvpAttendedLaunchGate.mqh")
seed = read(control / "SW_V5_S5_MvpAttendedAuthoritySeed.mqh")
port = read(control / "SW_V5_S5_MvpControlledDemoAuthorityPort.mqh")
runner = read(control / "SW_V5_S5_MvpControlledDemoRunner.mqh")
wrapper = read(tests / "SW_V5_S5_MVP_CONTROLLED_DEMO_RUNNER.mq5")
admin = read(runtime / "SW_V5_S5_MvpAttendedAdministration.mqh")
setup_wrapper = read(tests / "SW_V5_S5_MVP_MANUAL_DEMO_SETUP.mq5")
admin_wrapper = read(tests / "SW_V5_S5_MVP_ATTENDED_SAFETY_GOVERNANCE.mq5")
check("LAUNCH-01-complete-native-graph", all(s in launch for s in (
    "CCentralOrchestrator", "MvpMt5ReadOnlyPlatform", "MvpControlledDemoAuthorityPort", "MvpBrokerEvidenceStore",
    "new SWV5S5_F_BrokerPlatformAdapter", "new SWV5S5_MvpBrokerRecoveryReadPort", "new SWV5S5_MvpControlledDemoBrokerBoundary")))
check("actual-wrapper-dispatch", "g_launch.OnCurrentSymbolTick()" in wrapper and "runner.Run(invocation,authority,boundary,result)" in launch)
check("LAUNCH-02-default-readonly-clock", "clock.ConfigureReadOnly" in launch and "observation.observed_at!=TimeCurrent()" in launch)
check("LAUNCH-04-four-safe-defaults", all(s in wrapper for s in (
    "runner_mode=MODE_PREFLIGHT", "armed_for_demo_submission=false", "operator_confirmed_before_claim=false", "execute_attended_once=false")))
check("actual-decision-source", "m_orchestrator.Evaluate(" in launch and "seed.decision=decision" in launch and "MvpProjectSignalSource" in gate)
check("no-synthetic-native-buy", not re.search(r'(?:decision|seed\.decision)\.(?:action|direction)\s*=', code(launch + seed)))
check("fresh-session-no-saved-rearm", "m_session_armed=false; m_consumed=false" in gate and "m_gate.ArmExplicitly(m_invocation)" in launch and "CHARTEVENT_KEYDOWN" in wrapper)
check("LAUNCH-08-wrapper-latch-before-clock", launch.index("m_gate.ConsumeEligibleBuy") < launch.index("clock.ObserveFromCurrentSymbolOnTick") and "m_consumed=true; m_session_armed=false" in gate)
check("LAUNCH-09-no-second-tick", "m_gate.Consumed()) return" in launch and "if(m_consumed" in gate)
check("no-timer-dispatch", "void OnTimer(void) { }" in wrapper)
check("LAUNCH-13-full-physical-seed", all(s in seed for s in ("OpenReadOnly", "LoadCurrentLease", "LoadCurrent(seed.current_trust", "account.ValidateCurrent", "basket.ValidateCurrentBasket", "activation.LoadCurrentInactive")))
check("single-financial-preparation-read", "CaptureFlatAccount" not in code(seed + port) and "increasing.observation=m_account_observation" in port)
check("LAUNCH-15-claim-submission-same-stack", runner.index("authority.ClaimPhysicalNow") < runner.index("submission_boundary.SubmitExactlyOnce") and "while(" not in code(runner))
check("LAUNCH-16-17-durable-pin-vector-guard", "RevalidateDurablePinAndVectorBeforeClaim()" in port and "PersistReconciliationPinBeforeClaim()" in port)
check("LAUNCH-22-independent-administration", "SAFETY_RELEASE_ONLY" in admin_wrapper and "TryActivateInactiveAfterValidatedRelease" in admin and "LoadCurrentInactive(prerequisite" in admin)
check("LAUNCH-23-physical-zero-independent-release", all(s in admin for s in ("producer.Produce", "zeros.Persist", "issuer.Issue", "PersistApprovedRelease", "MvpDecodeReleaseBundle")))
check("LAUNCH-24-no-silent-governance-in-D1", ".Provision(" not in code(port + launch) and "governance.Provision" in admin)
check("fresh-setup-ack-required", "g_setup_armed=false; g_setup_attempted=false" in setup_wrapper and "CHARTEVENT_KEYDOWN" in setup_wrapper and "g_ack=false; g_consumed=false" in admin_wrapper)
callback = launch[launch.index("void ObserveCallbackOnly("):]
check("LAUNCH-20-21-callback-no-dispatch", "m_runner.OnTradeTransaction" in callback and "Run(" not in code(callback) and "SubmitExactlyOnce(" not in code(callback))
check("LAUNCH-25-D6-read-port-only", "m_gate.ConsumeRecovery" in launch and runner.index("authority.ReloadAndReconcileD6") < runner.index("authority.CollectReadOnlyPreflight"))
check("LAUNCH-26-D6-full-readback", all(s in port for s in ("claims.ReloadClaim", "ownership_loader.ReloadCurrent", "pin_authority.Load", "governance_authority.Load", "request_set.ReadState", "terminal_readback_verified=true")))
check("LAUNCH-27-no-reconstructed-grant", "evidence.claim_granted_now=false" in port and "reloaded.claim_granted_now" in port)
check("LAUNCH-29-no-negative-authority", '"NEGATIVE_AUTHORITY_NOT_PROVEN_FOR_MVP_DEMO"' in port and "candidate.negative_evidence_present=false" in port)
check("LAUNCH-30-31-no-binding-stubs", "provider_binding_required_before_run" not in wrapper and "OBSERVATION_NOT_BOUND" not in wrapper)
check("evidence-native-source-not-input", "SWV5S5_MVP_ATTENDED_BUILT_SOURCE" in wrapper and "input string source_head" not in wrapper and "rev-parse HEAD" in read(tests / "Build-AttendedLaunch.ps1"))
check("nonimmutable-build-fails-closed", "NONIMMUTABLE_BUILD_FAIL_CLOSED" in wrapper and "SWV5S5_MVP_ATTENDED_CLEAN_SOURCE" in setup_wrapper + admin_wrapper)
check("evidence-unknown-is-not-zero-proof", "broker_observation_taken" in runner and "authority_readback_complete" in port and "e.submission_authority_state=-1" in port)
check("no-test-import-in-production", not re.search(r'#include\s+"[^"\n]*(?:Tests|TestFixtures|ReferenceValidators)', launch + seed + gate + admin + port))
check("no-native-retry-or-async", not re.search(r'\b(?:OrderSendAsync|CTrade|PositionOpen|PositionClose)\b', code(launch + admin + port + wrapper)))
sites = []
for path in (root / "ExecutionLayer").rglob("*.mqh"):
    if re.search(r'\bOrderSend\s*\(', code(read(path))): sites.append(path)
check("LAUNCH-32-one-production-ordersend", len(sites) == 1 and sites[0].name == "SW_V5_S5_F_BrokerPlatformBoundary.mqh")
# Exact native binding diff audit, not a general exception for Broker changes.
broker_path = "FusionProV5/ExecutionLayer/BrokerAdapter/SW_V5_S5_F_BrokerPlatformBoundary.mqh"
old = git("show", f"{baseline}:{broker_path}")
current = read(repo / broker_path)
expected = old.replace("environment.account_mode=(SWV5_AccountPositionMode)AccountInfoInteger(ACCOUNT_MARGIN_MODE);",
    "environment.account_mode=SWV5S5_F_NativeAccountMode(AccountInfoInteger(ACCOUNT_MARGIN_MODE));")
current = re.sub(r'SWV5_AccountPositionMode SWV5S5_F_NativeAccountMode\(const long native_mode\)\s*\{.*?\n\}', '', current, count=1, flags=re.S)
current = re.sub(r'bool ObserveEnvironment\(const string symbol,SWV5S5_F_AdapterEnvironment &environment\) const\s*\{ return CaptureEnvironment\(symbol,environment\); \}', '', current, count=1)
check("broker-only-explicit-enum-translation-and-read-accessor", re.sub(r'\s+', '', code(current)) == re.sub(r'\s+', '', code(expected)))
changed = git("diff", "--name-only", baseline).splitlines()
for prefix in ("FusionProV5/ProductionArchitecture/", "FusionProV5/ExecutionLayer/Contracts/", "FusionProV5/Engines/",
               "FusionProV5/Indicators/", "FusionProV5/Decision/", "FusionProV5/Orchestration/", "FusionProV5/Dashboard/"):
    check("frozen-unchanged-" + prefix, not any(p.startswith(prefix) for p in changed))
check("no-other-broker-change", not any(p.startswith("FusionProV5/ExecutionLayer/BrokerAdapter/") and p != broker_path for p in changed))
check("no-frozen-root-manifest-change", not any('/' not in p and p.endswith('.mq5') for p in changed))
failed = [name for name, ok in checks if not ok]
quote_platform = read(runtime / "SW_V5_S5_MvpReadOnlyPlatform.mqh")
quote_tests = read(tests / "SW_V5_S5_MvpNativeQuoteAssertions.mqh")
native_quote = quote_platform[quote_platform.index("class SWV5S5_MvpMt5ReadOnlyPlatform"):]
native_quote = native_quote[native_quote.index("virtual bool CaptureMarketQuote"):native_quote.index("virtual bool CaptureProfile")]
check("QUOTE-19-no-caller-market-fabrication", "invocation.requested_price" not in code(port))
check("QUOTE-native-single-tick-read", "SymbolInfoTick(symbol,tick)" in native_quote and "quote.bid=tick.bid" in native_quote and "quote.ask=tick.ask" in native_quote)
check("QUOTE-readonly-no-mutation", not re.search(r'\b(?:OrderSend|OrderSendAsync|DatabaseExecute|DatabaseOpen|FileOpen|SymbolSelect|ChartSet\w*)\s*\(', code(native_quote)))
check("QUOTE-event-capture-before-decision", launch.index("m_platform.CaptureMarketQuote") < launch.index("m_orchestrator.Evaluate("))
check("QUOTE-no-silent-event-replacement", "m_quote.tick_time_msc!=m_seed.event_quote.tick_time_msc" in port and "MathAbs(m_quote.ask-m_seed.event_quote.ask)>quote_tolerance" in port)
check("QUOTE-time-symbol-source-shape", all(s in quote_platform for s in ("q.tick_time!=event_at", "q.observed_at!=event_at", "q.symbol!=symbol", "q.source!=SWV5_AUTHORITY_LIVE_BROKER_STATE", "q.ask<q.bid")))
check("QUOTE-canonical-tick-check", "MathRound(q.ask/tick_size)" in quote_platform and "tick_size*1e-6" in quote_platform)
check("QUOTE-native-entry-and-protection", "unit.raw_price=q.ask" in quote_platform and "stop>=q.ask" in quote_platform and "target<=q.ask" in quote_platform)
check("QUOTE-unit-feeds-all-authorities", "increasing.normalized=m_normalized" in port and "m_risk_input.intent.normalized_price=m_normalized.price" in port and "command.price=m_normalized.price" in port)
check("QUOTE-no-observer-constants", not any(s in code(port + launch + quote_platform) for s in ("4123.334", "4123.502", "168")))
check("QUOTE-nontrivial-regression", "200.0*spec.tick_size" in quote_tests and "invocation.requested_price=tick.ask+10.0" in read(tests / "SW_V5_S5_MvpAttendedLaunchAssertions.mqh"))
seam = read(root / "Tests/Sprint5MvpD1Authorities/SW_V5_S5_MvpD1AuthorityAssertions.mqh")
seam = seam[seam.index("class SWV5S5_MvpD1PersistedEvidenceBoundary"):seam.index("class SWV5S5_MvpD1RecoveryReadPort")]
check("QUOTE-test-seam-no-native-send", "last_command=command" in seam and not re.search(r'\b(?:OrderSend|OrderSendAsync|SubmitWithCurrentClaim)\s*\(', code(seam)))
failed = [name for name, ok in checks if not ok]
print(f"ATTENDED_SOURCE_SUMMARY|total={len(checks)}|passed={len(checks)-len(failed)}|failed={len(failed)}|mql_executed=false")
if failed: raise SystemExit(', '.join(failed))
