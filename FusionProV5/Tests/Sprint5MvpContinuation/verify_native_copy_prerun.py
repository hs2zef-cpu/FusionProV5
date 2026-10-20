"""TEST ONLY: read-only pre-run audit. Never launches MT5 or executes an EA.

SQLite is opened URI mode=ro&immutable=1 with query_only=ON. Negative tests
evaluate the source-extracted early refusal predicate with I/O-denying stubs;
they are isolated Python guard evidence, NOT native MQL execution evidence.
"""
from pathlib import Path
import ast
import hashlib
import json
import re
import sqlite3
import subprocess
from datetime import datetime, timezone, timedelta

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
COMMON = Path(r"C:\Users\Nutthakrit\AppData\Roaming\MetaQuotes\Terminal\Common\Files")
DATA = Path(r"C:\Users\Nutthakrit\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075")
ORIGINAL = COMMON / "fusion_v5_mvp_demo_authority.sqlite"
COPY = COMMON / "TEST_ONLY_MVP_CONTINUATION_3f39a13e0c314df2bcd8452ae9de5e4c.sqlite"
EA = "SW_V5_S5_MVP_CONTINUATION_NATIVE_COPY_ASSERTIONS"
EXPECTED = "BEC62E7435D29D5511A41BF85C74AE443994C5804B3A9574AF90D861FE674EF6"
NAMESPACE = "58408af3c3381470aa50161762e4f1102eec5d214448495a79d732cd31d90d8c"
checks = []


def check(name, condition):
    checks.append({"id": name, "passed": bool(condition)})


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def artifact(path):
    return {"path": str(path), "bytes": path.stat().st_size, "sha256": sha(path)}


def db_artifact(path):
    return artifact(path) | {"wal_present": Path(str(path) + "-wal").exists(),
                             "shm_present": Path(str(path) + "-shm").exists()}


def clean(text):
    return re.sub(r"//[^\n]*|/\*.*?\*/", "", text, flags=re.S)


def delimited(text, start, opening="(", closing=")"):
    depth, quote, escaped = 0, False, False
    for i in range(start, len(text)):
        ch = text[i]
        if quote:
            if escaped:
                escaped = False
            elif ch == "\\":
                escaped = True
            elif ch == '"':
                quote = False
            continue
        if ch == '"':
            quote = True
        elif ch == opening:
            depth += 1
        elif ch == closing:
            depth -= 1
            if depth == 0:
                return text[start + 1:i], i + 1
    raise ValueError("Unbalanced source")


def function(text, name):
    match = re.search(r"\b(?:bool|void|int)\s+" + re.escape(name) + r"\s*\(", text)
    if not match:
        raise ValueError("Missing function " + name)
    _, end = delimited(text, text.index("(", match.start()))
    return delimited(text, text.index("{", end), "{", "}")[0]


def first_if_condition(body):
    match = re.search(r"\bif\s*\(", body)
    return delimited(body, body.index("(", match.start()))[0]


