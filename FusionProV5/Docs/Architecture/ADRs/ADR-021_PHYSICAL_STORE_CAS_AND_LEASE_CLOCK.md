# ADR-021: Physical Store, Compare-And-Set, And Lease Clock

## Status

**APPROVED — New Independent Sprint 5 Phase D0 review PASS.**

This decision resolves a Phase D entry question. Separate governance authorizes only a deterministic fake-store/fake-clock Phase D reference implementation. This ADR does not authorize real MQL5 database code, MT5 Terminal or Strategy Tester execution, broker access, runtime wiring, production, live trading, Architecture Lock, or merge to `main`.

## Context

ADR-003, ADR-013 through ADR-015, ADR-017, ADR-018, and ADR-020 already define independent durable authorities, exact expected-current mutation, ownership fencing, crash uncertainty, and fail-closed behavior. The frozen Phase B contracts prepare pure proposals but deliberately do not supply a physical store. Phase D cannot start until one MT5-compatible technology can represent those semantics without inventing a global transaction or weakening compare-and-set.

Current official MQL5 documentation establishes these platform facts:

- the MQL5 Database API uses SQLite and exposes explicit begin, commit, and rollback operations;
- `DATABASE_OPEN_COMMON` locates a database file in the common folder of installed client terminals;
- SQLite transactions provide the relevant ACID model and preserve a consistent database state across interruption;
- `GlobalVariableSetOnCondition` is atomic only for interacting EAs within one client terminal;
- `TimeCurrent()` is the last-known server-formed quote time and does not depend on local computer settings; and
- `TimeTradeServer()` is calculated in the client terminal and depends on local computer time settings.

The official references are listed in the Phase D0 feasibility document. Common-folder visibility and SQLite transactional semantics justify selection as a candidate. Cross-terminal contention, lock behavior, commit uncertainty, and filesystem durability on supported terminal/build/filesystem combinations remain mandatory later platform evidence; they are not claimed as proven by this documentation task.

## Decision

### Selected technology

The physical-store candidate is **SQLite through the native MQL5 Database API**, opened read/write in the terminal common folder with `DATABASE_OPEN_COMMON`. The initial physical schema is `SWV5-S5-STORE-SCHEMA-V1`, schema version `1`, minimum compatible version `1`.

Each ownership namespace maps by canonical SHA-256 namespace digest to one shared relative database name:

`FusionProV5/Store/SWV5_<ownership-namespace-digest>.sqlite`

The digest preimage contains the exact canonical broker identity, server, account login, symbol, strategy ID, and magic. Basket-scoped rows additionally use the complete `SWV5_PersistenceNamespace` digest including Basket ID. Raw account credentials are not placed in the filename. Every terminal participating in the same authority namespace must resolve the same common-folder database. A different path, schema identity, or namespace digest is a conflict, not a fallback store.

### Authority separation

Logical storage categories remain separately identifiable and independently revised:

1. schema and namespace metadata;
2. genesis authority;
3. instance ownership lease and lease-clock observations;
4. Host Ingress Ledger;
5. Request Sequence Authority;
6. Submission Permit / Invocation Claim journal;
7. pending-request-set publication; and
8. checkpoint publication.

Producer Trust and credential storage remain deployment scope. A SQLite transaction may touch the rows needed for one owning domain only. No transaction may collapse Ledger, Sequence, request lifecycle, Submission Authority, request set, checkpoint, and lease into one architectural authority.

### Cross-terminal concurrency

All writers open the same common-folder database. SQLite file locking and transaction serialization are the sole cross-terminal writer-coordination candidate. Terminal Global Variables, in-process mutexes, timestamps, host queue order, and local files are not authority.

Busy/locked, begin failure, statement failure, read failure, rollback failure, commit failure, inaccessible common folder, unexpected schema, or uncertain lock state all fail closed. A caller may use bounded backoff only to retry a new observation; it may not preserve a stale expected revision or reinterpret uncertainty as success. Exhaustion disables the affected authority and requires reconciliation or operator action.

### Exact physical CAS

Every safety-bearing mutation follows this falsifiable pattern:

1. begin one SQLite transaction for exactly one authority domain;
2. read the authoritative row and all integrity-linked rows required by that domain;
3. validate schema, namespace, canonical digest, ownership fence, takeover generation where applicable, exact expected state, exact authority/store revision, and ordered membership/index linkage;
4. execute a conditional `INSERT` or `UPDATE` whose predicate repeats every expected-current field;
5. read the logical result inside the transaction and require exactly the proposed next state, revision, sequence, membership, and digest;
6. commit;
7. perform authoritative post-commit readback and canonical validation before reporting success.

