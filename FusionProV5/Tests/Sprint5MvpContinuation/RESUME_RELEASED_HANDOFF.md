# RESUME_RELEASED targeted correction / operator handoff

TEST ONLY evidence. No MT5 launch or native suite execution was performed by this patch.
This is a pre-run PASS, not a post-fix native PASS. Operator run approval is still required.

## Proven first failure

- Caller: `SWV5S5_MvpAttendedContinuation::CompleteRelease`, RuntimeAuthority/SW_V5_S5_MvpAttendedContinuation.mqh:419 (old stop at line 430).
- Decoder: `SWV5S5_MvpCodecDecode_SWV5_HardKillState`, SW_V5_S5_MvpAuthorityRecordCodec.mqh:1254.
- First failing subpredicate: `reader.ReadNested("contract_version",nested)`.
- Its `ReadRaw` prefix check (same file:23) expects `contract_version:x:` at offset zero.
- Actual CURRENT starts `hard_kill:x:5364:version:x:119:`.
- Domain/key: `MVP_HARD_KILL_STATE/CURRENT`.
- Classification: payload codec/envelope mismatch (category a). Not physical corruption, revision failure, operator binding, activation proof binding, or clock failure.
- CURRENT revision: 7; updated_at: 1791992123.
- CURRENT payload digest: f4c5b36bedf500ace21b6ec09bf28f20de941692afeb6a1bf4060376a0fe9018.
- CURRENT store revision: bea7851c300bbd4cd5d8d584d10f0bb470b27ccca65c316ff924e87a5918e9c2.
- Complete bundle key: MVP-CONTINUATION-RISK-AUTH-8bbe2395db83e6f3916989ca941e3776a34786576523183d608380ab52a20b8f.
- Both row domain digests and CAS revisions validate. Interpreting the accepted canonical serializer field order in Python projects the real typed release bundle byte-exactly onto CURRENT. This is a structural Python check, not an MQL execution claim.
- Actual journal baseline independently read: 213 passed / 1 failed / 0 skipped / 214 total; only RESUME_RELEASED failed.
- Journal SHA256: C92F753C9C68F08DD11EA56FDB5F510CCAB1268AB77E003DDB32F43D35BCEEC9.
- Failed TEST_ONLY copy SHA256: 2DDDF76781874CF351D562CBE7532DE0A801592F41ED75661D646B7559363791.

## Exact correction

Only two pre-existing source files changed relative to the pre-patch 737-file hash baseline:

1. RuntimeAuthority/SW_V5_S5_MvpAttendedContinuation.mqh:
   Decode the existing typed complete bundle, require its revision/state and physical digest/CAS validity, require canonical projection byte-equality with CURRENT, and run the existing complete release validator.
   Use historical flat A1 only to identify the original record. Do not assign A2 to any historical release field.
   The existing finalization, bound-row, lease, release-order, and activation validators remain in force.
2. Tests/Sprint5MvpContinuation/SW_V5_S5_MvpContinuationAssertions.mqh:
   Add focused physical beforeimage checks at the genuine RELEASED interruption, before resumed finalization, and in the final activation history.
   Check real A1 fields/timestamps; cold reopen rejects A1 and the actual accepted A2 without a fresh event; immutable complete bundle survives; activation proof carries A2 and real later T2; final state INACTIVE; zero submission/transport.

No generated codec, frozen contract, operator authorization predicate, 3600-second window, broker-zero predicate, quote binding, production transport, or production wrapper source changed in this patch.

## Historical authority integrity / evidence limit

No old TEST_ONLY copy or donor was mutated. The real deployment store was file-hashed only, never opened by SQLite.
The old current row and immutable complete bundle remain unchanged throughout this patch.
A1 authenticated_at=1791991926; original approval/release timestamps=1791992123.
A2 authenticated_at=1791992139 and final accepted T2=1791992408 in the actual failed journal.
The failure happened before activation and before any historical release write.