def isolated_guard_tests(harness):
    condition = first_if_condition(function(harness, "NativeCopyGate"))
    expression = re.sub(r"!(?!=)", " not ", condition.replace("||", " or ").replace("&&", " and ")).strip()
    tree = ast.parse("(" + expression + ")", mode="eval")
    permitted = (ast.Expression, ast.BoolOp, ast.Or, ast.And, ast.UnaryOp, ast.Not,
                 ast.Compare, ast.Eq, ast.NotEq, ast.GtE, ast.Call, ast.Name, ast.Load, ast.Constant)
    if any(not isinstance(node, permitted) for node in ast.walk(tree)):
        raise ValueError("Guard expression is outside the isolated evaluator allowlist")
    code = compile(tree, "source-extracted NativeCopyGate early refusal", "eval")
    cases = [("production-filename", ORIGINAL.name, "TEST_ONLY_AUTHORIZED_UNCOMMITTED_DRAFT"),
             ("missing-marker", COPY.name, ""), ("invalid-marker", COPY.name, "PRODUCTION"),
             ("absolute-production-path", str(ORIGINAL), "TEST_ONLY_AUTHORIZED_UNCOMMITTED_DRAFT"),
             ("traversal", "TEST_ONLY_MVP_CONTINUATION_../fusion_v5_mvp_demo_authority.sqlite", "TEST_ONLY_AUTHORIZED_UNCOMMITTED_DRAFT"),
             ("subdirectory", "TEST_ONLY_MVP_CONTINUATION_sub\\fusion_v5_mvp_demo_authority.sqlite", "TEST_ONLY_AUTHORIZED_UNCOMMITTED_DRAFT")]
    results = []
    for name, path, marker in cases:
        io_attempts = []
        def deny_io(*args):
            io_attempts.append("I/O")
            raise AssertionError("Rejected input unexpectedly reached I/O")
        env = {"explicit_test_only_marker": marker, "execute_test_copy_once": True,
               "operator_confirmed_test_copy": True, "expected_initial_copy_sha256": EXPECTED.lower(),
               "expected_copy_sha": EXPECTED.lower(), "initial_copy_relative_path": path,
               "StringFind": lambda value, needle: value.find(needle), "_Symbol": "XAUUSD", "_Period": 15,
               "PERIOD_M15": 15, "MQL_TESTER": 1, "MQLInfoInteger": lambda token: False,
               "SWV5S5_TestContinuationFileSha": deny_io, "FileIsExist": deny_io, "FILE_COMMON": 0, "digest": ""}
        rejected = bool(eval(code, {"__builtins__": {}}, env))
        passed = rejected and not io_attempts
        check("REFUSAL/" + name, passed)
        results.append({"case": name, "rejected_by_actual_source_predicate": rejected,
                        "io_attempts": len(io_attempts), "durable_writes": 0, "passed": passed})
    return {"classification": "ISOLATED_SOURCE_EXTRACTED_PYTHON_GUARD_NOT_MQL_RUNTIME",
            "source_predicate": condition, "cases": results}


def field(name, token, value):
    return f"{name}:{token}:{len(str(value).encode('utf-8'))}:{value}"


def digest(domain, payload):
    return hashlib.sha256((field("domain", "s", domain) + field("body", "x", payload)).encode()).hexdigest()


def decode(payload):
    data = payload.encode("utf-8"); pos = 0; out = {}
    while pos < len(data):
        parts = []
        for _ in range(3):
            end = data.index(b":", pos); parts.append(data[pos:end].decode("ascii")); pos = end + 1
        name, token, size = parts; end = pos + int(size)
        if end > len(data) or name in out:
            raise ValueError("Malformed canonical field")
        value = data[pos:end].decode("utf-8"); pos = end
        if token == "x": value = decode(value)
        elif token in ("u", "i"): value = int(value)
        elif token == "d": value = float(value)
        elif token == "b":
            if value not in ("0", "1"): raise ValueError("Invalid boolean")
            value = value == "1"
        elif token != "s": raise ValueError("Unknown token")
        out[name] = value
    return out


