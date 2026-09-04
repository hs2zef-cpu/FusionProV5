# Phase F0 Attended Demo Runbook

TEST ONLY / F0 / DEMO ONLY / NOT FOR PRODUCTION.

This runbook is preparation, not authorization to execute. Fusion/operator must
schedule an attended run. Do not use automation to start or attach the probe.

## Mandatory pre-send gate

1. Operator is physically present and responsible for stopping the run.
2. Confirm the account is Demo and the runtime reports
   `ACCOUNT_TRADE_MODE_DEMO`.
3. Confirm `ACCOUNT_MARGIN_MODE_RETAIL_HEDGING`; NETTING means STOP.
4. Confirm exact broker, server, symbol, build, connection, and minimal volume.
5. Confirm no live/real-money account, production VPS, signal input, recurring
   loop, pending-order path, or unresolved prior experiment.
6. Compile from an immutable source commit and open a sanitized raw-evidence
   destination conforming to `EVIDENCE_SCHEMA.json`.
7. Run the query probe read-only first. Failure or incomplete history means no
   authoritative empty/negative claim and no armed send.
8. Keep `magic` at its frozen strategy value. Use `comment` only as an empirical
   candidate carrier, not approved authority.

## Single-send measurement

The operator must manually attach the Demo profile probe. Defaults are disarmed.
An armed run requires all runtime gates, exact server input, a non-empty test
comment, and one market BUY or SELL at the symbol's minimum volume. The probe
calls `OrderSend` at most once, never retries, never creates a pending order,
never auto-closes, and never treats the synchronous result as confirmation.

The operator must resolve and record any resulting Demo exposure manually under
the approved experimental procedure. An ambiguous result remains unresolved
until complete authoritative query/reconciliation evidence exists; timeout or
operator convenience may not clear it.

## Immediate stop conditions

Stop before any send on non-Demo, NETTING, server mismatch, connection failure,
unresolved prior attempt, missing evidence capture, or unsafe environment. Stop
after any duplicate side effect, material profile inconsistency, query
incompleteness, or evidence that frozen contracts cannot represent the result.
