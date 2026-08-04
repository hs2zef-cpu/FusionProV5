# Fusion Pro V5 Sprint 1 Architecture

## Scope

Sprint 1 creates the architectural skeleton only. The original V4/V4.2 trading logic is not redesigned, optimized, deleted, or migrated wholesale.

## Locked Boundaries

- Platform Adapter owns terminal data access that is not indicator-buffer access.
- IndicatorCache owns all `CopyBuffer()` calls.
- MarketSnapshot is versioned and treated as immutable after construction.
- Engines receive only `const SWV5_MarketSnapshot`.
- Engines do not call each other.
- PriceActionEngine emits state, bias, score, strength, confidence, and reason flags only.
- DecisionEngine is the only final BUY/SELL/WAIT authority.
- ExecutionPolicy gates final decisions, but does not invent signal rules.
- Dashboard receives DTOs and renders them read-only.
- LegacyEngineAdapter preserves existing indicator-buffer compatibility where buffers exist.

## File Tree

```text
SOMWANG_XAU_M15_FUSION_PRO_V5/
  SOMWANG_XAU_M15_FUSION_PRO_V4_2_LOOKBACK_CONFIRM_FIX.mq5
  SW_FIBO_BASIC_V3.mq5
  SOMWANG_XAU_M15_FUSION_PRO_V5_SPRINT1.mq5
  FusionProV5/
    Core/
      SW_V5_Types.mqh
      SW_V5_Interfaces.mqh
      SW_V5_ResultValidator.mqh
    Platform/
      SW_V5_PlatformAdapter.mqh
    Execution/
      SW_V5_ExecutionPolicy.mqh
    Indicators/
      SW_V5_IndicatorCache.mqh
    Engines/
      SW_V5_PriceActionEngine.mqh
      SW_V5_TrendEngine.mqh
    Decision/
      SW_V5_DecisionEngine.mqh
    Orchestration/
      SW_V5_Orchestrator.mqh
    Dashboard/
      SW_V5_ReadOnlyDashboard.mqh
    Adapters/
      SW_V5_LegacyEngineAdapter.mqh
    Docs/
      SPRINT1_ARCHITECTURE.md
```

## Unresolved Assumptions

- V4.2 Fusion has no plotted indicator buffers, so Sprint 1 cannot adapt V4.2 by buffer directly without adding buffers to a legacy wrapper later.
- `SW_FIBO_BASIC_V3` exposes BUY/SELL buffers and is the current concrete compatibility-buffer source.
- The V5 Sprint 1 indicator is an architectural harness, not the production trading indicator yet.
- Execution remains manual/advisory because the supplied sources are indicators, not an EA trade executor.

## Migration Plan

1. Wrap V4.2 `Evaluate()` output into a legacy DTO without changing its scoring.
2. Move all indicator-buffer reads from V4 helper functions into `CIndicatorCache`.
3. Convert V4/V5 core rating functions into independent domain engines.
4. Convert safety filters into independent engines returning DTO results.
5. Move final score and direction arbitration fully into `CDecisionEngine`.
6. Replace the legacy dashboard calls with `CReadOnlyDashboard`.
7. Add regression checks comparing V4.2 output against V5 legacy-adapter output on the same historical bars.
