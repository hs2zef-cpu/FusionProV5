# Sprint 5 Phase F0 Authorization Status

Date: 2026-09-04

## Decision

**PHASE F0 — AUTHORIZED FOR PROFILE/EVIDENCE WORK ONLY**

**PHASE F — IMPLEMENTATION NOT AUTHORIZED**

Phase E remains **CLOSED / PASS** at governance closure
`36f6017e17fac75aad1b1b92dc90065fed0cf9b1`. Phase F0 is limited to an exact
broker/platform profile, evidence-contract design, measurement, isolated
test-only probes, deterministic offline adversarial harnesses, and assessment of
whether frozen contracts are sufficient for a later Phase F decision.

Attended Demo measurement/probe scripts may be used solely for empirical F0
profiling after the environment is positively attested as Demo and HEDGING. This
does not authorize a Phase-F Broker Adapter or general trade execution path.

## Explicit prohibitions

- Production Broker Adapter: **NOT AUTHORIZED**
- General trade execution path: **NOT AUTHORIZED**
- Live/real-money account: **PROHIBITED**
- Production VPS: **PROHIBITED**
- Unattended Demo: **NOT AUTHORIZED**
- Phase G: **NOT AUTHORIZED**
- Architecture Lock: **NOT GRANTED**
- Merge into `main`: **NOT AUTHORIZED**
- Production/runtime readiness: **NOT GRANTED**

Every broker-invoking probe must be clearly marked F0 / TEST / DEMO ONLY,
operator-triggered, minimal volume, isolated from production dependencies, and
incapable of recurring or signal-driven trading. If Demo/HEDGING status,
isolation, query completeness, safe correlation, or authoritative negative
evidence cannot be proven, F0 must stop for Fusion adjudication.
