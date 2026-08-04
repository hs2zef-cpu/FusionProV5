# Breaking Changes: Sprint 4 Architecture

There are no runtime behavioral changes because Sprint 4 contains contracts only.

New compile-time contract types use the `SWV5_` prefix and live under `FusionProV5/ProductionArchitecture/`. They are not wired into Sprint 3.2.1 Signal Engine modules.

Future implementations must conform to these contracts or receive an approved architecture revision. No existing Signal Engine API, score, decision, dashboard, regression, or snapshot behavior changed.
