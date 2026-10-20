# RESUME_CLOCK diagnostic preparation / Option R adjudication

Date: 2026-10-13. Uncommitted candidate, not an execution PASS.
Branch: `sprint5-phase-f-entry-contract`.
Base HEAD: `d926f2e6b1aa4ea7b4b0936293d2fa47a2ce7ba8`.
Base tree: `46c09cfbed423df9c93b7f63aaf4b901af5b83fd`.
Main: `32b79ca71ffc331e15e48a57c52be1352e3dbe7e`.

## 1. Exact reproduced predicate

NOT REPRODUCED. The previous operator-run Experts log is
`C:\Users\Nutthakrit\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Logs\20261013.log`.
Line 59 records only
`CONTINUATION_RESUME_DETAIL|CLOCK|PRE_STATE|CONTINUATION_PRE_STATE_INVALID`.
Line 105 records 60 passed / 19 failed / 0 skipped / 79 total.
This old binary did not log the failed predicate. Read-only clone differences
cannot establish that predicate. No fresh reproduction clone was created and
no new MQL/native run occurred. Profile/event-time equality is retained; it is
not asserted to be the actual cause. No old-deployment-baseline clock equality
predicate was identified, so no fictitious baseline-equality reason was added.

## 2. Option R disposition

WITHHELD. Fusion selected R conditionally, not as an unconditional patch.
There is no durable CLOCK checkpoint, write-ahead intent, new domain/DTO,
allowlist entry, CURRENT pointer, clock/checkpoint atomic pair, second clock
publisher or durable completion marker. Ordinary durable clock publication is
unchanged. No authority-row binding or execution eligibility was relaxed.

## 3. Source changes in this diagnostic step

- RuntimeAuthority/SW_V5_S5_MvpOwnershipAuthority.mqh:264 adds a read-only
  `CurrentFreshObservationDiagnostic`. It distinguishes local freshness,
  missing/read/physical/decode/identity/authority/time/sequence/canonical/digest/
  store-token/event binding failures. Ordinary clock validation/publication
  bodies are unchanged from HEAD.
- RuntimeAuthority/SW_V5_S5_MvpAttendedContinuation.mqh:89,118,292 splits
  continuation pre-state reasons for RequestSet/Basket/inventory and physical
  authority/profile/namespace/reference predicates. Conditions are preserved;
  the current profile/event-time check at line 299 is not relaxed.
- RuntimeAuthority/SW_V5_S5_MvpContinuationFlatAuthority.mqh:158 adds diagnostic
  inventory reasons while retaining the closed allowlist and Genesis checks.
- Both continuation assertion manifests record positively fired, named
  TEST_ONLY interruption hooks in volatile state.
- Tests/Sprint5MvpContinuation/SW_V5_S5_MvpContinuationAssertions.mqh adds exact
  interruption/state/later-row checks, prerequisite-failure rejection,
  mandatory actual invocation, paired accepting/rejecting boundary fixtures,
  zero-mutation denied PREFLIGHT checks and 14 clock-negative fixture cases.
- Tests/Sprint5MvpContinuation/verify_option_r_adjudication.py separates
  source-extracted Python predicate evaluation, static mutation controls,
  compile evidence and read-only hashes from actual MQL execution.
- This report, generated diagnostic evidence JSON and IMPLEMENTATION_STATUS.md
  record current limitations and supersede the checkpoint recommendation.

Other dirty draft edits predate this step and were preserved. The Governance
alias fix, activation/release boundaries and store snapshot implementation were
not changed in this diagnostic step. No frozen/Signal/Decision/Broker source
change was made.

## 4. Periodic continuation

Architecture analysis agrees with Fusion: a legitimate later infrastructure
clock alone must not permanently disqualify a future attended epoch. This does
not authorize bypassing actual authority-row predicates or rebuilding old
event-local freshness. R did not land, so the conditional epoch-1 / clock advance
/ expiry / epoch-2 fixture has not been implemented or executed. Periodic
closure is not claimed.

## 5. Boundary interruption

SOURCE PREPARED / COMPILED, NOT EXECUTION-VERIFIED.
ReleaseBoundaryCase (assertions header:337) requires the hook to fire and the
exact intended reason; an earlier prerequisite failure is a fixture failure.
It validates FLAT + ACTIVE or FLAT + RELEASE_PENDING, lineage/bound rows, absence
of later complete-release authority, and denied read-only PREFLIGHT with exact
row equality. No submission path is invoked. No new MQL PASS count is claimed.

## 6. Governance boundary differential

SOURCE PREPARED / COMPILED, NOT EXECUTION-VERIFIED.
Independent fresh donor-derived CONTROL/MUTATED copies share the same
configuration/identity/stage basis; each has its own genuine native event time.
They do not claim byte-identical native event clocks. The mutation advances
exactly Governance CURRENT revision/token while preserving payload/digest/state/
updated_at and proving ordinary validity. Lease read/decode failure fails the
fixture. Immediately before the actual boundary call, release_invoked becomes
true. PENDING invokes PersistApprovedContinuationRelease; ACTIVE separately
checks StageContinuationPending. Control must accept with exact readback;
mutation must reject without changing Hard Kill. Credit requires BOTH cases.

