# Phase F0 Coverage Matrix

TEST ONLY / F0 / NOT FOR PRODUCTION.

| Required invariant/profile question | Artifact or test | Status |
|---|---|---|
| Exact supported environment | `BROKER_PROFILE.md`, `ENVIRONMENT_ATTESTATION.md` | CORRECTED SUCCESSFUL RUN OBSERVED — build 6180 / Exness-MT5Trial6 / Demo / HEDGING / XAUUSD |
| Durable pre-send correlation | `CORRELATION_IDENTITY_DESIGN.md`, NC-14 | RUN-SCOPED / NON-AUTHORITATIVE linkage; cardinality-1 prevents selectivity proof; durable authority unproven |
| request_id session-local only | correlation study, NC-14 | COVERED OFFLINE |
| Magic semantics unchanged | correlation study, source scan | MATERIALIZED FROM ONE SSOT; ownership/admission/claim semantics preserved |
| Magic governance controls | NC-16–NC-19, `F0_MAGIC_GOVERNANCE_PROPOSAL.md` | F0 MATERIALIZED / OFFLINE CONTROLS; no send authority |
| Retcode classes R0–R5 | `RETCODE_CLASSIFICATION.md`, NC-02/03 | Retcode 10009 observed once and later confirmed by positive query evidence; no universal mapping |
| Sync acceptance not confirmation | NC-02 | COVERED OFFLINE |
| Callback order/absence non-authoritative | transaction profile, NC-04/06/07 | COVERED OFFLINE; zero callbacks observed after local rejection, still non-authoritative |
| Query incomplete differs from empty | query profile, NC-05/13 | Build-6182 positive controls PASS for tested windows/filters/depths; every query remains `UNPROVEN` |
| Clock/watermark profile | clock measurement | One 110.976-second positive visibility sample; watermark/guarantee unproven |
| Timeout is not negative evidence | negative-evidence policy, NC-03 | COVERED OFFLINE |
| Read-only historical visibility across reconnect | build-6182 positive-control probe | Known entry/cleanup order/deal survived; no transient under-reporting observed; open-position/unresolved reconnect unproven |
| HEDGING mandatory | environment probe, NC-12 | OBSERVED ON DEMO build 6180 |
| Stale owner/spec fail closed | NC-09/11 | COVERED OFFLINE |
| Broker double remains dumb | NC-08 | COVERED OFFLINE |
| Pending orders excluded | source verifier | COVERED STATICALLY |
| Tester cannot replace Demo | divergence matrix, NC-15 | COVERED OFFLINE |
| Physical broker behavior | raw attended-Demo evidence | One successful market BUY and separate manual cleanup observed; broader behavior unproven |
| Trading-permission preflight | corrected probe, NC-20–NC-24, source scan | All four permissions observed true before the sole successful `OrderSend` |
| Frozen contract sufficiency | correlation/query/negative-evidence gates | INSUFFICIENT FOR RETRY OR PHASE F — Fusion decision required |
