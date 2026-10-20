# Remaining non-Governance native failures — review hold

NON-GOVERNANCE NATIVE FAILURES STILL OPEN — FUSION REVIEW REQUIRED
## Scope and safety

Current branch: sprint5-phase-f-entry-contract.
HEAD: d926f2e6b1aa4ea7b4b0936293d2fa47a2ce7ba8.
HEAD tree: 46c09cfbed423df9c93b7f63aaf4b901af5b83fd.
main: 32b79ca71ffc331e15e48a57c52be1352e3dbe7e.

The existing draft was preserved. No terminal/tester was launched, no A was
requested/pressed, no installed binary/preset was replaced, no deployment DB
or old clone was written, and no commit/push/merge occurred. MetaEditor was used
only to compile the non-native assertion manifest and attended wrapper.
No native rebuild/handoff is authorized by this report.

## 1. Governance alias fix locked

Governance source SHA256 remains:
5C0FB4E933A833BB0C4DADD43E84B1683D57A163D5F532276C2E060D378E642A

The preserved local prior row is copied before output clearing, used for exact
CAS comparisons, and exact readback remains required. Ordinary Load(now) and
GovernanceValid source bodies remain equal to canonical HEAD.

The actual MQL fixture now has separate immutable-donor clones for:
- GOV_CLOCK_EXACT_ACCEPTED_EVENT_REFRESH_DISTINCT_CAS
- GOV_CLOCK_EXACT_ACCEPTED_EVENT_REFRESH_ALIASED_CAS

Both require CAS +1, accepted event/time/sequence, finite validity and ordinary
Load/readback success. They are compiled test logic, NOT executed MQL results.

## 2. Exact physical CLOCK/PENDING triage

Immutable donor:
C:\Users\Nutthakrit\AppData\Roaming\MetaQuotes\Terminal\Common\Files\TEST_ONLY_MVP_CONTINUATION_3f39a13e0c314df2bcd8452ae9de5e4c.sqlite

Original/donor SHA256:
BEC62E7435D29D5511A41BF85C74AE443994C5804B3A9574AF90D861FE674EF6

Both old failed clones were inspected mode=ro&immutable=1, query_only=ON.
Their WAL had no uncheckpointed data; no old clone was reused or restored.

| Existing clone | Rows | Donor clock sequence/time | Current clock sequence/time | Other rows |
|---|---:|---|---|---|
| TEST_ONLY_MVP_CONTINUATION_3f39a13e0c314df2bcd8452ae9de5e4c.sqlite.RESUME_CLOCK.sqlite | 26 | 3 / 1791814007 | 5 / 1791882923 | All other 25 rows byte/logically exact |
| TEST_ONLY_MVP_CONTINUATION_3f39a13e0c314df2bcd8452ae9de5e4c.sqlite.BOUND_PENDING.sqlite | 26 | 3 / 1791814007 | 4 / 1791882920 | All other 25 rows byte/logically exact |

The only changed key is MVP_OWNERSHIP_LEASE / LEASE_CLOCK_CURRENT. Clock payload
digest, physical CAS token, row state/revision/time, clock identity and
broker/server/account/symbol bindings validate. Ownership, Trust and Governance
remain original/expired; Hard Kill remains the old INACTIVE, Basket IDLE/v1,
RequestSet empty, and no new execution-authority row exists.

This is evidence AGAINST classifying clock advancement itself as corruption.
The old generic CONTINUATION_PRE_STATE_INVALID log does not identify which
predicate failed. Physical state alone cannot recover the sampled native profile
or its observation timestamp. A profile/time mismatch is a hypothesis, not an
established original failure reason.

## 3. Diagnostics preserve strict behavior

RuntimeAuthority/SW_V5_S5_MvpAttendedContinuation.mqh:276 now evaluates the same
pre-state predicates in their original short-circuit order, but names the first
failed boundary. The strict profile time equality remains at :281. A mismatch
logs both accepted_at and profile_at, without login or execution authority.

Possible reasons now distinguish INPUT, FRESH_ACCEPTED_CLOCK, OPERATOR_EVENT,
PROFILE_CAPTURE, PROFILE_EVENT_TIME, DEMO_PROFILE, STORE, OWNERSHIP_PHYSICAL,
OWNER_IDENTITY, TRUST_PHYSICAL, ACCOUNT_PHYSICAL_PROFILE, GOVERNANCE_STRUCTURAL,
GOVERNANCE_SCOPE, GOVERNANCE_REFERENCES and HARD_KILL_PHYSICAL.
No freshness tolerance, expiry bypass, new eligibility route or retry was added.

