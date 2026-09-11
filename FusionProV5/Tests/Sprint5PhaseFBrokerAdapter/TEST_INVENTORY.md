# Phase F Broker Adapter Test Inventory

TEST ONLY / NOT FOR PRODUCTION / NO BROKER ACCESS.

The independent adapter oracle contains 45 deterministic cases:

- BA-001–008: Claim, exact-profile, four trading-permission, payload and filling pre-call rejects; expected send count is zero.
- BA-009–015: synchronous acceptance, callback-only/absent, timeout, transport failure, unknown retcode and incomplete query remain unresolved.
- BA-016–018: full positive, partial positive and orphan/foreign positive evidence.
- BA-019–020: authoritative Execution-store NO_CALL and contradiction.
- BA-021–026: capability self-attestation, policy drift, watermark/timing, generation, shared-source and fully qualified negative cases.
- BA-027–028: stale lease and stale revision publication rejection.
- BA-029–034: restart unresolved, terminal replay/conflict, blocked stickiness, Magic/comment-only rejection and F0-UNPROVEN rejection.
- BA-035–040: accepted, client-local rejection, timeout, broker-rejection candidate, transport failure and unknown synchronous-result classifications; every class remains non-confirming.
- BA-041–045: final environment drift, final wire digest mismatch, combined filling rejection, adapter self-attestation rejection, and query-row omission rejection.

The dedicated 17-mutant suite covers Claim fabrication, preflight bypass,
synchronous/callback false confirmation, retry, capability self-attestation,
incomplete-as-empty, shared evidence source, stale-CAS equality, residual
authority, Magic/comment-only correlation and terminal regression. Each control
passes only when both `unsafe_result_observed` and
`target_assertion_detected` are true. Ordinary negative tests are not counted as
mutation power.

The real MQL assertion harness contains 24 pure assertions covering canonical
grid arithmetic, exact filling mapping, market/SL/TP semantics, wire digest
determinism and mutation sensitivity, environment re-sampling, row omission,
and Broker/Execution source independence. It is run only in Strategy Tester and
reports an explicit zero broker-call count.

The five audit-hardening controls are `MC-TOCTOU-WINDOW`,
`MC-POSTDIGEST-NORMALIZE`, `MC-ADAPTER-SELFATTEST`,
`MC-FILLING-COERCION`, and `MC-QUERY-ROW-OMISSION`.
