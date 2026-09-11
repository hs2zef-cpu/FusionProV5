#!/usr/bin/env python3
"""TEST ONLY / NOT FOR PRODUCTION / NO BROKER ACCESS.

Independent deterministic broker-double oracle for the Phase F adapter.
It does not import or execute the MQL implementation.
"""
from dataclasses import dataclass, replace
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
class Scenario:
    test_id: str
    claim_granted_now: bool = True
    exact_profile: bool = True
    terminal_permission: bool = True
    mql_permission: bool = True
    account_permission: bool = True
    expert_permission: bool = True
    normalized_payload_bound: bool = True
    filling_supported: bool = True
    filling_exact_single: bool = True
    final_environment_stable: bool = True
    wire_payload_exact: bool = True
    broker_outcome: str = "none"
    callback: bool = False
    query_complete: bool = False
    governed_capability: bool = False
    adapter_authors_capability: bool = False
    query_row_counts_exact: bool = True
    policy_pinned: bool = True
    broker_execution_independent: bool = True
    timing_valid: bool = True
    generation_valid: bool = True
    positive_volume: float = 0.0
    requested_volume: float = 1.0
    positive_binding: bool = True
    magic_comment_only: bool = False
    no_call_proof: bool = False
    claimed_record: bool = True
    prior: State = State.UNRESOLVED
    terminal_replay_exact: bool = True
    later_conflict: bool = False
    publication_lease_current: bool = True
    publication_revision_exact: bool = True
    after_restart: bool = False


@dataclass(frozen=True)
class Outcome:
    state: State
    send_calls: int
    retry_allowed: bool = False
    residual_authority: bool = False
    published: bool = False


def evaluate(s: Scenario) -> Outcome:
    if s.prior is State.BLOCKED:
        return Outcome(State.BLOCKED, 0)
    if s.prior in (State.POSITIVE, State.NEGATIVE, State.PARTIAL):
        state = s.prior if s.terminal_replay_exact and not s.later_conflict else State.BLOCKED
        return Outcome(state, 0)
    if s.prior is State.NO_CALL:
        valid = s.no_call_proof and not s.claimed_record and s.broker_outcome == "none" and not s.callback
        return Outcome(State.NO_CALL if valid else State.BLOCKED, 0)

    preflight = all((s.claim_granted_now, s.exact_profile, s.terminal_permission,
                     s.mql_permission, s.account_permission, s.expert_permission,
                     s.normalized_payload_bound, s.filling_supported,
                     s.filling_exact_single, s.final_environment_stable,
                     s.wire_payload_exact))
    if not preflight:
        return Outcome(State.UNRESOLVED, 0)
    send_calls = 1

    # Sync response, callback, timeout, transport failure and retcode are never terminal.
    if s.positive_volume > 0:
        if not s.positive_binding or s.magic_comment_only or not s.policy_pinned:
            return Outcome(State.BLOCKED, send_calls)
        state = State.POSITIVE if s.positive_volume >= s.requested_volume else State.PARTIAL
    elif s.query_complete and s.query_row_counts_exact and s.governed_capability and \
            not s.adapter_authors_capability and s.policy_pinned and \
            s.broker_execution_independent and s.timing_valid and s.generation_valid:
        state = State.NEGATIVE
    else:
        state = State.UNRESOLVED

    published = s.publication_lease_current and s.publication_revision_exact
    return Outcome(state, send_calls, published=published)


def classify_sync(invoked: bool, transport: bool, retcode: int) -> str:
    if not invoked:
        return "PRE_CALL_REJECTED"
    if retcode == 10027:
        return "CLIENT_LOCAL_REJECTION_UNRESOLVED"
    if retcode == 10012:
        return "TIMEOUT_UNRESOLVED"
    if retcode in (10008, 10009, 10010) and transport:
        return "ACCEPTED_UNRESOLVED"
    if retcode in (*range(10004, 10008), *range(10011, 10047)):
        return "BROKER_REJECTION_CANDIDATE_UNRESOLVED"
    if not transport:
        return "TRANSPORT_FAILURE_UNRESOLVED"
    if retcode == 0:
        return "MALFORMED_UNRESOLVED"
    return "UNKNOWN_UNRESOLVED"


def case(test_id: str, expected: State, sends: int = 1, published: bool | None = None, **kw):
    return Scenario(test_id, **kw), expected, sends, published


