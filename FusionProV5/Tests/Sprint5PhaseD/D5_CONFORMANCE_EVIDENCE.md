# Phase D.5 conformance work record

TEST ONLY / NOT FOR PRODUCTION / NO BROKER ACCESS.

D.4 independent final re-audit: FAIL, Critical 1 / Major 2 / Minor 0.
D.5 self-verification does not close Phase D. Phase E is NOT AUTHORIZED.
The existing governance commit `c3709d7d961d881355b55453758d5e43984406dc`
is preserved. The user additionally authorized the restart-input schema gate
correction; no other candidate-version checks are globally replaced.

## Version-domain inventory (inspected before the schema correction)

| DTO / field | Domain | Existing/required validation |
|---|---|---|
| RestartReconciliationInput.contract_version | Production V5 | Exact frozen TestExecutionVersionExact(context, version); replaces candidate V3 check |
| Persisted checkpoint header / namespace / fence | Production V5 | IsV5Version and typed frozen predicates |
| Broker summary / query set | Production V5 | IsV5Version, reference summary/query validation |
| Execution restart summary / query set | Production V5 | IsV5Version, reference execution/query validation |
| Claimant fence / Lease / Lease fence | Production V5 | IsV5Version, exact fence equality, frozen heartbeat/fence completeness |
| Basket aggregate / lifecycle / pending-request set | Production V5 | Frozen Basket/reconciliation predicates and IsV5Version |
| Hard Kill state / release evidence / typed evidence / authority record / reference | Production V5 | Exact frozen state/release predicates and IsV5Version |
| Reconciliation vector | Production V5 | Frozen vector validation, IsV5Version |
| ReferenceGenesisRequest / ReferenceGenesisRecord / submission journal | Phase D reference | Sprint-5 candidate version initialized by reference Genesis; unchanged |
| ReferenceRestartResult | Phase D reference | No ContractVersion member; reference result, not a retagged Production DTO |
| Phase-D store schema / clock observation / transaction envelope | Phase D reference | Existing reference-domain policies remain unchanged |
| Frozen Sprint-5 publication/claim/ledger/sequence envelopes | Sprint-5 candidate | Existing candidate-version policies unchanged; outside correction scope |

## Frozen digest inventory (inspected before digest correction)

| Field | Exact frozen helper | Representation / validation |
|---|---|---|
| checkpoint.header.payload_digest | TestCheckpointPayloadDigest | Decimal unsigned 64-bit canonical hash; exact derivation equality and payload-size equality |
| reconciliation_vector.source_summary_digest | TestReconciliationSourceDigest | Decimal canonical hash; exact derivation equality |
| release_evidence.release_record_digest | TestHardKillReleaseDigest | Decimal canonical hash; exact derivation equality |
| authority_record.authority_record_digest | TestHardKillAuthorityRecordDigest | Decimal canonical hash; exact derivation equality and external reference binding |

All four helpers ultimately use frozen TestCanonicalHash (UTF-16 code units,
unsigned 64-bit multiply/xor, decimal output), NOT SHA-256. No numeric-string-only
validation is sufficient. Phase-D row/projection/request-set/query/summary/fence
SHA-256 reference digests remain distinct existing reference domains.

## Narrow positive reachability review

This is development source review, NOT an independent audit and NOT MQL
execution. `D5BuildRestart` supplies complete ordinary/zero-history inputs;
`D5BuildRestartWithRequests` additionally supplies two ordered, fully reconstructed
confirmed requests. Genesis READY is an independently supplied fixture input to
the restart validator; this review does not re-verify Genesis provisioning.

| Gate encountered in EvaluateReferenceRestart | Satisfying positive input / source check |
|---|---|
| Production schema/context | Frozen TestMakeContext/TestMakeRestartInput; exact V5 name/schema/minimum/policy; no fixture retagging |
| Namespace and owner equality | Complete frozen namespace, one derived current lease fence in claimant/header/Basket/vector |
| Genesis/persistence readiness | Independently supplied READY_FOR_RECONCILIATION and PERSISTENCE_LOADED inputs |
| Live Lease | ACQUIRED or RENEWED; positive 7/2 epochs, heartbeat 900 < context 1000 < expiry 1100, time T-60 < T < T+60 |
| Phase-D checkpoint projection / request set | Unchanged frozen Phase-B canonical SHA-256 domains; both empty authority views independently derive their set |
| Production payload integrity | Exact frozen payload size and decimal digest after TestSealCheckpoint; no 64hex predicate |
| Basket/vector/Hard Kill intrinsic semantics | ACTIVE .30 open/.30 residual/zero closed; state version 12; counts, identities, request indexes and latch generation agree |
| Reconciliation source | Exact frozen decimal helper, self-field excluded by frozen derivation |
| Broker/Execution authority and query union | Independently constructed authority summaries; required/completed/authoritative masks exact; existing Phase-D summary/query SHA domains preserved |
| Freshness / anti-replay | Persisted query HWMs 899; new snapshots 900; enclosing 901/902 <= evaluation 2000; checkpoint T-10 <= observations T |
| Cross-source relations | Basket/key/mode/fence, six volume measures, positions/orders, full correlation and Broker event/HWM agree |
| Request reconstruction | Empty controls have no latest request; two-request control updates canonical set/vector/latest record and checks ordered records |
| Independent release authority | Frozen decimal authority/evidence digests; matching external reference and complete exact policy/account/exposure/chronology; release effective before T and expiry T+60 |
| Dirty/unresolved/retry guards | Clean checkpoint; no unresolved request in positives; changing a later request reaches the explicit unresolved diagnostic |
| Final disposition | SAFE_TO_RESUME and increasing_execution_eligible=true |

