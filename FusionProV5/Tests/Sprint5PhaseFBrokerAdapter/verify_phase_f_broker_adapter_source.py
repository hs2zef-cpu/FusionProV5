#!/usr/bin/env python3
"""TEST ONLY / NOT FOR PRODUCTION / NO BROKER ACCESS."""
from pathlib import Path
import re
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[3]
BASE = "4e5a785f77d291c2e43499da9da9c5fb7572f5cb"
ADAPTER = ROOT / "FusionProV5/ExecutionLayer/BrokerAdapter"
PLATFORM = ADAPTER / "SW_V5_S5_F_BrokerPlatformBoundary.mqh"
CORE = ADAPTER / "SW_V5_S5_F_BrokerAdapterCore.mqh"
INTEGRATION = ADAPTER / "SW_V5_S5_F_BrokerReconciliationIntegration.mqh"
TYPES = ADAPTER / "SW_V5_S5_F_BrokerAdapterTypes.mqh"
TEST_ROOT = ROOT / "FusionProV5/Tests/Sprint5PhaseFBrokerAdapter"
MQL_ASSERTIONS = TEST_ROOT / "SW_V5_S5_PhaseF_BrokerAdapterAssertions.mqh"
MUTATION_MATRIX = TEST_ROOT / "MUTATION_CREDIBILITY_MATRIX.md"
CLEARING_PACKAGE = TEST_ROOT / "AUDITOR_CLEARING_PACKAGE.md"

DIRECT_PLATFORM_CALLS = (
    "OrderSend(", "AccountInfoInteger(", "AccountInfoString(", "TerminalInfoInteger(",
    "MQLInfoInteger(", "SymbolInfoInteger(", "SymbolInfoDouble(", "PositionsTotal(",
    "PositionGetTicket(", "OrdersTotal(", "OrderGetTicket(", "HistorySelect(",
    "HistoryOrdersTotal(", "HistoryOrderGetTicket(", "HistoryDealsTotal(",
    "HistoryDealGetTicket(", "TimeTradeServer(",
)
FORBIDDEN = ("OrderSendAsync(", "CTrade", "PositionOpen(", "PositionClose(")
REQUIRED_CORE = (
    "SWV5S5_ValidateAuthoritativeClaimResult", "claim_granted_now",
    "EPHEMERAL_CLAIM_NOT_GRANTED_NOW", "TRADING_PERMISSION_NOT_POSITIVELY_ATTESTED",
    "SWV5_RUNTIME_STRATEGY_MAGIC", "final_confirmation=false", "retry_allowed=false",
    "SWV5S5_F_DeriveAdapterEnvironmentDigest", "m_send_consumed=true",
    "SWV5S5_F_AdapterValidatePublication", "expected_store_revision",
    "proposed_reconciliation_revision==publication.expected_reconciliation_revision+1",
    "SWV5S5_F_AdapterCanonicalGridEqual", "SWV5S5_F_AdapterMarketProtectionValid",
    "SWV5S5_F_AdapterResolveFilling", "SWV5S5_F_DeriveAdapterWirePayloadDigest",
    "SWV5S5_F_AdapterValidateFinalEnvironment", "SWV5S5_F_AdapterBrokerQueryShapeComplete",
    "SWV5S5_F_AdapterExecutionQueryShapeComplete", "SWV5S5_F_AdapterEvidenceSourcesIndependent",
)
REQUIRED_INTEGRATION = (
    "SWV5S5_F_AdapterBuildPositiveEvidence", "SWV5S5_F_AdapterBuildNegativeObservation",
    "ordered_deal_set_digest", "magic_used_as_sole_authority=false",
    "comment_used_as_sole_authority=false", "SWV5S5_F_EvaluateReconciliation",
    "ISWV5S5FReconciliationPublicationAuthority", "TryPublishReconciliation",
    "ResolveCallbackBinding", "AdapterBuildExecutionPendingSnapshot",
    "capability_proof_digest_consumed", "execution_sequence_authority_id", "reported_total",
)


def git(*args: str) -> list[str]:
    return subprocess.check_output(["git", *args], cwd=ROOT, text=True).splitlines()


