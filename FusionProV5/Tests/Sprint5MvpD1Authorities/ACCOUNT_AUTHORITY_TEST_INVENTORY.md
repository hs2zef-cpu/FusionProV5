# Account authority verification inventory

TEST ONLY / NOT FOR PRODUCTION / NO BROKER ACCESS.

The executable `SOMWANG_XAU_M15_FUSION_PRO_V5_MVP_ACCOUNT_AUTHORITY_TESTS.mq5`
uses actual runtime owners and suite-private physical SQLite stores. External
read-only account facts are deterministic TEST ONLY fixtures, not executed live
MT5 account evidence. No production source imports these fixtures. Counts and
signatures must come from the fresh Strategy Tester journal, never this inventory.

| Test | Behavior exercised |
|---|---|
| ACCOUNT-01 | Genesis/Ownership exist but physical Account CURRENT is absent. |
| ACCOUNT-02 | A manual fixture namespace cannot validate without the physical owner. |
| ACCOUNT-03 | Valid exact locked Demo observation creates via guarded CAS/readback. |
| ACCOUNT-04 | The physically committed first generation is 1/1. |
| ACCOUNT-05 | LIVE_BROKER_STATE source is retained. |
| ACCOUNT-06 | Complete strict payload and store revision round trip. |
| ACCOUNT-07 | Complete physical payload SHA-256 re-derivation. |
| ACCOUNT-08 | Duplicate preserves payload, store token and original creation time. |
| ACCOUNT-09 | Conflicting observed profile cannot provision/replace. |
| ACCOUNT-10 | Noncurrent Ownership cannot provision. |
| ACCOUNT-11 | New owner object/read-only connection restores exact record. |
| ACCOUNT-12 | Restart preserves epoch. |
| ACCOUNT-13 | Restart preserves namespace publication sequence. |
| ACCOUNT-14 | Physically changed valid Ownership consumes unchanged Account row/token. |
| ACCOUNT-15 | Foreign server blocks current authority use. |
| ACCOUNT-16 | NETTING drift blocks use. |
| ACCOUNT-17 | Currency drift blocks use. |
| ACCOUNT-18 | Deliberately corrupted complete physical payload fails closed. |
| ACCOUNT-19 | Deleted Account with dependent operational state cannot be recreated. |
| ACCOUNT-20 | Actual concrete preflight fails and does not recreate missing Account. |
| ACCOUNT-21 | Fresh captured account values/time flow through the actual producer. |
| ACCOUNT-22 | Complete physical flat observation plus independent Basket proves exposure. |
| ACCOUNT-23 | Account snapshot consumes the owner-issued namespace. |
| ACCOUNT-24 | Exposure consumes the identical namespace. |
| ACCOUNT-25 | Actual physical release/activation Hard Kill consumes that namespace. |
| ACCOUNT-26 | Canonical Basket Risk snapshot consumes that namespace. |
| ACCOUNT-27 | Actual Margin issuance consumes that namespace. |
| ACCOUNT-28 | Actual Basket Risk issuance consumes that namespace. |
| ACCOUNT-29 | Every namespace in the actual prepared Risk candidate is identical. |
| ACCOUNT-30 | ALLOW authorization copies independently issued epoch/sequence. |
| ACCOUNT-31 | Actual V1 consumes the canonical owner namespace/projection. |
| ACCOUNT-32 | Actual V2 consumes the same canonical namespace/projection. |
| ACCOUNT-33 | Re-sealed unauthorized generation blocks renewed Admission collection. |
| ACCOUNT-34 | Changed financial observation changes complete observation/Risk projections, not namespace. |
| ACCOUNT-35 | Claim rejects changed physical authority without recreating it or granting. |
| ACCOUNT-36 | Actual physical D1 Claim reaches a nonmutating seam once; broker calls remain zero. |
| ACCOUNT-COHERENCE-01 | One instrumented financial capture feeds actual issued Margin/Basket Risk and evaluated Risk. |
| ACCOUNT-COHERENCE-02 | The three issued outputs bind the identical independent Account namespace. |
| ACCOUNT-COHERENCE-03 | Full account/exposure digest equals both records' source references. |
| ACCOUNT-COHERENCE-04 | Margin calculation changes the next fixture read; no second read occurs inside preparation and later probe cannot replace the captured value. |
| ACCOUNT-COHERENCE-05 | Wrong observation digest rejects Risk evaluation with no authorization. |
| ACCOUNT-COHERENCE-06 | Re-sealed wrong observed_at rejects Risk evaluation with no authorization. |
| ACCOUNT-COHERENCE-07 | Authorized epoch/sequence remain the physical namespace token. |
| ACCOUNT-COHERENCE-08 | Actual V1/V2 remain stable while changed financial Risk input fails the observation gate. |
| ACCOUNT-COHERENCE-09 | Actual full physical D1 rehearsal reaches its nonmutating seam exactly once and no broker invocation occurs. |

Distinct stores prevent an open negative-case provider from interfering with
later setup. Takeover is a deliberate external Ownership fixture publication,
not a new production takeover implementation. Generation mutation re-seals both
payload SHA and store token to isolate semantic rejection. Corruption never
becomes a positive authority fixture.

Run `Verify-MvpBasketOffline.ps1 -RunTester -AccountOnly` for the focused gate,
or omit `-AccountOnly` for the full authority/adapter regression batch. Only
offline test manifests are deployable by that helper. Raw agent journals are
retained in ignored `*.raw.log` files.

The 61-case suite separates observed financial content from durable namespace
generation. Exact double comparisons here compare copies of the same captured
values, not independently sampled prices or numeric normalization results.

`ACCOUNT-COHERENCE-FIELD-1..16` independently change balance, equity, margin,
free margin, realized daily net, unrealized daily net, trading day, long/short/net
symbol volume, aggregate volume, notional, live Basket count, nested namespace
sequence, Account timestamp and Exposure timestamp. Every case starts from the
positively evaluated candidate and invokes the real `EvaluateObserved` gate;
it must return false and a blocked/empty authorization. These are negative
input fixtures, not claimed production-code mutation-detection evidence.
