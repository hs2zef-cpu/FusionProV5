# Narrow native RESUME_CLOCK diagnostic — pre-run handoff

TEST ONLY / NOT FOR PRODUCTION / NO BROKER MUTATION / NO AUTHORITY GRANT.
Prepared 2026-10-13; **not executed**. Operator run approval is still required.
Option R remains WITHHELD. No checkpoint/R+/new authority domain was added.

## Source / build / installation

- Source:
  `C:\Users\Nutthakrit\Documents\FusionProV5\FusionProV5\Tests\Sprint5MvpContinuation\SW_V5_S5_MVP_CONTINUATION_RESUME_CLOCK_DIAGNOSTIC.mq5`
- Source SHA256:
  `57F964FD1CD34CD3FA5433A43401370E180AA6E46F14725ED4E750D55DC92D0C`
- Complete 61-file MQL dependency-source digest (sorted relative path + NUL +
  uppercase SHA256, LF-separated, then SHA256):
  `2A63F2695BA7A4E7E9005623D06002E234AA4C16B4D48E5A9ACDABD0EE32AF89`
- Compiled EX5:
  `C:\Users\Nutthakrit\Documents\FusionProV5\FusionProV5\Tests\Sprint5MvpContinuation\SW_V5_S5_MVP_CONTINUATION_RESUME_CLOCK_DIAGNOSTIC.ex5`
- Installed EX5 (NEW visible TEST_ONLY name):
  `C:\Users\Nutthakrit\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Experts\FusionProV5Tests\TEST_ONLY_SW_V5_S5_MVP_CONTINUATION_RESUME_CLOCK_DIAGNOSTIC.ex5`
- Compiled and installed SHA256, exact match:
  `FB38D8ED95A3FA38B0E3E9810B8D8F036C759DED20DE4020C5A1851FB1AF84DD`
- MetaEditor compile:
  `Result: 0 errors, 0 warnings, 7915 ms elapsed, cpu='X64 Regular'`
- The ordinary attended continuation wrapper and non-native full assertion
  manifest were recompiled: both 0 errors / 0 warnings, X64 Regular. They were
  not installed or executed by this step.
- Old installed full-suite EX5 remains unchanged:
  `B70132E9D5BA2CF2882971FBAD5DA1DD2D752A9FF83E1529FD00891DE1557C09`.

## Preset / target

- Preset:
  `C:\Users\Nutthakrit\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Presets\TEST_ONLY_RESUME_CLOCK_DIAGNOSTIC_9ee7fc055411445882dc75714db10333.set`
- SHA256:
  `0FB16EA0B36A4A41D5BB666A37A21F9F30AE6B70ADA8D41333D6129B51265B6D`
- Inputs:
  `explicit_test_only_marker=TEST_ONLY_RESUME_CLOCK_DIAGNOSTIC_NO_EXECUTION`
  `diagnostic_target_relative_path=TEST_ONLY_MVP_RESUME_CLOCK_DIAGNOSTIC_9ee7fc055411445882dc75714db10333.sqlite`
  `diagnostic_run_id=9ee7fc055411445882dc75714db10333`
  `operator_confirmed_diagnostic_only=true`
- Resolved future target:
  `C:\Users\Nutthakrit\AppData\Roaming\MetaQuotes\Terminal\Common\Files\TEST_ONLY_MVP_RESUME_CLOCK_DIAGNOSTIC_9ee7fc055411445882dc75714db10333.sqlite`
- Target, WAL, SHM and snapshot exports are all **absent before handoff**.
  The harness creates a new copy at execution; preparation did NOT create it.
  Existing artifacts cause rejection, never overwrite/reuse. Reload/re-attach
  after a run cannot reuse this target.
- Namespace remains:
  `58408af3c3381470aa50161762e4f1102eec5d214448495a79d732cd31d90d8c`.

## Original / immutable donor

