#!/usr/bin/env python3
"""TEST ONLY / NOT FOR PRODUCTION / NO BROKER ACCESS.

Independent table-driven oracle for the Phase F entry-contract patch.
It does not import or execute the MQL implementation.
"""
from dataclasses import dataclass
from enum import Enum
import hashlib
import json


class State(str, Enum):
    NO_CALL = "NO_CALL"
    UNRESOLVED = "SUBMISSION_UNRESOLVED"
    POSITIVE = "SIDE_EFFECT_POSITIVELY_CONFIRMED"
    NEGATIVE = "NO_SIDE_EFFECT_CONFIRMED"
    PARTIAL = "PARTIAL_EFFECT_CONFIRMED"
    BLOCKED = "RECONCILIATION_BLOCKED"


@dataclass(frozen=True)
class Result:
    state: State
    reason: str
    retry_allowed: bool = False
    residual_is_authority: bool = False
    requires_new_request_for_residual: bool = False


@dataclass(frozen=True)
class Case:
    test_id: str
    prior: State = State.UNRESOLVED
    claimed: bool = True
    binding_valid: bool = True
    no_call_proof_present: bool = False
    no_call_proof_valid: bool = False
    broker_query_present: bool = False
    positive_present: bool = False
    durable_broker_shape: bool = False
    positive_binding_valid: bool = True
    correlation_policy_pinned: bool = True
    capability_proof_governed: bool = True
    capability_proof_pinned: bool = True
    ordered_full_deal_set: bool = True
    direction_bound: bool = True
    confirmed: float = 0.0
    requested: float = 1.0
    negative_present: bool = False
    negative_policy_pinned: bool = True
    completeness_proven: bool = True
    visibility_proven: bool = True
    operations_complete: bool = True
    row_failures: int = 0
    matching_rows: int = 0
    first_after_visibility_lag: bool = True
    stability_interval_elapsed: bool = True
    same_connection_generation: bool = True
    same_restart_generation: bool = True
    current_generations: bool = True
    broker_first_beyond_hwm: bool = True
    execution_first_beyond_hwm: bool = True
    broker_second_advances: bool = True
    execution_second_advances: bool = True
    independent_read_paths: bool = True
    terminal_binding_match: bool = True
    terminal_partition_match: bool = True
    terminal_evidence_digest_match: bool = True
    later_evidence_present: bool = False


