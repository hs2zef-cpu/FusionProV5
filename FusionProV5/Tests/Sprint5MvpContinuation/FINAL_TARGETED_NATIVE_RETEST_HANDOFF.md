# Final targeted patch — operator approval required

This is PRE-RUN evidence only. No post-patch MQL execution has occurred.
No production defect or actual nonzero broker exposure has been established.
The earlier 149 PASS / 10 FAIL run remains historical evidence, not a result
for the new binary. Its 149 passing assertion IDs/families remain in the suite.

## Original ten failures

| Assertion | Established cause / narrow disposition |
| --- | --- |
| REAL_SQLITE_CONTINUATION_COMPLETE | Missing MAIN second-phase handshake. Defer to one later fresh native tick, new TEST_ONLY acknowledgement and new publication object on the same copy. |
| MONOTONIC_GENERATIONS | MAIN cascade; unchanged generation predicate now evaluates the second-phase completion result. |
| TWO_BROKER_OBSERVATIONS_ZERO_SUBMISSION | MAIN cascade; unchanged exact two-capture/zero-submission predicate evaluates a fresh observer for the second phase. |
| COMPLETED_REPLAY_READBACK_ONLY | MAIN cascade; unchanged completed-history/readback/full-row-equality predicate follows the actual completion attempt. |
| LATER_NATIVE_TICK_PREFLIGHT_COMPLETE_ZERO_SUBMISSION | MAIN cascade; snapshot after second-phase completion, then wait another strictly later native tick. PREFLIGHT code unchanged. |
| CLOCK_DIAG_MUTATION | ZERO_TIME used invalid physical updated_at=0. Preserve positive physical timestamp and payload sequence; mutate only payload observed_at. New assertions require exact committed readback and PRESTATE_CLOCK_TIME_INVALID rejection, not a CAS rejection. |
| PARTIAL_TRUST | Still unclassified. Detail now precedes early return; test-only fresh-event, stage attempt/result/stop and hook markers reveal the actual failing prerequisite. No speculative fix. |
| PARTIAL_GOVERNANCE | Still unclassified. Same diagnostics, including heartbeat, Trust and Governance stages. Governance alias correction preserved. No speculative fix. |
| RESUME_FLAT | Still unclassified. Single native capture logged before synthetic faults; exact BrokerZero inputs, expected clock and first rejecting field logged. No recapture/retiming/synthetic zero fix. |
| RESUME_PENDING | Still unclassified. Same diagnostics; pending/request is explicitly NOT_INCLUDED in BrokerZero. No speculative fix. |

The MAIN second phase is bounded to one invocation. Its pending flag is
consumed before publication. Failure does not schedule retries. All subsequent
MAIN assertions still fail honestly if the second phase fails. The new
acknowledgement is a TEST_ONLY invocation fixture, not production authorization.

## Local results (not MQL execution)

- Current aggregate pre-run: **210 passed / 0 failed**.
- Included active layering regressions: **101/101**.
- Governance regression summary: **54/54** (overlapping checks, not additive).
- Source-extracted CAS guard rejects the former zero physical timestamp and
  admits valid positive metadata. Private in-memory SQLite exact CAS/readback
  succeeds; stale CAS fails. This is Python/SQLite oracle evidence only.
- Production-filename, missing/invalid marker and path refusal: PASS using
  isolated source-extracted guards with I/O-denying stubs; not native execution.
- Exactly one unchanged production OrderSend site elsewhere; compile-time
  OrderSend/OrderSendAsync fail-trap active in this harness. Administrative
  continuation has no execution issuers. NativePreflight stays MODE_PREFLIGHT
  with its early return before D1/Permit/Admission/Claim/Submit.
- One production HeartbeatAttended caller, in attended continuation.
- Original DB, immutable donor and all prior mutable native targets unchanged.
- Fresh seed is byte-identical; fresh mutable target family is absent.
- git diff --check: PASS. No commit/push. No MT5 launch or EA execution.

## Compile and installed binary

MetaEditor X64 Regular: **0 errors / 0 warnings** for each:

- SW_V5_S5_MVP_ATTENDED_AUTHORITY_CONTINUATION
- SW_V5_S5_MVP_CONTINUATION_ASSERTIONS
- SW_V5_S5_MVP_CONTINUATION_NATIVE_COPY_ASSERTIONS

