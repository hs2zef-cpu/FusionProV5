# ADR-022: Genesis Provisioning Authority

## Status

**Approved Candidate for new independent Sprint 5 Phase D0 review.**

This decision defines namespace bootstrap governance only. It does not authorize Phase D implementation, a provisioning utility, database code, runtime enablement, broker access, MT5 execution, production, live trading, Architecture Lock, or merge to `main`.

## Context

The approved Sprint 5 startup model forbids treating missing persistence as a clean state. Normal Execution cannot originate evidence that no positions, orders, requests, Hard Kill latch, or prior authority exists. ADR-006 also forbids restart, takeover, or new signals from clearing a Hard Kill latch. A separate deployment authority must therefore create a unique, fail-closed namespace genesis before ordinary host startup can begin reconciliation.

## Decision

### Sole provisioning authority

Genesis is issued by a deployment-controlled **Genesis Provisioning Authority** represented by existing authority types:

- component identity: `SWV5_COMPONENT_AUTHORITY_OPERATOR`;
- authority source: `SWV5_AUTHORITY_OPERATOR`;
- policy: `SWV5-SPRINT5-GENESIS-PROVISIONING-V1`;
- policy version: `1`;
- authenticated `SWV5_OperatorIdentity` or an independently provisioned authority-record reference;
- exact `SWV5_PersistenceNamespace` and ownership-namespace digest;
- authoritative creation clock observation compatible with ADR-021; and
- canonical typed length-prefixed SHA-256 content digest.

The runtime host, Persistence service, lease claimant, Signal producer, and Broker Adapter cannot issue or approve genesis. They may only validate and consume a completed provisioned record.

### Genesis identity

Physical schema identity is `SWV5-S5-STORE-SCHEMA-V1`, version `1`, minimum compatible version `1`. Genesis policy version is independently `1`.

`genesis_id` is the canonical domain-separated digest of:

- physical schema identity/version;
- genesis policy ID/version;
- complete persistence namespace;
- ownership namespace digest;
- provisioning authority record identity;
- authenticated operator/provisioning identity;
- genesis generation `1`;
- creation clock ID, authority, sequence, and timestamp; and
- digest of the complete intended initial domain manifest.

The genesis row starts at generation `1`, revision `1`. Its digest excludes only its own digest field. Every initialized domain row binds `genesis_id`, genesis generation, namespace, schema version, domain revision, and canonical content digest.

### Provisioning protocol

No global operational transaction is invented. Provisioning uses a dedicated genesis state machine:

1. one CAS inserts the unique genesis identity as `PROVISIONING` only when no genesis or operational row exists for the namespace;
2. each independent authority domain is initialized in its own transaction and bound to the same manifest;
3. authoritative readback validates every required domain identity, empty-set digest, revision, and linkage;
4. one final genesis CAS changes `PROVISIONING` to `READY_FOR_RECONCILIATION` with the complete manifest digest.

The transition does not make runtime eligible. A crash before the final CAS leaves a partial `PROVISIONING` namespace that is preserved, disabled, and requires operator intervention. Normal runtime never completes, repairs, deletes, or overwrites partial genesis.

### Fail-closed initial state

The initial state uses existing Production V5 and Phase B meanings without inventing a released or clean authority:

