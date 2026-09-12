#!/usr/bin/env python3
"""TEST ONLY / NOT FOR PRODUCTION / NO BROKER ACCESS."""
import hashlib
import json
from verify_phase_f_broker_adapter import Outcome, Scenario, State, evaluate


AUDIT_TARGET_PATHS = {
    "MC-TOCTOU-WINDOW": lambda scenario: (
        scenario.claim_granted_now and scenario.terminal_permission and
        scenario.mql_permission and scenario.account_permission and
        scenario.expert_permission and scenario.exact_profile and
        scenario.normalized_payload_bound and scenario.filling_supported and
        scenario.filling_exact_single and
        not scenario.final_environment_stable
    ),
    "MC-POSTDIGEST-NORMALIZE": lambda scenario: (
        scenario.claim_granted_now and scenario.terminal_permission and
        scenario.mql_permission and scenario.account_permission and
        scenario.expert_permission and scenario.exact_profile and
        scenario.normalized_payload_bound and scenario.filling_supported and
        scenario.filling_exact_single and
        scenario.final_environment_stable and not scenario.wire_payload_exact
    ),
    "MC-ADAPTER-SELFATTEST": lambda scenario: (
        scenario.query_complete and scenario.governed_capability and
        scenario.broker_execution_independent and scenario.query_row_counts_exact and
        scenario.adapter_authors_capability
    ),
    "MC-FILLING-COERCION": lambda scenario: (
        scenario.claim_granted_now and scenario.terminal_permission and
        scenario.mql_permission and scenario.account_permission and
        scenario.expert_permission and scenario.exact_profile and
        scenario.normalized_payload_bound and scenario.filling_supported and
        not scenario.filling_exact_single
    ),
    "MC-QUERY-ROW-OMISSION": lambda scenario: (
        scenario.query_complete and scenario.governed_capability and
        scenario.broker_execution_independent and not scenario.adapter_authors_capability and
        not scenario.query_row_counts_exact
    ),
}

AUDIT_TARGET_DETECTORS = {
    "MC-TOCTOU-WINDOW": lambda scenario, safe, mutant: (
        AUDIT_TARGET_PATHS["MC-TOCTOU-WINDOW"](scenario) and
        safe.state is State.UNRESOLVED and safe.send_calls == 0 and
        mutant.state is State.UNRESOLVED and mutant.send_calls == 1
    ),
    "MC-POSTDIGEST-NORMALIZE": lambda scenario, safe, mutant: (
        AUDIT_TARGET_PATHS["MC-POSTDIGEST-NORMALIZE"](scenario) and
        safe.state is State.UNRESOLVED and safe.send_calls == 0 and
        mutant.state is State.UNRESOLVED and mutant.send_calls == 1
    ),
    "MC-ADAPTER-SELFATTEST": lambda scenario, safe, mutant: (
        AUDIT_TARGET_PATHS["MC-ADAPTER-SELFATTEST"](scenario) and
        safe.state is State.UNRESOLVED and mutant.state is State.NEGATIVE and
        safe.send_calls == mutant.send_calls
    ),
    "MC-FILLING-COERCION": lambda scenario, safe, mutant: (
        AUDIT_TARGET_PATHS["MC-FILLING-COERCION"](scenario) and
        safe.state is State.UNRESOLVED and safe.send_calls == 0 and
        mutant.state is State.UNRESOLVED and mutant.send_calls == 1
    ),
    "MC-QUERY-ROW-OMISSION": lambda scenario, safe, mutant: (
        AUDIT_TARGET_PATHS["MC-QUERY-ROW-OMISSION"](scenario) and
        safe.state is State.UNRESOLVED and mutant.state is State.NEGATIVE and
        safe.send_calls == mutant.send_calls
    ),
}

AUDIT_TARGET_GUARDS = {
    "MC-TOCTOU-WINDOW": "SWV5S5_F_AdapterValidateFinalEnvironment",
    "MC-POSTDIGEST-NORMALIZE": "SWV5S5_F_DeriveAdapterWirePayloadDigest + no-post-digest-mutation source shape",
    "MC-ADAPTER-SELFATTEST": "SWV5S5_F_IsCapabilityProofValid + adapter no-authorship source shape",
    "MC-FILLING-COERCION": "SWV5S5_F_AdapterResolveFilling",
    "MC-QUERY-ROW-OMISSION": "SWV5S5_F_AdapterBrokerQueryShapeComplete",
}


