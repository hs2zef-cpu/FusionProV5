# Sprint 5 MVP Controlled Demo offline gate

TEST ONLY / NOT FOR PRODUCTION / NO BROKER ACCESS.

This package verifies the fail-closed orchestration boundary for `MODE_PREFLIGHT`,
`MODE_D1_BUY`, `MODE_D6_RECOVER`, and `MODE_D3_SELL`. The real-MQL suite uses a
non-mutating boundary seam: a seam invocation proves serialized control flow but
never calls MT5 or increments `broker_submission_calls`.

The executable gate contains 41 Controlled Demo orchestration assertions and 18
ownership persistence/restart assertions. The ownership cases write, close,
reopen, and strictly decode the complete accepted `SWV5_InstanceLease` from the
physical SQLite row, then prove that D6 accepts only the exact current fence and
never invokes the submission boundary.

The launch wrappers are deliberately inert until an attended integration supplies
the accepted provider graph and explicit operator inputs. No default can arm a
submission. Runtime evidence is written only as an ignored `.log` file in
`FILE_COMMON`; authentication references are excluded from the evidence schema.
