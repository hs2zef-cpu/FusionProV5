# Phase F0 Query Positive-Control / Reconnect Runbook

TEST ONLY / F0 / ATTENDED DEMO ONLY / READ-ONLY / NOT FOR PRODUCTION.

This runbook uses known order `5055862979`, entry deal `4360221913`, and
position ID `5055862979` only as positive controls. It never submits, modifies,
or closes an order or position. Results falsify specific under-reporting modes;
they cannot certify universal broker-history completeness.

## Fixed matrix

The probe executes these server-time selections on every run:

| ID | Window/filter | Purpose |
|---|---|---|
| `WIDE_INCLUDE_FULL` | `1788796719..1788803919`, full enumeration | Must contain entry and cleanup records |
| `WIDE_INCLUDE_REPEAT_FULL` | same selection repeated | Detect transient same-session differences |
| `ENTRY_SECOND_INCLUDE_FULL` | `1788800319..1788800319` | Entry millisecond falls within this server second |
| `BEFORE_ENTRY_EXCLUDE_FULL` | `1788796719..1788800318` | Intentionally excludes entry and cleanup |
| `AFTER_ENTRY_EXCLUDE_FULL` | `1788800320..1788803919` | Intentionally excludes entry; includes later cleanup |
| `CLEANUP_SECOND_INCLUDE_FULL` | `1788800706..1788800706` | Cleanup millisecond falls within this server second |
| `WIDE_INCLUDE_DEPTH_1` | wide window, first row per collection | Client enumeration depth 1 |
| `WIDE_INCLUDE_DEPTH_2` | wide window, first two rows per collection | Client enumeration depth 2 |
| `POSITION_FILTER_KNOWN` | `HistorySelectByPosition(5055862979)` | Exact broker position-link filter |
| `POSITION_FILTER_UNKNOWN` | impossible control ID | Negative position-filter control |

MQL exposes collection totals and indexed enumeration after selection, not a
server pagination-token API. Depth 1/2/FULL are therefore explicitly client
enumeration depths, not claims about server pagination.

## Attended sequence

1. Confirm no open position or active order from the F0 experiment.
2. Run once with `InpObservationLabel=PRE_RECONNECT` and preserve complete
   `F0_PC_ATTEST` through `F0_PC_END` output. The attestation must show the
   current compiler/runtime build and unchanged Demo/HEDGING broker profile.
3. Operator performs one attended disconnect/reconnect or terminal reconnect
   boundary without changing broker, server, account, symbol, build, or source.
4. Run the identical binary with `InpObservationLabel=POST_RECONNECT` and
   preserve complete output, including the new `F0_PC_ATTEST` boundary.
5. Run the ordinary read-only query probe with its 86,400-second default window.
6. Stop. No `OrderSend`, probe arming, position mutation, or retry is authorized.

Any unexpected selection/read failure, missing known record in an include
control, known record in an exclude control, or PRE/POST inconsistency is a
finding. `POSITION_FILTER_UNKNOWN` is the deliberate negative control and may
report selection failure or an empty selected collection; either outcome must
contain no known record. All outcomes retain `completeness=UNPROVEN` unless a
separately approved rule proves the required global coverage.

## Completed build-6182 observation

The authorized PRE_RECONNECT and POST_RECONNECT executions matched the required
Demo/HEDGING broker profile and build 6182. All ten matrix outcomes were
identical across the boundary. The known entry and cleanup records were visible
in their include windows and absent from their exclusion windows; depth 1 and 2
exposed the expected prefixes; the known-position filter returned both linked
records. The unknown-position filter returned `selection_success=0` and error
`4753`, explicitly preventing an unsupported authoritative-empty reading.

Recorded classification: **POSITIVE-CONTROL BEHAVIOR PASS FOR TESTED
WINDOWS/FILTERS/DEPTHS AND SURVIVES READ-ONLY RECONNECT.** Completeness remains
`UNPROVEN`; no `OrderSend` or broker mutation occurred.
