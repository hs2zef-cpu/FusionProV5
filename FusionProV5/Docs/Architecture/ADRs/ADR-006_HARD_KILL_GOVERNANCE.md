# ADR-006: Hard Kill Governance

## Status

Accepted.

Governance note: this technical decision is part of the Sprint 4.1 Candidate / In Review package. It does not Architecture Lock Sprint 4.1, replace the Sprint 4 authorized baseline, or authorize runtime implementation.

## Decision

Hard Kill is a durable latch. Restart, reattachment, ownership takeover, or a new signal cannot clear it. While latched, only reconciliation and explicitly authorized risk-reducing or close-only actions are eligible.

The canonical `SWV5_HardKillState` contains persistence namespace, latch identity, latch generation, activation state/reason/authority/time, release generation, and release evidence. It is stored in every persisted checkpoint and its generation is bound into Risk Authorization.

Release requires an independent approving component, identified operator authority, typed and versioned broker-state evidence, typed persistence evidence, typed zero-or-reducing exposure evidence, an expiry, a monotonic generation, and an auditable reference. Self-attested booleans are not evidence. Release evidence cannot be created or approved by the execution component that consumes it.

## Consequences

- Missing, expired, self-issued, or incomplete release evidence is rejected.
- Hard Kill evaluation precedes every other Risk domain.
- Restart loads and reconciles the persisted latch before any readiness decision.
- Detailed operator workflow and credential storage remain deployment concerns for a later approved Sprint.

## Demo MVP addendum: Release Epoch Re-authorization

Fusion has authorized the implementation scope below. The implementation is a
candidate pending executable verification and AiPASS/Opus post-patch review;
this addendum does not authorize deployment of the candidate, trading,
Architecture Lock, or a main merge.

Expiry makes an INACTIVE release epoch execution-ineligible. Expiry never
extends its validity. Ordinary release/eligibility validators retain their
strict finite expiry checks. A continuation-only historical structural reader
is not an eligibility decision and is not consumed by PREFLIGHT, D1, Admission,
Claim or D6.

An explicitly acknowledged attended Demo continuation may establish a new epoch:
expired INACTIVE structural validation -> fail-closed ACTIVE continuation latch
-> independently observed, typed continuation flat-state authority -> ordinary
RELEASE_PENDING/RELEASED lifecycle -> a new INACTIVE epoch. The original release
records and Bootstrap Zero authority are retained unchanged. Continuation flat
evidence has a distinct type/domain and is not D6 negative-terminalization proof.

The deployed owner is a configured session identity, not a sampled OS PID or
process-start identity. Same-owner heartbeat preserves its full authority fence;
only liveness and store/CAS metadata advance. Late attended heartbeat does not
make the expired lease usable before its exact physical CAS/readback commits.

Release generation is derived from physical historical lineage and cross-checked
against the maximum completed release generation, never the INACTIVE sentinel's
zero value. Release and latch generations increase strictly across epochs. Each
new release is finite. Old release evidence cannot validate against the new
latch or satisfy current eligibility. Completed replay is readback/report only.

Partial completion remains explicit and fail closed. No automatic retry,
takeover, broker mutation, liquidation, or increasing execution is part of this
administrative continuation.
