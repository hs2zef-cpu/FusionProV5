#!/usr/bin/env python3
"""Mutation controls for the independent Demo MVP policy oracle."""

from dataclasses import replace

from verify_mvp_runtime import (
    BasketRisk, Margin, Operator, Risk, Symbol, basket_authority,
    callback_matches_submission, execution_observation, hard_kill_transition,
    margin_authority, operator_valid, risk_allowed, symbol_valid,
)


def main() -> int:
    rows = [
        ("MUT-SYMBOL", not symbol_valid(replace(Symbol(), symbol="XAUUSD.a"))),
        ("MUT-DIGITS", not symbol_valid(replace(Symbol(), digits=2))),
        ("MUT-EXPIRY", not symbol_valid(replace(Symbol(), valid_until=105))),
        ("MUT-DEMO", not risk_allowed(replace(Risk(), demo=False))),
        ("MUT-CURRENCY", not risk_allowed(replace(Risk(), usd=False))),
        ("MUT-MARGIN", not risk_allowed(replace(Risk(), projected_margin=100.0001))),
        ("MUT-VOLUME", not risk_allowed(replace(Risk(), volume=0.0101))),
        ("MUT-NOTIONAL", not risk_allowed(replace(Risk(), notional=10000.0001))),
        ("MUT-ORDER", not margin_authority(replace(Margin(), orders=1))[0]),
        ("MUT-CALC-MARGIN", not margin_authority(replace(Margin(), calculation_ok=False))[0]),
        ("MUT-STOP-SIDE", not basket_authority(replace(BasketRisk(), stop=3501))[0]),
        ("MUT-COST-RESERVE", not basket_authority(replace(BasketRisk(), calculated_profit=-4.0001))[0]),
        ("MUT-OPERATOR-ROLE", not operator_valid(replace(Operator(), role="FUSION_DEMO_OPERATOR"))),
        ("MUT-OPERATOR-AUTH", not operator_valid(replace(Operator(), auth=""))),
        ("MUT-CALLBACK-CONFLICT", not callback_matches_submission(11, 99, 44, 11, 12, 44)),
        ("MUT-EXECUTION-ROW-OMISSION", execution_observation(True, True, 3, [True, True])[1] == 1),
        ("MUT-HARD-KILL-SKIP-PENDING", hard_kill_transition("ACTIVE", True, True) != "RELEASED"),
    ]
    for test_id, passed in rows:
        print(f"MVP_MUTATION|{test_id}|{'KILLED' if passed else 'SURVIVED'}")
    killed = sum(ok for _, ok in rows)
    print(f"MVP_MUTATION_SUMMARY|total={len(rows)}|killed={killed}|survived={len(rows)-killed}")
    return 0 if killed == len(rows) else 1


if __name__ == "__main__":
    raise SystemExit(main())
