# Sprint 4.5 Phase E Test Credibility Matrix

> TEST ONLY - NOT FOR PRODUCTION - NO BROKER ACCESS

This matrix classifies every executable ID in the 368-case V4 candidate suite. Categories `MERGE_GATING_BEHAVIOR`, `STATE_TRANSITION`, `NEGATIVE_FAIL_CLOSED`, `ROUND_TRIP`, and `INVARIANT_BEHAVIOR` count as merge-gating behavioral evidence. Supporting and conformance cases remain executable but are not represented as behavioral proof.

The audit question for every behavioral row is: if the advertised behavior were removed or intentionally broken, would the material assertion fail? Every behavioral row below answers **yes**. No row is classified by test name or intent alone.

## Totals

| Category | Count | Merge-gating evidence |
|---|---:|---|
| `MERGE_GATING_BEHAVIOR` | 40 | YES |
| `STATE_TRANSITION` | 96 | YES |
| `NEGATIVE_FAIL_CLOSED` | 190 | YES |
| `ROUND_TRIP` | 17 | YES |
| `INVARIANT_BEHAVIOR` | 13 | YES |
| `SUPPORTING_PURE_FUNCTION` | 11 | NO |
| `CONFORMANCE_ONLY` | 1 | NO |
| `WEAK_FALSE_POSITIVE` | 0 | NO |
| **Executable total** | **368** | **356 behavioral; 12 supporting/conformance** |

## Complete classification

