# Phase C to Phase D Total Crossing Mapping

TEST ONLY / NOT FOR PRODUCTION / NO BROKER ACCESS.

This table maps every Phase-C disposition that can cross into persistence or
restart handling. No unmapped value succeeds; all other values fail closed as
`UNMAPPED_C_DISPOSITION` in the test oracle. This is a fixture mapping, not a new
authority enum.

| Phase-C disposition | Existing durable observation | Phase-D restart handling |
|---|---|---|
| FAKE_BROKER_INVOKED | INVOCATION_CLAIMED_UNRESOLVED | RECONCILIATION_REQUIRED |
| BROKER_ACKNOWLEDGED | acknowledgement only; still claimed-unresolved until authoritative evidence | RECONCILIATION_REQUIRED |
| FAKE_BROKER_REJECTED | claimed attempt plus scripted response evidence | RECONCILIATION_REQUIRED |
| FAKE_BROKER_UNCERTAIN | INVOCATION_CLAIMED_UNRESOLVED | RECONCILIATION_REQUIRED |
| CLAIMED_RECONCILIATION_REQUIRED | INVOCATION_CLAIMED_UNRESOLVED | RECONCILIATION_REQUIRED |
| ALREADY_CLAIMED_UNCERTAIN | persisted Claim; no event-local grant | RECONCILIATION_REQUIRED |
| TAKEOVER_RECONCILIATION | new owner reads prior durable authority | RECONCILIATION_REQUIRED |

Only later authoritative Broker/Execution reconciliation plus coherent Request
Set and Checkpoint publication can result in `SAFE_TO_RESUME`. ACK is never
treated as authoritative confirmation.