## 4. CLOCK resume authority/event model — still open

Choice B is the behavior already implied by the production wrapper:
new explicit A -> consume latch -> new current-symbol OnTick publication ->
operator authenticated_at = that accepted clock -> continuation mutation.
The test clone's sequence 3 -> 5 confirms the old test published twice; it did
not reopen the first durable observation as event-fresh clock authority.
The production wrapper resets its latch only on an explicit new attachment and
does not retry automatically. It was not executed.

The current test CLOCK interruption (:104 in the assertion helper) writes only
the clock, then changes result/stage in memory. There is NO durable continuation
CLOCK-stage record and NO durable complete prior-row snapshot. The physical
clock's opaque platform_observation_id is not a full prior-inventory binding or
a persisted fresh-A acknowledgement.

Therefore a new production resume flag or a TEST_ONLY donor comparison would
NOT satisfy the requested durable proof. A continuation-only structural mode
with durable stage/prior-snapshot validation has NOT been implemented/authorized
by an unverified inference in this patch. That remains a development/model gate,
not a reason to weaken the existing validator or reuse historical clock authority.

The new MQL ClockOnlyPartial helper (:58) is explicitly TEST ONLY and read-only.
It verifies physical clock readback, monotonic sequence/time, exact identity and
every other row, but cannot grant production resume authority. Resume fixtures
now require the exact TEST_INTERRUPTION_CLOCK reason rather than any partial
failure, and record the physical clock-only state before proceeding.

## 5. Boundary fixture precision

Actual MQL test logic, not a substituted Python result, now requires:
- stop reason PARTIAL_CONTINUATION/TEST_INTERRUPTION_FLAT, with Hard Kill ACTIVE;
  or PARTIAL_CONTINUATION/TEST_INTERRUPTION_PENDING, with RELEASE_PENDING;
- a durable typed flat record and valid activation/history lineage;
- ordinary fresh Governance validity plus physically valid row;
- complete bound-row validation BEFORE the test mutation.

An earlier PRE_STATE or Governance failure cannot count as boundary success.
BOUNDARY_INTENDED_STAGE_AND_FRESH_BINDING_PROVEN must pass first.

The mutation changes ONLY Governance CURRENT logical_revision +1 and derived
store token. Payload, payload digest, state and original updated_at are preserved.
Preserving updated_at is important: changing it to a later wall-clock value could
invalidate the new structural refresh check, causing a false-positive rejection.

The fixture rereads via ordinary Governance Load at the same frozen context,
compares every store row and requires exactly one changed row. Then it proves
activation/history and physical invariants STILL pass while bound-row validation
fails. Only then does it invoke the actual StageContinuationPending or
PersistApprovedContinuationRelease, require false and exact unchanged Hard Kill,
and print CONTINUATION_BOUNDARY_REJECTION|...|STALE_BOUND_AUTHORITY.

Neither production boundary nor CAS/snapshot guard was loosened. The assertions
are compiled, but no post-fix MQL execution verdict is claimed.

## 6. Available offline execution versus MQL-local execution

New read-only/Python-model/source checks: 82/82,
0 failed. MQL execution count: 0.

They include the real persisted failed-copy layouts, rejection of an additional
mutation to EACH of the other 25 rows per clone, monotonic/foreign clock
negatives, source checks of meaningful boundary/alias/partial assertions,
one-event operator binding, locked Governance behavior and preservation hashes.

The previous verifier was rerun: 53/54.
Its one failed gate is PROVENANCE/compiled-not-older-than-includes.
This correctly says the native binary predates current includes; it is NOT
waived or relabeled PASS. Previous Python/SQLite Governance oracle/static
mutation checks ran; none substitutes for MQL interface execution.

There is no standalone EX5 runtime in the repository/tooling. MetaEditor
compiles; the provided Verify-ContinuationOffline.ps1 executes MQL by starting
terminal64.exe /config with Strategy Tester and refuses an existing terminal.
Running that path would violate the explicit no-MT5 instruction. It was not run.

