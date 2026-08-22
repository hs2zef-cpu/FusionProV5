# Sprint 5 Phase B contract coverage matrix

| Authority | ADR | Phase B implementation | Verification | Deferred implementation |
|---|---|---|---|---|
| Signal Decision ingress boundary | ADR-009 | Immutable numeric source projection, strict binding, nonrecursive identity/digest, freshness, Producer Trust | ING/TRU/CAN | Runtime adapter: Phase C |
| EA host single writer | ADR-010 | Immutable orchestration events/results; no dispatcher | ORC | Coordinator/queue: Phase C |
| Startup runtime enable gate | ADR-012 | Authority tokens and fail-closed admission inputs | ADM/MUT | Startup runtime gate: Phase C/D |
| Durable ingress acceptance/request binding | ADR-013 | Ledger lifecycle/proposals and deterministic initial V5 blueprint | LED/BND | Physical durability: Phase D |
| Permit reservation/takeover quiescence | ADR-014 | Permit and durable submission-authority state | PER/CLM | Atomic store/quiescence: Phase D |
| Runtime publication/crash recovery | ADR-015 | Fenced request-set/checkpoint proposal/result contracts | PUB | Store/recovery execution: Phase D/E |
| Invocation claim/admission vector | ADR-016 | Exactly-once claim shape; ephemeral grant; stable vector | CLM/ADM | Broker invocation: Phase F |
| Namespace request sequence authority | ADR-017 | Namespace-wide reservation authority/proposal/result | SEQ | Linearizable allocator store: Phase D |
| Fenced runtime publication | ADR-018 | Expected store/logical revision plus ownership fence | PUB | CAS publication: Phase D |
| Coherent admission snapshot | ADR-019 | Typed tokens and double-collect validator | ADM | Integrated authority collectors: Phase E |
| Conditional policy admission | ADR-020 | P/Claim model, exclusive Risk expiry, mutation ordering | CLM/ADM/MUT | Runtime linearization: Phase C/E |

Phase F retains broker adapter/retcode/event-ordering and Demo-only integration work under separate authorization. Phase G retains immutable integration evidence and independent final execution-layer audit. No Phase C–G work is implemented here.
