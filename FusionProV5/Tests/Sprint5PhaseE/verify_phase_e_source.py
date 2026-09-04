"""TEST ONLY / NOT FOR PRODUCTION / NO BROKER ACCESS. Offline source audit."""
import json
import re
from pathlib import Path

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]

def verify():
    fixtures=(HERE/"SW_V5_S5_PhaseE_Fixtures.mqh").read_text(encoding="utf-8-sig")
    assertions=(HERE/"SW_V5_S5_PhaseE_Assertions.mqh").read_text(encoding="utf-8-sig")
    contract=(HERE/"FIXTURE_CONTRACT.md").read_text(encoding="utf-8-sig")
    mutations=(HERE/"verify_phase_e_mutation_controls.py").read_text(encoding="utf-8-sig")
    isolation=(HERE/"verify_phase_e_isolation.py").read_text(encoding="utf-8-sig")
    mutation_matrix=(HERE/"NEGATIVE_CONTROL_MATRIX.md").read_text(encoding="utf-8-sig")
    broker=(ROOT/"Tests/Sprint5PhaseC/SW_V5_S5_PhaseC_TestDoubles.mqh").read_text(encoding="utf-8-sig")
    assert "SWV5S5_D1Restart(ca,hybrid,ra,ga,la,out)" in fixtures
    assert fixtures.count("SWV5S5_D1PositiveRestartSafeToResume") >= 3
    assert "hybrid.persisted=b.persisted" in fixtures
    assert "fixture-only validator" not in fixtures.lower()
    assert "ArrayResize(invocations,n+1)" in broker and "invocations[n]=invocation" in broker
    assert "Deliberately empty" in assertions and "void SWV5S5_RunPhaseECompileOnlyAssertions(void) {}" in assertions
    mutation_ids=("MC-P","MC-JOINT","MC-DOMAIN","MC-OWNERSHIP-LOGICAL",
                  "MC-OWNERSHIP-DURABLE","MC-GRANT","MC-BROKER-DEDUPE",
                  "MC-STALE-CAS-EQUALITY")
    assert all(f'"{control_id}"' in mutations for control_id in mutation_ids)
    assert all(f'`{control_id}`' in mutation_matrix for control_id in mutation_ids)
    assert "unsafe_result_observed" in mutations and "target_assertion_detected" in mutations
    assert "if mutant_enabled" not in mutations and "NEGATIVE_CONTROL_DETECTED" not in mutations
    assert "production_reverse_dependencies" in isolation and "transitive_file_count" in isolation
    for pin in ("31e76411829e2f2e6acb24740ddca32b886969e0","1366edb25238463c9a76fa78257196dbf4c64e34",
                "55cd230ca222c60cd42dd218efe5e175ba70acd6","f0434d0e84907b1d454deec0abb899c16b35cd35"):
        assert pin in contract
    combined=fixtures+assertions
    positives=sorted(set(re.findall(r"bool (SWV5S5_EPositive\w+)\(",combined)))
    negatives=sorted(set(re.findall(r"bool (SWV5S5_ENegative\w+)\(",combined)))
    semantic=sorted(set(re.findall(r"bool (SWV5S5_ESemantic\w+)\(",combined)))
    helpers=sorted(set(re.findall(r"bool (SWV5S5_E_(?:Run|Stop)\w+)\(",combined)))
    forbidden=re.findall(r"\b(?:Database\w*|GlobalVariable\w*|FileOpen|OrderSend(?:Async)?|CTrade|PositionGet\w*|PositionSelect\w*|OrderGet\w*|HistoryOrder\w*|HistoryDeal\w*|AccountInfo\w*|SymbolInfo\w*|TimeCurrent|TimeTradeServer|TimeLocal|WebRequest|Socket\w*|OnTick|OnTimer|OnTradeTransaction)\s*\(",re.sub(r"//[^\n]*|\"(?:\\.|[^\"\\])*\"","",combined))
    assert not forbidden
    return {"status":"PASS","mql_executed":False,"positive_functions":len(positives),
            "negative_functions":len(negatives),"semantic_functions":len(semantic),
            "semantic_resealed_functions":len(negatives)-1+len(semantic),
            "checksum_only_functions":1,"non_proving_helper_functions":len(helpers)+1,
            "p11_existing_restart_path":True,"forbidden_matches":len(forbidden),
            "mutation_control_definitions":len(mutation_ids),
            "positive_names":positives,"negative_names":negatives,"semantic_names":semantic}

if __name__=="__main__": print(json.dumps(verify(),sort_keys=True,separators=(",",":")))
