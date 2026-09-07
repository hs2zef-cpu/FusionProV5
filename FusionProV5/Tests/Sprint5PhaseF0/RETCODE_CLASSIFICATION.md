# Phase F0 Retcode Classification

TEST ONLY / F0 / PROFILE CANDIDATE / NOT FOR PRODUCTION.

Version: `SWV5-S5-F0-RETCODE-PROFILE-V1`
Measured broker/profile: **CLIENT-LOCAL REJECTION ONLY; BROKER PROFILE NONE**

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
this package because the sole attended Demo API invocation was rejected by the
local terminal before broker acknowledgement.

## Observed build-6180 result

`F0-6180-CLIENT-LOCAL-REJECT-001` returned `transport_result=0`,
`last_error=4752`, `retcode=10027`, `request_id=0`, `order=0`, `deal=0`, and
`AutoTrading disabled by client`. Because `OrderSend` was invoked, this is not
the intrinsic pre-call R0 class. Because no broker acknowledgement is proven,
it is not a certified R1 broker rejection. The run is held fail-closed as R4
pending a Fusion decision on an explicit post-invocation client-local class.
Zero callback/query rows do not upgrade this classification to authoritative
no-side-effect evidence.