- Original (hashed only; no SQLite connection):
  `C:\Users\Nutthakrit\AppData\Roaming\MetaQuotes\Terminal\Common\Files\fusion_v5_mvp_demo_authority.sqlite`
- Fixed donor:
  `C:\Users\Nutthakrit\AppData\Roaming\MetaQuotes\Terminal\Common\Files\TEST_ONLY_MVP_CONTINUATION_3f39a13e0c314df2bcd8452ae9de5e4c.sqlite`
- Both 81920 bytes, SHA256 unchanged:
  `BEC62E7435D29D5511A41BF85C74AE443994C5804B3A9574AF90D861FE674EF6`.
- Original WAL/SHM absent. Donor WAL 0 bytes, SHM 32768 bytes; preserved.
- Non-native donor inspection used mode=ro&immutable=1 plus query_only, confirmed
  26 rows and exact namespace. The harness refuses a nonempty donor WAL and
  verifies donor bytes before creating the new copy. It never opens the real DB.

## Pre-run evidence and isolation

Actual output is RESUME_CLOCK_NATIVE_DIAGNOSTIC_PRE_RUN_EVIDENCE.json, produced
by verify_resume_clock_diagnostic.py --require-installed:
**64 checks passed / 0 failed / 0 native executions**.

- Fifteen actual source-extracted pure-gate cases include production filename,
  missing/invalid marker, traversal, absolute path, wrong run ID, old clone and
  wrong extension refusals. These are non-native expression evaluations, NOT
  executed MQL refusal assertions. They do no file/database writes.
- Input refusal dominates all durable-write entry paths. OnInit/preset loading
  and OnChartEvent perform validation/read-only checks only. A is accepted once;
  OnTick consumes the latch before copy creation or ordinary clock publication.
  No timer, next-tick completion, retry or automatic resume is present.
- The harness includes the exact production-draft continuation class, not a
  copied Python/MQL classifier. TEST_ONLY preprocessing removes private Flat
  and the entire heartbeat/Trust/Governance/Hard Kill/release tail. Its store
  open is read-only; shared predicates and order are retained. Ordinary builds
  have no diagnostic endpoint and retain their existing execution semantics.
- The classifier's existing historical completed-readback flag grants no
  authority; the diagnostic success endpoint grants no authority either.
- Reachable class methods are structural/read-only: ReadCompletedOnly,
  ScopeOwner, ReadLease, ReadTrust, ReadGovernance, ResumeProofValid,
  EmptyExecutionAndBasketDiagnostic and RowsAllowedDiagnostic. The diagnostic
  harness never invokes Broker Adapter Submit, Sequence/Ledger/Margin/Risk/
  Permit/Admission/Claim or an authority refresh/transition method.
- Broker-related type/codec headers exist transitively; no Broker Submit/native
  transport path is invoked. Both OrderSend names are compile-time fail traps;
  the classifier's Broker observer is also a fail trap, never native dispatch.
- Exactly one production OrderSend site remains unchanged elsewhere:
  SW_V5_S5_F_BrokerPlatformBoundary.mqh:275. Exactly one ordinary production
  HeartbeatAttended caller remains in the attended continuation path, excluded
  from this diagnostic binary. Frozen, Signal/Decision, Broker Adapter and
  ControlledDemo source files were not changed by this step.
- git diff --check passes. MetaEditor was used only to compile. MT5 was not
  launched or controlled; the operator's existing terminal process was left
  untouched. No production wrapper or native EA was executed.

## Execution protocol encoded in the harness

1. Validate immutable donor hash, TEST_ONLY inputs, fresh XAUUSD/M15 Demo profile
   and exact native login against donor Ownership. Create a previously absent
   target only after one A and current native OnTick.
2. Read complete physical rows. Require clock, Ownership, Trust, Governance,
   Hard Kill, Account, Basket and RequestSet records plus no operational rows.
   Export exact complete row payloads to `.before.rows` as lossless UTF-8.
