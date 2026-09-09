#!/usr/bin/env python3
"""TEST ONLY / NOT FOR PRODUCTION / NO BROKER ACCESS."""
from pathlib import Path
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[3]
BASE="9ef04d4be9d6a2ffcd1369dd71b5e14dcebd8d26"
CONTRACT=ROOT/"FusionProV5/ExecutionLayer/Contracts/SW_V5_S5_ReconciliationEvidenceContract.mqh"
required=(
 "SWV5S5_F_NO_CALL", "SWV5S5_F_SUBMISSION_UNRESOLVED",
 "SWV5S5_F_SIDE_EFFECT_POSITIVELY_CONFIRMED", "SWV5S5_F_NO_SIDE_EFFECT_CONFIRMED",
 "SWV5S5_F_PARTIAL_EFFECT_CONFIRMED", "SWV5S5_F_RECONCILIATION_BLOCKED",
 "NON_AUTHORITATIVE_NEGATIVE_CANDIDATE_PRESERVES_UNRESOLVED",
 "PARTIAL_DURABLE_SIDE_EFFECT_RESIDUAL_UNRESOLVED", "retry_allowed=false",
 "magic_used_as_sole_authority", "comment_used_as_sole_authority",
 "query_completeness_capability_proven", "visibility_watermark_proven",
 "SWV5S5_F_DeriveNegativePolicyDigest", "SWV5_COMPONENT_AUTHORITY_OPERATOR",
 "SWV5S5_F_DeriveProfileDigest",
 "SWV5S5_F_DeriveCorrelationPolicyDigest", "correlation_policy_digest",
 "ordered_deal_set_digest", "all_deals_linked_to_order_and_position",
 "expected_broker_query_high_watermark", "expected_execution_query_high_watermark",
 "claim_ownership_fence", "current_reconciliation_lease", "claimed_at",
 "persisted_confirmed_volume", "persisted_residual_volume",
 "TERMINAL_STATE_BINDING_MISMATCH",
)
forbidden=("OrderSend(","OrderSendAsync(","CTrade","OnTradeTransaction(",
           "PositionOpen(","PositionClose(","HistorySelect(","FileOpen(","WebRequest(")

def git(*args):
    return subprocess.check_output(["git",*args],cwd=ROOT,text=True).splitlines()

def main():
    text=CONTRACT.read_text(encoding="utf-8")
    failures=[]
    failures += [f"missing:{item}" for item in required if item not in text]
    code_files=[CONTRACT, ROOT/"FusionProV5/Tests/Sprint5PhaseF/SW_V5_S5_PHASE_F_ENTRY_COMPILE.mq5"]
    for path in code_files:
        source=path.read_text(encoding="utf-8")
        failures += [f"forbidden:{path.name}:{token}" for token in forbidden if token in source]
    changed=git("diff","--name-only",BASE,"--")
    protected_prefixes=("FusionProV5/ProductionArchitecture/","FusionProV5/SignalEngine/",
                        "FusionProV5/DecisionEngine/","FusionProV5/Engines/",
                        "FusionProV5/Dashboard/","FusionProV5/Tests/Sprint5PhaseB/",
                        "FusionProV5/Tests/Sprint5PhaseC/","FusionProV5/Tests/Sprint5PhaseD/",
                        "FusionProV5/Tests/Sprint5PhaseE/")
    failures += [f"protected-change:{p}" for p in changed if p.startswith(protected_prefixes)]
    print(f"PHASE_F_SOURCE|checks={len(required)+len(forbidden)*len(code_files)+1}|failures={len(failures)}")
    for failure in failures: print(f"FAIL|{failure}")
    return 1 if failures else 0

if __name__=="__main__":
    sys.exit(main())
