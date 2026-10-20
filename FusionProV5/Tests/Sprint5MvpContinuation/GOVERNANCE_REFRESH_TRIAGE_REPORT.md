# Governance refresh native failure triage — uncommitted candidate

## Disposition

GOVERNANCE REFRESH STILL BLOCKED — FUSION REVIEW REQUIRED
The confirmed Governance CAS alias defect is corrected in source, but this is
not a post-fix native PASS. No MT5/native harness/tester was started in this run.
Existing terminal PID 13128 was preserved. No press-A request, commit or push.

## 1. Confirmed root cause

RefreshCurrent did **not** require the old Governance bundle to be eligible at
current time before refreshing it. It evaluated historical structure at
current.valid_from. In the actual operator run, the distinct-input/output
GOV_CLOCK_EXACT_ACCEPTED_EVENT_REFRESH assertion passed at native time
1791882917, refreshing the expired 1791817607 record to 1791886517.

The core call passes the same row as expected_row and committed. The prior
RefreshCurrent initialized committed with ZeroMemory before comparing
expected_row. Both references alias, so that initialization erased the caller's
prior CAS revision/token/digest/state. The physical nonzero row then mismatched.
The .MAIN SQLite readback confirms Ownership/Trust advanced to revision 2 at
1791882921, while Governance remained revision 1, expiry 1791817607, and Hard
Kill remained its old INACTIVE state. The standalone .GOV_CLOCK clone contains
Governance revision 2. This rules out old expiry as the first Governance cause.

## 2. Exact source changes

- RuntimeAuthority/SW_V5_S5_MvpReconciliationGovernanceAuthorities.mqh:252:
  private LoadCurrentStructural, callable only by RefreshCurrent (:322).
  It verifies canonical decoding/re-encoding, all relevant versions and policy
  digests/IDs/versions, exact encoded profile/account/namespace, derived store
  namespace, row state/revision/digest/CAS token/time, approval/proof references,
  fixed capability values, nested policy links and canonical bundle identity.
  Historical finite validity is inspected at its origin, never granted as
  current eligibility.
- Same header :304: value-copy prior_expected_row before ZeroMemory(committed).
  All eight prior row fields are compared. Fresh accepted event/operator binding,
  finite lifetime, guarded CAS +1 and capabilities/profile/policy preservation
  remain enforced. Readback (:366) now compares full committed row semantics.
- SW_V5_S5_MvpContinuationAssertions.mqh: positive tests explicitly cover prior/
  output alias plus ordinary expired Load rejection and exact refreshed Load
  readback; separate corrupt canonical row, re-digested capability coercion,
  policy-version and profile-negative assertions were added.
- Boundary interruption (:243) must report exactly the requested FLAT/PENDING
  interruption, not just any partial error. No release/snapshot/CAS guard changed.
- Clone (:35) rejects existing targets/sidecars and verifies copied SHA. All
  mutable cases use a fresh per-run prefix (:280); donor m_copy is unchanged.
- Prepare-NativeContinuationCopy.ps1 copies only the specified immutable donor,
  not the original DB or a previously mutated clone. This helper was not run.
- New verify_governance_refresh.py, generated evidence JSON and this report;
  IMPLEMENTATION_STATUS.md records the failed native run and current limitations.

## 3. Ordinary expiry semantics

Load(now) (:436) and SWV5S5_MvpGovernanceValid (:214) are source-body identical to
canonical HEAD. Expired Governance still fails PREFLIGHT/D1/Admission/Claim and
ordinary eligibility. The structural loader is private, has one production
call inside RefreshCurrent, and ordinary Load never calls it. Refresh success
still requires ordinary Load at the newly accepted current event time.

## 4. Boundary fixture result

Before fix: ACTIVE/FLAT BOUNDARY_INTERRUPT was a false-positive partial-failure
check; no flat row existed. Its mutation assertion failed. The PENDING fixture
did not even renew Ownership/Trust, so its earlier failure cannot be attributed
to Governance without additional evidence.

After fix: the independent Python/SQLite in-memory oracle proves a valid fresh
Governance row can be CAS-refreshed/read back, subsequently revised, and that
the captured complete snapshot is then stale. This is **not** execution of the
MQL StageContinuationPending/PersistApprovedContinuationRelease methods.
The strengthened real-MQL boundary fixtures compile but have not run; their
post-fix release-rejection verdict remains PENDING.

## 5. Every prior native failure

A = direct observed Governance-refresh failure.
B = downstream missing refreshed Governance/continuation authority.
UNRESOLVED = evidence contradicts a blanket Governance-cascade claim.

Counts: A=8; B=8; UNRESOLVED=3.
It would be incorrect to force the unresolved cases into A or B.

