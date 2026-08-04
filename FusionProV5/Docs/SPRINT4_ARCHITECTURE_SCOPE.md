# Fusion Pro V5 Sprint 4 Architecture Scope

## Authorized Work

- Production DTO contracts
- Abstract interfaces
- Basket state and transition rules
- Persistence and restart reconciliation contract
- Execution request/confirmation contract
- Risk-domain contract
- Basket identity and residual-exposure contract
- Authoritative statistics contract
- Duplicate-instance ownership contract
- Symbol unit and normalization contract
- Architecture documentation and compile manifest

## Explicitly Excluded

- Broker command implementation
- Automated trading
- Concrete execution coordinator
- Concrete persistence or lock store
- Recovery algorithm
- Basket execution algorithm
- Signal-to-execution runtime wiring
- Threshold or signal behavior changes
- Any modification to frozen Sprint 3.2.1

## Definition Of Done

- All required domains have typed DTOs and abstract interfaces.
- Basket allowed/forbidden transitions and invariants are documented.
- Ownership and authority are unambiguous.
- Request confirmation cannot be inferred from request acknowledgement.
- Restart cannot resume before ownership and broker reconciliation.
- Risk is separated into account, basket, exposure, equity, daily loss, Hard Kill, and aggregate exposure.
- Statistics use authoritative deal evidence including commission, swap, fee, and partial closes.
- Unit normalization distinguishes point, tick, pip, price, volume step, tick value, stops level, and freeze level.
- Production architecture source contains no broker command implementation.
- MetaEditor reports zero errors and zero warnings.
