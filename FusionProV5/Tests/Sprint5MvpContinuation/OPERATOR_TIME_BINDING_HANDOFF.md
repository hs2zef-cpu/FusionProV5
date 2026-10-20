# Operator authorization time binding — final native retest handoff

Source/local/pre-run closure only. **The new MQL binary has NOT been executed.**
MT5 was not launched. No wrapper, Claim, Submit or OrderSend was executed.
The prior native 153 PASS / 8 FAIL / 0 SKIP result is historical, not a result
for this binary. No production readiness or deployment authorization is claimed.

## 1. Old operator semantics

`SWV5S5_MvpOperatorInvocationValid` required nonempty operator/reference,
the exact existing operator role, and `authenticated_at == validation_time`.
This forced the accepted A/event, evidence and final activation into one second.

## 2. New finite-window semantics

The same nonempty identity/reference and exact role checks remain. Require:

```text
authenticated_at > 0
authenticated_at <= validation_time
validation_time - authenticated_at < 3600
```

The interval is **[T0, T0 + 3600)**. Before T0 and at/after the upper bound fail.
Subtraction after the lower-bound check avoids adding a possibly overflowing
expiry timestamp. The original invocation DTO and canonical payload/digest
format are unchanged. Finalization compares the exact original canonical
operator payload and exact input/owner identity retained in memory.

## 3. Lifetime source

Reuse the pre-existing production constant:

`SWV5S5_MVP_MANUAL_AUTHORITY_LIFETIME_SECONDS = 3600`

File:
`C:\Users\Nutthakrit\Documents\FusionProV5\FusionProV5\ExecutionLayer\RuntimeAuthority\SW_V5_S5_MvpDeploymentProfile.mqh`

No lifetime input, new policy constant, domain, checkpoint or authority is added.

## 4. Exact shared/frozen source scope

Shared production runtime file changed:

- `FusionProV5/ExecutionLayer/RuntimeAuthority/SW_V5_S5_MvpDeploymentProfile.mqh`:
  only the operator-validity body changes. All other profile logic/constants
  match HEAD after substituting the old function body (verified).

Continuation implementation changed:

- `FusionProV5/ExecutionLayer/RuntimeAuthority/SW_V5_S5_MvpAttendedContinuation.mqh`:
  retain one invocation in memory; prepare real observations; wait for the later
  accepted native event; validate the complete physical read-set, then persist
  the final flat record with atomic exact-snapshot CAS and finalize release.
- `FusionProV5/ExecutionLayer/RuntimeAuthority/SW_V5_S5_MvpContinuationFlatAuthority.mqh`:
  ordered real observation times instead of same-second equality; retain all
  exact identity, complete enumeration, zero-state and digest predicates; bind
  the known finalization clock advance separately from cold-resume advances.
- `FusionProV5/Tests/Sprint5MvpContinuation/SW_V5_S5_MVP_ATTENDED_AUTHORITY_CONTINUATION.mq5`:
  one in-memory A across two OnTicks; the original publisher path serves both
  phases; consume final dispatch once and reject expired A before publication.
  Only the TEST_ONLY full suite was installed, not this administrator wrapper.

Test/verification source changed:

- `FusionProV5/Tests/Sprint5MvpContinuation/SW_V5_S5_MvpContinuationAssertions.mqh`:
  preserve original positive/negative assertions, schedule real later-tick
  finalization, add finite-window/identity/clock/chronology negatives. Waiting
  is explicitly NOT counted as a negative rejection. The obsolete compensating
  MAIN-new-attempt branch is removed; MAIN now keeps its one original A.
- `FusionProV5/Tests/Sprint5MvpContinuation/verify_event_freshness_layering.py`:
  check the authorized ordered profile-time predicate, the shared publisher
  route and current installed binary instead of the retired B7 HOLD check.
- `FusionProV5/Tests/Sprint5MvpRuntime/SW_V5_S5_MvpRuntimeAssertions.mqh`
- `FusionProV5/Tests/Sprint5MvpRuntime/verify_mvp_runtime.py`
- `FusionProV5/Tests/Sprint5MvpRuntime/verify_mvp_mutation_controls.py`

The runtime regression's old “one second earlier must reject” expectation is
replaced by before-authentication and expired-window negatives and a delayed
positive. These are intentional policy-aligned fixture updates, not waivers.

