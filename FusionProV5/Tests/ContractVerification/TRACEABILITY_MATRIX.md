# Sprint 4.6 Phase E1 V4 Candidate Verification Traceability Matrix

> TEST ONLY - NOT FOR PRODUCTION - NO BROKER ACCESS

| Requirement | Contract field/interface | Executable IDs | Material evidence |
|---|---|---|---|
| Contract compatibility and deterministic output | Version policy and validation context | COM-01–COM-06, COM-09–COM-12 | Exact/migration/rejection decisions; hostile preseed overwritten; invalid clocks/sequences fail closed |
| All 49 Basket transitions | `ValidateTransition`, state/version | BSM-01–BSM-49 | Independent pair table; allowed +1; same/forbidden stable |
| Recovery mutation and durable replay | Recovery evidence and accepted identity set | IFC-01–IFC-03, S44-16, S45BR-01–S45BR-10 | First mutation, exact no-op replay, canonical negative mutations, restart-restored replay |
| IDLE and close-completion invariants | Residual/live counts/query authority | BAS-06, XDM-04, XDM-12 | Missing evidence or residual exposure denies completion |
| Partial-close arithmetic | Partial-close evidence and Basket residual | BAS-03–BAS-05, EXE-11, IFC-27 | Coherent partial allowed; over-close rejected; returned residual remains managed |
| Acknowledgement cannot confirm | Transaction event kind/authority/phase | EXE-16, XDM-11, IFC-26, S45A-01–S45A-06 | Actual acknowledgement interface returns pending, no identity/money mutation, persisted restart not ready |
| Authoritative execution confirmation | `AcceptTransactionEvidence` | EXE-09–EXE-11, IFC-24–IFC-27, S44-17–S44-18, S45A-07–S45A-10 | Full/partial returned state, exact replay idempotency, conflicting fingerprint no mutation |
| Durable execution fingerprint | Canonical event/fingerprint index | S45F-01–S45F-02 | Eight material mutations conflict; identity survives persistence round trip |
| Retry policy and current typed proof | `EvaluateRetry`, Risk freshness evidence, normalization freshness evidence, exclusive authorization deadline | EXE-12, IFC-32, S46DR-01–S46DR-20 | Current canonical retry allows; each context/contract/fence/deadline/freshness/spec/Basket/budget/lifecycle/request mutation denies; evaluation does not mutate pending state |
| Complete restart readiness | Full ordered pending set, broker summary, Hard Kill | PER-05–PER-15, XDM-03, XDM-08, XDM-11, S44-01–S44-05 | Safe/reconcile/retry-forbidden/close-only/halted dispositions from actual set contents |
| Persistence header/payload integrity | Namespace, count, digest, revision, record sequence | PER-01–PER-04, PER-13–PER-15, S44-06–S44-09, S45DP-08–S45DP-12, S46CP-01–S46CP-20 | Foreign/corrupt/stale payloads reject before storage mutation; PER-02 retains a stale non-empty digest after a nested mutation |
| Durable collision-safe event identity | Typed length-prefix event encoding, fingerprint, ordered durable identity set | S46EI-01–S46EI-20 | Exact replay is stable, unseen older evidence is retained, conflicts/malformed payloads reject, and checkpoint round trip reconstructs the full ordered set |
| Persistence deep-copy round trip | Configure/Save/Load interfaces | IFC-33–IFC-36, PRT-01–PRT-11, S44-10–S44-11, S45DP-15–S45DP-16 | Field/order equality, caller isolation, replacement semantics, no stale latest summary |
| Canonical collision resistance | Typed length-prefixed serializer/digest helpers | S45DP-01–S45DP-07, S45DP-13–S45DP-14 | Adversarial delimiter/unicode/field changes differ; independent equal fixtures match |
| Ownership unclaimed acquisition | Claimant/key/CAS/clock bindings | OWN-01, S45BO-01–S45BO-10 | Complete acquired lease; invalid claims return field-equal observed lease |
| Same-owner heartbeat semantics | Immutable fence; mutable liveness/store revision | OWN-06, OWN-11, IFC-39, S44-21–S44-22, S45DO-01–S45DO-16, S45DO-32 | Returned-state heartbeat chain, stable authority fence, monotonic heartbeat/expiry/CAS revision, Risk auth remains valid |
| Typed takeover and stale-owner fencing | Takeover evidence/generation/authority | OWN-03–OWN-05, IFC-19–IFC-21, S44-23–S44-25, S45DO-17–S45DO-31, S45DO-33 | Complete takeover succeeds; every stale/malformed dimension rejects; old authorization invalidated |
| Ownership conflict/release | `DetectConflict`, `Release` | OWN-02, OWN-07–OWN-10, IFC-39–IFC-40 | Conflict identities exposed; stale release rejected; matching lease transitions RELEASED |
| Risk authorization construction | `Evaluate`, authorization DTO | IFC-09, S44-12, S45CR-01 | Complete independently asserted binding and coherent ALLOW state |
| Risk binding mutation resistance | `ValidateAuthorization` | RSK-02–RSK-16, IFC-10–IFC-13, S44-13–S44-15, S45CR-02–S45CR-29 | Every limits/account/mode/Basket/spec/term/money/Hard Kill/fence/identity/time mutation denies |
| Hard Kill release | Typed independent release evidence | RSK-11, IFC-22–IFC-23, XDM-10 | Complete independent release allows; self/incomplete/mismatched release denies |
| Derived unit policy | Operation semantics and directional rounding | UNT-01–UNT-10, IFC-14–IFC-18, S45CU-01–S45CU-20 | Caller flags cannot override; safe rounding material outputs; stale/wrong-side/freeze/stops/range fail closed |
| Statistics monetary completeness | Profit/commission/swap/fee/net | STA-02, STA-08, S44-19 | Actual accumulator changes every component; returned next state finalizes |
| Statistics durable deduplication | Identity set/revision/counts | STA-03–STA-04, STA-10–STA-12, IFC-29, S44-19–S44-20 | Unique and out-of-order mutate once; duplicate changes only duplicate counter |
| Cross-domain gate ordering | Unit/Risk/Persistence/Execution interfaces | XDM-01–XDM-12 | Coherent path succeeds; stale owner, Hard Kill, residual, restart, and spec failures close safely |
| Determinism | Complete inputs and returned DTOs | COM-05, S45CU-16, S45DP-13–S45DP-14 plus suite replay | Independent identical inputs produce identical material results and signatures |

Phase E1 adds `S46E1-01` through `S46E1-15` for typed fingerprint policy, exact one-to-one identity/fingerprint mapping, canonical order, deterministic classification, and fail-closed duplicate/conflicting/orphan/malformed/count/digest cases. `S46E1-16` through `S46E1-18` trace ambiguous mappings through checkpoint validation, save, configure, and load; `S46E1-19` preserves statistics one-count-only behavior; `S46E1-20` preserves execution exposure, residual, and event state on conflict.

The per-ID credibility category and mutation-resistance rationale are authoritative in `TEST_CREDIBILITY_MATRIX.md`.
