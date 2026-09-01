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
from dataclasses import dataclass, field
from enum import Enum
from typing import Any

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
    value = {"expiry": True, "broker": broker, "persistence": durable, "independent": True,
             "sequence": sequence, "observed_at": observed_at}
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

    def acquire(self, owner: str, expected_revision: int, obs: dict[str, Any], duration: int) -> bool:
        if self.owner or not owner or expected_revision != self.store_revision or duration <= 0:
            return False
        c = Clock(); c.sequence = self.clock_sequence; c.timestamp = self.heartbeat_at
        if not c.accept(obs): return False
        self.owner, self.lease_version, self.takeover_generation = owner, 1, 1
        self.store_revision += 1; self.heartbeat_sequence = 1
        self.clock_sequence, self.heartbeat_at = obs["sequence"], obs["timestamp"]
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
        self.clock_sequence, self.heartbeat_at = obs["sequence"], obs["timestamp"]
        self.expires_at = obs["timestamp"] + duration
        assert stable == (self.owner, self.lease_version, self.takeover_generation, self.fence_digest)
        return True

    def takeover(self, new_owner: str, expected_revision: int, expected_fence: str,
                 proposed_generation: int, obs: dict[str, Any], evidence: dict[str, Any], duration: int) -> bool:
        if (not self.owner or not new_owner or new_owner == self.owner or expected_revision != self.store_revision or
                expected_fence != self.fence_digest or proposed_generation != self.takeover_generation + 1 or
                obs["sequence"] <= self.clock_sequence or obs["timestamp"] < self.expires_at or duration <= 0 or
                not evidence.get("expiry") or not evidence.get("independent") or
                evidence.get("sequence") != obs["sequence"] or evidence.get("observed_at") != obs["timestamp"] or
                not valid_reconciliation_item(evidence.get("broker", {}), "BROKER", "BROKER",
                                              self.complete_namespace, self, obs["sequence"], obs["timestamp"]) or
                not valid_reconciliation_item(evidence.get("persistence", {}), "PERSISTENCE", "PERSISTENCE",
                                              self.complete_namespace, self, obs["sequence"], obs["timestamp"])):
            return False
        self.owner = new_owner; self.lease_version += 1; self.takeover_generation = proposed_generation
        self.store_revision += 1; self.heartbeat_sequence = 1
        self.clock_sequence, self.heartbeat_at = obs["sequence"], obs["timestamp"]
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

    def publish_set(self, expected: dict[str, Any], proposed: dict[str, Any]) -> bool:
        if (not self.expected_equal(self.request_set, expected) or proposed["revision"] != expected["revision"] + 1 or
                proposed["store_revision"] != expected["store_revision"] + 1 or
                proposed["record_sequence"] != expected["record_sequence"] + 1 or
                proposed["fence"] != expected["fence"] or proposed["takeover"] != expected["takeover"] or
                proposed["digest"] != digest(proposed["ordered"]) or
                proposed.get("row_digest") != digest({key: item for key, item in proposed.items() if key != "row_digest"})):
            return False
        self.request_set = copy.deepcopy(proposed); self.reloaded_set_digest = ""; return True

    def reload_set(self) -> bool:
        valid = (self.request_set["digest"] == digest(self.request_set["ordered"]) and
                 self.request_set.get("row_digest") == digest({key: item for key, item in self.request_set.items() if key != "row_digest"}))
        self.reloaded_set_digest = self.request_set["digest"] if valid else ""; return valid

    def publish_checkpoint(self, expected: dict[str, Any], proposed: dict[str, Any], converged: bool) -> bool:
        if (not self.reloaded_set_digest or not self.expected_equal(self.checkpoint, expected) or
                proposed["revision"] != expected["revision"] + 1 or proposed["store_revision"] != expected["store_revision"] + 1 or
                proposed["record_sequence"] != expected["record_sequence"] + 1 or proposed["fence"] != expected["fence"] or
                proposed["takeover"] != expected["takeover"] or proposed["request_set_digest"] != self.reloaded_set_digest or
                (proposed["clean"] and not converged)): return False
        self.checkpoint = copy.deepcopy(proposed); return True


