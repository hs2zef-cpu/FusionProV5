"""TEST ONLY / NOT FOR PRODUCTION / NO BROKER ACCESS.

Offline, source-derived serializer for the four frozen Production digest fields.
This interprets ONLY pure canonical string expressions, not MQL assertions or
runtime code. Unknown syntax fails closed. The old oracle's reduced objects are
explicitly projected to DTO fields; unspecified DTO members are zero-initialized.
No JSON/SHA substitution is used for these four Production digest fields.
"""
from __future__ import annotations
import ast
import copy
import re
from functools import lru_cache
from pathlib import Path

FIXTURES = Path(__file__).resolve().parents[1] / "ContractVerification/SW_V5_TestFixtures.mqh"
SOURCE = re.sub(r"//[^\n]*", "", FIXTURES.read_text(encoding="utf-8-sig"))
PRODUCTION = Path(__file__).resolve().parents[2] / "ProductionArchitecture"
ENUMS = {}
for path in PRODUCTION.glob("*.mqh"):
    source = re.sub(r"//[^\n]*", "", path.read_text(encoding="utf-8-sig"))
    for block in re.findall(r"enum\s+\w+\s*\{([^}]+)\}", source):
        current = -1
        for entry in block.split(","):
            match = re.fullmatch(r"\s*(\w+)\s*(?:=\s*(\d+))?\s*", entry)
            if match:
                current = int(match[2]) if match[2] else current + 1
                ENUMS[match[1]] = current


def u16len(value):
    return len(value.encode("utf-16-le", errors="surrogatepass")) // 2


def canonical_hash(value):
    raw = value.encode("utf-16-le", errors="surrogatepass")
    result = 1469598103934665603  # Exact frozen offset (not standard FNV offset).
    for i in range(0, len(raw), 2):
        result = ((result ^ (raw[i] | (raw[i + 1] << 8))) * 1099511628211) & ((1 << 64) - 1)
    return str(result)


def scalar(value, default):
    return default if value is None else value


def canonical_field(name, kind, value):
    value = str(scalar(value, ""))
    return f"{name}:{kind}:{u16len(value)}:{value}"


@lru_cache(maxsize=None)
def expression(text):
    text = re.sub(r"\((?:long|ulong|datetime|uint|int)\)", "", text)
    return ast.parse(" ".join(text.split()), mode="eval").body


def evaluate(node, env):
    if isinstance(node, ast.Constant): return node.value
    if isinstance(node, ast.Name): return env[node.id]
    if isinstance(node, ast.Attribute):
        value = evaluate(node.value, env)
        return value.get(node.attr) if isinstance(value, dict) else None
    if isinstance(node, ast.BinOp) and isinstance(node.op, ast.Add):
        return evaluate(node.left, env) + evaluate(node.right, env)
    if isinstance(node, ast.Call) and isinstance(node.func, ast.Name) and not node.keywords:
        return frozen(node.func.id, *(evaluate(arg, env) for arg in node.args))
    raise ValueError(f"Unsupported frozen expression: {ast.dump(node)}")


@lru_cache(maxsize=None)
def body(name):
    match = re.search(r"string\s+" + re.escape(name) + r"\(([^{};]*)\)\s*\{([^{}]*)\}", SOURCE)
    if not match: raise ValueError(f"No supported frozen function {name}")
    parameters = [re.search(r"(\w+)\s*$", part)[1] for part in match[1].split(",")]
    return parameters, [part.strip() for part in match[2].split(";") if part.strip()]


def frozen(name, *args):
    if name == "SWV5_TestCanonicalHash": return canonical_hash(args[0])
    if name == "SWV5_TestCanonicalField": return canonical_field(*args)
    primitives = {"Integer": "i", "Unsigned": "u", "Double": "d", "Bool": "b"}
    for suffix, kind in primitives.items():
        if name == f"SWV5_TestCanonical{suffix}Field":
            key, value = args; value = scalar(value, 0)
            if kind == "d":
                value = float(value); value = 0.0 if abs(value) < 0.00000000000000005 else value
                text = format(value, ".16f")
            elif kind == "b": text = "1" if value else "0"
            elif kind == "u": text = str(int(value) & ((1 << 64) - 1))
            else: text = str(int(value))
            return canonical_field(key, kind, text)
    parameters, statements = body(name)
    if len(parameters) != len(args): raise ValueError("Frozen arity mismatch")
    env = dict(zip(parameters, args))
    for statement in statements:
        if statement.startswith("return "): return evaluate(expression(statement[7:]), env)
        assignment = re.fullmatch(r"string\s+(\w+)\s*=\s*(.+)", statement, re.S)
        if not assignment: raise ValueError(f"Unsupported frozen statement in {name}: {statement}")
        env[assignment[1]] = evaluate(expression(assignment[2]), env)
    raise ValueError("Missing frozen return")


