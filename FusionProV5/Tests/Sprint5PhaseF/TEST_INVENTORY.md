# Phase F Entry Test Inventory

All tests are deterministic, test-only, not for production, and have no broker access.

| ID | Scenario | Expected state |
|---|---|---|
| F-001 | no Claim / no call | `NO_CALL` |
| F-002 | synchronous success alone | `SUBMISSION_UNRESOLVED` |
| F-003 | callback absent | `SUBMISSION_UNRESOLVED` |
| F-004 | timeout | `SUBMISSION_UNRESOLVED` |
| F-005 | zero rows with incomplete query | `SUBMISSION_UNRESOLVED` |
| F-006 | restart after Claim | `SUBMISSION_UNRESOLVED` |
| F-007 | Magic/comment-only positive candidate | `RECONCILIATION_BLOCKED` |
| F-008 | valid durable order/deal linkage | `SIDE_EFFECT_POSITIVELY_CONFIRMED` |
| F-009 | fully qualified negative evidence | `NO_SIDE_EFFECT_CONFIRMED` |
| F-010 | stale ownership/current fence | `RECONCILIATION_BLOCKED` |
| F-011 | partial durable fill | `PARTIAL_EFFECT_CONFIRMED` |
| F-012 | positive record without Claim | `RECONCILIATION_BLOCKED` |
| F-013 | broker rejection candidate alone | `SUBMISSION_UNRESOLVED` |
| F-014 | client-local post-invocation rejection | `SUBMISSION_UNRESOLVED` |
| F-015 | query failure | `SUBMISSION_UNRESOLVED` |
| F-016 | unknown/unmapped retcode | `SUBMISSION_UNRESOLVED` |
| F-017 | callback-only evidence | `SUBMISSION_UNRESOLVED` |
| F-018 | stale reconnect/restart generation | `SUBMISSION_UNRESOLVED` |
| F-019..021 | replay each terminal state without evidence | identical terminal state |
| F-022 | completeness claimed without full negative policy proof | `SUBMISSION_UNRESOLVED` |
| F-023 | otherwise-qualified negative observation with row-read failure | `SUBMISSION_UNRESOLVED` |
| F-024 | otherwise-qualified negative observation with one matching row | `SUBMISSION_UNRESOLVED` |
| F-025 | terminal reconciliation state disagrees with frozen submission authority | `RECONCILIATION_BLOCKED` |
| F-026 | terminal partial state disagrees with persisted volume partition | `RECONCILIATION_BLOCKED` |
| F-027 | otherwise-valid positive rows without approved correlation policy | `RECONCILIATION_BLOCKED` |
| F-028 | positive deal set with a row-read failure | `RECONCILIATION_BLOCKED` |
| F-029 | positive evidence without canonical ordered deal-set proof | `RECONCILIATION_BLOCKED` |

The independent oracle tests state policy. The MetaEditor manifest separately checks MQL type/interface conformance. No MQL assertion is claimed as executed because Strategy Tester use is outside this authorization.