Minimum real-MQL assertions still needed, only after Fusion resolves the hold:
1. CLOCK injection: only clock advances; exact all-other-row snapshot; valid
   durable stage lineage before any second publication; fresh-A/new event bound
   consistently; actual Run succeeds (or reports the exact first failed predicate).
2. FLAT and PENDING injections: actual requested stop reason and physical stage,
   valid fresh Governance/binding before mutation.
3. Revision-only Governance mutation: ordinary validity remains true; lineage/
   physical invariants remain true; actual release boundary rejects stale binding;
   Hard Kill and all other rows remain unchanged.
4. Execute distinct and aliased Governance regressions, flat binding,
   generation/history, partial visibility, compiled transport trap and later-tick
   actual PREFLIGHT result with complete-store equality.

No operator run/press-A request is made by this minimum-assertion specification.

## 7. Compile and native install held

Non-native syntax builds, MetaEditor X64 Regular:

- SW_V5_S5_MVP_ATTENDED_AUTHORITY_CONTINUATION: Result: 0 errors, 0 warnings, 1072 ms elapsed, cpu='X64 Regular'; EX5 SHA256 8B32905AE55A757F3B0E469C0BB5F8EC6C3A160F05A20928EBCD935087631B61
- SW_V5_S5_MVP_CONTINUATION_ASSERTIONS: Result: 0 errors, 0 warnings, 28037 ms elapsed, cpu='X64 Regular'; EX5 SHA256 C75D193ECE44B405D82AB930CF51E0942D1E472CAFDF2A80D79A81EF5342674D

Native harness was NOT rebuilt because sections 1-6 are not green.
Installed native EX5 remains the old executed artifact:
B70132E9D5BA2CF2882971FBAD5DA1DD2D752A9FF83E1529FD00891DE1557C09

Repository native EX5 is the earlier, now-stale Governance-patch build:
845E2764B0A9E229E282B41132782D6928E1D744DA1F2C30D281771BEB10769F

They are NOT identical. No identical-current-build claim, installation or
second-run approval is issued. Do not use either as the current candidate.
The prior 73/73 pre-run safety package is not valid for the current source.

Current core SHA256: CBF35E578A629E5103B916B6E7CE1610EDC6DFA439288C8799EAE660313B1CD4
Current assertion helper SHA256: FF8B8802A7656D7D1179891790B9883C5AC2AB93D1DFD1832F085032795E8B01
Current 85-include source digest: 09bc36d026d56c3bde1a39515c8e20605401cd11936e37b9e9d2c4b6f5df4aba

## 8. Fresh target plan only

New planned run ID: 695684156024459685b689f9d0c38955
New planned target: C:\Users\Nutthakrit\AppData\Roaming\MetaQuotes\Terminal\Common\Files\TEST_ONLY_MVP_CONTINUATION_695684156024459685b689f9d0c38955.sqlite

It does not exist; DB/WAL/SHM/preset were not created. Future clones must use
the hash-verified immutable donor, never prior MAIN/resume/negative clones.
Existing targets remain refused. Preparation/install/full new pre-run gate
are deferred, not silently performed. No new preset SHA or operator handoff exists.

## 9. Files changed in this follow-up

- RuntimeAuthority/SW_V5_S5_MvpAttendedContinuation.mqh: first-failure diagnostics
  only; original validation conditions/order retained.
- Tests/Sprint5MvpContinuation/SW_V5_S5_MvpContinuationAssertions.mqh: distinct/
  aliased regression fixtures; exact partial stops; clock-only structural test;
  meaningful before/after boundary evidence and valid revision-only mutation.
- verify_non_governance_failures.py, NON_GOVERNANCE_FAILURE_EVIDENCE.json,
  this report, and current-status addendum in IMPLEMENTATION_STATUS.md.
- Regenerated non-native .ex5/.log artifacts only, not installed.

Governance header, existing Ownership/SQLite/ADR changes and all other prior
draft edits were preserved. Frozen contracts, Signal/Decision, native quote
binding, ordinary Governance/PREFLIGHT/D1/D6 and Broker source were unchanged.
git diff --check passes. Working tree remains intentionally uncommitted/dirty.

NON-GOVERNANCE NATIVE FAILURES STILL OPEN — FUSION REVIEW REQUIRED