3. Publish exactly ONE clock through ObserveFromCurrentSymbolOnTick and its
   ordinary CAS/readback; positively log INTERRUPT_AFTER_CLOCK_PUBLICATION.
4. Close and destroy the publication object. Reopen snapshots from disk. Require
   clock sequence/revision +1, strictly later time, changed observation ID and
   all non-clock rows exact; export `.after.rows`.
5. Construct NEW clock/store/classifier objects; LoadStored read-only, never
   publish/reconstruct freshness. Call the exact shared Run classifier with
   its test-only mutating tail removed. Print stored clock fields, actual
   predicate comparison facts and the exact returned reason.
6. Require complete authority rows unchanged by classification and zero
   forbidden calls; export `.classified.rows`. COMPLETE means the diagnostic
   protocol succeeded, NOT continuation authorization or a baseline verdict.

The original full-suite Resume fixture invokes Execute again, which publishes
another fresh clock before Run. This new diagnostic deliberately does NOT do
that, as Fusion requested a cold-restart-only classifier. Consequently a cold
event-local-freshness rejection must be reported honestly; it must NOT be
presented as proof of an unlogged predicate from the earlier full-suite run.
No particular runtime result is claimed before execution.

## Operator steps — only after Fusion run approval

On the intended existing Exness-MT5Trial6 Demo XAUUSD M15 chart:

1. Select Navigator > Expert Advisors > FusionProV5Tests >
   `TEST_ONLY_SW_V5_S5_MVP_CONTINUATION_RESUME_CLOCK_DIAGNOSTIC`.
2. Load `TEST_ONLY_RESUME_CLOCK_DIAGNOSTIC_9ee7fc055411445882dc75714db10333.set`.
3. Require READY / WAIT_FOR_A_ONCE; press A on this chart once only.
4. Capture these Experts markers and the generated snapshot artifact paths:
   `RESUME_CLOCK_DIAGNOSTIC|START|TEST_ONLY`
   `RESUME_CLOCK_DIAGNOSTIC|INJECTION_FIRED|INTERRUPT_AFTER_CLOCK_PUBLICATION`
   `RESUME_CLOCK_DIAGNOSTIC|CLOCK_ONLY_PROVEN|changed_rows=1|non_clock_rows_exact=true|sequence_delta=1`
   `RESUME_CLOCK_DIAGNOSTIC|REOPEN|new_objects=true|freshness_reconstructed=false|second_publication=false`
   `RESUME_CLOCK_DIAGNOSTIC|PREDICATE_FACT|...`
   `RESUME_CLOCK_DIAGNOSTIC|CLASSIFIER|accepted=<true/false>|reason=<exact reason>`
   `RESUME_CLOCK_DIAGNOSTIC|CLASSIFIER_STORE_UNCHANGED|true`
   `RESUME_CLOCK_DIAGNOSTIC|COMPLETE|fixture_valid=true|forbidden_transport_calls=0|NO_RETRY|NO_AUTHORITY_GRANT`

Any FAIL or missing prerequisite marker is a fixture failure; do not credit a
classifier rejection alone. Do not rerun this preset/target. No other MT5
action, account/settings/Algo Trading change or production wrapper is requested.

## Provenance

Branch: sprint5-phase-f-entry-contract.
HEAD: d926f2e6b1aa4ea7b4b0936293d2fa47a2ce7ba8.
Committed tree: 46c09cfbed423df9c93b7f63aaf4b901af5b83fd.
Main unchanged: 32b79ca71ffc331e15e48a57c52be1352e3dbe7e.
This diagnostic is an uncommitted working-tree build, identified by the source
digest above, NOT by HEAD alone. Prior dirty edits were preserved. No commit,
push, merge, Option R or real deployment action occurred.

RESUME_CLOCK NATIVE DIAGNOSTIC READY — OPERATOR RUN APPROVAL REQUIRED
