# Sprint 5 Phase F Broker Adapter Verification

TEST ONLY / NOT FOR PRODUCTION. No Demo or live broker mutation is authorized.

This directory verifies the Phase F Broker Adapter implementation against the
accepted entry contract at commit `4e5a785f77d291c2e43499da9da9c5fb7572f5cb`.
The compile manifest includes the production adapter boundary but executes no
adapter method. Deterministic integration tests use an independent broker-double
oracle; source controls verify that the only direct MT5 API calls are inside the
platform boundary.

The adapter has four layers:

1. neutral DTOs and persistence-facing interfaces;
2. pure Claim/preflight and synchronous-result classification;
3. pure Broker/Execution evidence projection into the accepted reconciliation contract;
4. one exclusive MT5 platform boundary for environment reads, broker queries,
   callback capture, and the single guarded `OrderSend` call.

No capability proof is created here. Until an independently governed proof is
present and valid, query completeness and visibility-watermark claims remain
false and authoritative negative reconciliation remains naturally unreachable.