Zero-history controls use IDLE, zero initial/closed/open/residual volume, no
positions/orders/requests, zero transaction HWM, and zero identities with correct
V5 nested versions. ACQUIRED and RENEWED follow the same live-Lease gate.
No further mutually exclusive condition was found in this narrow positive trace.

## Affected negative call graph and source credit

The 79 affected entry points are explicitly called by
`D5AffectedRestartProbeMatrix`: 50 pre-D.4 and 29 D.4. Two request-array negatives
use the complete two-request fixture; the remaining 77 use the complete empty-set
ordinary fixture and create zero-history controls where applicable.

The common `D5RejectRestart` establishes a positive, reseals only caller-computable
integrity, and does NOT synchronize namespace/fence/state/identity/revision
relations. Direct checksum probes intentionally preserve their corrupted field.
The active-Hard-Kill probe now constructs a valid active envelope and requires
CLOSE_ONLY. Unresolved-request probes reseal the complete set and require the
specific UNRESOLVED_REQUEST_REQUIRES_RECONCILIATION diagnostic, not a digest error.

| Negative family | Intended rejection after unrelated integrity reseal |
|---|---|
| Scope/fence/account/query provenance | Exact governed namespace/owner/mode/source gate |
| Set digest/index/count/reconciliation revision | Independent Execution/checkpoint/request-array relation |
| Query age / HWM / identity | Freshness/anti-replay or complete Broker/correlation relation |
| Basket state/version/net exposure | Frozen Basket/vector intrinsic predicate |
| Release policy/account/operator/evidence/chronology/reference | Frozen persisted or independent release-authority relation |
| Zero-history identity/exposure/orders/positions/query/fence | Explicit zero-history and authoritative-source predicates |
| Non-live ordinary/zero-history Lease | Common frozen heartbeat/live-Lease predicate |
| Three new zero-epoch cases | Complete CURRENT fence before CAS; fresh token, expected/observed epochs, reconciliation digests and accepted clock; unchanged stored row |
| Five new version substitutions | Exact Production version gate before digest/readiness |

Fresh source inventory: **26 positives / 173 negatives**. Source-review credit:
**82 semantic/resealed**, **13 checksum-only**, **78 uncredited other negatives**.
The 78 are deliberately not counted as D.5 proving evidence; this is not a new
finding that all those closed-domain probes are defective. All names are emitted
by `verify_phase_d5_source.py`. Nine complete new positive controls are present.
Counts exclude builders, parameterized Reject helpers and matrix collectors.
The old 34-only and 26/12 proving counts are withdrawn.

## Python/MQL boundary

The oracle retains its reduced independent state model. The four Production
digest fields now serialize explicit DTO projections using frozen canonical
expression bodies read offline by a restricted AST evaluator. The scalar hash
matches the frozen UTF-16/uint64/decimal algorithm; checkpoint size uses the
frozen body and MQL UTF-16 character count. Field order/names/preimages are not
copied into an alternative JSON/SHA formula. Unsupported expressions fail closed.
Unspecified projection members are explicitly zero-initialized; the projection
is not claimed to be byte-for-byte identical to every complete MQL fixture.

Python remains executable oracle evidence, NOT execution of the MQL assertions.
Source checks verify the exact adapter calls/hash algorithm, an independently
specified canonical version string/UTF-16 field example, sensitivity to preimage
mutations, and the 79-function source inventory. Negative digest cases substitute
both SHA-256 text and unrelated numeric text; matching character shape alone
cannot establish integrity. All 294 prior scenarios remain.

## Observed development gates

- Phase D: **318/318**, failed 0, skipped 0, 318 unique IDs; two final invocations, each with two identical internal runs, with identical result and durable-state digests across invocations.
- Result digest: `8330ea23fffa852b60a7e505e4184e08a565d617350a2f7a2e052b6804348486`.
- Durable-state digest: `a67f5a9f3e451f20a3203121df73a98f5ffa7b32678de1fb9c78d2fdfc6cd023`.
- Phase B: **139/139**. Phase C: **22/22**, approved trace digest
  `8a18101b83332f8931ef40a33408a88371bc9e38daf8b48ace3d2093dec55c4a`.
- All six B/C/D umbrella/assertion manifests: MetaEditor **X64 Regular**, **0 errors / 0 warnings**.
- Direct forbidden-API scan: PASS. Transitive include scan: **55 files, 0 forbidden API/dependency matches**.
- MQL assertions executed: **NO**. No Terminal/Tester/broker/platform activity.

These are D.5 development self-checks only. Phase D remains INCOMPLETE until a
new independent D.5 re-audit passes. Phase E remains NOT AUTHORIZED.
