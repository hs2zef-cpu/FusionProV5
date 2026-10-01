# ADR-024: Demo MVP post-release inactive eligibility

## Status

Fusion-authorized narrow semantic closure, 2026-10-01. Implementation and
broker-free verification only. No actual Demo D1, Architecture Lock,
production readiness, live trading, or main merge is authorized.

## Decision

The attended lifecycle is ACTIVE → RELEASE_PENDING → RELEASED → INACTIVE.
RELEASED is durable completion of independent Risk-Governance approval,
not increasing-execution permission. Existing Production V5 DTOs, frozen
Risk validators and Phase B–F contracts remain unchanged.

`PersistApprovedRelease` retains RELEASED and persists the complete
independently issued release authority and exact RELEASED DTO in
`MVP_HARD_KILL_COMPLETE_RELEASE/<authority_record_id>`. The length-prefixed
codec preserves every field; canonical authority digest and physical
envelope digest are checked independently. The row is create-only and
ownership-guarded. A retained approval whose CURRENT update fails is inert.

The explicit attended `TryActivateInactiveAfterValidatedRelease` validates
exact physical RELEASED CURRENT, its complete independently issued record,
full reference/evidence binding, namespace/account, unexpired approval and
current physical lease. It checks the caller's exact CURRENT revision,
store revision, digest, state and payload. No wrapper issues approval.

The existing guarded two-row SQLite transaction atomically creates
`MVP_HARD_KILL_ACTIVATION_HISTORY/<new_latch_id>` and advances Hard Kill
CURRENT. History embeds the full RELEASED bundle, predecessor revision and
digest, activation fence, authenticated operator invocation and authoritative
clock sample. Its digest identifies `INACTIVE/<transition_digest>`. Latch
generation advances by one; release generation is zero; activation reason,
activation authority and release ID are explicitly empty. Required nested
versions, namespace and new latch identity/generation are initialized.
The old release is not overwritten. Both rows and the ownership guard are
read back transactionally and after commit. Interrupted pair writes cannot
leave an executable CURRENT; deterministic rollback injection covers both
failure points including an existing CURRENT row.

INACTIVE alone is insufficient. Before Risk, Permit and each authoritative
Admission collect, the runtime validates physical CURRENT and immutable
lineage, complete release authority, activation digest, exact namespace,
lease/fence, row revisions/digests and the original approval expiry. Risk's
authorization deadline is capped by this horizon as well as its existing
Trust/lease/specification deadlines. Expiry fails closed; no extension or
automatic requalification is introduced. Restart validates the same lineage
and cannot recreate a Claim grant.

At Claim completion, ADR-020 remains authoritative: validate the activation
lineage represented by the coherent Admission snapshot, its exclusive
deadline and current ownership/liveness. Do not re-evaluate a subsequent
non-time latch as a second policy decision. A latch ordered after the
conditional Admission point governs later admissions; expiry or ownership
loss still prevents completion. There is no new Risk decision after Claim.
Existing conservative post-Claim failure and reconciliation rules remain.

Ordinary setup and read-only preflight never activate INACTIVE. Safety
approval, post-release activation and Governance provisioning are explicit
attended actions. D6 observation/reconciliation does not acquire increasing
authority, extend release validity, submit, or retry.

## Verification and limits

The real-MQL HK suite specifies HK-01–HK-25 plus physical release-to-Risk E2E.
Fixtures use real SQLite and production producers, issuer, provisioning,
activation, preflight and Risk functions. Only read-only external observations
and the non-mutating broker boundary are test seams. Frozen checkpoint
validation proves the new inactive DTO without changes to the validator.
The legacy successful physical D1 fixtures now traverse the actual release
and activation path rather than directly installing INACTIVE.

Approval/readback, missing/corrupt authority, wrong identities/generations,
expiry, stale ownership, changed CURRENT, rollback, duplicate activation,
restart, corrupted lineage and zero-submission cases are separate tests.
Executed counts belong to raw tester journals, not this design record.
Final attended launch wiring remains a separate implementation commit.
