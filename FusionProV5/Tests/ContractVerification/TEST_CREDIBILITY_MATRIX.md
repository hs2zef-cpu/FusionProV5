# Sprint 4.8 Phase B11 V5 Candidate Test Credibility Matrix

> TEST ONLY - NOT FOR PRODUCTION - NO BROKER ACCESS

This matrix classifies every executable ID in the 969-case V5 candidate suite. `TEST_CREDIBILITY_ID_INVENTORY.txt` is the canonical machine-readable exact-one classification authority. The exporter derives all totals from it, checks its exact ID order against `TEST_ID_INVENTORY.txt`, and treats this table as an independent human-readable cross-check.

`ROUND_TRIP` is restricted to a full serialized DTO decoded into a fresh object and reserialized with exact full-representation equality, including its embedded integrity field. Negative decoder tests and digest-preimage-only checks are not round-trip credit.

The audit question for every behavioral row is: if the advertised behavior were removed or intentionally broken, would the material assertion fail? Every behavioral row below answers **yes**. No row is classified by test name or intent alone.

## Totals

| Category | Count | Merge-gating evidence |
|---|---:|---|
| `MERGE_GATING_BEHAVIOR` | 86 | YES |
| `STATE_TRANSITION` | 109 | YES |
| `NEGATIVE_FAIL_CLOSED` | 638 | YES |
| `ROUND_TRIP` | 10 | YES |
| `INVARIANT_BEHAVIOR` | 49 | YES |
| `SUPPORTING_PURE_FUNCTION` | 63 | NO |
| `CONFORMANCE_ONLY` | 14 | NO |
| `WEAK_FALSE_POSITIVE` | 0 | NO |
| **Executable total** | **969** | **892 behavioral; 77 supporting/conformance** |

## Complete classification

