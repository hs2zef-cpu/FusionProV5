# Controlled Demo attended launch integration

Implementation/offline-verification scope only. This document does **not** authorize actual D1, OrderSend, D3, real-exposure D6, Phase G, live trading, or a main merge. Fusion owns the separate actual-D1 gate. Frozen Phase B–F DTOs/policy, Signal Engine and DecisionEngine are unchanged.

## Dependency disposition

| Class | Disposition |
| --- | --- |
| A — existing accepted implementations | SQLite/CAS/readback, Genesis, Ownership/lease clock, Producer Trust, Hard Kill release/activation, canonical Account and Basket, coherent Account Observation, Unit/Margin/Basket Risk/Risk, Sequence/Ledger/RequestSet, Permit/Admission/Claim, Governance/Pin/Vector, Broker evidence, independent Execution pending query, Phase F reconciliation/terminalization, frozen Orchestrator/DecisionEngine. |
| B — mechanical launch binding | Native host, physical read-only seed projection, shared synchronous dispatch, fresh-session acknowledgement/one-shot, explicit administrative wrapper, observational callback binding, ignored evidence diagnostics and immutable-build identity. Native MT5 account-margin enums require explicit translation into the different frozen contract enum values. |
| C — unresolved semantic amendment | None established by the implementation/rehearsal. A missing physical prerequisite fails closed; it is not an excuse to invent an authority or relax a validator. |

Canonical Account closure commit: `3d0224e7a0d8bd42a0b9eec91e8bdf3f8c048dd7`, parent `03bc0b3927036ce6a64264421153898282b3fe1b`. Its authority token remains epoch/sequence 1/1 across financial observations; a single captured observation envelope per D1 preparation binds Margin, Basket Risk and Risk. Read-only preflight is a separate observation event.

## Build and graph

Run `Build-AttendedLaunch.ps1` from a clean immutable source commit before an attended launch. It generates an **ignored** build header from full Git HEAD plus clean-tree status and compiles the native runner with MetaEditor X64 Regular. Non-preflight dirty builds fail closed. Re-run the build after committing: a previously compiled dirty binary does not become authorized merely because Git later became clean. The setup wrappers use the same generated identity; compile them again after the clean-source metadata generation. Build metadata is evidence, never Risk/Claim authority.

The native `.mq5` constructs `MvpAttendedLaunch`. This constructs native read-only platform, actual Orchestrator, SQLite-backed Authority Port and Broker Evidence Store, native BrokerPlatformAdapter, independent recovery read bridge, controlled Broker boundary and Runner. `OnTick` calls the host; the shared dispatch builds the seed from physical owners and calls `runner.Run` on one synchronous stack. No test provider/import belongs to this native graph.

The sole permitted production OrderSend site remains BrokerPlatformBoundary. The adapter's submission body, final permission/profile/spec sample, wire digest/filling mapping and no-retry behavior are untouched. The boundary diff is exhaustively checked to allow only native enum conversion and its read-only environment accessor.

## Explicit setup order — for a later authorized attended session

1. Verify the locked XAUUSD / Demo / Hedging / USD profile, exact broker/server/login and immutable clean build. Never change account/server/settings/Algo Trading to make a gate pass.
2. Configure the Manual Setup executable with accepted operator-role/authentication reference, exact namespace, claimant identity, lease duration, basket/producer scope and approved Trust Anchor. `InpIngressIdentity` is retained for compatibility but is not used to fabricate a future ingress: ingress is derived from actual Decision publication. `InpOperatorAuthenticatedAt` is retained but cannot supply a saved event timestamp. All mutating defaults are false. A fresh **A key** acknowledgement arms only this launch; the next current XAUUSD tick consumes its latch before clock/Genesis/Ownership/Account/Trust writes. Genesis Hard Kill remains ACTIVE.
3. Use the separate `SAFETY_RELEASE_ONLY` administrative action with explicit confirmation and a fresh A acknowledgement. It consumes current physical lease/Account and independently observed native Broker + physical Persistence/Exposure zero-state; persists Bootstrap Zero; invokes independent Risk-Governance release; CAS/readback of ACTIVE → RELEASE_PENDING → RELEASED → new canonical INACTIVE epoch. It cannot submit.
4. Separately use `GOVERNANCE_AND_INITIAL_BASKET`. Prior physical INACTIVE release is required **before** governance provisioning. Approved correlation capability remains true; query-completeness and watermark capability remain false, visibility lag zero. Initialize the accepted empty RequestSet, then let the canonical Basket owner independently verify zero-state and create initial flat Basket. D1 never provisions Governance.
5. MODE_PREFLIGHT has all arming flags false. It opens authority/clock storage read-only, validates complete physical owners and native financial/symbol observations, and changes no authority rows/revisions/digests. It cannot silently refresh/publish an accepted clock. If the stored clock is not the current event's accepted observation, report `PREFLIGHT_ACCEPTED_CURRENT_CLOCK_PREREQUISITE_MISSING_ZERO_AUTHORITY_MUTATION`; no historical timestamp is promoted to fresh. Similarly fail closed on missing, corrupt, foreign, expired or non-initial-flat prerequisites. Ignored diagnostic log output is separate from authority-store mutation.
6. Only a separately Fusion-authorized D1 session may select MODE_D1_BUY and explicitly set all three flags true, then freshly acknowledge A. Saved true inputs alone cannot arm after relaunch. Native Orchestrator/DecisionEngine must produce the first eligible healthy, current, trusted BUY. WAIT/SELL/stale/invalid inputs cannot prepare D1. Consume the wrapper latch **before the accepted clock write**, then complete the physical D1 path. There is no timer/callback/retry/rearm path.

