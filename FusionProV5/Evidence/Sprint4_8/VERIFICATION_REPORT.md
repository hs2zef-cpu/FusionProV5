# Sprint 4.8 Immutable Verification Report

Verdict: PASS
Tested source: `e56e51e72dc5fd9ee47d847781a545134b092059`
Source tree: `c97ba3cf8b21d12cc601753f4b2c311a06d02206`
Source timestamp: `2026-08-14T22:26:38+07:00`
Verification-source digest: `66a11100c3ba44a6c3b0699b93dedfacd3c2d0d618ddcc4b039efe0beda4cfd7`

Run 1: 934/934 passed, 0 failed, 0 skipped, signature `11631338912972649069`
Run 2: 934/934 passed, 0 failed, 0 skipped, signature `11631338912972649069`
Run 1 raw SHA-256: `7ed31d15d679ac469fd495e88ddd4d22ac02b495e9c47e8000172886ddf16c8d`
Run 2 raw SHA-256: `23767c95557b3d1cc2195ee1673ae92fc08e831f17aea6ff872d7f1171bbdb1e`
Each raw run contains two deterministic streams of 934 IDs, 1868 `SWV5_TEST` records total, exact canonical order, and all PASS outcomes.
Exact per-case records and canonical test IDs: VERIFIED (934 inventory, 934 unique, 934 runner entries, exact match)
Determinism: IDENTICAL
Schema: `SWV5-CONTRACT-TEST-RESULT-V5`
Policy: `SWV5-PRODUCTION-V5`
Suite: `SPRINT4.8-V5-FULL`
Environment: MetaTrader build 6090, `Exness-MT5Trial6`, HEDGING test fixture, broker_access=false, OnTester 1

Architecture compile raw SHA-256: `0aa359ddca8badf1b08dcb4f459ccd52a1047e19e28b937dce11072635bd0a7c`
Test compile raw SHA-256: `9e6dfdc3df22aa9944b2dc9e208d4d1f39462d082608d110aa4ec0f1165ee534`
Compiled test EX5 raw SHA-256: `8986da812dfbe182b71541a7e408d2459afbefc6bc6a64c9436e989366eb427d`

Credibility: 85 merge-gating behavior, 109 state transition, 606 negative fail-closed, 10 round trip, 48 invariant behavior, 62 supporting pure-function, 14 conformance-only, 0 weak false-positive; 858 behavioral and 934 executable total.

Exporter SHA-256: `2e99c6fb9065eda8ffb66a10d88fddf0780f4fa0c7f8d77cbc875b36c56fa8b2`
Exporter offline verification: 73/73 passed, 0 failed, 0 skipped, signature `aef3182e58ba10f267ac0459d1b0df14afa8fc988d15b17e5c1828ff0a25bb37`
Exporter offline result raw SHA-256: `e3430d18fa8d63f7be296b616e28770c1552f3451feac18f650001dbcf53cf09`
Repository evidence hash authority: GIT_BLOB_BYTES_SHA256
Raw-input hash authority: EXACT_EXTERNAL_FILE_BYTES_SHA256

Safety: immutable verification used MT5 Trial/Demo and Strategy Tester only, with no broker access or runtime implementation.

Governance: Production Contract V5 and Sprint 4.8 remain Candidate / In Review / Unlocked. No Architecture Lock, runtime authorization, production-readiness claim, or merge authorization is made. Final independent merge audit remains required.
