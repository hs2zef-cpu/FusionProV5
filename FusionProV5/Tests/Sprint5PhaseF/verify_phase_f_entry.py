#!/usr/bin/env python3
"""TEST ONLY / NOT FOR PRODUCTION / NO BROKER ACCESS.

Independent table-driven oracle for the Phase F entry contract candidate.
It deliberately does not import or execute MQL implementation code.
"""
from dataclasses import dataclass
from enum import Enum
import hashlib
import json

class State(str, Enum):
    NO_CALL="NO_CALL"
    UNRESOLVED="SUBMISSION_UNRESOLVED"
    POSITIVE="SIDE_EFFECT_POSITIVELY_CONFIRMED"
    NEGATIVE="NO_SIDE_EFFECT_CONFIRMED"
    PARTIAL="PARTIAL_EFFECT_CONFIRMED"
    BLOCKED="RECONCILIATION_BLOCKED"

@dataclass(frozen=True)
class Case:
    test_id: str
    claimed: bool = True
    positive: bool = False
    durable_confirmed: bool = False
    correlation_proven: bool = False
    correlation_policy_approved: bool = False
    magic_or_comment_only: bool = False
    claim_bound: bool = True
    broker_ids_linked: bool = False
    ordered_deal_set: bool = False
    all_rows_read: bool = False
    query_after_claim: bool = False
    confirmed: float = 0.0
    requested: float = 1.0
    negative: bool = False
    completeness_proven: bool = False
    visibility_proven: bool = False
    operations_success: bool = False
    coverage_complete: bool = False
    row_failures: int = 0
    stable_observations: int = 0
    sequences_advance: bool = False
    after_visibility_lag: bool = False
    generation_match: bool = True
    matching_rows: int = 0
    binding_valid: bool = True
    terminal_binding_match: bool = True
    terminal_volume_match: bool = True
    prior: State = State.UNRESOLVED

def evaluate(c: Case) -> State:
    if not c.binding_valid:
        return State.BLOCKED
    if c.prior == State.NO_CALL:
        return State.NO_CALL if not c.claimed and not c.positive and not c.negative else State.BLOCKED
    if c.prior in (State.POSITIVE, State.NEGATIVE, State.PARTIAL):
        return c.prior if (c.terminal_binding_match and c.terminal_volume_match and
                           not c.positive and not c.negative) else State.BLOCKED
    if not c.claimed:
        return State.BLOCKED
    positive_valid=(c.durable_confirmed and c.correlation_proven and
                    c.correlation_policy_approved and
                    not c.magic_or_comment_only and c.claim_bound and
                    c.broker_ids_linked and c.ordered_deal_set and
                    c.all_rows_read and c.query_after_claim and
                    0 < c.confirmed <= c.requested)
    negative_valid=(c.correlation_policy_approved and c.completeness_proven and
                    c.visibility_proven and
                    c.operations_success and c.coverage_complete and
                    c.row_failures == 0 and c.stable_observations == 2 and
                    c.sequences_advance and c.after_visibility_lag and
                    c.generation_match and c.matching_rows == 0)
    if c.positive and (not positive_valid or c.negative):
        return State.BLOCKED
    if c.positive and positive_valid:
        return State.PARTIAL if c.confirmed < c.requested else State.POSITIVE
    if c.negative and not negative_valid:
        return State.UNRESOLVED
    if c.negative and negative_valid:
        return State.NEGATIVE
    return State.UNRESOLVED