| Test ID(s) | Category | Production interface / helper | Prior state | Operation | Material assertion/output | Specific broken behavior detected | Gate? |
|---|---|---|---|---|---|---|---|
| COM-01 | `MERGE_GATING_BEHAVIOR` | Version policy `EvaluateCompatibility` | Valid current V5 candidate/context | Evaluate exact version | Returns true and `EXACT` | Exact compatible version rejected or misclassified | YES |
| COM-02 | `MERGE_GATING_BEHAVIOR` | Version policy | Older compatible schema | Evaluate | `MIGRATION_REQUIRED` | Older schema treated as exact or unusable | YES |
| COM-03 | `NEGATIVE_FAIL_CLOSED` | Version policy | Foreign policy ID | Evaluate | `REJECTED` | Unknown policy accepted | YES |
| COM-04 | `NEGATIVE_FAIL_CLOSED` | Basket `ValidateState` | Valid IDLE; missing authoritative clock | Validate | False and invalid report | Missing clock accepted | YES |
| COM-05 | `INVARIANT_BEHAVIOR` | Basket `ValidateTransition` | ACTIVE version N | Invoke ACTIVE to CLOSING twice | Both return CLOSING/N+1/ALLOW and equal material outputs | Determinism-only default output or wrong transition | YES |
| COM-06 | `NEGATIVE_FAIL_CLOSED` | Basket `ValidateState` | Valid IDLE; zero evaluation sequence | Validate | False and invalid report | Missing sequence accepted | YES |
| COM-07 | `SUPPORTING_PURE_FUNCTION` | `SWV5_TestFenceEqual` | Two equal fences | Mutate fencing digest | Equality becomes false | Equality helper ignores authority digest | NO |
| COM-08 | `SUPPORTING_PURE_FUNCTION` | `SWV5_TestNamespaceEqual` | Two equal namespaces | Mutate Basket ID | Equality becomes false | Namespace helper ignores Basket identity | NO |
| COM-09 | `NEGATIVE_FAIL_CLOSED` | Ownership `Heartbeat` | Active lease with foreign clock | Heartbeat | DENY | Clock binding ignored | YES |
| COM-10 | `NEGATIVE_FAIL_CLOSED` | Version policy | Empty contract name | Evaluate | `REJECTED` | Incomplete version accepted | YES |
| COM-11 | `MERGE_GATING_BEHAVIOR` | Version policy | Output preseeded with wrong version/disposition | Evaluate exact candidate | Preseed replaced by exact candidate, `EXACT`, reason `EXACT` | Method returns success without writing advertised result | YES |
| COM-12 | `NEGATIVE_FAIL_CLOSED` | Basket `ValidateState` | Invalid context | Validate | False and invalid report | Invalid context fails open | YES |
| BSM-01–BSM-07 | `STATE_TRANSITION` | Basket `ValidateTransition` | IDLE version N | Request every target state | Independent table rule; allowed N+1, same/forbidden N | Any IDLE pair or version rule incorrect | YES |
| BSM-08–BSM-14 | `STATE_TRANSITION` | Basket `ValidateTransition` | OPENING version N | Request every target state | Independent table rule and version output | Any OPENING pair incorrect | YES |
| BSM-15–BSM-21 | `STATE_TRANSITION` | Basket `ValidateTransition` | ACTIVE version N | Request every target state | Independent table rule and version output | Any ACTIVE pair incorrect | YES |
| BSM-22–BSM-28 | `STATE_TRANSITION` | Basket `ValidateTransition` | RECOVERY version N | Request every target state | Independent table rule and version output | Any RECOVERY pair incorrect | YES |
| BSM-29–BSM-35 | `STATE_TRANSITION` | Basket `ValidateTransition` | CLOSING version N | Request every target state | Independent table rule and version output | Any CLOSING pair incorrect | YES |
| BSM-36–BSM-42 | `STATE_TRANSITION` | Basket `ValidateTransition` | HALTED version N | Request every target state | Independent table rule and version output | Any HALTED pair incorrect | YES |
| BSM-43–BSM-49 | `STATE_TRANSITION` | Basket `ValidateTransition` | HARD_KILL version N | Request every target state | Independent table rule and version output | Any HARD_KILL pair incorrect | YES |
| BAS-01 | `NEGATIVE_FAIL_CLOSED` | Basket `ValidateAggregate` | Foreign Basket identity | Validate | False | Aggregate attribution ignored | YES |
| BAS-02 | `NEGATIVE_FAIL_CLOSED` | Basket state transition | Recovery counters do not advance | Transition | False; stable state | Recovery regression accepted | YES |
| BAS-03 | `INVARIANT_BEHAVIOR` | Basket `ValidatePartialClose` | Coherent aggregate/evidence | Validate | ALLOW | Valid partial close rejected | YES |
| BAS-04 | `INVARIANT_BEHAVIOR` | Basket `ValidatePartialClose` | Coherent evidence plus adversarial over-close | Validate/replay/mutate/revalidate | Valid calls equal/ALLOW; impossible close DENY; basket unchanged | Default-output determinism or over-close accepted | YES |
| BAS-05 | `NEGATIVE_FAIL_CLOSED` | Basket `ValidatePartialClose` | Closed volume exceeds evidence | Validate | False | Residual arithmetic ignored | YES |
| BAS-06 | `NEGATIVE_FAIL_CLOSED` | Basket `ValidateCloseCompletion` | Missing orders query | Validate | False | Incomplete broker evidence accepted | YES |
| BAS-07 | `NEGATIVE_FAIL_CLOSED` | Basket `ValidateAggregate` | Incomplete ownership namespace | Validate | DENY | Composite identity not enforced | YES |
| BAS-08 | `NEGATIVE_FAIL_CLOSED` | Basket `ValidateAggregate` | Netting-mode aggregate | Validate | False | Unsupported account mode accepted | YES |
| UNT-01 | `MERGE_GATING_BEHAVIOR` | Unit `Normalize` | Valid entry request | Normalize | Tick-aligned price 2400.05 | Price normalization absent/wrong | YES |
| UNT-02 | `NEGATIVE_FAIL_CLOSED` | Unit `ValidateSpecification` | Zero pip size | Validate | False | Invalid specification accepted | YES |
| UNT-03 | `MERGE_GATING_BEHAVIOR` | Unit `Normalize` | Off-step volume | Normalize | Volume rounds down to 0.01 | Unsafe volume rounding | YES |
| UNT-04 | `NEGATIVE_FAIL_CLOSED` | Unit `Normalize` | Below-minimum volume | Normalize | False | Unsafe subminimum accepted | YES |
| UNT-05 | `NEGATIVE_FAIL_CLOSED` | Unit specification | Foreign tick-value currency | Validate | False | Monetary unit mismatch ignored | YES |
| UNT-06 | `NEGATIVE_FAIL_CLOSED` | Unit `Normalize` | Stops-level violation | Normalize | False | Unsafe stop accepted | YES |
| UNT-07 | `NEGATIVE_FAIL_CLOSED` | Unit `Normalize` | Freeze violation | Normalize | False | Frozen operation accepted | YES |
| UNT-08 | `NEGATIVE_FAIL_CLOSED` | Unit `Normalize` | Specification sequence mismatch | Normalize | False | Stale specification accepted | YES |
| UNT-09 | `NEGATIVE_FAIL_CLOSED` | Unit `Normalize` | Missing bid/ask | Normalize | False | Missing market context accepted | YES |
| UNT-10 | `MERGE_GATING_BEHAVIOR` | Unit `Normalize` | Adversarial fractional entry price | Normalize | Direction-safe 2400.10 | Wrong-direction entry rounding | YES |
| OWN-01 | `STATE_TRANSITION` | Ownership `Acquire` | UNCLAIMED lease | Acquire | ACQUIRED, authority epoch N+1, claimant owner | Acquire returns success without usable authority | YES |
| OWN-02 | `MERGE_GATING_BEHAVIOR` | Ownership `DetectConflict` | Active incumbent, foreign claimant | Detect | Conflict DTO contains both owners | Ownership conflict not surfaced | YES |
| OWN-03 | `NEGATIVE_FAIL_CLOSED` | Ownership `Acquire` | Lease marked expired but authoritative sequence not expired | Acquire | False | Time-only false takeover | YES |
| OWN-04 | `NEGATIVE_FAIL_CLOSED` | Ownership `Acquire` | Expired lease; incomplete reconciliation evidence | Acquire | False | Takeover without evidence | YES |
| OWN-05 | `STATE_TRANSITION` | Ownership `Acquire` | Valid expired incumbent | Takeover | New generation 3 | Takeover generation not advanced | YES |
| OWN-06 | `NEGATIVE_FAIL_CLOSED` | Ownership `Heartbeat` | Stale fence digest | Heartbeat | DENY | Stale authority renews lease | YES |
| OWN-07 | `NEGATIVE_FAIL_CLOSED` | Ownership `Release` | Stale CAS revision | Release | False; observed state retained | Stale record releases owner | YES |
| OWN-08 | `MERGE_GATING_BEHAVIOR` | Ownership `DetectConflict` | Simultaneous foreign heartbeat | Detect | Conflict and simultaneous flag | Live conflict omitted | YES |
| OWN-09 | `NEGATIVE_FAIL_CLOSED` | Ownership `Acquire` | Corrupt lease and invalid authority clock | Acquire | DENY/operator required | Corrupt ownership fails open | YES |
| OWN-10 | `NEGATIVE_FAIL_CLOSED` | Ownership `Release` | Stale lease epoch | Release | False; state retained | Stale epoch releases current owner | YES |
| OWN-11 | `NEGATIVE_FAIL_CLOSED` | Ownership `Heartbeat` | Foreign clock ID | Heartbeat | DENY | Clock identity ignored | YES |
| EXE-01 | `INVARIANT_BEHAVIOR` | Execution `ValidateIntent` | Complete intent | Validate | True/ALLOW | Valid execution intent unusable | YES |
| EXE-02–EXE-06, EXE-13 | `MERGE_GATING_BEHAVIOR` | Execution `ClassifyResultRetcode` | Raw accepted/deal/reject/connection/price/volume/unknown retcodes | Classify each | Independent expected class for every mapping | Retcode map aliases acknowledgement, rejection, uncertainty, or revalidation incorrectly | YES |
| EXE-07 | `NEGATIVE_FAIL_CLOSED` | Execution `AcceptTransactionEvidence` | Foreign persistence namespace | Accept | CONFLICT | Foreign evidence confirms request | YES |
| EXE-08 | `NEGATIVE_FAIL_CLOSED` | Execution evidence | Basket-version mismatch | Accept | CONFLICT | Wrong Basket version accepted | YES |
| EXE-09 | `STATE_TRANSITION` | Execution evidence | Pending request | Accept A, replay A using returned state | First mutation; replay duplicate; volumes/identity set stable | Duplicate double-applied or returned state unusable | YES |
| EXE-10 | `STATE_TRANSITION` | Execution evidence | Durable set already contains newer event | Accept unseen older event | CONFIRMED once | Out-of-order unseen evidence discarded | YES |
| EXE-11 | `STATE_TRANSITION` | Execution evidence | Pending 0.10 | Accept authoritative 0.04 | PARTIAL, confirmed 0.04, residual 0.06 | Partial fill treated complete | YES |
| EXE-12 | `NEGATIVE_FAIL_CLOSED` | Execution `EvaluateRetry` | Attempts equal maximum | Evaluate | DENY | Retry limit ignored | YES |
| EXE-14 | `NEGATIVE_FAIL_CLOSED` | Execution evidence | Missing broker event ID | Accept | CONFLICT | Unidentifiable evidence accepted | YES |
| EXE-15 | `NEGATIVE_FAIL_CLOSED` | Execution evidence | Stale ownership fence | Accept | CONFLICT | Stale owner confirms execution | YES |
| EXE-16 | `STATE_TRANSITION` | Execution evidence | ACKNOWLEDGED pending state | Accept order-ack event | ACK-only/PENDING; returned pending is field-equal and unconfirmed | Acknowledgement mutates confirmation state | YES |
| S45A-01–S45A-02 | `STATE_TRANSITION` | Execution evidence | Pending request | Accept acknowledgement/order-ticket events | Returned request unchanged; pending; no event identity | Ack/ticket confirms execution | YES |
| S45A-03–S45A-06 | `NEGATIVE_FAIL_CLOSED` | Execution evidence | Position-only, non-authoritative, zero-volume, or wrong-phase evidence | Accept | Reconcile/conflict; no mutation | Non-authoritative evidence confirms | YES |
| S45A-07–S45A-09 | `STATE_TRANSITION` | Execution evidence | Pending or returned first state | Full, partial, and exact-replay operations | Full/partial material state; duplicate idempotency | Authoritative evidence not applied or duplicate reapplied | YES |
| S45A-10 | `NEGATIVE_FAIL_CLOSED` | Execution evidence | Returned state after event A | Reuse identity with conflicting fingerprint | CONFLICT; returned state unchanged | Same ID/different payload accepted | YES |
| S45F-01 | `NEGATIVE_FAIL_CLOSED` | Execution durable fingerprint | Returned state after authoritative evidence | Mutate each of eight fingerprint-bound fields and replay | Every mutation conflicts without mutation | Fingerprint omits a material field | YES |
| S45F-02 | `INVARIANT_BEHAVIOR` | Persistence plus execution | Returned execution state with fingerprint | Save/load, replay exact and conflicting evidence | Loaded identity survives; exact duplicate; conflict rejected | Durable fingerprint lost across restart; this is persistence/replay behavior, not full DTO reconstruction | YES |
| S45BR-01–S45BR-02 | `STATE_TRANSITION` | Basket recovery transition | ACTIVE then returned RECOVERY state | First recovery, exact replay | Identity added once; replay no-op | Recovery not mutated or duplicate re-applied | YES |
| S45BR-03–S45BR-09 | `NEGATIVE_FAIL_CLOSED` | Basket recovery transition | Returned state after first recovery | Replay with owner/fence/Basket/fingerprint/context/version/counter mutation | DENY; all returned fields unchanged | Known-identity fast path bypasses canonical validation | YES |
| S45BR-10 | `INVARIANT_BEHAVIOR` | Persistence plus recovery | Returned RECOVERY lifecycle | Configure/load checkpoint, replay original request | Loaded state recognizes exact duplicate without mutation | Restart loses recovery identity | YES |
| S45BO-01, S45BO-09 | `STATE_TRANSITION` | Ownership `Acquire` | UNCLAIMED lease | Acquire | Complete coherent ACQUIRED lease and new fence/revision | Stub/patched lease returned | YES |
| S45BO-02–S45BO-08 | `NEGATIVE_FAIL_CLOSED` | Ownership `Acquire` | UNCLAIMED lease | Mutate context, namespace, claimant, key dimensions, duration, or CAS revision | DENY; observed lease field-equal | Unclaimed acquire bypasses canonical validation | YES |
| S45BO-10 | `INVARIANT_BEHAVIOR` | Ownership acquire plus heartbeat validator | UNCLAIMED lease | Acquire then validate returned lease as later lifecycle input | Returned lease is complete and heartbeat-eligible | Acquire result cannot be consumed | YES |
| S45CR-01 | `MERGE_GATING_BEHAVIOR` | Risk `Evaluate`/`ValidateAuthorization` | Complete coherent binding | Evaluate then validate | Every authorization field populated; ALLOW state coherent | Evaluate returns partial or self-contradictory authorization | YES |
| S45CR-02–S45CR-03 | `NEGATIVE_FAIL_CLOSED` | Risk authorization validator | Authorization from valid Evaluate | Mutate every RiskLimit or account-namespace dimension | Every mutation DENY | Validator omits a limit/namespace binding | YES |
| S45CR-04–S45CR-13 | `NEGATIVE_FAIL_CLOSED` | Risk authorization validator | Valid authorization | Mutate mode, Basket/spec, prices/volume, or projected monetary values | DENY | Any operational binding ignored | YES |
| S45CR-14 | `NEGATIVE_FAIL_CLOSED` | Risk authorization validator | Valid authorization | Mutate each monetary-basis category | Every mutation DENY | Currency/conversion/basis/completeness omitted | YES |
| S45CR-15–S45CR-19 | `NEGATIVE_FAIL_CLOSED` | Risk authorization validator | Valid authorization | Mutate Hard Kill ID/generation/expiry, fence, or request identity | DENY | Safety/identity binding ignored | YES |
| S45CR-20 | `NEGATIVE_FAIL_CLOSED` | Risk authorization validator | Valid ALLOW authorization | Inject blocking domain or reason flag | DENY | Contradictory ALLOW accepted | YES |
| S45CR-21–S45CR-29 | `NEGATIVE_FAIL_CLOSED` | Risk authorization validator | Valid authorization | Mutate version, IDs, snapshot, time, intent direction/type, or persistence Basket | DENY | Remaining binding category ignored | YES |
| S45CU-01–S45CU-02, S45CU-04–S45CU-06 | `MERGE_GATING_BEHAVIOR` | Unit `Normalize` | Open/increase/reduce/full-close/residual-close requests | Normalize | Derived semantic, rounding, volume, exposure outputs | Caller flags select policy or close semantics wrong | YES |
| S45CU-03, S45CU-07–S45CU-13 | `NEGATIVE_FAIL_CLOSED` | Unit `Normalize` | Flag override, impossible residual, wrong-side/freeze/stops/stale/contradictory requests | Normalize | False | Unsafe unit input accepted | YES |
| S45CU-14 | `MERGE_GATING_BEHAVIOR` | Unit `Normalize` | Off-step lot | Normalize | Down-rounded aligned volume | Lot step ignored | YES |
| S45CU-15 | `NEGATIVE_FAIL_CLOSED` | Unit `Normalize` | Below-minimum and above-maximum requests | Normalize | Both false | Range limits ignored | YES |
| S45CU-16 | `INVARIANT_BEHAVIOR` | Unit `Normalize` | Identical valid inputs | Normalize twice | Full normalized DTO and decision equal | Nondeterministic output | YES |
| S45CU-17–S45CU-18 | `MERGE_GATING_BEHAVIOR` | Unit `Normalize` | Buy/sell limit targets | Normalize | Direction-safe down/up target price | Target rounding increases execution risk | YES |
| S45CU-19–S45CU-20 | `NEGATIVE_FAIL_CLOSED` | Unit `Normalize` | Invalid volume step or absent market | Normalize | False | Malformed units/market accepted | YES |
| S45DO-01–S45DO-08 | `STATE_TRANSITION` | Ownership acquire/heartbeat | UNCLAIMED lease | Acquire, then heartbeat #1/#2/#3 using each returned lease | Status, sequences, times, expiry, stable fence, and changing CAS revision | Heartbeat fabricates input, changes authority, or returns unusable lease | YES |
| S45DO-09–S45DO-16 | `NEGATIVE_FAIL_CLOSED` | Ownership heartbeat | Active lease | Mutate owner, namespace, fence, epoch, heartbeat, clock, CAS revision, or expiry | DENY and field-equal observed lease | Stale/foreign heartbeat mutates state | YES |
| S45DO-17 | `STATE_TRANSITION` | Ownership takeover | Expired incumbent with complete typed evidence | Acquire | ACQUIRED | Valid takeover unavailable | YES |
| S45DO-18–S45DO-30 | `NEGATIVE_FAIL_CLOSED` | Ownership takeover | Expired incumbent | Mutate generation, nested/top-level identity, lease/CAS/liveness/clock/evidence/authority fields | DENY and field-equal incumbent | Typed takeover binding omitted | YES |
| S45DO-31 | `STATE_TRANSITION` | Ownership takeover/heartbeat | Expired incumbent | Takeover then heartbeat returned lease | New epoch/generation/revision/owner and usable renewal | Takeover result incoherent | YES |
| S45DO-32 | `INVARIANT_BEHAVIOR` | Ownership plus Risk | Risk authorization bound to acquired fence | Same-owner heartbeat then revalidate authorization | Fence equal; authorization remains valid | Heartbeat invalidates same-owner authority | YES |
| S45DO-33 | `NEGATIVE_FAIL_CLOSED` | Ownership plus Risk | Authorization bound to prior incumbent | Valid takeover then validate old authorization | New fence differs and old authorization DENY | Takeover fails to fence stale owner | YES |
| S45DP-01–S45DP-03 | `SUPPORTING_PURE_FUNCTION` | Canonical persisted-request serializer | Adversarial delimiter/unicode/field-split payload pairs | Serialize | Typed length-prefix encodings differ | Canonical field-boundary collision | NO |
| S45DP-04–S45DP-07 | `SUPPORTING_PURE_FUNCTION` | Request-set digest helper | Canonical two-request set | Mutate nested string/numeric/fingerprint or order | Digest changes | Digest omits content/order | NO |
| S45DP-08–S45DP-12 | `NEGATIVE_FAIL_CLOSED` | Persistence `SavePendingRequests` | Canonical stored/set state | Supply copied digest, count/sequence/namespace mismatch, or stale revision | Save rejects | Invalid header/payload overwrites storage | YES |
| S45DP-13–S45DP-14 | `SUPPORTING_PURE_FUNCTION` | Canonical set/digest helpers | Independently constructed equal fixtures | Compare independent results, then adversarially mutate content/cardinality | Equal fixtures equal; changed fixtures differ | Self-comparison false positive or constant canonicalizer | NO |
| S45DP-15–S45DP-16 | `INVARIANT_BEHAVIOR` | Persistence Save/Load | Request set A, then replacement B | Save/load A; save B/load B/latest | Full equality and stale A absent | Save succeeds without storage/replacement semantics | YES |
| PER-01 | `INVARIANT_BEHAVIOR` | Persistence `ValidateRecord` | Valid checkpoint | Validate | Loaded/valid | Canonical record rejected | YES |
| PER-02 | `NEGATIVE_FAIL_CLOSED` | Persistence `ValidateRecord` / `SaveCheckpoint` / `LoadLatest` | Valid canonical checkpoint is saved; copied checkpoint mutates nested recovery attempts while retaining its original non-empty digest and payload size | Validate and save corrupted copy; reload latest | Both corrupted operations reject; stored valid checkpoint remains field-equal | Payload integrity reduced to `payload_digest != "" && payload_size > 0` | YES |
| PER-03–PER-04 | `NEGATIVE_FAIL_CLOSED` | Persistence record validator | Corrupt sequence or namespace | Validate | False | Corrupt/foreign record accepted | YES |
| PER-05 | `MERGE_GATING_BEHAVIOR` | Persistence `ReconcileRestart` | Matched empty checkpoint/broker | Reconcile | Matched and checkpoint-required | Restart result absent/wrong | YES |
| PER-06–PER-08 | `NEGATIVE_FAIL_CLOSED` | Restart reconciliation | Broker ahead, persistence ahead, incomplete queries | Reconcile | Correct halt/manual status | Restart becomes ready on mismatch | YES |
| PER-09 | `MERGE_GATING_BEHAVIOR` | Restart reconciliation | Complete uncertain pending set | Reconcile | Reconciliation-required readiness | Uncertain request resumes blindly | YES |
| PER-10–PER-11 | `NEGATIVE_FAIL_CLOSED` | Restart reconciliation | Checksum failure or stale fence | Reconcile | Corrupt/ownership halt | Corrupt or stale owner resumes | YES |
| PER-12 | `MERGE_GATING_BEHAVIOR` | Restart reconciliation | Persisted active Hard Kill | Reconcile | CLOSE_ONLY | Restart clears latch | YES |
| PER-13–PER-15 | `NEGATIVE_FAIL_CLOSED` | Restart reconciliation | Copied digest, incomplete namespace, or foreign member | Reconcile | Conflict/HALTED | Invalid set resumes | YES |
| RSK-01–RSK-07 | `NEGATIVE_FAIL_CLOSED` | Risk `Evaluate`/authorization | Hard Kill, stale fence/snapshot, low equity, loss, volume, or basket-loss violation | Evaluate/validate | No ALLOW | Risk limits fail open | YES |
| RSK-08–RSK-10 | `NEGATIVE_FAIL_CLOSED` | Risk authorization | Valid authorization then spec/expiry/volume mutation | Validate | False | Authorization not bound/expired | YES |
| RSK-11–RSK-16 | `NEGATIVE_FAIL_CLOSED` | Risk/Hard Kill validator | Invalid release/latch/snapshot/generation/monetary/request binding | Validate | False | Safety or identity mutation accepted | YES |
| STA-01 | `INVARIANT_BEHAVIOR` | Statistics `ValidateDeal` | Complete authoritative entry deal | Validate | True | Valid deal rejected | YES |
| STA-02 | `STATE_TRANSITION` | Statistics `AccumulateDeal` | Current statistics/durable identity set | Accumulate unique deal | Money components, net, counts, and identity all advance from prior state | Local net arithmetic passes while accumulator does nothing | YES |
| STA-03 | `STATE_TRANSITION` | Statistics accumulator | Residual 0.30 | Accumulate 0.10 exit | Residual 0.20 and partial count +1 | Partial close accounting absent | YES |
| STA-04 | `STATE_TRANSITION` | Statistics accumulator | Existing identity set | Accumulate duplicate | All money/count/identity state stable except duplicate counter +1 | Duplicate double-counts or silently changes identity | YES |
| STA-05–STA-07 | `NEGATIVE_FAIL_CLOSED` | Statistics validators | Foreign Basket, incomplete money, or incomplete history | Validate | False | Invalid statistics evidence accepted | YES |
| STA-08 | `STATE_TRANSITION` | Statistics accumulator/finalizer | Residual equals deal volume | Accumulate returned next state, then finalize it | Residual zero, ALLOW, monetary and identity flags | Fabricated final state hides broken accumulation/finalization | YES |
| STA-09 | `NEGATIVE_FAIL_CLOSED` | Statistics validator | Netting mode | Validate | False | Unsupported mode accepted | YES |
| STA-10 | `STATE_TRANSITION` | Statistics accumulator | Identity set with higher sequence | Accumulate unseen older deal | Unique count/identity +1; high watermark stable | Out-of-order unique deal lost | YES |
| STA-11–STA-13 | `NEGATIVE_FAIL_CLOSED` | Statistics accumulator/validator | Missing proof, identity conflict, or currency | Accumulate/validate | False | Dedup or monetary completeness fails open | YES |
| XDM-01 | `MERGE_GATING_BEHAVIOR` | Ordered Unit/Risk/Persistence/Execution gates | Coherent cross-domain fixtures | Invoke every gate | All material decisions succeed and transaction confirms | Hidden cross-domain incompatibility | YES |
| XDM-02 | `NEGATIVE_FAIL_CLOSED` | Execution evidence | Acknowledged request with takeover fence mismatch | Accept | CONFLICT | Stale owner confirms | YES |
| XDM-03 | `MERGE_GATING_BEHAVIOR` | Restart reconciliation | Complete uncertain request set | Reconcile | Reconciliation required | Blind retry after restart | YES |
| XDM-04 | `NEGATIVE_FAIL_CLOSED` | Basket close completion | Residual position | Validate | DENY | Residual exposure marked complete | YES |
| XDM-05–XDM-06 | `NEGATIVE_FAIL_CLOSED` | Risk/Unit | Spec mismatch or active Hard Kill | Validate/evaluate | DENY/no ALLOW | Safety gate bypass | YES |
| XDM-07 | `STATE_TRANSITION` | Execution evidence | Pending request | Accept then replay returned state | Duplicate no second mutation | Cross-domain duplicate double-applied | YES |
| XDM-08–XDM-10 | `NEGATIVE_FAIL_CLOSED` | Persistence/Risk | Missing restart evidence, stale owner, or invalid release | Reconcile/validate | Halt/DENY | Recovery/ownership/Hard Kill fails open | YES |
| XDM-11 | `STATE_TRANSITION` | Execution plus Persistence | ACKNOWLEDGED request | Accept actual ack, persist returned state, reconcile restart | Unconfirmed volume remains zero and restart is retry-forbidden | Fabricated uncertainty or acknowledgement treated as confirmation | YES |
| XDM-12 | `NEGATIVE_FAIL_CLOSED` | Basket close completion | Closing Basket with residual | Validate | False | Partial close declared complete | YES |
| IFC-01, IFC-03 | `STATE_TRANSITION` | Basket recovery | ACTIVE/returned RECOVERY state | First recovery and exact replay | Counters/identity advance once; replay stable | Recovery state not exposed/idempotent | YES |
| IFC-02 | `NEGATIVE_FAIL_CLOSED` | Basket recovery | Non-advancing recovery counters | Transition | False/stable version | Regression accepted | YES |
| IFC-04 | `INVARIANT_BEHAVIOR` | Execution `ValidateIntent` | Complete pre-submission identity | Validate | True and identity complete | Valid interface input unusable | YES |
| IFC-05, IFC-07, IFC-09, IFC-16–IFC-17, IFC-22, IFC-32 | `MERGE_GATING_BEHAVIOR` | Phase/Persistence/Risk/Unit/Hard Kill/Retry interfaces | Canonical positive fixtures | Invoke named behavior | Expected material ALLOW/state/normalized/restart output | Interface callable but advertised positive behavior absent | YES |
| IFC-06, IFC-08, IFC-10–IFC-15, IFC-18, IFC-20–IFC-21, IFC-23, IFC-28 | `NEGATIVE_FAIL_CLOSED` | Named interface validators | One realistic invalid binding per ID | Invoke | DENY/halt | Corrective contract boundary ignored | YES |
| IFC-19 | `STATE_TRANSITION` | Ownership takeover | Expired lease with typed evidence | Acquire | New generation | Typed takeover unavailable | YES |
| IFC-24–IFC-25 | `STATE_TRANSITION` | Execution evidence | Returned pending state | A/B/replay A or unseen older event | Durable idempotency/order material state | Event state not reconstructed | YES |
| IFC-26–IFC-27 | `STATE_TRANSITION` | Execution evidence | ACK or pending request | Accept actual ack or partial fill | Returned pending/partial state and residual inspected | Ack confirmation or partial residual defect | YES |
| IFC-29 | `STATE_TRANSITION` | Statistics accumulator | Existing duplicate identity | Accumulate duplicate | Money stable; duplicate count +1 | Duplicate double-counts | YES |
| IFC-30–IFC-31, IFC-37 | `INVARIANT_BEHAVIOR` | Basket/Risk interfaces | Identical/valid fixtures | Replay transition, validate state/limits | Equal material outputs or valid report | Determinism/positive invariant broken | YES |
| IFC-33–IFC-36 | `INVARIANT_BEHAVIOR` | Persistence Configure/Save/Load | Checkpoint or request-set state | Configure/load, save/load empty set, save/load checkpoint after caller mutation | Loaded material state equals pre-mutation source | Invocation-only Save/Load or shallow copy | YES |
| IFC-38 | `CONFORMANCE_ONLY` | Statistics `Finalize` | Complete deterministic fixture | Invoke | Returns nonzero validation flags | Method/signature/output-shape regression; semantic finalize behavior is gated by STA-08 | NO |
| IFC-39–IFC-40 | `STATE_TRANSITION` | Ownership heartbeat/conflict/release | Active lease | Renew/detect or release | Returned status/sequences/time/expiry/conflict/released state | Remaining ownership methods do not perform advertised transition | YES |
| PRT-01–PRT-05 | `INVARIANT_BEHAVIOR` | Persistence Configure/Save/Load | Single/multiple/partial/uncertain payloads | Store then load | Field equality, order, and lifecycle content | Shallow/incomplete reconstruction | YES |
| PRT-06–PRT-08 | `NEGATIVE_FAIL_CLOSED` | Persistence | Foreign namespace or corrupt header/digest/revision | Load/save | False; output cleared where applicable | Foreign/corrupt storage accepted | YES |
| PRT-09–PRT-10 | `INVARIANT_BEHAVIOR` | Persistence | Stored multiple/single records | Repeated load or caller mutation after Save | Independent equal loads; stored state isolated | Nondeterministic or shallow storage | YES |
| PRT-11 | `NEGATIVE_FAIL_CLOSED` | Persistence `LoadPendingRequests` | Unconfigured store | Load | False, empty output, truncated status | Missing storage treated as valid | YES |
| S44-01–S44-04 | `MERGE_GATING_BEHAVIOR` | Restart reconciliation | Empty, uncertain, retry-forbidden, or Hard Kill persisted state | Reconcile | Safe/reconcile/retry-forbidden/close-only disposition | Complete-set readiness policy absent | YES |
| S44-05–S44-09 | `NEGATIVE_FAIL_CLOSED` | Persistence/restart | Residual mismatch or nested/order/revision/digest tamper | Reconcile/save | Halt/reject | Payload/header integrity ignored | YES |
| S44-10–S44-11 | `STATE_TRANSITION` | Persistence Save/LoadLatest | Two-record set then empty replacement | Save/load latest | Latest summary is final record then cleared | Stale latest summary | YES |
| S44-12 | `MERGE_GATING_BEHAVIOR` | Risk Evaluate/Validate | Complete binding | Evaluate then validate | Complete authorization and projection output | Partial authorization output | YES |
| S44-13–S44-15 | `NEGATIVE_FAIL_CLOSED` | Risk validator | Missing auth field or changed Hard Kill namespace/generation | Validate | DENY | Safety binding ignored | YES |
| S44-16–S44-17 | `STATE_TRANSITION` | Recovery/Execution | Initial then returned state | Accept first/second evidence and replay | Durable identity added once; replay stable | State mutation or replay semantics absent | YES |
| S44-18 | `NEGATIVE_FAIL_CLOSED` | Execution evidence | Returned state after event A | Reuse ID with changed event | CONFLICT | Fingerprint conflict accepted | YES |
| S44-19–S44-21 | `STATE_TRANSITION` | Statistics/Ownership | Current returned stats or lease | Accumulate/replay; unseen older deal; three returned-state heartbeats | Money/idempotency/order; stable fence with monotonic liveness/revision | Duplicate accounting, out-of-order loss, or heartbeat authority conflation | YES |
| S44-22–S44-25 | `NEGATIVE_FAIL_CLOSED` | Ownership heartbeat/takeover | Active/expired lease | Stale heartbeat or malformed/duplicate/foreign takeover | Reject; no unsafe mutation | Stale owner or invalid takeover accepted | YES |
| S46AE-01 | `MERGE_GATING_BEHAVIOR` | Execution `ValidateIntent` | Canonical current V4 execution envelope | Validate | ALLOW | Complete canonical execution envelope unusable | YES |
| S46AE-19, S46AE-22, S46AE-29 | `STATE_TRANSITION` | Execution acknowledgement/deal and ownership heartbeat | Canonical pending request or active same-owner lease | Accept evidence or heartbeat, then inspect returned state | Ack remains pending; deal confirms; heartbeat keeps authority usable | Ack confirmation, confirmation omission, or heartbeat authority churn | YES |
| S46AE-02–S46AE-18, S46AE-20–S46AE-21, S46AE-23–S46AE-28, S46AE-30–S46AE-42 | `NEGATIVE_FAIL_CLOSED` | Canonical execution-envelope validators | One exact contract, namespace, fence, lifecycle, identity, or context mutation | Invoke authoritative validation path | DENY/conflict without unsafe state mutation | Any V4 envelope fast-path bypass | YES |
| S46BR-01 | `MERGE_GATING_BEHAVIOR` | Risk `Evaluate` / `ValidateAuthorization` | Complete current risk input | Evaluate and validate returned authorization | ALLOW with complete bound projection/authorization | Canonical Risk authorization unavailable | YES |
| S46BR-02–S46BR-31 | `NEGATIVE_FAIL_CLOSED` | Risk evaluator/authorization validator | One semantic, limit, freshness, account-mode, Hard Kill, namespace, or version mutation | Evaluate/validate | DENY | Unsafe Risk input returns ALLOW | YES |
| S46BH-01 | `MERGE_GATING_BEHAVIOR` | Risk `ValidateHardKillRelease` | Complete independent current release evidence | Validate | ALLOW | Valid independent Hard Kill release unavailable | YES |
| S46BH-02–S46BH-40 | `NEGATIVE_FAIL_CLOSED` | Risk Hard Kill release validator | One proof, authority, approval, account, epoch, generation, clock, or identity mutation | Validate | DENY | Incomplete/self/foreign/stale release clears latch | YES |
| S46CP-01 | `INVARIANT_BEHAVIOR` | Persistence canonical checkpoint validator | Fully sealed checkpoint | Validate | True | Valid canonical checkpoint rejected | YES |
| S46CP-02–S46CP-12, S46CP-15, S46CP-18–S46CP-20 | `NEGATIVE_FAIL_CLOSED` | Persistence checkpoint validator/store | Sealed checkpoint with one material payload/header/sequence mutation and stale integrity envelope | Validate/save/load | Reject without corrupting stored state | Checkpoint integrity or sequence binding omitted | YES |
| S46CP-13–S46CP-14 | `SUPPORTING_PURE_FUNCTION` | Canonical checkpoint serializer/digest | Unicode or independently equal checkpoint fixtures | Serialize/hash | Stable distinct/equal output as applicable | Nondeterministic or encoding-unsafe canonicalizer | NO |
| S46CP-16–S46CP-17 | `INVARIANT_BEHAVIOR` | Persistence checkpoint Save/Load | Canonical sealed checkpoint | Save, mutate caller, load | Full stored payload reconstructed and isolated | Shallow or incomplete checkpoint storage | YES |
| S46EI-01–S46EI-02, S46EI-12–S46EI-13 | `STATE_TRANSITION` | Durable event identity set | Empty or populated typed identity set | Insert, replay, accept unseen older identity | Cardinality/order/high-watermark update exactly once | Duplicate application or out-of-order loss | YES |
| S46EI-10–S46EI-11, S46EI-14, S46EI-19–S46EI-20 | `NEGATIVE_FAIL_CLOSED` | Durable event identity validator | Conflicting fingerprint, malformed encoding, or count mismatch | Validate/insert | Reject with stable prior set | Ambiguous/conflicting durable identity accepted | YES |
| S46EI-03–S46EI-09, S46EI-16–S46EI-18 | `SUPPORTING_PURE_FUNCTION` | Typed event encoder/digest | Delimiter, Unicode, and individual-field mutations | Encode/hash | Boundary-safe distinct output | Concatenation collision or omitted digest field | NO |
| S46EI-15 | `INVARIANT_BEHAVIOR` | Persistence checkpoint Save/Load | Checkpoint containing typed identity set | Save/load | Full ordered identity set reconstructed | Durable idempotency lost at restart | YES |
| S46DR-01, S46DR-09, S46DR-12 | `MERGE_GATING_BEHAVIOR` | Execution `EvaluateRetry` | Current retry candidate with complete current evidence; fresh proof supplied where required | Evaluate | RETRY_ALLOWED | Valid current retry is unusable or mandatory typed proof cannot authorize | YES |
| S46DR-02–S46DR-08, S46DR-10–S46DR-11, S46DR-13–S46DR-19 | `NEGATIVE_FAIL_CLOSED` | Execution `EvaluateRetry` | One context, contract, owner, deadline, freshness, specification, Basket, budget, lifecycle, or request mutation | Evaluate | DENY | Expired/stale/foreign/unsafe retry allowed | YES |
| S46DR-20 | `INVARIANT_BEHAVIOR` | Execution `EvaluateRetry` | Valid canonical pending request and proof | Evaluate and compare pre/post request | RETRY_ALLOWED and pending request field-equal | Validation mutates request before actual submission | YES |