## 7. Governance alias regression

Fix preserved unchanged: copy prior row before ZeroMemory(output), exact prior
CAS, full committed readback; ordinary Load(now)/GovernanceValid expiry remains.
The prior old-native isolated distinct-output expired-Governance refresh PASS
does not prove the corrected alias fixture. New alias/distinct MQL fixtures are
compiled but not executed. Static preservation check passes.

## 8. Mutation / static evidence

Actual verifier output: OPTION_R_DIAGNOSTIC_EVIDENCE.json.
39 checks passed / 0 failed / 0 MQL executions. This includes 18 source-extracted
clock fixture comparisons with an independent Python ordinary-clock reference.
It is not a native resume reproduction or complete behavior equivalence proof.
Five static mutations detected (not compiled/executed MQL mutants):
MC-BOUND-INVOKED-BYPASS, MC-BOUND-INJECTION-FIRED-BYPASS,
MC-BOUND-CONTROL-CREDIT-BYPASS, MC-BOUND-MUTATION-TIME-INVALIDATES-GOVERNANCE,
MC-GOV-EXPIRED-ELIGIBILITY-BYPASS.
The MQL clock-negative table contains identity/profile/authority/canonical/
digest/store-token/zero/backward/duplicate/future cases; execution remains open.
The future-dated case tests ordinary publication rejecting until native time
catches up, not permissive acceptance of any newer row.
Exactly one production OrderSend site remains unchanged:
ExecutionLayer/BrokerAdapter/SW_V5_S5_F_BrokerPlatformBoundary.mqh:275.
Exactly one production HeartbeatAttended caller remains the attended continuation
path (SW_V5_S5_MvpAttendedContinuation.mqh:369). git diff --check passes.
Old verifier summaries are historical, not current expanded-suite PASS claims.

## 9. Compile

MetaEditor X64 Regular, compile only (no MT5 launch):

| Manifest | Errors | Warnings | EX5 SHA256 |
| --- | --- | --- | --- |
| SW_V5_S5_MVP_ATTENDED_AUTHORITY_CONTINUATION | 0 | 0 | F09B47E7FD25FD10D85D40AD9BCB8DE626523599E2AF2A0F59E0D11E37B8E31D |
| SW_V5_S5_MVP_CONTINUATION_ASSERTIONS | 0 | 0 | 96DBDC3897756DD4624893E4C98236D4A960ABC0DA8F147156A64125F131D18C |

Neither executable was installed or run. Compile does not close fixture behavior.

## 10. Native binary / preset

Native rebuild/install/new preset/full pre-run handoff is HELD. No new run ID or
fresh native reproduction clone was created. Installed old native EX5 remains
`B70132E9D5BA2CF2882971FBAD5DA1DD2D752A9FF83E1529FD00891DE1557C09`.
The pre-existing repository native EX5 is a different stale build
`845E2764B0A9E229E282B41132782D6928E1D744DA1F2C30D281771BEB10769F`;
it does not match the latest diagnostic source and was not rebuilt.
Only the old installed preset exists, SHA256
`61A8AC901CED3D3D9F352AE1D59D165191604FB3032F96EDD4CDF4D515AB4D4B`.
No operator run is requested or authorized by this report.

## 11. Original / donor integrity

Both remain 81920 bytes with SHA256
`BEC62E7435D29D5511A41BF85C74AE443994C5804B3A9574AF90D861FE674EF6`:

- Original: C:\Users\Nutthakrit\AppData\Roaming\MetaQuotes\Terminal\Common\Files\fusion_v5_mvp_demo_authority.sqlite
- Donor: C:\Users\Nutthakrit\AppData\Roaming\MetaQuotes\Terminal\Common\Files\TEST_ONLY_MVP_CONTINUATION_3f39a13e0c314df2bcd8452ae9de5e4c.sqlite

Original WAL/SHM absent. Donor WAL is 0 bytes; SHM is 32768 bytes, preserved from
the earlier operator native run. Original was file-hashed only, not opened with
SQLite. Donor predicate data was read with mode=ro&immutable=1 and query_only.
No database was mutated. Existing clone states are historical observations,
not proof of the exact unlogged predicate or a new reproduction.

## 12. Remaining blocker

Fresh TEST_ONLY predicate-level MQL RESUME_CLOCK reproduction remains mandatory.
It cannot be performed while complying with this step's prohibition on MT5
launch/execution. Without it, neither Outcome 1 nor Outcome 2 is proven.
New boundary differential/clock-negative/alias MQL execution also remains open.
No native handoff, commit, push, production action or main merge occurred.

RESUME_CLOCK ROOT CAUSE STILL UNPROVEN — FUSION REVIEW REQUIRED