def evaluate(c: Case) -> Result:
    if c.prior is State.BLOCKED:
        return Result(State.BLOCKED, "BLOCKED_STICKY")
    if not c.binding_valid:
        reason = "ORPHAN_POSITIVE_SIDE_EFFECT" if c.positive_present and c.durable_broker_shape else "INVALID_BINDING"
        return Result(State.BLOCKED, reason)
    if c.prior is State.NO_CALL:
        valid = (
            not c.claimed
            and c.no_call_proof_present
            and c.no_call_proof_valid
            and not c.broker_query_present
            and not c.positive_present
            and not c.negative_present
        )
        return Result(State.NO_CALL, "AUTHORITATIVE_LOCAL_NO_CALL_PROOF") if valid else Result(
            State.BLOCKED, "NO_CALL_CONTRADICTION"
        )
    if c.prior in (State.POSITIVE, State.NEGATIVE, State.PARTIAL):
        replay_ok = (
            c.terminal_binding_match
            and c.terminal_partition_match
            and c.terminal_evidence_digest_match
            and not c.later_evidence_present
            and not c.positive_present
            and not c.negative_present
        )
        return (Result(c.prior, "TERMINAL_REPLAY", requires_new_request_for_residual=c.prior is State.PARTIAL)
                if replay_ok else Result(State.BLOCKED, "TERMINAL_CONFLICT"))
    if not c.claimed:
        return Result(State.BLOCKED, "CLAIM_REQUIRED")
    if ((c.positive_present or c.negative_present) and
            not (c.correlation_policy_pinned and c.capability_proof_pinned)) or (
            c.negative_present and not c.negative_policy_pinned):
        return Result(State.BLOCKED, "PINNED_POLICY_DRIFT")

    positive_valid = (
        c.positive_present
        and c.durable_broker_shape
        and c.positive_binding_valid
        and c.capability_proof_governed
        and c.ordered_full_deal_set
        and c.direction_bound
        and 0 < c.confirmed <= c.requested
    )
    if c.positive_present and not positive_valid:
        reason = "ORPHAN_POSITIVE_SIDE_EFFECT" if c.durable_broker_shape else "INVALID_POSITIVE_EVIDENCE"
        return Result(State.BLOCKED, reason)
    if positive_valid and c.negative_present:
        return Result(State.BLOCKED, "CONFLICTING_EVIDENCE")
    if positive_valid:
        if c.confirmed < c.requested:
            return Result(State.PARTIAL, "PARTIAL_RESIDUAL_NON_AUTHORITY", requires_new_request_for_residual=True)
        return Result(State.POSITIVE, "POSITIVE_CONFIRMED")

    negative_valid = (
        c.negative_present
        and c.capability_proof_governed
        and c.completeness_proven
        and c.visibility_proven
        and c.operations_complete
        and c.row_failures == 0
        and c.matching_rows == 0
        and c.first_after_visibility_lag
        and c.stability_interval_elapsed
        and c.same_connection_generation
        and c.same_restart_generation
        and c.current_generations
        and c.broker_first_beyond_hwm
        and c.execution_first_beyond_hwm
        and c.broker_second_advances
        and c.execution_second_advances
        and c.independent_read_paths
    )
    if negative_valid:
        return Result(State.NEGATIVE, "AUTHORITATIVE_NEGATIVE")
    return Result(State.UNRESOLVED, "NON_AUTHORITATIVE_NEGATIVE" if c.negative_present else "AMBIGUOUS")


def C(test_id: str, expected: State, **kwargs):
    return Case(test_id, **kwargs), expected