| S46E1-01, S46E1-12 | `INVARIANT_BEHAVIOR` | Durable fingerprint integrity/classification | Canonical REQUIRED set; Unicode/delimiter identity and fingerprint | Validate, append, classify | Exact one-to-one set validates and boundary-bearing values replay as one duplicate | Required mapping cannot represent valid canonical evidence safely | YES |
| S46E1-02, S46E1-19 | `STATE_TRANSITION` | Fingerprint append; Statistics accumulator | Existing exact mapping or duplicate deal identity | Replay through advertised interface | No identity/money mutation; duplicate counter changes exactly once | Duplicate evidence double-applied or stored identity mutates | YES |
| S46E1-03 through S46E1-11, S46E1-14 through S46E1-18, S46E1-20 | `NEGATIVE_FAIL_CLOSED` | Durable fingerprint validator/classifier; Persistence; Execution | Conflicting, duplicate, orphan, malformed, count-mismatched, reordered, digest-stale, checkpoint-embedded, or execution-conflict state | Validate/classify/save/load/accept | Reject/conflict without storage or exposure mutation | Ambiguous fingerprint state accepted or mutates authoritative state | YES |
| S46E1-13 | `MERGE_GATING_BEHAVIOR` | Durable fingerprint classifier | Same ambiguous mapping candidates in opposite order | Classify both | Both return CONFLICT | Classification depends on first matching entry/order | YES |

