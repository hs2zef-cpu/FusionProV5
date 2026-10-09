# Native attended D1 quote binding

Narrow launch binding correction. No deployment authorization is conveyed by
this source or test inventory; return the new immutable source to Fusion first.

## Defect and binding

The former Authority Port promoted caller `requested_price` to market authority
and manufactured a one-point Bid/Ask spread. Native attended D1 now captures
XAUUSD Bid/Ask together using `SymbolInfoTick`, before Decision evaluation in
the serialized current-symbol OnTick. The runtime-only observation carries
symbol, bid, ask, server seconds/milliseconds, capture time, source and
completeness. No frozen DTO or Unit/Risk/Broker contract changes.

Authority preparation independently re-reads the native quote and requires
the same millisecond tick identity, symbol and tick-size-compatible prices as
the event capture. Both tick seconds and capture seconds must match the
authoritative event clock. Missing, stale, future, incompatible or changed
observations fail closed; a nonzero cached quote is not enough.

BUY raw/reference/operation entry is native ASK; Unit market Bid and Ask are
the captured native values. The existing frozen Unit evaluator owns normalization.
The compatibility `requested_price` input is ignored by the Authority Port;
it cannot override native market evidence. SELL/D3 remains unauthorized.

SL must be positive and below native entry. Nonzero TP must be above it.
The existing Unit distance/alignment checks still apply. Absolute operator
protection is not shifted to accommodate market movement. No risk widening,
automatic stop adjustment, retry or new send site is added.

One normalized payload feeds native margin and stop-loss calculations, Risk,
materialization/request publication, Permit, Admission V1/V2, Claim and the
existing final Broker wire-command digest. Broker final environment resampling
is unchanged. A quote pin is not a price guarantee: MT5 event dispatch does not
freeze the external market through submission. Any eventual fill remains Broker
evidence, and the existing irreducible TOCTOU boundary still applies.

## Executable traceability (Demo Strategy Tester only)

| Test | Meaningful output/guard |
|---|---|
| QUOTE-01 | Native observation agrees with independently read MqlTick Bid/Ask/milliseconds |
| QUOTE-02, QUOTE-19 | Independent 200-tick fixture preserves real spread in production binding helper |
| QUOTE-03..06 | Actual physical Unit input/normalized entry equals captured ASK; stale caller price differs |
| QUOTE-07-0..4 | Stale tick, stale capture, off-tick price, incomplete and foreign-source rejection |
| QUOTE-08..09 | Wrong symbol, zero Bid and inverted spread rejection |
| QUOTE-10..11 | Invalid absolute SL/TP reject; valid optional TP accepted, no automatic shift |
| QUOTE-12..13 | Recording native-calculation subclass observes normalized margin/loss entry; durable Margin/Basket Risk readback |
| QUOTE-14..15 | Physical Risk and Permit price/protection match the normalized payload |
| QUOTE-16 | Both Admission collections and persisted Claim snapshot bind the normalized entry |
| QUOTE-17..18 | Actual seam-received Claim and Broker command bind normalized price/protection |
| QUOTE-20 | Exactly one non-mutating seam; source audit prohibits any native send in that seam |
| QUOTE-EVENT-REJECT-0..3 | Actual dispatch rejects different tick millisecond, changed Bid, wrong symbol and missing quote; no Claim/send |

These extend the 47-case attended rehearsal to 75 assertions. The existing
authentic Decision BUY, SQLite authority chain and D6 restart tests remain.
Native calculation evidence is distinct from Python oracles and static checks.
The synthetic synchronous acknowledgement seam is NOT a Broker submission;
its simulated `invocation_attempted` counter must not be reported as a native
send count. No actual `OrderSend` is authorized in this verification run.

## Gates

Compile all accepted MVP launch/test manifests using MetaEditor X64 Regular:
zero errors/warnings. Execute the updated attended rehearsal and all existing
MQL regression floors using `Verify-MvpBasketOffline.ps1 -RunTester` only with
no existing terminal process. The runner must stop rather than interact with
an existing attended terminal. Native deployment database provisioning is out
of scope. Preserve the historical F0 PRE-EXISTING / WAIVED disposition.

The 52-check launch source scan includes event capture, no caller fabrication,
quote shape/time/source, no mutation in the native observation, downstream
payload binding, independent nontrivial fixtures, frozen isolation and exactly
one unchanged production OrderSend site. Source checks are not MQL execution.