def physical_prestate():
    c = sqlite3.connect(COPY.as_uri() + "?mode=ro&immutable=1", uri=True)
    c.row_factory = sqlite3.Row
    c.execute("PRAGMA query_only=ON")
    try:
        metadata = dict(c.execute("SELECT * FROM swv5_store_metadata").fetchone())
        rows = [dict(r) for r in c.execute("SELECT * FROM swv5_authority_rows ORDER BY domain_key,record_key")]
    finally:
        c.close()
    check("STORE/namespace", metadata["namespace_digest"] == NAMESPACE and all(r["namespace_digest"] == NAMESPACE for r in rows))
    check("STORE/schema", metadata["schema_id"] == "SWV5-S5-STORE-SCHEMA-V1" and metadata["schema_version"] == metadata["minimum_compatible_version"] == 1)
    bykey = {(r["domain_key"], r["record_key"]): r for r in rows}
    for r in rows:
        body = (field("namespace_digest", "s", NAMESPACE) + field("domain_key", "s", r["domain_key"]) +
                field("record_key", "s", r["record_key"]) + field("logical_revision", "u", r["logical_revision"]) +
                field("payload_digest", "s", r["payload_digest"]))
        check("ROW_CAS/" + r["domain_key"] + "/" + r["record_key"], digest("SWV5-S5-MVP-STORE-REVISION-V1", body) == r["store_revision"])
    def row(domain, key="CURRENT"):
        return bykey[domain, key]
    def payload(domain, key="CURRENT"):
        return decode(row(domain, key)["payload"])
    lease = payload("MVP_OWNERSHIP_LEASE", "CURRENT_LEASE")["lease"]
    key = lease["fence"]["ownership_namespace"]
    key_body = (field("account_login", "i", key["account_login"]) + field("broker_identity", "s", key["broker_identity"]) +
                field("server", "s", key["server"]) + field("symbol", "s", key["symbol"]) +
                field("strategy_id", "s", key["strategy_id"]) + field("magic", "u", key["magic"]))
    derived_namespace = digest("SWV5-S5-PHASE-D1-OWNERSHIP-NAMESPACE", field("ownership_namespace", "x", key_body))
    check("STORE/production-derived-canonical-namespace", derived_namespace == NAMESPACE)
    trust_physical = payload("MVP_PRODUCER_TRUST")
    governance = payload("MVP_RECONCILIATION_GOVERNANCE_BUNDLE")
    hard_kill = payload("MVP_HARD_KILL_STATE")["hard_kill"]
    history_row = row("MVP_HARD_KILL_ACTIVATION_HISTORY", hard_kill["latch_id"])
    history = decode(history_row["payload"])
    released = history["release_bundle"]["released"]
    release = history["release_bundle"]["authority"]
    requestset = payload("MVP_EXECUTION_PENDING_STATE", "REQUEST_SET")["view"]
    basket = payload("MVP_CANONICAL_BASKET")
    # Physical typed Trust codec names are checked explicitly, never defaulted.
    trust = trust_physical["record"]
    now = int(datetime.now(timezone.utc).timestamp())
    check("PRESTATE/ownership-expired", now >= lease["expires_at"])
    check("PRESTATE/trust-expired", now >= trust["valid_until"])
    check("PRESTATE/governance-expired", now >= governance["valid_until"])
    check("PRESTATE/release-expired", now >= release["expires_at"])
    hk_row = row("MVP_HARD_KILL_STATE")
    check("PRESTATE/hard-kill-row-digest", digest("MVP_HARD_KILL_STATE", hk_row["payload"]) == hk_row["payload_digest"])
    check("PRESTATE/history-digest", digest(history_row["domain_key"], history_row["payload"]) == history_row["payload_digest"])
    complete = row("MVP_HARD_KILL_COMPLETE_RELEASE", release["authority_record_id"])
    released_scope = released["persistence_namespace"]
    expected_scope = {"version": released_scope["contract_version"], "ownership_namespace": released_scope["ownership_namespace"],
                      "basket_id": released_scope["basket_id"]["value"]}
    expected_account = {("version" if k == "contract_version" else k): v for k, v in released["account_namespace"].items()}
    check("PRESTATE/complete-release-preserved", decode(complete["payload"]) == history["release_bundle"] and
          digest(complete["domain_key"], complete["payload"]) == complete["payload_digest"] and
          complete["logical_revision"] == 1 and complete["state"] == 3)
    check("PRESTATE/inactive-lineage", hard_kill["state"] == hk_row["state"] == 0 and
          hard_kill["latch_id"] == "INACTIVE/" + history_row["payload_digest"] and
          hard_kill["latch_generation"] == released["latch_generation"] + 1 and
          hard_kill["release_generation"] == 0 and hard_kill["activation_reason"] == hard_kill["activation_authority"] == "" and
          hard_kill["release_evidence"]["release_id"] == "" and hard_kill["release_evidence"]["latch_id"] == hard_kill["latch_id"] and
          hard_kill["release_authority_reference"]["authority_record_id"] == "" and
          hk_row["logical_revision"] == history["released_revision"] + 1 and
          hard_kill["scope"] == expected_scope and hard_kill["account"] == expected_account)
    check("PRESTATE/requestset-empty", requestset["requests_count"] == requestset["header"]["request_count"] == 0)
    lifecycle = basket["lifecycle"]
    check("PRESTATE/basket-idle-v1", lifecycle["state"] == 0 and lifecycle["state_version"] == 1 and
          lifecycle["aggregate_open_volume"] == lifecycle["residual_volume"] == basket["initial_volume"] == basket["aggregate_closed_volume"] == 0)
    allowed = {("MVP_ACCOUNT_RISK_AUTHORITY", "CURRENT"), ("MVP_BOOTSTRAP_ZERO_STATE_AUTHORITY", "CURRENT"),
               ("MVP_CANONICAL_BASKET", "CURRENT"), ("MVP_EXECUTION_PENDING_STATE", "REQUEST_SET"),
               ("MVP_HARD_KILL_RELEASE_AUTHORITY", "CURRENT"), ("MVP_HARD_KILL_STATE", "CURRENT"),
               ("MVP_OWNERSHIP_LEASE", "CURRENT_LEASE"), ("MVP_OWNERSHIP_LEASE", "LEASE_CLOCK_CURRENT"),
               ("MVP_PRODUCER_TRUST", "CURRENT"), ("MVP_RECONCILIATION_GOVERNANCE_BUNDLE", "CURRENT")}
    unknown = [(r["domain_key"], r["record_key"]) for r in rows if r["record_key"] != "GENESIS" and
               (r["domain_key"], r["record_key"]) not in allowed and
               r["domain_key"] not in ("MVP_HARD_KILL_ACTIVATION_HISTORY", "MVP_HARD_KILL_COMPLETE_RELEASE")]
    check("PRESTATE/no-operational-or-unknown-rows", not unknown)
    return {"sqlite_open_mode": "mode=ro&immutable=1;query_only=ON", "metadata": metadata, "derived_namespace": derived_namespace, "row_count": len(rows),
            "expiry_assessment_utc_epoch": now, "expiry_context": "READBACK_WALL_CLOCK_NOT_A_NATIVE_MT5_TICK",
            "ownership_expires_at": lease["expires_at"], "trust_valid_until": trust["valid_until"],
            "governance_valid_until": governance["valid_until"], "hard_kill_release_expires_at": release["expires_at"],
            "governance_row_state": row("MVP_RECONCILIATION_GOVERNANCE_BUNDLE")["state"],
            "governance_authority_sequence": governance["sequence"], "hard_kill_state": hard_kill["state"],
            "hard_kill_latch_generation": hard_kill["latch_generation"], "request_count": requestset["requests_count"],
            "basket_state": lifecycle["state"], "basket_state_version": lifecycle["state_version"],
            "operational_rows": unknown, "live_broker_positions_orders": "NOT_OBSERVED_NOT_INFERRED_FROM_SQLITE",
            "inventory": [{k: r[k] for k in ("domain_key", "record_key", "logical_revision", "state", "payload_digest", "store_revision")} for r in rows]}


