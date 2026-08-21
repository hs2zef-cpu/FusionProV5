# Changelog

### Sprint 4 post-merge governance closure

- Recorded Final Independent Merge Audit `PASS`: no Critical findings, no Major findings, all six Critical and three prior Final-Audit MAJOR findings closed, infrastructure closure matrix all pass, Merge Safety `SAFE`, and final merge decision `READY TO MERGE INTO MAIN`.
- Recorded the fast-forward-only update of old main `ed8b2b61ff83982faece7b7babd5ae6fd993e5f4` to audited evidence commit `87f77c8b0b9253c2a851540085f8b7ce14cf2e52`; no merge commit was created, remote main was updated successfully, and the candidate branch was retained.
- Preserved frozen technical source `ef556a94636e977e35e961be28ae03c9838615d4`, source tree `19db1538ab3ddfc982006ba89d43cf01c5e51f18`, evidence tree `c088ae72ee66e1896d7a6ed0ad62d1fec190f6b3`, and D5 verification digest `fe46965aa392df1a1dcc1cd919b77581445a589a1c694217ddb4a5b489617778`.
- Production Contract V5 is audited and merged to main but remains unlocked pending explicit formal Architecture Lock approval. No runtime, broker execution, production, live-trading, or Signal-to-Execution wiring authorization is granted.
- The next gate is Post-Merge Architecture Approval / Sprint 5 Scope Authorization. Any future Execution Layer or EA Host work requires a separately approved Sprint 5 scope.

### Sprint 4.8 Phase E5 B11.6 reproducible immutable evidence

- Recorded the technically frozen B11.6 source `ef556a94636e977e35e961be28ae03c9838615d4` and tree `19db1538ab3ddfc982006ba89d43cf01c5e51f18`.
- Packaged the exact D5 immutable results: two MT5 Trial/Demo Strategy Tester runs each passed 969/969 with 0 failed, 0 skipped, and identical signature `18372369681406354017`.
- Recorded the frozen offline exporter result: 140/140 passed with signature `5ee6614cc75642262a67e29661642787d9974de3e364499e05563baf83552bc5`.
- Bound exact source, compile, run, EX5, run-configuration, source-blob, and exporter authorities into verification-source digest `fe46965aa392df1a1dcc1cd919b77581445a589a1c694217ddb4a5b489617778`.
- Closed all six Critical findings, all three Final-Audit MAJOR findings, and the terminal-build, tester-server, exporter-identity, deterministic-provenance, and test-credibility parser/harness findings. D4 remains failed historical evidence and is superseded as verification authority by D5.
- Governance remains Candidate / In Review / Unlocked / Pending Approval. Sprint 4 remains the authorized baseline; the next gate is a new Final Independent Merge Audit. No Architecture Lock, runtime authorization, production-readiness claim, merge authorization, or formal approval is made.

### Sprint 4.8 Phase B11 full DTO, Statistics finite-boundary, and credibility semantics closure

- Marked B10.1 source `e56e51e72dc5fd9ee47d847781a545134b092059` and evidence `b6b36f204d4ebeb3aab4fdacf31b0b8b5b8e1b91` as immutable superseded failed-final-audit history; neither commit was amended.
- Split seven ambiguous canonical helpers into explicit nonrecursive digest-preimage and full-DTO representations. Full DTO decoders now read and validate original embedded integrity fields, including checkpoint LP2 envelope metadata.
- Added missing/tampered embedded-digest failures and repaired all advertised positive full DTO reconstruction cases.
- Added finite-number guards for all six authoritative deal doubles and made `AccumulateDeal` publish output only after complete validation and successful candidate mutation.
- Added source-bound `TEST_CREDIBILITY_ID_INVENTORY.txt`; exporter totals are now derived per ID and cross-checked against executable order and human-readable headlines. Verification-source format advances to `SWV5-SPRINT48-B11-VERIFICATION-SOURCE-V5`.
- Expanded the candidate MQL inventory from 934 to 969 cases and the exporter offline inventory from 73 to 82 cases. B11 remains Candidate / In Review / Unlocked and not source-frozen; no final evidence, Architecture Lock, runtime authorization, production-readiness claim, merge authorization, commit, or push is implied.

### Sprint 4.8 Phase E2 reproducible immutable evidence

