# Sprint 5 Phase B.2 verification inventory

Status: **TEST ONLY / NOT FOR PRODUCTION / NO BROKER ACCESS**

## MQL compile-only assertions

`SW_V5_S5_PHASE_B_ASSERTIONS.mq5` registers nine test groups containing 148 `SWV5S5_Assert(...)` call sites. The source directly calls the corrected pure contract functions for canonical identity, Ledger/Sequence integrity, ADR-020 ordering, complete Admission Proof, Producer Trust, Claim transition/durable retention, Permit identity/current Trust, initial Blueprint transitivity, and fenced request-set/checkpoint publication.

The adversarial calls include stable-invalid Hard Kill, changed Hard Kill, wrong Trust namespace, normalized-payload mutation, wrong request-set binding, missing/corrupt Admission Proof, stale owner, wrong request and Permit, BUY/SELL reversal, no-entry materialization, empty/unrelated Risk authority, Ledger accepted-at mutation, orphan record/index state, duplicate Sequence allocation, corrupt HWM/authority, corrupt prior/current Trust, and checkpoint safety-field mutation.

MetaEditor X64 Regular compiles this harness. The assertions are **not executed** because Phase B.2 forbids MT5 Terminal and Strategy Tester. Assertion-call count is source inventory, not a runtime pass count.

## Independent executable reference oracle

`verify_phase_b.ps1` executes 122 deterministic PowerShell/.NET assertions. It independently models canonical framing, identity, admission semantics, Blueprint transitivity, Ledger/Sequence integrity, Trust succession, Claim/publication/checkpoint behavior, repository safety, and verifier adversarial self-tests.

Latest permitted execution: **122 total / 122 passed / 0 failed**.

The independent reference oracle is not MQL runtime execution and does not prove that the compile-only MQL assertion bodies ran.
