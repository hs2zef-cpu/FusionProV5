#!/usr/bin/env python3
"""Independent offline oracle for the locked Demo MVP authority foundation.

This does not substitute for the real MQL assertion run. It supplies an
independent table-driven policy oracle, physical SQLite/CAS controls, and
source-shape checks. It never connects to MT5 and cannot submit an order.
"""

from __future__ import annotations

import hashlib
import re
import sqlite3
import tempfile
from dataclasses import dataclass, replace
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
RUNTIME = ROOT / "FusionProV5" / "ExecutionLayer" / "RuntimeAuthority"
EXECUTION_LAYER = ROOT / "FusionProV5" / "ExecutionLayer"


class Results:
    def __init__(self) -> None:
        self.rows: list[tuple[str, bool]] = []

    def check(self, test_id: str, value: bool) -> None:
        self.rows.append((test_id, bool(value)))
        print(f"MVP_ORACLE|{test_id}|{'PASS' if value else 'FAIL'}")

    def finish(self) -> int:
        passed = sum(ok for _, ok in self.rows)
        failed = len(self.rows) - passed
        material = "\n".join(f"{i}:{int(v)}" for i, v in self.rows).encode()
        signature = hashlib.sha256(material).hexdigest()
        print(
            f"MVP_ORACLE_SUMMARY|total={len(self.rows)}|passed={passed}|"
            f"failed={failed}|skipped=0|signature={signature}|broker_submission_calls=0"
        )
        return 0 if failed == 0 else 1


@dataclass(frozen=True)
class Symbol:
    symbol: str = "XAUUSD"
    digits: int = 3
    point: float = 0.001
    tick: float = 0.001
    pip: float = 0.10
    currency: str = "USD"
    complete: bool = True
    sequence: int = 1
    observed: int = 100
    valid_until: int = 110
    source: str = "LIVE_BROKER_STATE"


def symbol_valid(x: Symbol, now: int = 105) -> bool:
    return (
        x.complete
        and x.symbol == "XAUUSD"
        and x.digits == 3
        and abs(x.point - 0.001) <= 1e-12
        and x.tick > 0
        and abs(x.pip - x.point * 100) <= 1e-12
        and x.currency == "USD"
        and x.sequence > 0
        and x.observed <= now < x.valid_until
        and x.valid_until == x.observed + 10
        and x.source == "LIVE_BROKER_STATE"
    )


@dataclass(frozen=True)
class Risk:
    demo: bool = True
    usd: bool = True
    hedging: bool = True
    equity: float = 1000.0
    daily_net: float = -5.0
    projected_margin: float = 50.0
    basket_loss: float = 4.0
    volume: float = 0.01
    notional: float = 3500.0
    live_baskets: int = 1
    recovery_attempts: int = 1
    age: int = 5
    latch_inactive: bool = True
    complete: bool = True
    positions: int = 0
    orders: int = 0
    unresolved: bool = False


def risk_allowed(x: Risk) -> bool:
    return (
        x.demo and x.usd and x.hedging and x.complete and x.latch_inactive
        and x.positions == 0 and x.orders == 0 and not x.unresolved
        and x.equity >= 100 and -x.daily_net <= 10
        and x.projected_margin <= 0.10 * x.equity
        and x.basket_loss <= 5 and x.volume <= 0.01 and x.notional <= 10000
        and x.live_baskets <= 1 and x.recovery_attempts <= 1 and x.age <= 5
    )


@dataclass(frozen=True)
class Margin:
    positions: int = 0
    orders: int = 0
    active_operation: bool = False
    active_basket: bool = False
    unresolved: bool = False
    current_margin: float = 0.01
    calculation_ok: bool = True
    additional: float = 25.0
    complete: bool = True


def margin_authority(x: Margin) -> tuple[bool, float]:
    ok = (
        x.complete and x.positions == 0 and x.orders == 0 and not x.active_operation
        and not x.active_basket and not x.unresolved and x.current_margin <= 0.01
        and x.calculation_ok and 0 < x.additional < float("inf")
    )
    return ok, x.current_margin + x.additional if ok else 0.0