New files are the fresh preset, two baseline hash inventories, the targeted
verifier, its generated pre-run evidence and this handoff report.

**Frozen ProductionArchitecture contracts: unchanged.** No DTO field, enum,
contract version, Signal, Decision, Broker Adapter or OrderSend change.
No ADR expansion. Earlier uncommitted Ownership/Governance/SQLite/ADR work is
preserved, not rewritten by this patch.

Shared release/activation/codec files remain byte-identical to the pre-patch
baseline, including:

- SW_V5_S5_MvpDemoAuthorityProviders.mqh
- SW_V5_S5_MvpHardKillReleasePhysical.mqh
- SW_V5_S5_MvpHardKillActivationAuthority.mqh
- SW_V5_S5_MvpManualProvisioningAuthorities.mqh

## 5. Real observation times and unchanged broker-zero requirements

T0 is the initial accepted event and original A timestamp. The initial fresh
event still requires CurrentFreshObservation and exact stored/current payload.
The initial op timestamp still equals that initial event. A profile read may
be later, never earlier; exact broker/server/account/symbol binding remains.

BrokerZero performs a real Capture on every call. In addition to its unchanged
profile/identity, digest, complete enumeration, query-success, zero row-failure,
positions=0, orders=0 and finite exposure=0 conditions, it requires:

```text
observed_at >= accepted event
observed_at >= native capture-start time
observed_at <= native observation-end time
```

This rejects stale cached and future observations; it does not merely remove
the old temporal check. The native broker read-only capture implementation is
unchanged. There are still two real broker captures, not one capture reused as
two. No additional capture or broker mutation occurs during finalization.

The flat builder retains native broker time in the typed broker evidence and
broker-observation payload. Exposure evidence uses that same actual capture
time. Persistence evidence records the actual read-only observation time after
physical snapshot validation. These observation timestamps are NEVER rewritten
during finalization.

The existing flat envelope's `observed_at` is explicitly the accepted authority
finalization event T2 (as are its approval/release times), not the raw broker
capture time. Raw/typed broker, persistence and exposure times remain separately
bound into the canonical flat payload and its digest. No DTO shape change.

## 6. Real accepted finalization clock and no retry

```text
fresh A + accepted event T0 -> real observations T1 -> later OnTick / accepted T2
```

Preparation does not persist a flat/release authority. The hard kill remains
ACTIVE while waiting. Only the same in-memory invocation can continue.

The later OnTick calls the SAME existing
`SWV5S5_MvpLeaseClockAuthority.ObserveFromCurrentSymbolOnTick` path. Its ordinary
implementation and durable readback/freshness machinery are unchanged. The
wrapper has one publisher call site shared by both phases, not a second clock
sampler. Finalization requires:

- CurrentFreshObservation plus exact verified stored payload;
- same clock ID/authority/profile, exactly the next clock sequence;
- T2 > T0 and T2 >= every newly captured observation;
- original A still inside the finite window, exact original invocation/input;
- complete non-clock rows unchanged while waiting;
- physically current lease, Trust, Governance, Account, RequestSet and Basket;
- exact-snapshot CAS/readback before release.

Context time is assigned from accepted `final_clock.observed_at`, never from
TimeCurrent or a fabricated observation. Read-only TimeCurrent may deny an
expired A before publication, but cannot authorize finalization.

For a newly issued release:

`T0 <= each real T1 <= T2 = approved_at = released_at = activated_at`.

Cold PENDING/RELEASED resume preserves the original immutable release bundle and
its timestamps; a newly acknowledged accepted event and its later final clock
validate continuation without rewriting historical evidence.

The final dispatch is consumed before publication; any failure stops. No timer,
automatic retry or automatic new production invocation is added. Constructor /
OnInit do not reconstruct A. A process restart requires a new operator A. The
TEST_ONLY cold-restart fixture explicitly checks rejection without a new event.

## 7. Local and compile results

- Complete local/static/pre-run aggregate: **271/271 PASS**, 0 failed.
- Source-extracted Python guards cover actual operator/broker/final-clock and
  shared release chronology expressions, including exact-second reversion.
- Layering regression: **102/102 PASS**.
- Governance regression: **54/54 PASS** (overlapping, not additive).
- Independent runtime Python oracle: **94/94 PASS**.
- Runtime Python mutation controls: **20/20 KILLED**.
- git diff --check: PASS.

