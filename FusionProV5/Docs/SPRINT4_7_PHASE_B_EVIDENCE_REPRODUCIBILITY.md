# Sprint 4.7 Phase B — Evidence Reproducibility and Coverage Closure

Status: **CANDIDATE / IN REVIEW**

Architecture Locked: **NO**

Runtime authorization: **NO**

Sprint 4 remains the authorized architecture baseline. Production Contract V4 remains Candidate and Unlocked.

## Coverage closure review

The actual Phase A implementations were reviewed, not only their reported totals.

| Critical path | Executable IDs | Mutation-resistance conclusion |
|---|---|---|
| Risk projection/request/current-exposure binding | `S47-RISK-01`–`S47-RISK-18` | Reverting to limits-only projection checks makes the understated Basket, symbol, aggregate, notional, margin, REDUCE, CLOSE, and CANCEL cases pass incorrectly; the tests therefore fail and expose the regression. |
| Canonical finite-number validation | `S47-NUM-01`–`S47-NUM-18` | Real MQL NaN and positive-Infinity fixtures cover Risk, execution transaction, acknowledgement, and persisted-authoritative numeric paths. Removing finite checks makes authoritative classes accept or mutate invalid state. |
| Exclusive Hard Kill expiry | `S47-HK-01`–`S47-HK-07` | The exact-expiry case denies and preserves latch/generation, while strictly-before passes and strictly-after denies. |
| Integrity-consistent semantic checkpoint corruption | `S47-CHK-01`–`S47-CHK-18` | Each corrupted checkpoint is resealed before restart. Digest/size remain valid, so an integrity-only implementation would return restart authority and fail these tests. |
| Retry enum allowlisting | `S47-RETRY-01`–`S47-RETRY-12` | Unknown integers, equal-invalid values, invalid retcode/submission/confirmation states, and terminal/conflict states deny. Returning to blacklist semantics exposes the regression. |

No false-positive construction was found. MQL `WEAK_FALSE_POSITIVE` remains zero. The MQL executable inventory remains 634; PowerShell exporter tests are reported separately.

## Authoritative hash model

Repository evidence SHA-256 means exactly one thing: SHA-256 of the exact bytes stored in a staged or committed Git blob. Working-tree bytes are never reported as an immutable repository evidence hash.

Raw verification inputs use a distinct authority: SHA-256 of the exact external input-file bytes selected explicitly by the caller. The exporter records these as raw-input hashes and never silently selects the latest log.

## Deterministic text policy

The Sprint 4.7 exporter writes UTF-8 without BOM, LF line endings, exactly one final newline, and no blank line at EOF. `.gitattributes` explicitly fixes `FusionProV5/Evidence/**` to LF in Git. No manual newline or byte-normalization step is permitted after export.

## Non-circular packaging order

1. Generate the four semantic evidence files from explicit raw inputs.
2. Stage those evidence files.
3. Hash their exact Git index blobs.
4. Generate `evidence_blob_manifest.json` from those hashes.
5. Stage the manifest.
6. Verify every index-blob claim.
7. Commit evidence in the later evidence phase.
8. Verify every committed-blob claim from the immutable evidence commit.

The blob manifest intentionally excludes its own hash. Its `self_hash_policy` is `MANIFEST_EXCLUDED`, eliminating circular dependency.

## Exporter and offline verification

- Exporter: `FusionProV5/Tests/ContractVerification/Export-Sprint47Evidence.ps1`
- Offline tests: `FusionProV5/Tests/ContractVerification/Test-Export-Sprint47Evidence.ps1`
- Exporter modes: `Generate`, `IndexManifest`, `VerifyIndex`, `VerifyCommit`

The offline suite uses only temporary local Git repositories and controlled fixture inputs. It covers deterministic output, LF/final-newline policy, index and commit blob hashing, fresh-checkout reproduction, CRLF working-tree independence, mutation/stale-hash rejection, source/raw-input provenance, duplicate result rejection, credibility totals, signatures, compile results, and failed/skipped executions.

## Historical evidence

`50f0dc5f35f3fafd8604081cee6cb0c07cb9effe` and `683840cf124167f1ccf63bd41fe3ba05e3534a75` remain immutable Sprint 4.6 candidate history superseded by the failed final independent merge audit. They are not current Sprint 4.7 evidence.

Phase B performs no source freeze, evidence commit, final evidence generation, push, merge, Architecture Lock, production-readiness declaration, or runtime authorization.
