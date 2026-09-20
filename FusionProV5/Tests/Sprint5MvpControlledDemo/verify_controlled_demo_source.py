#!/usr/bin/env python3
"""Deterministic source/isolation checks for the Controlled Demo gate."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
CONTROL = ROOT / "ExecutionLayer" / "ControlledDemo"
TESTS = ROOT / "Tests" / "Sprint5MvpControlledDemo"
SETUP = (CONTROL / "SW_V5_S5_MvpManualDemoSetup.mqh").read_text(encoding="utf-8")
RUNNER = (CONTROL / "SW_V5_S5_MvpControlledDemoRunner.mqh").read_text(encoding="utf-8")
WRAPPER = (TESTS / "SW_V5_S5_MVP_CONTROLLED_DEMO_RUNNER.mq5").read_text(encoding="utf-8")
AUTHORITY = (ROOT / "ExecutionLayer" / "RuntimeAuthority" / "SW_V5_S5_MvpPermitClaimAuthorities.mqh").read_text(encoding="utf-8")

checks = []
def check(name, condition):
    checks.append((name, bool(condition)))
    print(f"CONTROLLED_DEMO_SOURCE|{name}|{'PASS' if condition else 'FAIL'}")

def code_occurrences(text, token):
    lines = []
    for raw in text.splitlines():
        line = raw.split("//", 1)[0]
        if token in line:
            lines.append(line)
    return lines

check("SETUP-NO-BROKER-ADAPTER-INCLUDE", "BrokerAdapter" not in SETUP)
check("SETUP-NO-SUBMIT-DEPENDENCY", not code_occurrences(SETUP, "SubmitExactlyOnce"))
check("SETUP-NO-ORDER-SEND", not code_occurrences(SETUP, "OrderSend("))
check("RUNNER-NO-RAW-ORDER-SEND", not code_occurrences(RUNNER, "OrderSend("))
check("RUNNER-NO-ORDER-SEND-ASYNC", not code_occurrences(RUNNER, "OrderSendAsync"))
check("RUNNER-NO-CTRADE", not code_occurrences(RUNNER, "CTrade"))
check("DEFAULT-MODE-PREFLIGHT", "invocation.mode=MODE_PREFLIGHT" in RUNNER and "runner_mode=MODE_PREFLIGHT" in WRAPPER)
check("DEFAULT-ARM-FALSE", "armed_for_demo_submission=false" in RUNNER and "armed_for_demo_submission=false" in WRAPPER)
check("OPERATOR-CONFIRM-BEFORE-LATCH", RUNNER.index("operator_confirmed_before_claim") < RUNNER.index("m_host_one_shot_consumed=true"))
check("LATCH-BEFORE-CLAIM", RUNNER.index("m_host_one_shot_consumed=true") < RUNNER.index("authority.ClaimPhysicalNow"))
check("CLAIM-BEFORE-BOUNDARY", RUNNER.index("authority.ClaimPhysicalNow") < RUNNER.index("submission_boundary.SubmitExactlyOnce"))
check("NO-RETRY-LOOP", "while(" not in RUNNER and "for(" not in RUNNER[RUNNER.index("bool Run("):])
check("D6-BEFORE-PREFLIGHT-AND-SUBMIT", RUNNER.index("MODE_D6_RECOVER") < RUNNER.index("submission_boundary.SubmitExactlyOnce"))
check("EVENTS-NON-AUTHORITATIVE", "bool OnTick(void) { return false; }" in RUNNER and "bool OnTimer(void) { return false; }" in RUNNER)
check("CALLBACK-OBSERVATION-ONLY", "authority.ObserveCallbackOnly" in RUNNER)
check("EVIDENCE-NO-AUTH-REFERENCE", "authentication_reference" not in RUNNER)
check("OWNERSHIP-PHYSICAL-FORMAT-VERSIONED", "SWV5-MVP-OWNERSHIP-LEASE-PHYSICAL-V1" in AUTHORITY)
check("OWNERSHIP-PUBLISH-COMPLETE-TYPED-PAYLOAD", "SWV5S5_MvpEncodeOwnershipLeasePhysical(lease,payload)" in AUTHORITY)
check("OWNERSHIP-ROW-DIGEST-REMAINS-PROJECTION", "view.projection_digest,payload,updated_at,committed" in AUTHORITY)
check("OWNERSHIP-TYPED-LOAD-API", "bool LoadCurrentLease(" in AUTHORITY and "SWV5S5_MvpDecodeOwnershipLeasePhysical" in AUTHORITY)
check("OWNERSHIP-LOAD-REDERIVES-PROJECTION", "SWV5S5_DeriveLeaseProjection(view)" in AUTHORITY and "view.projection_digest!=row.payload_digest" in AUTHORITY)
check("OWNERSHIP-LOAD-CHECKS-STATE", "row.state!=(int)decoded.status" in AUTHORITY)
check("OWNERSHIP-LOAD-CHECKS-STORE-REVISION", "expected_store_revision!=row.store_revision" in AUTHORITY)
check("OWNERSHIP-LOAD-CHECKS-EXACT-FENCE", "SWV5S5_EqualFence(decoded.fence,expected_fence)" in AUTHORITY)
check("D6-USES-TYPED-PERSISTED-LEASE", "authority.LoadCurrentLease" in RUNNER)
check("D6-REVALIDATES-CURRENT-LIVENESS", "SWV5S5_MvpLeaseCurrentForClock" in RUNNER)

runtime_control_text = "\n".join(
    path.read_text(encoding="utf-8")
    for folder in (ROOT / "ExecutionLayer" / "RuntimeAuthority", CONTROL)
    for path in folder.rglob("*.mqh")
)
check("RUNTIME-AUTHORITY-CONTROLLED-DEMO-NO-RAW-ORDER-SEND", not code_occurrences(runtime_control_text, "OrderSend("))
check("RUNTIME-AUTHORITY-CONTROLLED-DEMO-NO-ASYNC", not code_occurrences(runtime_control_text, "OrderSendAsync"))
check("RUNTIME-AUTHORITY-CONTROLLED-DEMO-NO-CTRADE", not code_occurrences(runtime_control_text, "CTrade"))

production = ROOT / "ExecutionLayer"
order_send_sites = []
for path in production.rglob("*.mqh"):
    for lineno, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        line = raw.split("//", 1)[0]
        if re.search(r"\bOrderSend\s*\(", line):
            order_send_sites.append((path.relative_to(ROOT).as_posix(), lineno))
check("GLOBAL-ONE-PRODUCTION-ORDER-SEND", len(order_send_sites) == 1)
check("ORDER-SEND-REMAINS-PLATFORM-BOUNDARY", len(order_send_sites) == 1 and order_send_sites[0][0].endswith("BrokerAdapter/SW_V5_S5_F_BrokerPlatformBoundary.mqh"))

failed = [name for name, ok in checks if not ok]
print(f"CONTROLLED_DEMO_SOURCE_SUMMARY|total={len(checks)}|passed={len(checks)-len(failed)}|failed={len(failed)}")
if failed:
    raise SystemExit("failed: " + ", ".join(failed))
