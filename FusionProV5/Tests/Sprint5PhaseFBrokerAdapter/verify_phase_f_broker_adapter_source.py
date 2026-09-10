#!/usr/bin/env python3
"""TEST ONLY / NOT FOR PRODUCTION / NO BROKER ACCESS."""
from pathlib import Path
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[3]
BASE = "4e5a785f77d291c2e43499da9da9c5fb7572f5cb"
ADAPTER = ROOT / "FusionProV5/ExecutionLayer/BrokerAdapter"
PLATFORM = ADAPTER / "SW_V5_S5_F_BrokerPlatformBoundary.mqh"
CORE = ADAPTER / "SW_V5_S5_F_BrokerAdapterCore.mqh"
INTEGRATION = ADAPTER / "SW_V5_S5_F_BrokerReconciliationIntegration.mqh"
TYPES = ADAPTER / "SW_V5_S5_F_BrokerAdapterTypes.mqh"

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
)
REQUIRED_INTEGRATION = (
    "SWV5S5_F_AdapterBuildPositiveEvidence", "SWV5S5_F_AdapterBuildNegativeObservation",
    "ordered_deal_set_digest", "magic_used_as_sole_authority=false",
    "comment_used_as_sole_authority=false", "SWV5S5_F_EvaluateReconciliation",
    "ISWV5S5FReconciliationPublicationAuthority", "TryPublishReconciliation",
    "ResolveCallbackBinding", "AdapterBuildExecutionPendingSnapshot",
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

    if platform_text.count("OrderSend(") != 1:
        failures.append("exactly-one-platform-ordersend-source-site")
    submit = platform_text.index("bool SubmitExactlyOnce")
    preflight = platform_text.index("SWV5S5_F_AdapterValidatePreflight", submit)
    send = platform_text.index("OrderSend(", submit)
    if not submit < preflight < send:
        failures.append("claim-preflight-before-send")
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

    checks = 4 + len(DIRECT_PLATFORM_CALLS)*(len(files)-1) + len(FORBIDDEN) + len(REQUIRED_CORE) + len(REQUIRED_INTEGRATION)
    print(f"PHASE_F_BROKER_ADAPTER_SOURCE|checks={checks}|failures={len(failures)}|platform_files=1|ordersend_sites={platform_text.count('OrderSend(')}")
    for failure in failures:
        print(f"FAIL|{failure}")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