Conceptually:

```sql
UPDATE authority_row
SET revision = :next_revision,
    state = :next_state,
    digest = :next_digest
WHERE namespace_key = :namespace_key
  AND revision = :expected_revision
  AND store_revision = :expected_store_revision
  AND fence_digest = :expected_fence_digest
  AND takeover_generation = :expected_takeover_generation
  AND state = :expected_state
  AND digest = :expected_digest;
```

The exact schema is deferred, but all listed predicates are mandatory when present in the owning contract. Because the MQL5 API does not provide a contract-level affected-row authority, the same transaction must authoritatively read and verify the resulting row. No change or any mismatch causes rollback. Larger revision, latest timestamp, last writer, and blind overwrite are never conflict resolution.

### Commit and crash semantics

- Crash or failure before the conditional mutation leaves the prior authority unchanged.
- Crash during an uncommitted transaction leaves no successful authority transition under the SQLite transaction model.
- Commit success followed by process death before caller observation creates an **uncertain outcome**. Restart/re-entry reads the authoritative row; it never blindly repeats the mutation.
- A successful API return without matching post-commit readback is uncertain and fails closed.
- A failed commit call is uncertain until authoritative readback distinguishes prior, exact proposed, or conflicting state.
- Exact proposed state may be recognized as already durable only where the owning contract defines idempotent replay. It never recreates an event-local privilege.

### Domain mappings

**Host Ingress Ledger.** The header, ordered index, complete records, revision, compaction generation, highest accepted publication sequence, and canonical digests are one Ledger-domain transaction. Duplicate identity with identical payload and sequence resolves idempotently; conflicting identity fails closed. Compaction atomically replaces only the Ledger domain after proving identical ordered logical membership. Corrupt data is retained for diagnosis; no partial-data rebuild or silent self-heal is allowed.

**Request Sequence Authority.** One namespace-wide authority row and canonical correlation-to-sequence index are one Sequence-domain transaction. A new correlation conditionally advances allocator revision and high-watermark once. The same correlation and binding returns the same sequence; a different binding conflicts. Different correlations receive unique increasing sequences. A committed reservation is never recycled, so crash before Ledger binding may leave a permanent allowed gap.

**Submission / Invocation Claim.** One Submission Authority journal row per exact permit/request/attempt transitions by CAS from `SWV5S5_COMMITTED_NOT_INVOKED` to `SWV5S5_INVOCATION_CLAIMED_UNRESOLVED`. Exactly one transaction winner may receive `CLAIM_GRANTED_NOW` in the committing event. Persisted claimed state, post-commit readback, restart, or takeover never recreates that grant. Crash after commit is uncertain and requires authoritative reconciliation without blind broker retry.

**Pending request set.** `CompareAndPublishPendingRequestSet()` compares namespace, exact set revision/digest, store/publication revision, record sequence, ownership fence, takeover generation, and proposed next revision/sequence. One Request-Set-domain transaction publishes the complete ordered set and complete digest. A stale host cannot overwrite it.

**Checkpoint.** `CompareAndPublishCheckpoint()` compares namespace, exact checkpoint/store revision, prior record sequence, complete current projection digest, ownership fence, and takeover generation. One Checkpoint-domain transaction publishes the exact proposed checkpoint identity, payload, digest, next sequence, and new store revision. A stale host cannot overwrite it.

Request-set publication remains ordered before authoritative reload/canonical validation, which remains ordered before checkpoint publication. Failure between them is `DIRTY / UNRESOLVED`, revokes runtime eligibility, and never implies the missing write succeeded. Only an orderly converged shutdown may later publish `clean_shutdown=true`.

### Lease record and takeover

The physical lease row preserves ADR-003 exactly.

Immutable ownership authority comprises owner identity, ownership namespace, `lease_version`, `takeover_generation`, and fencing-token digest. Mutable lease-record CAS comprises `store_revision`, heartbeat sequence/time/clock sequence, and expiry.

An ordinary same-owner heartbeat conditionally compares the exact current lease row, advances store revision and heartbeat evidence, extends expiry, and preserves the complete `SWV5_OwnershipFence`. It therefore does not invalidate current Risk Authorization, pending requests, Basket ownership, or Execution binding.

