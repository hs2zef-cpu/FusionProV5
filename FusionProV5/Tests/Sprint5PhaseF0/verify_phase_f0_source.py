"""TEST ONLY / F0. Static scope and safety audit; no Terminal access."""
from __future__ import annotations

import json
from pathlib import Path
import re


HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]


def verify() -> dict:
    probe = (HERE / "SW_V5_S5_PHASE_F0_DEMO_PROFILE_PROBE.mq5").read_text(encoding="utf-8-sig")
    query_probe = (HERE / "SW_V5_S5_PHASE_F0_QUERY_PROBE.mq5").read_text(encoding="utf-8-sig")
    compile_manifest = (HERE / "SW_V5_S5_PHASE_F0_COMPILE.mq5").read_text(encoding="utf-8-sig")
    contracts = (HERE / "SW_V5_S5_PhaseF0_EvidenceContracts.mqh").read_text(encoding="utf-8-sig")
    controls = (HERE / "verify_phase_f0_negative_controls.py").read_text(encoding="utf-8-sig")
    combined = probe + compile_manifest + contracts
    required_markers = ("TEST ONLY", "F0", "NOT FOR PRODUCTION")
    assert all(marker in probe for marker in required_markers)
    assert "InpOperatorAttestsAttendedDemo=false" in probe
    assert "InpArmExactlyOneMarketSend=false" in probe
    assert "ACCOUNT_TRADE_MODE_DEMO" in probe and "ACCOUNT_MARGIN_MODE_RETAIL_HEDGING" in probe
    assert probe.count("OrderSend(") == 1
    assert "OrderSend(" not in query_probe and "HistorySelect(" in query_probe
    assert all(token in query_probe for token in ("PositionsTotal(","OrdersTotal(","HistoryOrdersTotal(","HistoryDealsTotal("))
    assert not re.search(r"\b(?:OnTick|OnTimer|OrderSendAsync|CTrade)\s*\(", probe)
    assert not re.search(r"\b(?:ORDER_TYPE_BUY_LIMIT|ORDER_TYPE_SELL_LIMIT|ORDER_TYPE_BUY_STOP|ORDER_TYPE_SELL_STOP|TRADE_ACTION_PENDING|TRADE_ACTION_MODIFY|TRADE_ACTION_REMOVE)\b", probe)
    assert all(f'"NC-{index:02d}"' in controls for index in range(1, 16))
    assert "#error" in contracts and "SWV5S5_F0_TEST_ONLY_BUILD" in contracts
    assert "#define SWV5S5_F0_TEST_ONLY_BUILD" in compile_manifest
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
            "negative_control_definitions": 15, "production_reverse_dependencies": production_reverse,
            "forbidden_scope_paths": forbidden_paths}


if __name__ == "__main__":
    result = verify()
    print(json.dumps(result, sort_keys=True, separators=(",", ":")))
    if result["status"] != "PASS":
        raise SystemExit(1)
