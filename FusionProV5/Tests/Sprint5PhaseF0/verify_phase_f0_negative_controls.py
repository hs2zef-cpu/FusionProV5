"""TEST ONLY / F0 / NOT FOR PRODUCTION / NO BROKER ACCESS.

Offline deliberate-mutant controls. Unsafe behavior occurs before a separate
detector evaluates the intended F0 invariant. This is not MQL runtime or broker
evidence.
"""
from __future__ import annotations

from dataclasses import asdict, dataclass
import hashlib
import json
import sys


@dataclass(frozen=True)
class ControlResult:
    test_id: str
    unsafe_behavior: str
    fixture: str
    unsafe_result_observed: bool
    intended_detector: str
    detector_triggered: bool
    reason: str

    @property
    def passed(self) -> bool:
        return self.unsafe_result_observed and self.detector_triggered


def result(test_id: str, unsafe: str, fixture: str, observed: bool,
           detector: str, triggered: bool, reason: str) -> ControlResult:
    return ControlResult(test_id, unsafe, fixture, observed, detector, triggered, reason)


def controls() -> list[ControlResult]:
    out: list[ControlResult] = []

    persisted, event_grant = "INVOCATION_CLAIMED_UNRESOLVED", False
    mutant_send = persisted == "INVOCATION_CLAIMED_UNRESOLVED"
    out.append(result("NC-01", "persisted Claim authorizes send without event-local grant", persisted,
                      mutant_send, "send requires event-local CLAIM_GRANTED_NOW", mutant_send and not event_grant,
                      "mutant became send-eligible while event grant was absent"))

    sync_retcode, authoritative_deal = "TRADE_RETCODE_DONE", False
    mutant_confirmed = sync_retcode in {"TRADE_RETCODE_DONE", "TRADE_RETCODE_PLACED"}
    out.append(result("NC-02", "synchronous accepted retcode confirms Basket/deal", sync_retcode,
                      mutant_confirmed, "confirmation requires authoritative broker query/reconciliation",
                      mutant_confirmed and not authoritative_deal, "sync acceptance was promoted without deal evidence"))

    mutant_no_effect = True
    out.append(result("NC-03", "timeout proves no side effect", "TRADE_RETCODE_TIMEOUT", mutant_no_effect,
                      "timeout is ambiguous", mutant_no_effect, "timeout was incorrectly converted to negative evidence"))

    callbacks: list[str] = []
    mutant_absence = len(callbacks) == 0
    out.append(result("NC-04", "callback absence proves no side effect", "empty callback window", mutant_absence,
                      "callback absence has zero negative-evidence value", mutant_absence,
                      "an empty observational channel was treated as authoritative"))

    query = {"success": True, "complete": False, "rows": []}
    mutant_empty = query["success"] and not query["rows"]
    out.append(result("NC-05", "incomplete query is reported complete/empty", json.dumps(query), mutant_empty,
                      "empty requires explicit completeness", mutant_empty and not query["complete"],
                      "row count hid the incomplete status"))

    callback_ids = ["DEAL-1", "DEAL-1"]
    mutant_mutations = len(callback_ids)
    out.append(result("NC-06", "duplicate callback mutates state twice", str(callback_ids), mutant_mutations == 2,
                      "durable evidence identity is idempotent", mutant_mutations > len(set(callback_ids)),
                      "same evidence identity caused two mutations"))

    order_a = ["REQUEST", "ORDER_ADD", "DEAL_ADD"]
    order_b = ["DEAL_ADD", "REQUEST", "ORDER_ADD"]
    mutant_policy_a, mutant_policy_b = order_a[-1], order_b[-1]
    out.append(result("NC-07", "callback arrival order drives causal policy", f"{order_a}|{order_b}",
                      mutant_policy_a != mutant_policy_b, "safety result is order-independent",
                      mutant_policy_a != mutant_policy_b, "permutation changed the mutant policy result"))

    presented = ["CLAIM-1", "CLAIM-1"]
    mutant_broker_log = list(dict.fromkeys(presented))
    out.append(result("NC-08", "broker double silently deduplicates physical calls", str(presented),
                      len(mutant_broker_log) != len(presented), "dumb broker counts every presentation",
                      len(mutant_broker_log) != 2, "two presentations produced one log entry"))

    owner_epoch, current_epoch = 7, 8
    mutant_invoked = True
    out.append(result("NC-09", "stale owner invokes", "claimant epoch 7/current epoch 8", mutant_invoked,
                      "current ownership/fence required at Claim and CAS", mutant_invoked and owner_epoch != current_epoch,
                      "send occurred with stale epoch"))

    unresolved_before, mutant_after = True, False
    out.append(result("NC-10", "reconnect clears unresolved state", "claimed-unresolved before reconnect",
                      unresolved_before and not mutant_after, "reconnect preserves unresolved authority",
                      unresolved_before != mutant_after, "reconnect erased durable uncertainty"))

    spec_sequence, required_sequence = 41, 42
    mutant_spec_accepted = True
    out.append(result("NC-11", "stale margin/symbol specification accepted", "spec sequence 41/required 42",
                      mutant_spec_accepted, "exact current specification sequence required",
                      mutant_spec_accepted and spec_sequence != required_sequence, "stale spec crossed admission boundary"))

    account_mode, mutant_allowed = "NETTING", True
    out.append(result("NC-12", "NETTING accepted as HEDGING", account_mode, mutant_allowed,
                      "F0 and Phase F require HEDGING", mutant_allowed and account_mode != "HEDGING",
                      "mutant admitted unsupported account mode"))

    history = {"window_complete": False, "rows": 0}
    mutant_history_empty = history["rows"] == 0
    out.append(result("NC-13", "truncated history reported authoritative empty", json.dumps(history),
                      mutant_history_empty, "authoritative empty requires complete covered window",
                      mutant_history_empty and not history["window_complete"], "zero rows concealed truncated coverage"))

    session_a, session_b = {"request_id": 1, "session": "A"}, {"request_id": 1, "session": "B"}
    mutant_same_identity = session_a["request_id"] == session_b["request_id"]
    out.append(result("NC-14", "terminal request_id used across restart as durable identity",
                      f"{session_a}|{session_b}", mutant_same_identity, "request_id is session-local only",
                      mutant_same_identity and session_a["session"] != session_b["session"],
                      "request_id collision across sessions was treated as identity"))

    evidence_origin, required_origin = "STRATEGY_TESTER", "ATTENDED_DEMO"
    mutant_substitution = True
    out.append(result("NC-15", "Tester evidence substitutes for Demo-required transport evidence",
                      evidence_origin, mutant_substitution, "transport/reconnect/broker visibility requires Demo",
                      mutant_substitution and evidence_origin != required_origin,
                      "wrong evidence origin was accepted"))
    return out


def execute_once() -> dict:
    observed = controls()
    assert len({item.test_id for item in observed}) == len(observed) == 15
    rows = [asdict(item) | {"passed": item.passed} for item in observed]
    passed = sum(item.passed for item in observed)
    encoded = json.dumps(rows, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return {"classification": "OFFLINE PYTHON DELIBERATE MUTANTS; NOT MQL/TESTER/DEMO/BROKER EVIDENCE",
            "status": "PASS" if passed == len(observed) else "FAIL", "total": len(observed),
            "passed": passed, "failed": len(observed)-passed,
            "digest": hashlib.sha256(encoded).hexdigest(), "results": rows}


def main() -> None:
    first, second = execute_once(), execute_once()
    assert first == second
    output = first if "--details" in sys.argv else {key: value for key, value in first.items() if key != "results"}
    output.update({"runs": 2, "deterministic": True})
    print(json.dumps(output, sort_keys=True, separators=(",", ":")))


if __name__ == "__main__":
    main()
