# Sprint 5 Phase E Integrated Fixture Contract

TEST ONLY / NOT FOR PRODUCTION / NO BROKER ACCESS.

Status: Phase E specification. It grants no production authority and changes no
frozen Phase B/C/D or ADR semantics.

## Source pins

| Source | Immutable authority |
|---|---|
| Production Contract V5 | merged audited package `87f77c8b0b9253c2a851540085f8b7ce14cf2e52` |
| Sprint 5 Architecture / ADR-020 | `31e76411829e2f2e6acb24740ddca32b886969e0` |
| Phase B | `1366edb25238463c9a76fa78257196dbf4c64e34` |
| Phase C | `55cd230ca222c60cd42dd218efe5e175ba70acd6` |
| Phase D | `f0434d0e84907b1d454deec0abb899c16b35cd35` |

## Scenario schema

Every scenario declares literal fields: `id`, `group`, `invariants`,
`phases_crossed`, `authorities`, ordered `events`, `expected_outcome`,
`expected_broker_count`, and optional `expected_restart_disposition`. Values are
goldens written in the scenario; expectations may not be computed from harness
state or implementation output.

An event declares `ordinal`, `kind`, `authority_clock`, `owner_epoch`,
`fault`, and optional scripted broker outcome. Event order is fixed input, not
authority.

Observed output contains only actual disposition, broker count, durable summary,
restart disposition, and trace. A result collector compares these observations
with the literal scenario goldens. It does not decide a desirable state.

## Authority inventory

- authoritative injected clock: sole current liveness/expiry authority;
- frozen Producer Trust and Hard Kill records;
- accepted Ledger record and namespace Request Sequence reservation;
- Production V5 Request, Risk Authorization, Permit, and Admission Snapshot;
- existing Invocation Claim record (`COMMITTED_NOT_INVOKED` to
  `INVOCATION_CLAIMED_UNRESOLVED`);
- existing Phase-D Lease/fence, Request Set, Checkpoint, Broker summary,
  Execution summary, and reconciliation result;
- durable publication CAS/readback state.

The deterministic scheduler is a **NON-AUTHORITATIVE TEST SCHEDULER**. Safety
logic receives only ordered events and injected authority objects; it may not
read scheduler state as authority.

## Frozen ADR-020 binding

P is the equal ADR-019 stable point, initially provisional. P becomes the same
uninterrupted operation's Policy Admission Linearization Point if and only if
that operation later successfully wins Invocation Claim. Claim failure means P
never becomes effective. Hard Kill or explicit Trust revocation before P blocks;
a mutation after P does not retroactively cancel the same uninterrupted operation
that completes Claim, but blocks later increasing work. Claim-time time validity,
Risk expiry and current ownership/Lease liveness remain mandatory.

No second policy decision, intent record, intent journal, invocation fence, or
uncertainty state may exist between Claim and the fake broker.

## Test-double rules

The fake broker counts and logs every invocation identity, then returns only its
scripted ACK, REJECT, or UNCERTAIN outcome. It never deduplicates, retries,
normalizes, repairs, infers, or suppresses calls.

The fake store uses the existing Phase-D semantics. It does not sort, deduplicate,
repair, normalize, auto-complete, or auto-reconcile. Assertions use authoritative
durable readback. A stale fence fails even for byte-identical content.

Persisted historical timestamps are evidence only. Future-dated persisted data
never extends Lease, Trust, Risk, or Permit validity against the one injected
current clock.

## Integrated outcome rules

- WAIT/BLOCKED creates no increasing Request, Permit, Claim, or broker call.
- successful Claim yields one event-local `CLAIM_GRANTED_NOW` and durably retains
  only `INVOCATION_CLAIMED_UNRESOLVED`; restart never recreates the grant.
- zero-history ACQUIRED and RENEWED are both valid when all frozen predicates pass.
- publication is `PROPOSAL_VALID` until successful CAS and exact authoritative
  readback, then `COMMITTED`; split, stale, uncertain, or mismatched publication
  never self-repairs.
- current Claim fencing and durable fenced CAS are the only ownership enforcement
  points; fixtures introduce no third ownership authority.
- Phase-C to Phase-D disposition mapping is total and fail-closed; there is no
  default-success branch and no new authority enum.
- individually valid Checkpoint, Request Set, Broker summary and Execution summary
  from different worlds must fail through the existing Phase-D validation path.

## No-new-authority rule

Fixtures may build, inject, mutate, reseal, observe, and compare existing frozen
objects. They may not add a production validator, durable domain, policy enum,
state, or authority. Discovery of a validly sealed incoherent world accepted by
the existing Phase-D path blocks Phase E rather than authorizing a fixture-only
fix.
