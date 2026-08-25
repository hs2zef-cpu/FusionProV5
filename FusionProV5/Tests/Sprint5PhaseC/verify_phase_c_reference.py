#!/usr/bin/env python3
"""TEST ONLY / NON-PRODUCTION / NO BROKER ACCESS.

Independent deterministic reference model for Sprint 5 Phase C orchestration.
REFERENCE MODEL != MQL RUNTIME EXECUTION.
"""

from __future__ import annotations

import hashlib
import json
from dataclasses import dataclass, field
from typing import Any


def binding(ingress: str, ordinal: int = 1) -> tuple[str, str]:
    correlation = hashlib.sha256(("phase-c-scope|" + ingress).encode()).hexdigest()
    attempt = hashlib.sha256((correlation + "|" + str(ordinal)).encode()).hexdigest()
    return correlation, attempt


@dataclass
class ReferenceCoordinator:
    claims: dict[str, str] = field(default_factory=dict)
    ingress_requests: dict[str, tuple[str, str]] = field(default_factory=dict)
    broker_calls: list[dict[str, Any]] = field(default_factory=list)
    trace: list[dict[str, Any]] = field(default_factory=list)

    def emit(self, event: str, ordinal: int, step: str, disposition: str,
             request: str = "", attempt: str = "", grant: bool = False,
             broker: bool = False) -> None:
        self.trace.append({"event": event, "ordinal": ordinal, "step": step,
                           "request": request, "attempt": attempt,
                           "disposition": disposition, "grant_now": grant,
                           "fake_broker": broker})

    def ingress(self, event: str, ordinal: int, ingress_id: str, direction: int,
                trusted: bool = True) -> str:
        if not trusted:
            self.emit(event, ordinal, "INGRESS", "TRUST_DENIED")
            return "DENIED"
        if direction in (0, 9):
            self.emit(event, ordinal, "INGRESS", "NO_ENTRY")
            return "NO_ENTRY"
        if direction not in (-1, 1):
            self.emit(event, ordinal, "INGRESS", "DIRECTION_INVALID")
            return "DENIED"
        request, attempt = binding(ingress_id)
        existing = self.ingress_requests.get(ingress_id)
        if existing is not None:
            assert existing == (request, attempt)
            self.emit(event, ordinal, "INGRESS", "DUPLICATE_SAME_REQUEST", request, attempt)
            return "DUPLICATE"
        self.ingress_requests[ingress_id] = (request, attempt)
        self.emit(event, ordinal, "INGRESS", "BUY" if direction == 1 else "SELL", request, attempt)
        return "NOMINATED"

    def admission(self, event: str, ordinal: int, ingress_id: str, *,
                  owner: str = "owner-A", current_owner: str = "owner-A",
                  hard_kill_before_p: bool = False, trust_before_p: bool = False,
                  risk_expiry: int = 200, claim_time: int = 100,
                  interrupt: str = "", mutate_after_p: str = "",
                  broker_outcome: str = "REQUEST_RECEIVED") -> str:
        request, attempt = self.ingress_requests[ingress_id]
        self.emit(event, ordinal, "V1_V2_COLLECT", "STARTED", request, attempt)
        if hard_kill_before_p:
            self.emit(event, ordinal, "PROVISIONAL_P", "HARD_KILL_BLOCKED", request, attempt)
            return "ADMISSION_DENIED"
        if trust_before_p:
            self.emit(event, ordinal, "PROVISIONAL_P", "TRUST_BLOCKED", request, attempt)
            return "ADMISSION_DENIED"
        if claim_time >= risk_expiry:
            self.emit(event, ordinal, "PROVISIONAL_P", "RISK_EXPIRED_EXCLUSIVE", request, attempt)
            return "CLAIM_DENIED"
        self.emit(event, ordinal, "PROVISIONAL_P", "AVAILABLE_EVENT_LOCAL", request, attempt)
        if interrupt == "BEFORE_CLAIM":
            self.emit(event, ordinal, "INTERRUPT", "P_LOST_RECOLLECT", request, attempt)
            return "INTERRUPTED_RECOLLECT"
        if current_owner != owner:
            self.emit(event, ordinal, "CLAIM", "STALE_OWNER", request, attempt)
            return "STALE_OWNER"
        if self.claims.get(attempt) == "INVOCATION_CLAIMED_UNRESOLVED":
            self.emit(event, ordinal, "CLAIM", "ALREADY_CLAIMED_NO_GRANT", request, attempt)
            self.emit(event, ordinal, "RECONCILE", "REQUIRED_NO_RETRY", request, attempt)
            return "RECONCILIATION_REQUIRED"
        # The only authority transition. after-P policy mutations are retained for
        # this overlapping operation and block only a later collection.
        self.claims[attempt] = "INVOCATION_CLAIMED_UNRESOLVED"
        self.emit(event, ordinal, "CLAIM", "CLAIM_GRANTED_NOW", request, attempt, True)
        if mutate_after_p:
            self.emit(event, ordinal, "OVERLAP", mutate_after_p + "_CURRENT_RETAINED_LATER_BLOCKED",
                      request, attempt, True)
        if interrupt == "AFTER_CLAIM":
            self.emit(event, ordinal, "INTERRUPT", "CLAIMED_RECONCILIATION_REQUIRED",
                      request, attempt, True)
            return "RECONCILIATION_REQUIRED"
        call = {"event": event, "ordinal": ordinal, "request": request,
                "attempt": attempt, "payload": "normalized:" + ingress_id,
                "event_local_sequence": 1, "scripted_outcome": broker_outcome}
        self.broker_calls.append(call)
        self.emit(event, ordinal, "FAKE_BROKER", broker_outcome, request, attempt, True, True)
        return "FAKE_BROKER_INVOKED" if broker_outcome == "REQUEST_RECEIVED" else broker_outcome