## Rewritten false-positive patterns

The Phase E rewrite removed all known false-positive patterns:

- COM-05 and COM-11 now require specific material outputs and overwrite a hostile preseed.
- BAS-04 now pairs valid deterministic replay with an adversarial rejection.
- EXE-16, IFC-26, and XDM-11 now invoke transaction-evidence behavior instead of inferring confirmation from local state or retcode classification.
- STA-02, STA-04, and STA-08 consume returned accumulator state and verify monetary, identity, duplicate, and finalization behavior.
- IFC-35 and IFC-36 now observe Save through Load and verify deep-copy isolation.
- S45DP-13 and S45DP-14 compare independently constructed fixtures and require adversarial differences.
- S44-21 now performs three heartbeats, feeding each returned lease into the next operation.
- PER-02 now begins with a valid saved checkpoint, mutates a material nested recovery field while retaining the old non-empty digest and size, and requires validation/save rejection plus intact reload of the prior state.

No executable ID was removed. Helper-only canonical/equality cases are retained as supporting evidence and are excluded from the behavioral count.

## Sprint 4.7 Phase A adversarial additions

Every case starts from the named valid builder, mutates only the listed field(s), invokes the public test implementation, and asserts the material disposition plus unchanged authoritative state where mutation is possible. Removing the targeted canonical predicate makes the corresponding case fail.

