# Sprint 5 Phase F — Broker Adapter Implementation Status

Status: **CANDIDATE / IN REVIEW**

Accepted entry-contract source: `4e5a785f77d291c2e43499da9da9c5fb7572f5cb`

Architecture Lock: **NOT GRANTED**

Demo or live broker-mutating execution: **NOT AUTHORIZED / NOT PERFORMED**

Phase G / main merge / production deployment: **NOT AUTHORIZED**

The implementation confines every direct MT5 account, symbol, query, callback,
and `OrderSend` API to `SW_V5_S5_F_BrokerPlatformBoundary.mqh`. The pure core
requires the exact authoritative `CLAIM_GRANTED_NOW` result from the same
operation, the accepted bound request and profile, current permissions, valid
normalized parameters, supported filling, and a canonical submission digest.
The platform boundary contains exactly one guarded synchronous send site and no
retry path.

Audit hardening re-samples all permission, profile, and symbol-specification
inputs immediately before the send; validates a field-for-field digest of the
final wire-ready `MqlTradeRequest`; forbids post-digest normalization/coercion;
uses exact one-to-one filling mapping; and compares price/volume authority in
symbol-derived integer grid units. Market `price` is explicitly indicative,
while `stop_price` and `limit_price` are the optional SL and TP values.

Synchronous results and callback records are fully copied into digest-bound
observational evidence. Neither is final confirmation. Durable Broker queries
enumerate positions, active orders, history orders, history deals and persisted
callback transactions with row-read accounting, owner-specific sequence,
connection/restart generation, read-path identity, authority-instance identity,
sequence-authority identity, reported totals, and a canonical snapshot digest.
Execution pending-request observation remains a structurally separate authority,
read path, sequence authority, snapshot, and digest. Row omission or read failure
cannot support authoritative negative evidence.

Positive evidence requires the persisted request/Claim/profile-to-sync mapping
and the ordered, fully read broker order/deal/position relationship. Magic and
comment remain non-authoritative scope/metadata. Negative evidence stays
fail-closed unless an independently governed, pinned capability proof validates
completeness and visibility prerequisites. F0 `UNPROVEN` observations therefore
cannot become authoritative negative evidence.

Publication is proposed only through an existing persistence-facing CAS
interface. It requires a current reconciliation lease/fence and exact expected
store/reconciliation revisions. Stale CAS cannot succeed through content
equality. Historical Claim fencing evidence is not rewritten.

Still unproven: broker-query universal completeness, visibility watermarks,
capability-proof issuance, physical durable stores, platform-clock behavior,
reconnect behavior with exposure, broker-specific callback ordering, real
retcode behavior, and any Demo/live broker mutation by this implementation.
The final pre-send re-sample narrows but cannot eliminate the irreducible TOCTOU
interval between its last platform read and the platform call.