def source_safety(harness, installed):
    layer = ROOT / "FusionProV5/ExecutionLayer"
    control = layer / "ControlledDemo"
    runtime = layer / "RuntimeAuthority"
    suite = clean((HERE / "SW_V5_S5_MvpContinuationAssertions.mqh").read_text(encoding="utf-8"))
    isolation = clean((HERE / "SW_V5_S5_MvpContinuationTestIsolation.mqh").read_text(encoding="utf-8"))
    runner = clean((control / "SW_V5_S5_MvpControlledDemoRunner.mqh").read_text(encoding="utf-8"))
    host = clean((control / "SW_V5_S5_MvpAttendedLaunch.mqh").read_text(encoding="utf-8"))
    defaults = function(runner, "SWV5S5_MvpControlledDemoDefaults")
    native_preflight = function(suite, "NativePreflight")
    check("ISOLATION/constant-preflight-mode", "invocation.mode=MODE_PREFLIGHT;" in defaults and
          "SWV5S5_MvpControlledDemoDefaults(i);" in native_preflight and not re.search(r"i\.mode\s*=", native_preflight))
    check("ISOLATION/submission-flags-false", all("invocation." + name + "=false;" in defaults for name in
          ("armed_for_demo_submission", "operator_confirmed_before_claim", "execute_attended_once")) and
          not re.search(r"i\.(?:armed_for_demo_submission|operator_confirmed_before_claim|execute_attended_once)\s*=", native_preflight))
    run_body = function(runner, "Run")
    mode_return = run_body.index("if(invocation.mode==MODE_PREFLIGHT)")
    returned_block, _ = delimited(run_body, run_body.index("{", mode_return), "{", "}")
    dangerous = ("PrepareD1AuthorityPath", "PreparePermitSemantics", "CommitPermitPhysical", "CollectAdmissionSameEvent", "ClaimPhysicalNow", "SubmitExactlyOnce")
    check("ISOLATION/preflight-return-dominates-execution", "return m_broker_submission_calls==0;" in returned_block and
          all(run_body.index(name) > mode_return + len(returned_block) for name in dangerous))
    check("ISOLATION/preflight-host-clock-readonly", "clock.ConfigureReadOnly" in host and "builder.LoadBaseForReadOnlyPreflight" in host and
          "if(invocation.mode!=MODE_PREFLIGHT &&" in host and "!evidence.Configure" in host)
    continuation = clean((runtime / "SW_V5_S5_MvpAttendedContinuation.mqh").read_text(encoding="utf-8"))
    continuation_helpers = "\n".join(clean(p.read_text(encoding="utf-8")) for p in runtime.glob("SW_V5_S5_MvpContinuation*.mqh"))
    check("ISOLATION/continuation-no-execution-issuers", not re.search(r"\.\s*(?:PrepareD1AuthorityPath|CommitPermitPhysical|CollectAdmissionSameEvent|ClaimPhysicalNow|SubmitExactlyOnce|ReserveNext|AcceptIngress)\s*\(", continuation + continuation_helpers))
    check("ISOLATION/native-transport-compile-trap", "#define OrderSend FUSION_TEST_ONLY_FORBIDDEN_SEND" in isolation and
          "#define OrderSendAsync FUSION_TEST_ONLY_FORBIDDEN_SEND" in isolation and
          harness.index('#include "SW_V5_S5_MvpContinuationTestIsolation.mqh"') < harness.index('SW_V5_S5_MvpAttendedLaunch.mqh') and
          "test_forbidden_transport_calls++" in isolation and "return false;" in function(isolation, "FUSION_TEST_ONLY_FORBIDDEN_SEND"))
    def executable(text):
        return re.sub(r'"(?:\\.|[^"\\])*"', '""', clean(text))
    sends, heartbeats = [], []
    for p in (ROOT / "FusionProV5").rglob("*"):
        if p.suffix not in (".mqh", ".mq5") or "Tests" in p.parts:
            continue
        code = executable(p.read_text(encoding="utf-8-sig"))
        for match in re.finditer(r"\bOrderSend\s*\(", code):
            sends.append({"path": str(p), "line": code[:match.start()].count("\n") + 1})
        for match in re.finditer(r"\.\s*HeartbeatAttended\s*\(", code):
            heartbeats.append({"path": str(p), "line": code[:match.start()].count("\n") + 1})
    check("ISOLATION/exactly-one-production-OrderSend", len(sends) == 1)
    if len(sends) == 1:
        rel = Path(sends[0]["path"]).relative_to(ROOT).as_posix()
        original = subprocess.check_output(["git", "show", "d926f2e6b1aa4ea7b4b0936293d2fa47a2ce7ba8:" + rel], cwd=ROOT).decode("utf-8")
        current = Path(sends[0]["path"]).read_text(encoding="utf-8")
        check("ISOLATION/production-send-site-unchanged", original.replace("\r\n", "\n") == current.replace("\r\n", "\n"))
    check("ISOLATION/exactly-one-attended-heartbeat-caller", len(heartbeats) == 1 and "MvpAttendedContinuation.mqh" in heartbeats[0]["path"])
    init = function(harness, "OnInit"); tick = function(harness, "OnTick"); callback = function(harness, "OnChartEvent")
    gate = function(harness, "NativeCopyGate")
    check("ONESHOT/attach-and-preset-readonly", "native_test_ack=false" in init and "test_live_native_copy_armed=false" in init and
          "test_suite.Start" not in init and "copy.OpenReadOnly" in gate and
          not re.search(r"\b(?:Configure|Open|CompareAndSet|Execute|Run|ObserveFromCurrentSymbolOnTick|FileDelete)\s*\(", init + gate))
    check("ONESHOT/ack-required-before-start", tick.index("if(!native_test_ack)return;") < tick.index("test_suite.Start();"))
    check("ONESHOT/consume-before-first-test-write", tick.index("native_test_consumed=true;") < tick.index("test_live_native_copy_armed=true;") < tick.index("test_suite.Start();"))
    check("ONESHOT/no-reset-or-retry", "native_test_consumed=false" not in tick + callback and "OnTimer" not in harness and
          tick.count("test_suite.Start();") == 1 and "if(native_test_finished)return;" in tick)
    # Evaluate the actual keydown guard, with the read-only profile/path gate stubbed true.
    key_condition = first_if_condition(callback)
    expression = re.sub(r"!(?!=)", " not ", key_condition.replace("&&", " and ").replace("||", " or "))
    key_code = compile(ast.parse("(" + expression + ")", mode="eval"), "source-extracted A latch guard", "eval")
    state = {"id": 1, "CHARTEVENT_KEYDOWN": 1, "lparam": 65, "native_test_consumed": False, "native_test_ack": False, "NativeCopyGate": lambda: True}
    first = bool(eval(key_code, {"__builtins__": {}}, state)); state["native_test_ack"] = True
    duplicate_before_tick = bool(eval(key_code, {"__builtins__": {}}, state))
    state["native_test_consumed"] = True; state["native_test_ack"] = False
    duplicate_after_tick = bool(eval(key_code, {"__builtins__": {}}, state))
    check("ONESHOT/isolated-first-A-only", first and not duplicate_before_tick and not duplicate_after_tick)
    # Prove the installed artifact is not older than any quoted repo include.
    seen = {}; pending = [HERE / (EA + ".mq5")]
    while pending:
        path = pending.pop().resolve()
        if path in seen:
            continue
        raw = path.read_text(encoding="utf-8-sig"); seen[path] = sha(path)
        for include in re.findall(r'^\s*#include\s+"([^"]+)"', raw, flags=re.M):
            pending.append((path.parent / include).resolve())
    check("PROVENANCE/compiled-not-older-than-includes", all(p.stat().st_mtime <= installed.stat().st_mtime for p in seen))
    check("ISOLATION/no-native-callback-or-timer-entry", "OnTradeTransaction(" not in harness and "OnTimer(" not in harness)
    return {"classification": "STATIC_FIXED_MODE_CALL_PATH_AND_PREPROCESSOR_ISOLATION_NOT_LIVE_EXECUTION",
            "production_OrderSend_sites": sends, "production_Heartbeat_callers": heartbeats,
            "reachable_entry_chain": ["OnTick + A", "test_suite.Start", "continuation administrative functions", "NativePreflight MODE_PREFLIGHT", "runner early return"],
            "unreachable_execution_methods": list(dangerous),
            "one_shot_scope": "One EA attachment; reinitialization resets the in-memory latch. No durable across-reattach lock is claimed.",
            "operational_negative_fixtures": "Synthetic invalid row-presence fixtures in separate TEST_ONLY clones; not D1/Ledger/Permit/Admission/Claim issuers.",
            "include_count": len(seen), "source_digest": hashlib.sha256("\n".join(str(p.relative_to(ROOT)) + "=" + seen[p] for p in sorted(seen)).encode()).hexdigest()}


