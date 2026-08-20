# Sprint 4.8 Phase B11.4 - Harness Identity and Diagnostic Authority

Status: **Candidate / In Review - Unlocked - Pending Approval**

B11.4 closes the three source-review findings from C9 without changing the production exporter, MQL, runtime, architecture contracts, run configurations, or evidence-source field semantics. It does not create a source freeze, final evidence, merge authorization, runtime authorization, production readiness, or Architecture Lock. Sprint 4 remains the authorized architecture baseline, and D4 remains failed overall.

## Independent Executable Identity

`Assert-ExecutingFileIdentity` requires an independently supplied SHA-256 and hashes the exact execution file bytes. It fails closed for a missing or malformed expected hash, a missing execution file, or an actual/expected mismatch.

The offline harness now establishes this noncircular chain before Generate:

1. Hash the active harness and the explicit fixture-source copies as exact bytes.
2. Resolve exporter and harness Git objects from the intended synthetic fixture commit and exact repository paths.
3. Hash each Git blob directly from `git cat-file blob` bytes.
4. Require the explicit fixture-source byte hash to equal its Git-blob-byte hash.
5. Materialize each blob through an untranscoded binary stream.
6. Require the materialized exporter and harness hashes to equal their Git-blob-byte hashes.
7. Require the active harness exact-byte hash to equal the independently derived fixture harness Git-blob hash.

The B11.4 development result recorded fixture commit, repository paths, Git object IDs, expected Git-blob hashes, exact source hashes, materialized/executed hashes, and absolute execution paths. B11.5 supersedes that result representation: absolute paths remain available only in noncanonical diagnostics and are excluded from reproducible canonical result bytes. Exporter self-validation remains defense in depth and is not used as the independent harness proof.

The verified exporter SHA-256 is `786402fe6eea56f998132956e4f5ce42f85b2aa186216ea2e16feb08742c9401`. The active harness, explicit fixture source, fixture Git blob, and materialized fixture harness all resolve to `1ac3c565675dd446d7d32c9cd0e34dcbf18fd61b713766891639dd868273531b` in this development run.

## CRLF Adversarial Closure

`EXP48-119` converts an exporter copy to CRLF and proves identity rejection occurs before Generate can start. `EXP48-121` performs the equivalent test for the harness. Exact LF Git-blob materializations pass. Working-tree bytes are therefore never silently promoted to Git-blob authority when line-ending conversion changes their identity.

The repository-wide `.gitattributes` remains unchanged. Adding a broad `*.ps1 text eol=lf` rule could affect unrelated PowerShell files and history outside this focused phase. The explicit byte-authority chain fully closes execution authority, so the line-ending policy warning is accepted as a documented operational condition for later repository-wide review.

## Diagnostic Authority and Survival

Failure schema `SWV5-SPRINT48-HARNESS-FAILURE-V2` serializes the primary error, stage, failing case ID, exit code, resolved exporter path, output directory, invocation and arguments, produced-file inventory, diagnostic stream, and preserved-output filename.

Diagnostic roots are canonically checked and rejected when equal to or below the disposable workspace. The repaired `EXP48-113` runs a real failing Generate case, preserves the bundle externally, removes the disposable workspace, parses the surviving summary, validates the exporter path and primary error, and reads the copied exporter output after cleanup.

## Deterministic Verification

- Targeted identity and diagnostic suite: 20 passed, 0 failed, 0 skipped.
- New B11.4 cases `EXP48-118..127`: 10 passed, 0 failed, 0 skipped.
- Existing harness cases `EXP48-108..117`: 10 passed, 0 failed, 0 skipped.
- Build parser `EXP48-83..92`: 10 passed, 0 failed, 0 skipped.
- Server parser `EXP48-93..107`: 15 passed, 0 failed, 0 skipped.
- Full exporter offline suite: 127 passed, 0 failed, 0 skipped.
- Full exporter signature: `77a7f26c8f279f4679baedd8c1c57e9f33fe5920aedd362a7a623f0af79a28a8`.
- Full result raw SHA-256: `779e7fa368ff2ee40cd6194d661a135e80e9230a19fa2afd48852f3d2164698c`.
- Result schema: `SWV5-SPRINT48-EXPORTER-OFFLINE-TEST-V4`.

The exact-D4 offline Generate regression passed using the unchanged D4 raw logs. Both runs remain 969/969 with signature `18372369681406354017`, build `6090`, server `Exness-MT5Trial6`, 969 exact credibility mappings, 10 `ROUND_TRIP`, and 0 `WEAK_FALSE_POSITIVE`. This development regression does not convert D4 into final verification authority.

## Verification-Source Format

`SWV5-SPRINT48-B11-VERIFICATION-SOURCE-V5` is retained. B11.4 strengthens how executable identity and diagnostics are validated but does not change the canonical field set, ordering, or meanings. A new approved source freeze and immutable verification phase remain required.
