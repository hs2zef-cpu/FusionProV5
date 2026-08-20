# Sprint 4.8 Phase B11.5 - Deterministic Fixture and Canonical Provenance

Status: **Candidate / In Review - Unlocked - Pending Approval**

B11.5 closes the two C10 reproducibility findings without changing the production exporter, MQL, runtime, architecture contracts, MQL inventories, credibility inventory, run configurations, or D4 raw evidence. It does not create a source freeze, final evidence, merge authorization, runtime authorization, production readiness, or Architecture Lock. Sprint 4 remains the authorized architecture baseline, and D4 remains failed overall.

## Deterministic Synthetic Fixture

The synthetic fixture source commit is derived only from explicit fixture bytes and canonical Git inputs. Both independently constructed repositories use:

- commit message: `SWV5 deterministic fixture source`
- author and committer name: `SWV5 Deterministic Fixture`
- author and committer email: `swv5-fixture@example.invalid`
- author and committer timestamp: `2000-01-01T00:00:00+00:00`
- commit signing: disabled for the synthetic fixture commit

The fixed timestamp is a synthetic Git-fixture input, not a claimed execution time. No wall clock, GUID, temporary root, machine name, user name, PID, or run counter participates in the synthetic commit. A second repository is populated from the first fixture's exact Git blob bytes, staged independently, and committed with the same canonical inputs. `EXP48-128..132` require blob, tree, commit, root-isolation, and fixed-time equality.

## Canonical Result Fields

Only canonical/source-bound fields participate in `exporter_test_results.json` bytes:

- `schema`
- logical repository-relative `exporter_path`
- `exporter_sha256`
- `test_script_sha256`
- `active_test_script_sha256`
- `identity_provenance.fixture_commit`
- `identity_provenance.fixture_tree`
- canonical fixture commit message, synthetic author, committer, and fixed timestamp
- exporter and test-script repository paths, Git object IDs, and exact-byte SHA-256 identities
- `generated_from`
- `total`, `passed`, `failed`, `skipped`
- derived semantic `signature`
- ordered `cases` containing ordered `id`, `name`, and `passed`

The deterministic fixture commit remains in the canonical result because it is the Git source authority for the exact synthetic inputs, and independent construction proves that identical source produces the same commit.

Diagnostic/volatile fields are excluded from canonical result bytes:

- absolute execution, materialization, output, diagnostic, and temporary paths
- GUID workspace names
- local user, host, and process identity
- wall-clock execution timestamps
- transient repository roots and run counters

Real absolute paths remain permitted in B11.4 failure bundles and console diagnostics because those are noncanonical investigation artifacts. This does not weaken executable identity or cleanup-survival guarantees.

## Serialization Policy

Canonical JSON is built from ordered objects and ordered test cases. Serialization is UTF-8 without BOM, LF-only, with exactly one final LF. Test IDs retain the declared exporter inventory order. No timestamp represents execution time. `EXP48-133..139` enforce path exclusion, independent JSON byte equality, raw SHA equality, property and case order, diagnostic isolation, encoding/newline policy, and source-mutation sensitivity.

Two independent full offline runs each passed 139/139 with 0 failed and 0 skipped. Both produced semantic signature `1fd79d13088dfa18a0c6a862f05b4127fdcabc5ca5c57f13c7147507e0667539`, fixture commit `b2e3788544841f2dce4f62c476917b089d7831f7`, fixture tree `9ba90d9ca173e319f4ad850aa5a3cd56acf4c24a`, and raw result SHA-256 `8bae1d5e1f465b84c41e8fa548c04a71539e75a7f355439873d253586034a585`. Exact byte comparison passed.

## Verification-Source Format

`SWV5-SPRINT48-B11-VERIFICATION-SOURCE-V5` is retained. Its field set, ordering, and meanings are unchanged. The existing exporter-test-result field continues to mean the SHA-256 of canonical exporter offline result bytes; B11.5 corrects those bytes to be reproducible without changing the outer field's semantics.

The exact D4 historical offline Generate regression passed after the B11.5 full runs: both unchanged raws remained 969/969 with signature `18372369681406354017`, build `6090`, server `Exness-MT5Trial6`, 969 credibility mappings, 10 `ROUND_TRIP`, and 0 `WEAK_FALSE_POSITIVE`. Both raw hashes were unchanged before and after. This is a regression check only and cannot convert D4 into final evidence authority. No MQL rerun was authorized or performed.
