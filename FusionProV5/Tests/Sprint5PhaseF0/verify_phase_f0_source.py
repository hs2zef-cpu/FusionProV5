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
    positive_control_probe = (HERE / "SW_V5_S5_PHASE_F0_QUERY_POSITIVE_CONTROL.mq5").read_text(encoding="utf-8-sig")
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
    preserved_profile_tokens = ("ACCOUNT_COMPANY", "ACCOUNT_SERVER", "InpExpectedServer",
                                "TERMINAL_CONNECTED", "TERMINAL_BUILD", "__MQLBUILD__", "_Symbol",
                                "SYMBOL_VOLUME_MIN", "SYMBOL_FILLING_MODE",
                                "InpMeasuredFilling=ORDER_FILLING_FOK",
                                "request.volume=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);",
                                "request.type_filling=InpMeasuredFilling;")
    assert all(token in probe for token in preserved_profile_tokens)
    permission_properties = ("TERMINAL_TRADE_ALLOWED", "MQL_TRADE_ALLOWED",
                             "ACCOUNT_TRADE_ALLOWED", "ACCOUNT_TRADE_EXPERT")
    permission_diagnostics = ("terminal_trade_not_allowed", "mql_program_trade_not_allowed",
                              "account_trade_not_allowed", "account_expert_trade_not_allowed")
    assert all(token in probe for token in permission_properties)
    assert all(probe.count(token) == 1 for token in permission_properties)
    assert all(token in probe for token in permission_diagnostics)
    assert "F0_PERMISSIONS|" in probe and "snapshot_at_init=YES" in probe
    assert all(f"bool              {field};" in contracts for field in
               ("terminal_trade_allowed", "mql_trade_allowed",
                "account_trade_allowed", "account_trade_expert"))
    assert probe.count("g_send_attempted=true;") == 1
    guard_call = probe.index("if(g_send_attempted || !SWV5S5_F0EnvironmentPermitsSingleProbe(")
    send_attempt_assignment = probe.index("g_send_attempted=true;")
    order_send_call = probe.index("OrderSend(")
    assert guard_call < send_attempt_assignment < order_send_call
    assert probe.count("OrderSend(") == 1
    assert "OrderSend(" not in query_probe and "HistorySelect(" in query_probe
    assert "OrderSend(" not in positive_control_probe
    assert "HistorySelect(" in positive_control_probe
    assert "HistorySelectByPosition(" in positive_control_probe
    assert all(token in positive_control_probe for token in
               ("WIDE_INCLUDE_FULL", "WIDE_INCLUDE_REPEAT_FULL",
                "ENTRY_SECOND_INCLUDE_FULL", "BEFORE_ENTRY_EXCLUDE_FULL",
                "AFTER_ENTRY_EXCLUDE_FULL", "CLEANUP_SECOND_INCLUDE_FULL",
                "WIDE_INCLUDE_DEPTH_1", "WIDE_INCLUDE_DEPTH_2",
                "POSITION_FILTER_KNOWN", "POSITION_FILTER_UNKNOWN",
                "pagination_api=NONE_EXPOSED", "completeness=UNPROVEN",
                "F0_PC_ATTEST", "ACCOUNT_COMPANY", "ACCOUNT_SERVER",
                "ACCOUNT_TRADE_MODE", "ACCOUNT_MARGIN_MODE", "TERMINAL_BUILD",
                "__MQLBUILD__", "TERMINAL_CONNECTED"))
    assert not re.search(r"\b(?:OrderSend|OrderSendAsync|CTrade|PositionOpen|FileOpen|WebRequest)\s*\(",
                         positive_control_probe)
    assert '#include "../../Configuration/SW_V5_RuntimeIdentityProfile.mqh"' in query_probe
    assert all(token in query_probe for token in
               ("RUNTIME_MAGIC_MATCH_NOT_SOLE_CORRELATION_AUTHORITY",
                "FIXTURE_REFERENCE_MAGIC_NON_RUNTIME",
                "MAGIC_ZERO_ACCOUNT_BALANCE_OR_NON_STRATEGY", "UNRELATED_MAGIC"))
    assert all(token in query_probe for token in ("PositionsTotal(","OrdersTotal(","HistoryOrdersTotal(","HistoryDealsTotal("))
    assert not re.search(r"\b(?:OnTick|OnTimer|OnChartEvent|OnBookEvent|OrderSendAsync|CTrade)\s*\(", probe)
    assert not re.search(r"\b(?:ORDER_TYPE_BUY_LIMIT|ORDER_TYPE_SELL_LIMIT|ORDER_TYPE_BUY_STOP|ORDER_TYPE_SELL_STOP|TRADE_ACTION_PENDING|TRADE_ACTION_MODIFY|TRADE_ACTION_REMOVE)\b", probe)
    assert all(f'"NC-{index:02d}"' in controls for index in range(1, 25))
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
            "read_only_positive_control_probe": True,
            "runtime_strategy_magic": runtime_magic,
            "runtime_magic_executable_literal_paths": executable_literal_paths,
            "permission_properties": list(permission_properties),
            "permission_diagnostics": list(permission_diagnostics),
            "permission_properties_read_once": True,
            "precall_guard_order_verified": True,
            "preserved_profile_tokens": list(preserved_profile_tokens),
            "negative_control_definitions": 24, "production_reverse_dependencies": production_reverse,
            "forbidden_scope_paths": forbidden_paths}


if __name__ == "__main__":
    result = verify()
    print(json.dumps(result, sort_keys=True, separators=(",", ":")))
    if result["status"] != "PASS":
        raise SystemExit(1)
