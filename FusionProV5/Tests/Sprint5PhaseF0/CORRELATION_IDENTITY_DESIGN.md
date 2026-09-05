# Phase F0 Correlation Identity Study

TEST ONLY / F0 / NOT FOR PRODUCTION.

Precise blocker: **No durable broker-visible pre-send correlation design is
currently approved/proven for the target broker profile.** This does not assert
that no safe design can exist.

| Candidate | Known before/persistable before call | Broker transmitted | Active/history/position visibility | Restart/reconnect survival | Rewrite/truncation/collision/manual/other-EA risk | Frozen semantic impact | F0 status |
|---|---|---|---|---|---|---|---|
| `magic` | YES | YES | Commonly exposed, exact target profile unmeasured | Potentially queryable; unmeasured | Shared strategy value; not unique per request | Per-request repurposing would change frozen strategy/ownership semantics | REJECTED AS SOLE REQUEST IDENTITY |
| `comment` | YES | YES | Candidate visibility requires empirical order/deal/position profile | UNPROVEN | Broker rewrite/truncation and duplicate collisions unmeasured | No change if used only as non-authoritative evidence carrier | CANDIDATE — UNPROVEN |
| terminal `request_id` | Not an application-chosen durable value | Terminal/session result | Session-local result/callback correlation only | NO; restarts per terminal session | Reuse/collision across sessions | Durable use would violate frozen identity rules | FORBIDDEN AS DURABLE IDENTITY |
| order ticket | NO; broker assigned after submission | Broker authority | Orders/history orders | Potentially durable once observed | Not available for pre-send persistence | No frozen identity change if evidence only | CANNOT CLOSE PRE-SEND GAP |
| deal ticket | NO; broker assigned | Broker authority | History deals | Potentially durable once observed | Multiple deals per request/partial fill | Evidence only | CANNOT CLOSE PRE-SEND GAP |
| position identifier/ticket | NO; broker assigned/derived | Broker authority | Positions/history linkage depends on profile | Unmeasured | Position lifecycle and broker semantics | Evidence only | CANNOT CLOSE PRE-SEND GAP |
| `magic + comment` | YES | YES | Requires empirical preservation across every query domain | UNPROVEN | Comment rewrite/truncation remains decisive | Magic must retain frozen strategy meaning | PRIMARY CANDIDATE FOR MEASUREMENT ONLY |
| `comment + broker tickets` | Comment pre-send; tickets post-send | YES | Requires order/deal/history profile | UNPROVEN | Must handle missing/rewritten comment and partial fills | Evidence composition only | CANDIDATE — UNPROVEN |

Manual activity and other EAs must be tested as collision/adversarial cases.
Comment must not be assumed preserved. Magic must not be repartitioned or
redefined. The build-6180 disarmed profile did not make a broker call, so no
broker-preserved pre-send carrier has yet been proven.

## Governed runtime Magic materialization

The repository now defines `SWV5_RUNTIME_STRATEGY_MAGIC=1179670069`
(`0x46505635`, `FPV5`) in the sole executable SSOT
`Configuration/SW_V5_RuntimeIdentityProfile.mqh`. It is immutable strategy and
ownership scope, not a BasketID or per-request identity. Numeric values present
in Contract Verification, Phase B, and Phase D remain fixture/reference data,
not deployment authority; `0` remains invalid runtime identity.

The Demo probe has no mutable Magic input and the query probe classifies runtime
match, fixture/reference values, zero, and unrelated values without filtering
or treating Magic alone as correlation authority. The prior build-6180 evidence
predates materialization; a fresh disarmed gate and separate final confirmation
are required before any broker call.

Verdict: **NO SAFE CORRELATION CANDIDATE PROVEN — FUSION DECISION REQUIRED**.
