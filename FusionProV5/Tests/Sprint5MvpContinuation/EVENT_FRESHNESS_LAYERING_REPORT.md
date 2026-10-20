# RESUME_CLOCK structural / event-freshness separation

SOURCE IMPLEMENTED / COMPILED; REQUIRED POST-FIX MQL EXECUTION IS OPEN.
No full-native handoff or deployment authorization.

## Actual native root-cause evidence

The current Experts log
`C:\Users\Nutthakrit\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Logs\20261013.log`
lines 112-123 records the typed CLOCK publication interruption, exactly one
changed row, sequence 3 -> 4, cold reconstruction, and
`PRESTATE_CLOCK_EVENT_LOCAL_FRESHNESS_MISSING` with
`m_fresh_since_open|required=true|actual=false`.
The operator diagnostic completed with fixture_valid=true and forbidden calls=0.
This proves the cold-recognition layering defect; it is not a baseline-equality
rejection. Fusion explicitly selected a narrower fix than Option R.

Lossless snapshot verification read the actual artifacts, not a PASS summary:

- BEFORE SHA256: D89828B11E4D9C4F55EEF4462C4329F22BD56FF81A62FF3CEBF5F017ADD39A45
- AFTER SHA256: 43974C3DA76C048E2262BFE458C426225B29A4D3CACB4B3529F8701DD5286054
- CLASSIFIED SHA256: identical to AFTER.
- 26 rows in all snapshots; only MVP_OWNERSHIP_LEASE / LEASE_CLOCK_CURRENT changed.
- Observed time 1791814007 -> 1791903901. All 25 other rows exact.
- Raw Experts SHA256 at inspection:
  40AF31461D2C031861ACB3BEB2DFD76DCC9FB4D6EB11802DEA48CAEAAA5ECAB7.

## Exact source design

SW_V5_S5_MvpAttendedContinuation.mqh now shares one LoadStructuralPreState path
between cold classification and the authority-bearing Run path:

1. LoadStored uses the unchanged physical clock validator (canonical decoding,
   valid clock fields, exact digest, sequence/revision and store token).
2. Require clock/profile identity exact, physical target row exact, updated_at
   exact, and clock not behind the persisted Ownership heartbeat/time.
3. Open the authority store read-only. Preserve Ownership/Trust/Account/
   Governance/Hard Kill/RequestSet/Basket/inventory/history predicates.
4. Current native profile time is a diagnostic expiry/history context, NOT a
   rewritten stored observation or newly accepted clock. No durable publication
   or event-freshness reconstruction occurs in structural classification.
5. Require the complete physical read-set unchanged across classification.
6. ClassifyStoredPreState returns structure recognition only:
   accepted=false / NEW_ATTENDED_ATTEMPT_REQUIRED. INACTIVE is diagnosed as
   INITIAL_EXPIRED_PRESTATE; existing activation partials are separately labeled.
7. ClassifyClockOnlyHistoricalPartial can compare a transient before-image and
   require exactly clock +1 with all non-clock rows exact. Its stage is diagnostic
   only; Run never consumes that before-image or state as authority. There is no
   forever-original deployment-clock requirement.
8. Run requires fresh acknowledgement, CurrentFreshObservation on the actual
   new publication object, exact current stored/event payload, exact operator
   event and native profile time. Only then reopen for writes; require the
   structural read-set unchanged before the existing continuation tail.

The attended wrapper consumes physical A before any write, classifies read-only,
captures the complete prior row-set, publishes through the unchanged ordinary
ObserveFromCurrentSymbolOnTick path, proves the new object's freshness and
exact clock-only evolution, then invokes Run. No automatic retry is introduced.

No global m_fresh protections were removed. LoadVerified, CurrentFreshObservation,
ObserveAcceptedEvent and ObserveFromCurrentSymbolOnTick match their HEAD bodies.
No frozen contract, D1/D6/PREFLIGHT/Quote/Broker/Signal/Decision source was changed.
No checkpoint/R+/new domain/second publisher/completion authority was added.

## Files changed in this step

- FusionProV5/ExecutionLayer/RuntimeAuthority/SW_V5_S5_MvpAttendedContinuation.mqh
  (shared structural reader, diagnostic methods, explicit new-event mutation gate,
  read-set checks, TEST_ONLY event-ready stop).
- FusionProV5/Tests/Sprint5MvpContinuation/SW_V5_S5_MVP_ATTENDED_AUTHORITY_CONTINUATION.mq5
  (read-only pre-state before new publication, fresh-object and clock-only checks).
- FusionProV5/Tests/Sprint5MvpContinuation/SW_V5_S5_MvpContinuationAssertions.mqh
  (cold lifecycle, old event rejection, new-ack negative, later native-tick resume,
  persisted-clock negatives and explicit periodic model fixture).
- New verify_event_freshness_layering.py, actual generated evidence JSON, this
  report and updated IMPLEMENTATION_STATUS.md.

All earlier dirty edits were preserved. Existing Governance alias, physical CAS,
activation/release and snapshot implementation were not rewritten in this step.

