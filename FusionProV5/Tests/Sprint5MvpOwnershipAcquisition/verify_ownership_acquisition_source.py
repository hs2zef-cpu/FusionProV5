from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
production = ROOT / "FusionProV5" / "ExecutionLayer" / "RuntimeAuthority" / "SW_V5_S5_MvpOwnershipAuthority.mqh"
setup = ROOT / "FusionProV5" / "ExecutionLayer" / "ControlledDemo" / "SW_V5_S5_MvpManualDemoSetup.mqh"
text = production.read_text(encoding="utf-8")
setup_text = setup.read_text(encoding="utf-8")

checks = {
    "OA-SRC-01-no-reference-lease-import": "ReferenceLeaseStore" not in text,
    "OA-SRC-02-no-fake-clock-import": "FakeAuthoritativeClock" not in text,
    "OA-SRC-03-no-OrderSend": "OrderSend" not in text + setup_text,
    "OA-SRC-04-no-OrderSendAsync": "OrderSendAsync" not in text + setup_text,
    "OA-SRC-05-no-CTrade": "CTrade" not in text + setup_text,
    "OA-SRC-06-no-TimeLocal": "TimeLocal" not in text,
    "OA-SRC-07-no-TimeTradeServer": "TimeTradeServer" not in text,
    "OA-SRC-08-no-GetTickCount": "GetTickCount" not in text,
    "OA-SRC-09-exact-clock-profile": "SWV5-MQL5-TIMECURRENT-LAST-KNOWN-SERVER-V1" in text,
    "OA-SRC-10-current-symbol-OnTick-source": "ObserveFromCurrentSymbolOnTick" in text,
    "OA-SRC-11-TimeCurrent-single-sampler": text.count("TimeCurrent()") == 1,
    "OA-SRC-12-takeover-not-implemented": "bool Takeover(" not in text,
    "OA-SRC-13-heartbeat-not-implemented": "bool Heartbeat(" not in text,
    "OA-SRC-14-physical-CAS": "CompareAndSetWithGuard" in text,
    "OA-SRC-15-fresh-after-open": "m_fresh_since_open=false" in text,
    "OA-SRC-16-no-broker-mutation": all(x not in text + setup_text for x in ("PositionOpen", "PositionClose", "OrderDelete")),
}

for name, passed in checks.items():
    print(f"{name}|{'PASS' if passed else 'FAIL'}")
failed = [name for name, passed in checks.items() if not passed]
print(f"OWNERSHIP_SOURCE_SUMMARY|total={len(checks)}|passed={len(checks)-len(failed)}|failed={len(failed)}")
raise SystemExit(1 if failed else 0)