CASES = [
    case("BA-001-PRECALL-CLAIM", State.UNRESOLVED, 0, claim_granted_now=False),
    case("BA-002-PRECALL-PROFILE", State.UNRESOLVED, 0, exact_profile=False),
    case("BA-003-PRECALL-TERMINAL", State.UNRESOLVED, 0, terminal_permission=False),
    case("BA-004-PRECALL-MQL", State.UNRESOLVED, 0, mql_permission=False),
    case("BA-005-PRECALL-ACCOUNT", State.UNRESOLVED, 0, account_permission=False),
    case("BA-006-PRECALL-EXPERT", State.UNRESOLVED, 0, expert_permission=False),
    case("BA-007-PRECALL-PAYLOAD", State.UNRESOLVED, 0, normalized_payload_bound=False),
    case("BA-008-PRECALL-FILLING", State.UNRESOLVED, 0, filling_supported=False),
    case("BA-009-SYNC-ACCEPTED", State.UNRESOLVED, broker_outcome="sync_accepted"),
    case("BA-010-CALLBACK-ONLY", State.UNRESOLVED, broker_outcome="sync_accepted", callback=True),
    case("BA-011-CALLBACK-ABSENT", State.UNRESOLVED, broker_outcome="sync_accepted"),
    case("BA-012-TIMEOUT", State.UNRESOLVED, broker_outcome="timeout"),
    case("BA-013-TRANSPORT", State.UNRESOLVED, broker_outcome="transport_failure"),
    case("BA-014-UNKNOWN-RETCODE", State.UNRESOLVED, broker_outcome="unknown_retcode"),
    case("BA-015-QUERY-INCOMPLETE", State.UNRESOLVED, query_complete=False),
    case("BA-016-FULL-POSITIVE", State.POSITIVE, positive_volume=1.0),
    case("BA-017-PARTIAL", State.PARTIAL, positive_volume=.4),
    case("BA-018-ORPHAN", State.BLOCKED, positive_volume=1.0, positive_binding=False),
    case("BA-019-NO-CALL", State.NO_CALL, 0, prior=State.NO_CALL, claimed_record=False, no_call_proof=True),
    case("BA-020-NO-CALL-CONTRADICTION", State.BLOCKED, 0, prior=State.NO_CALL, no_call_proof=True),
    case("BA-021-CAPABILITY-SELF-ATTEST", State.UNRESOLVED, query_complete=True, governed_capability=False),
    case("BA-022-POLICY-DRIFT", State.UNRESOLVED, query_complete=True, governed_capability=True, policy_pinned=False),
    case("BA-023-WATERMARK-TIMING", State.UNRESOLVED, query_complete=True, governed_capability=True, timing_valid=False),
    case("BA-024-GENERATION", State.UNRESOLVED, query_complete=True, governed_capability=True, generation_valid=False),
    case("BA-025-SHARED-SOURCE", State.UNRESOLVED, query_complete=True, governed_capability=True, broker_execution_independent=False),
    case("BA-026-VALID-NEGATIVE", State.NEGATIVE, query_complete=True, governed_capability=True),
    case("BA-027-STALE-LEASE-PUBLISH", State.POSITIVE, positive_volume=1.0, publication_lease_current=False, published=False),
    case("BA-028-STALE-REVISION-PUBLISH", State.POSITIVE, positive_volume=1.0, publication_revision_exact=False, published=False),
    case("BA-029-RESTART-UNRESOLVED", State.UNRESOLVED, after_restart=True),
    case("BA-030-TERMINAL-REPLAY", State.POSITIVE, 0, prior=State.POSITIVE),
    case("BA-031-TERMINAL-CONFLICT", State.BLOCKED, 0, prior=State.POSITIVE, later_conflict=True),
    case("BA-032-BLOCKED-STICKY", State.BLOCKED, 0, prior=State.BLOCKED),
    case("BA-033-MAGIC-COMMENT-ONLY", State.BLOCKED, positive_volume=1.0, magic_comment_only=True),
    case("BA-034-F0-UNPROVEN", State.UNRESOLVED, query_complete=True, governed_capability=False),
    case("BA-041-FINAL-ENVIRONMENT-CHANGED", State.UNRESOLVED, 0, final_environment_stable=False),
    case("BA-042-WIRE-DIGEST-MISMATCH", State.UNRESOLVED, 0, wire_payload_exact=False),
    case("BA-043-COMBINED-FILLING", State.UNRESOLVED, 0, filling_exact_single=False),
    case("BA-044-ADAPTER-SELF-ATTEST", State.UNRESOLVED, query_complete=True,
         governed_capability=True, adapter_authors_capability=True),
    case("BA-045-BROKER-ROW-OMISSION", State.UNRESOLVED, query_complete=True,
         governed_capability=True, query_row_counts_exact=False),
]

SYNC_CASES = (
    ("BA-035-SYNC-DONE", True, True, 10009, "ACCEPTED_UNRESOLVED"),
    ("BA-036-SYNC-CLIENT-LOCAL", True, False, 10027, "CLIENT_LOCAL_REJECTION_UNRESOLVED"),
    ("BA-037-SYNC-TIMEOUT", True, False, 10012, "TIMEOUT_UNRESOLVED"),
    ("BA-038-SYNC-BROKER-REJECT", True, False, 10006, "BROKER_REJECTION_CANDIDATE_UNRESOLVED"),
    ("BA-039-SYNC-TRANSPORT", True, False, 0, "TRANSPORT_FAILURE_UNRESOLVED"),
    ("BA-040-SYNC-UNKNOWN", True, True, 19999, "UNKNOWN_UNRESOLVED"),
)


def main() -> int:
    rows = []
    for scenario, expected, expected_sends, expected_published in CASES:
        actual = evaluate(scenario)
        passed = (actual.state is expected and actual.send_calls == expected_sends and
                  actual.send_calls <= 1 and not actual.retry_allowed and not actual.residual_authority)
        if expected_published is not None:
            passed = passed and actual.published is expected_published
        rows.append({"id": scenario.test_id, "expected": expected.value, "actual": actual.state.value,
                     "send_calls": actual.send_calls, "pass": passed})
    for test_id, invoked, transport, retcode, expected in SYNC_CASES:
        actual = classify_sync(invoked, transport, retcode)
        rows.append({"id": test_id, "expected": expected, "actual": actual,
                     "send_calls": 1 if invoked else 0, "pass": actual == expected})
    canonical = json.dumps(rows, sort_keys=True, separators=(",", ":"))
    signature = hashlib.sha256(canonical.encode()).hexdigest()
    passed = sum(r["pass"] for r in rows)
    print(json.dumps({"suite": "Sprint5PhaseFBrokerAdapter", "total": len(rows), "passed": passed,
                      "failed": len(rows)-passed, "skipped": 0, "signature": signature}, sort_keys=True))
    return 0 if passed == len(rows) else 1


if __name__ == "__main__":
    raise SystemExit(main())
