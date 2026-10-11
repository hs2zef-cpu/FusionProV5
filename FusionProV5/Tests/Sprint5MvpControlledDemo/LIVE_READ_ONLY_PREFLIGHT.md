# Live read-only attended PREFLIGHT

Narrow Class-B launch binding correction; no deployment or trading authorization.
The accepted native quote binding at
`16080a7eab0f36d58e8fdf0f4174b1640099daec` is unchanged.

## Time and lineage

The former native host demanded that the last administrative clock timestamp
equal the new tick's `TimeCurrent()`. An unexpired deployment therefore failed
on a legitimate later tick. Row equality alone concealed this failed preflight.

The host still opens and physically verifies the persisted clock read-only.
`LoadBaseForReadOnlyPreflight` re-reads and matches the complete canonical
observation, then captures the native profile and broker-server time separately.
Its explicitly ephemeral `MvpReadOnlyPreflightNowObservation` contains no
sequence or durable revision. Foreign profile/clock identity, missing/corrupt
lineage and native time preceding persisted time fail closed.

The diagnostic seed preserves the original clock observation unchanged and
marks itself `read_only_preflight`. The validation context retains the stored
sequence as a **lineage watermark**, not a new observation sequence. Only its
diagnostic evaluation time is current native time. There is no increment, clock
publication, heartbeat, refresh, new record, or promoted durable clock authority.

Existing read-only physical validators already support this distinction:
lease heartbeat sequence must not exceed the persisted watermark, and native
time must fall before physical expiry. Exact physical lease/fence readback,
Hard Kill release/activation lineage, Account namespace and canonical Basket
are still required. PREFLIGHT additionally requires IDLE/v1 and unexpired Trust
and Governance (including capability validity) at current time. No frozen
execution validator is changed.

The diagnostic seed is rejected by every public write-capable Authority Port
entry: D1 preparation, Permit preparation/commit, Admission, Claim, D6 recovery,
callback persistence and adapter command creation. Production dispatch uses the
separate seed only for MODE_PREFLIGHT. D1/D6 still consume their one-shot gate
before publishing a fresh accepted durable OnTick clock. Native quote helpers,
Broker Adapter, Signal/Decision and frozen contracts are untouched.

## Executable traceability

The attended test manifest remains TEST ONLY / NO BROKER MUTATION, and executes
only in Demo Strategy Tester. Its existing 75 assertions are retained; the new
21 assertions produce a 96-case floor.

| ID | Observable assertion |
|---|---|
| PREFLIGHT-CLOCK-01..02 | Complete accepted private setup clone; physically verified clock equals T0 |
| 03..05 | Actual later tester tick T1 > T0; actual native host result is accepted with `PREFLIGHT_COMPLETE_ZERO_SUBMISSION` |
| 06..07 | Clock payload/revision/time unchanged; all ordered physical rows and full database bytes unchanged |
| 08..09 | Second native tick T2 > T1 also accepted; same complete snapshot and bytes |
| 10 | Integrity-valid lease expires at current time; exact stale-lease rejection |
| 11 | Integrity-valid Trust expires at current time; exact expired-Trust rejection |
| 12 | Integrity-valid Governance expires at current time; exact Governance rejection |
| 13-0..2 | Wrong expected broker, server and login each fail the native profile guard |
| 14..15 | Corrupt and missing persisted clock each fail physical lineage load |
| 16 | Existing request set remains empty; no Permit/Claim/submission, Pin or Vector artifacts |
| 17..18 | Actual host submission count zero; no Claim, adapter or transport attempt |
| NO-AUTHORITY-ESCAPE | The real diagnostic seed rejects D1, Permit, Admission, Claim, D6 and adapter construction; store unchanged |

Expiry faults are applied only to explicitly TEST_ONLY clones before each
negative snapshot. Complete payloads/digests/revisions are reconstructed with
production codecs and CAS, not malformed shortcuts. Each negative requires the
specific guard reason and unchanged complete rows after the invocation.

Snapshots compare count, ordered domain/record keys, logical/store revisions,
state, full payload/digest and updated_at. Full main database byte equality also
covers metadata and all stored tables after checkpointing the test setup before
cloning. Diagnostic files are separate from SQLite authority state.

Existing GENESIS envelopes and the setup-initialized empty request-set row are
not newly created execution artifacts; their exact preservation is mandatory.

The test supplies fresh absolute protective geometry for each separate diagnostic
invocation; PREFLIGHT itself never shifts/widens it. Compatibility requested_price
is deliberately stale. Existing native quote assertions remain unchanged.

Zero native OrderSend follows from the actual host result/counts and the unchanged
Runner's PREFLIGHT return before its sole boundary call. This is executable path
and structural proof, **not** an instrumented OS-level OrderSend counter. The
existing non-mutating D1/D6 regression seams are not real broker evidence.

## Gates and limits

MetaEditor X64 Regular must compile all accepted MVP manifests with zero errors
and warnings. Run all accepted MQL/SQLite floors plus Runtime, Phase B/C/D/E/F,
Broker oracle/mutations and source/isolation checks. Launch source audit adds
12 preflight checks to the existing 52. Preserve F0 PRE-EXISTING / WAIVED.

Generate build identity from the clean new commit and rerun the expanded attended
suite after commit. Fresh raw Strategy Tester journals remain local ignored
evidence; Python/source checks must not be called MQL execution.

Never run the native deployment wrappers or create the actual attended authority
database during this gate. No actual D1, Claim, OrderSend, D3, real-exposure D6,
Phase G, main merge or live deployment is authorized by this patch.