def mutations():
    # Each tuple contains an executable mutant outcome and the independent safe
    # oracle outcome for the same adversarial input. Ordinary negative tests are
    # not counted as mutation detection power.
    claim = Scenario("claim", claim_granted_now=False)
    permission = Scenario("permission", terminal_permission=False)
    sync = Scenario("sync", broker_outcome="sync_accepted")
    callback = Scenario("callback", broker_outcome="sync_accepted", callback=True)
    capability = Scenario("capability", query_complete=True, governed_capability=False)
    incomplete = Scenario("incomplete", query_complete=False, governed_capability=True)
    shared = Scenario("shared", query_complete=True, governed_capability=True, broker_execution_independent=False)
    stale = Scenario("stale", positive_volume=1.0, publication_revision_exact=False)
    partial = Scenario("partial", positive_volume=.4)
    carrier = Scenario("carrier", positive_volume=1.0, magic_comment_only=True)
    terminal = Scenario("terminal", prior=State.POSITIVE, later_conflict=True)
    toctou = Scenario("toctou", final_environment_stable=False)
    postdigest = Scenario("postdigest", wire_payload_exact=False)
    selfattest = Scenario("selfattest", query_complete=True, governed_capability=True,
                          adapter_authors_capability=True)
    filling = Scenario("filling", filling_exact_single=False)
    omission = Scenario("omission", query_complete=True, governed_capability=True,
                        query_row_counts_exact=False)
    return (
        ("MC-CLAIM-FABRICATION", claim, Outcome(State.UNRESOLVED, 1)),
        ("MC-PREFLIGHT-BYPASS", permission, Outcome(State.UNRESOLVED, 1)),
        ("MC-SYNC-AS-CONFIRMATION", sync, Outcome(State.POSITIVE, 1)),
        ("MC-CALLBACK-AS-CONFIRMATION", callback, Outcome(State.POSITIVE, 1)),
        ("MC-AUTO-RETRY", sync, Outcome(State.UNRESOLVED, 1, retry_allowed=True)),
        ("MC-CAPABILITY-SELFATTEST", capability, Outcome(State.NEGATIVE, 1)),
        ("MC-INCOMPLETE-AS-EMPTY", incomplete, Outcome(State.NEGATIVE, 1)),
        ("MC-SHARED-EVIDENCE-SOURCE", shared, Outcome(State.NEGATIVE, 1)),
        ("MC-STALE-CAS-EQUALITY", stale, Outcome(State.POSITIVE, 1, published=True)),
        ("MC-RESIDUAL-AUTHORITY", partial, Outcome(State.PARTIAL, 1, residual_authority=True)),
        ("MC-MAGIC-COMMENT-SOLE", carrier, Outcome(State.POSITIVE, 1)),
        ("MC-TERMINAL-REGRESSION", terminal, Outcome(State.UNRESOLVED, 0)),
        ("MC-TOCTOU-WINDOW", toctou, Outcome(State.UNRESOLVED, 1)),
        ("MC-POSTDIGEST-NORMALIZE", postdigest, Outcome(State.UNRESOLVED, 1)),
        ("MC-ADAPTER-SELFATTEST", selfattest, Outcome(State.NEGATIVE, 1)),
        ("MC-FILLING-COERCION", filling, Outcome(State.UNRESOLVED, 1)),
        ("MC-QUERY-ROW-OMISSION", omission, Outcome(State.NEGATIVE, 1)),
    )


def main() -> int:
    rows = []
    for test_id, scenario, mutant in mutations():
        safe = evaluate(scenario)
        unsafe_result_observed = (
            mutant.send_calls > safe.send_calls or mutant.state is not safe.state or
            mutant.retry_allowed or mutant.residual_authority or (mutant.published and not safe.published)
        )
        target_detector = AUDIT_TARGET_DETECTORS.get(test_id)
        target_path = AUDIT_TARGET_PATHS.get(test_id)
        target_path_reached = target_path(scenario) if target_path is not None else True
        target_assertion_detected = (
            target_detector(scenario, safe, mutant) if target_detector is not None else mutant != safe
        )
        passed = unsafe_result_observed and target_assertion_detected
        rows.append({"id": test_id, "unsafe_result_observed": unsafe_result_observed,
                     "target_assertion_detected": target_assertion_detected,
                     "target_specific_detector": target_detector is not None,
                     "target_guard": AUDIT_TARGET_GUARDS.get(test_id, "independent safe-oracle outcome"),
                     "detector_provenance": "PYTHON_ORACLE",
                     "target_path_reached": target_path_reached,
                     "unrelated_earlier_guard_rejection": not target_path_reached,
                     "pass": passed})
    canonical = json.dumps(rows, sort_keys=True, separators=(",", ":"))
    signature = hashlib.sha256(canonical.encode()).hexdigest()
    passed = sum(r["pass"] for r in rows)
    print(json.dumps({"suite": "Sprint5PhaseFBrokerAdapterMutations", "total": len(rows), "passed": passed,
                      "failed": len(rows)-passed, "skipped": 0, "signature": signature,
                      "ordinary_negative_tests_counted_as_mutation_power": False,
                      "rows": rows}, sort_keys=True))
    return 0 if passed == len(rows) else 1


if __name__ == "__main__":
    raise SystemExit(main())