Required request price/volume/protective stop/filling are explicit invocation parameters, not caller-authored authority DTOs. No threshold/Signal/geometry optimization is included. Exact allowed filling FOK/IOC is selected explicitly; combined/unsupported values are not coerced. Native margin/profit calculations remain read-only calculations. Final Broker permission/profile/spec sample and irreducible TOCTOU limit remain the accepted adapter behavior.

## Ordering and restart

Authentic Signal publication → Sequence → RequestIdentity → Unit → coherent Margin/Basket Risk/Risk → Ledger acceptance → Blueprint → Request publication → Ledger BOUND → Permit CAS → Admission double collect → independent persisted Governance validation → atomic Pin + initial Vector → authoritative readback → Claim CAS → CLAIM_GRANTED_NOW → existing Broker boundary in the **same event**. No human prompt or deferred callback occurs after Claim. Post-Claim failure remains unresolved, never automatically retried.

OnTradeTransaction only forwards observational callback facts to exact available persisted identities. Native Broker callback capture persists observational evidence; it cannot create ingress/sequence/Permit/Pin/Claim, run the Runner, submit, retry, or infer terminal confirmation. The evidence log may be refreshed from physical readback only.

MODE_D6_RECOVER requires a fresh explicit confirmation/execute-once/A acknowledgement; saved flags do not rearm. On the current-symbol tick it obtains a new accepted clock, reopens SQLite, reloads current lease, complete unresolved Claim, Account, Governance, Pin/Vector, RequestSet/Permit identities, and independently queries native Broker plus physical Execution. Accepted Phase F positive evaluation/publication CAS, canonical Basket transition and exact Submission terminal readback are required. No Claim grant is reconstructed. No-positive observations preserve unresolved state with `NEGATIVE_AUTHORITY_NOT_PROVEN_FOR_MVP_DEMO`; they never authorize a negative conclusion. D6 cannot submit.

## Evidence and test credibility

Runtime logs are ignored artifacts in Terminal `Common\Files`:

- `fusion_v5_mvp_attended_setup_evidence.log`: explicit action/source/build/profile, physical lease/Trust/Hard Kill/Governance readback and stop reason; submission fields explicitly not applicable.
- `fusion_v5_mvp_attended_evidence.log`: source/build/mode/explicit flags, current physical identities, Request/Permit/Admission/Pin/Vector/Claim, wire digest, synchronous transport/error/retcode/IDs, callback count, Broker/Execution observation presence/completeness/row failures, reconciliation and durable Submission state. Not-yet-observed fields are distinguished from observed zero; unknown states are -1. No authentication references/passwords are exported. A synchronous acknowledgement is never confirmation.

The launch MQL suite uses a TEST-only private SQLite namespace/store and actual native Demo profile/symbol/financial observations, Manual Setup, independent safety release and Governance, owners, native default host and actual Orchestrator initialization. Deterministic external engine-result fixtures invoke **actual CDecisionEngine.Decide**; no hand-authored BUY is used in the new rehearsal. The shared dispatch drives actual D1 providers through Claim, then a non-mutating TEST seam exactly once. The seam persists an explicitly simulated synchronous acknowledgement; its simulated transport count is **not** actual broker submission evidence. Providers are reconstructed with a new native clock; TEST Broker history/position fixtures (raw millisecond timestamp units) plus actual independent SQLite Execution observations drive empty and positive D6. Native callback capture is exercised with TEST callback facts. No real Broker submission/recovery effect is claimed.

Missing Pin/Vector are deleted only from verified row-for-row TEST clones **after actual Admission**, before actual Claim; unrelated earlier failure is not credited. WAL checkpoint before cloning prevents loss of committed authority rows. No runtime DB is cloned/deleted. Raw tester journals are preserved losslessly as ignored `.raw.log` artifacts by the runner.

| Requirements | Evidence type |
| --- | --- |
| LAUNCH-01 | MetaEditor graph compilation; real-MQL native graph and Orchestrator initialization, not compile counted as behavior. |
| LAUNCH-02–04 | Actual native default host + two actual Runner preflights; all authority row fields/revisions/digests unchanged and zero seam calls. |
| LAUNCH-05–07, 10–12 | Actual Decision BUY/WAIT/SELL fixtures and real gate negatives; stale/invalid/expired Trust rejection plus physical no-artifact comparison. |
| LAUNCH-08–09 | Actual ephemeral latch before accepted native clock publication; source shape proves host second-tick early return. |
| LAUNCH-13–15 | Physical seed/accepted Decision source/shared dispatch and complete Permit/Admission/Pin/Vector/Claim identity readback. |
| LAUNCH-16–19 | Exact post-Admission Pin/Vector row faults reach actual Claim and invoke zero seams; successful structural Claim invokes seam once. |
| LAUNCH-20–21 | Actual native callback evidence persistence leaves Claim digest unchanged; static callback dispatch prohibition. |
| LAUNCH-22–24 | Actual native Manual Setup ACTIVE state; independent release and explicit Governance/initial Basket; D1 leaves Governance unchanged. |
| LAUNCH-25–29 | New clock/provider instances, complete physical reconstruction, no reconstructed grant, zero recovery seams; positive exact terminalization and empty evidence unresolved. |
| LAUNCH-30–32 | Structural stub-removal, callback binding, exhaustive Broker diff and exactly-one-OrderSend scan, not behavioral Broker execution. |

`Verify-MvpBasketOffline.ps1 -RunTester` compiles the changed/current runtime manifests and runs all allowlisted TEST-only Demo Strategy Tester suites. Phase B–F compile manifests and Python/source gates are separate. Python mutation controls establish Python-oracle detection only, never MQL production mutation power. Historical Phase F0 literal verifier is PRE-EXISTING / WAIVED and unchanged. Passing offline gates does not authorize actual D1 or declare production readiness.