| IDs | Category | Valid baseline | Exact mutations by ID | Material assertion / defect detected |
|---|---|---|---|---|
| S47-RISK-01, S47-RISK-18 | `MERGE_GATING_BEHAVIOR` | `SWV5_TestMakeRiskInput` OPEN with external current exposure | 01 none; 18 all exposure/notional projections within tolerance | `Evaluate` returns complete ALLOW; detects an over-strict or unusable causal invariant |
| S47-RISK-02 through S47-RISK-17 | `NEGATIVE_FAIL_CLOSED` | Same valid OPEN | 02 Basket volume zero; 03 symbol unchanged; 04 aggregate unchanged; 05 notional zero; 06 margin zero; 07 free margin shortfall; 08 account cap exceeded; 09 INCREASE does not increase Basket; 10 REDUCE increases Basket; 11 CLOSE leaves residual; 12 CANCEL adds exposure; 13 Basket above symbol; 14 symbol above aggregate; 15 loss zero; 16 foreign exposure namespace; 17 long/net mismatch | No ALLOW and authorization cleared; detects projection-as-unbound-caller-assertion and incoherent current exposure |
| S47-NUM-01 through S47-NUM-11 | `NEGATIVE_FAIL_CLOSED` | Valid Risk input | NaN in intent volume/price, six projection fields, equity, free margin, or a floating limit respectively | `Evaluate` denies with cleared authorization; detects NaN comparison bypass |
| S47-NUM-12 through S47-NUM-17 | `NEGATIVE_FAIL_CLOSED` | Valid pending request and transaction/acknowledgement | NaN volume, NaN price, +Infinity volume, +Infinity price, acknowledgement NaN volume, acknowledgement NaN price | `AcceptTransactionEvidence` rejects and returns field-equal pending exposure/durable identity state; detects non-finite authoritative mutation |
| S47-NUM-18 | `NEGATIVE_FAIL_CLOSED` | Valid persisted pending request set | NaN in latest authoritative cumulative confirmation | `SavePendingRequests` denies; detects restart-persistable non-finite state |
| S47-HK-01 | `MERGE_GATING_BEHAVIOR` | Complete independent release evidence | Current time strictly before expiry | Release validates; detects unusable exclusive interval |
| S47-HK-02 through S47-HK-07 | `NEGATIVE_FAIL_CLOSED` | Same release evidence | 02 exact expiry; 03 after expiry; 04 expiry equals approval; 05 zero expiry; 06 reversed ordering; 07 exact expiry with state snapshot | DENY; 07 additionally proves latch/generation unchanged; detects equality-at-expiry authority |
| S47-CHK-01 through S47-CHK-18 | `NEGATIVE_FAIL_CLOSED` | Valid checkpoint/restart input, then canonical reseal | 01 Hard Kill enum; 02 Basket enum; 03 pending lifecycle; 04 retry disposition; 05 correlation phase; 06 contract identity; 07 namespace; 08 account mode; 09 negative residual; 10 confirmed above request; 11 intent enum; 12 direction; 13 durable index; 14 incomplete ACTIVE latch; 15 incoherent RELEASE_PENDING generation; 16 foreign fence; 17 foreign restart namespace; 18 foreign broker namespace | Digest and size remain valid but `ReconcileRestart` never returns SAFE/matched; detects integrity-only restart authority |
| S47-RETRY-01, S47-RETRY-11 | `MERGE_GATING_BEHAVIOR` | `SWV5_TestMakeRetryCandidate` plus current Risk/normalization evidence | No mutation | Explicit eligible lifecycle/state/disposition returns ALLOW; detects unusable whitelist |
| S47-RETRY-02 through S47-RETRY-10 | `NEGATIVE_FAIL_CLOSED` | Same valid retry envelope | 02 lifecycle 99; 03 policy disposition 99; 04 matching invalid pending/correlation phase; 05 matching invalid pending/policy disposition; 06 retcode class 99; 07 nested submission correlation phase 99; 08 terminal state; 09 reconciliation state; 10 confirmation conflict | DENY; detects blacklist-based fail-open and equal-invalid-value acceptance |
| S47-RETRY-12 | `INVARIANT_BEHAVIOR` | Same valid retry envelope | No mutation; retain pre-call snapshot | ALLOW and field-equal pending input; detects retry evaluation mutating caller state |