CASES = [
    C("F-001", State.NO_CALL, prior=State.NO_CALL, claimed=False, no_call_proof_present=True, no_call_proof_valid=True),
    C("F-002", State.BLOCKED, prior=State.NO_CALL, claimed=True, no_call_proof_present=True, no_call_proof_valid=True),
    C("F-003", State.BLOCKED, prior=State.NO_CALL, claimed=False),
    C("F-004", State.BLOCKED, prior=State.NO_CALL, claimed=False, no_call_proof_present=True, no_call_proof_valid=False),
    C("F-005", State.BLOCKED, prior=State.NO_CALL, claimed=False, no_call_proof_present=True, no_call_proof_valid=True, broker_query_present=True),
    C("F-006", State.UNRESOLVED),
    C("F-007", State.BLOCKED, positive_present=True, durable_broker_shape=True, binding_valid=False),
    C("F-008", State.BLOCKED, positive_present=True, durable_broker_shape=True, positive_binding_valid=False, confirmed=1),
    C("F-009", State.POSITIVE, positive_present=True, durable_broker_shape=True, confirmed=1),
    C("F-010", State.PARTIAL, positive_present=True, durable_broker_shape=True, confirmed=.4),
    C("F-011", State.BLOCKED, positive_present=True, durable_broker_shape=True, ordered_full_deal_set=False, confirmed=1),
    C("F-012", State.BLOCKED, positive_present=True, durable_broker_shape=True, direction_bound=False, confirmed=1),
    C("F-013", State.BLOCKED, positive_present=True, durable_broker_shape=True, capability_proof_governed=False, confirmed=1),
    C("F-014", State.BLOCKED, positive_present=True, durable_broker_shape=False, confirmed=1),
    C("F-015", State.NEGATIVE, negative_present=True),
    C("F-016", State.UNRESOLVED, negative_present=True, completeness_proven=False),
    C("F-017", State.UNRESOLVED, negative_present=True, visibility_proven=False),
    C("F-018", State.UNRESOLVED, negative_present=True, first_after_visibility_lag=False),
    C("F-019", State.UNRESOLVED, negative_present=True, stability_interval_elapsed=False),
    C("F-020", State.UNRESOLVED, negative_present=True, same_connection_generation=False),
    C("F-021", State.UNRESOLVED, negative_present=True, same_restart_generation=False),
    C("F-022", State.UNRESOLVED, negative_present=True, current_generations=False),
    C("F-023", State.UNRESOLVED, negative_present=True, broker_first_beyond_hwm=False),
    C("F-024", State.UNRESOLVED, negative_present=True, execution_first_beyond_hwm=False),
    C("F-025", State.UNRESOLVED, negative_present=True, broker_second_advances=False),
    C("F-026", State.UNRESOLVED, negative_present=True, execution_second_advances=False),
    C("F-027", State.UNRESOLVED, negative_present=True, independent_read_paths=False),
    C("F-028", State.UNRESOLVED, negative_present=True, row_failures=1),
    C("F-029", State.UNRESOLVED, negative_present=True, matching_rows=1),
    C("F-030", State.UNRESOLVED, negative_present=True, capability_proof_governed=False),
    C("F-031", State.BLOCKED, positive_present=True, durable_broker_shape=True, confirmed=1, correlation_policy_pinned=False),
    C("F-032", State.BLOCKED, positive_present=True, durable_broker_shape=True, confirmed=1, capability_proof_pinned=False),
    C("F-033", State.BLOCKED, negative_present=True, negative_policy_pinned=False),
    C("F-034", State.POSITIVE, prior=State.POSITIVE),
    C("F-035", State.NEGATIVE, prior=State.NEGATIVE),
    C("F-036", State.PARTIAL, prior=State.PARTIAL),
    C("F-037", State.BLOCKED, prior=State.POSITIVE, terminal_binding_match=False),
    C("F-038", State.BLOCKED, prior=State.PARTIAL, terminal_partition_match=False),
    C("F-039", State.BLOCKED, prior=State.NEGATIVE, terminal_evidence_digest_match=False),
    C("F-040", State.BLOCKED, prior=State.POSITIVE, later_evidence_present=True),
    C("F-041", State.BLOCKED, prior=State.BLOCKED),
    C("F-042", State.BLOCKED, prior=State.BLOCKED, binding_valid=False),
    C("F-043", State.BLOCKED, positive_present=True, durable_broker_shape=True, negative_present=True, confirmed=1),
    C("F-044", State.UNRESOLVED, negative_present=True, operations_complete=False),
    C("F-045", State.BLOCKED, prior=State.NO_CALL, claimed=False, no_call_proof_present=True,
      no_call_proof_valid=True, positive_present=True, durable_broker_shape=True, confirmed=1),
    C("F-046", State.BLOCKED, prior=State.NO_CALL, claimed=False, no_call_proof_present=True,
      no_call_proof_valid=True, negative_present=True),
    C("F-047", State.BLOCKED, prior=State.NEGATIVE, later_evidence_present=True),
    C("F-048", State.BLOCKED, prior=State.PARTIAL, later_evidence_present=True),
]


def main() -> int:
    rows = []
    for case, expected in CASES:
        actual = evaluate(case)
        passed = actual.state is expected and not actual.retry_allowed and not actual.residual_is_authority
        if expected is State.PARTIAL:
            passed = passed and actual.requires_new_request_for_residual
        rows.append({"id": case.test_id, "expected": expected.value, "actual": actual.state.value, "pass": passed})
    canonical = json.dumps(rows, sort_keys=True, separators=(",", ":"))
    signature = hashlib.sha256(canonical.encode()).hexdigest()
    passed = sum(r["pass"] for r in rows)
    print(json.dumps({"suite": "Sprint5PhaseFEntryPatch", "total": len(rows), "passed": passed,
                      "failed": len(rows)-passed, "skipped": 0, "signature": signature}, sort_keys=True))
    return 0 if passed == len(rows) else 1


if __name__ == "__main__":
    raise SystemExit(main())