def main() -> int:
    failures: list[str] = []
    files = list(ADAPTER.glob("*.mqh"))
    platform_text = PLATFORM.read_text(encoding="utf-8")
    core_text = CORE.read_text(encoding="utf-8")
    integration_text = INTEGRATION.read_text(encoding="utf-8")
    all_text = "\n".join(p.read_text(encoding="utf-8") for p in files)
    mql_text = MQL_ASSERTIONS.read_text(encoding="utf-8")
    mutation_matrix_text = MUTATION_MATRIX.read_text(encoding="utf-8")
    clearing_text = CLEARING_PACKAGE.read_text(encoding="utf-8")

    if platform_text.count("OrderSend(") != 1:
        failures.append("exactly-one-platform-ordersend-source-site")
    submit = platform_text.index("bool SubmitExactlyOnce")
    preflight = platform_text.index("SWV5S5_F_AdapterValidatePreflight", submit)
    send = platform_text.index("OrderSend(", submit)
    if not submit < preflight < send:
        failures.append("claim-preflight-before-send")
    submit_end = platform_text.index("bool CaptureCallback", submit)
    submit_body = platform_text[submit:submit_end]
    final_sample = submit_body.find("CaptureEnvironment(command.expected_profile.symbol,final_environment)")
    final_attest = submit_body.find("SWV5S5_F_AdapterValidateFinalEnvironment")
    wire_digest = submit_body.find("SWV5S5_F_DeriveAdapterWirePayloadDigest")
    sole_send = submit_body.find("OrderSend(")
    if not 0 < final_sample < final_attest < wire_digest < sole_send:
        failures.append("final-resample-wire-digest-send-order")
    post_digest = submit_body[wire_digest:sole_send]
    if "request." in post_digest or "Normalize" in post_digest or "NormalizeDouble" in post_digest:
        failures.append("post-digest-request-mutation-or-normalization")
    if submit_body.count("OrderSend(") != 1 or all_text.count("SubmitExactlyOnce(") != 1 or \
            "for(" in submit_body or "while(" in submit_body:
        failures.append("send-retry-or-reentry-shape")
    if all_text.count("m_send_consumed=false") != 1 or submit_body.find("m_send_consumed=true") > preflight-submit:
        failures.append("send-fuse-not-consumed-before-preflight")
    for path in files:
        if path == PLATFORM:
            continue
        text = path.read_text(encoding="utf-8")
        for token in DIRECT_PLATFORM_CALLS:
            if token in text:
                failures.append(f"platform-leak:{path.name}:{token}")
    for token in FORBIDDEN:
        if token in all_text:
            failures.append(f"forbidden-api:{token}")
    for token in REQUIRED_CORE:
        if token not in core_text and token not in platform_text:
            failures.append(f"missing-core:{token}")
    for token in REQUIRED_INTEGRATION:
        if token not in integration_text and token not in TYPES.read_text(encoding="utf-8"):
            failures.append(f"missing-integration:{token}")
    if "retry_allowed=true" in all_text:
        failures.append("retry-enabled")
    if all_text.count("1179670069"):
        failures.append("runtime-magic-literal-duplicated")
    if "OnTradeTransaction(" in all_text:
        failures.append("event-handler-wired")
    if "capability_flag==1" not in core_text or "capability_flag==2" not in core_text or \
            "capability_flag==3" in core_text:
        failures.append("filling-not-exact-one-to-one")
    if "candidate.volume==" in core_text or "candidate.price==" in core_text:
        failures.append("raw-double-authority-comparison")
    if re.search(r"capability_proof\.[A-Za-z0-9_]+\s*=(?!=)",platform_text) or \
            re.search(r"(?<!const )SWV5S5_F_CapabilityProof\s*&",all_text):
        failures.append("adapter-capability-proof-authorship")
    if "broker_sequence_authority_id!=execution.execution_sequence_authority_id" not in core_text:
        failures.append("broker-execution-sequence-authority-not-independent")
    if "reported_total!=(uint)ArraySize" not in core_text or "row_read_failures!=0" not in core_text:
        failures.append("query-row-omission-not-fail-closed")
    if "LoadCallbackEvidence(const SWV5S5_F_ReconciliationBinding &binding" not in TYPES.read_text(encoding="utf-8") or \
            "uint &reported_total" not in TYPES.read_text(encoding="utf-8"):
        failures.append("callback-store-total-not-observable")

    required_mql_calls = (
        "SWV5S5_F_AdapterValidatePreflight", "SWV5S5_ValidateAuthoritativeClaimResult",
        "SWV5S5_F_AdapterValidateFinalEnvironment", "SWV5S5_F_AdapterClassifySync",
        "SWV5S5_F_AdapterObservationKind", "SWV5S5_F_EvaluateReconciliation",
        "SWV5S5_F_AdapterResolveFilling", "SWV5S5_F_DeriveAdapterWirePayloadDigest",
        "SWV5S5_F_AdapterBrokerQueryShapeComplete", "SWV5S5_F_AdapterExecutionQueryShapeComplete",
        "SWV5S5_F_AdapterEvidenceSourcesIndependent",
    )
    mql_ids = set(re.findall(r'"(MQL-[A-Z0-9-]+)"', mql_text))
    if len(mql_ids) != 48:
        failures.append("expanded-real-mql-assertion-count-not-48")
    for token in required_mql_calls:
        if token not in mql_text:
            failures.append(f"missing-real-mql-call:{token}")
    if "OrderSend(" in mql_text:
        failures.append("mql-assertion-harness-broker-call")

    mutation_ids = re.findall(r"\| (MC-[A-Z0-9-]+) \|", mutation_matrix_text)
    if len(mutation_ids) != 17 or len(set(mutation_ids)) != 17:
        failures.append("mutation-credibility-matrix-not-17-unique-rows")
    for marker in ("unsafe_result_observed", "Detector provenance", "Target path reached",
                   "unrelated earlier guard", "MC-TOCTOU-WINDOW", "MC-POSTDIGEST-NORMALIZE",
                   "MC-ADAPTER-SELFATTEST", "MC-FILLING-COERCION", "MC-QUERY-ROW-OMISSION"):
        if marker not in mutation_matrix_text:
            failures.append(f"mutation-mapping-marker-missing:{marker}")
    for marker in ("F-1 NO_CALL", "F-10 read-path independence", "exactly one `OrderSend(`",
                   "REAL_MQL_EXECUTED", "PYTHON_ORACLE", "PYTHON_MUTATION", "STATIC_SOURCE",
                   "NOT_EXECUTABLE_WITHOUT_BROKER", "broker_calls=0"):
        if marker not in clearing_text:
            failures.append(f"auditor-clearing-marker-missing:{marker}")

    frozen = (
        "FusionProV5/ProductionArchitecture/", "FusionProV5/SignalEngine/",
        "FusionProV5/DecisionEngine/", "FusionProV5/Engines/", "FusionProV5/Dashboard/",
        "FusionProV5/ExecutionLayer/Contracts/", "FusionProV5/ExecutionLayer/Coordinator/",
        "FusionProV5/ExecutionLayer/PersistenceReference/", "FusionProV5/Tests/Sprint5PhaseB/",
        "FusionProV5/Tests/Sprint5PhaseC/", "FusionProV5/Tests/Sprint5PhaseD/",
        "FusionProV5/Tests/Sprint5PhaseE/", "FusionProV5/Tests/Sprint5PhaseF/",
    )
    changed = git("diff", "--name-only", BASE, "--") + git("ls-files", "--others", "--exclude-standard")
    for path in changed:
        if path.startswith(frozen):
            failures.append(f"frozen-change:{path}")

    contract_path = "FusionProV5/ExecutionLayer/Contracts/SW_V5_S5_ReconciliationEvidenceContract.mqh"
    if git("diff", "--name-only", BASE, "--", contract_path):
        failures.append("accepted-contract-mutated")

    checks = (14 + len(DIRECT_PLATFORM_CALLS)*(len(files)-1) + len(FORBIDDEN) +
              len(REQUIRED_CORE) + len(REQUIRED_INTEGRATION) + len(required_mql_calls) + 18)
    print(f"PHASE_F_BROKER_ADAPTER_SOURCE|checks={checks}|failures={len(failures)}|platform_files=1|ordersend_sites={platform_text.count('OrderSend(')}")
    for failure in failures:
        print(f"FAIL|{failure}")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