- **Namespace metadata:** exact V5 persistence namespace, schema identity, genesis identity, generation, and revision.
- **Hard Kill:** `SWV5_HARD_KILL_ACTIVE`, nonempty genesis latch ID, latch generation `1`, release generation `0`, activation reason `NAMESPACE_GENESIS_NOT_RECONCILED`, activation authority bound to the Genesis Provisioning Authority, and authoritative activation time. Release evidence/reference remains empty except for required version/namespace/latch binding. No `RELEASED` state exists at genesis.
- **Checkpoint:** an explicitly bootstrap-only `SWV5_PersistedCheckpoint` projection bound to genesis, with zero exposure/counts, `SWV5_BASKET_IDLE`, reconciliation state `SWV5_RECONCILIATION_STATE_REQUIRED`, Hard Kill generation `1`, empty request-set binding, zero accepted query high-watermarks, first store/record revision, and `clean_shutdown=false`.
- **Checkpoint authority rule:** the bootstrap projection is not an operational restart checkpoint and cannot satisfy ordinary runtime readiness. Fields that require prior authoritative broker history, including last-confirmed correlation, remain non-authoritative/empty under the genesis envelope rather than fabricating a broker event. After fresh reconciliation, the owning contracts must publish the first normal operational checkpoint through ordinary fenced publication.
- **Pending request set:** complete canonical empty ordered set, count `0`, deterministic empty digest, initial nonzero index/store revision, and no latest-pending summary.
- **Ingress Ledger:** complete canonical empty membership and record collections, high-watermark `0`, compaction generation `0`, initial revision, and deterministic empty digests in a genesis-disabled authority envelope. No producer authority is fabricated.
- **Request Sequence Authority:** empty correlation index, high-watermark `0`, initial allocator revision, and deterministic empty digest in a genesis-disabled authority envelope. First runtime reservation begins from that durable zero authority after ownership/readiness gates.
- **Submission Authority / Claim journal:** complete canonical empty journal with initial revision and digest. No permit, claim, or event-local grant exists.
- **Ownership/lease:** explicit physical unowned genesis state with `SWV5_LOCK_UNCLAIMED`; there is no fabricated `SWV5_OwnerIdentity` or valid downstream fence. The first separately authorized acquisition must CAS from this exact genesis state and create the first valid `SWV5_InstanceLease`/`SWV5_OwnershipFence`.

Genesis-domain envelopes exist because several operational DTOs require an owner, producer, or prior broker correlation. They never weaken those DTO validators or masquerade as operational authority. Their only permitted successor is an ordinary contract-valid record after ownership and fresh reconciliation.

### Zero-state reconciliation and Hard Kill release

`READY_FOR_RECONCILIATION` authorizes only startup reconciliation. The host must obtain a valid ownership lease and fresh complete authoritative query evidence for every mandatory Broker and Execution query domain. Missing, incomplete, stale, wrong-owner, or conflicting evidence is not safe.

Only complete reconciliation proving the expected zero state may publish the first normal fenced request set/checkpoint and advance the current session's reconciliation gate. `clean_shutdown` remains false because genesis is not an orderly prior shutdown. Normal increasing execution remains disabled while the genesis Hard Kill is active. Clearing it requires the independent ADR-006 release-authority workflow and complete current evidence; reconciliation alone does not manufacture release provenance.

### Idempotency and conflict

- Repeating the exact completed provisioning request with the same `genesis_id`, manifest digest, authority identity, and content returns the existing completed result idempotently without mutation.
- The same namespace or genesis identity with different content, authority, digest, generation, or policy is `CONFLICT / FAIL CLOSED`.
- Existing non-genesis operational state forbids provisioning.
- Partial `PROVISIONING` state is not automatically resumed or replaced, even by an identical request; operator diagnosis and an independently authorized recovery procedure are required.
- Delete-and-recreate, overwrite, namespace renaming, and generation reset are prohibited shortcuts.

### Corruption and versioning

Missing genesis is `NOT PROVISIONED`, never clean. Corrupt digest, partial domain set, linkage mismatch, incompatible schema/policy, impossible revision, foreign namespace, or unexpected operational row disables runtime and requires operator reconciliation/provisioning intervention. Evidence is preserved; no automatic repair or second genesis is allowed.

Only schema version `1` with minimum compatible version `1` and genesis policy version `1` is accepted for the Phase D reference model. Unsupported older/future versions fail closed. There is no silent downgrade or automatic destructive migration.

## Consequences

- Namespace absence cannot enable execution.
- Genesis is unique, explicit, auditable, and separate from normal orchestration.
- Initial Hard Kill is active and cannot be silently released.
- Initial checkpoint truthfully records unresolved startup and no clean shutdown.
- Fresh zero-state reconciliation and independent Hard Kill release are both required before increasing execution could ever become eligible.
- Phase D may later model this protocol with a deterministic fake store and fake clock only after independent D0 approval.