These are explicitly static/source-extracted/Python/SQLite-oracle checks, NOT
post-patch native MQL execution evidence. New real MQL cases cover before-A,
window expiry, wrong identity/reference, observations before A/after T2,
incomplete/nonzero/wrong-profile broker results, absent accepted final clock,
restart non-reconstruction and actual later-tick boundary/resume families.

MetaEditor X64 Regular, **0 errors / 0 warnings** for all four:

- SW_V5_S5_MVP_ATTENDED_AUTHORITY_CONTINUATION
- SW_V5_S5_MVP_CONTINUATION_ASSERTIONS
- SW_V5_S5_MVP_CONTINUATION_NATIVE_COPY_ASSERTIONS
- SOMWANG_XAU_M15_FUSION_PRO_V5_MVP_RUNTIME_TESTS

## 8. New full TEST_ONLY EX5

Compiled and installed hash are identical:

`BFA0D7EC4F86C9C853853E38DE2EB24639DB906F1E04BA2222ED63D637C4D023`

Installed path:

`C:\Users\Nutthakrit\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Experts\FusionProV5Tests\SW_V5_S5_MVP_CONTINUATION_NATIVE_COPY_ASSERTIONS.ex5`

Native include-closure source digest:

`637d03d5e5c277023693546c9fd0dcab8faf17511597d6fa315096d6c0d70b8b`

## 9. New preset/run ID

Preset:

`C:\Users\Nutthakrit\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Presets\TEST_ONLY_MVP_CONTINUATION_4de6f69b8813436a8f272d895b8e2cf0.sqlite.set`

SHA256:

`A2C44E7EFDA01124627EF132B8F78EDE2EA85195E99BC6D8EF773EA3496D0166`

Inputs:

```text
explicit_test_only_marker=TEST_ONLY_AUTHORIZED_UNCOMMITTED_DRAFT
initial_copy_relative_path=TEST_ONLY_MVP_CONTINUATION_4de6f69b8813436a8f272d895b8e2cf0.sqlite
expected_initial_copy_sha256=bec62e7435d29d5511a41bf85c74ae443994c5804b3a9574af90d861fe674ef6
execute_test_copy_once=true
operator_confirmed_test_copy=true
```

New mutable MAIN target, still absent:

`C:\Users\Nutthakrit\AppData\Roaming\MetaQuotes\Terminal\Common\Files\TEST_ONLY_MVP_CONTINUATION_4de6f69b8813436a8f272d895b8e2cf0.sqlite.RETEST.MAIN.sqlite`

All mutable targets are fresh `.RETEST*` names under this run's seed identity.
No old MAIN, partial, resume or negative clone is reused. Clone enforces the
immutable hash and refuses existing DB/WAL/SHM targets without overwrite.

## 10. Complete pre-run safety result

**271/271 PASS**, including current compile/source provenance, production-file /
marker/path refusal, one-shot A isolation and compiled transport trap.

- Exactly one production OrderSend site elsewhere, byte-unchanged.
- One production attended Heartbeat caller, unchanged scope.
- No continuation D1 Sequence/Ledger/Permit/Admission/Claim/Submit issuer path.
- NativePreflight remains MODE_PREFLIGHT with the existing execution early exit.
- Fresh test seed is donor-identical; mutable targets absent.
- Real DB and immutable donor unchanged; prior test artifacts unchanged.
- Real DB was only file-hashed, not opened as SQLite.
- No new broker positions/orders observations were performed in this task.

Real DB / donor / fresh seed SHA256:

`BEC62E7435D29D5511A41BF85C74AE443994C5804B3A9574AF90D861FE674EF6`

Branch: sprint5-phase-f-entry-contract

Base HEAD: d926f2e6b1aa4ea7b4b0936293d2fa47a2ce7ba8

Base tree: 46c09cfbed423df9c93b7f63aaf4b901af5b83fd

Main unchanged: 32b79ca71ffc331e15e48a57c52be1352e3dbe7e

Working tree intentionally remains uncommitted. No commit, push or merge.
No MT5 launch. Operator/Fusion approval is required before native execution.

OPERATOR AUTHORIZATION TIME BINDING CLOSED — FINAL NATIVE RETEST READY