Installed full-suite EA:

`C:\Users\Nutthakrit\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Experts\FusionProV5Tests\SW_V5_S5_MVP_CONTINUATION_NATIVE_COPY_ASSERTIONS.ex5`

Compiled = installed SHA256:

`292DA9F9E5719609587E29A48157FB33716D5BD48926A09C93038B11F1218838`

This differs from both previous executed binaries (B70132E9... and 67C32333...).
Stale-build provenance gate now passes against the current include closure.

## Fresh preset and targets

Preset:

`C:\Users\Nutthakrit\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Presets\TEST_ONLY_MVP_CONTINUATION_8e6c2b6183a44fedb58c28d730aa1140.sqlite.set`

Preset SHA256:

`8E82B3C9B4893418B63CB868A0EAF34E5B11EF93DCE876F46594416273E86480`

Inputs:

```text
explicit_test_only_marker=TEST_ONLY_AUTHORIZED_UNCOMMITTED_DRAFT
initial_copy_relative_path=TEST_ONLY_MVP_CONTINUATION_8e6c2b6183a44fedb58c28d730aa1140.sqlite
expected_initial_copy_sha256=bec62e7435d29d5511a41bf85c74ae443994c5804b3a9574af90d861fe674ef6
execute_test_copy_once=true
operator_confirmed_test_copy=true
```

Read-only seed:

`C:\Users\Nutthakrit\AppData\Roaming\MetaQuotes\Terminal\Common\Files\TEST_ONLY_MVP_CONTINUATION_8e6c2b6183a44fedb58c28d730aa1140.sqlite`

Fresh MAIN target (does NOT yet exist):

`C:\Users\Nutthakrit\AppData\Roaming\MetaQuotes\Terminal\Common\Files\TEST_ONLY_MVP_CONTINUATION_8e6c2b6183a44fedb58c28d730aa1140.sqlite.RETEST.MAIN.sqlite`

All new mutable targets use the fresh seed's `.RETEST` prefix, not any old
run prefix. Clone refuses an existing target, WAL or SHM; no overwrite/delete.
Every mutable clone still copies the immutable-hash seed, never MAIN or a prior
partial clone. This prefix change is test-fixture naming only.

Real DB / immutable donor / fresh seed all have SHA256:

`BEC62E7435D29D5511A41BF85C74AE443994C5804B3A9574AF90D861FE674EF6`

Real DB and fresh seed have no WAL/SHM. Donor has no uncheckpointed WAL.
The deployment DB is file-hashed only; no SQLite connection is opened to it.
Seed/donor structural reads use URI mode=ro&immutable=1 and query_only=ON.
SQLite prestate is not evidence of current broker positions/orders.

## Source scope

Changes made in this targeted patch:

- Assertion header: bounded MAIN handshake, corrected zero-time fixture,
  pre-return partial diagnostics, native capture diagnostic, unique run prefix.
- AttendedContinuation header: test-macro-only event/stage logs; no changed
  freshness, validation, mutation, resume or release predicates.
- ContinuationFlatAuthority header: same single capture and same complete
  BrokerZero conjunction, with test-macro-only post-evaluation diagnostics.
- Supporting new preset, baseline hash inventory, verifier and this evidence.

No ADR, frozen contract, ordinary Ownership validator, Governance alias logic,
PREFLIGHT implementation, Broker Adapter, Signal or Decision change was made
by this targeted patch. The earlier uncommitted draft is preserved.

Branch: sprint5-phase-f-entry-contract

HEAD: d926f2e6b1aa4ea7b4b0936293d2fa47a2ce7ba8

Tree: 46c09cfbed423df9c93b7f63aaf4b901af5b83fd

Main unchanged: 32b79ca71ffc331e15e48a57c52be1352e3dbe7e

These immutable identifiers describe the base, not the uncommitted patch.
Current source/include digest, exact artifact paths/hashes, raw historical run,
individual check results and dirty git status are recorded in
FINAL_TARGETED_NATIVE_PRE_RUN_EVIDENCE.json.

**STOP. Operator/Fusion approval is required before the one full native run.**

FINAL FULL NATIVE RETEST READY — OPERATOR APPROVAL REQUIRED
