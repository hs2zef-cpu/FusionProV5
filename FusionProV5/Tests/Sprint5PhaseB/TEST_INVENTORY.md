# Sprint 5 Phase B.3 verification inventory

Status: **TEST ONLY / NOT FOR PRODUCTION / NO BROKER ACCESS**

## MQL compile-only assertions

`SW_V5_S5_PHASE_B_ASSERTIONS.mq5` registers nine test groups containing 183 `SWV5S5_Assert(...)` function invocations on 181 source call lines. There are 184 textual occurrences including the assertion-function declaration. The source directly calls the corrected pure contract functions for canonical identity, Ledger/Sequence integrity, ADR-020 ordering, complete Admission Proof, Producer Trust, Claim transition/durable retention, conditional-admission completion, Permit identity/current Trust, initial Blueprint transitivity, and fenced request-set/checkpoint publication.

The B.3 adversarial calls directly exercise stable terminal and non-admissible request lifecycles, an incompatible Submission phase, exact Trust-successor scope mutations, ordinary Ledger evaluation with orphan/corrupt/mismatched records, valid duplicate/conflict/new/denied controls, successful and failed conditional-admission completion, and takeover-first stale-owner disposition. Earlier B.2 cases remain present, including Hard Kill ordering, wrong Trust namespace, payload/request/Risk binding, Claim proof corruption, direction reversal/no-entry materialization, Sequence integrity, complete Snapshot retention, and checkpoint mutation.

MetaEditor X64 Regular compiles this harness. The assertions are **not executed** because Phase B.3 forbids MT5 Terminal and Strategy Tester. Invocation and source-line counts are source inventory, not runtime pass counts.

## Independent executable reference oracle

`verify_phase_b.ps1` executes 139 deterministic PowerShell/.NET assertions. It independently models canonical framing, identity, exact request-lifecycle admission, Blueprint transitivity, ordinary Ledger complete-authority evaluation, Sequence integrity, exact Trust-successor scope, Claim/publication/checkpoint behavior, repository safety, and verifier adversarial self-tests.

Latest permitted execution: **139 total / 139 passed / 0 failed**.

The independent reference oracle is not MQL runtime execution and does not prove that the compile-only MQL assertion bodies ran.
