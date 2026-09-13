# Sprint 5 Demo MVP Runtime Authority Verification

OFFLINE TEST ONLY. NOT FOR PRODUCTION. NO BROKER MUTATION.

This directory separates three evidence classes:

- `SOMWANG_XAU_M15_FUSION_PRO_V5_MVP_RUNTIME_TESTS.mq5` executes real MQL assertions in Demo Strategy Tester, including the physical MQL SQLite store, CAS, rollback, reopen, genesis, canonical callback reconstruction, and Claim reload.
- `verify_mvp_runtime.py` is an independent table-driven policy and SQLite oracle plus source-shape verifier.
- `verify_mvp_mutation_controls.py` demonstrates that representative policy defects are detected rather than silently accepted.

The compile-only manifest is `SW_V5_S5_MVP_RUNTIME_COMPILE.mq5`. None of these files imports or calls the broker platform submission boundary.
