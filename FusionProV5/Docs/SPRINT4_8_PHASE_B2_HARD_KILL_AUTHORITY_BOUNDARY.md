# Sprint 4.8 Phase B2 — Hard Kill Authority Trust Boundary

Status: Candidate / In Review / Unlocked
Runtime authorization: none
Authorized architecture baseline: Sprint 4

## Threat and failure model

The V5 candidate must fail closed against corrupted, stale, or resealed checkpoints; forged checkpoint-local authority fields; mismatched operator identity, approval policy, release generation, or evidence references; and restart state that disagrees with independently supplied release authority.

The design does not claim protection when both checkpoint storage and the independent release-authority source are compromised. Authenticated signatures or another external cryptographic trust mechanism would be required for that threat, and no such mechanism is authorized here.

## Separate trust domains

Checkpoint content integrity proves only that persisted bytes match the checkpoint's canonical content. It does not prove that an operator or approving authority authorized a release.

Historical release authority is supplied independently through `SWV5_HardKillReleaseAuthorityRecord`. Risk Governance owns and issues that semantic record at the approved release-authority boundary. Persistence may store or transport it separately, but may not create it from checkpoint content.

The checkpoint contains `SWV5_HardKillReleaseAuthorityReference`, which binds record ID, sequence, digest, release ID, latch generation, and release generation into the checkpoint digest. The reference is not authority by itself.

## Restart rule

When persisted Hard Kill state is `RELEASED`, restart requires both:

1. A valid checkpoint with a complete authority reference.
2. An independently obtained authority record matching that reference and every diagnostic release field.

Missing, malformed, stale, foreign, digest-mismatched, or semantically mismatched authority halts restart. `ACTIVE` and `RELEASE_PENDING` remain close-only or stronger. A genuinely never-latched `INACTIVE` state does not require a historical authority record.

Historical validation enforces:

`authenticated_at <= evidence observations <= approved_at <= released_at < expires_at`

Restart time may be later than `expires_at`; historical validity concerns the release when it occurred.

## Integrity semantics

`SWV5_HardKillReleaseAuthorityRecord.authority_record_digest` uses canonical V5 typed length-prefixed serialization and excludes only the digest field itself. The digest verifies integrity of the independently supplied input; it is not a digital signature.

The checkpoint's canonical payload includes the complete authority reference. Modifying checkpoint-local release data and recomputing every checkpoint-local digest cannot make it agree with an unchanged independent authority record.

Production Contract V5 remains Candidate / Unlocked. This decision grants no Architecture Lock, runtime authorization, production-readiness claim, or merge authorization.
