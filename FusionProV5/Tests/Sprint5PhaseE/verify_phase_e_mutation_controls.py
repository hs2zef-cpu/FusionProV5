"""TEST ONLY / NOT FOR PRODUCTION / NO BROKER ACCESS.

Targeted Phase-E mutation controls.  Each control first executes deliberately
broken test-only behavior, then a separate invariant observer checks the unsafe
result.  These controls are Python-only and are not MQL runtime evidence.
"""
from __future__ import annotations

from dataclasses import asdict, dataclass
import hashlib
import json
import sys


@dataclass(frozen=True)
class MutationResult:
    test_id: str
    mutant_behavior: str
    fixture: str
    unsafe_result_observed: bool
    intended_assertion: str
    target_assertion_detected: bool
    detection_reason: str
    proof_source: str

    @property
    def passed(self) -> bool:
        return self.unsafe_result_observed and self.target_assertion_detected


def _sha(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def _mutant_p_effective(provisional_seen: bool, claim_succeeded: bool,
                        replayed_p: bool) -> bool:
    del claim_succeeded
    return provisional_seen or replayed_p


def control_p() -> MutationResult:
    provisional_seen, claim_succeeded, replayed_p = True, False, False
    mutant_effective = _mutant_p_effective(provisional_seen, claim_succeeded, replayed_p)
    broker_eligible = mutant_effective
    p_claim_invariant_broken = mutant_effective != claim_succeeded
    return MutationResult(
        "MC-P",
        "provisional P is treated as effective although Invocation Claim failed",
        "valid provisional ADR-020 stable point; Claim returns failure",
        mutant_effective and broker_eligible,
        "P is effective iff the same uninterrupted operation wins Claim",
        p_claim_invariant_broken and broker_eligible,
        "the mutant exposed broker eligibility without a successful Claim",
        "control_p / _mutant_p_effective",
    )


@dataclass(frozen=True)
class SealedWorldObject:
    domain: str
    world: str
    payload: str
    digest: str


def _sealed(domain: str, world: str) -> SealedWorldObject:
    payload = f"{domain}|{world}|FENCE-7|REQUEST-SET-{world}"
    return SealedWorldObject(domain, world, payload, _sha(payload))


def _locally_valid(obj: SealedWorldObject) -> bool:
    return obj.digest == _sha(obj.payload)


def _mutant_local_only_reconciliation(objects: tuple[SealedWorldObject, ...]) -> bool:
    return all(_locally_valid(obj) for obj in objects)


def _joint_world_coherent(objects: tuple[SealedWorldObject, ...]) -> bool:
    return len({obj.world for obj in objects}) == 1


def control_joint() -> MutationResult:
    objects = (
        _sealed("CHECKPOINT", "A"),
        _sealed("REQUEST_SET", "B"),
        _sealed("BROKER_SUMMARY", "C"),
        _sealed("EXECUTION_SUMMARY", "D"),
    )
    all_local_seals_valid = all(_locally_valid(obj) for obj in objects)
    mutant_accepted = _mutant_local_only_reconciliation(objects)
    joint_coherent = _joint_world_coherent(objects)
    return MutationResult(
        "MC-JOINT",
        "reconciliation validates each sealed object locally and omits joint-world coherence",
        "P11 four-way fixture with four valid seals from worlds A/B/C/D",
        all_local_seals_valid and mutant_accepted and not joint_coherent,
        "individually valid Checkpoint/Request Set/Broker/Execution objects must describe one world",
        mutant_accepted and not joint_coherent,
        "all local guards passed, then the independent world-coherence assertion rejected acceptance",
        "control_joint / _mutant_local_only_reconciliation / _joint_world_coherent",
    )


@dataclass(frozen=True)
class DomainObject:
    domain: str
    payload: str
    digest: str


def _domain_object(domain: str, payload: str) -> DomainObject:
    return DomainObject(domain, payload, _sha(f"{domain}|{payload}"))


def _correct_domain_validation(obj: DomainObject, expected_domain: str) -> bool:
    return obj.domain == expected_domain and obj.digest == _sha(f"{obj.domain}|{obj.payload}")


def _mutant_domain_ignored(obj: DomainObject, expected_domain: str) -> bool:
    del expected_domain
    return obj.digest == _sha(f"{obj.domain}|{obj.payload}")


def control_domain() -> MutationResult:
    request_set = _domain_object("REQUEST_SET", "WORLD-A|FENCE-7")
    expected_domain = "CHECKPOINT"
    correct_accepted = _correct_domain_validation(request_set, expected_domain)
    mutant_accepted = _mutant_domain_ignored(request_set, expected_domain)
    return MutationResult(
        "MC-DOMAIN",
        "validator verifies the source seal but ignores the required target type/domain",
        "validly sealed Request Set substituted at the Checkpoint boundary",
        mutant_accepted and not correct_accepted,
        "a valid seal from a different frozen digest family is not interchangeable",
        mutant_accepted and request_set.domain != expected_domain,
        "the valid Request Set seal reached and bypassed the mutant domain guard",
        "control_domain / _mutant_domain_ignored / _correct_domain_validation",
    )


@dataclass(frozen=True)
class OwnershipBinding:
    request_id: str
    owner: str
    lease_id: str
    fence_epoch: int
    takeover_generation: int


def _mutant_logical_claim(permit: OwnershipBinding, snapshot: OwnershipBinding,
                          current: OwnershipBinding) -> bool:
    del current
    return permit.request_id == snapshot.request_id


def _logical_ownership_coherent(permit: OwnershipBinding, snapshot: OwnershipBinding,
                                current: OwnershipBinding) -> bool:
    return permit == snapshot == current


def control_ownership_logical() -> MutationResult:
    permit = OwnershipBinding("REQ-1", "OWNER-A", "LEASE-A", 7, 3)
    snapshot = OwnershipBinding("REQ-1", "OWNER-A", "LEASE-A", 7, 3)
    current = OwnershipBinding("REQ-1", "OWNER-B", "LEASE-B", 8, 4)
    mutant_accepted = _mutant_logical_claim(permit, snapshot, current)
    coherent = _logical_ownership_coherent(permit, snapshot, current)
    return MutationResult(
        "MC-OWNERSHIP-LOGICAL",
        "Claim-side validation checks request identity but ignores current owner/lease/fence/takeover consistency",
        "coherent Permit and Admission Snapshot from owner A after takeover to owner B",
        mutant_accepted and not coherent,
        "Permit, Admission Snapshot and current Claim ownership binding must be equal",
        mutant_accepted and not coherent,
        "request identity passed while the independent complete-binding assertion exposed stale ownership",
        "control_ownership_logical / _mutant_logical_claim / _logical_ownership_coherent",
    )


class BrokenSubmissionAuthorityStore:
    def __init__(self, row: str, current_epoch: int) -> None:
        self.row = row
        self.current_epoch = current_epoch
        self.claimed = False

    def mutant_claim_cas(self, expected_row: str, claimant_epoch: int) -> bool:
        del claimant_epoch
        if self.row != expected_row:
            return False
        self.claimed = True
        return True


def control_ownership_durable() -> MutationResult:
    store = BrokenSubmissionAuthorityStore("SUBMISSION_PENDING|REQ-1", current_epoch=8)
    claimant_epoch = 7
    row_before = store.row
    mutant_accepted = store.mutant_claim_cas(row_before, claimant_epoch)
    stale_at_serialization = claimant_epoch != store.current_epoch
    row_unchanged = store.row == row_before
    return MutationResult(
        "MC-OWNERSHIP-DURABLE",
        "Submission Authority CAS checks the row but omits ownership/takeover/fence re-observation inside serialization",
        "unchanged SUBMISSION_PENDING row; current fence advances 7->8; old epoch 7 attempts Claim",
        row_unchanged and stale_at_serialization and mutant_accepted and store.claimed,
        "authoritative Claim CAS must re-observe the current fence inside its serialization boundary",
        mutant_accepted and stale_at_serialization and store.claimed,
        "the row comparison passed and the broken CAS committed stale-owner Claim authority",
        "control_ownership_durable / BrokenSubmissionAuthorityStore.mutant_claim_cas",
    )


def _mutant_restart_claim_state(persisted_state: str) -> tuple[str, bool]:
    if persisted_state == "INVOCATION_CLAIMED_UNRESOLVED":
        return "CLAIM_GRANTED_NOW", True
    return "NO_GRANT", False


def control_grant() -> MutationResult:
    persisted = "INVOCATION_CLAIMED_UNRESOLVED"
    reconstructed, reinvocation_eligible = _mutant_restart_claim_state(persisted)
    event_local_grant_reconstructed = reconstructed == "CLAIM_GRANTED_NOW"
    return MutationResult(
        "MC-GRANT",
        "restart maps durable claimed-unresolved state back to event-local Claim grant",
        "valid persisted INVOCATION_CLAIMED_UNRESOLVED read after restart/takeover",
        event_local_grant_reconstructed and reinvocation_eligible,
        "restart/replay/takeover must never reconstruct CLAIM_GRANTED_NOW or reinvocation eligibility",
        event_local_grant_reconstructed and reinvocation_eligible,
        "the mutant recreated the event-local grant and enabled reinvocation",
        "control_grant / _mutant_restart_claim_state",
    )


class MutantDeduplicatingBroker:
    def __init__(self) -> None:
        self.calls: list[str] = []

    def invoke(self, identity: str) -> None:
        if identity not in self.calls:
            self.calls.append(identity)


def control_broker_dedupe() -> MutationResult:
    broker = MutantDeduplicatingBroker()
    presented = ("CLAIM-1", "CLAIM-1")
    for identity in presented:
        broker.invoke(identity)
    silently_suppressed = len(broker.calls) != len(presented)
    return MutationResult(
        "MC-BROKER-DEDUPE",
        "fake broker silently deduplicates repeated invocation identity",
        "two physical presentations of CLAIM-1",
        silently_suppressed,
        "dumb fake broker must log and count every invocation presented to it",
        len(broker.calls) != 2,
        "two presentations produced one logged call, exposing forbidden broker leniency",
        "control_broker_dedupe / MutantDeduplicatingBroker.invoke",
    )


class MutantEqualityBypassStore:
    def __init__(self, epoch: int, value: str) -> None:
        self.epoch = epoch
        self.value = value

    def cas(self, expected_epoch: int, value: str) -> bool:
        if value == self.value:
            return True
        if expected_epoch != self.epoch:
            return False
        self.value = value
        return True


def control_stale_cas_equality() -> MutationResult:
    store = MutantEqualityBypassStore(7, "BYTE_IDENTICAL")
    stale_epoch = 6
    mutant_accepted = store.cas(stale_epoch, "BYTE_IDENTICAL")
    return MutationResult(
        "MC-STALE-CAS-EQUALITY",
        "generic durable CAS accepts stale epoch when proposed bytes equal current bytes",
        "current epoch 7/value BYTE_IDENTICAL; epoch 6 writes the same bytes",
        mutant_accepted and stale_epoch != store.epoch,
        "fence comparison remains load-bearing even when content is byte-identical",
        mutant_accepted and stale_epoch != store.epoch,
        "the equality shortcut bypassed the stale fence and the fence assertion detected it",
        "control_stale_cas_equality / MutantEqualityBypassStore.cas",
    )


CONTROLS = (
    control_p,
    control_joint,
    control_domain,
    control_ownership_logical,
    control_ownership_durable,
    control_grant,
    control_broker_dedupe,
    control_stale_cas_equality,
)


def execute_once() -> dict:
    results = [control() for control in CONTROLS]
    ids = [result.test_id for result in results]
    assert len(ids) == len(set(ids))
    encoded = json.dumps([asdict(result) | {"passed": result.passed} for result in results],
                         sort_keys=True, separators=(",", ":")).encode("utf-8")
    passed = sum(result.passed for result in results)
    return {
        "classification": "PYTHON-ONLY DELIBERATELY BROKEN TEST-DOUBLE MUTATION CONTROLS; NOT MQL RUNTIME PROOF",
        "status": "PASS" if passed == len(results) else "FAIL",
        "total": len(results),
        "passed": passed,
        "failed": len(results) - passed,
        "digest": hashlib.sha256(encoded).hexdigest(),
        "results": [asdict(result) | {"passed": result.passed} for result in results],
    }


def main() -> None:
    first = execute_once()
    second = execute_once()
    assert first == second
    output = first if "--details" in sys.argv else {key: value for key, value in first.items() if key != "results"}
    output["runs"] = 2
    output["deterministic"] = True
    print(json.dumps(output, sort_keys=True, separators=(",", ":")))


if __name__ == "__main__":
    main()