def version(schema=5):
    if isinstance(schema, dict): return copy.deepcopy(schema)
    return dict(contract_name="SWV5-PRODUCTION", schema_version=schema,
                minimum_compatible_version=5, policy_id="SWV5-PRODUCTION-V5")


def enum(prefix, value, aliases=None):
    if isinstance(value, int): return value
    value = (aliases or {}).get(value, value)
    if value is None: return 0
    if value == "INVALID": return 999  # Explicit adversarial enum cast in MQL probes.
    return ENUMS[prefix + value]


def namespace(value):
    if isinstance(value, dict): return copy.deepcopy(value)
    return dict(contract_version=version(), ownership_namespace=dict(account_login=10001,
                broker_identity="BROKER-DEMO", server="SERVER-DEMO", symbol="XAUUSD", strategy_id="FUSION-PRO-V5",
                magic=550015), basket_id=dict(value="BASKET-XAU-M15" if value=="NS" else scalar(value, "")))


def fence_dto(token):
    if isinstance(token, dict): return copy.deepcopy(token)
    key = namespace("NS")["ownership_namespace"]
    return dict(contract_version=version(), ownership_namespace=key, owner=dict(key=key,
                instance_id="OWNER-A", process_fingerprint="PROCESS-A", started_at=1),
                lease_version=1, takeover_generation=1, fencing_token_digest=token)


def account(value):
    return {**value, "contract_version": version(value.get("contract_version", 5)),
            "broker_identity": value.get("broker"), "account_currency": value.get("currency"),
            "strategy_id": value.get("strategy"), "account_mode": enum("SWV5_ACCOUNT_MODE_", value.get("account_mode")),
            "authoritative_source": enum("SWV5_AUTHORITY_", value.get("source"), {"BROKER": "LIVE_BROKER_STATE"})}


def typed(value, exposure=False):
    result = {**value, "contract_version": version(value.get("contract_version", 5)),
              "evidence_id": value.get("id", value.get("evidence_id")),
              "evidence_sequence": value.get("sequence", value.get("evidence_sequence")),
              "persistence_namespace": namespace(value.get("namespace")),
              "issuing_component": enum("SWV5_COMPONENT_AUTHORITY_", value.get("component"), {"BROKER": "BROKER_ADAPTER"}),
              "authority_source": enum("SWV5_AUTHORITY_", value.get("source"), {"BROKER": "LIVE_BROKER_STATE", "PERSISTENCE": "PERSISTED_CHECKPOINT"})}
    if exposure:
        result.update(observed_exposure_volume=value.get("observed_exposure"), prior_exposure_volume=value.get("prior_exposure"))
    return result


def release_dto(value, authority=False):
    result = {**value, "contract_version": version(value.get("contract_version", 5)),
              "persistence_namespace": namespace(value.get("namespace")),
              "operator_identity": {k: value.get(k) for k in ("operator_id", "authority_role", "authentication_reference", "authenticated_at")},
              "approving_component": enum("SWV5_COMPONENT_AUTHORITY_", value.get("approving_component"))}
    for kind in ("broker", "persistence", "exposure"):
        result[kind + "_evidence" + ("_reference" if authority else "")] = typed(value.get(kind + "_evidence", {}), kind == "exposure")
    if authority:
        result.update(account_namespace=account(value.get("account_namespace", {})),
                      issuing_component=enum("SWV5_COMPONENT_AUTHORITY_", value.get("issuing_component")),
                      authority_source=enum("SWV5_AUTHORITY_", value.get("authority_source")))
    return result


def release_digest(value, authority=False):
    helper = "SWV5_TestHardKillAuthorityRecordDigest" if authority else "SWV5_TestHardKillReleaseDigest"
    return frozen(helper, release_dto(value, authority))