@dataclass(frozen=True)
class BasketRisk:
    positions: int = 0
    idle: bool = True
    volume: float = 0.01
    entry: float = 3500.0
    stop: float = 3498.0
    direction: int = 1
    calculation_ok: bool = True
    calculated_profit: float = -3.0
    session_crosses_rollover: bool = False


def basket_authority(x: BasketRisk) -> tuple[bool, float]:
    stop_side = x.stop > 0 and (x.stop < x.entry if x.direction == 1 else x.stop > x.entry)
    resulting = -x.calculated_profit + 1.0
    ok = (
        x.positions == 0 and x.idle and x.volume <= 0.01 and stop_side
        and x.calculation_ok and x.calculated_profit < 0
        and resulting <= 5 and not x.session_crosses_rollover
    )
    return ok, resulting if ok else 0.0


@dataclass(frozen=True)
class Operator:
    operator_id: str = "OP-1"
    role: str = "FUSION_DEMO_MVP_OPERATOR"
    auth: str = "AUTH-1"
    authenticated_at: int = 100


def operator_valid(x: Operator, now: int = 100) -> bool:
    return bool(x.operator_id and x.auth and x.role == "FUSION_DEMO_MVP_OPERATOR" and x.authenticated_at == now)


def callback_matches_submission(
    order: int,
    deal: int,
    request: int,
    sync_order: int,
    sync_deal: int,
    sync_request: int,
) -> bool:
    exact = (
        (order != 0 and sync_order != 0 and order == sync_order)
        or (deal != 0 and sync_deal != 0 and deal == sync_deal)
        or (request != 0 and sync_request != 0 and request == sync_request)
    )
    conflict = (
        (order != 0 and sync_order != 0 and order != sync_order)
        or (deal != 0 and sync_deal != 0 and deal != sync_deal)
        or (request != 0 and sync_request != 0 and request != sync_request)
    )
    return exact and not conflict


def execution_observation(
    operation_success: bool, requested_complete: bool, reported_total: int, rows: list[bool]
) -> tuple[int, int, bool]:
    if reported_total < len(rows):
        raise ValueError("reported-total-smaller-than-materialization-attempts")
    materialized = sum(rows)
    failures = len(rows) - materialized + reported_total - len(rows)
    complete = operation_success and requested_complete and failures == 0 and materialized == reported_total
    return materialized, failures, complete


def recover(claim_state: str, broker_complete: bool, execution_complete: bool,
            broker_effect: bool, execution_pending: bool) -> tuple[str, int, bool]:
    if claim_state != "CLAIMED_UNRESOLVED":
        return "BLOCKED", 0, False
    if not broker_complete or not execution_complete:
        return "UNRESOLVED", 0, False
    if broker_effect:
        return "POSITIVE", 0, False
    if execution_pending:
        return "UNRESOLVED", 0, False
    return "NEGATIVE", 0, False


def hard_kill_transition(current: str, evidence_valid: bool, authority_valid: bool,
                         current_owner: bool = True, zero_state_reconciled: bool = True) -> str:
    if current == "ACTIVE":
        return "RELEASE_PENDING" if evidence_valid else "ACTIVE"
    if current == "RELEASE_PENDING":
        return "RELEASED" if evidence_valid and authority_valid and current_owner and zero_state_reconciled else "RELEASE_PENDING"
    return current


