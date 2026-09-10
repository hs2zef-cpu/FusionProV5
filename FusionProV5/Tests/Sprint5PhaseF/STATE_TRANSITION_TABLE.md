# Phase F Reconciliation State Table

| Prior state | Required evidence/event | Result | Retry / residual authority |
|---|---|---|---|
| `NO_CALL` | digest-bound authoritative Execution-store proof: Claim absent and invocation absent | `NO_CALL` | no retry; any future call uses the frozen admission/Claim path |
| `NO_CALL` | Claim, broker-query evidence, missing proof or contradictory local record | `RECONCILIATION_BLOCKED` | none |
| `SUBMISSION_UNRESOLVED` | provisional sync/callback/retcode/timeout/transport evidence | `SUBMISSION_UNRESOLVED` | none |
| `SUBMISSION_UNRESOLVED` | incomplete/unsupported zero-row evidence | `SUBMISSION_UNRESOLVED` | none |
| `SUBMISSION_UNRESOLVED` | valid durable ordered broker evidence, full requested volume | `SIDE_EFFECT_POSITIVELY_CONFIRMED` | none |
| `SUBMISSION_UNRESOLVED` | valid durable ordered broker evidence, partial volume | `PARTIAL_EFFECT_CONFIRMED` | residual is non-authority; new request/admission/permit/Claim required |
| `SUBMISSION_UNRESOLVED` | durable broker effect with invalid/missing/stale/foreign binding | `RECONCILIATION_BLOCKED` | none; orphan-side-effect reason |
| `SUBMISSION_UNRESOLVED` | complete, pinned, independently governed joint negative proof | `NO_SIDE_EFFECT_CONFIRMED` | only a distinct future request through frozen authorities |
| `SUBMISSION_UNRESOLVED` | pinned policy/capability drift or positive/negative conflict | `RECONCILIATION_BLOCKED` | none |
| confirmed terminal | no new evidence; state, volume partition and evidence digest match | identical terminal state | none |
| confirmed terminal | conflicting evidence or state/partition/digest mismatch | `RECONCILIATION_BLOCKED` | none |
| `RECONCILIATION_BLOCKED` | any evidence or replay | `RECONCILIATION_BLOCKED` | sticky; separate governed recovery required |

All paths set `retry_allowed=false`. Claim is the uncertainty linearization point. Restart, reconnect and takeover preserve `INVOCATION_CLAIMED_UNRESOLVED`; they never recreate invocation authority or clear `RECONCILIATION_BLOCKED`.
