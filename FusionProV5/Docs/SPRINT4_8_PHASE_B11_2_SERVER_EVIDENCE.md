# Sprint 4.8 Phase B11.2 — Server Evidence Parser Closure

Status: **Candidate / In Review — Unlocked — Pending Approval**

This phase is an uncommitted evidence-tooling correction on top of B11.1. It does not freeze a source, generate final repository evidence, authorize merge, grant runtime authority, establish production readiness, or create Architecture Lock. Sprint 4 remains the authorized architecture baseline.

## Root Cause

The prior exporter required exactly one literal `EURUSD,M1 (<server>): testing of` occurrence. The immutable D3 logs instead bind the server in a structured `Tester` record of the form `<symbol>,<timeframe> (<server>): generating based on real ticks`; their separate `testing of` records do not carry a server. The parser therefore rejected valid evidence even after the B11.1 build resolver succeeded.

## Server Authority Policy

- Authoritative: structured `Tester` generation records ending in `generating based on real ticks` and supported legacy structured `Tester` execution records containing a server-qualified `testing of` clause.
- Corroborating: a machine-result `server` field, when present, must equal the raw resolved server but cannot replace raw authority.
- Optional: either authoritative wording may be absent when the other is present; repeated identical authoritative records are accepted.
- Ignored for server authority: arbitrary payload or diagnostic mentions, `fixture_server` test-fixture metadata, local MetaTester startup records, and build-only agent/login records.
- Unsupported: unrecognized session/startup text that does not directly bind a tester run to a server.

The source-bound run-config Git blob supplies the expected symbol and timeframe. Every recognized server record must match those tokens. The resolved server must be unique, equal the exact allowlisted `Exness-MT5Trial6` value, and independently satisfy the Demo/Trial classification gate. Missing, malformed, empty, conflicting, wrong, non-Trial, or cross-layer-inconsistent evidence fails closed.

## Cross-Layer Enforcement

`Resolve-TesterServerEvidence` is the single raw-log resolver used by Generate and by the common semantic path behind VerifyIndex and VerifyCommit. Each run is resolved independently. Raw resolution is cross-checked against an optional machine-result server, the generated or committed per-run semantic summaries, the other run, and the canonical verification-source `server` input.

## Deterministic Verification

- Server-parser cases `EXP48-93..107`: 15 passed, 0 failed, 0 skipped.
- Build-parser regression `EXP48-83..92`: 10 passed, 0 failed, 0 skipped.
- Complete exporter suite: 107 passed, 0 failed, 0 skipped.
- Complete exporter signature: `75622e6fff50c84777a44610ae5743ae1af84d9d96bb48329d342d997341f160`.
- Exporter SHA-256: `786402fe6eea56f998132956e4f5ce42f85b2aa186216ea2e16feb08742c9401`.
- Exporter test-script SHA-256: `53a1f6bf27676fbbf52b90be90ff4c782027c87b7f97349f22e556d109b875d6`.
- Exact immutable D3 resolution: both runs resolve build `6090` and server `Exness-MT5Trial6`.
- Exact immutable D3 Generate: PASS offline with 969/969 executable cases, signature `18372369681406354017`, 969 exact credibility mappings, 10 `ROUND_TRIP`, and 0 `WEAK_FALSE_POSITIVE`.

The immutable D3 raw SHA-256 values remain `faf11eccdde06082acbf84610bb6f77545cacb837f80dd8d6c118172f88f9168` for Run 1 and `9095cc508f91a2479cc93b9a5d8652ac7f872b77629eea0e927061af79b7be20` for Run 2.

## Verification-Source Format

`SWV5-SPRINT48-B11-VERIFICATION-SOURCE-V5` is retained. The canonical field remains the exact resolved tester-server identity; B11.2 corrects the allowlisted raw record classes used to derive that existing meaning and does not change the ordered field set.

The prior D3 digest `49f90d11d8b1349b243bfc15e929c1fb39f4076b4d894fca7b4bc2e52b9d5d32` remains superseded for any successor evidence because the exporter and exporter-test Git blobs have changed. No successor digest becomes final authority until a separately approved source freeze and reproducible evidence phase.

## Scope

No MQL, production contract, runtime, broker, Signal Engine, DecisionEngine, dashboard, or frozen Sprint file is changed. No MT5 process is launched. The full MQL suite is not rerun because this correction is limited to offline evidence tooling, its tests and inventory, and governance documentation.