| # | Failed assertion | Classification | Evidence/reason |
|---|---|---|---|
| 1 | BOUNDARY_MUTATE_VALID_GOVERNANCE_ROW (ACTIVE/FLAT) | B | Downstream: continuation never obtained refreshed Governance/ACTIVE/flat release authority. |
| 2 | BOUNDARY_INTERRUPT | UNRESOLVED | Stopped before Governance refresh (PRE_STATE/no lease renewal). Raw evidence lacks exact failed predicate; do not invent a causal classification. |
| 3 | BOUNDARY_MUTATE_VALID_GOVERNANCE_ROW (PENDING) | UNRESOLVED | PENDING fixture never renewed Ownership/Trust; failure precedes Governance refresh, not proven to be its cascade. |
| 4 | REAL_SQLITE_CONTINUATION_COMPLETE | A | Run detail stops at GOVERNANCE_REFRESH / GOVERNANCE_FAILED; alias destroys prior row before CAS validation. |
| 5 | MONOTONIC_GENERATIONS | B | Downstream: continuation never obtained refreshed Governance/ACTIVE/flat release authority. |
| 6 | TWO_BROKER_OBSERVATIONS_ZERO_SUBMISSION | B | Downstream: continuation never obtained refreshed Governance/ACTIVE/flat release authority. |
| 7 | COMPLETED_REPLAY_READBACK_ONLY | B | Downstream: continuation never obtained refreshed Governance/ACTIVE/flat release authority. |
| 8 | PARTIAL_NOT_HIDDEN_AFTER_ACTIVE | B | Downstream: continuation never obtained refreshed Governance/ACTIVE/flat release authority. |
| 9 | RESUME_CLOCK | UNRESOLVED | Stopped before Governance refresh (PRE_STATE/no lease renewal). Raw evidence lacks exact failed predicate; do not invent a causal classification. |
| 10 | RESUME_HEARTBEAT | A | Run detail stops at GOVERNANCE_REFRESH / GOVERNANCE_FAILED; alias destroys prior row before CAS validation. |
| 11 | RESUME_TRUST | A | Run detail stops at GOVERNANCE_REFRESH / GOVERNANCE_FAILED; alias destroys prior row before CAS validation. |
| 12 | RESUME_GOVERNANCE | A | Run detail stops at GOVERNANCE_REFRESH / GOVERNANCE_FAILED; alias destroys prior row before CAS validation. |
| 13 | RESUME_ACTIVE | A | Run detail stops at GOVERNANCE_REFRESH / GOVERNANCE_FAILED; alias destroys prior row before CAS validation. |
| 14 | RESUME_FLAT | A | Run detail stops at GOVERNANCE_REFRESH / GOVERNANCE_FAILED; alias destroys prior row before CAS validation. |
| 15 | PARTIAL_PENDING | B | Downstream: continuation never obtained refreshed Governance/ACTIVE/flat release authority. |
| 16 | RESUME_PENDING | A | Run detail stops at GOVERNANCE_REFRESH / GOVERNANCE_FAILED; alias destroys prior row before CAS validation. |
| 17 | RESUME_RELEASED | A | Run detail stops at GOVERNANCE_REFRESH / GOVERNANCE_FAILED; alias destroys prior row before CAS validation. |
| 18 | RESUME_INACTIVE | B | Downstream: continuation never obtained refreshed Governance/ACTIVE/flat release authority. |
| 19 | LATER_NATIVE_TICK_PREFLIGHT_COMPLETE_ZERO_SUBMISSION | B | Downstream: continuation never obtained refreshed Governance/ACTIVE/flat release authority. |

The exact first failing PRE_STATE predicate for RESUME_CLOCK and BOUND_PENDING
is not present in the raw log. A native-time/profile rollover is a hypothesis,
not a verified cause. No clock/Ownership/frozen validation semantics were changed
to guess away these failures.

## 6. Offline/static/mutation evidence

54/54 checks passed; 0 failed.
Classes are recorded per assertion in GOVERNANCE_REFRESH_TRIAGE_EVIDENCE.json.

These include read-only fixture integrity, static reachability/expiry/source
checks, a reference alias model, an independent SQLite **in-memory** Governance
oracle (expired refresh; corrupt/profile/capability/policy negatives; exact CAS
and readback; stale CAS; valid bound-row mutation/stale snapshot), and source
isolation/one-shot/early refusal tests.

Five mutated source strings were detected without editing runtime source:
MC-GOV-EXPIRED-ELIGIBILITY-BYPASS, MC-GOV-STRUCTURAL-PUBLIC,
MC-GOV-PRIOR-ALIAS, MC-GOV-CAS-BYPASS, MC-GOV-READBACK-BYPASS.
These are static mutation controls, not execution of compiled MQL mutants.