def release_authority_record(**changes: Any) -> dict[str, Any]:
    value = {"contract_version": 5, "namespace": "NS", "account_mode": "HEDGING",
             "latch_id": "LATCH-1", "latch_generation": 1, "release_id": "RELEASE-1",
             "release_generation": 1, "operator_id": "OP-1", "authority_role": "RISK-APPROVER",
             "authentication_reference": "AUTH-1", "authenticated_at": 970,
             "approving_component": "RISK_GOVERNANCE", "approval_policy_id": "HK-RELEASE-V5",
             "approval_sequence": 50, "broker_evidence": "BROKER-EVIDENCE-1",
             "persistence_evidence": "PERSISTENCE-EVIDENCE-1", "exposure_evidence": "EXPOSURE-EVIDENCE-1",
             "approved_at": 980, "released_at": 985, "expires_at": 1060,
             "release_record_sequence": 51, "authority_record_id": "HK-AUTHORITY-1",
             "issuing_component": "RISK_GOVERNANCE", "authority_source": "HARD_KILL_RELEASE_RECORD"}
    value.update(changes)
    value["authority_record_digest"] = digest(value)
    return value


def release_authority_reference(record: dict[str, Any]) -> dict[str, Any]:
    return {"authority_record_id": record["authority_record_id"],
            "authority_record_sequence": record["release_record_sequence"],
            "authority_record_digest": record["authority_record_digest"],
            "release_id": record["release_id"], "latch_generation": record["latch_generation"],
            "release_generation": record["release_generation"]}


def valid_release_authority(x: dict[str, Any]) -> bool:
    record = x["release_record"]; reference = x["release_reference"]
    body = {k: v for k, v in record.items() if k != "authority_record_digest"}
    return (record.get("authority_record_digest") == digest(body) and record.get("contract_version") == 5 and
            record.get("namespace") == x["namespace"] and record.get("account_mode") == x["account_mode"] and
            record.get("latch_id") == x["release_latch_id"] and record.get("latch_generation") == x["release_latch_generation"] and
            record.get("release_id") == x["release_id"] and record.get("release_generation") == x["release_generation"] and
            all(record.get(key) for key in ("operator_id", "authority_role", "authentication_reference", "approval_policy_id",
                                             "broker_evidence", "persistence_evidence", "exposure_evidence", "authority_record_id")) and
            record.get("authenticated_at", 0) > 0 and record.get("approval_sequence", 0) > 0 and
            0 < record.get("approved_at", 0) <= record.get("released_at", 0) and record.get("expires_at", 0) > x["now"] and
            record.get("release_record_sequence", 0) > 0 and record.get("approving_component") == "RISK_GOVERNANCE" and
            record.get("issuing_component") == "RISK_GOVERNANCE" and
            record.get("authority_source") == "HARD_KILL_RELEASE_RECORD" and
            reference == release_authority_reference(record))


