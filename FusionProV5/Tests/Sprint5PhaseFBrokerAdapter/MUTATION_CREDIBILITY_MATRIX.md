# Broker Adapter Mutation Credibility Matrix

TEST ONLY / NOT FOR PRODUCTION / NO BROKER ACCESS.

The executable mutation rule is unchanged: `PASS = unsafe_result_observed && target_assertion_detected`.
Every row uses the same targeted adversarial input for the safe oracle and mutant. `Target path reached = yes`
means the fixture satisfies all earlier prerequisites; the mutant is therefore not killed by an unrelated
earlier rejection. Detector provenance names the detector used by the mutation runner; the final column records
independent corroboration without reclassifying it as mutation execution.

| Mutant ID | Exact target invariant | Deliberately broken behavior | `unsafe_result_observed` predicate | Target detector / assertion | Detector provenance | Target path reached; unrelated earlier guard? | Independent corroboration |
|---|---|---|---|---|---|---|---|
| MC-CLAIM-FABRICATION | Only the current operation's authoritative Claim grant can permit a call | Calls with `claim_granted_now=false` | mutant send count exceeds safe send count | safe send `0`, mutant send `1` | PYTHON_ORACLE | Yes; no | REAL_MQL `MQL-PREFLIGHT-02`, `03`, `04` |
| MC-PREFLIGHT-BYPASS | Failed permission preflight cannot reach submission | Sends while terminal permission is false | mutant send count exceeds safe send count | safe send `0`, mutant send `1` | PYTHON_ORACLE | Yes; no | REAL_MQL `MQL-PREFLIGHT-06`–`10` |
| MC-SYNC-AS-CONFIRMATION | Synchronous acceptance is observational and non-final | Promotes synchronous acceptance to positive confirmation | mutant terminal state differs from safe unresolved state | safe `UNRESOLVED`, mutant `POSITIVE` | PYTHON_ORACLE | Yes; no | REAL_MQL `MQL-SYNC-01` |
| MC-CALLBACK-AS-CONFIRMATION | Callback presence alone cannot confirm side effect | Promotes a callback to positive confirmation | mutant terminal state differs from safe unresolved state | safe `UNRESOLVED`, mutant `POSITIVE` | PYTHON_ORACLE | Yes; no | STATIC_SOURCE callback is evidence-only |
| MC-AUTO-RETRY | No uncertain submission outcome enables retry | Enables retry after synchronous acceptance | mutant `retry_allowed=true` while safe is false | retry flag transition false to true | PYTHON_ORACLE | Yes; no | REAL_MQL `MQL-SYNC-01`–`05` |
| MC-CAPABILITY-SELFATTEST | Negative evidence requires governed capability proof | Treats absent governed capability as authoritative negative | mutant state differs from safe unresolved state | safe `UNRESOLVED`, mutant `NEGATIVE` | PYTHON_ORACLE | Yes; no | STATIC_SOURCE proof consumption only |
| MC-INCOMPLETE-AS-EMPTY | Incomplete query is not authoritative emptiness | Treats incomplete query as authoritative negative | mutant state differs from safe unresolved state | safe `UNRESOLVED`, mutant `NEGATIVE` | PYTHON_ORACLE | Yes; no | REAL_MQL `MQL-QUERY-02`, `04` |
| MC-SHARED-EVIDENCE-SOURCE | Broker and Execution evidence authorities are independent | Accepts one shared authority/source path | mutant state differs from safe unresolved state | safe `UNRESOLVED`, mutant `NEGATIVE` | PYTHON_ORACLE | Yes; no | REAL_MQL `MQL-EVIDENCE-01`, `02` |
| MC-STALE-CAS-EQUALITY | Publication requires exact fresh CAS revision | Publishes stale revision because content matches | mutant publishes while safe does not | safe `published=false`, mutant `true` | PYTHON_ORACLE | Yes; no | STATIC_SOURCE exact revision check |
| MC-RESIDUAL-AUTHORITY | Partial residual exposure is never reusable submission authority | Marks residual volume as submission authority | mutant residual-authority flag true while safe is false | safe false, mutant true | PYTHON_ORACLE | Yes; no | REAL_MQL `MQL-RECON-01` |
| MC-MAGIC-COMMENT-SOLE | Magic/comment are scope metadata, not sole correlation authority | Confirms by Magic/comment alone | mutant terminal state differs from safe unresolved state | safe `UNRESOLVED`, mutant `POSITIVE` | PYTHON_ORACLE | Yes; no | STATIC_SOURCE positive-evidence relationship guards |
| MC-TERMINAL-REGRESSION | Terminal conflict is blocked and monotonic | Regresses terminal conflict to unresolved | mutant state differs from safe blocked state | safe `BLOCKED`, mutant `UNRESOLVED` | PYTHON_ORACLE | Yes; no | REAL_MQL `MQL-RECON-02`, `03` |
| MC-TOCTOU-WINDOW | Final permission/profile/spec sample must equal the preflight sample | Sends after final environment drift | mutant send count exceeds safe send count | target-specific: safe unresolved/send `0`, mutant unresolved/send `1` | PYTHON_ORACLE | Yes; no | REAL_MQL `MQL-FINAL-ENV-01`; STATIC_SOURCE `SWV5S5_F_AdapterValidateFinalEnvironment` before the sole send |
| MC-POSTDIGEST-NORMALIZE | Final wire digest binds the exact request sent; no later mutation | Mutates/normalizes the request after digest and sends | mutant send count exceeds safe send count | target-specific: safe unresolved/send `0`, mutant unresolved/send `1` | PYTHON_ORACLE | Yes; no | REAL_MQL `MQL-WIRE-01`, `02`; STATIC_SOURCE digest-to-send interval contains no request mutation |
| MC-ADAPTER-SELFATTEST | Adapter cannot author capability/completeness/watermark proof | Adapter self-attestation creates authoritative negative evidence | mutant state differs from safe unresolved state | target-specific: safe `UNRESOLVED`, mutant `NEGATIVE`, equal send counts | PYTHON_ORACLE | Yes; no | STATIC_SOURCE `SWV5S5_F_IsCapabilityProofValid` plus no proof-authorship interface |
| MC-FILLING-COERCION | Filling mode is exact one-to-one; combined/unsupported values fail closed | Coerces unsupported/combined filling and sends | mutant send count exceeds safe send count | target-specific: safe unresolved/send `0`, mutant unresolved/send `1` | PYTHON_ORACLE | Yes; no | REAL_MQL `MQL-FILL-01`–`04`, `MQL-PREFLIGHT-15`; STATIC_SOURCE `SWV5S5_F_AdapterResolveFilling` |
| MC-QUERY-ROW-OMISSION | Reported totals and successfully read rows must match exactly | Treats omitted/read-failed rows as authoritative empty evidence | mutant state differs from safe unresolved state | target-specific: safe `UNRESOLVED`, mutant `NEGATIVE`, equal send counts | PYTHON_ORACLE | Yes; no | REAL_MQL `MQL-QUERY-02`, `04`; STATIC_SOURCE `SWV5S5_F_AdapterBrokerQueryShapeComplete` |

The five audit-specific rows use target-specific predicates in
`verify_phase_f_broker_adapter_mutations.py`; the other twelve retain direct safe-versus-mutant outcome
comparison because their unsafe property is itself the named state/flag transition.
