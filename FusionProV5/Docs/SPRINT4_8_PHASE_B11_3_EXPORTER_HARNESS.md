# Sprint 4.8 Phase B11.3 - Exporter Harness Failure Preservation

Status: **Candidate / In Review - Unlocked - Pending Approval**

This phase corrects only the offline exporter test harness and its test inventory. It does not create a source freeze, generate final repository evidence, authorize a merge or runtime work, establish production readiness, or claim Architecture Lock. Sprint 4 remains the authorized architecture baseline.

## D4 Status and Preserved Facts

The D4 immutable verification remains **FAILED overall** because its exporter offline suite did not execute. Its successful immutable facts remain historical diagnostic inputs: source `911a2783a9165d8194f834cb2e7feac35c226591`, tree `f25a5a74a414b962675f41656463c7e9a28857be`, both compiles at 0 errors and 0 warnings, two independent 969/969 MQL runs with signature `18372369681406354017`, build `6090`, server `Exness-MT5Trial6`, 969 exact credibility mappings, 10 `ROUND_TRIP`, and 0 `WEAK_FALSE_POSITIVE`.

The immutable raw SHA-256 values remain `c110a52f354519c4946a997535f4e360974aeebbb4041c41a7cb4a1ce314f917` for Run 1 and `d89e8da2038f208be636346b9e357d9ba599dd119d290dfbe1a4eff753c98360` for Run 2.

## Preserved Root Cause

The first valid reproduction of the exact D4 baseline Generate invocation exited `1` with `SPRINT48_EXPORT_VALIDATION_FAILED: executing exporter does not match tested source blob` and produced no evidence files. The D4 isolated checkout materialized `Export-Sprint48Evidence.ps1` with CRLF bytes and SHA-256 `d58934fcd8f3e02ae05a2b7334e0abdeffb20a66091582e3610d950f4e4882d1`; the tested Git blob and byte-exact active file use LF bytes and SHA-256 `786402fe6eea56f998132956e4f5ce42f85b2aa186216ea2e16feb08742c9401`. The exporter correctly rejected the byte-different executable.

The former harness then attempted to hash absent `OutA/COMPILE_REPORT.md`. That secondary file-not-found operation masked the primary Generate rejection, and unconditional cleanup removed the temporary workspace before diagnosis. The preserved diagnostic root is `C:\Users\Nutthakrit\AppData\Local\Temp\FusionProV5_Sprint48_B113_Diagnostic_20260816_023532`; the canonical failing reproduction is under `d4_baseline_generate_corrected`.

## Harness Contract Correction

- Baseline Generate now captures its invocation, output streams, exit result, and output location, then fails immediately on a nonzero result.
- Every required evidence artifact is checked for existence and file type before any read or hash. A successful Generate with an incomplete set fails with `GENERATE_SUCCEEDED_BUT_REQUIRED_OUTPUT_MISSING` and names the missing artifact.
- Failed cases preserve a deterministic external diagnostic bundle containing the invocation, primary error, exit status, produced-file inventory, captured output, test identity, and paths.
- Cleanup is isolated so it cannot replace the primary exception or delete failure evidence. Successful cases may still clean temporary workspaces.
- Harness and exporter output paths are resolved through the same canonical directory authority, including Windows paths containing spaces and special characters.
- Fixture execution rematerializes the exporter and test harness from committed Git blob bytes, preventing checkout line-ending conversion from changing the source-bound executable identity.

The exporter itself is unchanged. Repeating the exact D4 baseline Generate with the byte-exact frozen exporter and unchanged D4 inputs passed and produced all five required artifacts. This confirms that the underlying exporter semantics were valid and the D4 blocker arose from checkout byte materialization plus harness failure masking.

## Deterministic Verification

- New failure-preservation cases `EXP48-108..117`: 10 passed, 0 failed, 0 skipped.
- Build-parser regression `EXP48-83..92`: 10 passed, 0 failed, 0 skipped.
- Server-parser regression `EXP48-93..107`: 15 passed, 0 failed, 0 skipped.
- Complete offline exporter suite: 117 passed, 0 failed, 0 skipped.
- Complete exporter signature: `6ce8f4a3e820656743eba8808fedec05798c824b5165f2bcd0f99191b1d59f40`.
- Exporter SHA-256: `786402fe6eea56f998132956e4f5ce42f85b2aa186216ea2e16feb08742c9401`.
- Exporter test-script SHA-256: `1d80fa7015abc949ea27a2f0d212ee59d63e8b6376c1469dd45bc6fd6c25d7d2`.

No MT5 or Strategy Tester run was performed. MQL source remains unchanged; the two D4 raw runs were consumed read-only.

## Verification-Source Format

`SWV5-SPRINT48-B11-VERIFICATION-SOURCE-V5` is retained. B11.3 changes harness control flow, diagnostics, cleanup, and byte-exact fixture execution, but it does not change the canonical field set or field meanings. Because the harness source changes, a newly approved source freeze and verification-source digest are still required before reproducible evidence generation.

## Closure State

The Six Critical findings remain closed. Full DTO serialization/round-trip and non-finite Statistics mutation remain closed. Credibility semantic verification and both parser closures remain closed at implementation level and have passed the corrected offline harness. These results do not convert the failed D4 attempt into final evidence authority.