def correlation(value):
    value = value if isinstance(value, dict) else {}
    identity = value.get("broker_identity", {})
    return dict(contract_version=version(), phase=enum("SWV5_EXECUTION_PHASE_", "AUTHORITATIVE_CONFIRMATION" if value else "INTENT"),
                request_identity=dict(contract_version=version(), request_id=dict(correlation_id=value.get("id"))),
                broker_identity={**identity, "contract_version": version()})


def vector_dto(value):
    return {**value, "contract_version": version(value.get("contract_version", 5)),
            "persistence_namespace": namespace(value.get("namespace")), "basket_id": dict(value=value.get("basket")),
            "account_mode": enum("SWV5_ACCOUNT_MODE_", value.get("account_mode")),
            "pending_request_count": value.get("pending_count"), "latest_confirmed_correlation": correlation(value.get("correlation")),
            "latest_broker_event_identity": {**(value.get("broker_identity") or {}), "contract_version": version()},
            "transaction_high_watermark": value.get("transaction_hwm"), "broker_query_sequence_high_watermark": value.get("broker_query_hwm"),
            "request_query_sequence_high_watermark": value.get("execution_query_hwm"),
            "basket_state": enum("SWV5_BASKET_", value.get("basket_state")), "ownership_fence": fence_dto(value.get("fence")),
            "request_set_revision": str(value.get("request_set_revision", ""))}


def vector_digest(value):
    dto = vector_dto(value); dto["source_summary_digest"] = ""
    return canonical_hash(canonical_field("format", "s", "SWV5-RECONCILIATION-SOURCE-V5-LP1") +
                          frozen("SWV5_TestCanonicalReconciliationVector", dto))


def checkpoint_dto(value):
    header = value["header"]; basket = value.get("basket", {}); kill = value.get("hard_kill", {})
    request_set = value.get("request_set", {}); vector = value.get("vector", {})
    lifecycle = {**basket, "contract_version": version(basket.get("contract_version", 5)),
                 "basket_id": dict(value=basket.get("basket")), "ownership_fence": fence_dto(header.get("fence")),
                 "state": enum("SWV5_BASKET_", basket.get("state")),
                 "reconciliation_state": enum("SWV5_RECONCILIATION_STATE_", basket.get("reconciliation_state")),
                 "live_position_count": basket.get("position_count"), "live_order_count": basket.get("order_count"),
                 "pending_request_count": basket.get("pending_count")}
    return {"header": {**header, "contract_version": version(header.get("contract_version", 5)),
                       "persistence_namespace": namespace(header.get("namespace")), "ownership_fence": fence_dto(header.get("fence")),
                       "store_revision": str(header.get("store_revision", ""))},
            "basket": {**basket, "contract_version": version(basket.get("contract_version", 5)),
                       "persistence_namespace": namespace(basket.get("namespace")), "lifecycle": lifecycle,
                       "account_mode": enum("SWV5_ACCOUNT_MODE_", basket.get("account_mode")),
                       "close_verification": enum("SWV5_CLOSE_", basket.get("close_verification"), {"NOT_CONFIRMED": "NOT_REQUESTED"})},
            "last_confirmed_correlation": correlation(vector.get("correlation")),
            "pending_request_set": dict(contract_version=version(request_set.get("contract_version", 5)), request_count=request_set.get("count"),
                request_set_digest=request_set.get("digest"), request_index_revision=str(request_set.get("revision", "")), record_sequence=request_set.get("record_sequence")),
            "has_latest_pending_request": value.get("has_latest_pending_request", False),
            "latest_pending_request": value.get("latest_pending_request"),
            "hard_kill_state": {**kill, "contract_version": version(kill.get("contract_version", 5)),
                "persistence_namespace": namespace(kill.get("namespace")), "account_namespace": account(kill.get("account_namespace", {})),
                "state": enum("SWV5_HARD_KILL_", kill.get("state")), "release_evidence": release_dto(kill.get("release_evidence", {})),
                "release_authority_reference": {**kill.get("release_reference", {}), "contract_version": version(kill.get("release_reference", {}).get("contract_version", 5))}},
            "reconciliation_vector": vector_dto(vector), "clean_shutdown": value.get("clean_shutdown")}


def checkpoint_integrity(value):
    dto = checkpoint_dto(value)
    size = u16len(frozen("SWV5_TestCanonicalCheckpointPayloadBody", dto))
    dto["header"]["payload_size"] = size
    return size, frozen("SWV5_TestCheckpointPayloadDigest", dto)