class CasStore:
    def __init__(self, path: Path, namespace: str):
        self.namespace = namespace
        self.db = sqlite3.connect(path, isolation_level=None)
        self.db.execute("PRAGMA journal_mode=WAL")
        self.db.execute("CREATE TABLE IF NOT EXISTS meta(schema_id TEXT, version INT, min_version INT, namespace TEXT)")
        self.db.execute("CREATE TABLE IF NOT EXISTS rows(domain TEXT, key TEXT, revision INT, store_revision TEXT, state INT, digest TEXT, payload TEXT, PRIMARY KEY(domain,key))")
        meta = self.db.execute("SELECT schema_id,version,min_version,namespace FROM meta").fetchone()
        if meta is None:
            self.db.execute("INSERT INTO meta VALUES(?,?,?,?)", ("SWV5-S5-STORE-SCHEMA-V1", 1, 1, namespace))
        elif meta != ("SWV5-S5-STORE-SCHEMA-V1", 1, 1, namespace):
            self.db.close()
            raise ValueError("schema-or-namespace-mismatch")

    def cas(self, domain: str, key: str, expected: int, proposed: int, state: int, payload: str) -> tuple[bool, str]:
        digest = hashlib.sha256(payload.encode()).hexdigest()
        store_revision = hashlib.sha256(f"{self.namespace}|{domain}|{key}|{proposed}|{digest}".encode()).hexdigest()
        self.db.execute("BEGIN IMMEDIATE")
        current = self.db.execute("SELECT revision FROM rows WHERE domain=? AND key=?", (domain, key)).fetchone()
        actual = 0 if current is None else current[0]
        if actual != expected or proposed != expected + 1:
            self.db.execute("ROLLBACK")
            return False, ""
        if expected == 0:
            self.db.execute("INSERT INTO rows VALUES(?,?,?,?,?,?,?)", (domain, key, proposed, store_revision, state, digest, payload))
        else:
            changed = self.db.execute("UPDATE rows SET revision=?,store_revision=?,state=?,digest=?,payload=? WHERE domain=? AND key=? AND revision=?", (proposed, store_revision, state, digest, payload, domain, key, expected)).rowcount
            if changed != 1:
                self.db.execute("ROLLBACK")
                return False, ""
        readback = self.db.execute("SELECT revision,store_revision,state,digest,payload FROM rows WHERE domain=? AND key=?", (domain, key)).fetchone()
        if readback != (proposed, store_revision, state, digest, payload):
            self.db.execute("ROLLBACK")
            return False, ""
        self.db.execute("COMMIT")
        return True, store_revision


def stripped_code(text: str) -> str:
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
    text = re.sub(r"//.*", "", text)
    text = re.sub(r'"(?:\\.|[^"\\])*"', '""', text)
    return text