## Sprint 4.8 Phase B5 V5 additions

| IDs | Category | Material credibility |
|---|---|---|
| S48-MARGIN-01 through S48-MARGIN-15 | 2 `MERGE_GATING_BEHAVIOR`; 13 `NEGATIVE_FAIL_CLOSED` | Coherent broker-authoritative total-margin equation permits the two tolerance-valid cases; request/account/namespace/fence/spec/freshness/equation/free-margin/cap/non-finite/digest/source mutations deny. |
| S48-LOSS-01 through S48-LOSS-15 | 2 `MERGE_GATING_BEHAVIOR`; 13 `NEGATIVE_FAIL_CLOSED` | Complete resulting Basket loss includes existing, incremental, adjustment, monetary basis, identity, source and freshness; impaired or underbound projections deny. |
| S48-NOTIONAL-01 through S48-NOTIONAL-10 | 2 `MERGE_GATING_BEHAVIOR`; 8 `NEGATIVE_FAIL_CLOSED` | Contract size, supported calculation mode, authoritative specification, conversion basis, request price/volume and sequence materially bind aggregate notional. |
| S48-RST-01 through S48-RST-20 | 1 `MERGE_GATING_BEHAVIOR`; 19 `NEGATIVE_FAIL_CLOSED` | SAFE_TO_RESUME requires exact V5, clean shutdown, MATCHED reconciliation, complete broker vector/query/namespace/ownership bindings and no unresolved state. |
| S48-HKR-01 through S48-HKR-20 | 3 `MERGE_GATING_BEHAVIOR`; 17 `NEGATIVE_FAIL_CLOSED` | Historical release accepts only complete authority-aligned evidence and rejects stale, forged, foreign, malformed or V4 evidence. |
| S48-HKA-01, S48-HKA-C-01 through C-12, S48-HKA-A-01 through A-06, S48-HKA-M01, S48-HKA-S01 through S03 | 1 `MERGE_GATING_BEHAVIOR`; 20 `NEGATIVE_FAIL_CLOSED`; 2 `INVARIANT_BEHAVIOR` | An independently supplied authority record is mandatory; resealed checkpoint forgeries and mutated/missing authority halt, while ACTIVE and RELEASE_PENDING remain close-only. |
| S48-CAN-* | 34 `SUPPORTING_PURE_FUNCTION` | Every V5 safety field changes its canonical digest; typed/order/length/nested-boundary and self-digest exclusion properties are explicit supporting evidence, not interface behavior. |
| S48-RT-V5-01 through V5-07 | 7 `ROUND_TRIP` | A test-side LP1 decoder constructs a zeroed new DTO from serialized content only; exact reserialization and canonical digest equality are both required. |
| S48-RT-NEG-01 through NEG-11 | 11 `NEGATIVE_FAIL_CLOSED` | Truncated prefix/payload, impossible length, wrong type/order, missing/trailing content, corrupt nested identity, V4 version, malformed boolean and malformed numeric representation all fail decoding. |
| S48-META-01 | 1 `CONFORMANCE_ONLY` | Result schema and policy derive from and equal the compiled Production Contract version/policy constants. |

