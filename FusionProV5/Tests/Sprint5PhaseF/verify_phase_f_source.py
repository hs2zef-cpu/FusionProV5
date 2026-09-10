#!/usr/bin/env python3
"""TEST ONLY / NOT FOR PRODUCTION / NO BROKER ACCESS."""
from pathlib import Path
import re
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[3]
BASE = "5cb530e492a0c045cb24990fe1a3532e7f894c03"
CONTRACT = ROOT / "FusionProV5/ExecutionLayer/Contracts/SW_V5_S5_ReconciliationEvidenceContract.mqh"
MUTATIONS = ROOT / "FusionProV5/Tests/Sprint5PhaseF/verify_phase_f_mutation_controls.py"

REQUIRED = (
    "SWV5S5_F_NoCallProof", "SWV5S5_F_IsNoCallProofValid", "AUTHORITATIVE_LOCAL_NO_CALL_PROOF",
    "NO_CALL_CONTRADICTED_BY_CLAIM_OR_EVIDENCE", "ORPHAN_OR_UNAUTHORIZED_POSITIVE_SIDE_EFFECT",
    "residual_is_submission_authority", "requires_new_request_identity_for_residual",
    "PARTIAL_DURABLE_SIDE_EFFECT_RESIDUAL_NON_AUTHORITY_NEW_REQUEST_REQUIRED",
    "SWV5S5_F_CapabilityProof", "SWV5S5_F_IsCapabilityProofValid",
    "proof.issuing_component!=SWV5_COMPONENT_AUTHORITY_BROKER_ADAPTER",
    "pinned_correlation_policy_digest", "pinned_negative_policy_digest", "pinned_capability_proof_digest",
    "PINNED_POLICY_DRIFT_OR_CAPABILITY_PROOF_INVALID",
    "first.connection_generation==second.connection_generation",
    "first.restart_generation==second.restart_generation",
    "first.broker_query_set.observed_at>=binding.claimed_at",
    "first.execution_query_set.observed_at>=binding.claimed_at",
    "second.broker_query_set.observation_sequence>first.broker_query_set.observation_sequence",
    "second.execution_query_set.observation_sequence>first.execution_query_set.observation_sequence",
    "broker_read_path_id!=observation.execution_read_path_id",
    "broker_authority_instance_id!=observation.execution_authority_instance_id",
    "RECONCILIATION_BLOCKED_STICKY_REQUIRES_EXTERNAL_RECOVERY_AUTHORITY",
    "persisted_terminal_evidence_digest",
    "SWV5S5_F_DeriveResultDigest", "SWV5S5_F_DOMAIN_RECONCILIATION_RESULT",
    "retry_allowed=false", "NON_AUTHORITATIVE_NEGATIVE_CANDIDATE_PRESERVES_UNRESOLVED",
)
MUTATION_IDS = (
    "MC-NOCALL-BYPASS", "MC-ORPHAN-BINDING", "MC-RESIDUAL-AUTHORITY",
    "MC-WATERMARK-COLLAPSE", "MC-CAPABILITY-SELFATTEST", "MC-POLICY-DRIFT",
    "MC-TERMINAL-OVERWRITE", "MC-SINGLE-ROW-POSITIVE",
    "MC-DIGEST-DOMAIN-SUBSTITUTION", "MC-SHARED-EVIDENCE-SOURCE",
)
FORBIDDEN = (
    "OrderSend(", "OrderSendAsync(", "CTrade", "OnTradeTransaction(",
    "PositionOpen(", "PositionClose(", "HistorySelect(", "FileOpen(", "WebRequest(",
)


def git(*args):
    return subprocess.check_output(["git", *args], cwd=ROOT, text=True).splitlines()


def main():
    text = CONTRACT.read_text(encoding="utf-8")
    mutation_text = MUTATIONS.read_text(encoding="utf-8")
    failures = [f"missing:{item}" for item in REQUIRED if item not in text]
    failures += [f"missing-mutation:{item}" for item in MUTATION_IDS if item not in mutation_text]

    domains = re.findall(r'^#define\s+SWV5S5_F_DOMAIN_[A-Z_]+\s+"([^"]+)"', text, re.MULTILINE)
    if len(domains) != len(set(domains)) or len(domains) < 7:
        failures.append("digest-domain-separation")

    code_files = [CONTRACT, ROOT / "FusionProV5/Tests/Sprint5PhaseF/SW_V5_S5_PHASE_F_ENTRY_COMPILE.mq5"]
    for path in code_files:
        source = path.read_text(encoding="utf-8")
        failures += [f"forbidden:{path.name}:{token}" for token in FORBIDDEN if token in source]

    changed = git("diff", "--name-only", BASE, "--") + git("ls-files", "--others", "--exclude-standard")
    protected_prefixes = (
        "FusionProV5/ProductionArchitecture/", "FusionProV5/SignalEngine/",
        "FusionProV5/DecisionEngine/", "FusionProV5/Engines/", "FusionProV5/Dashboard/",
        "FusionProV5/Tests/Sprint5PhaseB/", "FusionProV5/Tests/Sprint5PhaseC/",
        "FusionProV5/Tests/Sprint5PhaseD/", "FusionProV5/Tests/Sprint5PhaseE/",
    )
    failures += [f"protected-change:{path}" for path in changed if path.startswith(protected_prefixes)]
    checks = len(REQUIRED) + len(MUTATION_IDS) + len(FORBIDDEN) * len(code_files) + 2
    print(f"PHASE_F_PATCH_SOURCE|checks={checks}|failures={len(failures)}|digest_domains={len(domains)}")
    for failure in failures:
        print(f"FAIL|{failure}")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