## Fixture / mutation dispositions

| Gate | Source/compile | Post-fix MQL execution |
| --- | --- | --- |
| RESUME_CLOCK exact typed interruption + one changed row | Prepared | NOT RUN |
| Cold structural recognition / no reconstructed freshness / no grant | Prepared | NOT RUN |
| Old object / old event cannot mutate | Prepared | NOT RUN |
| No new acknowledgement means zero publication | Prepared | NOT RUN |
| Later XAUUSD tick / new accepted clock / continuation completion | Prepared | NOT RUN |
| Boundary exact hook + intended physical stage | Preserved | NOT RUN |
| Valid Governance control accepted / mutated binding rejected | Preserved | NOT RUN |
| Governance alias/distinct regression | Preserved | NOT RUN |
| Periodic epoch 1 -> accepted later clock -> expiry -> cold epoch 2 | Prepared | NOT RUN |
| Persisted clock identity/canonical/digest/token/sequence/time negatives | Prepared | NOT RUN |

The periodic fixture first requires actual production continuation on a fresh
TEST_ONLY clone, then uses the deterministic clock-entry method and an explicitly
TEST_ONLY future profile-time model. It does not edit authority validity windows
or claim a future live native tick. Epoch 2 stops at an explicitly fired EVENT_READY
hook before authority mutation. No Permit/Admission/Claim/Submit is required.
The later native-tick CLOCK fixture models a new acknowledgement within the test
suite; actual physical A handling is separately preserved in the production
wrapper. Neither model is substituted for native execution evidence.

MC-CONT-EVENT-FRESHNESS-BYPASS and three additional event-binding static mutants
are detected. These are source mutation guards, NOT compiled/executed MQL
mutants. Governance's existing five static mutation controls, including
MC-GOV-EXPIRED-ELIGIBILITY-BYPASS, remain detected. Boundary invocation/differential
source guards pass; no execution acceptance/rejection result is fabricated.

## Non-native results and compile

verify_event_freshness_layering.py: 102 passed / 0 failed; 0 post-fix MQL executions.
Includes actual historical native snapshot checks, current isolation/source guards,
13 independent Python clock-oracle cases and preserved Governance/CAS/alias
model regressions. These evidence classes are explicit in the generated JSON.

The prior Governance checker reports 53/54. Its ONLY red gate is
PROVENANCE/compiled-not-older-than-includes for the full-native binary, intentionally
not rebuilt before required execution gates. It is tracked separately, not
waived or hidden. Historical unresolved full-suite failures in that report are
not new post-fix execution results.

MetaEditor X64 Regular, compile only:

- SW_V5_S5_MVP_ATTENDED_AUTHORITY_CONTINUATION:
  0 errors / 0 warnings; EX5 SHA256
  6613F81C26CF0F39FFEEBE361FF653595552A90929BFF5D5C42F424464C4A2EA.
- SW_V5_S5_MVP_CONTINUATION_ASSERTIONS:
  0 errors / 0 warnings; EX5 SHA256
  2840AA2278AD3C9C3760FCCA0F112315771C93B1329EF4ABD975B6236F9384C4.

Neither was installed or executed. The full-native harness was not rebuilt,
installed or given a new preset. The narrow diagnostic's old installed EX5 is
historical evidence only and was not replaced. Old executed full-suite EX5
B70132E9D5BA2CF2882971FBAD5DA1DD2D752A9FF83E1529FD00891DE1557C09
remains unchanged. No operator handoff is authorized by this report.

## Integrity / provenance / blocker

Original deployment DB and immutable donor SHA256 unchanged:
BEC62E7435D29D5511A41BF85C74AE443994C5804B3A9574AF90D861FE674EF6.
Original was hashed only; donor/model connections were read-only/immutable or
private in-memory SQLite. No existing clone/deployment SQLite was mutated.
Governance source remains SHA256
5C0FB4E933A833BB0C4DADD43E84B1683D57A163D5F532276C2E060D378E642A.
Exactly one unchanged production OrderSend site and one attended heartbeat
caller remain. git diff --check passes.

Branch sprint5-phase-f-entry-contract; HEAD
d926f2e6b1aa4ea7b4b0936293d2fa47a2ce7ba8; committed tree
46c09cfbed423df9c93b7f63aaf4b901af5b83fd; main unchanged
32b79ca71ffc331e15e48a57c52be1352e3dbe7e. Current working-tree build is uncommitted;
source SHA256 values are in EVENT_FRESHNESS_LAYERING_EVIDENCE.json.

Remaining blocker is verification: required post-fix MQL lifecycle/boundary/
alias/periodic/clock-negative/full-suite execution has not occurred. This step
forbids running MT5. Therefore the conditional full-native build/install/pre-run
gate cannot honestly be declared ready. No new architecture contradiction is
asserted. No MT5 launch/control, production action, commit, push or merge occurred.

RESUME_CLOCK EVENT-FRESHNESS LAYERING FIX BLOCKED — FUSION REVIEW REQUIRED