Sprint 4.8 Phase B5 totals: executable 790; `MERGE_GATING_BEHAVIOR` 63; `STATE_TRANSITION` 107; `NEGATIVE_FAIL_CLOSED` 516; `ROUND_TRIP` 7; `INVARIANT_BEHAVIOR` 38; `SUPPORTING_PURE_FUNCTION` 57; `CONFORMANCE_ONLY` 2; `WEAK_FALSE_POSITIVE` 0. Behavioral total 731; category sum 790. `ROUND_TRIP` is reserved exclusively for the seven decode-into-new-DTO reconstruction cases.

## Sprint 4.8 Phase B6 additions

| IDs | Category | Material credibility |
|---|---|---|
| S48-MAUTH-01 through S48-MAUTH-15 | 2 `MERGE_GATING_BEHAVIOR`; 13 `NEGATIVE_FAIL_CLOSED` | Exposure-increasing ALLOW requires a separately supplied Broker Adapter authority record. Coherently resealed tiny-margin projection, identity/value/source/reference mismatch, missing authority, stale authority, and corrupt authority deny. |
| S48-BAUTH-01 through S48-BAUTH-15 | 2 `MERGE_GATING_BEHAVIOR`; 13 `NEGATIVE_FAIL_CLOSED` | Resulting Basket risk requires a separately supplied Risk Governance authority record bound to a non-empty source identity. Coherently resealed loss understatement, arbitrary source, impaired Basket, missing/stale/foreign/corrupt authority deny. |
| S48-PAT-01 through S48-PAT-12 | 2 `MERGE_GATING_BEHAVIOR`; 1 `NEGATIVE_FAIL_CLOSED`; 9 `INVARIANT_BEHAVIOR` | A-to-B and empty replacement update request header, latest record, Basket count, reconciliation vector/revision, checkpoint publication sequence, CAS revision, source digest, payload size and digest atomically; a rejected replacement leaves the prior checkpoint byte-identical. |
| S48-ID-01 through S48-ID-12 | 12 `CONFORMANCE_ONLY` | Every active implementation reports its V5 identity; result schema/policy, serializer format and Sprint 4.8/V5 suite identity are current, while an explicit V4 decoder input remains rejected. |
| S48-CAN-AUTH-01 through S48-CAN-AUTH-02 | 2 `SUPPORTING_PURE_FUNCTION` | Exhaustive per-field mutation proves both new authority records' typed LP1 digests cover every semantic field and exclude only the self-digest. |

Sprint 4.8 Phase B6 totals: executable 846; `MERGE_GATING_BEHAVIOR` 69; `STATE_TRANSITION` 107; `NEGATIVE_FAIL_CLOSED` 543; `ROUND_TRIP` 7; `INVARIANT_BEHAVIOR` 47; `SUPPORTING_PURE_FUNCTION` 59; `CONFORMANCE_ONLY` 14; `WEAK_FALSE_POSITIVE` 0. Behavioral total 773; category sum 846.

## Sprint 4.8 Phase B7 additions

| IDs | Category | Material credibility |
|---|---|---|
| S48-RFULL-01, S48-RFULL-20 | 2 `MERGE_GATING_BEHAVIOR` | Independently built Broker Adapter exposure and Execution request-authority snapshots exactly match a valid persisted vector and reach SAFE_TO_RESUME. |
| S48-RFULL-02 through S48-RFULL-19 | 18 `NEGATIVE_FAIL_CLOSED` | Each case mutates one independently owned broker/execution dimension, reseals the applicable authority summary, leaves the persisted checkpoint byte-identical, and requires restart to remain unsafe. Removing the corresponding comparison makes its test fail. |
| S48-CAN-DTO-10 | 1 `SUPPORTING_PURE_FUNCTION` | Every Execution-owned restart-request-summary field changes its typed canonical digest. |
| S48-RT-V5-15 | 1 `ROUND_TRIP` | A zeroed new restart-request-authority DTO reconstructs from canonical text and reserializes exactly with the same digest. |

Sprint 4.8 Phase B7 totals: executable 868; `MERGE_GATING_BEHAVIOR` 71; `STATE_TRANSITION` 107; `NEGATIVE_FAIL_CLOSED` 561; `ROUND_TRIP` 8; `INVARIANT_BEHAVIOR` 47; `SUPPORTING_PURE_FUNCTION` 60; `CONFORMANCE_ONLY` 14; `WEAK_FALSE_POSITIVE` 0. Behavioral total 794; category sum 868.

## Sprint 4.8 Phase B8 additions

