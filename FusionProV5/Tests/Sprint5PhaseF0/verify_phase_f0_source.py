"""TEST ONLY / F0. Static scope and safety audit; no Terminal access."""
from __future__ import annotations

import json
from pathlib import Path
import re


HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]


def verify() -> dict:
    identity_path = ROOT / "Configuration" / "SW_V5_RuntimeIdentityProfile.mqh"
    identity = identity_path.read_text(encoding="utf-8-sig")
    probe = (HERE / "SW_V5_S5_PHASE_F0_DEMO_PROFILE_PROBE.mq5").read_text(encoding="utf-8-sig")
    query_probe = (HERE / "SW_V5_S5_PHASE_F0_QUERY_PROBE.mq5").read_text(encoding="utf-8-sig")
    compile_manifest = (HERE / "SW_V5_S5_PHASE_F0_COMPILE.mq5").read_text(encoding="utf-8-sig")
    contracts = (HERE / "SW_V5_S5_PhaseF0_EvidenceContracts.mqh").read_text(encoding="utf-8-sig")
    controls = (HERE / "verify_phase_f0_negative_controls.py").read_text(encoding="utf-8-sig")
    identity_match = re.search(r"const\s+ulong\s+SWV5_RUNTIME_STRATEGY_MAGIC\s*=\s*([0-9]+)\s*;", identity)
    assert identity_match is not None
    runtime_magic = int(identity_match.group(1))
    assert runtime_magic > 0 and runtime_magic.to_bytes(4, "big") == b"FPV5"
    assert runtime_magic not in {5042001, 5005, 550015}
    combined = probe + compile_manifest + contracts
    required_markers = ("TEST ONLY", "F0", "NOT FOR PRODUCTION")
    assert all(marker in probe for marker in required_markers)
    assert "InpOperatorAttestsAttendedDemo=false" in probe
    assert "InpArmExactlyOneMarketSend=false" in probe
    assert "InpFrozenStrategyMagic" not in probe
    assert '#include "../../Configuration/SW_V5_RuntimeIdentityProfile.mqh"' in probe
    assert "request.magic=SWV5_RUNTIME_STRATEGY_MAGIC;" in probe
    assert "ACCOUNT_TRADE_MODE_DEMO" in probe and "ACCOUNT_MARGIN_MODE_RETAIL_HEDGING" in probe
    assert probe.count("OrderSend(") == 1
    assert "OrderSend(" not in query_probe and "HistorySelect(" in query_probe
    assert '#include "../../Configuration/SW_V5_RuntimeIdentityProfile.mqh"' in query_probe
    assert all(token in query_probe for token in
               ("RUNTIME_MAGIC_MATCH_NOT_SOLE_CORRELATION_AUTHORITY",
                "FIXTURE_REFERENCE_MAGIC_NON_RUNTIME",
                "MAGIC_ZERO_ACCOUNT_BALANCE_OR_NON_STRATEGY", "UNRELATED_MAGIC"))
    assert all(token in query_probe for token in ("PositionsTotal(","OrdersTotal(","HistoryOrdersTotal(","HistoryDealsTotal("))
    assert not re.search(r"\b(?:OnTick|OnTimer|OrderSendAsync|CTrade)\s*\(", probe)
    assert not re.search(r"\b(?:ORDER_TYPE_BUY_LIMIT|ORDER_TYPE_SELL_LIMIT|ORDER_TYPE_BUY_STOP|ORDER_TYPE_SELL_STOP|TRADE_ACTION_PENDING|TRADE_ACTION_MODIFY|TRADE_ACTION_REMOVE)\b", probe)
    assert all(f'"NC-{index:02d}"' in controls for index in range(1, 20))
    assert "#error" in contracts and "SWV5S5_F0_TEST_ONLY_BUILD" in contracts
    assert "#define SWV5S5_F0_TEST_ONLY_BUILD" in compile_manifest
    executable_literal_paths = []
    for path in ROOT.rglob("*"):
        if path.suffix.lower() not in {".mq5", ".mqh", ".py", ".ps1"}:
            continue
        if identity_match.group(1) in path.read_text(encoding="utf-8-sig"):
            executable_literal_paths.append(path.relative_to(ROOT).as_posix())
    assert executable_literal_paths == ["Configuration/SW_V5_RuntimeIdentityProfile.mqh"]
    production_reverse = []
    for path in ROOT.rglob("*"):
        if path.suffix.lower() not in {".mq5", ".mqh"} or "Tests" in path.parts:
            continue
        text = path.read_text(encoding="utf-8-sig")
        if "Sprint5PhaseF0" in text or "PhaseF0_EvidenceContracts" in text:
            production_reverse.append(path.relative_to(ROOT).as_posix())
    forbidden_paths = [path.relative_to(ROOT).as_posix() for path in HERE.rglob("*")
                       if path.is_file() and any(part in path.as_posix() for part in ("ProductionArchitecture","Signal","Decision","Engines","Dashboard","V3S"))]
    status = "PASS" if not production_reverse and not forbidden_paths else "FAIL"
    return {"status": status, "mql_runtime_executed": False, "tester_executed": False,
            "attended_demo_executed": False, "broker_invoking_probe_default_armed": False,
            "ordersend_occurrences_in_isolated_probe": probe.count("OrderSend("),
            "read_only_query_probe": True,
            "runtime_strategy_magic": runtime_magic,
            "runtime_magic_executable_literal_paths": executable_literal_paths,
            "negative_control_definitions": 19, "production_reverse_dependencies": production_reverse,
            "forbidden_scope_paths": forbidden_paths}


if __name__ == "__main__":
    result = verify()
    print(json.dumps(result, sort_keys=True, separators=(",", ":")))
    if result["status"] != "PASS":
        raise SystemExit(1)