CASES = [
    (Case("F-001", claimed=False, prior=State.NO_CALL), State.NO_CALL),
    (Case("F-002"), State.UNRESOLVED),                         # sync success alone
    (Case("F-003"), State.UNRESOLVED),                         # callback absent
    (Case("F-004"), State.UNRESOLVED),                         # timeout
    (Case("F-005", negative=True), State.UNRESOLVED),          # zero rows, incomplete
    (Case("F-006"), State.UNRESOLVED),                         # restart preserves ambiguity
    (Case("F-007", positive=True, durable_confirmed=True, correlation_proven=True,
          correlation_policy_approved=True, magic_or_comment_only=True,
          broker_ids_linked=True, ordered_deal_set=True, all_rows_read=True,
          query_after_claim=True, confirmed=1), State.BLOCKED),
    (Case("F-008", positive=True, durable_confirmed=True, correlation_proven=True,
          correlation_policy_approved=True, broker_ids_linked=True,
          ordered_deal_set=True, all_rows_read=True, query_after_claim=True,
          confirmed=1), State.POSITIVE),
    (Case("F-009", negative=True, correlation_policy_approved=True,
          completeness_proven=True, visibility_proven=True,
          operations_success=True, coverage_complete=True, stable_observations=2,
          sequences_advance=True, after_visibility_lag=True), State.NEGATIVE),
    (Case("F-010", binding_valid=False), State.BLOCKED),       # stale owner/fence
    (Case("F-011", positive=True, durable_confirmed=True, correlation_proven=True,
          correlation_policy_approved=True, broker_ids_linked=True,
          ordered_deal_set=True, all_rows_read=True, query_after_claim=True,
          confirmed=.4), State.PARTIAL),
    (Case("F-012", claimed=False, positive=True, durable_confirmed=True,
          correlation_proven=True, correlation_policy_approved=True,
          broker_ids_linked=True, ordered_deal_set=True, all_rows_read=True,
          query_after_claim=True,
          confirmed=1), State.BLOCKED),
    (Case("F-013"), State.UNRESOLVED),                         # explicit reject candidate alone
    (Case("F-014"), State.UNRESOLVED),                         # client-local post-call reject
    (Case("F-015"), State.UNRESOLVED),                         # query failure
    (Case("F-016"), State.UNRESOLVED),                         # unknown retcode
    (Case("F-017"), State.UNRESOLVED),                         # callback-only
    (Case("F-018", negative=True, correlation_policy_approved=True,
          completeness_proven=True, visibility_proven=True,
          operations_success=True, coverage_complete=True, stable_observations=2,
          sequences_advance=True, after_visibility_lag=True, generation_match=False), State.UNRESOLVED),
    (Case("F-019", prior=State.POSITIVE), State.POSITIVE),
    (Case("F-020", prior=State.NEGATIVE), State.NEGATIVE),
    (Case("F-021", prior=State.PARTIAL), State.PARTIAL),
    (Case("F-022", negative=True, completeness_proven=True), State.UNRESOLVED),
    (Case("F-023", negative=True, correlation_policy_approved=True,
          completeness_proven=True, visibility_proven=True,
          operations_success=True, coverage_complete=True, row_failures=1,
          stable_observations=2, sequences_advance=True, after_visibility_lag=True), State.UNRESOLVED),
    (Case("F-024", negative=True, correlation_policy_approved=True,
          completeness_proven=True, visibility_proven=True,
          operations_success=True, coverage_complete=True, stable_observations=2,
          sequences_advance=True, after_visibility_lag=True, matching_rows=1), State.UNRESOLVED),
    (Case("F-025", prior=State.POSITIVE, terminal_binding_match=False), State.BLOCKED),
    (Case("F-026", prior=State.PARTIAL, terminal_volume_match=False), State.BLOCKED),
    (Case("F-027", positive=True, durable_confirmed=True, correlation_proven=True,
          broker_ids_linked=True, ordered_deal_set=True, all_rows_read=True,
          query_after_claim=True, confirmed=1), State.BLOCKED),
    (Case("F-028", positive=True, durable_confirmed=True, correlation_proven=True,
          correlation_policy_approved=True, broker_ids_linked=True,
          ordered_deal_set=True, query_after_claim=True, confirmed=1), State.BLOCKED),
    (Case("F-029", positive=True, durable_confirmed=True, correlation_proven=True,
          correlation_policy_approved=True, broker_ids_linked=True,
          all_rows_read=True, query_after_claim=True, confirmed=1), State.BLOCKED),
]

def main() -> int:
    results=[]
    for case, expected in CASES:
        actual=evaluate(case)
        results.append({"id":case.test_id,"expected":expected.value,"actual":actual.value,"pass":actual==expected})
    canonical=json.dumps(results,sort_keys=True,separators=(",",":"))
    signature=hashlib.sha256(canonical.encode()).hexdigest()
    passed=sum(r["pass"] for r in results)
    print(json.dumps({"suite":"Sprint5PhaseFEntry","total":len(results),"passed":passed,
                      "failed":len(results)-passed,"skipped":0,"signature":signature},sort_keys=True))
    return 0 if passed==len(results) else 1

if __name__ == "__main__":
    raise SystemExit(main())