def main():
    evidence = {"classification": "PRE_RUN_ONLY_NOT_NATIVE_EXECUTION", "time_bangkok": datetime.now(timezone(timedelta(hours=7))).isoformat()}
    before = {"original": db_artifact(ORIGINAL), "test_copy": db_artifact(COPY)}
    check("DB/original-exact-hash", before["original"]["sha256"] == EXPECTED)
    check("DB/copy-exact-hash", before["test_copy"]["sha256"] == EXPECTED and COPY.name != ORIGINAL.name)
    check("DB/no-sidecars", not any(before[name][key] for name in before for key in ("wal_present", "shm_present")))
    harness = clean((HERE / (EA + ".mq5")).read_text(encoding="utf-8"))
    evidence["guard_tests"] = isolated_guard_tests(harness)
    evidence["prestate"] = physical_prestate()
    preset = DATA / "MQL5/Presets" / (COPY.name + ".set")
    inputs = dict(line.split("=", 1) for line in preset.read_text(encoding="utf-16").splitlines() if "=" in line)
    check("PRESET/exact-copy-target", inputs["initial_copy_relative_path"] == COPY.name)
    check("PRESET/explicit-marker", inputs["explicit_test_only_marker"] == "TEST_ONLY_AUTHORIZED_UNCOMMITTED_DRAFT")
    check("PRESET/exact-sha", inputs["expected_initial_copy_sha256"] == EXPECTED.lower())
    check("PRESET/explicit-test-intent", inputs["execute_test_copy_once"] == inputs["operator_confirmed_test_copy"] == "true")
    source = HERE / (EA + ".mq5"); built = HERE / (EA + ".ex5"); installed = DATA / "MQL5/Experts/FusionProV5Tests" / (EA + ".ex5")
    log = HERE / (EA + ".log")
    result = re.findall(r"^Result:.*", log.read_text(encoding="utf-16"), flags=re.M)[-1]
    check("COMPILE/x64-regular-zero-errors-warnings", bool(re.fullmatch(r"Result: 0 errors, 0 warnings, .*cpu='X64 Regular'", result)))
    check("BINARY/installed-identical", sha(built) == sha(installed))
    evidence["harness"] = {"source": artifact(source), "compiled": artifact(built), "installed": artifact(installed), "compile_log": artifact(log), "compile_result": result}
    evidence["source_safety"] = source_safety(harness, installed)
    evidence["preset"] = artifact(preset) | {"inputs": inputs, "fixture_input_path": str(COPY), "main_mutation_target_if_authorized": str(COPY) + ".MAIN.sqlite",
                                            "other_targets_if_authorized": "Unique-copy-name .GOV_CLOCK/.HB_NEGATIVES/.OP_n/.BOUND_*/.NEG_n/.RESUME_* test fixtures"}
    evidence["database_before"] = before
    evidence["database_after"] = {"original": db_artifact(ORIGINAL), "test_copy": db_artifact(COPY)}
    check("DB/exact-before-after", evidence["database_before"] == evidence["database_after"])
    evidence["git"] = {name: subprocess.check_output(["git", *args], cwd=ROOT, text=True).strip() for name, args in
                       [("branch", ["branch", "--show-current"]), ("HEAD", ["rev-parse", "HEAD"]), ("tree", ["rev-parse", "HEAD^{tree}"]),
                        ("main", ["rev-parse", "main"]), ("status", ["status", "--short"])]}
    diff = subprocess.run(["git", "diff", "--check"], cwd=ROOT, capture_output=True, text=True)
    check("GIT/diff-check", diff.returncode == 0)
    evidence["checks"] = checks
    evidence["summary"] = {"total": len(checks), "passed": sum(r["passed"] for r in checks), "failed": sum(not r["passed"] for r in checks), "native_tests_executed": 0}
    print(json.dumps(evidence, indent=2))
    return int(any(not r["passed"] for r in checks))


if __name__ == "__main__":
    raise SystemExit(main())