- Recorded the technically frozen B10.1 source `e56e51e72dc5fd9ee47d847781a545134b092059` and tree `c97ba3cf8b21d12cc601753f4b2c311a06d02206`.
- Packaged the exact Phase D2 immutable results: two MT5 Trial/Demo Strategy Tester runs each passed 934/934 with 0 failed, 0 skipped, and identical signature `11631338912972649069`.
- Recorded the frozen offline exporter result: 73/73 passed with signature `aef3182e58ba10f267ac0459d1b0df14afa8fc988d15b17e5c1828ff0a25bb37`.
- Bound source identity, exact external raw hashes, source-derived Git blob hashes, run configuration, compiled EX5, and semantic results into verification-source digest `66a11100c3ba44a6c3b0699b93dedfacd3c2d0d618ddcc4b039efe0beda4cfd7`.
- The prior `06e0d6e2c9c9138a73ebe69bbdd1766c813d5f89` source and `eebbd169aeff6afaeeaba75c1c120d823e2ec2b3` evidence remain immutable superseded failed-audit history.
- Governance remains Candidate / In Review / Unlocked. Sprint 4 remains the authorized baseline; final independent merge audit is required. No Architecture Lock, runtime authorization, production-readiness claim, merge authorization, or formal approval is made.

### Sprint 4.8 Phase B10 query-domain, anti-replay publication, and evidence-root closure

- Closed the V5 query-domain mask so unknown bits fail closed in required, completed, and authoritative masks.
- Classified `snapshot_id` as a diagnostic, integrity-bound label rather than authority or anti-replay evidence.
- Added a typed SAFE-reconciliation proposal and explicit atomic Persistence publication for separate Broker and Execution accepted-query high-watermarks.
- Added monotonicity, replay-after-publication, owner-separation, coherent-checkpoint, CAS, and failure-atomicity verification.
- Made VerifyIndex and VerifyCommit independently derive the tested Git tree and rebuild one canonically framed verification-source digest from source identity, raw-hash claims, parsed run semantics, and source-bound Git blobs.
- Expanded the candidate suite to 934 executable cases; the single authorized local MT5 Trial Strategy Tester run passed 934/934 with signature `11631338912972649069`.
- Expanded the offline exporter suite to 73 cases; all 73 passed with signature `aef3182e58ba10f267ac0459d1b0df14afa8fc988d15b17e5c1828ff0a25bb37`.
- Governance remains Candidate / In Review / Unlocked. No source freeze, Architecture Lock, runtime authorization, production-readiness claim, merge authorization, commit, or push is implied.

### Sprint 4.8 Phase B9 query snapshot authority and semantic evidence closure

- Made Broker and Execution restart query snapshots independently identified, timestamped, sequenced, source-bound, and digest-protected.
- Added owner-specific persisted query-sequence high-watermarks so fresh wrappers cannot replay stale nested query evidence.
- Separated Broker positions/orders/deals/transactions query ownership from Execution pending-request query ownership.
- Removed the shared persistence-to-authority request fixture path and added one-sided mutation tests.
- Upgraded evidence verification from hash-only checks to source-bound semantic validation of both tester streams and a machine-readable 67/67 offline exporter result.
- Added canonical, reconstruction, malformed-input, and regression cases; the candidate suite now contains 914 executable tests.
- Governance remains Candidate / In Review / Unlocked. No source freeze, Architecture Lock, runtime authorization, production-readiness claim, merge authorization, commit, or push is implied.

### Sprint 4.8 Phase B8 restart authority closure

- Replaced caller-selected restart query completeness with the V5 contract-defined positions, orders, deals, transactions, and pending-request mask.
- Added distinct Execution/Pending-Request `authority_source` binding with canonical serialization, strict decoding, digest sensitivity, and negative tests.
- Added an inclusive 60-second deterministic restart freshness limit, checkpoint-time ordering, and query-to-broker sequence coherence without aliasing independent streams.
- Repaired S48-RST-18 to prove its own safe baseline, isolated resealed request-revision mutation, and byte-identical valid persisted checkpoint.
- Expanded RFULL plus direct query/freshness/authority cases and added exporter rejection of an old 868-ID stream against newer source inventory.
- Governance remains Candidate / In Review / Unlocked. No source freeze, Architecture Lock, runtime authorization, production-readiness claim, merge authorization, commit, or push is implied.

This file records the authorized evolution of Fusion Pro V5.

## Unreleased

### Sprint 4.8 Phase B7 complete reconciliation and evidence-parser correction

