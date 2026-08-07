# Changelog

This file records the authorized evolution of Fusion Pro V5.

## Unreleased

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
