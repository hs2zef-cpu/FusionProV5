# Sprint 4.8 Phase B11.1 — Terminal Build Evidence Parser Closure

## Status

**CANDIDATE / IN REVIEW — UNLOCKED — NOT SOURCE-FROZEN**

Sprint 4 Architecture remains the authorized baseline. Production Contract V5 remains a review candidate. This correction grants no Architecture Lock, runtime authorization, production-readiness claim, merge authorization, or formal approval.

## Original Defect

The B11 exporter required exactly one literal `authorized (agent build N)` record. It ignored the actual immutable D3 agent-log records `MetaTester 5 build 6090, 31 Jul 2026` and `login (build 6090)`. Valid D3 evidence therefore failed before evidence generation.

## Build Evidence Authority

- `MetaTester 5 build N` in a structured Startup record is authoritative process identity and is mandatory.
- `authorized (agent build N)` is optional corroborating agent-authorization identity.
- `login (build N)` is optional corroborating client/login identity; it is not sufficient without MetaTester process identity.
- Arbitrary text containing a build number is ignored and cannot establish authority.
- A record beginning as a supported build record but not matching its complete allowlisted form is malformed and fails closed.
- Multiple supported records may occur. Identical values pass; any disagreement fails.
- The resolved value must equal the expected build, both runs must resolve independently to the same value, optional machine-result build evidence must agree, run summaries must agree, and the verification-source canonical `terminal_build` must agree.

`Resolve-TesterBuildEvidence` is the single resolver used by Generate and by the raw evidence revalidation performed in VerifyIndex and VerifyCommit.

## D3 Resolution

Both immutable D3 runs contain one authoritative MetaTester record and one corroborating login record, both resolving to build `6090`. Neither contains an agent-authorization record. The original Run 1 and Run 2 raw files and hashes remain unchanged.

## Verification-Source Format

`SWV5-SPRINT48-B11-VERIFICATION-SOURCE-V5` is retained because the ordered fields and the semantic meaning of `terminal_build` remain unchanged: it is the resolved, validated tester build. B11.1 corrects which explicit raw record classes can establish that existing meaning.

The former D3 digest `49f90d11d8b1349b243bfc15e929c1fb39f4076b4d894fca7b4bc2e52b9d5d32` is superseded for any successor package because the digest binds the exporter and exporter-test Git blobs, both of which change in B11.1.

## Validation Status

- Dedicated build-parser cases `EXP48-83..92`: passed.
- Complete exporter suite: 92 passed, 0 failed, 0 skipped.
- Exact D3 build resolution: Run 1 = `6090`; Run 2 = `6090`.
- Exact D3 Generate: blocked after build resolution by a distinct pre-existing server-record parser mismatch. The exporter expects a server-qualified `testing of` record, while the immutable agent logs contain the server-qualified `generating based on real ticks` record.

The server-record mismatch is not corrected in B11.1. A separately approved focused correction is required before a new source freeze.

## Preservation

Source `b9b175a5226dd85c3eaacc86c2daca2a42f24b01` remains immutable history but is superseded as the current development candidate once B11.1 changes are introduced. The D3 raw runs remain immutable historical verification inputs. No MT5 rerun, MQL change, source-freeze commit, final evidence, push, merge, Architecture Lock, or runtime authorization occurs in this phase.
