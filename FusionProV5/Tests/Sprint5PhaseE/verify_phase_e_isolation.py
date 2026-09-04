"""TEST ONLY / NOT FOR PRODUCTION / NO BROKER ACCESS. Static include/API scan."""
from __future__ import annotations

import json
from pathlib import Path
import re


HERE = Path(__file__).resolve().parent
MQL_ROOT = HERE.parents[1]
MANIFESTS = (
    HERE / "SW_V5_S5_PHASE_E_COMPILE.mq5",
    HERE / "SW_V5_S5_PHASE_E_ASSERTIONS.mq5",
    MQL_ROOT / "Tests/Sprint5PhaseD/SW_V5_S5_PHASE_D_COMPILE.mq5",
    MQL_ROOT / "Tests/Sprint5PhaseD/SW_V5_S5_PHASE_D_ASSERTIONS.mq5",
    MQL_ROOT / "Tests/Sprint5PhaseC/SW_V5_S5_PHASE_C_COMPILE.mq5",
    MQL_ROOT / "Tests/Sprint5PhaseC/SW_V5_S5_PHASE_C_ASSERTIONS.mq5",
    MQL_ROOT / "Tests/Sprint5PhaseB/SW_V5_S5_PHASE_B_COMPILE.mq5",
    MQL_ROOT / "Tests/Sprint5PhaseB/SW_V5_S5_PHASE_B_ASSERTIONS.mq5",
)

INCLUDE = re.compile(r'^\s*#include\s+"([^"]+)"', re.MULTILINE)
FORBIDDEN = re.compile(
    r"\b(?:DatabaseOpen|DatabaseClose|DatabaseExecute|DatabasePrepare|DatabaseRead|"
    r"DatabaseTransactionBegin|DatabaseTransactionCommit|DatabaseTransactionRollback|"
    r"GlobalVariable\w*|FileOpen|OrderSend|OrderSendAsync|CTrade|PositionGet\w*|"
    r"PositionSelect\w*|OrderGet\w*|HistoryOrder\w*|HistoryDeal\w*|AccountInfo\w*|"
    r"SymbolInfo\w*|TimeCurrent|TimeTradeServer|TimeLocal|WebRequest|Socket\w*|"
    r"OnTick|OnTimer|OnTradeTransaction)\s*\("
)
FORBIDDEN_DEPENDENCY_PARTS = ("Signal", "DecisionEngine", "Engines", "Dashboard", "V3S")


def _code_only(text: str) -> str:
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.DOTALL)
    text = re.sub(r"//[^\n]*", "", text)
    return re.sub(r'"(?:\\.|[^"\\])*"', '""', text)


def _closure() -> tuple[set[Path], list[str]]:
    found: set[Path] = set()
    missing: list[str] = []
    pending = list(MANIFESTS)
    while pending:
        path = pending.pop().resolve()
        if path in found:
            continue
        if not path.is_file():
            missing.append(str(path))
            continue
        found.add(path)
        text = path.read_text(encoding="utf-8-sig")
        for raw in INCLUDE.findall(text):
            included = (path.parent / raw.replace("\\", "/")).resolve()
            pending.append(included)
    return found, missing


def verify() -> dict:
    closure, missing = _closure()
    forbidden_matches: list[str] = []
    forbidden_dependencies: list[str] = []
    for path in sorted(closure):
        relative = path.relative_to(MQL_ROOT).as_posix()
        code = _code_only(path.read_text(encoding="utf-8-sig"))
        forbidden_matches.extend(f"{relative}:{match.group(0)}" for match in FORBIDDEN.finditer(code))
        segments = relative.lower().split("/")
        if any(part.lower() in segment for part in FORBIDDEN_DEPENDENCY_PARTS for segment in segments):
            forbidden_dependencies.append(relative)

    production_reverse_dependencies: list[str] = []
    for path in MQL_ROOT.rglob("*"):
        if path.suffix.lower() not in {".mq5", ".mqh"} or "Tests" in path.parts:
            continue
        text = path.read_text(encoding="utf-8-sig")
        if "Sprint5PhaseE" in text or "PhaseE_Fixtures" in text:
            production_reverse_dependencies.append(path.relative_to(MQL_ROOT).as_posix())

    passed = not missing and not forbidden_matches and not forbidden_dependencies and not production_reverse_dependencies
    return {
        "status": "PASS" if passed else "FAIL",
        "manifest_count": len(MANIFESTS),
        "transitive_file_count": len(closure),
        "missing_includes": missing,
        "forbidden_api_matches": forbidden_matches,
        "forbidden_dependency_paths": forbidden_dependencies,
        "production_reverse_dependencies": production_reverse_dependencies,
    }


if __name__ == "__main__":
    result = verify()
    print(json.dumps(result, sort_keys=True, separators=(",", ":")))
    if result["status"] != "PASS":
        raise SystemExit(1)