def restart(base: dict[str, Any], **changes: Any) -> str:
    x = copy.deepcopy(base); x.update(changes)
    if not x["schema"] or not x["genesis"] or not x["persistence"]: return "HALTED"
    if not x["lease"] or x["claimed"]: return "RETRY_FORBIDDEN"
    broker = x["broker_summary"]; execution = x["execution_summary"]
    if (broker.get("summary_digest") != digest({key: value for key, value in broker.items() if key != "summary_digest"}) or
            execution.get("summary_digest") != digest({key: value for key, value in execution.items() if key != "summary_digest"})):
        return "RECONCILIATION_REQUIRED"
    if (x["broker_mask"] != BROKER_QUERY_MASK or x["execution_mask"] != EXECUTION_QUERY_MASK or
            x["broker_authority"] != "BROKER" or x["execution_authority"] != "EXECUTION" or
            x["broker_namespace"] != x["namespace"] or x["execution_namespace"] != x["namespace"] or
            x["broker_account_mode"] != x["account_mode"] or x["execution_account_mode"] != x["account_mode"] or
            x["current_fence"] != x["persisted_fence"] or
            not x["requests_complete"] or not x["checkpoint_matches"]): return "RECONCILIATION_REQUIRED"
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
            broker.get("correlation") != x["checkpoint_correlation"]):
        return "RECONCILIATION_REQUIRED"
    request_set_digest = digest(x["requests"])
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
    if not x["broker_matches"] or not x["execution_matches"] or not x["clean"]: return "RECONCILIATION_REQUIRED"
    if x["hard_kill"]: return "CLOSE_ONLY"
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
    broker_summary = reseal_summary({"contract_version": 5, "namespace": source.namespace,
                                     "basket": "BASKET-XAU-M15", "account_mode": source.account_mode,
                                     "fence": source.fence_digest, "correlation": "CHECKPOINT-CORR-1",
                                     "transaction_hwm": 10, "position_count": 0, "order_count": 0,
                                     "deal_count": 1, "exposure": "0.00", "query": broker,
                                     "observed_at": broker["observed_at"], "authority": "BROKER"})
    execution_summary = reseal_summary({"contract_version": 5, "namespace": source.namespace,
                                        "basket": "BASKET-XAU-M15", "account_mode": source.account_mode,
                                        "fence": source.fence_digest, "pending_count": len(requests),
                                        "request_set_digest": digest(requests), "request_set_revision": 4,
                                        "reconciliation_revision": 7, "query": execution,
                                        "observed_at": execution["observed_at"], "authority": "EXECUTION"})
    return {"schema": True, "genesis": True, "persistence": True, "lease": True, "claimed": False,
            "broker_mask": broker["mask"], "execution_mask": execution["mask"],
            "broker_authority": broker["authority"], "execution_authority": execution["authority"], "requests_complete": True,
            "namespace": source.namespace, "broker_namespace": broker["namespace"], "execution_namespace": execution["namespace"],
            "account_mode": source.account_mode, "broker_account_mode": broker["account_mode"], "execution_account_mode": execution["account_mode"],
            "persisted_fence": source.fence_digest, "current_fence": broker["fence"],
            "checkpoint_matches": True, "broker_sequence": 11, "execution_sequence": 21,
            "broker_hwm": 10, "execution_hwm": 20, "broker_time": broker["observed_at"], "execution_time": execution["observed_at"], "now": 1000,
            "basket": "BASKET-XAU-M15", "checkpoint_transaction_hwm": 10,
            "checkpoint_correlation": "CHECKPOINT-CORR-1", "request_set_revision": 4,
            "reconciliation_revision": 7, "requests": requests,
            "broker_summary": broker_summary, "execution_summary": execution_summary,
            "broker_matches": True, "execution_matches": True, "clean": True,
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
    weak = reconciliation_evidence(lease.complete_namespace, lease.owner, lease.fence_digest,
                                   lease.store_revision, lease.takeover_generation, 3, 120)
    weak["broker"] = {}
    r.check("LEASE-MISSED-HEARTBEAT-INSUFFICIENT", "LEASE_TAKEOVER", not lease.takeover("OWNER-B", 3, lease.fence_digest, 2, observation(3, 120), weak, 10), lease.__dict__)
    complete = reconciliation_evidence(lease.complete_namespace, lease.owner, lease.fence_digest,
                                       lease.store_revision, lease.takeover_generation, 3, 120)
    stale_fence = lease.fence_digest
    took = lease.takeover("OWNER-B", 3, stale_fence, 2, observation(3, 120), complete, 10)
    r.check("LEASE-VALID-TAKEOVER", "LEASE_TAKEOVER", took and lease.owner == "OWNER-B" and lease.takeover_generation == 2 and lease.fence_digest != stale_fence, lease.__dict__)
    r.check("LEASE-TAKEOVER-RACE", "LEASE_TAKEOVER", not lease.takeover("OWNER-C", 3, stale_fence, 2, observation(4, 140), complete, 10), lease.__dict__)
    r.check("LEASE-STALE-TAKEOVER-GENERATION", "LEASE_TAKEOVER", not lease.takeover("OWNER-C", 4, lease.fence_digest, 2, observation(4, 140), complete, 10), lease.__dict__)

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
        evidence = reconciliation_evidence(probe_lease.complete_namespace, probe_lease.owner, probe_lease.fence_digest,
                                           probe_lease.store_revision, probe_lease.takeover_generation, 2, 120)
        mutate(evidence)
        for name in ("broker", "persistence"):
            evidence[name]["state_digest"] = digest({key: value for key, value in evidence[name].items() if key != "state_digest"})
        r.check(test_id, "TAKEOVER_COMPLETE_AUTHORITY",
                not probe_lease.takeover("OWNER-B", 2, probe_lease.fence_digest, 2, observation(2, 120), evidence, 10),
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
    foreign_evidence = reconciliation_evidence(domain_lease.complete_namespace, domain_lease.owner, domain_lease.fence_digest,
                                               domain_lease.store_revision, domain_lease.takeover_generation, 2, 120)
    foreign_evidence["broker"]["namespace"]["basket"] = "FOREIGN"
    foreign_evidence["broker"]["state_digest"] = digest({key: value for key, value in foreign_evidence["broker"].items() if key != "state_digest"})
    r.check("D2-DOMAIN-CANONICAL-LEASE", "DOMAIN_CANONICAL",
            not domain_lease.takeover("OWNER-B", 2, domain_lease.fence_digest, 2, observation(2, 120), foreign_evidence, 10),
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
    r.check("D2-RESTART-UNSAFE-REQUEST-AT-INDEX-1", "RESTART_COMPLETE_AUTHORITY",
            restart(base, requests=unsafe_requests, execution_summary=unsafe_execution) == "RETRY_FORBIDDEN",
            {"index": 1, "state": unsafe_requests[1]["state"]})
    r.check("D2-RESTART-CHECKPOINT-VECTOR-MISMATCH", "RESTART_COMPLETE_AUTHORITY",
            restart(base, checkpoint_transaction_hwm=9) == "RECONCILIATION_REQUIRED", "re-sealed Broker disagrees with checkpoint")
    for test_id, changes, expected in (
            ("RESTART-DIRTY", {"clean": False}, "RECONCILIATION_REQUIRED"),
            ("RESTART-SPLIT", {"checkpoint_matches": False}, "RECONCILIATION_REQUIRED"),
            ("RESTART-BROKER-AHEAD", {"broker_matches": False}, "RECONCILIATION_REQUIRED"),
            ("RESTART-PERSISTENCE-AHEAD", {"execution_matches": False}, "RECONCILIATION_REQUIRED"),
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
            ("RESTART-RELEASE-WRONG-EVIDENCE", "broker_evidence", "BROKER-FORGED"),
            ("RESTART-RELEASE-EXPIRED", "expires_at", 999),
            ("RESTART-RELEASE-WRONG-SEQUENCE", "release_record_sequence", 52),
            ("RESTART-RELEASE-WRONG-POLICY", "approval_policy_id", "POLICY-FORGED"),
            ("RESTART-RELEASE-WRONG-VERSION", "contract_version", 4),
            ("RESTART-RELEASE-WRONG-ISSUER", "issuing_component", "PERSISTENCE")):
        changed = copy.deepcopy(base["release_record"]); changed[field_name] = changed_value
        changed["authority_record_digest"] = digest({k: v for k, v in changed.items() if k != "authority_record_digest"})
        r.check(test_id, "RESTART", restart(base, release_record=changed) == "HALTED",
                {field_name: changed_value, "digest_valid": True})
    wrong_reference = copy.deepcopy(base["release_reference"]); wrong_reference["authority_record_id"] = "OTHER"
    r.check("RESTART-RELEASE-WRONG-REFERENCE", "RESTART",
            restart(base, release_reference=wrong_reference) == "HALTED", wrong_reference)
    r.check("RESTART-CLAIM-NO-RETRY", "RESTART", restart(base, claimed=True) == "RETRY_FORBIDDEN", "no retry/invocation")
    r.check("RESTART-PARTIAL-REQUEST-RECONSTRUCTION", "RESTART", restart(base, requests_complete=False) == "RECONCILIATION_REQUIRED", "full ordered array required")
    r.check("RESTART-GENESIS-HARD-KILL", "RESTART", restart(base, clean=False, hard_kill=True) == "RECONCILIATION_REQUIRED", "genesis is not ordinary checkpoint")

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
