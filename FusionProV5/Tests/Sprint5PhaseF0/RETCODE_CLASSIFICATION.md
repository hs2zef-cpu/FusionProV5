# Phase F0 Retcode Classification

TEST ONLY / F0 / PROFILE CANDIDATE / NOT FOR PRODUCTION.

Version: `SWV5-S5-F0-RETCODE-PROFILE-V1`
Measured broker/profile: **NONE**

| Class | Meaning | Side-effect statement |
|---|---|---|
| R0 `ADAPTER_LOCAL_REJECT` | Validation stops before any broker call | Only intrinsic side-effect-free class |
| R1 `BROKER_EXPLICIT_REJECT_CANDIDATE` | Explicit broker reject candidate | Not authoritative until exact broker/profile certification |
| R2 `ACCEPTED_SUBMISSION` | Accepted/placed | Submission evidence only; not confirmation |
| R3 `PROVISIONAL_SYNC_EVIDENCE` | Sync deal/order/volume hints | Provisional only; not Basket/deal confirmation |
| R4 `AMBIGUOUS` | Timeout, unknown/unmapped, malformed/uncertain response | No retry; no negative evidence |
| R5 `TRANSPORT_PLATFORM_FAILURE` | Connection/platform transport failure | Ambiguous unless authoritative evidence later proves otherwise |

| Retcode/failure | Candidate class before profile | Required measurement |
|---|---|---|
| `TRADE_RETCODE_PLACED` | R2 | Sync result plus callback/query sequence |
| `TRADE_RETCODE_DONE` | R2 + R3 fields | Must not become confirmation without authoritative evidence |
| `TRADE_RETCODE_DONE_PARTIAL` | R2/R3; unresolved remainder | Partial-fill and durable query profile |
| `TRADE_RETCODE_TIMEOUT` | R4 | Reconnect and complete-query resolution; never blind retry |
| requote | R1 candidate or R4 until measured | Exact broker side-effect behavior |
| price changed | R1 candidate or R4 until measured | Exact broker side-effect behavior |
| price off | R1 candidate or R4 until measured | Exact broker side-effect behavior |
| invalid filling | R1 candidate | Explicit target-profile certification required |
| no connection/transport | R5→R4 | Demo disconnect/reconnect evidence required |
| trading disabled | R1 candidate or local R0 when blocked before call | Distinguish local prevention from broker call |
| external retcode | R4 until mapped empirically | Record raw value and broker profile |
| unknown/unmapped | R4 | Fail closed; no retry |

No universal mapping is approved. No broker-specific R1 certification exists in
this package because no attended Demo broker-call run occurred. The build-6180
attended session was read-only/default-disarmed observation only.