Governance status: corrective work inside the Sprint 4.1 **CANDIDATE / IN REVIEW** branch. Sprint 4 remains the authorized baseline; Production Contract V5 remains unlocked with no Architecture Lock, production readiness, runtime authorization, or merge authorization.

- Separated broker-observed exposure, execution-owned pending-request identity, and persistence-owned checkpoint state for complete restart reconciliation.
- Added independently supplied Basket open-volume and request-set/reconciliation dimensions, explicit fail-closed comparisons, adversarial full-vector tests, and canonical reconstructive coverage.
- Strengthened the evidence exporter to validate the exact immutable test-ID inventory and every individual `SWV5_TEST` record against the machine summary.
- Marked source `06e0d6e2c9c9138a73ebe69bbdd1766c813d5f89` and evidence `eebbd169aeff6afaeeaba75c1c120d823e2ec2b3` as immutable superseded failed-audit history. Phase B7 has no current final source freeze; a new source review and evidence cycle are required.

## Sprint 4.8 Production Contract V5 and Reproducible Immutable Verification

Governance status: corrective work inside the Sprint 4.1 **CANDIDATE / IN REVIEW** branch. Sprint 4 remains the authorized baseline; Production Contract V5 and Sprint 4.8 remain Candidate / Unlocked with no Architecture Lock, production readiness, runtime authorization, or merge authorization.

- Recorded the frozen Sprint 4.8 source `06e0d6e2c9c9138a73ebe69bbdd1766c813d5f89` and tree `13b9a0dc020dbdd293e648c5a6f4c4d1cba05147`.
- Packaged the existing immutable Phase D verification: two MT5 Demo Strategy Tester runs each passed 846/846 with 0 failed, 0 skipped, and identical signature `12393352988365616976`.
- Classified the 846 executable cases as 773 behavioral, 59 supporting pure-function, 14 conformance-only, and zero weak false-positive cases.
- Added deterministic Sprint 4.8 evidence tooling with offline validation and exact Git index/commit blob-byte SHA-256 authority.
- A final independent merge audit remains required before any merge or formal approval decision.

The later final independent audit failed on complete reconciliation sufficiency, test credibility, exact result-record parsing, and governance wording. The successful run facts remain historical, but this source/evidence pair is superseded and is not current merge evidence.

## Sprint 4.7 Adversarial Safety and Reproducible Immutable Verification

Governance status: corrective work inside the Sprint 4.1 **CANDIDATE / IN REVIEW** branch. Sprint 4 remains the authorized baseline; Production Contract V4 remains a Candidate / Unlocked contract with no Architecture Lock, production readiness, runtime authorization, or merge authorization.

- Closed the five Critical safety findings and the coverage/provenance Major findings raised by the final independent audit of Sprint 4.6; Sprint 4.6 remains superseded failed-candidate history.
- Recorded immutable verification against source `008411c67239372968a4f742519984169044b7e4`: two intentional MT5 Demo Strategy Tester runs each passed 634/634 with 0 failed, 0 skipped, and identical signature `18433705061502137480`.
- Classified the 634 executable cases as 610 behavioral, 23 supporting pure-function, one conformance-only, and zero weak false-positive cases.
- Generated reproducible evidence from hash-gated Phase D raw inputs using exact Git-index and committed-blob SHA-256 authority.
- A new final independent merge audit remains required before any merge or formal approval decision.

## Sprint 4.6 Final Safety Closure and Immutable Verification

Governance status: corrective work inside the Sprint 4.1 **CANDIDATE / IN REVIEW** branch. Sprint 4 remains the authorized baseline; V4 remains an unlocked candidate with no Architecture Lock, production readiness, runtime authorization, or merge authorization.

- Closed the remaining reviewed safety findings for execution-envelope authority, Risk evaluation and Hard Kill release evidence, checkpoint payload integrity, collision-safe canonicalization, retry freshness, and durable fingerprint mapping uniqueness.
- Preserved the isolated contract and deterministic test-only boundary: no broker execution, Signal Engine wiring, or production runtime implementation was added.
- Recorded immutable verification against source `50f0dc5f35f3fafd8604081cee6cb0c07cb9effe` (tree `32c04850f08b488f6376943135d83df992979e78`): two intentional MT5 Demo/Trial Strategy Tester runs each passed 561/561 with 0 failed, 0 skipped, and identical signature `11321096574546544847`.
- Classified all 561 executable cases as 537 behavioral, 23 supporting pure-function, one conformance-only, and zero weak false-positive cases.
- Final independent merge audit remains required before any merge decision.

