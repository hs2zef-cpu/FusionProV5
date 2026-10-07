# ADR-026: MVP canonical account Risk namespace authority

## Status and scope

Implementation of the explicit Fusion account-authority closure decision,
pending review. No Architecture Lock, actual Demo D1, live-trading, Phase G or
production authorization. The accepted Basket and Hard Kill semantics and all
frozen Production V5/Sprint 5 DTOs and interfaces remain unchanged.

## Durable namespace versus fresh observation

`SWV5_AccountRiskNamespace.snapshot_epoch` and `snapshot_sequence` identify the
stable account namespace authority generation, not an account-read counter.
Only `SWV5S5_MvpAccountRiskAuthority` issues the first physical `1/1` generation.
It is never borrowed from a lease, takeover, clock, process or wrapper constant.
Repeated capture of financial facts does not advance either namespace token.
Complete fresh account and exposure canonical payloads, domain SHA-256 and
freshness remain independently included in the frozen Risk binding projection.
This preserves ADR-019's two evidence layers without changing frozen structures.

## Physical authority and fail-closed policies

`MVP_ACCOUNT_RISK_AUTHORITY/CURRENT` stores the strict versioned complete record:
persistence/account scope, complete account namespace, authority epoch/publication
sequence, record ID/revision, created time and CURRENT status. Its physical row
contains domain-separated SHA-256 and the independently re-derived store token.
Creation requires canonical ready Genesis, exact locked Demo/HEDGING/USD profile,
successful current read-only account observation, current physical ownership
lease, ownership-guarded CAS and full canonical readback. LIVE_BROKER_STATE is the
only source. Ownership guards the write, but cannot determine the account token.

Identical creation is idempotent without changing time, digest or revision.
Conflicting scope, corrupt records and stale owners fail closed. If the row is
missing and dependent state exists, a closed infrastructure allowlist prevents
recreation as `1/1`; unknown rows do not prove an empty namespace. Restart and
valid ownership takeover reload the same independent authority. Automatic epoch
rollover, profile migration and account aggregation are outside this MVP scope.

## Consumers and setup order

Explicit setup creates Account authority after Genesis/Ownership and before
Trust or anything persisting an AccountRiskNamespace. BootstrapZero/Hard Kill,
Basket Risk snapshots, Margin/Basket Risk issuers, every Risk input namespace,
Risk authorization, both Admission collections and Claim consume that physical
namespace. Both collections reload and derive the frozen account projection;
Claim revalidates rather than issuing/replacing a token. D6 reloads the same
account authority against the current observed profile and persisted Permit.

`SWV5S5_MvpAccountObservationProducer` captures current facts through the existing
read-only platform and loads the independent canonical flat Basket. Actual
complete empty Broker enumeration, not local request absence, proves initial
flat exposure. Account values are never made current merely by persistence of
the namespace. The runtime-only observation envelope carries full account and
exposure snapshots and their SHA-256 identities; it does not invent a sequence.

Preflight loads existing SQLite READONLY without CREATE, DDL or metadata writes.
Missing authority is an explicit setup failure, not permission to provision.

## Serialized D1 observation coherence

Each preparation event captures one account/exposure observation. Margin and
Basket Risk receive the same runtime-only immutable envelope; neither issuer
captures account state. Platform margin/profit calculations remain read-only.
The full account and exposure canonical digests bind balance, equity, current
margin, free margin, both daily nets, trading day, exposure totals, namespace
and timestamps. The combined digest is the observation identity (no extra
sequence issuer). Margin binds it in its existing calculation reference;
Basket Risk binds it in its existing source snapshot fields. Their normal
authority-record digests protect these references. Frozen fields do not change.

Risk's runtime `EvaluateObserved` gate re-derives every observation digest and
requires exact input, namespace, timestamp and source-reference agreement before
the existing evaluator can authorize. Admission repeats the same gate, then the
frozen Risk projection protects full financial content separately from V1/V2's
stable Account namespace projection. A mixed, corrupted or stale observation
fails closed. Exact numeric equality is appropriate for immutable copies of the
same financial sample, not independently derived market-price calculations.

## Evidence boundaries

ACCOUNT-01..36 and ACCOUNT-COHERENCE-01..09 use real MQL owners, SQLite transactions/readback/restart,
deliberate physical corruptions and positive/negative Admission/Claim paths.
External account/Broker fixtures are expressly TEST ONLY. They are not actual
Demo D1 or live-exposure evidence. Python models/static scans and compiler
results must be reported separately from Strategy Tester execution.
The additional sixteen field-wise negative fixtures reject each monetary,
exposure, namespace and timestamp mismatch through the real observation gate.
They do not establish production-code mutation-detection power.
