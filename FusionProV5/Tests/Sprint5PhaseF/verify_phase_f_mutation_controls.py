#!/usr/bin/env python3
"""TEST ONLY / NOT FOR PRODUCTION / NO BROKER ACCESS.

Deliberately broken Phase F models. Each control constructs a concrete unsafe
result, then applies an independently stated invariant to the same fixture.
Ordinary negative cases and static token scans are not counted here.
"""
import hashlib
import json


def control(test_id, fixture, broken_model, unsafe_predicate, invariant_detector):
    broken_result = broken_model(fixture)
    unsafe_result_observed = bool(unsafe_predicate(fixture, broken_result))
    target_assertion_detected = bool(invariant_detector(fixture, broken_result))
    return {
        "id": test_id,
        "unsafe_result_observed": unsafe_result_observed,
        "target_assertion_detected": target_assertion_detected,
        "pass": unsafe_result_observed and target_assertion_detected,
    }


def main() -> int:
    rows = [
        control(
            "MC-NOCALL-BYPASS", {"claimed": True},
            lambda _: {"state": "NO_CALL"},
            lambda _, r: r["state"] == "NO_CALL",
            lambda f, r: f["claimed"] and r["state"] == "NO_CALL",
        ),
        control(
            "MC-ORPHAN-BINDING", {"binding_valid": False, "durable_side_effect": True},
            lambda _: {"state": "SIDE_EFFECT_POSITIVELY_CONFIRMED"},
            lambda _, r: r["state"] == "SIDE_EFFECT_POSITIVELY_CONFIRMED",
            lambda f, r: not f["binding_valid"] and f["durable_side_effect"] and r["state"] != "RECONCILIATION_BLOCKED",
        ),
        control(
            "MC-RESIDUAL-AUTHORITY", {"confirmed": 0.4, "requested": 1.0},
            lambda f: {"state": "PARTIAL_EFFECT_CONFIRMED", "residual_submission_authority": f["requested"]-f["confirmed"]},
            lambda _, r: r["residual_submission_authority"] > 0,
            lambda f, r: f["confirmed"] < f["requested"] and r["residual_submission_authority"] != 0,
        ),
        control(
            "MC-WATERMARK-COLLAPSE", {"claimed_at": 100, "lag": 30, "obs1": 110, "obs2": 111, "stability": 20},
            lambda _: {"state": "NO_SIDE_EFFECT_CONFIRMED"},
            lambda _, r: r["state"] == "NO_SIDE_EFFECT_CONFIRMED",
            lambda f, _: f["obs1"] < f["claimed_at"]+f["lag"] or f["obs2"] < f["obs1"]+f["stability"],
        ),
        control(
            "MC-CAPABILITY-SELFATTEST", {"proof_author": "BROKER_ADAPTER", "required_author": "OPERATOR"},
            lambda _: {"state": "NO_SIDE_EFFECT_CONFIRMED"},
            lambda _, r: r["state"] == "NO_SIDE_EFFECT_CONFIRMED",
            lambda f, _: f["proof_author"] != f["required_author"],
        ),
        control(
            "MC-POLICY-DRIFT", {"pinned": (1, "digest-v1"), "evaluated": (2, "digest-v2")},
            lambda _: {"state": "NO_SIDE_EFFECT_CONFIRMED"},
            lambda _, r: r["state"] == "NO_SIDE_EFFECT_CONFIRMED",
            lambda f, _: f["pinned"] != f["evaluated"],
        ),
        control(
            "MC-TERMINAL-OVERWRITE", {"prior": "SIDE_EFFECT_POSITIVELY_CONFIRMED"},
            lambda _: {"state": "SUBMISSION_UNRESOLVED"},
            lambda _, r: r["state"] == "SUBMISSION_UNRESOLVED",
            lambda f, r: f["prior"] != r["state"],
        ),
        control(
            "MC-SINGLE-ROW-POSITIVE", {"enumerated": 2, "read": 1},
            lambda _: {"state": "SIDE_EFFECT_POSITIVELY_CONFIRMED"},
            lambda _, r: r["state"] == "SIDE_EFFECT_POSITIVELY_CONFIRMED",
            lambda f, _: f["read"] != f["enumerated"],
        ),
        control(
            "MC-DIGEST-DOMAIN-SUBSTITUTION", {"expected_domain": "CAPABILITY-PROOF", "actual_domain": "CORRELATION-POLICY"},
            lambda _: {"accepted": True},
            lambda _, r: r["accepted"],
            lambda f, _: f["expected_domain"] != f["actual_domain"],
        ),
        control(
            "MC-SHARED-EVIDENCE-SOURCE", {"broker_path": "shared-cache", "execution_path": "shared-cache"},
            lambda _: {"state": "NO_SIDE_EFFECT_CONFIRMED"},
            lambda _, r: r["state"] == "NO_SIDE_EFFECT_CONFIRMED",
            lambda f, _: f["broker_path"] == f["execution_path"],
        ),
    ]
    canonical = json.dumps(rows, sort_keys=True, separators=(",", ":"))
    digest = hashlib.sha256(canonical.encode()).hexdigest()
    passed = sum(row["pass"] for row in rows)
    print(json.dumps({
        "suite": "Sprint5PhaseFMutationControls",
        "classification": "DELIBERATELY BROKEN INDEPENDENT TEST DOUBLES; NOT ORDINARY NEGATIVE TESTS",
        "total": len(rows), "passed": passed, "failed": len(rows)-passed,
        "unsafe_results_observed": sum(row["unsafe_result_observed"] for row in rows),
        "target_assertions_detected": sum(row["target_assertion_detected"] for row in rows),
        "digest": digest, "rows": rows,
    }, sort_keys=True))
    return 0 if passed == len(rows) else 1


if __name__ == "__main__":
    raise SystemExit(main())
