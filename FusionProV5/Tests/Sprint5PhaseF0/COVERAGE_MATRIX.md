# Phase F0 Coverage Matrix

TEST ONLY / F0 / NOT FOR PRODUCTION.

| Required invariant/profile question | Artifact or test | Status |
|---|---|---|
| Exact supported environment | `BROKER_PROFILE.md`, `ENVIRONMENT_ATTESTATION.md` | BLOCKED — NOT MEASURED |
| Durable pre-send correlation | `CORRELATION_IDENTITY_DESIGN.md`, NC-14 | BLOCKED — no carrier proven |
| request_id session-local only | correlation study, NC-14 | COVERED OFFLINE |
| Magic semantics unchanged | correlation study, source scan | COVERED |
| Retcode classes R0–R5 | `RETCODE_CLASSIFICATION.md`, NC-02/03 | CANDIDATE ONLY |
| Sync acceptance not confirmation | NC-02 | COVERED OFFLINE |
| Callback order/absence non-authoritative | transaction profile, NC-04/06/07 | COVERED OFFLINE; Demo pending |
| Query incomplete differs from empty | query profile, NC-05/13 | COVERED OFFLINE; Demo pending |
| Clock/watermark profile | clock measurement | BLOCKED — NOT MEASURED |
| Timeout is not negative evidence | negative-evidence policy, NC-03 | COVERED OFFLINE |
| Reconnect preserves unresolved | NC-10 | COVERED OFFLINE; Demo pending |
| HEDGING mandatory | environment probe, NC-12 | COVERED OFFLINE; Demo pending |
| Stale owner/spec fail closed | NC-09/11 | COVERED OFFLINE |
| Broker double remains dumb | NC-08 | COVERED OFFLINE |
| Pending orders excluded | source verifier | COVERED STATICALLY |
| Tester cannot replace Demo | divergence matrix, NC-15 | COVERED OFFLINE |
| Physical broker behavior | raw attended-Demo evidence | NOT AVAILABLE |
| Frozen contract sufficiency | correlation/query/negative-evidence gates | UNRESOLVED — Fusion decision required |
