# Canonical Basket authority verification

TEST ONLY / NOT FOR PRODUCTION / NO BROKER ACCESS.

Manifest: `SOMWANG_XAU_M15_FUSION_PRO_V5_MVP_BASKET_AUTHORITY_TESTS.mq5`.
Assertions execute the production owner/state-machine functions with real SQLite.
All external Broker rows/profile facts are visibly test-only observations.
No real Broker submission boundary is constructed or invoked.

| IDs | Requirement and actual observable |
| --- | --- |
| BASKET-01–03 | Missing physical CURRENT; missing capture rejected; owner flat creation persisted |
| BASKET-04–07 | Position/order/incomplete/row failure individually reject and leave CURRENT absent |
| BASKET-08 | Genuine prepared PendingRequest prevents reinitialization; no Permit/Claim |
| BASKET-09 | Deliberate independent Execution rollback fault isolates the real unresolved Submission veto |
| BASKET-10 | Owner-issued IDLE/v1 also satisfies accepted V5 checkpoint semantic oracle |
| BASKET-11–12 | Complete aggregate typed round trip and physical SHA-256 re-derivation |
| BASKET-13–15 | Exact idempotency, conflicting publication preserves row revision, stale owner rejected |
| BASKET-16–17 | Deliberate physical corruption rejected; new object loads exact prior aggregate |
| BASKET-18–22 | Actual physical D1 Claim record, Risk, Permit, both collections and durable pin bind loaded version |
| BASKET-23 | Another runner cannot reach the boundary with IDLE plus genuine unresolved Claim |
| BASKET-24–25 | Valid authorization/confirmation controls; missing authority and acknowledgement phase individually rejected |
| BASKET-26–27 | Decode entire ordered history; revalidate both transitions; compare full ACTIVE to CURRENT; versions 1/2/3 |
| BASKET-28 | Restart reloads IDLE and claimed-unresolved, with no reconstructed grant |
| BASKET-29–31 | Actual D6 positive converges ACTIVE; no-positive stays IDLE/unresolved; measured zero D6 submissions |
| BASKET-32 | Nested actual D1/D6 path results and non-mutating seam; no actual platform send |
| BASKET-33–34 | Real SQLite trigger aborts Basket publication after reconciliation; new providers resume |
| BASKET-35–36 | Real SQLite trigger aborts Submission terminalization after Basket publication; new providers resume |

Negative rollback/corruption fixtures are not represented as legitimate positive
lifecycle data. Ordered-history acceptance compares complete independently read
typed records, not local arithmetic or string presence alone.

`Verify-MvpBasketOffline.ps1` compiles the MVP/Broker manifests. With explicit
`-RunTester`, it runs only the fixed broker-free assertion configurations;
it refuses an existing terminal and any login/startup/EA-attachment configuration.
It never launches the attended runner. `*.raw.log` exports are ignored generated
lossless agent journals. Summaries must come from the current run's timestamp,
never earlier PASS text. Model-based Python checks are separate from REAL-MQL.