def result(name: str, model: ReferenceCoordinator, outcomes: list[str]) -> dict[str, Any]:
    return {"scenario": name, "outcomes": outcomes,
            "broker_invocations": model.broker_calls, "trace": model.trace}


def run_scenario(name: str) -> dict[str, Any]:
    c = ReferenceCoordinator()
    o: list[str] = []
    if name == "directional":
        o.append(c.ingress("E1", 1, "I-BUY", 1))
        o.append(c.admission("E2", 2, "I-BUY"))
        assert len(c.broker_calls) == 1
    elif name == "duplicate_ingress":
        o += [c.ingress("E1", 1, "I-DUP", 1), c.ingress("E2", 2, "I-DUP", 1)]
        assert len(c.ingress_requests) == 1
    elif name == "wait":
        o.append(c.ingress("E1", 1, "I-WAIT", 0)); assert not c.broker_calls
    elif name == "blocked":
        o.append(c.ingress("E1", 1, "I-BLOCK", 9)); assert not c.broker_calls
    elif name == "two_requests":
        o += [c.ingress("E1", 1, "I-BUY", 1), c.ingress("E2", 2, "I-SELL", -1)]
        assert len(c.ingress_requests) == 2 and c.trace[0]["disposition"] == "BUY" and c.trace[1]["disposition"] == "SELL"
    elif name in ("duplicate_submission", "claim_winner_duplicate"):
        c.ingress("E1", 1, "I-A", 1)
        o += [c.admission("E2", 2, "I-A"), c.admission("E3", 3, "I-A")]
        assert len(c.broker_calls) == 1 and o[1] == "RECONCILIATION_REQUIRED"
    elif name == "takeover_before_claim":
        c.ingress("E1", 1, "I-A", 1)
        o.append(c.admission("E2", 2, "I-A", current_owner="owner-B")); assert not c.broker_calls
    elif name == "claim_before_takeover":
        c.ingress("E1", 1, "I-A", 1)
        o.append(c.admission("E2", 2, "I-A"))
        request, attempt = c.ingress_requests["I-A"]
        c.emit("E3", 3, "TAKEOVER", "CLAIMED_UNRESOLVED_QUIESCENCE", request, attempt)
        o.append("TAKEOVER_RECONCILIATION_REQUIRED"); assert len(c.broker_calls) == 1
    elif name == "crash_before_claim":
        c.ingress("E1", 1, "I-A", 1)
        o.append(c.admission("E2", 2, "I-A", interrupt="BEFORE_CLAIM"))
        o.append(c.admission("E3", 3, "I-A")); assert len(c.broker_calls) == 1
    elif name == "crash_after_claim":
        c.ingress("E1", 1, "I-A", 1)
        o.append(c.admission("E2", 2, "I-A", interrupt="AFTER_CLAIM")); assert not c.broker_calls
    elif name == "uncertain_followed":
        c.ingress("E1", 1, "I-A", 1)
        o.append(c.admission("E2", 2, "I-A", interrupt="AFTER_CLAIM"))
        o.append(c.admission("E3", 3, "I-A")); assert not c.broker_calls
    elif name == "hard_kill_ordering":
        c.ingress("E1", 1, "I-A", 1); c.ingress("E2", 2, "I-B", 1)
        o.append(c.admission("E3", 3, "I-A", hard_kill_before_p=True))
        o.append(c.admission("E4", 4, "I-B", mutate_after_p="HARD_KILL"))
        assert len(c.broker_calls) == 1
    elif name == "trust_ordering":
        c.ingress("E1", 1, "I-A", 1); c.ingress("E2", 2, "I-B", 1)
        o.append(c.admission("E3", 3, "I-A", trust_before_p=True))
        o.append(c.admission("E4", 4, "I-B", mutate_after_p="TRUST"))
        assert len(c.broker_calls) == 1
    elif name == "risk_exact_expiry":
        c.ingress("E1", 1, "I-A", 1); c.ingress("E2", 2, "I-B", 1); c.ingress("E3", 3, "I-C", 1)
        o.append(c.admission("E4", 4, "I-A", claim_time=99, risk_expiry=100))
        o.append(c.admission("E5", 5, "I-B", claim_time=100, risk_expiry=100))
        o.append(c.admission("E6", 6, "I-C", claim_time=101, risk_expiry=100))
        assert len(c.broker_calls) == 1 and o[1:] == ["CLAIM_DENIED", "CLAIM_DENIED"]
    else:
        raise AssertionError("unknown scenario: " + name)
    return result(name, c, o)


SCENARIOS = [
    "directional", "duplicate_ingress", "wait", "blocked", "two_requests",
    "duplicate_submission", "claim_winner_duplicate", "takeover_before_claim",
    "claim_before_takeover", "crash_before_claim", "crash_after_claim",
    "uncertain_followed", "hard_kill_ordering", "trust_ordering", "risk_exact_expiry",
]


def main() -> int:
    first = [run_scenario(name) for name in SCENARIOS]
    second = [run_scenario(name) for name in SCENARIOS]
    assert first == second
    serialized = json.dumps(first, sort_keys=True, separators=(",", ":"))
    summary = {
        "classification": "REFERENCE MODEL != MQL RUNTIME EXECUTION",
        "scenario_count": len(first),
        "repeated_runs": 2,
        "deterministic": True,
        "trace_digest_sha256": hashlib.sha256(serialized.encode()).hexdigest(),
        "status": "PASS",
    }
    print(json.dumps(summary, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