The old native run did NOT export an INTERRUPT_AFTER_RELEASED physical beforeimage.
Therefore no retrospective two-snapshot byte-comparison is claimed. Current row/bundle integrity and projection are proven, and the new real MQL regression captures that missing beforeimage explicitly. Execution of that regression remains pending.

## Verification

- Complete pre-run gate: 297/297 PASS, 0 failed.
- Focused forensic/source guard checks: 32/32, including 9/9 source-guard mutations killed.
- Existing operator/clock/zero-state guard regression: 56/56.
- Runtime Python oracle: 94/94, 0 failed/skipped.
- Runtime Python mutations: 20/20 killed, 0 survived.
- Layering checks: 102/102 (includes Governance 54/54, not additive).
- All four manifests: MetaEditor X64 Regular, 0 errors / 0 warnings.
- git diff --check: PASS.
- Exactly one unchanged production OrderSend site: BrokerAdapter/SW_V5_S5_F_BrokerPlatformBoundary.mqh:275.
- Exactly one production attended heartbeat continuation caller.
- Compile-time OrderSend/OrderSendAsync fail-trap remains before the include graph.
- Production filename / marker / traversal refusal: PASS with zero attempted I/O in isolated source-extracted Python tests.
- Native post-fix executions: 0. All existing native families remain scheduled; 213/1 is historical evidence only.
- Imported Governance summary's unresolved_prior_failures metadata describes an older archived baseline, not the current 213/1 run or a new failure.
- Compiled include-source digest: 72175faf558ecf79dae6d063edca4cce89bca02aeb5021e8feed825f425c663e.

## New operator artifacts (not executed)

EA: SW_V5_S5_MVP_CONTINUATION_NATIVE_COPY_ASSERTIONS

Installed EX5:
C:\Users\Nutthakrit\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Experts\FusionProV5Tests\SW_V5_S5_MVP_CONTINUATION_NATIVE_COPY_ASSERTIONS.ex5

EX5 SHA256:
8A0EAAF6DA33ABAEB43413F47A8F90F0DADA9B0F69C0A4A489ACB2E35164A40F

Preset:
C:\Users\Nutthakrit\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Presets\TEST_ONLY_MVP_CONTINUATION_d2c6f9539b124ae7bf03a8d4f1806c72.sqlite.set

Preset SHA256:
72B2BAB1C4464D8DFCD7B8F59105122A33E4B9F49AE13832D5268398478FCE67

New immutable seed:
TEST_ONLY_MVP_CONTINUATION_d2c6f9539b124ae7bf03a8d4f1806c72.sqlite

Fresh mutable MAIN target (absent):
C:\Users\Nutthakrit\AppData\Roaming\MetaQuotes\Terminal\Common\Files\TEST_ONLY_MVP_CONTINUATION_d2c6f9539b124ae7bf03a8d4f1806c72.sqlite.RETEST.MAIN.sqlite

All new .RETEST* targets are absent. Do not reuse previous run clones.
Seed, donor, and real DB SHA256:
BEC62E7435D29D5511A41BF85C74AE443994C5804B3A9574AF90D861FE674EF6

Real DB and seed: 81920 bytes, no WAL/SHM. Donor sidecars preserved exactly.
Native profile/positions/orders were not inferred from SQLite.

## Provenance / restrictions

Branch: sprint5-phase-f-entry-contract
HEAD: d926f2e6b1aa4ea7b4b0936293d2fa47a2ce7ba8
Tree: 46c09cfbed423df9c93b7f63aaf4b901af5b83fd
main: 32b79ca71ffc331e15e48a57c52be1352e3dbe7e

Existing dirty draft remains preserved. No commit, push, merge, reset, checkout, stash, clean, authority DB mutation, wrapper execution, A key, Claim, D1, D3, D6, or broker operation was performed.
MT5 was already open; it was not launched, closed, or controlled by this patch.
All original source files except the two listed and all pre-existing test-copy hashes remain exact.

RESUME_RELEASED CLOSED — FINAL NATIVE RETEST READY