## Sprint 4.5 Authority Binding and State Semantics

Governance status: corrective work inside the Sprint 4.1 **CANDIDATE / IN REVIEW** branch. Sprint 4 remains the authorized baseline; V4 remains an unlocked candidate with no Architecture Lock, production readiness, or runtime authorization.

- Advanced the unresolved breaking contract candidate from V3 to V4.
- Separated acknowledgement from authoritative execution confirmation and added durable evidence fingerprints.
- Required canonical validation before recovery replay or unclaimed ownership acquisition.
- Completed Risk authorization rebinding and contract-derived Unit operation semantics.
- Separated stable ownership authority from mutable heartbeat liveness and store/CAS revision.
- Replaced delimiter-based persistence canonicalization with typed length-prefixed encoding.
- Classified every executable test and separated behavioral, supporting, and conformance evidence.
- Recorded final immutable verification against source `f768205573d44d71a7f55b8e893ae0b48770d451`: two intentional independent MT5 Demo Strategy Tester runs each passed 368/368 with 0 failed, 0 skipped, and identical signature `14243830495988534780`.

## Sprint 4.4 Contract Completion and Semantic Verification

Governance status: corrective work inside the Sprint 4.1 **CANDIDATE / IN REVIEW** branch. Sprint 4 remains the authorized baseline; no Architecture Lock, production readiness, or runtime authorization is claimed.

- Completed restart reconciliation over the full ordered pending-request set.
- Bound persistence digest/revision metadata to canonical nested payload content and order.
- Completed Risk authorization output and validation across account, limits, Basket, Hard Kill, projected-risk, monetary, and normalized execution fields.
- Added durable recovery/execution/statistics identity-state mutation outputs and idempotent replay behavior.
- Added monotonic heartbeat renewal and fully typed lease-expiry/takeover binding.
- Audited all 238 executable cases: 236 meaningful interface-behavior cases and two supporting pure equality cases.
- Verified 238/238 twice in MT5 Demo Strategy Tester with identical signature `6132791249901820115`.

## Sprint 4.3 Contract Correction and Interface Verification

Governance status: corrective work inside the Sprint 4.1 **CANDIDATE / IN REVIEW** branch. Sprint 4 remains the authorized baseline; no Architecture Lock or runtime authorization is claimed.

- Corrected all ten verified CRITICAL and MAJOR contract findings.
- Advanced the breaking candidate schema from version 2 to version 3.
- Split pre-submission request identity from broker-generated identity and added explicit execution phases.
- Added reconstructible pending-request, durable event-set, account namespace/epoch, account-mode, recovery, takeover, Hard Kill, and unit-safety evidence.
- Replaced helper-only claims with deterministic implementations and invocation of every `ISWV5*` interface.
- Its verification claim is superseded by the Sprint 4.4 semantic suite and immutable-source evidence.

## Sprint 4.2 Executable Verification

Governance status: authorized verification sub-sprint within the Sprint 4.1 candidate branch. It did not Architecture Lock the candidate or authorize runtime.

- Added the executable contract test manifest and deterministic test-only fixtures.
- Established the initial 162-case regression matrix; Sprint 4.3 supersedes its helper-only verification claim with interface-level evidence.

## Sprint 4.1 Contract Hardening

Governance status: **CANDIDATE / IN REVIEW**. Pending formal approval; not Architecture Locked; no runtime authorization.

- Advanced the Production Architecture contract candidate to schema version 2.
- Added deterministic validation context and explicit compatibility policy.
- Hardened Basket, Execution, Persistence, Risk, Statistics, Ownership, and Unit evidence boundaries.
- Added ADRs for execution isolation, Hedging-only initial support, lease atomicity, transaction confirmation, units, and Hard Kill governance.
- Added table-driven validation specifications without implementing broker execution.

## Sprint 4 Architecture

- Established isolated production architecture contracts without runtime or broker execution.

## Sprint 3.2.1

- Hardened history-token handling and runtime regression evidence.

## Sprint 3.2

- Completed architecture audit closure, validation ownership, score semantics, and CSV evidence support.

## Sprint 3

- Migrated Momentum evidence with independent regression comparison.

## Sprint 2

- Migrated Trend behavior and completed the read-only dashboard panel work.

## Sprint 1

- Established the Fusion Pro V5 architectural skeleton and core ownership boundaries.