Exactly one unchanged production OrderSend site:
ExecutionLayer/BrokerAdapter/SW_V5_S5_F_BrokerPlatformBoundary.mqh:275.
Exactly one attended production HeartbeatAttended caller:
RuntimeAuthority/SW_V5_S5_MvpAttendedContinuation.mqh:334.
The test binary traps OrderSend/OrderSendAsync; its reachable administrative
and fixed MODE_PREFLIGHT paths do not issue D1/Ledger/Permit/Admission/Claim.
No timer/retry path was added. The original native run reported forbidden
transport calls=0 and original_unchanged=true; post-fix executions=0.

Experts: C:\Users\Nutthakrit\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Logs\20261013.log
SHA256: C112BF285FCBFC7EC0687A341ABE4B3D443D218AEA13929607AE726694B6F93E

Journal: C:\Users\Nutthakrit\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\logs\20261013.log
SHA256: 9E1247D79DFC0394D96A9EDB2A50F9F382B46044AEE44C87FA143DF7F1A6BD18

The JSON preserves the relevant native run text as a lossless Unicode export.
No old PASS was copied or relabeled as post-fix execution evidence.

## 7. Compile evidence

MetaEditor X64 Regular, all 0 errors / 0 warnings:

- SW_V5_S5_MVP_ATTENDED_AUTHORITY_CONTINUATION: Result: 0 errors, 0 warnings, 2350 ms elapsed, cpu='X64 Regular'; EX5 SHA256 58606926B28D91A2508F5C31CAEFA8660527E2FDA26C3D1873EEED4255EBE9F0
- SW_V5_S5_MVP_CONTINUATION_ASSERTIONS: Result: 0 errors, 0 warnings, 28066 ms elapsed, cpu='X64 Regular'; EX5 SHA256 0EC746E07ADB14730707E61B122554CBEF3155890C483636B0D418017EB33FB6
- SW_V5_S5_MVP_CONTINUATION_NATIVE_COPY_ASSERTIONS: Result: 0 errors, 0 warnings, 26983 ms elapsed, cpu='X64 Regular'; EX5 SHA256 845E2764B0A9E229E282B41132782D6928E1D744DA1F2C30D281771BEB10769F

The repository builds are new; the installed native binary and preset were
not replaced. Their previous identity must not be represented as this build.

## 8. Exact fresh TEST_ONLY fixture/copy plan

Immutable donor:
C:\Users\Nutthakrit\AppData\Roaming\MetaQuotes\Terminal\Common\Files\TEST_ONLY_MVP_CONTINUATION_3f39a13e0c314df2bcd8452ae9de5e4c.sqlite

Donor and original remain 81920 bytes with SHA256:
BEC62E7435D29D5511A41BF85C74AE443994C5804B3A9574AF90D861FE674EF6

A zero-byte donor WAL and 32768-byte donor SHM left by the earlier native
read-only open were observed; neither was deleted. No uncheckpointed WAL data
was used or guessed. The original DB was only hashed; no original SQL writes.

No fresh on-disk mutable copy was created or launched after this correction.
After Fusion disposition, the preparation helper can create a unique
TEST_ONLY_MVP_CONTINUATION_<new-guid>.sqlite donor copy, hash-checked against
the preserved donor. The suite creates:
TEST_ONLY_MVP_CONTINUATION_RETEST_<native-TimeCurrent>_<microsecond-id>
with .MAIN/.GOV_CLOCK/.GOV_NEG_n/.HB_NEGATIVES/.OP_n/.BOUND_ACTIVE/
.BOUND_PENDING/.NEG_n/.RESUME_<stage> .sqlite suffixes.
Every target must be absent before copying; every initial clone must match the
donor hash. No earlier .MAIN or interruption/resume clone may be reused.

## Repository/provenance

Branch sprint5-phase-f-entry-contract.
HEAD d926f2e6b1aa4ea7b4b0936293d2fa47a2ce7ba8.
HEAD tree 46c09cfbed423df9c93b7f63aaf4b901af5b83fd.
main 32b79ca71ffc331e15e48a57c52be1352e3dbe7e, unchanged.
Existing uncommitted draft preserved; working tree intentionally dirty.
git diff --check passes. No frozen contracts, Signal/Decision, ordinary
PREFLIGHT/D1/D6 or Broker Adapter source was edited by this correction.
No deployment mutation, Claim, OrderSend, native rerun, commit, push or merge.

GOVERNANCE REFRESH STILL BLOCKED — FUSION REVIEW REQUIRED
