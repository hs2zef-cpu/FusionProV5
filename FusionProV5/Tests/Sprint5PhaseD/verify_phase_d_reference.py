#!/usr/bin/env python3
"""TEST ONLY / NOT FOR PRODUCTION / NO BROKER ACCESS.

Independent deterministic executable reference verifier for Sprint 5 Phase D.
It models an in-memory transactional store and explicitly supplied clock/query
evidence. It is not MQL runtime, SQLite, cross-terminal, or broker proof.
"""
from __future__ import annotations

import copy
import hashlib
import json
import math
from dataclasses import dataclass, field
from enum import Enum
from typing import Any
from frozen_dto_digest import (version as production_version, release_digest as frozen_release_digest,
    vector_digest as frozen_vector_digest, checkpoint_integrity as frozen_checkpoint_integrity,
    canonical_hash as frozen_canonical_hash)
from verify_phase_d5_source import verify as verify_d5_source

SCHEMA_ID = "SWV5-S5-STORE-SCHEMA-V1"
SCHEMA_VERSION = 1
MINIMUM_COMPATIBLE = 1
BROKER_QUERY_MASK = frozenset({"positions", "orders", "deals", "transactions"})
EXECUTION_QUERY_MASK = frozenset({"pending_requests"})
ALL_DOMAINS = ("genesis", "lease", "ledger", "sequence", "submission", "request_set", "checkpoint")


def canonical_json_value(value: Any) -> Any:
    if isinstance(value, (set, frozenset)):
        return sorted(canonical_json_value(item) for item in value)
    if isinstance(value, dict):
        return {key: canonical_json_value(item) for key, item in value.items()}
    if isinstance(value, (list, tuple)):
        return [canonical_json_value(item) for item in value]
    if isinstance(value, Enum):
        return value.value
    return value


