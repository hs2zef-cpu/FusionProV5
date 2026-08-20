# Sprint 4.8 Phase B11.6 - Determinism Test Credibility

Status: **Candidate / In Review - Unlocked - Pending Approval**

B11.6 closes only the two C11 determinism-test credibility findings. It does not change the production exporter, MQL, runtime, architecture contracts, MQL inventories, credibility authority, run configurations, or D4 raw evidence. It does not create a source freeze, final evidence, merge authorization, runtime authorization, production readiness, or Architecture Lock. Sprint 4 remains the authorized architecture baseline, and D4 remains failed overall.

## C11 Findings and EXP48-137 Repair

C11 found that the former `EXP48-137` created different diagnostic objects but never supplied them to the canonical-result builder. The repaired builder receives and validates a complete runtime context containing execution, materialization, output, diagnostic, and workspace paths plus a process identifier. These values are deliberately diagnostic/volatile inputs and are not copied into the canonical result.

The repaired test creates two otherwise identical complete scenarios with different absolute runtime paths, GUID roots, and process identifiers. Each scenario is passed through the same `New-CanonicalExporterResult` function used by targeted and complete offline-suite results. Invocation counters prove both calls occurred. The test requires identical canonical/source inputs, identical canonical JSON bytes and SHA-256, absence of every supplied volatile value, and presence of stable repository-relative source provenance.

`EXP48-140` is the negative control. It follows the same builder path while changing one canonical field to a real independently derived mutated fixture tree. Canonical bytes and SHA-256 must change, proving that the builder excludes diagnostic context rather than ignoring all provenance.

## EXP48-139 Real Source Mutation

C11 found that the former `EXP48-139` injected an unrelated hash without rebuilding the Git authority chain. The repaired test extracts all explicit Base fixture bytes, builds a new Base repository from scratch, and independently builds a Mutated repository after appending the harmless PowerShell comment `# B11.6 deterministic source mutation probe` to logical file `FusionProV5/Tests/ContractVerification/Test-Export-Sprint48Evidence.ps1`.

Both repositories use the fixed synthetic Git identity, timestamp, message, parentless root-commit model, and disabled signing. Each authority is derived independently through explicit bytes, Git blobs, tree, deterministic commit, materialized bytes, canonical provenance, and canonical result serialization. No changed hash, blob, tree, commit, or provenance object is fabricated or copied from Base.

Base authority:

- source SHA-256: `8fe7c8a5422e55cc0a7cdc7029c51a3b9cea93f08961956a06521a5e2b62f28b`
- affected blob: `46f3343dad24cf037ef8a1d5c3ad0622668dc4b4`
- tree: `96a4e8cff5a8be973208b638ffd770c5ab739349`
- commit: `ff9fd1e83a4ee102bcffecc6438750ccddd19a43`
- canonical result SHA-256: `5ae5ecf9ac2befac5ce22a508e1c1221186ab83762783b60f08b9451ef9078c5`

Mutated authority:

- source SHA-256: `8961f9fed0ec518257a6f75fc582f11c9eb39eefc0f6bb2cbffdb8cd9e36f365`
- affected blob: `13ad7ac4aabcff71cb265806dc0472336ca6c73f`
- tree: `ca6f02fbfb1d79b84a9f8d17f15ac76e9f811de1`
- commit: `ef07ad3a7b3c76570b728a805c7c97ae39083ce1`
- canonical result SHA-256: `77978c154a0978527529fe410224328e2d4905b4a0a8bdb55773e95bee552151`

The test requires every affected authority value and canonical identity/result to differ while all unrelated fixture blob IDs remain equal. It also requires source, Git-blob, and materialized SHA-256 equality within each independently built authority.

## Offline Verification

- Repaired targeted credibility suite: 3 passed, 0 failed, 0 skipped (`EXP48-137`, `EXP48-139`, `EXP48-140`).
- Determinism group: 13 passed, 0 failed, 0 skipped (`EXP48-128..140`).
- Complete exporter suite Run A: 140 passed, 0 failed, 0 skipped.
- Complete exporter suite Run B: 140 passed, 0 failed, 0 skipped.
- Signature: `5ee6614cc75642262a67e29661642787d9974de3e364499e05563baf83552bc5`.
- Exporter SHA-256: `786402fe6eea56f998132956e4f5ce42f85b2aa186216ea2e16feb08742c9401`.
- Harness/source SHA-256: `8fe7c8a5422e55cc0a7cdc7029c51a3b9cea93f08961956a06521a5e2b62f28b`.
- Fixture tree: `96a4e8cff5a8be973208b638ffd770c5ab739349`.
- Fixture commit: `ff9fd1e83a4ee102bcffecc6438750ccddd19a43`.
- Canonical result raw SHA-256: `7ec87f0785b9494c31d524abaff11295ab4e1b9bc74777408aa9b2bd629becf3`.
- Canonical result length: 31,877 bytes.
- Run A and Run B canonical bytes: identical despite distinct disposable workspace paths.

The canonical volatility scan found no absolute path, AppData/Temp path, GUID, user, host, PID, runtime-path field, or wall-clock timestamp. Only fixed synthetic fixture timestamp `2000-01-01T00:00:00+00:00` remains.

`SWV5-SPRINT48-B11-VERIFICATION-SOURCE-V5` remains unchanged because its fields, ordering, meanings, and canonical exporter-result-byte SHA-256 semantics are unchanged.

The exact historical D4 offline Generate regression passed using unchanged raw hashes, 969/969 twice, signature `18372369681406354017`, build `6090`, server `Exness-MT5Trial6`, 969 credibility mappings, 10 `ROUND_TRIP`, and 0 `WEAK_FALSE_POSITIVE`. D4 remains historically failed overall and is not immutable successor authority. No MQL rerun, MT5, Strategy Tester, runtime action, or broker mutation occurred.