| Test ID(s) | Category | Production interface / helper | Prior state | Operation | Material assertion/output | Specific broken behavior detected | Gate? |
|---|---|---|---|---|---|---|---|
| COM-01 | `MERGE_GATING_BEHAVIOR` | Version policy `EvaluateCompatibility` | Valid V4 candidate/context | Evaluate exact version | Returns true and `EXACT` | Exact compatible version rejected or misclassified | YES |
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
| S45F-02 | `ROUND_TRIP` | Persistence plus execution | Returned execution state with fingerprint | Save/load, replay exact and conflicting evidence | Loaded identity survives; exact duplicate; conflict rejected | Durable fingerprint lost across restart | YES |
| S45BR-01–S45BR-02 | `STATE_TRANSITION` | Basket recovery transition | ACTIVE then returned RECOVERY state | First recovery, exact replay | Identity added once; replay no-op | Recovery not mutated or duplicate re-applied | YES |
| S45BR-03–S45BR-09 | `NEGATIVE_FAIL_CLOSED` | Basket recovery transition | Returned state after first recovery | Replay with owner/fence/Basket/fingerprint/context/version/counter mutation | DENY; all returned fields unchanged | Known-identity fast path bypasses canonical validation | YES |
| S45BR-10 | `ROUND_TRIP` | Persistence plus recovery | Returned RECOVERY lifecycle | Configure/load checkpoint, replay original request | Loaded state recognizes exact duplicate without mutation | Restart loses recovery identity | YES |
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
| S45DP-15–S45DP-16 | `ROUND_TRIP` | Persistence Save/Load | Request set A, then replacement B | Save/load A; save B/load B/latest | Full equality and stale A absent | Save succeeds without storage/replacement semantics | YES |
| PER-01 | `INVARIANT_BEHAVIOR` | Persistence `ValidateRecord` | Valid checkpoint | Validate | Loaded/valid | Canonical record rejected | YES |
| PER-02–PER-04 | `NEGATIVE_FAIL_CLOSED` | Persistence record validator | Corrupt digest, sequence, or namespace | Validate | False | Corrupt/foreign record accepted | YES |
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
| IFC-33–IFC-36 | `ROUND_TRIP` | Persistence Configure/Save/Load | Checkpoint or request-set state | Configure/load, save/load empty set, save/load checkpoint after caller mutation | Loaded material state equals pre-mutation source | Invocation-only Save/Load or shallow copy | YES |
| IFC-38 | `CONFORMANCE_ONLY` | Statistics `Finalize` | Complete deterministic fixture | Invoke | Returns nonzero validation flags | Method/signature/output-shape regression; semantic finalize behavior is gated by STA-08 | NO |
| IFC-39–IFC-40 | `STATE_TRANSITION` | Ownership heartbeat/conflict/release | Active lease | Renew/detect or release | Returned status/sequences/time/expiry/conflict/released state | Remaining ownership methods do not perform advertised transition | YES |
| PRT-01–PRT-05 | `ROUND_TRIP` | Persistence Configure/Save/Load | Single/multiple/partial/uncertain payloads | Store then load | Field equality, order, and lifecycle content | Shallow/incomplete reconstruction | YES |
| PRT-06–PRT-08 | `NEGATIVE_FAIL_CLOSED` | Persistence | Foreign namespace or corrupt header/digest/revision | Load/save | False; output cleared where applicable | Foreign/corrupt storage accepted | YES |
| PRT-09–PRT-10 | `ROUND_TRIP` | Persistence | Stored multiple/single records | Repeated load or caller mutation after Save | Independent equal loads; stored state isolated | Nondeterministic or shallow storage | YES |
| PRT-11 | `NEGATIVE_FAIL_CLOSED` | Persistence `LoadPendingRequests` | Unconfigured store | Load | False, empty output, truncated status | Missing storage treated as valid | YES |
| S44-01–S44-04 | `MERGE_GATING_BEHAVIOR` | Restart reconciliation | Empty, uncertain, retry-forbidden, or Hard Kill persisted state | Reconcile | Safe/reconcile/retry-forbidden/close-only disposition | Complete-set readiness policy absent | YES |
| S44-05–S44-09 | `NEGATIVE_FAIL_CLOSED` | Persistence/restart | Residual mismatch or nested/order/revision/digest tamper | Reconcile/save | Halt/reject | Payload/header integrity ignored | YES |
| S44-10–S44-11 | `ROUND_TRIP` | Persistence Save/LoadLatest | Two-record set then empty replacement | Save/load latest | Latest summary is final record then cleared | Stale latest summary | YES |
| S44-12 | `MERGE_GATING_BEHAVIOR` | Risk Evaluate/Validate | Complete binding | Evaluate then validate | Complete authorization and projection output | Partial authorization output | YES |
| S44-13–S44-15 | `NEGATIVE_FAIL_CLOSED` | Risk validator | Missing auth field or changed Hard Kill namespace/generation | Validate | DENY | Safety binding ignored | YES |
| S44-16–S44-17 | `STATE_TRANSITION` | Recovery/Execution | Initial then returned state | Accept first/second evidence and replay | Durable identity added once; replay stable | State mutation or replay semantics absent | YES |
| S44-18 | `NEGATIVE_FAIL_CLOSED` | Execution evidence | Returned state after event A | Reuse ID with changed event | CONFLICT | Fingerprint conflict accepted | YES |
| S44-19–S44-21 | `STATE_TRANSITION` | Statistics/Ownership | Current returned stats or lease | Accumulate/replay; unseen older deal; three returned-state heartbeats | Money/idempotency/order; stable fence with monotonic liveness/revision | Duplicate accounting, out-of-order loss, or heartbeat authority conflation | YES |
| S44-22–S44-25 | `NEGATIVE_FAIL_CLOSED` | Ownership heartbeat/takeover | Active/expired lease | Stale heartbeat or malformed/duplicate/foreign takeover | Reject; no unsafe mutation | Stale owner or invalid takeover accepted | YES |

## Rewritten false-positive patterns

The Phase E rewrite removed all known false-positive patterns:

- COM-05 and COM-11 now require specific material outputs and overwrite a hostile preseed.
- BAS-04 now pairs valid deterministic replay with an adversarial rejection.
- EXE-16, IFC-26, and XDM-11 now invoke transaction-evidence behavior instead of inferring confirmation from local state or retcode classification.
- STA-02, STA-04, and STA-08 consume returned accumulator state and verify monetary, identity, duplicate, and finalization behavior.
- IFC-35 and IFC-36 now observe Save through Load and verify deep-copy isolation.
- S45DP-13 and S45DP-14 compare independently constructed fixtures and require adversarial differences.
- S44-21 now performs three heartbeats, feeding each returned lease into the next operation.

No executable ID was removed. Helper-only canonical/equality cases are retained as supporting evidence and are excluded from the behavioral count.