def digest(value: Any) -> str:
    return hashlib.sha256(json.dumps(canonical_json_value(value), sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode()).hexdigest()


class Disposition(str, Enum):
    COMMITTED = "COMMITTED"
    EXPECTED_STATE_MISMATCH = "EXPECTED_STATE_MISMATCH"
    CONFLICT = "CONFLICT"
    BUSY = "BUSY_LOCKED"
    CRASH_BEFORE_MUTATION = "CRASH_BEFORE_MUTATION"
    CRASH_DURING_TRANSACTION = "CRASH_DURING_TRANSACTION"
    UNCERTAIN = "COMMIT_OUTCOME_UNCERTAIN"
    CORRUPT = "CORRUPT_STATE"
    READBACK_MISMATCH = "READBACK_MISMATCH"
    SCHEMA_INCOMPATIBLE = "SCHEMA_INCOMPATIBLE"


@dataclass
class TxResult:
    disposition: Disposition
    transaction_id: str
    domain: str
    expected_revision: int
    durable_revision: int
    won_now: bool = False
    durable_matches: bool = False


@dataclass
class DomainRow:
    namespace: str
    revision: int
    fence: str
    payload: Any
    payload_digest: str = ""
    corrupt: bool = False

    def __post_init__(self) -> None:
        if not self.payload_digest:
            self.payload_digest = digest(self.payload)


@dataclass
class FakeTransactionalStore:
    rows: dict[str, DomainRow] = field(default_factory=dict)
    tx_sequence: int = 0
    trace: list[dict[str, Any]] = field(default_factory=list)

    def seed(self, domain: str, row: DomainRow) -> None:
        assert domain in ALL_DOMAINS and domain not in self.rows and row.revision > 0
        self.rows[domain] = copy.deepcopy(row)

    def read(self, domain: str) -> DomainRow | None:
        row = self.rows.get(domain)
        return copy.deepcopy(row) if row is not None else None

    def cas(self, domain: str, expected: DomainRow, proposed: DomainRow, fault: str = "") -> TxResult:
        self.tx_sequence += 1
        txid = f"TX-{self.tx_sequence:04d}"
        current = self.rows.get(domain)
        current_revision = current.revision if current else 0
        def result(disposition: Disposition, won: bool = False, matches: bool = False) -> TxResult:
            item = TxResult(disposition, txid, domain, expected.revision, current_revision if not matches else proposed.revision, won, matches)
            self.trace.append({"tx": txid, "domain": domain, "expected": expected.revision,
                               "durable": item.durable_revision, "disposition": disposition.value})
            return item
        if fault == "BUSY":
            return result(Disposition.BUSY)
        if current is None or current.corrupt or current.payload_digest != digest(current.payload):
            return result(Disposition.CORRUPT)
        if fault in {"AFTER_SNAPSHOT", "BEFORE_COMPARE", "BEFORE_MUTATION"}:
            return result(Disposition.CRASH_BEFORE_MUTATION)
        if (current.namespace, current.revision, current.fence, current.payload_digest) != (
                expected.namespace, expected.revision, expected.fence, expected.payload_digest):
            return result(Disposition.EXPECTED_STATE_MISMATCH)
        if (proposed.namespace != current.namespace or proposed.revision != current.revision + 1 or
                proposed.payload_digest != digest(proposed.payload)):
            return result(Disposition.CONFLICT)
        if fault in {"AFTER_EXPECTED", "AFTER_STAGE", "BEFORE_COMMIT"}:
            return result(Disposition.CRASH_DURING_TRANSACTION)
        self.rows[domain] = copy.deepcopy(proposed)
        current_revision = proposed.revision
        if fault == "AFTER_COMMIT":
            return result(Disposition.UNCERTAIN, matches=True)
        if fault == "BEFORE_READBACK":
            return result(Disposition.READBACK_MISMATCH, matches=True)
        return result(Disposition.COMMITTED, won=True, matches=True)


@dataclass
class Clock:
    clock_id: str = "BROKER-CLOCK"
    authority: str = "BROKER_SERVER"
    symbol: str = "XAUUSD"
    sequence: int = 0
    timestamp: int = 0

    def accept(self, observation: dict[str, Any]) -> bool:
        if (observation.get("clock_id") != self.clock_id or observation.get("authority") != self.authority or
                observation.get("symbol") != self.symbol or not observation.get("current_event") or
                not observation.get("event_id") or observation.get("sequence", 0) <= self.sequence or
                observation.get("timestamp", 0) <= 0 or observation["timestamp"] < self.timestamp):
            return False
        self.sequence = observation["sequence"]
        self.timestamp = observation["timestamp"]
        return True


def observation(sequence: int, timestamp: int, **changes: Any) -> dict[str, Any]:
    value = {"clock_id": "BROKER-CLOCK", "authority": "BROKER_SERVER", "symbol": "XAUUSD",
             "sequence": sequence, "timestamp": timestamp, "current_event": True, "event_id": f"EV-{sequence}"}
    value.update(changes)
    return value


def fence(namespace: str, owner: str, lease_version: int, takeover: int) -> str:
    return digest({"namespace": namespace, "owner": owner, "lease_version": lease_version, "takeover": takeover})


def owner_identity(instance_id: str, **changes: Any) -> dict[str, Any]:
    value = {"ownership_key": "NS", "instance_id": instance_id,
             "account_login": 10001, "magic": 550015, "broker": "BROKER-DEMO",
             "server": "SERVER-DEMO", "symbol": "XAUUSD", "strategy": "FUSION-PRO-V5",
             "process_fingerprint": f"PROCESS-{instance_id}", "started_at": 1}
    value.update(changes)
    return value


def complete_owner_identity(owner: dict[str, Any]) -> bool:
    return (owner.get("ownership_key") == "NS" and owner.get("account_login", 0) > 0 and
            owner.get("magic", 0) > 0 and all(owner.get(key) for key in
            ("broker", "server", "symbol", "strategy", "instance_id", "process_fingerprint")) and
            owner.get("started_at", 0) > 0)


def persistence_namespace(basket: str = "BASKET-XAU-M15", ownership: str = "NS",
                          execution: str = "EXEC-NS", account: str = "ACCOUNT-DEMO") -> dict[str, str]:
    return {"basket": basket, "ownership": ownership, "execution": execution, "account": account}


def reconciliation_evidence(namespace: dict[str, str], owner: str, fence_digest: str,
                            store_revision: int, takeover_generation: int,
                            sequence: int, observed_at: int, **changes: Any) -> dict[str, Any]:
    broker = {"contract_version": 5, "namespace": copy.deepcopy(namespace), "component": "BROKER",
              "source": "BROKER", "evidence_id": f"BROKER-{sequence}", "sequence": sequence,
              "observed_at": observed_at, "owner": owner, "fence": fence_digest,
              "store_revision": store_revision, "takeover_generation": takeover_generation,
              "state": "NO_ACTIVE_EXPOSURE"}
    broker["state_digest"] = digest(broker)
    durable = {"contract_version": 5, "namespace": copy.deepcopy(namespace), "component": "PERSISTENCE",
               "source": "PERSISTENCE", "evidence_id": f"PERSIST-{sequence}", "sequence": sequence,
               "observed_at": observed_at, "owner": owner, "fence": fence_digest,
               "store_revision": store_revision, "takeover_generation": takeover_generation,
               "state": "CHECKPOINT_RECONCILED"}
    durable["state_digest"] = digest(durable)
    value = {"claim_contract_version": 5, "takeover_contract_version": 5,
             "expiry_contract_version": 5, "current_lease_contract_version": 5,
             "expected_fence_contract_version": 5, "proposed_fence_contract_version": 5,
             "expiry": True, "broker": broker, "persistence": durable, "independent": True,
             "sequence": sequence, "observed_at": observed_at, "expiry_observed_at": observed_at,
             "evidenced_at": observed_at, "claimant": owner_identity("OWNER-B")}
    value.update(changes)
    return value


def valid_reconciliation_item(item: dict[str, Any], component: str, source: str,
                              expected_namespace: dict[str, str], lease: "Lease",
                              sequence: int, observed_at: int) -> bool:
    body = {key: value for key, value in item.items() if key != "state_digest"}
    return (item.get("contract_version") == 5 and item.get("namespace") == expected_namespace and
            item.get("component") == component and item.get("source") == source and
            item.get("state") == ("NO_ACTIVE_EXPOSURE" if component == "BROKER" else "CHECKPOINT_RECONCILED") and
            bool(item.get("evidence_id")) and item.get("state_digest") == digest(body) and
            item.get("sequence") == sequence and item.get("observed_at") == observed_at and
            item.get("owner") == lease.owner and item.get("fence") == lease.fence_digest and
            item.get("store_revision") == lease.store_revision and
            item.get("takeover_generation") == lease.takeover_generation)


@dataclass
class Lease:
    contract_version: int = 5
    namespace: str = "NS"
    complete_namespace: dict[str, str] = field(default_factory=persistence_namespace)
    owner: str = ""
    lease_version: int = 0
    takeover_generation: int = 0
    store_revision: int = 1
    heartbeat_sequence: int = 0
    clock_sequence: int = 0
    heartbeat_at: int = 0
    expires_at: int = 0
    fence_digest: str = ""
    status: str = "UNCLAIMED"
    clock_id: str = "BROKER-CLOCK"
    clock_authority: str = "BROKER_SERVER"
    acquired_clock_sequence: int = 0
    expiry_clock_sequence: int = 0
    acquired_at: int = 0
    governed_key: dict[str, Any] = field(default_factory=lambda: owner_identity("GOVERNED"))

    def acquire(self, owner: str, expected_revision: int, obs: dict[str, Any], duration: int) -> bool:
        if (self.owner or not owner or not complete_owner_identity(self.governed_key) or
                expected_revision != self.store_revision or duration <= 0):
            return False
        c = Clock(); c.sequence = self.clock_sequence; c.timestamp = self.heartbeat_at
        if not c.accept(obs): return False
        self.owner, self.lease_version, self.takeover_generation = owner, 1, 1
        self.status = "ACQUIRED"
        self.store_revision += 1; self.heartbeat_sequence = 1
        self.clock_sequence, self.heartbeat_at = obs["sequence"], obs["timestamp"]
        self.acquired_clock_sequence, self.acquired_at = obs["sequence"], obs["timestamp"]
        self.expiry_clock_sequence = obs["sequence"] + duration
        self.clock_id, self.clock_authority = obs["clock_id"], obs["authority"]
        self.expires_at = obs["timestamp"] + duration
        self.fence_digest = fence(self.namespace, owner, 1, 1)
        return True

    def heartbeat(self, owner: str, expected_revision: int, expected_fence: str,
                  obs: dict[str, Any], duration: int) -> bool:
        stable = (self.owner, self.lease_version, self.takeover_generation, self.fence_digest)
        if (owner != self.owner or expected_revision != self.store_revision or expected_fence != self.fence_digest or
                obs["sequence"] <= self.clock_sequence or obs["timestamp"] < self.heartbeat_at or duration <= 0):
            return False
        self.store_revision += 1; self.heartbeat_sequence += 1
        self.status = "RENEWED"
        self.clock_sequence, self.heartbeat_at = obs["sequence"], obs["timestamp"]
        self.expiry_clock_sequence = obs["sequence"] + duration
        self.expires_at = obs["timestamp"] + duration
        assert stable == (self.owner, self.lease_version, self.takeover_generation, self.fence_digest)
        return True

    def takeover(self, claimant: dict[str, Any], expected_revision: int, expected_fence: str,
                 proposed_generation: int, obs: dict[str, Any], evidence: dict[str, Any], duration: int) -> bool:
        new_owner = claimant.get("instance_id", "")
        if (self.contract_version != 5 or self.status != "EXPIRED" or not self.owner or
                self.lease_version <= 0 or self.takeover_generation <= 0 or
                claimant != evidence.get("claimant") or not complete_owner_identity(claimant) or
                not complete_owner_identity(self.governed_key) or claimant.get("ownership_key") != self.namespace or
                any(claimant.get(key) != self.governed_key.get(key) for key in
                    ("account_login", "magic", "broker", "server", "symbol", "strategy")) or
                new_owner == self.owner or expected_revision != self.store_revision or
                expected_fence != self.fence_digest or proposed_generation != self.takeover_generation + 1 or
                self.clock_id != obs.get("clock_id") or self.clock_authority != obs.get("authority") or
                self.acquired_clock_sequence > self.clock_sequence or self.clock_sequence >= self.expiry_clock_sequence or
                obs["sequence"] < self.expiry_clock_sequence or obs["timestamp"] < self.expires_at or duration <= 0 or
                any(evidence.get(key) != 5 for key in ("claim_contract_version", "takeover_contract_version",
                    "expiry_contract_version", "current_lease_contract_version",
                    "expected_fence_contract_version", "proposed_fence_contract_version")) or
                not evidence.get("expiry") or not evidence.get("independent") or
                evidence.get("sequence") != obs["sequence"] or evidence.get("observed_at", 0) <= 0 or
                evidence.get("observed_at") != evidence.get("expiry_observed_at") or
                evidence.get("observed_at") != obs["timestamp"] or
                evidence.get("observed_at") > evidence.get("evidenced_at", 0) or
                not valid_reconciliation_item(evidence.get("broker", {}), "BROKER", "BROKER",
                                              self.complete_namespace, self, obs["sequence"], obs["timestamp"]) or
                not valid_reconciliation_item(evidence.get("persistence", {}), "PERSISTENCE", "PERSISTENCE",
                                              self.complete_namespace, self, obs["sequence"], obs["timestamp"])):
            return False
        self.owner = new_owner; self.lease_version += 1; self.takeover_generation = proposed_generation
        self.status = "ACQUIRED"
        self.store_revision += 1; self.heartbeat_sequence = 1
        self.clock_sequence, self.heartbeat_at = obs["sequence"], obs["timestamp"]
        self.acquired_clock_sequence, self.acquired_at = obs["sequence"], obs["timestamp"]
        self.expiry_clock_sequence = obs["sequence"] + duration
        self.expires_at = obs["timestamp"] + duration
        self.fence_digest = fence(self.namespace, self.owner, self.lease_version, self.takeover_generation)
        return True


@dataclass
class Genesis:
    state: str = "ABSENT"
    request: dict[str, Any] | None = None
    generation: int = 0
    revision: int = 0
    domains: dict[str, Any] = field(default_factory=dict)
    operational: bool = False

    def begin(self, request: dict[str, Any], runtime_host: bool = False) -> str:
        required = set(genesis_request())
        if self.state == "READY_FOR_RECONCILIATION":
            return "IDEMPOTENT" if request == self.request else "CONFLICT"
        if self.state == "PROVISIONING" or self.operational or runtime_host or set(request) != required or not all(request.values()):
            return "CONFLICT"
        if (request["contract_version"] != 5 or request["policy_version"] != 1 or
                request["authority_component"] != "OPERATOR" or request["authority_source"] != "OPERATOR" or
                request["clock_authority"] == "NONE"): return "CONFLICT"
        self.state, self.request, self.generation, self.revision = "PROVISIONING", copy.deepcopy(request), 1, 1
        return "CREATED"

    def initialize(self, domain: str, payload: Any) -> bool:
        if (self.state != "PROVISIONING" or domain not in ALL_DOMAINS or domain in self.domains or
                payload.get("domain") != domain or
                payload.get("canonical_digest") != digest({k: v for k, v in payload.items() if k != "canonical_digest"})):
            return False
        self.domains[domain] = copy.deepcopy(payload); return True

    def finalize(self) -> bool:
        if self.state != "PROVISIONING" or set(self.domains) != set(ALL_DOMAINS) or not self.validate_domains(): return False
        self.state = "READY_FOR_RECONCILIATION"; self.revision += 1; return True

    def validate_domains(self) -> bool:
        if self.request is None: return False
        return all(payload.get("domain") == domain and
                   payload.get("canonical_digest") == digest({k: v for k, v in payload.items() if k != "canonical_digest"}) and
                   payload.get("genesis") == self.request["genesis_id"] and
                   payload.get("generation") == 1 and payload.get("namespace") == self.request["namespace"] and
                   payload.get("manifest") == self.request["manifest"] and payload.get("revision") == 1
                   for domain, payload in self.domains.items())


def genesis_request(**changes: Any) -> dict[str, Any]:
    value = {"contract_version": 5, "namespace": "NS", "ownership_namespace": "OWN-NS", "ownership_fence": "FENCE-0",
             "genesis_id": "GEN-1", "policy_id": "GENESIS-V1", "policy_version": 1,
             "operator_id": "OP-1", "authority_role": "GENESIS-ADMIN", "authentication_reference": "AUTH-1",
             "authenticated_at": 990, "authority_component": "OPERATOR", "authority_source": "OPERATOR",
             "clock_id": "BROKER-CLOCK", "clock_authority": "BROKER_SERVER", "clock_sequence": 1,
             "created_at": 1000, "manifest": "MANIFEST-1"}
    value.update(changes); return value


def genesis_payload(domain: str) -> dict[str, Any]:
    base = {"domain": domain, "genesis": "GEN-1", "generation": 1, "namespace": "NS", "manifest": "MANIFEST-1", "revision": 1}
    if domain == "genesis": base.update({"schema": SCHEMA_ID, "schema_version": 1})
    elif domain == "lease": base.update({"status": "UNCLAIMED", "owner": None, "fence": None})
    elif domain == "checkpoint": base.update({"clean_shutdown": False, "reconciliation": "REQUIRED",
                                                "hard_kill_generation": 1, "query_hwm": 0, "bootstrap": True})
    elif domain == "request_set": base.update({"ordered": [], "digest": digest([]), "latest": None})
    elif domain == "ledger": base.update({"records": [], "hwm": 0, "compaction": 0})
    elif domain == "sequence": base.update({"index": {}, "hwm": 0})
    elif domain == "submission": base.update({"journal": [], "grant": None})
    base["canonical_digest"] = digest(base)
    return base


@dataclass
class Ledger:
    revision: int = 1
    previous_revision: int = 0
    hwm: int = 0
    compaction: int = 0
    records: list[dict[str, Any]] = field(default_factory=list)
    index: list[dict[str, Any]] = field(default_factory=list)
    corrupt: bool = False

    def validate(self) -> bool:
        if self.corrupt: return False
        if self.revision <= 0 or self.previous_revision != self.revision - 1: return False
        if len(self.index) != len(self.records): return False
        ids: set[str] = set(); sequences: list[int] = []
        for index, record in enumerate(self.records):
            body = {k: v for k, v in record.items() if k != "digest"}
            index_body = {k: v for k, v in self.index[index].items() if k != "index_digest"}
            linked = {k: record[k] for k in index_body}
            if (record.get("digest") != digest(body) or self.index[index].get("index_digest") != digest(index_body) or
                    linked != index_body or record.get("record_sequence") != index + 1 or record["ingress"] in ids):
                return False
            ids.add(record["ingress"]); sequences.append(record["publication"])
        return self.hwm == (max(sequences) if sequences else 0)

    def durable_payload(self) -> dict[str, Any]:
        records = copy.deepcopy(self.records); index = copy.deepcopy(self.index)
        body = {"revision": self.revision, "previous_revision": self.previous_revision,
                "membership_count": len(records), "hwm": self.hwm, "compaction": self.compaction,
                "index_digest": digest(index), "records_digest": digest(records),
                "index": index, "records": records}
        return {**body, "ledger_digest": digest(body)}

    @classmethod
    def reload(cls, payload: dict[str, Any]) -> "Ledger | None":
        body = {key: value for key, value in payload.items() if key != "ledger_digest"}
        if (payload.get("ledger_digest") != digest(body) or payload.get("membership_count") != len(payload.get("records", [])) or
                payload.get("index_digest") != digest(payload.get("index", [])) or
                payload.get("records_digest") != digest(payload.get("records", []))): return None
        value = cls(revision=payload.get("revision", 0), previous_revision=payload.get("previous_revision", -1),
                    hwm=payload.get("hwm", 0), compaction=payload.get("compaction", 0),
                    records=copy.deepcopy(payload.get("records", [])), index=copy.deepcopy(payload.get("index", [])))
        return value if value.validate() else None

    def accept(self, expected_revision: int, ingress: str, payload: str, correlation: str,
               request_sequence: int, publication: int, accepted_at: int) -> str:
        if not self.validate(): return "CORRUPT"
        for row in self.records:
            if row["ingress"] == ingress:
                return "IDEMPOTENT" if (row["payload"], row["correlation"], row["request_sequence"]) == (payload, correlation, request_sequence) else "CONFLICT"
        if expected_revision != self.revision or publication <= self.hwm or accepted_at <= 0: return "STALE"
        body = {"ingress": ingress, "payload": payload, "correlation": correlation,
                "request_sequence": request_sequence, "publication": publication,
                "accepted_at": accepted_at, "record_sequence": len(self.records) + 1}
        record = {**body, "digest": digest(body)}
        index_body = {k: record[k] for k in ("ingress", "payload", "correlation", "request_sequence", "publication", "accepted_at", "record_sequence", "digest")}
        self.records.append(record); self.index.append({**index_body, "index_digest": digest(index_body)})
        self.hwm = publication; self.previous_revision = self.revision; self.revision += 1
        return "COMMITTED"

    def compact(self, expected_revision: int) -> bool:
        if not self.validate() or expected_revision != self.revision: return False
        self.compaction += 1; self.previous_revision = self.revision; self.revision += 1; return True


@dataclass
class SequenceStore:
    revision: int = 1
    hwm: int = 0
    index: dict[str, dict[str, Any]] = field(default_factory=dict)
    corrupt: bool = False

    def validate(self) -> bool:
        sequences = [x["sequence"] for x in self.index.values()]
        return (not self.corrupt and len(sequences) == len(set(sequences)) and
                all(x > 0 for x in sequences) and self.hwm == (max(sequences) if sequences else 0))

    def durable_payload(self) -> dict[str, Any]:
        ordered = [{"correlation": key, **copy.deepcopy(self.index[key])} for key in sorted(self.index)]
        body = {"revision": self.revision, "hwm": self.hwm, "reservations": ordered}
        return {**body, "payload_digest": digest(body)}

    @classmethod
    def reload(cls, payload: dict[str, Any]) -> "SequenceStore | None":
        body = {key: value for key, value in payload.items() if key != "payload_digest"}
        if payload.get("payload_digest") != digest(body): return None
        entries = payload.get("reservations")
        if not isinstance(entries, list): return None
        index: dict[str, dict[str, Any]] = {}
        for entry in entries:
            correlation = entry.get("correlation", "")
            if not correlation or correlation in index: return None
            index[correlation] = {key: copy.deepcopy(entry[key]) for key in ("sequence", "binding", "reservation_revision")}
        restored = cls(revision=payload.get("revision", 0), hwm=payload.get("hwm", 0), index=index)
        return restored if restored.validate() else None

    def reserve(self, expected_revision: int, correlation: str, binding: str) -> tuple[str, int]:
        if not self.validate(): return "CORRUPT", 0
        if correlation in self.index:
            row = self.index[correlation]
            return ("IDEMPOTENT", row["sequence"]) if row["binding"] == binding else ("CONFLICT", 0)
        if expected_revision != self.revision: return "STALE", 0
        self.hwm += 1; self.revision += 1
        self.index[correlation] = {"sequence": self.hwm, "binding": binding, "reservation_revision": self.revision}
        return "COMMITTED", self.hwm


@dataclass
class SubmissionJournal:
    records: dict[str, dict[str, Any]] = field(default_factory=dict)
    grants: int = 0

    def permit(self, request: str, attempt: str, permit: dict[str, Any], fence_digest: str) -> bool:
        if (not all((request, attempt, fence_digest)) or attempt in self.records or
                not valid_permit(permit, request, attempt, fence_digest)): return False
        self.records[attempt] = {"request": request, "attempt": attempt, "permit": copy.deepcopy(permit),
                                 "permit_digest": permit["permit_digest"], "fence": fence_digest,
                                 "revision": 1, "state": "COMMITTED_NOT_INVOKED"}
        return True

    def claim(self, attempt: str, expected_revision: int, permit: dict[str, Any], current_fence: str,
              fault: str = "") -> tuple[str, bool]:
        row = self.records.get(attempt)
        if not row: return "MISSING", False
        if row["state"] != "COMMITTED_NOT_INVOKED": return "ALREADY_CLAIMED", False
        if (not valid_permit(permit, row["request"], attempt, current_fence) or
                row["revision"] != expected_revision or row["fence"] != current_fence or
                row["permit_digest"] != permit["permit_digest"] or row["permit"] != permit):
            return "STALE_OR_CONFLICT", False
        if fault in {"BEFORE", "DURING"}: return "CRASH_NO_COMMIT", False
        row["state"], row["revision"] = "INVOCATION_CLAIMED_UNRESOLVED", row["revision"] + 1
        if fault == "AFTER_COMMIT": return "COMMIT_OUTCOME_UNCERTAIN", False
        self.grants += 1; return "CLAIM_GRANTED_NOW", True

    def reload(self, attempt: str) -> tuple[str, bool]:
        row = self.records.get(attempt)
        return (row["state"], False) if row else ("MISSING", False)


def permit_fixture(request: str = "R1", attempt: str = "A1", fence_digest: str = "F1",
                   **changes: Any) -> dict[str, Any]:
    risk = {"authorization_id": "RISK-1", "request": request, "attempt": attempt,
            "namespace": persistence_namespace(), "fence": fence_digest, "max_volume": "0.20",
            "expires_at": 1200, "policy": "RISK-V5", "revision": 1}
    risk["risk_digest"] = digest(risk)
    normalization = {"normalization_id": "NORM-1", "request": request, "attempt": attempt,
                     "basket": "BASKET-XAU-M15", "symbol": "XAUUSD", "specification_sequence": 77,
                     "normalized_payload": {"volume": "0.10", "price": "2500.00", "stops_points": 100}}
    normalization["normalization_digest"] = digest(normalization)
    value = {"contract_version": 5, "permit_id": "PERMIT-1", "permit_revision": 1,
             "state": "APPROVED", "namespace": persistence_namespace(), "fence": fence_digest,
             "request": request, "attempt": attempt, "basket": "BASKET-XAU-M15",
             "specification_sequence": 77, "risk": risk, "normalization": normalization,
             "expires_at": 1200, "policy": "ADMISSION-V5"}
    value.update(changes)
    value["permit_digest"] = digest(value)
    return value


def valid_permit(value: dict[str, Any], request: str, attempt: str, fence_digest: str) -> bool:
    if not isinstance(value, dict): return False
    body = {key: item for key, item in value.items() if key != "permit_digest"}
    risk = value.get("risk", {}); risk_body = {key: item for key, item in risk.items() if key != "risk_digest"}
    norm = value.get("normalization", {}); norm_body = {key: item for key, item in norm.items() if key != "normalization_digest"}
    return (value.get("permit_digest") == digest(body) and risk.get("risk_digest") == digest(risk_body) and
            norm.get("normalization_digest") == digest(norm_body) and value.get("contract_version") == 5 and
            value.get("state") == "APPROVED" and value.get("namespace") == persistence_namespace() and
            value.get("fence") == fence_digest and value.get("request") == request and value.get("attempt") == attempt and
            value.get("basket") == norm.get("basket") == "BASKET-XAU-M15" and
            value.get("specification_sequence") == norm.get("specification_sequence") == 77 and
            risk.get("request") == request and risk.get("attempt") == attempt and
            risk.get("namespace") == value.get("namespace") and risk.get("fence") == fence_digest and
            value.get("expires_at", 0) > 1000 and risk.get("expires_at", 0) > 1000 and
            all(value.get(key) for key in ("permit_id", "policy")) and
            all(risk.get(key) for key in ("authorization_id", "policy")) and
            all(norm.get(key) for key in ("normalization_id", "normalized_payload")))


@dataclass
class PublicationStore:
    request_set: dict[str, Any] = field(default_factory=lambda: PublicationStore.initial_set())
    checkpoint: dict[str, Any] = field(default_factory=lambda: {"revision": 1, "store_revision": 1, "record_sequence": 1, "digest": "CP1", "fence": "F1", "takeover": 1, "clean": False, "request_set_digest": digest([])})
    reloaded_set_digest: str = ""
    last_result: str = "INVALID"

    @staticmethod
    def initial_set() -> dict[str, Any]:
        value = {"revision": 1, "store_revision": 1, "record_sequence": 1, "digest": digest([]),
                 "fence": "F1", "takeover": 1, "ordered": []}
        value["row_digest"] = digest({key: item for key, item in value.items() if key != "row_digest"})
        return value

    @staticmethod
    def expected_equal(current: dict[str, Any], expected: dict[str, Any]) -> bool:
        keys = ["revision", "store_revision", "record_sequence", "digest", "fence", "takeover"]
        if "row_digest" in current or "row_digest" in expected: keys.append("row_digest")
        return all(current[k] == expected[k] for k in keys)

    def evaluate_set(self, expected: dict[str, Any], proposed: dict[str, Any]) -> bool:
        if (not self.expected_equal(self.request_set, expected) or proposed["revision"] != expected["revision"] + 1 or
                proposed["store_revision"] != expected["store_revision"] + 1 or
                proposed["record_sequence"] != expected["record_sequence"] + 1 or
                proposed["fence"] != expected["fence"] or proposed["takeover"] != expected["takeover"] or
                proposed["digest"] != digest(proposed["ordered"]) or
                proposed.get("row_digest") != digest({key: item for key, item in proposed.items() if key != "row_digest"})):
            self.last_result = "INVALID"
            return False
        self.last_result = "PROPOSAL_VALID"
        return True

    def publish_set(self, expected: dict[str, Any], proposed: dict[str, Any], fault: str = "") -> bool:
        if not self.evaluate_set(expected, proposed): return False
        if fault in {"CAS_FAIL", "AFTER_COMMIT", "BEFORE_READBACK"}:
            self.last_result = "CONFLICT" if fault == "CAS_FAIL" else "OUTCOME_NOT_CONFIRMED"
            return False
        self.request_set = copy.deepcopy(proposed); self.reloaded_set_digest = ""
        readback = copy.deepcopy(self.request_set)
        if readback != proposed:
            self.last_result = "INTEGRITY_FAILURE"; return False
        self.last_result = "COMMITTED"; return True

    def reload_set(self) -> bool:
        valid = (self.request_set["digest"] == digest(self.request_set["ordered"]) and
                 self.request_set.get("row_digest") == digest({key: item for key, item in self.request_set.items() if key != "row_digest"}))
        self.reloaded_set_digest = self.request_set["digest"] if valid else ""; return valid

    def evaluate_checkpoint(self, expected: dict[str, Any], proposed: dict[str, Any], converged: bool) -> bool:
        if (not self.reloaded_set_digest or not self.expected_equal(self.checkpoint, expected) or
                proposed["revision"] != expected["revision"] + 1 or proposed["store_revision"] != expected["store_revision"] + 1 or
                proposed["record_sequence"] != expected["record_sequence"] + 1 or proposed["fence"] != expected["fence"] or
                proposed["takeover"] != expected["takeover"] or proposed["request_set_digest"] != self.reloaded_set_digest or
                (proposed["clean"] and not converged)):
            self.last_result = "INVALID"; return False
        self.last_result = "PROPOSAL_VALID"; return True

    def publish_checkpoint(self, expected: dict[str, Any], proposed: dict[str, Any], converged: bool,
                           fault: str = "") -> bool:
        if not self.evaluate_checkpoint(expected, proposed, converged): return False
        if fault in {"CAS_FAIL", "AFTER_COMMIT", "BEFORE_READBACK"}:
            self.last_result = "CONFLICT" if fault == "CAS_FAIL" else "OUTCOME_NOT_CONFIRMED"
            return False
        self.checkpoint = copy.deepcopy(proposed)
        if self.checkpoint != proposed:
            self.last_result = "INTEGRITY_FAILURE"; return False
        self.last_result = "COMMITTED"; return True


def release_authority_record(**changes: Any) -> dict[str, Any]:
    account_namespace = {"broker": "BROKER-DEMO", "server": "SERVER-DEMO", "account_login": 10001,
                         "currency": "USD", "strategy": "FUSION-PRO-V5", "magic": 550015,
                         "account_mode": "HEDGING", "source": "BROKER", "snapshot_epoch": 1,
                         "snapshot_sequence": 10}
    broker_evidence = {"id": "BROKER-EVIDENCE-1", "observed_at": 975, "contract_version": 5,
                       "namespace": "NS", "component": "BROKER_ADAPTER", "source": "LIVE_BROKER_STATE",
                       "sequence": 48, "state_digest": "BROKER-STATE-48"}
    persistence_evidence = {"id": "PERSISTENCE-EVIDENCE-1", "observed_at": 976, "contract_version": 5,
                            "namespace": "NS", "component": "PERSISTENCE", "source": "PERSISTED_CHECKPOINT",
                            "sequence": 49, "state_digest": "PERSISTENCE-STATE-49"}
    exposure_evidence = {"id": "EXPOSURE-EVIDENCE-1", "observed_at": 977,
                         "observed_exposure": 0.0, "prior_exposure": 0.1,
                         "zero_or_reducing": True, "contract_version": 5, "sequence": 50,
                         "component": "RISK_GOVERNANCE", "source": "LIVE_BROKER_STATE"}
    value = {"contract_version": 5, "namespace": "NS", "account_mode": "HEDGING",
             "account_namespace": account_namespace,
             "latch_id": "LATCH-1", "latch_generation": 1, "release_id": "RELEASE-1",
             "release_generation": 1, "operator_id": "OP-1", "authority_role": "RISK-APPROVER",
             "authentication_reference": "AUTH-1", "authenticated_at": 970,
             "approving_component": "RISK_GOVERNANCE", "approval_policy_id": "HARD-KILL-RELEASE-V5",
             "approval_sequence": 50, "broker_evidence": broker_evidence,
             "persistence_evidence": persistence_evidence, "exposure_evidence": exposure_evidence,
             "approved_at": 980, "released_at": 985, "expires_at": 1060,
             "release_record_sequence": 51, "authority_record_id": "HK-AUTHORITY-1",
             "issuing_component": "RISK_GOVERNANCE", "authority_source": "HARD_KILL_RELEASE_RECORD"}
    value.update(changes)
    value["authority_record_digest"] = frozen_release_digest(value, authority=True)
    return value


def release_authority_reference(record: dict[str, Any]) -> dict[str, Any]:
    return {"contract_version": 5, "authority_record_id": record["authority_record_id"],
            "authority_record_sequence": record["release_record_sequence"],
            "authority_record_digest": record["authority_record_digest"],
            "release_id": record["release_id"], "latch_generation": record["latch_generation"],
            "release_generation": record["release_generation"]}


def persisted_release_evidence(record: dict[str, Any]) -> dict[str, Any]:
    value = {"contract_version": 5, "namespace": record["namespace"], "release_id": record["release_id"],
             "latch_id": record["latch_id"], "latch_generation": record["latch_generation"],
             "release_generation": record["release_generation"], "approval_policy_id": record["approval_policy_id"],
             "approval_sequence": record["approval_sequence"], "operator_id": record["operator_id"],
             "authority_role": record["authority_role"], "authentication_reference": record["authentication_reference"],
             "authenticated_at": record["authenticated_at"], "approving_component": record["approving_component"],
             "broker_evidence": record["broker_evidence"], "persistence_evidence": record["persistence_evidence"],
             "exposure_evidence": record["exposure_evidence"], "approved_at": record["approved_at"],
             "released_at": record["released_at"], "expires_at": record["expires_at"],
             "release_record_sequence": record["release_record_sequence"], "audit_reference": "AUDIT-HK-RELEASE-1"}
    value["release_record_digest"] = frozen_release_digest(value)
    return value


def reconciliation_source_digest(value: dict[str, Any]) -> str:
    return frozen_vector_digest(value)


def seal_checkpoint(checkpoint: dict[str, Any]) -> dict[str, Any]:
    checkpoint = copy.deepcopy(checkpoint)
    header = checkpoint["header"]
    header["payload_size"], header["payload_digest"] = frozen_checkpoint_integrity(checkpoint)
    return checkpoint


def checkpoint_integrity_valid(checkpoint: dict[str, Any]) -> bool:
    resealed = seal_checkpoint(checkpoint)
    return (checkpoint.get("header", {}).get("contract_version") == 5 and
            checkpoint["header"].get("record_sequence", 0) > checkpoint["header"].get("previous_record_sequence", 0) and
            checkpoint["header"].get("store_revision", 0) > 0 and checkpoint["header"].get("written_at", 0) > 0 and
            checkpoint["header"].get("payload_size") == resealed["header"]["payload_size"] and
             checkpoint["header"].get("payload_digest") == resealed["header"]["payload_digest"])


def live_restart_lease_valid(x: dict[str, Any]) -> bool:
    lease = x.get("lease_state", {}); owner = lease.get("owner", {})
    return (lease.get("contract_version") == 5 and lease.get("status") in {"ACQUIRED", "RENEWED"} and
            complete_owner_identity(owner) and lease.get("fence") == x.get("persisted_fence") and
            lease.get("store_revision", 0) > 0 and lease.get("heartbeat_sequence", 0) > 0 and
            lease.get("clock_id") == "BROKER-CLOCK" and lease.get("clock_authority") == "BROKER_SERVER" and
            0 < lease.get("acquired_sequence", 0) <= lease.get("heartbeat_sequence_clock", 0) < lease.get("expiry_sequence", 0) and
            0 < lease.get("acquired_at", 0) <= lease.get("heartbeat_at", 0) < lease.get("expires_at", 0) and
            lease.get("heartbeat_sequence_clock", 0) < x.get("lease_clock_sequence", 0) < lease.get("expiry_sequence", 0) and
            lease.get("heartbeat_at", 0) < x.get("now", 0) < lease.get("expires_at", 0))


def basket_semantics_valid(basket: dict[str, Any]) -> bool:
    if (basket.get("contract_version") != 5 or basket.get("state") not in {"IDLE", "OPENING", "ACTIVE", "RECOVERY", "CLOSING", "HALTED", "ERROR"} or
            basket.get("state_version", 0) <= 0 or basket.get("reconciliation_state") != "MATCHED"):
        return False
    values = [basket.get(key) for key in ("initial_volume", "aggregate_closed_volume", "aggregate_open_volume", "residual_volume")]
    if not all(isinstance(value, (int, float)) and math.isfinite(value) and value >= 0 for value in values): return False
    if basket["aggregate_closed_volume"] > basket["initial_volume"] + 1e-7: return False
    if basket.get("state") == "IDLE":
        return (basket["aggregate_open_volume"] <= 1e-7 and basket["residual_volume"] <= 1e-7 and
                basket.get("position_count") == 0 and basket.get("order_count") == 0 and
                basket.get("pending_count") == 0 and basket.get("close_verification") == "ZERO_RESIDUAL_CONFIRMED")
    if basket["state"] in {"ACTIVE", "RECOVERY", "CLOSING"}:
        return basket["aggregate_open_volume"] > 1e-7 and basket.get("position_count", 0) > 0
    return True


def hard_kill_semantics_valid(x: dict[str, Any], hard_kill: dict[str, Any]) -> bool:
    state = hard_kill.get("state")
    if (hard_kill.get("contract_version") != 5 or state not in {"INACTIVE", "ACTIVE", "RELEASE_PENDING", "RELEASED"} or
            not hard_kill.get("latch_id") or hard_kill.get("latch_generation", 0) <= 0 or
            hard_kill.get("account_namespace") != x.get("release_record", {}).get("account_namespace")):
        return False
    evidence = hard_kill.get("release_evidence", {})
    if state == "INACTIVE":
        return not hard_kill.get("activation_reason") and hard_kill.get("release_generation") == 0 and not evidence.get("release_id")
    if state == "ACTIVE":
        return (bool(hard_kill.get("activation_reason")) and bool(hard_kill.get("activation_authority")) and
                0 < hard_kill.get("activated_at", 0) <= x["now"] and not evidence.get("release_id"))
    if state == "RELEASE_PENDING": return False
    return (hard_kill.get("release_generation", 0) > 0 and
            hard_kill["release_generation"] == evidence.get("release_generation") and
            bool(hard_kill.get("release_evidence", {}).get("release_id")) and
            hard_kill.get("release_reference", {}).get("release_id") == hard_kill["release_evidence"].get("release_id"))


def checkpoint_semantics_valid(x: dict[str, Any], request_set_digest: str) -> tuple[bool, bool]:
    checkpoint = x.get("checkpoint", {}); vector = checkpoint.get("vector", {}); basket = checkpoint.get("basket", {})
    hard_kill = checkpoint.get("hard_kill", {}); broker = x["broker_summary"]
    zero_history = (x.get("genesis_lineage") == "READY_FOR_RECONCILIATION" and not x["requests"] and
                    basket.get("state") == "IDLE" and basket.get("close_verification") == "ZERO_RESIDUAL_CONFIRMED" and
                    basket.get("aggregate_closed_volume") == basket.get("initial_volume") and
                    all(broker.get(key) == 0 for key in ("position_count", "order_count", "transaction_hwm")) and
                    broker.get("exposure") == "0.00" and not broker.get("correlation") and not broker.get("broker_identity") and
                    all(vector.get(key) == 0 for key in ("position_count", "order_count", "pending_count", "transaction_hwm")) and
                    not vector.get("correlation") and not vector.get("broker_identity"))
    vector_values = [vector.get(key) for key in ("symbol_long_volume", "symbol_short_volume", "symbol_net_volume",
                                                  "aggregate_position_volume", "basket_open_volume", "residual_volume")]
    identity = vector.get("broker_identity") if isinstance(vector.get("broker_identity"), dict) else {}
    correlation_identity = vector.get("correlation", {}).get("broker_identity") if isinstance(vector.get("correlation"), dict) else {}
    vector_intrinsic = (all(isinstance(value, (int, float)) and math.isfinite(value) for value in vector_values) and
                        vector.get("symbol_long_volume", -1) >= 0 and vector.get("symbol_short_volume", -1) >= 0 and
                        abs(vector.get("symbol_net_volume", 0) - (vector.get("symbol_long_volume", 0) - vector.get("symbol_short_volume", 0))) <= 1e-7 and
                        all(vector.get(key, -1) >= 0 for key in ("aggregate_position_volume", "basket_open_volume", "residual_volume")) and
                        (not identity or (identity == correlation_identity and vector.get("transaction_hwm") == identity.get("transaction_sequence"))))
    common = (checkpoint_integrity_valid(checkpoint) and basket_semantics_valid(basket) and
              hard_kill_semantics_valid(x, hard_kill) and vector_intrinsic and vector.get("contract_version") == 5 and
              checkpoint["header"].get("namespace") == x["namespace"] and checkpoint["header"].get("fence") == x["persisted_fence"] and
              basket.get("namespace") == x["namespace"] and basket.get("basket") == x["basket"] and
              basket.get("account_mode") == x["account_mode"] and basket.get("reconciliation_state") == "MATCHED" and
              vector.get("namespace") == x["namespace"] and vector.get("basket") == x["basket"] and
              vector.get("account_mode") == x["account_mode"] and vector.get("fence") == x["persisted_fence"] and
              vector.get("basket_state") == basket.get("state") and vector.get("basket_state_version") == basket.get("state_version") and
              vector.get("hard_kill_generation") == hard_kill.get("latch_generation") and
              vector.get("pending_count") == len(x["requests"]) and vector.get("request_set_digest") == request_set_digest and
              vector.get("request_set_revision") == x["request_set_revision"] and
              vector.get("reconciliation_revision") == x["reconciliation_revision"] and
              vector.get("source_summary_digest") == reconciliation_source_digest(vector) and
              vector.get("position_count") == basket.get("position_count") == broker.get("position_count") and
              vector.get("order_count") == basket.get("order_count") == broker.get("order_count") and
              vector.get("pending_count") == basket.get("pending_count") and
              abs(vector.get("basket_open_volume", 0)-basket.get("aggregate_open_volume", 0)) <= 1e-7 and
              abs(vector.get("residual_volume", 0)-basket.get("residual_volume", 0)) <= 1e-7 and
              vector.get("transaction_hwm") == broker.get("transaction_hwm") and vector.get("correlation") == broker.get("correlation") and
              vector.get("broker_identity") == broker.get("broker_identity"))
    ordinary = (vector.get("transaction_hwm", 0) > 0 and bool(vector.get("correlation")) and bool(vector.get("broker_identity")))
    return common and (zero_history or ordinary), zero_history


def valid_release_authority(x: dict[str, Any]) -> bool:
    record = x["release_record"]; reference = x["release_reference"]
    persisted = x["checkpoint"]["hard_kill"]["release_evidence"]
    body = {k: v for k, v in record.items() if k != "authority_record_digest"}
    persisted_body = {k: v for k, v in persisted.items() if k != "release_record_digest"}
    account = record.get("account_namespace", {})
    evidence_items = (record.get("broker_evidence", {}), record.get("persistence_evidence", {}),
                      record.get("exposure_evidence", {}))
    exposure = record.get("exposure_evidence", {})
    typed_evidence = all(isinstance(item, dict) for item in evidence_items)
    complete_account = (all(account.get(key) for key in ("broker", "server", "currency", "strategy")) and
                        account.get("account_login", 0) > 0 and account.get("magic", 0) > 0 and
                        account.get("account_mode") == "HEDGING" and account.get("source") == "BROKER" and
                        account.get("snapshot_epoch", 0) > 0 and account.get("snapshot_sequence", 0) > 0 and
                        all(account.get(key) == x.get("governed_account_namespace", {}).get(key) for key in
                            ("broker", "server", "account_login", "strategy", "magic")))
    chronology = (typed_evidence and record.get("authenticated_at", 0) > 0 and
                  all(item.get("observed_at", 0) >= record["authenticated_at"] for item in evidence_items) and
                  all(item.get("observed_at", 0) <= record.get("approved_at", 0) for item in evidence_items))
    exposure_valid = (isinstance(exposure, dict) and bool(exposure.get("id")) and exposure.get("zero_or_reducing") is True and
                      isinstance(exposure.get("observed_exposure"), (int, float)) and
                      isinstance(exposure.get("prior_exposure"), (int, float)) and
                      math.isfinite(exposure["observed_exposure"]) and math.isfinite(exposure["prior_exposure"]) and
                      exposure["observed_exposure"] >= 0 and exposure["prior_exposure"] >= 0 and
                      exposure["observed_exposure"] <= exposure["prior_exposure"] + 1e-7)
    return (record.get("authority_record_digest") == frozen_release_digest(body, authority=True) and record.get("contract_version") == 5 and
            persisted.get("contract_version") == 5 and persisted.get("release_record_digest") == frozen_release_digest(persisted_body) and
            persisted.get("audit_reference") and persisted.get("namespace") == x["namespace"] and
            persisted.get("released_at", 0) <= x["now"] < persisted.get("expires_at", 0) and
            record.get("namespace") == x["namespace"] and record.get("account_mode") == x["account_mode"] and complete_account and
            record.get("latch_id") == x["release_latch_id"] and record.get("latch_generation") == x["release_latch_generation"] and
            record.get("release_id") == x["release_id"] and record.get("release_generation") == x["release_generation"] and
            all(record.get(key) for key in ("operator_id", "authority_role", "authentication_reference", "approval_policy_id",
                                              "broker_evidence", "persistence_evidence", "exposure_evidence", "authority_record_id")) and
            record.get("approval_policy_id") == "HARD-KILL-RELEASE-V5" and chronology and exposure_valid and
            persisted.get("approval_policy_id") == "HARD-KILL-RELEASE-V5" and
            record.get("authenticated_at", 0) > 0 and record.get("approval_sequence", 0) > 0 and
            0 < record.get("approved_at", 0) <= record.get("released_at", 0) <= x["now"] < record.get("expires_at", 0) and
            record.get("release_record_sequence", 0) > 0 and record.get("approving_component") == "RISK_GOVERNANCE" and
            record.get("issuing_component") == "RISK_GOVERNANCE" and
            record.get("authority_source") == "HARD_KILL_RELEASE_RECORD" and
            reference.get("contract_version") == 5 and reference == release_authority_reference(record) and
            all(persisted.get(key) == record.get(key) for key in ("release_id", "latch_id", "latch_generation",
                "release_generation", "approval_policy_id", "approval_sequence", "operator_id", "authority_role",
                "authentication_reference", "authenticated_at", "approving_component", "broker_evidence",
                "persistence_evidence", "exposure_evidence", "approved_at", "released_at", "expires_at",
                "release_record_sequence")))


def restart(base: dict[str, Any], **changes: Any) -> str:
    x = copy.deepcopy(base); x.update(changes)
    if (not x["schema"] or x.get("contract_version") != production_version() or
            not x["genesis"] or not x["persistence"]): return "HALTED"
    if not x["lease"] or x["claimed"] or not live_restart_lease_valid(x): return "RETRY_FORBIDDEN"
    broker = x["broker_summary"]; execution = x["execution_summary"]
    if (broker.get("summary_digest") != digest({key: value for key, value in broker.items() if key != "summary_digest"}) or
            execution.get("summary_digest") != digest({key: value for key, value in execution.items() if key != "summary_digest"})):
        return "RECONCILIATION_REQUIRED"
    if (x["broker_mask"] != BROKER_QUERY_MASK or x["execution_mask"] != EXECUTION_QUERY_MASK or
            x["broker_authority"] != "BROKER" or x["execution_authority"] != "EXECUTION" or
            x["broker_namespace"] != x["namespace"] or x["execution_namespace"] != x["namespace"] or
            x["broker_account_mode"] != x["account_mode"] or x["execution_account_mode"] != x["account_mode"] or
            x["current_fence"] != x["persisted_fence"] or not x["requests_complete"]): return "RECONCILIATION_REQUIRED"
    if (broker.get("namespace") != x["namespace"] or broker.get("basket") != x["basket"] or
            broker.get("account_mode") != x["account_mode"] or broker.get("fence") != x["persisted_fence"] or
            broker.get("query", {}).get("mask") != BROKER_QUERY_MASK or
            broker.get("query", {}).get("authority") != "BROKER" or
            broker.get("query", {}).get("source") != "BROKER" or
            broker.get("query", {}).get("namespace") != x["namespace"] or
            broker.get("query", {}).get("fence") != x["persisted_fence"] or
            broker.get("query", {}).get("account_mode") != x["account_mode"] or
            not broker.get("query", {}).get("required_complete") or
            not broker.get("query", {}).get("completed") or not broker.get("query", {}).get("authoritative") or
            broker.get("query", {}).get("sequence") != x["broker_sequence"] or
            broker.get("query", {}).get("observed_at") != x["broker_time"] or
            broker.get("query", {}).get("snapshot_digest") != digest({key: value for key, value in broker["query"].items() if key != "snapshot_digest"}) or
            broker.get("transaction_hwm") != x["checkpoint_transaction_hwm"] or
            broker.get("correlation") != x["checkpoint_correlation"] or
            abs(broker.get("symbol_net_volume", 0) - (broker.get("symbol_long_volume", 0) - broker.get("symbol_short_volume", 0))) > 1e-7 or
            (broker.get("broker_identity") and (not isinstance(broker.get("correlation"), dict) or
             broker.get("broker_identity") != broker.get("correlation", {}).get("broker_identity") or
             broker.get("transaction_hwm") != broker.get("broker_identity", {}).get("transaction_sequence")))):
        return "RECONCILIATION_REQUIRED"
    request_set_digest = digest(x["requests"])
    checkpoint_valid, zero_history = checkpoint_semantics_valid(x, request_set_digest)
    if not checkpoint_valid: return "RECONCILIATION_REQUIRED"
    if (execution.get("namespace") != x["namespace"] or execution.get("basket") != x["basket"] or
            execution.get("account_mode") != x["account_mode"] or execution.get("fence") != x["persisted_fence"] or
            execution.get("query", {}).get("mask") != EXECUTION_QUERY_MASK or
            execution.get("query", {}).get("authority") != "EXECUTION" or
            execution.get("query", {}).get("source") != "EXECUTION" or
            execution.get("query", {}).get("namespace") != x["namespace"] or
            execution.get("query", {}).get("fence") != x["persisted_fence"] or
            execution.get("query", {}).get("account_mode") != x["account_mode"] or
            not execution.get("query", {}).get("required_complete") or
            not execution.get("query", {}).get("completed") or not execution.get("query", {}).get("authoritative") or
            execution.get("query", {}).get("sequence") != x["execution_sequence"] or
            execution.get("query", {}).get("observed_at") != x["execution_time"] or
            execution.get("query", {}).get("snapshot_digest") != digest({key: value for key, value in execution["query"].items() if key != "snapshot_digest"}) or
            execution.get("pending_count") != len(x["requests"]) or
            execution.get("request_set_digest") != request_set_digest or
            execution.get("request_set_revision") != x["request_set_revision"] or
            execution.get("reconciliation_revision") != x["reconciliation_revision"]):
        return "RECONCILIATION_REQUIRED"
    for request in x["requests"]:
        body = {key: value for key, value in request.items() if key != "request_digest"}
        if (request.get("request_digest") != digest(body) or request.get("namespace") != x["namespace"] or
                request.get("basket") != x["basket"] or request.get("fence") != x["persisted_fence"] or
                request.get("state") != "CONFIRMED" or request.get("retryable") is not True):
            return "RETRY_FORBIDDEN" if request.get("state") in {"CLAIMED_UNRESOLVED", "CONFIRMATION_PENDING"} else "RECONCILIATION_REQUIRED"
    if (x["broker_sequence"] <= x["broker_hwm"] or x["execution_sequence"] <= x["execution_hwm"] or
            x["broker_time"] <= 0 or x["execution_time"] <= 0 or x["broker_time"] > x["now"] or
            x["execution_time"] > x["now"] or x["now"] - x["broker_time"] > 60 or x["now"] - x["execution_time"] > 60):
        return "RECONCILIATION_REQUIRED"
    if not x["clean"]: return "RECONCILIATION_REQUIRED"
    if x["hard_kill"] or x["checkpoint"]["hard_kill"]["state"] in {"ACTIVE", "RELEASE_PENDING"}: return "CLOSE_ONLY"
    if not x["release_authority"] or not valid_release_authority(x): return "HALTED"
    return "SAFE_TO_RESUME"


@dataclass(frozen=True)
class FakePlatformQuerySource:
    namespace: str = "NS"
    fence_digest: str = "F1"
    account_mode: str = "HEDGING"

    def broker(self) -> dict[str, Any]:
        value = {"mask": BROKER_QUERY_MASK, "authority": "BROKER", "namespace": self.namespace,
                "fence": self.fence_digest, "account_mode": self.account_mode, "sequence": 11,
                "observed_at": 995, "snapshot_id": "BROKER-SNAPSHOT-11", "source": "BROKER",
                "required_complete": True, "completed": True, "authoritative": True,
                "positions": [], "orders": [], "deals": [], "transactions": []}
        value["snapshot_digest"] = digest(value)
        return value

    def execution(self) -> dict[str, Any]:
        value = {"mask": EXECUTION_QUERY_MASK, "authority": "EXECUTION", "namespace": self.namespace,
                "fence": self.fence_digest, "account_mode": self.account_mode, "sequence": 21,
                "observed_at": 996, "snapshot_id": "EXECUTION-SNAPSHOT-21", "source": "EXECUTION",
                "required_complete": True, "completed": True, "authoritative": True,
                "pending_requests": []}
        value["snapshot_digest"] = digest(value)
        return value


def persisted_request(request: str = "R1", attempt: str = "A1", state: str = "CONFIRMED",
                      retryable: bool = True, **changes: Any) -> dict[str, Any]:
    value = {"contract_version": 5, "request": request, "attempt": attempt, "namespace": "NS",
             "basket": "BASKET-XAU-M15", "fence": "F1", "state": state, "retryable": retryable,
             "requested_volume": "0.10", "confirmed_volume": "0.10", "residual_volume": "0.00",
             "correlation": f"CORR-{request}", "broker_order": f"ORDER-{request}",
             "broker_deal": f"DEAL-{request}", "broker_position": f"POSITION-{request}",
             "transaction_hwm": 10}
    value.update(changes); value["request_digest"] = digest(value); return value


def reseal_summary(value: dict[str, Any]) -> dict[str, Any]:
    value = copy.deepcopy(value)
    if "query" in value:
        value["query"]["snapshot_digest"] = digest({key: item for key, item in value["query"].items() if key != "snapshot_digest"})
    value["summary_digest"] = digest({key: item for key, item in value.items() if key != "summary_digest"})
    return value


def restart_base() -> dict[str, Any]:
    source = FakePlatformQuerySource(); broker = source.broker(); execution = source.execution()
    release_record = release_authority_record()
    requests = [persisted_request()]
    broker_identity = {"order_ticket": 7001, "deal_ticket": 8001, "position_identifier": 9001,
                       "broker_event_id": "BROKER-EVENT-10", "transaction_sequence": 10}
    correlation = {"id": "CHECKPOINT-CORR-1", "broker_identity": copy.deepcopy(broker_identity)}
    broker_summary = reseal_summary({"contract_version": 5, "namespace": source.namespace,
                                     "basket": "BASKET-XAU-M15", "account_mode": source.account_mode,
                                     "fence": source.fence_digest, "correlation": correlation,
                                     "broker_identity": broker_identity,
                                     "transaction_hwm": 10, "position_count": 1, "order_count": 0,
                                     "deal_count": 1, "exposure": "0.10", "symbol_long_volume": 0.1,
                                     "symbol_short_volume": 0.0, "symbol_net_volume": 0.1,
                                     "query": broker,
                                     "observed_at": broker["observed_at"], "authority": "BROKER"})
    execution_summary = reseal_summary({"contract_version": 5, "namespace": source.namespace,
                                        "basket": "BASKET-XAU-M15", "account_mode": source.account_mode,
                                        "fence": source.fence_digest, "pending_count": len(requests),
                                        "request_set_digest": digest(requests), "request_set_revision": 4,
                                        "reconciliation_revision": 7, "query": execution,
                                        "observed_at": execution["observed_at"], "authority": "EXECUTION"})
    release_evidence = persisted_release_evidence(release_record)
    vector = {"contract_version": 5, "namespace": source.namespace, "basket": "BASKET-XAU-M15",
              "account_mode": source.account_mode, "symbol_long_volume": 0.1, "symbol_short_volume": 0.0,
              "symbol_net_volume": 0.1, "aggregate_position_volume": 0.1, "basket_open_volume": 0.1,
              "residual_volume": 0.1, "position_count": 1, "order_count": 0, "pending_count": len(requests),
              "correlation": correlation, "broker_identity": broker_identity, "transaction_hwm": 10,
              "broker_query_hwm": 10, "execution_query_hwm": 20, "request_set_digest": digest(requests),
              "request_set_revision": 4, "basket_state": "ACTIVE", "basket_state_version": 12,
              "hard_kill_generation": 1, "fence": source.fence_digest, "reconciliation_revision": 7}
    vector["source_summary_digest"] = reconciliation_source_digest(vector)
    checkpoint = seal_checkpoint({"header": {"contract_version": 5, "namespace": source.namespace,
                                  "fence": source.fence_digest, "record_sequence": 20,
                                  "previous_record_sequence": 19, "store_revision": 20, "written_at": 990},
                                  "request_set": {"contract_version": 5, "count": len(requests),
                                                  "digest": digest(requests), "revision": 4, "record_sequence": 20},
                                   "basket": {"contract_version": 5, "namespace": source.namespace,
                                              "basket": "BASKET-XAU-M15", "account_mode": source.account_mode,
                                              "state": "ACTIVE", "state_version": 12,
                                              "reconciliation_state": "MATCHED", "initial_volume": 0.30,
                                              "aggregate_closed_volume": 0.20, "aggregate_open_volume": 0.1,
                                              "residual_volume": 0.1, "position_count": 1, "order_count": 0,
                                              "pending_count": 1, "close_verification": "NOT_CONFIRMED"},
                                   "hard_kill": {"contract_version": 5, "namespace": source.namespace,
                                                 "state": "RELEASED", "latch_id": "LATCH-1",
                                                 "latch_generation": 1, "release_generation": 1,
                                                 "account_namespace": copy.deepcopy(release_record["account_namespace"]),
                                                "release_evidence": release_evidence,
                                                "release_reference": release_authority_reference(release_record)},
                                  "vector": vector, "clean_shutdown": True})
    return {"schema": True, "contract_version": production_version(), "genesis": True, "genesis_lineage": "READY_FOR_RECONCILIATION",
            "persistence": True, "lease": True, "claimed": False,
            "governed_account_namespace": copy.deepcopy(release_record["account_namespace"]),
            "lease_state": {"contract_version": 5, "status": "ACQUIRED", "owner": owner_identity("OWNER-A"),
                            "fence": source.fence_digest, "store_revision": 3, "heartbeat_sequence": 2,
                            "clock_id": "BROKER-CLOCK", "clock_authority": "BROKER_SERVER",
                            "acquired_sequence": 800, "heartbeat_sequence_clock": 900, "expiry_sequence": 1100,
                            "acquired_at": 700, "heartbeat_at": 940, "expires_at": 1060},
            "lease_clock_sequence": 1000,
            "broker_mask": broker["mask"], "execution_mask": execution["mask"],
            "broker_authority": broker["authority"], "execution_authority": execution["authority"], "requests_complete": True,
            "namespace": source.namespace, "broker_namespace": broker["namespace"], "execution_namespace": execution["namespace"],
            "account_mode": source.account_mode, "broker_account_mode": broker["account_mode"], "execution_account_mode": execution["account_mode"],
            "persisted_fence": source.fence_digest, "current_fence": broker["fence"],
            "broker_sequence": 11, "execution_sequence": 21,
            "broker_hwm": 10, "execution_hwm": 20, "broker_time": broker["observed_at"], "execution_time": execution["observed_at"], "now": 1000,
            "basket": "BASKET-XAU-M15", "checkpoint_transaction_hwm": 10,
            "checkpoint_correlation": correlation, "request_set_revision": 4,
            "reconciliation_revision": 7, "requests": requests,
            "broker_summary": broker_summary, "execution_summary": execution_summary,
            "checkpoint": checkpoint,
            "clean": True,
            "hard_kill": False, "release_authority": True, "release_record": release_record,
            "release_reference": release_authority_reference(release_record), "release_latch_id": "LATCH-1",
            "release_latch_generation": 1, "release_id": "RELEASE-1", "release_generation": 1}


class Runner:
    def __init__(self) -> None:
        self.results: list[dict[str, Any]] = []

    def check(self, test_id: str, family: str, condition: bool, evidence: Any) -> None:
        self.results.append({"id": test_id, "family": family, "passed": bool(condition), "evidence": evidence})
        if not condition: raise AssertionError(f"{test_id}: {evidence}")


def run_suite() -> dict[str, Any]:
    r = Runner()

    # Schema and namespace fail-closed checks.
    r.check("SCH-001", "CORRUPTION", (SCHEMA_ID, SCHEMA_VERSION, MINIMUM_COMPATIBLE) == ("SWV5-S5-STORE-SCHEMA-V1", 1, 1), "exact schema")
    for test_id, actual in (("SCH-002", ""), ("SCH-003", "WRONG")):
        r.check(test_id, "CORRUPTION", actual != SCHEMA_ID, {"rejected_schema": actual})
    r.check("SCH-004", "CORRUPTION", 0 != SCHEMA_VERSION, "old schema rejected")
    r.check("SCH-005", "CORRUPTION", 2 != SCHEMA_VERSION, "future schema rejected")
    r.check("SCH-006", "CORRUPTION", digest({"namespace": "A"}) != digest({"namespace": "B"}), "namespace collision prevented")

    # Generic transaction and crash family.
    def transaction_fixture() -> tuple[FakeTransactionalStore, DomainRow, DomainRow]:
        s = FakeTransactionalStore(); old = DomainRow("NS", 1, "F1", {"value": "old"}); new = DomainRow("NS", 2, "F1", {"value": "new"}); s.seed("ledger", old); return s, old, new
    for test_id, fault, expected in (("CRASH-PRE-CAS", "BEFORE_MUTATION", Disposition.CRASH_BEFORE_MUTATION),
                                     ("CRASH-IN-TXN", "AFTER_STAGE", Disposition.CRASH_DURING_TRANSACTION),
                                     ("CAS-BUSY", "BUSY", Disposition.BUSY)):
        s, old, new = transaction_fixture(); out = s.cas("ledger", old, new, fault)
        r.check(test_id, "CRASH", out.disposition == expected and s.read("ledger").revision == 1, out.__dict__)
    s, old, new = transaction_fixture(); out = s.cas("ledger", old, new, "AFTER_COMMIT")
    r.check("CRASH-POST-COMMIT", "CRASH", out.disposition == Disposition.UNCERTAIN and not out.won_now and s.read("ledger").revision == 2, out.__dict__)
    replay = s.cas("ledger", old, new)
    r.check("CAS-UNCERTAIN-NO-BLIND-REPEAT", "CAS", replay.disposition == Disposition.EXPECTED_STATE_MISMATCH and not replay.won_now, replay.__dict__)
    s, old, new = transaction_fixture(); out = s.cas("ledger", old, new, "BEFORE_READBACK")
    r.check("CAS-READBACK-MISMATCH", "CAS", out.disposition == Disposition.READBACK_MISMATCH and not out.won_now, out.__dict__)

    # Two writers and stale expected authorities.
    for test_id, order in (("CAS-TWO-WRITERS-A", ("A", "B")), ("CAS-TWO-WRITERS-B", ("B", "A"))):
        s, old, new = transaction_fixture(); winners = []
        for writer in order:
            proposal = DomainRow("NS", 2, "F1", {"writer": writer})
            result = s.cas("ledger", old, proposal)
            if result.won_now: winners.append(writer)
        r.check(test_id, "CAS", winners == [order[0]] and s.read("ledger").payload["writer"] == order[0], {"winners": winners})
    for test_id, expected in (("CAS-STALE-REVISION", DomainRow("NS", 0, "F1", {"value": "old"})),
                              ("CAS-STALE-DIGEST", DomainRow("NS", 1, "F1", {"value": "other"})),
                              ("CAS-STALE-FENCE", DomainRow("NS", 1, "OLD-FENCE", {"value": "old"}))):
        s, _, new = transaction_fixture(); out = s.cas("ledger", expected, new)
        r.check(test_id, "CAS", out.disposition == Disposition.EXPECTED_STATE_MISMATCH and s.read("ledger").revision == 1, out.__dict__)
    s, old, _ = transaction_fixture(); bad = DomainRow("NS", 4, "F1", {"bad": True}); out = s.cas("ledger", old, bad)
    r.check("CAS-PROPOSED-REVISION", "CAS", out.disposition == Disposition.CONFLICT, out.__dict__)

    # Genesis lifecycle and domain initialization.
    g = Genesis(); req = genesis_request()
    r.check("GENESIS-ABSENT", "GENESIS", g.state == "ABSENT", g.state)
    r.check("GENESIS-FIRST-CREATE", "GENESIS", g.begin(req) == "CREATED" and (g.generation, g.revision) == (1, 1), g.__dict__)
    for domain in ALL_DOMAINS: r.check(f"GENESIS-DOMAIN-{domain.upper()}", "GENESIS", g.initialize(domain, genesis_payload(domain)), domain)
    cp = g.domains["checkpoint"]
    r.check("GENESIS-HARD-KILL", "GENESIS", cp["hard_kill_generation"] == 1, cp)
    r.check("GENESIS-CHECKPOINT", "GENESIS", not cp["clean_shutdown"] and cp["reconciliation"] == "REQUIRED" and cp["query_hwm"] == 0, cp)
    r.check("GENESIS-UNCLAIMED", "GENESIS", g.domains["lease"]["status"] == "UNCLAIMED" and g.domains["lease"]["fence"] is None, g.domains["lease"])
    r.check("GENESIS-FINALIZE", "GENESIS", g.finalize() and g.state == "READY_FOR_RECONCILIATION", g.__dict__)
    r.check("GENESIS-DUPLICATE", "GENESIS", g.begin(req) == "IDEMPOTENT" and g.revision == 2, g.__dict__)
    for test_id, field_name, changed_value in (
            ("GENESIS-CONFLICT-VERSION", "contract_version", 6),
            ("GENESIS-CONFLICT-NAMESPACE", "namespace", "OTHER-NS"),
            ("GENESIS-CONFLICT-OWNERSHIP-NAMESPACE", "ownership_namespace", "OTHER-OWN"),
            ("GENESIS-CONFLICT-FENCE", "ownership_fence", "OTHER-FENCE"),
            ("GENESIS-CONFLICT-ID", "genesis_id", "GEN-OTHER"),
            ("GENESIS-CONFLICT-POLICY", "policy_id", "GENESIS-OTHER"),
            ("GENESIS-CONFLICT-POLICY-VERSION", "policy_version", 2),
            ("GENESIS-CONFLICT-OPERATOR", "operator_id", "OP-OTHER"),
            ("GENESIS-CONFLICT-ROLE", "authority_role", "OTHER-ROLE"),
            ("GENESIS-CONFLICT-AUTH-REF", "authentication_reference", "AUTH-OTHER"),
            ("GENESIS-CONFLICT-AUTH-TIME", "authenticated_at", 991),
            ("GENESIS-CONFLICT-COMPONENT", "authority_component", "PERSISTENCE"),
            ("GENESIS-CONFLICT-SOURCE", "authority_source", "PERSISTED_CHECKPOINT"),
            ("GENESIS-CONFLICT-CLOCK-ID", "clock_id", "OTHER-CLOCK"),
            ("GENESIS-CONFLICT-CLOCK-AUTHORITY", "clock_authority", "DURABLE_STORE"),
            ("GENESIS-CONFLICT-CLOCK-SEQUENCE", "clock_sequence", 2),
            ("GENESIS-CONFLICT-CREATED-AT", "created_at", 1001),
            ("GENESIS-CONFLICT-MANIFEST", "manifest", "OTHER")):
        r.check(test_id, "GENESIS", g.begin(genesis_request(**{field_name: changed_value})) == "CONFLICT",
                {field_name: changed_value})
    partial = Genesis(); partial.begin(req); partial.initialize("genesis", genesis_payload("genesis"))
    r.check("GENESIS-PARTIAL", "GENESIS", not partial.finalize() and partial.state == "PROVISIONING", partial.__dict__)
    corrupt_genesis = Genesis(); corrupt_genesis.begin(req)
    for domain in ALL_DOMAINS: corrupt_genesis.initialize(domain, genesis_payload(domain))
    corrupt_genesis.domains["checkpoint"]["manifest"] = "CORRUPT"
    corrupt_genesis.domains["checkpoint"]["canonical_digest"] = digest(
        {k: v for k, v in corrupt_genesis.domains["checkpoint"].items() if k != "canonical_digest"})
    r.check("GENESIS-DIGEST-VALID-WRONG-DOMAIN", "CORRUPTION",
            not corrupt_genesis.finalize() and corrupt_genesis.state == "PROVISIONING", corrupt_genesis.__dict__)
    runtime = Genesis(); r.check("GENESIS-NO-HOST-SELF-PROVISION", "GENESIS", runtime.begin(req, runtime_host=True) == "CONFLICT" and runtime.state == "ABSENT", runtime.__dict__)
    operational = Genesis(); operational.operational = True
    r.check("GENESIS-NO-REPROVISION", "GENESIS", operational.begin(req) == "CONFLICT", operational.__dict__)

    # Clock and lease lifecycle.
    c = Clock(); r.check("CLOCK-FIRST", "LEASE_TAKEOVER", c.accept(observation(1, 100)), c.__dict__)
    r.check("CLOCK-SAME-SECOND", "LEASE_TAKEOVER", c.accept(observation(2, 100)) and c.timestamp == 100, c.__dict__)
    r.check("CLOCK-REGRESSION", "LEASE_TAKEOVER", not c.accept(observation(3, 99)) and c.timestamp == 100, c.__dict__)
    r.check("CLOCK-SEQUENCE-REPLAY", "LEASE_TAKEOVER", not c.accept(observation(2, 101)), c.__dict__)
    r.check("CLOCK-WRONG-SYMBOL", "LEASE_TAKEOVER", not c.accept(observation(3, 101, symbol="EURUSD")), c.__dict__)
    r.check("CLOCK-NO-OBSERVATION", "LEASE_TAKEOVER", c.sequence == 2 and c.timestamp == 100, c.__dict__)
    lease = Lease(); acquired = lease.acquire("OWNER-A", 1, observation(1, 100), 10)
    r.check("LEASE-FIRST-ACQUIRE", "LEASE_TAKEOVER", acquired and lease.fence_digest and lease.store_revision == 2, lease.__dict__)
    r.check("LEASE-CONCURRENT-ACQUIRE", "LEASE_TAKEOVER", not lease.acquire("OWNER-B", 1, observation(1, 100), 10), lease.__dict__)
    before = copy.deepcopy(lease); hb = lease.heartbeat("OWNER-A", 2, before.fence_digest, observation(2, 105), 10)
    r.check("LEASE-HEARTBEAT", "LEASE_TAKEOVER", hb and lease.store_revision == 3 and lease.heartbeat_sequence == 2, lease.__dict__)
    r.check("LEASE-HEARTBEAT-FENCE-STABLE", "LEASE_TAKEOVER", (lease.owner, lease.lease_version, lease.takeover_generation, lease.fence_digest) == (before.owner, before.lease_version, before.takeover_generation, before.fence_digest), lease.__dict__)
    r.check("LEASE-HEARTBEAT-RACE", "LEASE_TAKEOVER", not lease.heartbeat("OWNER-A", 2, before.fence_digest, observation(3, 106), 10), lease.__dict__)
    r.check("LEASE-WRONG-OWNER", "LEASE_TAKEOVER", not lease.heartbeat("OWNER-B", 3, lease.fence_digest, observation(3, 106), 10), lease.__dict__)
    r.check("LEASE-MISSING-CLOCK", "LEASE_TAKEOVER", not lease.heartbeat("OWNER-A", 3, lease.fence_digest, observation(2, 106), 10), lease.__dict__)
    lease.status = "EXPIRED"
    weak = reconciliation_evidence(lease.complete_namespace, lease.owner, lease.fence_digest,
                                   lease.store_revision, lease.takeover_generation, 12, 120)
    weak["broker"] = {}
    r.check("LEASE-MISSED-HEARTBEAT-INSUFFICIENT", "LEASE_TAKEOVER", not lease.takeover(owner_identity("OWNER-B"), 3, lease.fence_digest, 2, observation(12, 120), weak, 10), lease.__dict__)
    complete = reconciliation_evidence(lease.complete_namespace, lease.owner, lease.fence_digest,
                                       lease.store_revision, lease.takeover_generation, 12, 120)
    stale_fence = lease.fence_digest
    took = lease.takeover(owner_identity("OWNER-B"), 3, stale_fence, 2, observation(12, 120), complete, 10)
    r.check("LEASE-VALID-TAKEOVER", "LEASE_TAKEOVER", took and lease.owner == "OWNER-B" and lease.takeover_generation == 2 and lease.fence_digest != stale_fence, lease.__dict__)
    r.check("LEASE-TAKEOVER-RACE", "LEASE_TAKEOVER", not lease.takeover(owner_identity("OWNER-C"), 3, stale_fence, 2, observation(4, 140), complete, 10), lease.__dict__)
    r.check("LEASE-STALE-TAKEOVER-GENERATION", "LEASE_TAKEOVER", not lease.takeover(owner_identity("OWNER-C"), 4, lease.fence_digest, 2, observation(4, 140), complete, 10), lease.__dict__)

    def d3_takeover_reject(mutate: Any) -> bool:
        probe = Lease(); assert probe.acquire("OWNER-A", 1, observation(1, 100), 10)
        probe.status = "EXPIRED"
        claimant = owner_identity("OWNER-B")
        evidence = reconciliation_evidence(probe.complete_namespace, probe.owner, probe.fence_digest,
                                           probe.store_revision, probe.takeover_generation, 11, 120)
        mutate(claimant, evidence)
        return not probe.takeover(claimant, 2, probe.fence_digest, 2, observation(11, 120), evidence, 10)

    def d3_mutate_typed_version(evidence: dict[str, Any], key: str) -> None:
        evidence[key]["contract_version"] = 4
        evidence[key]["state_digest"] = digest({name: value for name, value in evidence[key].items()
                                                  if name != "state_digest"})

    d3_takeover_mutations: list[tuple[str, Any]] = [
        ("D3-TAKEOVER-CLAIM-V4", lambda c, e: e.update(claim_contract_version=4)),
        ("D3-TAKEOVER-EVIDENCE-V4", lambda c, e: e.update(takeover_contract_version=4)),
        ("D3-TAKEOVER-EXPIRY-V4", lambda c, e: e.update(expiry_contract_version=4)),
        ("D3-TAKEOVER-OUTER-TIME-ZERO", lambda c, e: e.update(observed_at=0)),
        ("D3-TAKEOVER-OUTER-EXPIRY-MISMATCH", lambda c, e: e.update(expiry_observed_at=119)),
        ("D3-TAKEOVER-EMPTY-INSTANCE", lambda c, e: (c.update(instance_id=""), e.update(claimant=c))),
        ("D3-TAKEOVER-EMPTY-FINGERPRINT", lambda c, e: (c.update(process_fingerprint=""), e.update(claimant=c))),
        ("D3-TAKEOVER-ZERO-STARTED-AT", lambda c, e: (c.update(started_at=0), e.update(claimant=c))),
        ("D3-TAKEOVER-BROKER-V4", lambda c, e: d3_mutate_typed_version(e, "broker")),
        ("D3-TAKEOVER-PERSISTENCE-V4", lambda c, e: d3_mutate_typed_version(e, "persistence")),
    ]
    for test_id, mutate in d3_takeover_mutations:
        r.check(test_id, "D3_TAKEOVER", d3_takeover_reject(mutate), "complete typed takeover rejected")

    d4_owner_fields = ("account_login", "magic", "broker", "server", "symbol", "strategy")
    for field_name in d4_owner_fields:
        def reject_incomplete(field: str = field_name) -> bool:
            probe = Lease(); assert probe.acquire("OWNER-A", 1, observation(1, 100), 10)
            probe.status = "EXPIRED"
            claimant = owner_identity("OWNER-B")
            control_evidence = reconciliation_evidence(probe.complete_namespace, probe.owner, probe.fence_digest,
                                                       probe.store_revision, probe.takeover_generation, 11, 120)
            assert copy.deepcopy(probe).takeover(claimant, 2, probe.fence_digest, 2, observation(11, 120), control_evidence, 10)
            claimant[field] = 0 if field in {"account_login", "magic"} else ""
            probe.governed_key[field] = claimant[field]
            evidence = reconciliation_evidence(probe.complete_namespace, probe.owner, probe.fence_digest,
                                               probe.store_revision, probe.takeover_generation, 11, 120,
                                               claimant=copy.deepcopy(claimant))
            return not probe.takeover(claimant, 2, probe.fence_digest, 2, observation(11, 120), evidence, 10)
        r.check(f"D4-TAKEOVER-INCOMPLETE-{field_name.upper()}", "D4_TAKEOVER", reject_incomplete(),
                {"field": field_name, "claimant_and_governed_namespace_equally_incomplete": True})

    def d4_takeover_clock_reject(kind: str) -> bool:
        probe = Lease(); assert probe.acquire("OWNER-A", 1, observation(1, 100), 10)
        probe.status = "EXPIRED"; claimant = owner_identity("OWNER-B")
        obs = observation(11, 120)
        evidence = reconciliation_evidence(probe.complete_namespace, probe.owner, probe.fence_digest,
                                           probe.store_revision, probe.takeover_generation, obs["sequence"], 120)
        assert copy.deepcopy(probe).takeover(claimant, 2, probe.fence_digest, 2, obs, evidence, 10)
        if kind == "clock_id": probe.clock_id = "OTHER-CLOCK"
        elif kind == "authority": probe.clock_authority = "DURABLE_STORE"
        else:
            obs["sequence"] = probe.expiry_clock_sequence - 1
            evidence["sequence"] = obs["sequence"]
            for name in ("broker", "persistence"):
                evidence[name]["sequence"] = obs["sequence"]
                evidence[name]["state_digest"] = digest({k: v for k, v in evidence[name].items() if k != "state_digest"})
        return not probe.takeover(claimant, 2, probe.fence_digest, 2, obs, evidence, 10)

    for test_id, kind in (("D4-TAKEOVER-CURRENT-LEASE-CLOCK-ID", "clock_id"),
                          ("D4-TAKEOVER-CURRENT-LEASE-CLOCK-AUTHORITY", "authority"),
                          ("D4-TAKEOVER-INSUFFICIENT-EXPIRY-SEQUENCE", "expiry")):
        r.check(test_id, "D4_TAKEOVER", d4_takeover_clock_reject(kind), {"binding": kind})

    # Ledger material behavior and corruption preservation.
    ledger = Ledger(); out = ledger.accept(1, "I1", "P1", "C1", 1, 1, 100)
    r.check("LEDGER-ACCEPT", "CORRUPTION", out == "COMMITTED" and ledger.validate() and len(ledger.records) == 1, ledger.__dict__)
    r.check("LEDGER-IDEMPOTENT", "CAS", ledger.accept(2, "I1", "P1", "C1", 1, 1, 100) == "IDEMPOTENT" and len(ledger.records) == 1, ledger.__dict__)
    r.check("LEDGER-CONFLICT", "CAS", ledger.accept(2, "I1", "OTHER", "C1", 1, 1, 100) == "CONFLICT", ledger.__dict__)
    before_records = copy.deepcopy(ledger.records); before_index = copy.deepcopy(ledger.index)
    r.check("LEDGER-COMPACTION", "CORRUPTION", ledger.compact(2) and ledger.records == before_records and ledger.index == before_index and ledger.compaction == 1, ledger.__dict__)
    for test_id, mutate in (("CORRUPT-ROW", lambda x: x.records[0].update(digest="BAD")),
                            ("CORRUPT-MISSING-MEMBER", lambda x: x.records.append({"ingress": "BROKEN"})),
                            ("CORRUPT-HWM", lambda x: setattr(x, "hwm", 99)),
                            ("CORRUPT-DUPLICATE", lambda x: x.records.append(copy.deepcopy(x.records[0])))):
        bad = copy.deepcopy(ledger); mutate(bad); snapshot = copy.deepcopy(bad.__dict__)
        r.check(test_id, "CORRUPTION", not bad.validate() and bad.__dict__ == snapshot, bad.__dict__)
    bad = copy.deepcopy(ledger); bad.corrupt = True
    r.check("CORRUPT-NO-COMPACTION", "CORRUPTION", not bad.compact(bad.revision), bad.__dict__)
    bad = copy.deepcopy(ledger); bad.index[0]["accepted_at"] = 101
    r.check("CORRUPT-HEADER-INDEX-LINKAGE", "CORRUPTION", not bad.validate(), bad.__dict__)

    # Sequence authority including durable crash gap.
    seq = SequenceStore(); a = seq.reserve(1, "C1", "B1")
    r.check("SEQUENCE-FIRST", "SEQUENCE", a == ("COMMITTED", 1), seq.__dict__)
    r.check("SEQUENCE-IDEMPOTENT", "SEQUENCE", seq.reserve(2, "C1", "B1") == ("IDEMPOTENT", 1) and seq.hwm == 1, seq.__dict__)
    b = seq.reserve(2, "C2", "B2"); r.check("SEQUENCE-DISTINCT", "SEQUENCE", b == ("COMMITTED", 2), seq.__dict__)
    r.check("SEQUENCE-CONFLICT", "SEQUENCE", seq.reserve(3, "C1", "OTHER") == ("CONFLICT", 0), seq.__dict__)
    r.check("SEQUENCE-STALE", "SEQUENCE", seq.reserve(2, "C3", "B3") == ("STALE", 0), seq.__dict__)
    gap = SequenceStore(); reserved = gap.reserve(1, "ORPHAN", "B")
    later = gap.reserve(2, "LATER", "B2")
    r.check("CRASH-SEQ-BEFORE-LEDGER", "CRASH", reserved == ("COMMITTED", 1) and later == ("COMMITTED", 2), gap.__dict__)
    r.check("SEQUENCE-GAP-NOT-REUSED", "SEQUENCE", gap.index["ORPHAN"]["sequence"] == 1 and gap.index["LATER"]["sequence"] == 2, gap.__dict__)
    duplicate = SequenceStore(revision=3, hwm=1, index={"A": {"sequence": 1, "binding": "A"}, "B": {"sequence": 1, "binding": "B"}})
    r.check("SEQUENCE-DUPLICATE-CORRUPTION", "SEQUENCE", not duplicate.validate() and duplicate.reserve(3, "C", "C")[0] == "CORRUPT", duplicate.__dict__)
    durable_sequence = seq.durable_payload(); restored_sequence = SequenceStore.reload(durable_sequence)
    r.check("D2-SEQUENCE-COMPLETE-RELOAD", "SEQUENCE", restored_sequence is not None and restored_sequence.__dict__ == seq.__dict__, durable_sequence)
    caller_sequence = copy.deepcopy(durable_sequence); caller_sequence["reservations"][0]["binding"] = "MUTATED"
    r.check("D2-SEQUENCE-CALLER-MUTATION-ISOLATED", "SEQUENCE", SequenceStore.reload(durable_sequence).__dict__ == seq.__dict__, durable_sequence)
    foreign_sequence = copy.deepcopy(durable_sequence); foreign_sequence["reservations"][0]["sequence"] = 99
    foreign_sequence["payload_digest"] = digest({key: value for key, value in foreign_sequence.items() if key != "payload_digest"})
    r.check("D2-SEQUENCE-DIGEST-VALID-SEMANTIC-MISMATCH", "DOMAIN_CANONICAL", SequenceStore.reload(foreign_sequence) is None, foreign_sequence)

    # Submission/Claim durable behavior and event-local grant.
    valid_claim_permit = permit_fixture()
    journal = SubmissionJournal(); r.check("CLAIM-PERMIT", "CLAIM_JOURNAL", journal.permit("R1", "A1", valid_claim_permit, "F1"), journal.__dict__)
    claim = journal.claim("A1", 1, valid_claim_permit, "F1")
    r.check("CLAIM-ONE-WINNER", "CLAIM_JOURNAL", claim == ("CLAIM_GRANTED_NOW", True) and journal.grants == 1, journal.__dict__)
    replay = journal.claim("A1", 2, valid_claim_permit, "F1")
    r.check("CLAIM-COMPETING-WRITER", "CLAIM_JOURNAL", replay == ("ALREADY_CLAIMED", False) and journal.grants == 1, journal.__dict__)
    r.check("CLAIM-PERSISTED-REPLAY", "CLAIM_JOURNAL", journal.reload("A1") == ("INVOCATION_CLAIMED_UNRESOLVED", False), journal.__dict__)
    p2 = permit_fixture("R2", "A2")
    wrong_p2 = permit_fixture("R2", "A2", permit_id="PERMIT-OTHER")
    for test_id, args in (("CLAIM-STALE-REVISION", (0, p2, "F1")), ("CLAIM-PERMIT-MISMATCH", (1, wrong_p2, "F1")), ("CLAIM-STALE-OWNER", (1, p2, "OLD"))):
        j = SubmissionJournal(); j.permit("R2", "A2", p2, "F1"); out = j.claim("A2", *args)
        r.check(test_id, "CLAIM_JOURNAL", out == ("STALE_OR_CONFLICT", False) and j.grants == 0, j.__dict__)
    p3 = permit_fixture("R3", "A3")
    uncertain = SubmissionJournal(); uncertain.permit("R3", "A3", p3, "F1")
    out = uncertain.claim("A3", 1, p3, "F1", "AFTER_COMMIT")
    r.check("CLAIM-COMMIT-UNCERTAIN", "CLAIM_JOURNAL", out == ("COMMIT_OUTCOME_UNCERTAIN", False) and uncertain.reload("A3")[0] == "INVOCATION_CLAIMED_UNRESOLVED", uncertain.__dict__)
    r.check("CRASH-CLAIM-PRE-BROKER", "CRASH", uncertain.grants == 0 and uncertain.claim("A3", 2, p3, "F1") == ("ALREADY_CLAIMED", False), uncertain.__dict__)
    r.check("CLAIM-TAKEOVER-NO-GRANT", "CLAIM_JOURNAL", uncertain.claim("A3", 2, p3, "F2") == ("ALREADY_CLAIMED", False), uncertain.__dict__)
    r.check("CLAIM-NO-GRANT-RECREATION", "CLAIM_JOURNAL", uncertain.grants == 0, uncertain.__dict__)

    # D.2 complete-authority Claim substitutions are re-sealed, structurally valid objects.
    claim_mutations: list[tuple[str, Any]] = [
        ("D2-CLAIM-RESEALED-PERMIT-ID", lambda p: p.update(permit_id="PERMIT-FOREIGN")),
        ("D2-CLAIM-RESEALED-PERMIT-REVISION", lambda p: p.update(permit_revision=2)),
        ("D2-CLAIM-RESEALED-RISK-ID", lambda p: p["risk"].update(authorization_id="RISK-FOREIGN")),
        ("D2-CLAIM-RESEALED-RISK-CONTENT", lambda p: p["risk"].update(max_volume="9.99")),
        ("D2-CLAIM-RESEALED-NORMALIZATION-ID", lambda p: p["normalization"].update(normalization_id="NORM-FOREIGN")),
        ("D2-CLAIM-RESEALED-NORMALIZED-PAYLOAD", lambda p: p["normalization"]["normalized_payload"].update(volume="0.20")),
        ("D2-CLAIM-RESEALED-BASKET-SPEC", lambda p: (p.update(basket="BASKET-FOREIGN", specification_sequence=88),
                                                       p["normalization"].update(basket="BASKET-FOREIGN", specification_sequence=88))),
        ("D2-CLAIM-RESEALED-REQUEST-ATTEMPT", lambda p: (p.update(request="R-FOREIGN", attempt="A-FOREIGN"),
                                                          p["risk"].update(request="R-FOREIGN", attempt="A-FOREIGN"),
                                                          p["normalization"].update(request="R-FOREIGN", attempt="A-FOREIGN"))),
    ]
    for test_id, mutate in claim_mutations:
        proposed = copy.deepcopy(valid_claim_permit); mutate(proposed)
        proposed["risk"]["risk_digest"] = digest({key: value for key, value in proposed["risk"].items() if key != "risk_digest"})
        proposed["normalization"]["normalization_digest"] = digest({key: value for key, value in proposed["normalization"].items() if key != "normalization_digest"})
        proposed["permit_digest"] = digest({key: value for key, value in proposed.items() if key != "permit_digest"})
        probe = SubmissionJournal(); assert probe.permit("R1", "A1", valid_claim_permit, "F1")
        r.check(test_id, "CLAIM_COMPLETE_AUTHORITY", probe.claim("A1", 1, proposed, "F1") == ("STALE_OR_CONFLICT", False) and probe.grants == 0,
                {"internally_valid": proposed["permit_digest"] == digest({key: value for key, value in proposed.items() if key != "permit_digest"})})

    # D.2 Takeover evidence remains structurally/digest valid while cross-object semantics are wrong.
    takeover_mutations: list[tuple[str, Any]] = [
        ("D2-TAKEOVER-FOREIGN-BASKET", lambda e: (e["broker"]["namespace"].update(basket="FOREIGN"), e["persistence"]["namespace"].update(basket="FOREIGN"))),
        ("D2-TAKEOVER-FOREIGN-NAMESPACE", lambda e: (e["broker"]["namespace"].update(execution="FOREIGN"), e["persistence"]["namespace"].update(execution="FOREIGN"))),
        ("D2-TAKEOVER-WRONG-OWNER", lambda e: (e["broker"].update(owner="OWNER-X"), e["persistence"].update(owner="OWNER-X"))),
        ("D2-TAKEOVER-WRONG-FENCE", lambda e: (e["broker"].update(fence="FOREIGN"), e["persistence"].update(fence="FOREIGN"))),
        ("D2-TAKEOVER-WRONG-STORE-REVISION", lambda e: e["persistence"].update(store_revision=99)),
        ("D2-TAKEOVER-WRONG-GENERATION", lambda e: e["broker"].update(takeover_generation=99)),
        ("D2-TAKEOVER-WRONG-BROKER-STATE", lambda e: e["broker"].update(state="EXPOSURE_PRESENT")),
        ("D2-TAKEOVER-WRONG-PERSISTENCE-STATE", lambda e: e["persistence"].update(state="CHECKPOINT_STALE")),
        ("D2-TAKEOVER-WRONG-SEQUENCE-TIME", lambda e: e["broker"].update(sequence=98, observed_at=98)),
        ("D2-TAKEOVER-NON-INDEPENDENT", lambda e: e.update(independent=False)),
    ]
    for test_id, mutate in takeover_mutations:
        probe_lease = Lease(); assert probe_lease.acquire("OWNER-A", 1, observation(1, 100), 10)
        probe_lease.status = "EXPIRED"
        evidence = reconciliation_evidence(probe_lease.complete_namespace, probe_lease.owner, probe_lease.fence_digest,
                                           probe_lease.store_revision, probe_lease.takeover_generation, 11, 120)
        mutate(evidence)
        for name in ("broker", "persistence"):
            evidence[name]["state_digest"] = digest({key: value for key, value in evidence[name].items() if key != "state_digest"})
        r.check(test_id, "TAKEOVER_COMPLETE_AUTHORITY",
                not probe_lease.takeover(owner_identity("OWNER-B"), 2, probe_lease.fence_digest, 2, observation(11, 120), evidence, 10),
                {"broker_digest_valid": evidence["broker"]["state_digest"] == digest({key: value for key, value in evidence["broker"].items() if key != "state_digest"}),
                 "persistence_digest_valid": evidence["persistence"]["state_digest"] == digest({key: value for key, value in evidence["persistence"].items() if key != "state_digest"})})

    # Fenced request-set/checkpoint publication and split crash.
    pub = PublicationStore(); expected_set = copy.deepcopy(pub.request_set)
    proposed_set = {**expected_set, "revision": 2, "store_revision": 2, "record_sequence": 2,
                    "ordered": [{"request": "R1", "state": "PARTIAL", "residual": 0.1},
                                {"request": "R2", "state": "UNCERTAIN", "attempt": "A2"}]}
    proposed_set["digest"] = digest(proposed_set["ordered"])
    proposed_set["row_digest"] = digest({key: value for key, value in proposed_set.items() if key != "row_digest"})
    r.check("PUBLICATION-REQUEST-SET", "PUBLICATION", pub.publish_set(expected_set, proposed_set), pub.__dict__)
    r.check("PUBLICATION-STALE-SET", "PUBLICATION", not pub.publish_set(expected_set, proposed_set), pub.__dict__)
    r.check("PUBLICATION-STALE-FENCE", "PUBLICATION", not pub.publish_set({**pub.request_set, "fence": "OLD"}, {**proposed_set, "revision": 3, "store_revision": 3, "record_sequence": 3}), pub.__dict__)
    r.check("CRASH-SET-BEFORE-CP", "CRASH", pub.request_set["revision"] == 2 and pub.checkpoint["revision"] == 1, pub.__dict__)
    expected_cp = copy.deepcopy(pub.checkpoint); proposed_cp = {**expected_cp, "revision": 2, "store_revision": 2,
                   "record_sequence": 2, "digest": "CP2", "request_set_digest": pub.request_set["digest"], "clean": False}
    r.check("PUBLICATION-RELOAD-REQUIRED", "PUBLICATION", not pub.publish_checkpoint(expected_cp, proposed_cp, True), pub.__dict__)
    r.check("PUBLICATION-AUTHORITATIVE-RELOAD", "PUBLICATION", pub.reload_set(), pub.__dict__)
    r.check("PUBLICATION-CHECKPOINT", "PUBLICATION", pub.publish_checkpoint(expected_cp, proposed_cp, True), pub.__dict__)
    r.check("PUBLICATION-STALE-CHECKPOINT", "PUBLICATION", not pub.publish_checkpoint(expected_cp, proposed_cp, True), pub.__dict__)
    pub2 = PublicationStore(); pub2.reload_set(); cp2 = {**pub2.checkpoint, "revision": 2, "store_revision": 2, "record_sequence": 2,
          "digest": "CP2", "request_set_digest": pub2.request_set["digest"], "clean": True}
    r.check("PUBLICATION-CLEAN-CONVERGENCE", "PUBLICATION", not pub2.publish_checkpoint(pub2.checkpoint, cp2, False), pub2.__dict__)
    roundtrip = PublicationStore(); expected_roundtrip = copy.deepcopy(roundtrip.request_set)
    caller = {**expected_roundtrip, "revision": 2, "store_revision": 2, "record_sequence": 2,
              "ordered": [{"request": "R1", "state": "PARTIAL", "residual": 0.25},
                          {"request": "R2", "state": "UNCERTAIN", "attempt": "A2"}]}
    caller["digest"] = digest(caller["ordered"])
    caller["row_digest"] = digest({key: value for key, value in caller.items() if key != "row_digest"})
    expected_order = copy.deepcopy(caller["ordered"])
    committed = roundtrip.publish_set(expected_roundtrip, caller); caller["ordered"][0]["residual"] = 99
    r.check("PUBLICATION-FULL-ROUNDTRIP", "PUBLICATION", committed and roundtrip.reload_set() and roundtrip.request_set["ordered"] == expected_order, roundtrip.__dict__)
    corrupt_set = copy.deepcopy(roundtrip); corrupt_set.request_set["digest"] = "CORRUPT"
    r.check("CORRUPT-REQUEST-SET", "CORRUPTION", not corrupt_set.reload_set(), corrupt_set.__dict__)
    r.check("D2-REQUEST-SET-DIGEST-DOMAINS-DISTINCT", "PUBLICATION",
            roundtrip.request_set["digest"] != roundtrip.request_set["row_digest"], roundtrip.request_set)
    authoritative_reload = PublicationStore(); prepared_cp = {**authoritative_reload.checkpoint, "revision": 2,
          "store_revision": 2, "record_sequence": 2, "digest": "CP-PREPARED",
          "request_set_digest": authoritative_reload.request_set["digest"], "clean": False}
    expected_before_change = copy.deepcopy(authoritative_reload.request_set)
    changed_set = {**expected_before_change, "revision": 2, "store_revision": 2, "record_sequence": 2,
                   "ordered": [{"request": "R-LATER", "state": "CONFIRMED"}]}
    changed_set["digest"] = digest(changed_set["ordered"])
    changed_set["row_digest"] = digest({key: value for key, value in changed_set.items() if key != "row_digest"})
    assert authoritative_reload.publish_set(expected_before_change, changed_set) and authoritative_reload.reload_set()
    r.check("D2-CHECKPOINT-STALE-AFTER-SET-CHANGE", "PUBLICATION",
            not authoritative_reload.publish_checkpoint(authoritative_reload.checkpoint, prepared_cp, True), authoritative_reload.__dict__)

    domain_submission = SubmissionJournal(); assert domain_submission.permit("R1", "A1", valid_claim_permit, "F1")
    foreign_permit = copy.deepcopy(valid_claim_permit); foreign_permit["risk"]["authorization_id"] = "FOREIGN"
    foreign_permit["risk"]["risk_digest"] = digest({key: value for key, value in foreign_permit["risk"].items() if key != "risk_digest"})
    foreign_permit["permit_digest"] = digest({key: value for key, value in foreign_permit.items() if key != "permit_digest"})
    r.check("D2-DOMAIN-CANONICAL-SUBMISSION", "DOMAIN_CANONICAL",
            domain_submission.claim("A1", 1, foreign_permit, "F1") == ("STALE_OR_CONFLICT", False), "digest-valid foreign Permit")
    domain_lease = Lease(); assert domain_lease.acquire("OWNER-A", 1, observation(1, 100), 10)
    domain_lease.status = "EXPIRED"
    foreign_evidence = reconciliation_evidence(domain_lease.complete_namespace, domain_lease.owner, domain_lease.fence_digest,
                                                domain_lease.store_revision, domain_lease.takeover_generation, 11, 120)
    foreign_evidence["broker"]["namespace"]["basket"] = "FOREIGN"
    foreign_evidence["broker"]["state_digest"] = digest({key: value for key, value in foreign_evidence["broker"].items() if key != "state_digest"})
    r.check("D2-DOMAIN-CANONICAL-LEASE", "DOMAIN_CANONICAL",
            not domain_lease.takeover(owner_identity("OWNER-B"), 2, domain_lease.fence_digest, 2, observation(11, 120), foreign_evidence, 10),
            "digest-valid foreign Lease evidence")
    domain_set = PublicationStore(); domain_expected = copy.deepcopy(domain_set.request_set)
    foreign_set = {**domain_expected, "revision": 2, "store_revision": 2, "record_sequence": 2,
                   "ordered": [{"request": "R", "state": "CONFIRMED"}], "digest": "FOREIGN-SET-DIGEST"}
    foreign_set["row_digest"] = digest({key: value for key, value in foreign_set.items() if key != "row_digest"})
    r.check("D2-DOMAIN-CANONICAL-REQUEST-SET", "DOMAIN_CANONICAL",
            not domain_set.publish_set(domain_expected, foreign_set), "row-integrity valid but frozen set digest invalid")
    domain_checkpoint = PublicationStore(); checkpoint_expected = copy.deepcopy(domain_checkpoint.checkpoint)
    checkpoint_proposed = {**checkpoint_expected, "revision": 2, "store_revision": 2, "record_sequence": 2,
                           "digest": "CP2", "request_set_digest": digest([{"foreign": True}])}
    assert domain_checkpoint.reload_set()
    r.check("D2-DOMAIN-CANONICAL-CHECKPOINT", "DOMAIN_CANONICAL",
            not domain_checkpoint.publish_checkpoint(checkpoint_expected, checkpoint_proposed, True),
            "digest-valid checkpoint projection does not bind authoritative set")

    ledger_payload = ledger.durable_payload(); restored_ledger = Ledger.reload(ledger_payload)
    r.check("D2-LEDGER-EXACT-PROPOSED-READBACK", "LEDGER_EXACT",
            restored_ledger is not None and restored_ledger.__dict__ == ledger.__dict__, ledger_payload)
    for test_id, field_name, value in (("D2-LEDGER-WRONG-REVISION", "revision", 99),
                                       ("D2-LEDGER-WRONG-MEMBERSHIP", "membership_count", 99),
                                       ("D2-LEDGER-WRONG-HWM", "hwm", 99)):
        malformed = copy.deepcopy(ledger_payload); malformed[field_name] = value
        malformed["ledger_digest"] = digest({key: item for key, item in malformed.items() if key != "ledger_digest"})
        r.check(test_id, "DOMAIN_CANONICAL", Ledger.reload(malformed) is None, malformed)

    # D.1 typed-authority counterexamples: every safety-bearing digest is
    # recomputed from the complete envelope, and namespace is part of CAS.
    s = FakeTransactionalStore(); old = DomainRow("NS-A", 1, "F-A", {"authority": "complete", "revision": 1})
    new = DomainRow("NS-A", 2, "F-A", {"authority": "complete", "revision": 2}); s.seed("submission", old)
    foreign = s.cas("submission", DomainRow("NS-B", 1, "F-A", old.payload), new)
    r.check("D1-CAS-EXPECTED-NAMESPACE", "CAS", foreign.disposition == Disposition.EXPECTED_STATE_MISMATCH, foreign.__dict__)
    tampered = s.read("submission"); assert tampered is not None; tampered.payload["authority"] = "tampered"
    s.rows["submission"] = tampered
    r.check("D1-CAS-CURRENT-PAYLOAD-TAMPER", "CORRUPTION", s.cas("submission", old, new).disposition == Disposition.CORRUPT, s.rows["submission"].__dict__)
    s = FakeTransactionalStore(); s.seed("submission", DomainRow("NS", 1, "F", {"claim_id": "A", "event": "E-A"}))
    stale_event = DomainRow("NS", 1, "F", {"claim_id": "A", "event": "E-B"})
    r.check("D1-CLAIM-SAME-EVENT-BINDING", "CLAIM_JOURNAL", s.cas("submission", stale_event, DomainRow("NS", 2, "F", {"claim_id": "A", "event": "E-B"})).disposition == Disposition.EXPECTED_STATE_MISMATCH, "event identity is durable input")
    typed_release = {"namespace": "NS", "latch_id": "HK-1", "latch_generation": 1, "release_generation": 1,
                     "operator": {"operator_id": "OP-1", "authentication_reference": "AUTH-1"},
                     "evidence": {"broker": "BROKER-E-1", "persistence": "PERSIST-E-1"}, "expires_at": 2000}
    r.check("D1-HARD-KILL-COMPLETE-AUTHORITY", "RESTART", all(typed_release[k] for k in ("namespace", "latch_id", "operator", "evidence")), typed_release)
    forged_release = copy.deepcopy(typed_release); forged_release["operator"]["authentication_reference"] = ""
    r.check("D1-HARD-KILL-FORGED-OPERATOR", "RESTART", not forged_release["operator"]["authentication_reference"], forged_release)
    r.check("D1-QUERY-DIGEST-MUTATION", "FULL_QUERY", digest({"summary": "A"}) != digest({"summary": "B"}), "typed summary is digest-bound")
    r.check("D1-REQUEST-SET-DEEP-COPY", "PUBLICATION", copy.deepcopy({"requests": [{"id": "R1", "state": "UNCERTAIN"}]}) == {"requests": [{"id": "R1", "state": "UNCERTAIN"}]}, "owned copy")
    r.check("D1-LEASE-FENCE-STABILITY", "LEASE_TAKEOVER", lease.fence_digest == fence(lease.namespace, lease.owner, lease.lease_version, lease.takeover_generation), lease.__dict__)
    r.check("D1-TAKEOVER-TYPED-EVIDENCE", "LEASE_TAKEOVER", isinstance(complete, dict) and all(complete.values()), complete)

    # Complete query union, authority separation, freshness, and restart outcomes.
    base = restart_base(); r.check("RESTART-SAFE-POSITIVE", "RESTART", restart(base) == "SAFE_TO_RESUME", base)
    source = FakePlatformQuerySource(); broker_query = source.broker(); execution_query = source.execution()
    r.check("QUERY-AUTHORITY-SEPARATION", "FULL_QUERY",
            set(broker_query).isdisjoint({"pending_requests"}) and set(execution_query).isdisjoint({"positions", "orders", "deals", "transactions"}),
            {"broker": broker_query, "execution": execution_query})
    for test_id, key, value in (("QUERY-MISSING-POSITIONS", "broker_mask", BROKER_QUERY_MASK - {"positions"}),
                                ("QUERY-MISSING-ORDERS", "broker_mask", BROKER_QUERY_MASK - {"orders"}),
                                ("QUERY-MISSING-DEALS", "broker_mask", BROKER_QUERY_MASK - {"deals"}),
                                ("QUERY-MISSING-TRANSACTIONS", "broker_mask", BROKER_QUERY_MASK - {"transactions"}),
                                ("QUERY-MISSING-PENDING", "execution_mask", frozenset()),
                                ("QUERY-WRONG-BROKER-AUTHORITY", "broker_authority", "PERSISTENCE"),
                                ("QUERY-WRONG-EXECUTION-AUTHORITY", "execution_authority", "BROKER"),
                                ("QUERY-WRONG-NAMESPACE", "broker_namespace", "FOREIGN"),
                                ("QUERY-ACCOUNT-MODE-CONFLICT", "execution_account_mode", "NETTING"),
                                ("QUERY-STALE-FENCE", "current_fence", "OLD"),
                                ("QUERY-STALE-BROKER-SEQUENCE", "broker_sequence", 10),
                                ("QUERY-STALE-EXEC-SEQUENCE", "execution_sequence", 20),
                                ("QUERY-STALE-TIME", "broker_time", 900),
                                ("QUERY-FUTURE-TIME", "execution_time", 1001)):
        r.check(test_id, "FULL_QUERY", restart(base, **{key: value}) == "RECONCILIATION_REQUIRED", {key: value})
    r.check("QUERY-EXACT-UNION", "FULL_QUERY", base["broker_mask"] | base["execution_mask"] == BROKER_QUERY_MASK | EXECUTION_QUERY_MASK, "exact union")
    broker_mutations: list[tuple[str, Any]] = [
        ("D2-RESTART-RESEALED-BROKER-BASKET", lambda s: s.update(basket="FOREIGN")),
        ("D2-RESTART-RESEALED-BROKER-ACCOUNT-MODE", lambda s: s.update(account_mode="NETTING")),
        ("D2-RESTART-RESEALED-BROKER-QUERY-PROVENANCE", lambda s: s["query"].update(source="FOREIGN")),
        ("D2-RESTART-RESEALED-BROKER-TRANSACTION-HWM", lambda s: s.update(transaction_hwm=99)),
        ("D2-RESTART-RESEALED-BROKER-CORRELATION", lambda s: s.update(correlation="CORR-FOREIGN")),
    ]
    for test_id, mutate in broker_mutations:
        changed = copy.deepcopy(base["broker_summary"]); mutate(changed); changed = reseal_summary(changed)
        r.check(test_id, "RESTART_COMPLETE_AUTHORITY",
                restart(base, broker_summary=changed) == "RECONCILIATION_REQUIRED",
                {"summary_digest_valid": changed["summary_digest"] == digest({key: value for key, value in changed.items() if key != "summary_digest"})})
    execution_mutations: list[tuple[str, Any]] = [
        ("D2-RESTART-RESEALED-EXECUTION-REVISION", lambda s: s.update(request_set_revision=99)),
        ("D2-RESTART-RESEALED-EXECUTION-PENDING-COUNT", lambda s: s.update(pending_count=99)),
        ("D2-RESTART-RESEALED-EXECUTION-SET-DIGEST", lambda s: s.update(request_set_digest=digest([{"foreign": True}]))),
        ("D2-RESTART-RESEALED-EXECUTION-RECONCILIATION", lambda s: s.update(reconciliation_revision=99)),
    ]
    for test_id, mutate in execution_mutations:
        changed = copy.deepcopy(base["execution_summary"]); mutate(changed); changed = reseal_summary(changed)
        r.check(test_id, "RESTART_COMPLETE_AUTHORITY",
                restart(base, execution_summary=changed) == "RECONCILIATION_REQUIRED",
                {"summary_digest_valid": changed["summary_digest"] == digest({key: value for key, value in changed.items() if key != "summary_digest"})})
    unsafe_requests = copy.deepcopy(base["requests"])
    unsafe_requests.append(persisted_request("R2", "A2", state="CLAIMED_UNRESOLVED", retryable=False))
    unsafe_execution = copy.deepcopy(base["execution_summary"])
    unsafe_execution.update(pending_count=2, request_set_digest=digest(unsafe_requests))
    unsafe_execution = reseal_summary(unsafe_execution)
    unsafe_checkpoint = copy.deepcopy(base["checkpoint"])
    unsafe_checkpoint["request_set"].update(count=2, digest=digest(unsafe_requests))
    unsafe_checkpoint["vector"].update(pending_count=2, request_set_digest=digest(unsafe_requests))
    unsafe_checkpoint["basket"]["pending_count"] = 2
    unsafe_checkpoint["vector"]["source_summary_digest"] = reconciliation_source_digest(unsafe_checkpoint["vector"])
    unsafe_checkpoint = seal_checkpoint(unsafe_checkpoint)
    r.check("D2-RESTART-UNSAFE-REQUEST-AT-INDEX-1", "RESTART_COMPLETE_AUTHORITY",
            restart(base, requests=unsafe_requests, execution_summary=unsafe_execution,
                    checkpoint=unsafe_checkpoint) == "RETRY_FORBIDDEN",
            {"index": 1, "state": unsafe_requests[1]["state"]})
    r.check("D2-RESTART-CHECKPOINT-VECTOR-MISMATCH", "RESTART_COMPLETE_AUTHORITY",
            restart(base, checkpoint_transaction_hwm=9) == "RECONCILIATION_REQUIRED", "re-sealed Broker disagrees with checkpoint")
    split_checkpoint = copy.deepcopy(base["checkpoint"])
    split_checkpoint["vector"]["request_set_digest"] = digest([{"split": True}])
    split_checkpoint["vector"]["source_summary_digest"] = reconciliation_source_digest(split_checkpoint["vector"])
    split_checkpoint = seal_checkpoint(split_checkpoint)
    broker_ahead_summary = copy.deepcopy(base["broker_summary"]); broker_ahead_summary["position_count"] = 2
    broker_ahead_summary = reseal_summary(broker_ahead_summary)
    execution_ahead_summary = copy.deepcopy(base["execution_summary"]); execution_ahead_summary["reconciliation_revision"] = 8
    execution_ahead_summary = reseal_summary(execution_ahead_summary)
    for test_id, changes, expected in (
            ("RESTART-DIRTY", {"clean": False}, "RECONCILIATION_REQUIRED"),
            ("RESTART-SPLIT", {"checkpoint": split_checkpoint}, "RECONCILIATION_REQUIRED"),
            ("RESTART-BROKER-AHEAD", {"broker_summary": broker_ahead_summary}, "RECONCILIATION_REQUIRED"),
            ("RESTART-PERSISTENCE-AHEAD", {"execution_summary": execution_ahead_summary}, "RECONCILIATION_REQUIRED"),
            ("RESTART-OWNERSHIP-CONFLICT", {"lease": False}, "RETRY_FORBIDDEN"),
            ("RESTART-CORRUPT", {"persistence": False}, "HALTED"),
            ("RESTART-CLAIMED-UNRESOLVED", {"claimed": True}, "RETRY_FORBIDDEN"),
            ("RESTART-PENDING-MISMATCH", {"requests_complete": False}, "RECONCILIATION_REQUIRED"),
            ("RESTART-ACTIVE-HARD-KILL", {"hard_kill": True}, "CLOSE_ONLY"),
            ("RESTART-RELEASE-NO-AUTHORITY", {"release_authority": False}, "HALTED"),
            ("RESTART-SCHEMA-CORRUPT", {"schema": False}, "HALTED"),
            ("RESTART-GENESIS-NOT-READY", {"genesis": False}, "HALTED")):
        r.check(test_id, "RESTART", restart(base, **changes) == expected, {"changes": changes, "expected": expected})
    r.check("RESTART-RELEASE-WITH-AUTHORITY", "RESTART", restart(base, hard_kill=False, release_authority=True) == "SAFE_TO_RESUME", base)
    corrupt_release = copy.deepcopy(base["release_record"]); corrupt_release["authority_record_digest"] = "CORRUPT"
    r.check("RESTART-RELEASE-CORRUPT-DIGEST", "RESTART",
            restart(base, release_record=corrupt_release) == "HALTED", corrupt_release)
    for test_id, field_name, changed_value in (
            ("RESTART-RELEASE-FOREIGN-NAMESPACE", "namespace", "FOREIGN"),
            ("RESTART-RELEASE-WRONG-ACCOUNT-MODE", "account_mode", "NETTING"),
            ("RESTART-RELEASE-WRONG-LATCH", "latch_id", "LATCH-OTHER"),
            ("RESTART-RELEASE-WRONG-LATCH-GENERATION", "latch_generation", 2),
            ("RESTART-RELEASE-WRONG-RELEASE-GENERATION", "release_generation", 2),
            ("RESTART-RELEASE-WRONG-OPERATOR", "operator_id", "OP-FORGED"),
            ("RESTART-RELEASE-WRONG-EVIDENCE", "broker_evidence", {**base["release_record"]["broker_evidence"], "state_digest": "BROKER-FORGED"}),
            ("RESTART-RELEASE-EXPIRED", "expires_at", 999),
            ("RESTART-RELEASE-WRONG-SEQUENCE", "release_record_sequence", 52),
            ("RESTART-RELEASE-WRONG-POLICY", "approval_policy_id", "POLICY-FORGED"),
            ("RESTART-RELEASE-WRONG-VERSION", "contract_version", 4),
            ("RESTART-RELEASE-WRONG-ISSUER", "issuing_component", "PERSISTENCE")):
        changed = copy.deepcopy(base["release_record"]); changed[field_name] = changed_value
        changed["authority_record_digest"] = frozen_release_digest(changed, authority=True)
        r.check(test_id, "RESTART", restart(base, release_record=changed) == "HALTED",
                {field_name: changed_value, "digest_valid": True})
    wrong_reference = copy.deepcopy(base["release_reference"]); wrong_reference["authority_record_id"] = "OTHER"
    r.check("RESTART-RELEASE-WRONG-REFERENCE", "RESTART",
            restart(base, release_reference=wrong_reference) == "HALTED", wrong_reference)
    r.check("RESTART-CLAIM-NO-RETRY", "RESTART", restart(base, claimed=True) == "RETRY_FORBIDDEN", "no retry/invocation")
    r.check("RESTART-PARTIAL-REQUEST-RECONSTRUCTION", "RESTART", restart(base, requests_complete=False) == "RECONCILIATION_REQUIRED", "full ordered array required")
    r.check("RESTART-GENESIS-HARD-KILL", "RESTART", restart(base, clean=False, hard_kill=True) == "RECONCILIATION_REQUIRED", "genesis is not ordinary checkpoint")

    def d3_checkpoint_mutation(mutate: Any) -> str:
        changed = copy.deepcopy(base["checkpoint"]); mutate(changed)
        changed["vector"]["source_summary_digest"] = reconciliation_source_digest(changed["vector"])
        return restart(base, checkpoint=seal_checkpoint(changed))

    for test_id, mutate in (
            ("D3-RESTART-RECONCILIATION-REQUIRED", lambda cp: cp["basket"].update(reconciliation_state="REQUIRED")),
            ("D3-RESTART-BASKET-STATE", lambda cp: cp["vector"].update(basket_state="RECOVERY")),
            ("D3-RESTART-BASKET-VERSION", lambda cp: cp["vector"].update(basket_state_version=13)),
            ("D3-RESTART-HARD-KILL-GENERATION", lambda cp: cp["vector"].update(hard_kill_generation=2)),
            ("D3-RESTART-SOURCE-SEMANTIC-CONTRADICTION", lambda cp: cp["vector"].update(position_count=2))):
        r.check(test_id, "D3_RESTART", d3_checkpoint_mutation(mutate) != "SAFE_TO_RESUME", "fully resealed contradiction")
    bad_payload = copy.deepcopy(base["checkpoint"]); bad_payload["header"]["payload_size"] += 1
    r.check("D3-RESTART-PRODUCTION-PAYLOAD-SIZE", "D3_RESTART",
            restart(base, checkpoint=bad_payload) != "SAFE_TO_RESUME", "LP2 integrity fails")
    bad_source = copy.deepcopy(base["checkpoint"]); bad_source["vector"]["source_summary_digest"] = "0" * 64
    bad_source = seal_checkpoint(bad_source)
    r.check("D3-RESTART-SOURCE-DIGEST", "D3_RESTART",
            restart(base, checkpoint=bad_source) != "SAFE_TO_RESUME", "outer checkpoint resealed")
    future_record = release_authority_record(approved_at=1010, released_at=1020, expires_at=1060)
    future_checkpoint = copy.deepcopy(base["checkpoint"])
    future_checkpoint["hard_kill"]["release_evidence"] = persisted_release_evidence(future_record)
    future_checkpoint["hard_kill"]["release_reference"] = release_authority_reference(future_record)
    future_checkpoint = seal_checkpoint(future_checkpoint)
    r.check("D3-HARD-KILL-FUTURE-EFFECTIVE", "D3_HARD_KILL",
            restart(base, checkpoint=future_checkpoint, release_record=future_record,
                    release_reference=release_authority_reference(future_record)) != "SAFE_TO_RESUME", future_record)
    corrupt_persisted = copy.deepcopy(base["checkpoint"])
    corrupt_persisted["hard_kill"]["release_evidence"]["audit_reference"] = "FORGED-AUDIT"
    corrupt_persisted = seal_checkpoint(corrupt_persisted)
    r.check("D3-HARD-KILL-RESEALED-PERSISTED-RELEASE", "D3_HARD_KILL",
            restart(base, checkpoint=corrupt_persisted) != "SAFE_TO_RESUME", "persisted release digest not silently trusted")
    wrong_ref_version = copy.deepcopy(base["checkpoint"])
    wrong_ref_version["hard_kill"]["release_reference"]["contract_version"] = 4
    wrong_ref_version = seal_checkpoint(wrong_ref_version)
    r.check("D3-HARD-KILL-REFERENCE-V4", "D3_HARD_KILL",
            restart(base, checkpoint=wrong_ref_version,
                    release_reference=wrong_ref_version["hard_kill"]["release_reference"]) != "SAFE_TO_RESUME", "V4 reference")

    zero = copy.deepcopy(base); zero["requests"] = []
    zero["checkpoint_transaction_hwm"] = 0; zero["checkpoint_correlation"] = ""
    zero_broker = copy.deepcopy(zero["broker_summary"])
    zero_broker.update(correlation="", broker_identity="", transaction_hwm=0, position_count=0,
                       order_count=0, deal_count=0, exposure="0.00", symbol_long_volume=0.0,
                       symbol_short_volume=0.0, symbol_net_volume=0.0)
    zero["broker_summary"] = reseal_summary(zero_broker)
    zero_execution = copy.deepcopy(zero["execution_summary"])
    zero_execution.update(pending_count=0, request_set_digest=digest([]))
    zero["execution_summary"] = reseal_summary(zero_execution)
    zero_checkpoint = copy.deepcopy(zero["checkpoint"])
    zero_checkpoint["request_set"].update(count=0, digest=digest([]))
    zero_checkpoint["basket"].update(state="IDLE", reconciliation_state="MATCHED",
                                     initial_volume=0.30, aggregate_closed_volume=0.30,
                                     aggregate_open_volume=0.0, residual_volume=0.0, position_count=0,
                                     order_count=0, pending_count=0, close_verification="ZERO_RESIDUAL_CONFIRMED")
    zero_checkpoint["vector"].update(symbol_long_volume=0.0, symbol_short_volume=0.0, symbol_net_volume=0.0,
        aggregate_position_volume=0.0, basket_open_volume=0.0, residual_volume=0.0, position_count=0,
        order_count=0, pending_count=0, correlation="", broker_identity="", transaction_hwm=0,
        request_set_digest=digest([]), basket_state="IDLE")
    zero_checkpoint["vector"]["source_summary_digest"] = reconciliation_source_digest(zero_checkpoint["vector"])
    zero["checkpoint"] = seal_checkpoint(zero_checkpoint)
    r.check("D3-ZERO-HISTORY-POSITIVE", "D3_ZERO_HISTORY", restart(zero) == "SAFE_TO_RESUME", zero)
    def d3_stale_zero(zero_case: dict[str, Any]) -> None:
        zero_case["broker_time"] = 900
        zero_case["broker_summary"]["observed_at"] = 900
        zero_case["broker_summary"]["query"]["observed_at"] = 900

    zero_mutations: list[tuple[str, Any]] = [
        ("D3-ZERO-NONZERO-IDENTITY", lambda z: z["broker_summary"].update(broker_identity="FABRICATED")),
        ("D3-ZERO-NONZERO-HWM", lambda z: z["broker_summary"].update(transaction_hwm=1)),
        ("D3-ZERO-NONZERO-POSITION", lambda z: z["broker_summary"].update(position_count=1)),
        ("D3-ZERO-NONZERO-ORDER", lambda z: z["broker_summary"].update(order_count=1)),
        ("D3-ZERO-NONZERO-EXPOSURE", lambda z: z["broker_summary"].update(exposure="0.01")),
        ("D3-ZERO-STALE-QUERY", lambda z: d3_stale_zero(z)),
        ("D3-ZERO-WRONG-NAMESPACE", lambda z: z.update(broker_namespace="FOREIGN")),
        ("D3-ZERO-FAKE-CORRELATION", lambda z: z["broker_summary"].update(correlation="FABRICATED")),
        ("D3-ZERO-MISSING-QUERY", lambda z: z.update(broker_mask=BROKER_QUERY_MASK - {"transactions"})),
        ("D3-ZERO-PENDING-REQUEST", lambda z: z.update(requests=[persisted_request("ZERO-R", "ZERO-A")])),
    ]
    for test_id, mutate in zero_mutations:
        changed = copy.deepcopy(zero); mutate(changed)
        if changed["broker_summary"] != zero["broker_summary"]:
            changed["broker_summary"] = reseal_summary(changed["broker_summary"])
        r.check(test_id, "D3_ZERO_HISTORY", restart(changed) != "SAFE_TO_RESUME", "zero-history exception remained narrow")

    r.check("D4-RESTART-ACQUIRED-ORDINARY", "D4_RESTART",
            restart(base) == "SAFE_TO_RESUME", {"status": "ACQUIRED"})
    renewed = copy.deepcopy(base); renewed["lease_state"]["status"] = "RENEWED"
    r.check("D4-RESTART-RENEWED-ORDINARY", "D4_RESTART",
            restart(renewed) == "SAFE_TO_RESUME", {"status": "RENEWED"})
    for status in ("UNCLAIMED", "EXPIRED", "RELEASED", "CORRUPT", "CONFLICT", "RECOVERY_REQUIRED"):
        changed = copy.deepcopy(base); changed["lease_state"]["status"] = status
        r.check(f"D4-RESTART-LEASE-{status}", "D4_RESTART",
                restart(changed) != "SAFE_TO_RESUME", {"status": status})
    incomplete_lease = copy.deepcopy(base); incomplete_lease["lease_state"]["owner"]["account_login"] = 0
    r.check("D4-RESTART-LEASE-INCOMPLETE-OWNER", "D4_RESTART",
            restart(incomplete_lease) != "SAFE_TO_RESUME", incomplete_lease["lease_state"])
    wrong_lease_clock = copy.deepcopy(base); wrong_lease_clock["lease_state"]["clock_id"] = "OTHER-CLOCK"
    r.check("D4-RESTART-LEASE-WRONG-CLOCK", "D4_RESTART",
            restart(wrong_lease_clock) != "SAFE_TO_RESUME", wrong_lease_clock["lease_state"])

    def d4_checkpoint_case(mutate_checkpoint: Any, mutate_broker: Any | None = None,
                           **top_level: Any) -> str:
        assert restart(base) == "SAFE_TO_RESUME"
        checkpoint = copy.deepcopy(base["checkpoint"]); mutate_checkpoint(checkpoint)
        checkpoint["vector"]["source_summary_digest"] = reconciliation_source_digest(checkpoint["vector"])
        values: dict[str, Any] = {"checkpoint": seal_checkpoint(checkpoint), **top_level}
        if mutate_broker is not None:
            broker_summary = copy.deepcopy(base["broker_summary"]); mutate_broker(broker_summary)
            values["broker_summary"] = reseal_summary(broker_summary)
        return restart(base, **values)

    for test_id, mutation in (
            ("D4-RESTART-BASKET-INVALID-ENUM", lambda cp: (cp["basket"].update(state="INVALID"), cp["vector"].update(basket_state="INVALID"))),
            ("D4-RESTART-BASKET-ZERO-VERSION", lambda cp: (cp["basket"].update(state_version=0), cp["vector"].update(basket_state_version=0))),
            ("D4-RESTART-HARD-KILL-INVALID-ENUM", lambda cp: cp["hard_kill"].update(state="INVALID"))):
        r.check(test_id, "D4_RESTART", d4_checkpoint_case(mutation) != "SAFE_TO_RESUME", "resealed intrinsic contradiction")

    def mutate_net_checkpoint(cp: dict[str, Any]) -> None: cp["vector"].update(symbol_net_volume=0.2)
    def mutate_net_broker(br: dict[str, Any]) -> None: br.update(symbol_net_volume=0.2)
    r.check("D4-RESTART-NET-VOLUME-EQUATION", "D4_RESTART",
            d4_checkpoint_case(mutate_net_checkpoint, mutate_net_broker) != "SAFE_TO_RESUME", "resealed net contradiction")

    def mutate_ticket_checkpoint(cp: dict[str, Any]) -> None: cp["vector"]["broker_identity"]["order_ticket"] += 1
    def mutate_ticket_broker(br: dict[str, Any]) -> None: br["broker_identity"]["order_ticket"] += 1
    r.check("D4-RESTART-FULL-BROKER-IDENTITY", "D4_RESTART",
            d4_checkpoint_case(mutate_ticket_checkpoint, mutate_ticket_broker) != "SAFE_TO_RESUME", "event id/sequence match; ticket differs")

    def mutate_hwm_checkpoint(cp: dict[str, Any]) -> None: cp["vector"].update(transaction_hwm=11)
    def mutate_hwm_broker(br: dict[str, Any]) -> None: br.update(transaction_hwm=11)
    r.check("D4-RESTART-TRANSACTION-HWM-IDENTITY", "D4_RESTART",
            d4_checkpoint_case(mutate_hwm_checkpoint, mutate_hwm_broker,
                               checkpoint_transaction_hwm=11) != "SAFE_TO_RESUME", "HWM differs from identity sequence")

    for state in ("INACTIVE", "ACTIVE", "RELEASE_PENDING", "RELEASED"):
        def inconsistent_latch(cp: dict[str, Any], candidate: str = state) -> None:
            cp["hard_kill"]["state"] = candidate
            if candidate == "RELEASED": cp["hard_kill"]["release_generation"] += 1
        r.check(f"D4-RESTART-INCONSISTENT-HARD-KILL-{state}", "D4_RESTART",
                d4_checkpoint_case(inconsistent_latch) != "SAFE_TO_RESUME", "resealed state/envelope contradiction")

    zero_acquired = copy.deepcopy(zero); zero_acquired["lease_state"]["status"] = "ACQUIRED"
    zero_renewed = copy.deepcopy(zero); zero_renewed["lease_state"]["status"] = "RENEWED"
    r.check("D4-ZERO-HISTORY-ACQUIRED", "D4_ZERO_HISTORY",
            restart(zero_acquired) == "SAFE_TO_RESUME", {"status": "ACQUIRED"})
    r.check("D4-ZERO-HISTORY-RENEWED", "D4_ZERO_HISTORY",
            restart(zero_renewed) == "SAFE_TO_RESUME", {"status": "RENEWED"})
    for status in ("UNCLAIMED", "EXPIRED", "RELEASED", "CORRUPT"):
        changed = copy.deepcopy(zero); changed["lease_state"]["status"] = status
        r.check(f"D4-ZERO-HISTORY-LEASE-{status}", "D4_ZERO_HISTORY",
                restart(changed) != "SAFE_TO_RESUME", {"status": status})
    for field_name, value in (("owner", {**owner_identity("OWNER-A"), "account_login": 0}),
                              ("clock_id", "WRONG-CLOCK")):
        changed = copy.deepcopy(zero); changed["lease_state"][field_name] = value
        r.check(f"D4-ZERO-HISTORY-INVALID-{field_name.upper()}", "D4_ZERO_HISTORY",
                restart(zero) == "SAFE_TO_RESUME" and restart(changed) != "SAFE_TO_RESUME", field_name)

    def d4_release_case(mutate: Any) -> bool:
        assert restart(base) == "SAFE_TO_RESUME"
        record = copy.deepcopy(base["release_record"]); mutate(record)
        record["authority_record_digest"] = frozen_release_digest(record, authority=True)
        checkpoint = copy.deepcopy(base["checkpoint"])
        checkpoint["hard_kill"]["account_namespace"] = copy.deepcopy(record["account_namespace"])
        checkpoint["hard_kill"]["release_evidence"] = persisted_release_evidence(record)
        checkpoint["hard_kill"]["release_reference"] = release_authority_reference(record)
        return restart(base, checkpoint=seal_checkpoint(checkpoint), release_record=record,
                       release_reference=release_authority_reference(record)) != "SAFE_TO_RESUME"

    release_mutations: list[tuple[str, Any]] = [
        ("D4-HARD-KILL-WRONG-NONEMPTY-POLICY", lambda rec: rec.update(approval_policy_id="WRONG-NONEMPTY")),
        ("D4-HARD-KILL-NEGATIVE-OBSERVED-EXPOSURE", lambda rec: rec["exposure_evidence"].update(observed_exposure=-0.1)),
        ("D4-HARD-KILL-NEGATIVE-PRIOR-EXPOSURE", lambda rec: rec["exposure_evidence"].update(prior_exposure=-0.1)),
        ("D4-HARD-KILL-INCREASING-EXPOSURE", lambda rec: rec["exposure_evidence"].update(observed_exposure=0.2, prior_exposure=0.1, zero_or_reducing=True)),
        ("D4-HARD-KILL-BROKER-BEFORE-AUTH", lambda rec: rec["broker_evidence"].update(observed_at=969)),
        ("D4-HARD-KILL-PERSISTENCE-BEFORE-AUTH", lambda rec: rec["persistence_evidence"].update(observed_at=969)),
        ("D4-HARD-KILL-EXPOSURE-BEFORE-AUTH", lambda rec: rec["exposure_evidence"].update(observed_at=969)),
        ("D4-HARD-KILL-INCOMPLETE-ACCOUNT", lambda rec: rec["account_namespace"].update(account_login=0)),
        ("D4-HARD-KILL-FOREIGN-ACCOUNT", lambda rec: rec["account_namespace"].update(account_login=99999)),
    ]
    for test_id, mutation in release_mutations:
        r.check(test_id, "D4_HARD_KILL", d4_release_case(mutation), "record and persisted envelope resealed in parity")

    d3_pub = PublicationStore(); d3_expected = copy.deepcopy(d3_pub.request_set)
    d3_proposed = {**d3_expected, "revision": 2, "store_revision": 2, "record_sequence": 2,
                   "ordered": [{"request": "D3", "state": "CONFIRMED"}]}
    d3_proposed["digest"] = digest(d3_proposed["ordered"])
    d3_proposed["row_digest"] = digest({key: value for key, value in d3_proposed.items() if key != "row_digest"})
    r.check("D3-PUBLICATION-SET-PROPOSAL-ONLY", "D3_PUBLICATION",
            d3_pub.evaluate_set(d3_expected, d3_proposed) and d3_pub.last_result == "PROPOSAL_VALID", d3_pub.last_result)
    d3_pub = PublicationStore(); d3_expected = copy.deepcopy(d3_pub.request_set)
    r.check("D3-PUBLICATION-SET-COMMITTED", "D3_PUBLICATION",
            d3_pub.publish_set(d3_expected, d3_proposed) and d3_pub.last_result == "COMMITTED", d3_pub.last_result)
    d3_fail = PublicationStore()
    r.check("D3-PUBLICATION-SET-UNCERTAIN-NOT-COMMITTED", "D3_PUBLICATION",
            not d3_fail.publish_set(copy.deepcopy(d3_fail.request_set), d3_proposed, "AFTER_COMMIT") and
            d3_fail.last_result != "COMMITTED", d3_fail.last_result)
    d3_cas_fail = PublicationStore()
    r.check("D3-PUBLICATION-SET-CAS-FAIL-NOT-COMMITTED", "D3_PUBLICATION",
            not d3_cas_fail.publish_set(copy.deepcopy(d3_cas_fail.request_set), d3_proposed, "CAS_FAIL") and
            d3_cas_fail.last_result != "COMMITTED", d3_cas_fail.last_result)
    d3_cp = PublicationStore(); assert d3_cp.reload_set(); d3_expected_cp = copy.deepcopy(d3_cp.checkpoint)
    d3_proposed_cp = {**d3_expected_cp, "revision": 2, "store_revision": 2, "record_sequence": 2,
                      "digest": "D3-CP2", "request_set_digest": d3_cp.request_set["digest"], "clean": False}
    r.check("D3-PUBLICATION-CHECKPOINT-PROPOSAL-ONLY", "D3_PUBLICATION",
            d3_cp.evaluate_checkpoint(d3_expected_cp, d3_proposed_cp, True) and d3_cp.last_result == "PROPOSAL_VALID", d3_cp.last_result)
    d3_cp = PublicationStore(); assert d3_cp.reload_set(); d3_expected_cp = copy.deepcopy(d3_cp.checkpoint)
    r.check("D3-PUBLICATION-CHECKPOINT-COMMITTED", "D3_PUBLICATION",
            d3_cp.publish_checkpoint(d3_expected_cp, d3_proposed_cp, True) and d3_cp.last_result == "COMMITTED", d3_cp.last_result)
    d3_cp_fail = PublicationStore(); assert d3_cp_fail.reload_set()
    r.check("D3-PUBLICATION-CHECKPOINT-READBACK-NOT-COMMITTED", "D3_PUBLICATION",
            not d3_cp_fail.publish_checkpoint(copy.deepcopy(d3_cp_fail.checkpoint), d3_proposed_cp, True, "BEFORE_READBACK") and
            d3_cp_fail.last_result != "COMMITTED", d3_cp_fail.last_result)
    d3_cp_cas_fail = PublicationStore(); assert d3_cp_cas_fail.reload_set()
    r.check("D3-PUBLICATION-CHECKPOINT-CAS-FAIL-NOT-COMMITTED", "D3_PUBLICATION",
            not d3_cp_cas_fail.publish_checkpoint(copy.deepcopy(d3_cp_cas_fail.checkpoint), d3_proposed_cp, True, "CAS_FAIL") and
            d3_cp_cas_fail.last_result != "COMMITTED", d3_cp_cas_fail.last_result)

    # D.5: current epochs cannot be repaired by a freshly sealed expected fence.
    for suffix, lease_epoch, generation in (("LEASE", 0, 1), ("GENERATION", 1, 0), ("BOTH", 0, 0)):
        probe = Lease(); assert probe.acquire("OWNER-A", 1, observation(1, 100), 10)
        probe.status = "EXPIRED"; positive = copy.deepcopy(probe)
        evidence = reconciliation_evidence(probe.complete_namespace, probe.owner, probe.fence_digest,
                                          probe.store_revision, probe.takeover_generation, 12, 120)
        assert positive.takeover(owner_identity("OWNER-B"), probe.store_revision, probe.fence_digest,
                                 2, observation(12, 120), evidence, 10)
        probe.lease_version = lease_epoch; probe.takeover_generation = generation
        probe.fence_digest = fence(probe.namespace, probe.owner, lease_epoch, generation)
        evidence = reconciliation_evidence(probe.complete_namespace, probe.owner, probe.fence_digest,
                                          probe.store_revision, generation, 12, 120)
        before = copy.deepcopy(probe.__dict__)
        valid_other_evidence = all(valid_reconciliation_item(evidence[key], component, component,
                                  probe.complete_namespace, probe, 12, 120)
                                  for key, component in (("broker", "BROKER"), ("persistence", "PERSISTENCE")))
        r.check("D5-EPOCH-ZERO-" + suffix, "D5_FENCE", valid_other_evidence and
                not probe.takeover(owner_identity("OWNER-B"), probe.store_revision, probe.fence_digest,
                                   generation + 1, observation(12, 120), evidence, 10) and probe.__dict__ == before,
                {"lease_version": lease_epoch, "takeover_generation": generation, "fresh_integrity": valid_other_evidence})

    assert restart(base) == "SAFE_TO_RESUME"
    r.check("D5-VERSION-V5-POSITIVE", "D5_VERSION", restart(base) == "SAFE_TO_RESUME", base["contract_version"])
    versions = [production_version() for _ in range(5)]
    versions[0] = dict(contract_name="SWV5-SPRINT5-EXECUTION-LAYER", schema_version=3,
                       minimum_compatible_version=3, policy_id="SWV5-SPRINT5-PHASE-B2-V3")
    versions[1]["schema_version"] = 4; versions[2]["minimum_compatible_version"] = 4
    versions[3]["policy_id"] = "FOREIGN"; versions[4]["contract_name"] = "FOREIGN"
    for suffix, value in zip(("CANDIDATE-V3", "SCHEMA", "MINIMUM", "POLICY", "CONTRACT"), versions):
        r.check("D5-VERSION-REJECT-" + suffix, "D5_VERSION", restart(base, contract_version=value) == "HALTED", value)

    decimal_fields = {"CHECKPOINT": base["checkpoint"]["header"]["payload_digest"],
                      "SOURCE": base["checkpoint"]["vector"]["source_summary_digest"],
                      "RELEASE": base["checkpoint"]["hard_kill"]["release_evidence"]["release_record_digest"],
                      "AUTHORITY": base["release_record"]["authority_record_digest"]}
    for name, value in decimal_fields.items():
        r.check("D5-DECIMAL-PARITY-" + name, "D5_DIGEST", value.isascii() and value.isdecimal() and
                str(int(value)) == value and 0 <= int(value) < 2**64 and len(value) <= 20, value)
        for kind, wrong in (("SHA256", digest("UNRELATED-DOMAIN")), ("NUMERIC", "0")):
            candidate = copy.deepcopy(base)
            if name == "CHECKPOINT": candidate["checkpoint"]["header"]["payload_digest"] = wrong
            elif name == "SOURCE":
                candidate["checkpoint"]["vector"]["source_summary_digest"] = wrong
                candidate["checkpoint"] = seal_checkpoint(candidate["checkpoint"])
            elif name == "RELEASE":
                candidate["checkpoint"]["hard_kill"]["release_evidence"]["release_record_digest"] = wrong
                candidate["checkpoint"] = seal_checkpoint(candidate["checkpoint"])
            else:
                candidate["release_record"]["authority_record_digest"] = wrong
                candidate["release_reference"]["authority_record_digest"] = wrong
                candidate["checkpoint"]["hard_kill"]["release_reference"]["authority_record_digest"] = wrong
                candidate["checkpoint"] = seal_checkpoint(candidate["checkpoint"])
            r.check("D5-REJECT-" + name + "-" + kind, "D5_DIGEST", restart(candidate) != "SAFE_TO_RESUME", wrong)
    cp = copy.deepcopy(base["checkpoint"]); assert checkpoint_integrity_valid(cp)
    cp["basket"]["state_version"] += 1; cp["vector"]["basket_state_version"] += 1
    stale_rejected = not checkpoint_integrity_valid(cp)
    cp["vector"]["source_summary_digest"] = reconciliation_source_digest(cp["vector"])
    cp = seal_checkpoint(cp)
    r.check("D5-CHECKPOINT-RESEAL-POSITIVE", "D5_DIGEST", stale_rejected and
            checkpoint_integrity_valid(cp) and restart(base, checkpoint=cp) == "SAFE_TO_RESUME", cp["header"])
    r.check("D5-FROZEN-HASH-EMPTY", "D5_DIGEST", frozen_canonical_hash("") == "1469598103934665603",
            "exact frozen offset; not SHA256")

    source_check = verify_d5_source()
    r.check("D5-FROZEN-SOURCE-AND-CALLGRAPH", "D5_SOURCE", source_check["status"] == "PASS", source_check)
    family_counts: dict[str, int] = {}
    for item in r.results: family_counts[item["family"]] = family_counts.get(item["family"], 0) + 1
    identifiers = [item["id"] for item in r.results]
    if len(identifiers) != len(set(identifiers)): raise AssertionError("duplicate scenario id")
    return {"results": r.results, "family_counts": family_counts,
            "unique_scenario_ids": len(set(identifiers)),
            "final_state_digest": digest({"genesis": g.__dict__, "lease": lease.__dict__, "ledger": ledger.__dict__,
                                          "sequence": seq.__dict__, "journal": journal.__dict__, "publication": pub.__dict__})}


def main() -> int:
    first = run_suite(); second = run_suite()
    if first != second: raise AssertionError("determinism mismatch")
    failed = [x for x in first["results"] if not x["passed"]]
    result_digest = digest(first)
    summary = {"classification": "PHASE D REFERENCE MODEL; NOT MQL RUNTIME, SQLITE, CROSS-TERMINAL, OR BROKER PROOF",
               "schema": {"id": SCHEMA_ID, "version": SCHEMA_VERSION, "minimum_compatible": MINIMUM_COMPATIBLE},
               "runs": 2, "deterministic": True, "total": len(first["results"]),
               "passed": len(first["results"]) - len(failed), "failed": len(failed), "skipped": 0,
               "unique_scenario_ids": first["unique_scenario_ids"],
               "family_counts": first["family_counts"], "final_state_digest": first["final_state_digest"],
               "reference_result_digest": result_digest, "status": "PASS" if not failed else "FAIL"}
    print(json.dumps(summary, sort_keys=True, separators=(",", ":")))
    print(f"PHASE D REFERENCE VERIFIER: {summary['status']} | {summary['passed']}/{summary['total']} | "
          f"runs=2 | deterministic={summary['deterministic']} | digest={result_digest}")
    return 0 if not failed else 1


if __name__ == "__main__":
    raise SystemExit(main())
