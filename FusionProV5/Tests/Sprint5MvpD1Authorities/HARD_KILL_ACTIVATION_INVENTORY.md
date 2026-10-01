# Hard Kill activation inventory

TEST ONLY / NOT FOR PRODUCTION / NO BROKER ACCESS.

The real-MQL activation manifest executes HK-01 through HK-25 plus one
physical release-to-Risk E2E requirement (26 top-level assertions). Nested
legacy E2E/D6 assertions must also pass but do not inflate that count.
This manually authored inventory is not a PASS report; results come from
actual tester journals.

- HK-01–04: real genesis ACTIVE, direct-activation rejection, pending CAS
  and readback, complete independently issued RELEASED authority readback.
- HK-05–12: RELEASED Risk rejection; absent authority, wrong digest/ID/
  generation, exclusive approval expiry with a live physical lease,
  stale takeover fence and changed CURRENT rejection.
- HK-13–16: unchanged frozen checkpoint validator, new latch epoch,
  immutable complete predecessor history and full authority restart reload.
- HK-17: corrupted history payload at revision 1 fails closed.
- HK-18: exact valid pair-CAS proposals fail before write one and between
  writes; history remains absent and existing CURRENT/guard unchanged.
  The same production transition then succeeds.
- HK-19–21: duplicate activation does not advance CURRENT, valid lineage
  permits actual MVP Risk ALLOW, and raw RELEASED is still rejected.
- HK-22: guard passes immediately before approval expiry with a renewed
  same-fence live lease, rejects at expiry, and rejects actual history
  deletion while CURRENT/full independent authority remain intact.
- HK-23–25: exact restart lineage, positive/no-positive D6 with zero
  recovery submissions, concrete runner/preflight with zero boundary calls.
- HK-E2E-RELEASE-TO-RISK: production Genesis/BootstrapZero/independent
  issuer/release/activation/physical D1 authority path and MVP Risk.

SQLite, authority functions and frozen validators execute in MQL. External
read-only observations and the non-mutating broker boundary are explicit
test seams. Account and canonical Basket observations remain test-supplied:
these cases do not prove a production attended-launch seed provider exists.
Successful physical fixtures never install INACTIVE instead of release.
Pure legacy Risk unit inputs are not runtime eligibility authority.

Python oracles, mutation controls and static scans are separate evidence
classes. No actual Demo D1, OrderSend, live exposure or main merge is allowed.
