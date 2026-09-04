# Sprint 5 Phase E — Integrated V5 Fixtures

TEST ONLY / NOT FOR PRODUCTION / NO BROKER ACCESS.

This package composes the frozen Phase B contract, Phase C deterministic
coordinator, and Phase D persistence/restart reference boundaries. It introduces
no production authority, second intent journal, runtime implementation, physical
store, platform clock, broker, Signal dependency, or execution wiring.

Run the independent offline oracle:

```powershell
python -B FusionProV5/Tests/Sprint5PhaseE/verify_phase_e_integration.py
```

Run the source credibility check:

```powershell
python -B FusionProV5/Tests/Sprint5PhaseE/verify_phase_e_source.py
```

Run the separate Python-only mutation controls:

```powershell
python -B FusionProV5/Tests/Sprint5PhaseE/verify_phase_e_mutation_controls.py
```

Run the transitive include, forbidden-API, and reverse-dependency scan:

```powershell
python -B FusionProV5/Tests/Sprint5PhaseE/verify_phase_e_isolation.py
```

The oracle is an **independent executable reference/adversarial oracle**. It is
not MQL execution, MT5 proof, broker proof, or physical database proof. Expected
outcomes are literal scenario declarations. The deterministic scheduler orders
events only and is non-authoritative.

The Phase-E MQL manifestations compile the existing frozen interfaces and direct
cross-phase source probes; their `OnStart` bodies are empty. MQL assertions
executed: **NO**. MetaEditor is used only as an X64 Regular compiler. Terminal and
Strategy Tester are not used.

Phase D is CLOSED/PASS. Phase E remains development self-verification until
AiPASS post-patch review and any subsequently authorized independent audit.
Phase F/G, real runtime/platform/broker, main merge, production, and live trading
are NOT AUTHORIZED.

Observed correction gates: 52/52 ordinary oracle scenarios and 8/8 separate
mutation controls, both repeated deterministically; Phase B 139/139, Phase C
22/22, Phase D 318/318; and eight MetaEditor X64 Regular manifests at 0 errors /
0 warnings. The prior generation's three controls were insufficient for the
required mutation classes; `NEGATIVE_CONTROL_MATRIX.md` records the expanded
targeted controls. See `PHASE_E_SELF_VERIFICATION.md` for exact digests and
evidence limitations.