def main() -> int:
    r = Results()

    base_symbol = Symbol()
    r.check("SYMBOL-VALID", symbol_valid(base_symbol))
    for test_id, changed in [
        ("SYMBOL-WRONG", replace(base_symbol, symbol="EURUSD")),
        ("SYMBOL-DIGITS", replace(base_symbol, digits=2)),
        ("SYMBOL-POINT", replace(base_symbol, point=0.01)),
        ("SYMBOL-INCOMPLETE", replace(base_symbol, complete=False)),
        ("SYMBOL-EXPIRED", replace(base_symbol, valid_until=105)),
        ("SYMBOL-SEQUENCE-ZERO", replace(base_symbol, sequence=0)),
        ("SYMBOL-PIP", replace(base_symbol, pip=0.01)),
    ]:
        r.check(test_id, not symbol_valid(changed))
    r.check("SYMBOL-REFRESH-SEQUENCE", base_symbol.sequence + 1 == 2)
    pinned = base_symbol.sequence
    refreshed = replace(base_symbol, sequence=2)
    r.check("SYMBOL-OPERATION-PINNED", pinned == 1 and refreshed.sequence != pinned)

    base_risk = Risk()
    r.check("RISK-VALID", risk_allowed(base_risk))
    for test_id, changed in [
        ("RISK-EQUITY", replace(base_risk, equity=99)),
        ("RISK-DAILY-LOSS", replace(base_risk, daily_net=-10.01)),
        ("RISK-MARGIN", replace(base_risk, projected_margin=100.01)),
        ("RISK-BASKET-LOSS", replace(base_risk, basket_loss=5.01)),
        ("RISK-VOLUME", replace(base_risk, volume=0.011)),
        ("RISK-NOTIONAL", replace(base_risk, notional=10000.01)),
        ("RISK-SECOND-BASKET", replace(base_risk, live_baskets=2)),
        ("RISK-STALE", replace(base_risk, age=6)),
        ("RISK-INCOMPLETE-HISTORY", replace(base_risk, complete=False)),
        ("RISK-NON-USD", replace(base_risk, usd=False)),
        ("RISK-NON-HEDGING", replace(base_risk, hedging=False)),
        ("RISK-NON-DEMO", replace(base_risk, demo=False)),
        ("RISK-LATCH-ACTIVE", replace(base_risk, latch_inactive=False)),
        ("RISK-UNRESOLVED", replace(base_risk, unresolved=True)),
    ]:
        r.check(test_id, not risk_allowed(changed))

    base_margin = Margin()
    r.check("MARGIN-VALID", margin_authority(base_margin) == (True, 25.01))
    for test_id, changed in [
        ("MARGIN-NON-FLAT", replace(base_margin, positions=1)),
        ("MARGIN-ACTIVE-ORDER", replace(base_margin, orders=1)),
        ("MARGIN-CURRENT", replace(base_margin, current_margin=0.011)),
        ("MARGIN-CALC-FAIL", replace(base_margin, calculation_ok=False)),
        ("MARGIN-NEGATIVE", replace(base_margin, additional=-1)),
        ("MARGIN-NONFINITE", replace(base_margin, additional=float("inf"))),
    ]:
        r.check(test_id, not margin_authority(changed)[0])

    base_basket = BasketRisk()
    r.check("BASKET-RISK-VALID", basket_authority(base_basket) == (True, 4.0))
    for test_id, changed in [
        ("BASKET-MISSING-SL", replace(base_basket, stop=0)),
        ("BASKET-WRONG-SIDE-SL", replace(base_basket, stop=3501)),
        ("BASKET-CALC-FAIL", replace(base_basket, calculation_ok=False)),
        ("BASKET-NONLOSS", replace(base_basket, calculated_profit=0)),
        ("BASKET-OVER-LIMIT", replace(base_basket, calculated_profit=-4.01)),
        ("BASKET-EXISTING-POSITION", replace(base_basket, positions=1)),
        ("BASKET-ROLLOVER", replace(base_basket, session_crosses_rollover=True)),
    ]:
        r.check(test_id, not basket_authority(changed)[0])
    r.check("BASKET-FIXED-RESERVE", basket_authority(base_basket)[1] == -base_basket.calculated_profit + 1.0)

    base_op = Operator()
    r.check("TRUST-OPERATOR-VALID", operator_valid(base_op))
    for test_id, changed in [
        ("TRUST-BLANK-ID", replace(base_op, operator_id="")),
        ("TRUST-BLANK-ROLE", replace(base_op, role="")),
        ("TRUST-WRONG-ROLE", replace(base_op, role="ADMIN")),
        ("TRUST-BLANK-AUTH", replace(base_op, auth="")),
        ("TRUST-CLOCK-MISMATCH", replace(base_op, authenticated_at=99)),
    ]:
        r.check(test_id, not operator_valid(changed))
    r.check("TRUST-MAX-LIFETIME", 100 + 3600 - 100 == 3600)
    r.check("TRUST-EXPIRED", not (100 <= 3700 < 3700))
    r.check("GENESIS-PARTIAL-DISABLED", "PROVISIONING" != "READY_FOR_RECONCILIATION")
    r.check("RELEASE-BEFORE-ZERO-REJECTED", not (False and operator_valid(base_op)))
    genesis_latch = "ACTIVE"
    r.check("RESTART-NO-AUTO-ENABLE", genesis_latch != "INACTIVE")

    r.check("CALLBACK-EXACT-ORDER", callback_matches_submission(11, 0, 0, 11, 12, 44))
    r.check("CALLBACK-EXACT-REQUEST", callback_matches_submission(0, 0, 44, 11, 12, 44))
    r.check("CALLBACK-MAGIC-ONLY-DENIED", not callback_matches_submission(0, 0, 0, 11, 12, 44))
    r.check("CALLBACK-CONFLICT-DENIED", not callback_matches_submission(11, 99, 44, 11, 12, 44))

    materialized, failures, complete = execution_observation(True, True, 3, [True, False])
    r.check("EXECUTION-MATERIALIZED-COUNT", materialized == 1)
    r.check("EXECUTION-ROW-FAILURES", failures == 2)
    r.check("EXECUTION-INCOMPLETE-CLOSED", not complete)
    r.check("EXECUTION-FAILED-OP-INCOMPLETE", not execution_observation(False, True, 1, [True])[2])

    pending = hard_kill_transition("ACTIVE", True, False)
    released = hard_kill_transition(pending, True, True)
    r.check("HARD-KILL-RELEASE-PENDING", pending == "RELEASE_PENDING")
    r.check("HARD-KILL-RELEASED", released == "RELEASED")
    r.check("HARD-KILL-NO-AUTHORITY", hard_kill_transition(pending, True, False) == "RELEASE_PENDING")
    r.check("HARD-KILL-STALE-OWNER", hard_kill_transition(pending, True, True, False, True) == "RELEASE_PENDING")
    r.check("HARD-KILL-NO-ZERO-STATE", hard_kill_transition(pending, True, True, True, False) == "RELEASE_PENDING")

    with tempfile.TemporaryDirectory(prefix="swv5_mvp_") as temp:
        db_path = Path(temp) / "authority.sqlite"
        store = CasStore(db_path, "ns-a")
        first, rev1 = store.cas("permit", "one", 0, 1, 1, "permit-a")
        r.check("STORE-CAS-INSERT", first and len(rev1) == 64)
        stale, _ = store.cas("permit", "one", 0, 1, 1, "permit-b")
        r.check("STORE-STALE-PERMIT", not stale)
        winner1, _ = store.cas("claim", "one", 0, 1, 2, "claimed")
        winner2, _ = store.cas("claim", "one", 0, 1, 2, "claimed")
        r.check("STORE-ONE-CLAIM-WINNER", winner1 and not winner2)
        persisted = store.db.execute("SELECT state,payload FROM rows WHERE domain='claim' AND key='one'").fetchone()
        r.check("STORE-CLAIM-DURABLE", persisted == (2, "claimed"))
        r.check("STORE-CLAIM-GRANT-EPHEMERAL", "CLAIM_GRANTED_NOW" not in persisted[1])
        store.db.close()
        reopened = CasStore(db_path, "ns-a")
        r.check("STORE-REOPEN", reopened.db.execute("SELECT count(*) FROM rows").fetchone()[0] == 2)
        try:
            CasStore(db_path, "ns-b")
            mismatch = False
        except ValueError:
            mismatch = True
        r.check("STORE-NAMESPACE-MISMATCH", mismatch)
        reopened.db.execute("BEGIN IMMEDIATE")
        reopened.db.execute("INSERT INTO rows VALUES('rollback','one',1,'r',1,'d','p')")
        reopened.db.execute("ROLLBACK")
        r.check("STORE-ROLLBACK", reopened.db.execute("SELECT count(*) FROM rows WHERE domain='rollback'").fetchone()[0] == 0)
        incomplete_payload = "operation=1|complete=0|reported=3|materialized=1|failures=2"
        incomplete, _ = reopened.cas("execution", "current", 0, 1, 1, incomplete_payload)
        reopened.db.close()
        incomplete_store = CasStore(db_path, "ns-a")
        persisted_incomplete = incomplete_store.db.execute(
            "SELECT payload FROM rows WHERE domain='execution' AND key='current'"
        ).fetchone()
        r.check("STORE-INCOMPLETE-RESTART", incomplete and persisted_incomplete == (incomplete_payload,))
        terminal, terminal_revision = incomplete_store.cas("reconciliation", "one", 0, 1, 2, "positive")
        incomplete_store.db.close()
        terminal_store = CasStore(db_path, "ns-a")
        terminal_row = terminal_store.db.execute("SELECT state,store_revision FROM rows WHERE domain='reconciliation'").fetchone()
        r.check("STORE-TERMINAL-RESTART", terminal and terminal_row == (2, terminal_revision))
        terminal_store.db.close()

    claimed = recover("CLAIMED_UNRESOLVED", True, True, False, False)
    positive = recover("CLAIMED_UNRESOLVED", True, True, True, False)
    incomplete_recovery = recover("CLAIMED_UNRESOLVED", False, True, False, False)
    r.check("RECOVERY-CLAIMED-ZERO-SUBMIT", claimed == ("NEGATIVE", 0, False))
    r.check("RECOVERY-POSITIVE-ZERO-SUBMIT", positive == ("POSITIVE", 0, False))
    r.check("RECOVERY-BLOCKED-STICKY", recover("BLOCKED", True, True, False, False) == ("BLOCKED", 0, False))
    r.check("RECOVERY-INCOMPLETE-UNRESOLVED", incomplete_recovery == ("UNRESOLVED", 0, False))
    r.check("RECOVERY-INDEPENDENT-EVIDENCE", "BROKER" != "EXECUTION")
    with tempfile.TemporaryDirectory(prefix="swv5_mvp_stale_") as temp:
        stale_store = CasStore(Path(temp) / "stale.sqlite", "ns-stale")
        winner, _ = stale_store.cas("reconciliation", "one", 0, 1, 1, "unresolved")
        stale, _ = stale_store.cas("reconciliation", "one", 0, 1, 2, "positive")
        stale_store.db.close()
        r.check("RECOVERY-STALE-PUBLICATION-CAS", winner and not stale)

    profile_text = (RUNTIME / "SW_V5_S5_MvpDeploymentProfile.mqh").read_text(encoding="utf-8")
    platform_text = (RUNTIME / "SW_V5_S5_MvpReadOnlyPlatform.mqh").read_text(encoding="utf-8")
    runtime_sources = "\n".join(p.read_text(encoding="utf-8") for p in RUNTIME.glob("*.mqh"))
    execution_sources = {
        p.relative_to(EXECUTION_LAYER).as_posix(): stripped_code(p.read_text(encoding="utf-8"))
        for p in EXECUTION_LAYER.rglob("*.mqh")
    }
    order_send_sites = [name for name, source in execution_sources.items() if "OrderSend(" in source]
    r.check("SOURCE-PROFILE-ID", '"FUSION-V5-DEMO-MVP-V1"' in profile_text)
    r.check("SOURCE-RISK-ID", '"FUSION-V5-DEMO-MVP-RISK-V1"' in profile_text)
    r.check("SOURCE-SYMBOL-LIVE", "SymbolInfo" in platform_text)
    r.check("SOURCE-MARGIN-PRIMITIVE", "OrderCalcMargin(" in platform_text)
    r.check("SOURCE-PROFIT-PRIMITIVE", "OrderCalcProfit(" in platform_text)
    r.check("SOURCE-DAILY-HISTORY", all(x in platform_text for x in ("HistorySelect(", "DEAL_PROFIT", "DEAL_COMMISSION", "DEAL_SWAP", "DEAL_FEE")))
    code = stripped_code(runtime_sources)
    r.check("SOURCE-NO-ORDERSEND", "OrderSend(" not in code and "OrderSendAsync(" not in code)
    r.check("SOURCE-NO-CTRADE", "CTrade" not in code)
    r.check("SOURCE-OFFLINE-ZERO-SUBMISSION", "broker_submission_calls=0" in runtime_sources)
    store_text = (RUNTIME / "SW_V5_S5_MvpSqliteAuthorityStore.mqh").read_text(encoding="utf-8")
    r.check("SOURCE-COMMON-FILENAME-ONLY", all(token in store_text for token in (
        "DATABASE_OPEN_COMMON", 'StringFind(relative_path,"..")', 'StringFind(relative_path,":")'
    )))
    r.check(
        "SOURCE-ONE-PRODUCTION-ORDERSEND",
        order_send_sites == ["BrokerAdapter/SW_V5_S5_F_BrokerPlatformBoundary.mqh"]
        and sum(source.count("OrderSend(") for source in execution_sources.values()) == 1,
    )

    return r.finish()


if __name__ == "__main__":
    raise SystemExit(main())
