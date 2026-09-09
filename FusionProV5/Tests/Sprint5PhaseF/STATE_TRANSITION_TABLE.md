# Phase F Reconciliation State Table

| Prior state | Evidence | Result | Retry |
|---|---|---|---|
| `NO_CALL` | no successful Claim; optional pre-call rejection | `NO_CALL` | only through a new frozen admission/claim path |
| `NO_CALL` | Claim or broker evidence exists | `RECONCILIATION_BLOCKED` | no |
| `SUBMISSION_UNRESOLVED` | sync result, callback, timeout, transport/client failure, unknown retcode, incomplete query | `SUBMISSION_UNRESOLVED` | no |
| `SUBMISSION_UNRESOLVED` | durable, query-confirmed order/deal evidence with approved correlation proof | `SIDE_EFFECT_POSITIVELY_CONFIRMED` | no |
| `SUBMISSION_UNRESOLVED` | durable evidence below requested volume | `PARTIAL_EFFECT_CONFIRMED` | no; residual remains exposed/unresolved |
| `SUBMISSION_UNRESOLVED` | fully qualified joint authoritative negative evidence | `NO_SIDE_EFFECT_CONFIRMED` | only a future request through new admission |
| `SUBMISSION_UNRESOLVED` | stale binding, invalid positive evidence, or conflicting evidence | `RECONCILIATION_BLOCKED` | no |
| terminal state | no new evidence | same terminal state | no |
| terminal state | frozen submission state or persisted volume partition disagrees | `RECONCILIATION_BLOCKED` | no |
| terminal state | later evidence | `RECONCILIATION_BLOCKED` | no |

Claim is the uncertainty linearization point. Restart, reconnect, and takeover preserve `INVOCATION_CLAIMED_UNRESOLVED`; they never recreate invocation authority.
