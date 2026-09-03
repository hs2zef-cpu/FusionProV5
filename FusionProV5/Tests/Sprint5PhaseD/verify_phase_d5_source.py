"""TEST ONLY / NOT FOR PRODUCTION / NO BROKER ACCESS.
Offline source checks and conservative assertion inventory, NOT MQL execution.
"""
import json
import re
from pathlib import Path
from frozen_dto_digest import SOURCE, canonical_field, frozen, version, canonical_hash

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent


def verify():
    assertions = (HERE / "SW_V5_S5_PhaseD_Assertions.mqh").read_text(encoding="utf-8-sig")
    fixtures = (HERE / "SW_V5_S5_PhaseD5_Fixtures.mqh").read_text(encoding="utf-8-sig")
    reference = ROOT / "FusionProV5/ExecutionLayer/PersistenceReference"
    restart = (reference / "SW_V5_S5_ReferenceRestart.mqh").read_text(encoding="utf-8-sig")
    integrity = (reference / "SW_V5_S5_ReferenceProductionIntegrity.mqh").read_text(encoding="utf-8-sig")
    lease = (reference / "SW_V5_S5_ReferenceLeaseStore.mqh").read_text(encoding="utf-8-sig")
    assert "SWV5_TestExecutionVersionExact(context,restart_input.contract_version)" in restart
    assert "IsCandidateVersion(restart_input.contract_version)" not in restart
    for helper in ("SWV5_TestCheckpointPayloadDigest", "SWV5_TestReconciliationSourceDigest", "SWV5_TestHardKillReleaseDigest"):
        assert helper in integrity
    assert "SWV5_TestHardKillAuthorityRecordDigest(record)" in restart
    assert "IsDigest64Lower" not in integrity + restart
    assert "!SWV5_TestFenceComplete(m_lease.fence)" in lease
    assert "!SWV5_TestFenceComplete(claim.expected_fence)" in lease
    assert "!SWV5_TestFenceComplete(result.fence)" in lease[lease.index("bool Takeover("):]
    compact = re.sub(r"\s+", "", SOURCE)
    for statement in ("ulonghash=1469598103934665603;", "hash^=(ulong)StringGetCharacter(value,index);",
                      "hash*=1099511628211;", 'returnStringFormat("%I64u",hash);'):
        assert statement in compact
    # Known independent field envelope, including MQL UTF-16 length semantics.
    assert canonical_field("sample", "s", "A😀") == "sample:s:3:A😀"
    expected = "contract_name:s:15:SWV5-PRODUCTIONschema_version:i:1:5minimum_compatible_version:i:1:5policy_id:s:18:SWV5-PRODUCTION-V5"
    # Literal lengths are checked here, never obtained from the implementation under test.
    assert frozen("SWV5_TestCanonicalVersion", version()) == expected
    assert canonical_hash("") == "1469598103934665603"
    for helper in ("SWV5_TestCanonicalHardKillReleaseDigestPreimage", "SWV5_TestCanonicalHardKillAuthorityRecordDigestPreimage",
                   "SWV5_TestCanonicalReconciliationVector", "SWV5_TestCanonicalCheckpointDigestPreimage"):
        # A supplied field mutation changes the actual frozen preimage/hash.
        base = {"release_id": "A", "source_summary_digest": "A", "header": {"store_revision": "A"}}
        changed = {"release_id": "B", "source_summary_digest": "B", "header": {"store_revision": "B"}}
        assert canonical_hash(frozen(helper, base)) != canonical_hash(frozen(helper, changed))
    affected = set(re.findall(r"bool (SWV5S5_D[1-4]Negative\w+)\([^{}]*SWV5_RestartReconciliationInput[^{}]*\{", assertions))
    matrix = fixtures[fixtures.index("bool SWV5S5_D5AffectedRestartProbeMatrix"):]
    invoked = set(re.findall(r"if\(!([A-Za-z0-9_]+Negative\w+)\(c,x,r,g,l\)\) failed\+\+;", matrix))
    assert len(affected) == 79 and invoked == affected
    assert "Deliberately empty" in assertions
    positives = set(re.findall(r"bool (SWV5S5_D\dPositive\w+)\(", assertions + fixtures))
    negatives = set(re.findall(r"bool (SWV5S5_D\dNegative\w+)\(", assertions + fixtures))
    new_negatives = {name for name in negatives if name.startswith("SWV5S5_D5")}
    assert len(new_negatives) == 16
    old_checksum = {"SWV5S5_D1NegativeRestartCorruptBrokerDigest", "SWV5S5_D1NegativeRestartCorruptExecutionDigest",
                    "SWV5S5_D1NegativeRestartInvalidReleaseDigest", "SWV5S5_D3NegativeRestartWrongProductionPayload",
                    "SWV5S5_D3NegativePersistedReleaseDigest"}
    new_checksum = {name for name in new_negatives if name.endswith(("Sha256", "Numeric"))}
    credited = affected | new_negatives
    checksum = old_checksum | new_checksum
    return dict(status="PASS", mql_executed=False, positive_functions=len(positives), negative_functions=len(negatives),
                affected_restart_functions=len(affected), source_reviewed_semantic_functions=len(credited - checksum),
                checksum_only_functions=len(checksum), uncredited_non_proving_functions=len(negatives - credited),
                uncredited_names=sorted(negatives - credited),
                note="Counts are source-review credit, NOT executed MQL results; unrelated parameterized probes are not credited by this narrow D.5 review.")


if __name__ == "__main__":
    print(json.dumps(verify(), sort_keys=True, separators=(",", ":")))