| IDs | Category | Material credibility |
|---|---|---|
| S48-QRY-01 through S48-QRY-10 | 2 `MERGE_GATING_BEHAVIOR`; 8 `NEGATIVE_FAIL_CLOSED` | Restart uses fixed V5 owner-specific masks whose union covers five domains. Reduced completion, every missing mandatory domain, caller mask downgrade, and version drift fail; complete and explicitly owned inputs behave as defined. |
| S48-RAUTH-01 through S48-RAUTH-04 | 1 `MERGE_GATING_BEHAVIOR`; 3 `NEGATIVE_FAIL_CLOSED` | Execution is the issuer and `EXECUTION_REQUEST_STATE` is the distinct trust source; wrong component or source fails despite coherent resealing. |
| S48-FRESH-01 through S48-FRESH-10 | 4 `MERGE_GATING_BEHAVIOR`; 6 `NEGATIVE_FAIL_CLOSED` | Valid nonzero, digest-correct observations test stale, future, inclusive age boundary, independent stream sequences, and query/enclosing-summary sequence order without hidden clocks. |
| S48-RFULL-21 through S48-RFULL-26 | 2 `MERGE_GATING_BEHAVIOR`; 4 `NEGATIVE_FAIL_CLOSED` | Every case proves a safe baseline and immutable checkpoint before isolated reduced-query, stale broker/request, wrong-source, boundary, or fully fresh reconciliation behavior. |
| S48-RT-NEG-12 | 1 `NEGATIVE_FAIL_CLOSED` | A restart-request authority record with omitted `authority_source` cannot decode. |

Sprint 4.8 Phase B8 totals: executable 899; `MERGE_GATING_BEHAVIOR` 80; `STATE_TRANSITION` 107; `NEGATIVE_FAIL_CLOSED` 583; `ROUND_TRIP` 8; `INVARIANT_BEHAVIOR` 47; `SUPPORTING_PURE_FUNCTION` 60; `CONFORMANCE_ONLY` 14; `WEAK_FALSE_POSITIVE` 0. Behavioral total 825; category sum 899.

## Sprint 4.8 Phase B9 additions

| IDs | Category | Material credibility |
|---|---|---|
| S48-QAUTH-01 through S48-QAUTH-10 | 2 `MERGE_GATING_BEHAVIOR`; 8 `NEGATIVE_FAIL_CLOSED` | Independently Broker- and Execution-owned nested query snapshots require exact mask, source, issuer, digest, timestamp and a sequence newer than the persisted owner-specific high-watermark. The content-bound label is diagnostic only. A fresh enclosing wrapper cannot refresh stale nested evidence. |
| S48-RFIX-01 through S48-RFIX-02 | 2 `NEGATIVE_FAIL_CLOSED` | Persistence request metadata and Execution request authority are built independently. Coherently mutating either side leaves the other byte-identical and restart remains unsafe. |
| S48-CAN-DTO-11 | 1 `SUPPORTING_PURE_FUNCTION` | Every query-snapshot authority field changes its typed canonical digest, with only the self-digest excluded. |
| S48-RT-V5-16 | 1 `ROUND_TRIP` | A zeroed new query-snapshot DTO reconstructs from canonical text and reserializes exactly with the same digest. |
| S48-RT-NEG-13 | 1 `NEGATIVE_FAIL_CLOSED` | Missing query timestamp or authority provenance cannot decode as a valid query snapshot. |

Sprint 4.8 Phase B9 totals: executable 914; `MERGE_GATING_BEHAVIOR` 82; `STATE_TRANSITION` 107; `NEGATIVE_FAIL_CLOSED` 594; `ROUND_TRIP` 9; `INVARIANT_BEHAVIOR` 47; `SUPPORTING_PURE_FUNCTION` 61; `CONFORMANCE_ONLY` 14; `WEAK_FALSE_POSITIVE` 0. Behavioral total 839; category sum 914.

## Sprint 4.8 Phase B10 additions and reclassification

| IDs | Category | Material credibility |
|---|---|---|
| S48-QRY-01 through S48-QRY-13 | 1 `MERGE_GATING_BEHAVIOR`; 12 `NEGATIVE_FAIL_CLOSED` | The exact owner mask is accepted once; missing, reduced, zero, version-drifted, or unknown completed/authoritative/required bits fail after the affected snapshot and wrapper are resealed. Former false-positive S48-QRY-07 now rejects undefined bit 32. |
| S48-QID-01 through S48-QID-03 | 2 `MERGE_GATING_BEHAVIOR`; 1 `NEGATIVE_FAIL_CLOSED` | Arbitrary or empty diagnostic labels do not change a valid authority decision after resealing; a fresh-looking label cannot bypass sequence anti-replay. |
| S48-QPUB-01 through S48-QPUB-12 | 2 `MERGE_GATING_BEHAVIOR`; 2 `STATE_TRANSITION`; 7 `NEGATIVE_FAIL_CLOSED`; 1 `INVARIANT_BEHAVIOR` | SAFE reconciliation emits owner-specific accepted watermarks; atomic publication advances both and checkpoint metadata; replays, rollback, aliasing, CAS failure, and non-SAFE publication fail without mutating stored state. |
| S48-CAN-DTO-12 | 1 `SUPPORTING_PURE_FUNCTION` | Every accepted-watermark proposal field changes its typed canonical digest; only the proposal self-digest is excluded. |
| S48-RT-V5-17 | 1 `ROUND_TRIP` | A zeroed accepted-watermark proposal reconstructs from canonical text and reserializes exactly with the same digest. |

Sprint 4.8 Phase B10 totals: executable 934; `MERGE_GATING_BEHAVIOR` 85; `STATE_TRANSITION` 109; `NEGATIVE_FAIL_CLOSED` 606; `ROUND_TRIP` 10; `INVARIANT_BEHAVIOR` 48; `SUPPORTING_PURE_FUNCTION` 62; `CONFORMANCE_ONLY` 14; `WEAK_FALSE_POSITIVE` 0. Behavioral total 858; category sum 934.

## Sprint 4.8 Phase B11 additions and semantic correction

| IDs | Category | Material credibility |
|---|---|---|
| S48-RT-V5-01 through V5-07, S48-RT-V5-15 through V5-17 | 10 `ROUND_TRIP` | Each full DTO representation carries its original embedded integrity field, decodes into a fresh object, validates the embedded digest against a nonrecursive digest preimage, and reserializes exactly. |
| S48-RT-DIGEST-MISSING-01 through 07, S48-RT-DIGEST-TAMPER-01 through 07 | 14 `NEGATIVE_FAIL_CLOSED` | Every repaired DTO rejects a missing or structurally valid but altered embedded digest; no decoder regenerates or self-heals it. |
| S48-CAN-SELF-01 through 07 | 7 `SUPPORTING_PURE_FUNCTION` | Own-digest mutation leaves the digest preimage unchanged but changes the full DTO representation. SELF-07 adds restart-request-summary coverage. |
| S48-NFD-01 through S48-NFD-18 | 18 `NEGATIVE_FAIL_CLOSED` | NaN, positive infinity, and negative infinity independently fail for volume, price, profit, commission, swap, and fee before Statistics state mutation. |
| S48-NFD-19 | 1 `MERGE_GATING_BEHAVIOR` | A complete finite authoritative deal validates and mutates the returned Statistics state exactly once. |
| S48-NFD-20 | 1 `INVARIANT_BEHAVIOR` | Failed accumulation preserves the preseeded output Statistics state byte/canonical-identically, including money, counts, volumes, and dedup identity. |
| S45F-02 | reclassified from `ROUND_TRIP` to `INVARIANT_BEHAVIOR` | It proves durable identity persistence and replay semantics, but not serialized-full-DTO to fresh-object reconstruction. This corrects the prior detailed/headline inconsistency without inflating round-trip credit. |
| EXP48-74 through EXP48-82 | exporter offline negative evidence | Headline/per-ID disagreement, source-authority drift, duplicate/missing/phantom IDs, unknown category, false round-trip credit, hidden weak classification, and balanced wrong mapping all reject. |

Sprint 4.8 Phase B11 totals: executable 969; `MERGE_GATING_BEHAVIOR` 86; `STATE_TRANSITION` 109; `NEGATIVE_FAIL_CLOSED` 638; `ROUND_TRIP` 10; `INVARIANT_BEHAVIOR` 49; `SUPPORTING_PURE_FUNCTION` 63; `CONFORMANCE_ONLY` 14; `WEAK_FALSE_POSITIVE` 0. Behavioral total 892; category sum 969.