Takeover conditionally compares the exact stale row and requires matching typed lease-expiry evidence plus independent broker and persistence reconciliation evidence. It advances lease version according to ownership policy, takeover generation, owner, fence digest, and store revision. Missed heartbeat alone is not takeover authority. One CAS winner acquires; every stale claimant fails.

### Authoritative lease clock

The production clock candidate is a platform Clock Adapter observation of **`TimeCurrent()`**, not an arbitrary direct call by domain code.

- Clock ID: `SWV5-MQL5-TIMECURRENT-LAST-KNOWN-SERVER-V1/<broker>/<server>/<account>/<symbol>`.
- Contract authority: `SWV5_TIME_AUTHORITY_BROKER_SERVER`.
- Source boundary: `TimeCurrent()` sampled inside the currently handled `OnTick` event for the exact ownership-namespace symbol, with that event's source symbol and monotonic platform-observation identity recorded. A later real adapter must reject cached reads from `OnTimer`, initialization, or unrelated symbols as lease-expiry evidence.
- Durable ordering: a separate lease-clock row uses an exact DB CAS to advance an observation revision and `clock_sequence` for every accepted platform observation.
- Timestamp rule: accepted time must be positive and not less than the prior accepted time. Regression fails closed.
- Equal seconds: a distinct proven current-symbol `OnTick` observation may advance `clock_sequence` while retaining the same timestamp; it cannot prove that wall time moved beyond that second or manufacture expiry.
- Expiry: takeover requires a fresh accepted server observation whose timestamp satisfies the lease expiry predicate and whose sequence is later than the lease evidence it evaluates.
- Restart: reload the clock row, then require a new current server observation before takeover or increasing admission that depends on current liveness. Stored time alone does not prove present time.

No new server observation means no proof that expiry advanced. Invalid, absent, regressed, wrong-authority, cached/stale beyond the approved platform-observation policy, or unverifiable time means no takeover, no increasing admission requiring current lease liveness, and reconciliation/operator action. `TimeTradeServer`, `TimeLocal`, local UTC, `GetTickCount`, queue ordinal, and database revision are prohibited substitutes.

### Global Variables classification

`GlobalVariableSetOnCondition` is permitted only as a non-authoritative optimization or same-terminal convenience mutex. Official documentation limits its mutex guarantee to EAs within one client terminal. It cannot be the sole durable store, cross-terminal ownership authority, CAS token, lease clock, or recovery truth.

### Corruption, schema, and failure policy

Every row carries exact schema identity, namespace key, logical revision, domain digest, and linkages needed by its authority. A corrupt digest, header/index mismatch, impossible sequence, partial membership, unknown row kind, schema mismatch, or namespace collision is preserved and fails closed. No destructive or automatic migration is allowed.

Schema version `1` accepts only minimum-compatible version `1`. Future or older unsupported versions fail closed as incompatible; no silent downgrade exists. A separately reviewed migration would require new policy and evidence.

## Rejected alternatives

- **Terminal Global Variables:** same-terminal visibility and atomic conditional set are insufficient for cross-terminal authority, typed durable records, transactions, and corruption linkage.
- **Raw/common files with move/rename:** common visibility exists, but the native MQL5 evidence reviewed does not establish a cross-terminal multi-row conditional transaction, compare-and-set, or portable crash-safe rename protocol adequate for these authorities.
- **Per-terminal files or memory:** not shared and cannot fence competing terminals.
- **External service/database:** potentially feasible but adds network, authentication, availability, deployment, and new trust boundaries outside the approved native MT5-safe D0 scope.

## Required later evidence

Before any real adapter approval, supported MetaTrader build and filesystem combinations must prove two-terminal contention, one-winner conditional mutation, busy handling, transaction rollback, crash recovery, commit-uncertainty readback, common-folder identity, corruption detection, and current-event clock provenance. Failure of that evidence blocks the real adapter; it does not permit contract weakening.

## Consequences

- SQLite/MQL5 is selected as a concrete physical-store candidate with explicit limitations.
- Physical CAS is exact, testable, and fail closed.
- Domain ownership and independent transactions remain unchanged.
- The lease clock uses server-formed last-known observations without trusting local time.
- Phase D may later model these semantics against a fake store and fake clock only after independent D0 approval.
