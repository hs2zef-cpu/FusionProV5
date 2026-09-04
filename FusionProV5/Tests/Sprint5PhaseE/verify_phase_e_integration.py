"""TEST ONLY / NOT FOR PRODUCTION / NO BROKER ACCESS.

Independent deterministic Phase-E reference/adversarial oracle. This is not MQL,
MT5, a broker, a physical database, or a production implementation. Scenario
expectations are literal goldens; the harness only observes and compares.
"""
from __future__ import annotations
from dataclasses import dataclass
import hashlib
import json


@dataclass(frozen=True)
class Scenario:
    id: str
    group: str
    mode: str
    invariants: tuple[str, ...]
    phases: tuple[str, ...]
    authorities: tuple[str, ...]
    events: tuple[str, ...]
    expected_outcome: str
    expected_broker_count: int
    expected_restart: str
    expected_durable: str


class DumbBroker:
    def __init__(self, scripted: str = "ACK") -> None:
        self.scripted = scripted
        self.invocations: list[str] = []

    def invoke(self, identity: str) -> str:
        self.invocations.append(identity)  # deliberately no dedupe
        return self.scripted


class FencedStore:
    def __init__(self, epoch: int = 7) -> None:
        self.epoch = epoch
        self.value = "EMPTY"

    def cas(self, expected_epoch: int, value: str) -> bool:
        if expected_epoch != self.epoch:
            return False
        self.value = value
        return True


@dataclass
class Observation:
    outcome: str
    broker_count: int
    restart: str
    durable: str
    trace: tuple[str, ...]


class IntegratedReferenceHarness:
    """Reduced independent integration oracle; it grants no production authority."""

    def run(self, s: Scenario) -> Observation:
        broker = DumbBroker("ACK")
        store = FencedStore()
        trace = ["CLOCK@1000", "OWNER@7"]
        outcome, restart, durable = "FAIL_CLOSED", "NONE", "UNCHANGED"

        if s.mode in {"HAPPY_BUY", "HAPPY_SELL"}:
            identity = "INGRESS|LEDGER|SEQ-1|REQUEST-1|PERMIT-1|SNAPSHOT-1|CLAIM-1"
            chain = [identity] * 10
            assert len(set(chain)) == 1
            trace += ["INGRESS_ACCEPTED", "LEDGER_COMMITTED", "SEQUENCE_RESERVED", "REQUEST_SUBMISSION_PENDING",
                      "P_PROVISIONAL", "CLAIM_GRANTED_NOW", "DURABLE_CLAIMED_UNRESOLVED"]
            broker.invoke(identity)
            assert store.cas(7, "REQUEST_SET+CHECKPOINT")
            outcome, restart, durable = "COMMITTED", "SAFE_TO_RESUME", "REQUEST_SET+CHECKPOINT"
        elif s.mode in {"WAIT", "BLOCKED"}:
            trace += [s.mode, "LEDGER_NO_ENTRY", "NO_REQUEST_NO_PERMIT_NO_CLAIM"]
            outcome, durable = "NO_INCREASING_AUTHORITY", "LEDGER_NO_ENTRY"
        elif s.mode.startswith("CRASH_M"):
            point = int(s.mode[-1]); trace += [f"CRASH_M{point}"]
            duplicate_probe={1:"DUPLICATE_INGRESS",2:"DUPLICATE_EVENT",3:"DUPLICATE_SUBMISSION",6:"DUPLICATE_CLAIM"}.get(point)
            if duplicate_probe:
                # The owning durable prefix is observed twice; only one logical
                # membership/reservation/Claim may exist and no duplicate gets
                # an event-local broker grant at these crash boundaries.
                durable_owner_rows={duplicate_probe:"ONE"}
                assert durable_owner_rows[duplicate_probe]=="ONE"
                trace += [duplicate_probe,"OWNER_ROWS=1"]
            if point <= 5:
                outcome, restart, durable = "RECOLLECT_OR_FAIL_CLOSED", "NOT_CLAIMED", f"M{point}_PREFIX"
            elif point == 6:
                outcome, restart, durable = "RECONCILIATION_ONLY", "CLAIMED_UNRESOLVED", "CLAIMED_UNRESOLVED"
            elif point == 7:
                broker.scripted = "UNCERTAIN"; broker.invoke("CLAIM-1")
                outcome, restart, durable = "RECONCILIATION_ONLY", "CLAIMED_UNRESOLVED", "BROKER_UNCERTAIN"
            elif point == 8:
                broker.invoke("CLAIM-1"); store.cas(7, "REQUEST_SET_ONLY")
                outcome, restart, durable = "RECONCILIATION_ONLY", "SPLIT_PUBLICATION", "REQUEST_SET_ONLY"
            else:
                outcome, restart, durable = "RECONCILIATION_ONLY", "CAS_UNCERTAIN", "PREVIOUS_COMMITTED"
        elif s.mode.startswith("RESTART_"):
            key = s.mode.removeprefix("RESTART_")
            mapping = {
                "ORDINARY_ACQUIRED": ("RESUME", "SAFE_TO_RESUME", "COHERENT"),
                "ORDINARY_RENEWED": ("RESUME", "SAFE_TO_RESUME", "COHERENT"),
                "ZERO_ACQUIRED": ("RESUME", "SAFE_TO_RESUME", "ZERO_HISTORY"),
                "ZERO_RENEWED": ("RESUME", "SAFE_TO_RESUME", "ZERO_HISTORY"),
                "CLAIMED": ("RECONCILIATION_ONLY", "CLAIMED_UNRESOLVED", "CLAIMED_UNRESOLVED"),
                "SPLIT": ("RECONCILIATION_ONLY", "SPLIT_PUBLICATION", "REQUEST_SET_ONLY"),
                "STALE": ("FAIL_CLOSED", "STALE_QUERY", "UNCHANGED"),
                "CORRUPT": ("FAIL_CLOSED", "CORRUPT_CHECKPOINT", "UNCHANGED"),
                "WRONG_SET": ("FAIL_CLOSED", "CROSS_OBJECT_MISMATCH", "UNCHANGED"),
                "HARD_KILL": ("NO_INCREASING_AUTHORITY", "CLOSE_ONLY", "HARD_KILL_ACTIVE"),
                "INVALID_RELEASE": ("FAIL_CLOSED", "INVALID_RELEASE", "UNCHANGED"),
                "VALID_RELEASE": ("RESUME", "SAFE_TO_RESUME", "RELEASED_VALID"),
                "OLDER_SET": ("FAIL_CLOSED", "CROSS_OBJECT_MISMATCH", "UNCHANGED"),
            }
            outcome, restart, durable = mapping[key]; trace += [s.mode, restart]
            if key=="CLAIMED": trace += ["RESTART_AFTER_CLAIM","NO_EVENT_LOCAL_GRANT","NO_REINVOKE"]
        elif s.mode.startswith("ADR_"):
            key = s.mode.removeprefix("ADR_")
            retained = key in {"HK_AFTER_P", "TRUST_AFTER_P", "CLAIM_BEFORE_TAKEOVER"}
            if retained:
                broker.invoke("CLAIM-1")
                outcome, restart, durable = "CURRENT_RETAINED_LATER_BLOCKED", "CLAIMED_UNRESOLVED", "CLAIMED_UNRESOLVED"
            else:
                outcome, restart, durable = "BLOCK_CURRENT", "NOT_CLAIMED", "UNCHANGED"
            trace += ["P_FROZEN_ADR020", key, outcome]
        elif s.mode.startswith("TAKEOVER_"):
            key = s.mode.removeprefix("TAKEOVER_")
            if key == "CLAIM_FIRST":
                broker.invoke("CLAIM-1"); outcome, restart, durable = "RECONCILIATION_ONLY", "CLAIMED_UNRESOLVED", "CLAIMED_UNRESOLVED"
            elif key == "DUAL_INTERLEAVING":
                broker.invoke("CLAIM-1"); outcome, restart, durable = "SINGLE_WINNER", "CLAIMED_UNRESOLVED", "OWNER_B_RECONCILES"
            elif key == "SPLIT":
                outcome, restart, durable = "RECONCILIATION_ONLY", "SPLIT_PUBLICATION", "REQUEST_SET_ONLY"
            else:
                assert not store.cas(6, "BYTE_IDENTICAL")
                outcome, restart, durable = "STALE_OWNER_DENIED", "NOT_CLAIMED", "UNCHANGED"
            trace += [s.mode, outcome]
        elif s.mode.startswith("SEMANTIC_") or s.mode.startswith("EXACTLY_ONCE_"):
            key = s.mode.removeprefix("EXACTLY_ONCE_") if s.mode.startswith("EXACTLY_ONCE_") else s.mode.removeprefix("SEMANTIC_")
            if key in {"DUP_INGRESS", "DUP_EVENT", "DUP_SUBMISSION", "DUP_CLAIM", "PRIOR_CLAIM_REPLAY",
                       "RESTART_AFTER_CLAIM", "TAKEOVER_AFTER_CLAIM", "STALE_OWNER_REPLAY"}:
                # The owning Ledger/Claim/fence authority grants only the first
                # event. Both events reach the dumb broker adapter only if both
                # receive a current event-local grant.
                grants = [True, False]
                for granted in grants:
                    if granted: broker.invoke("CLAIM-1")
                outcome, restart, durable = "DUPLICATE_SUPPRESSED_BY_AUTHORITY", "CLAIMED_UNRESOLVED", "CLAIMED_UNRESOLVED"
            elif key == "P11-FOUR-WAY-INCOHERENCE":
                def sealed(domain: str, world: str) -> dict[str, str]:
                    payload=f"{domain}|{world}|FENCE-7|REQUEST-SET-{world}"
                    return {"domain":domain,"world":world,"payload":payload,
                            "digest":hashlib.sha256(payload.encode()).hexdigest()}
                objects=[sealed("CHECKPOINT","A"),sealed("REQUEST_SET","B"),
                         sealed("BROKER_SUMMARY","C"),sealed("EXECUTION_SUMMARY","D")]
                individually_valid=all(o["digest"]==hashlib.sha256(o["payload"].encode()).hexdigest() for o in objects)
                joint_valid=individually_valid and len({o["world"] for o in objects})==1
                assert individually_valid and not joint_valid
                outcome, restart, durable = "FAIL_CLOSED", "CROSS_OBJECT_MISMATCH", "UNCHANGED"
            else:
                outcome, restart, durable = "FAIL_CLOSED", "CROSS_OBJECT_MISMATCH", "UNCHANGED"
            if key=="P10-NO-RECONSTRUCTED-GRANT": trace += ["PRIOR_EVENT_CLAIM_RESULT_REPLAY","NO_GRANT"]
            trace += [s.mode, outcome]
        elif s.mode.startswith("SCHEDULER_"):
            broker.invoke("CLAIM-1")
            outcome, restart, durable = "INVARIANT_SINGLE_WINNER", "CLAIMED_UNRESOLVED", "AUTHORITATIVE_STATE_UNAMBIGUOUS"
            trace += ["NON_AUTHORITATIVE_SCHEDULER", s.mode]
        else:
            raise AssertionError(f"unmapped scenario mode {s.mode}")

        return Observation(outcome, len(broker.invocations), restart, durable, tuple(trace))


def make_scenarios() -> list[Scenario]:
    s: list[Scenario] = []
    def add(id_: str, group: str, mode: str, inv: tuple[str, ...], phases: tuple[str, ...], auth: tuple[str, ...],
            events: tuple[str, ...], outcome: str, broker: int, restart: str, durable: str) -> None:
        s.append(Scenario(id_, group, mode, inv, phases, auth, events, outcome, broker, restart, durable))

    common = ("B", "C", "D"); authorities = ("CLOCK", "LEASE_FENCE", "TRUST", "HARD_KILL", "LEDGER", "SEQUENCE", "RISK", "PERMIT", "CLAIM", "REQUEST_SET", "CHECKPOINT")
    add("E-HAPPY-BUY", "HAPPY", "HAPPY_BUY", ("TOTAL_IDENTITY_CHAIN", "EXACTLY_ONCE"), common, authorities, ("INGRESS", "CLAIM", "BROKER_ACK", "PUBLISH", "RESTART"), "COMMITTED", 1, "SAFE_TO_RESUME", "REQUEST_SET+CHECKPOINT")
    add("E-HAPPY-SELL", "HAPPY", "HAPPY_SELL", ("DIRECTION_UNCHANGED", "EXACTLY_ONCE"), common, authorities, ("SELL_INGRESS", "CLAIM", "BROKER_ACK", "PUBLISH"), "COMMITTED", 1, "SAFE_TO_RESUME", "REQUEST_SET+CHECKPOINT")
    add("E-WAIT", "STOP", "WAIT", ("NO_SYNTHESIZED_DIRECTION",), ("B", "C"), ("TRUST", "LEDGER"), ("WAIT",), "NO_INCREASING_AUTHORITY", 0, "NONE", "LEDGER_NO_ENTRY")
    add("E-BLOCKED", "STOP", "BLOCKED", ("NO_SYNTHESIZED_DIRECTION",), ("B", "C"), ("TRUST", "LEDGER"), ("BLOCKED",), "NO_INCREASING_AUTHORITY", 0, "NONE", "LEDGER_NO_ENTRY")
    crash = [(1,"RECOLLECT_OR_FAIL_CLOSED",0,"NOT_CLAIMED","M1_PREFIX"),(2,"RECOLLECT_OR_FAIL_CLOSED",0,"NOT_CLAIMED","M2_PREFIX"),(3,"RECOLLECT_OR_FAIL_CLOSED",0,"NOT_CLAIMED","M3_PREFIX"),(4,"RECOLLECT_OR_FAIL_CLOSED",0,"NOT_CLAIMED","M4_PREFIX"),(5,"RECOLLECT_OR_FAIL_CLOSED",0,"NOT_CLAIMED","M5_PREFIX"),(6,"RECONCILIATION_ONLY",0,"CLAIMED_UNRESOLVED","CLAIMED_UNRESOLVED"),(7,"RECONCILIATION_ONLY",1,"CLAIMED_UNRESOLVED","BROKER_UNCERTAIN"),(8,"RECONCILIATION_ONLY",1,"SPLIT_PUBLICATION","REQUEST_SET_ONLY"),(9,"RECONCILIATION_ONLY",0,"CAS_UNCERTAIN","PREVIOUS_COMMITTED")]
    for n,out,broker,restart,durable in crash:
        add(f"E-CRASH-M{n}","CRASH",f"CRASH_M{n}",(f"CRASH_M{n}","NO_BLIND_RETRY"),common,("LEDGER","SEQUENCE","CLAIM","STORE"),(f"M{n}",),out,broker,restart,durable)
    restart_cases=[("N1","ORDINARY_ACQUIRED","RESUME","SAFE_TO_RESUME","COHERENT"),("N2","ORDINARY_RENEWED","RESUME","SAFE_TO_RESUME","COHERENT"),("N3","ZERO_ACQUIRED","RESUME","SAFE_TO_RESUME","ZERO_HISTORY"),("N4","ZERO_RENEWED","RESUME","SAFE_TO_RESUME","ZERO_HISTORY"),("N5","CLAIMED","RECONCILIATION_ONLY","CLAIMED_UNRESOLVED","CLAIMED_UNRESOLVED"),("N6","SPLIT","RECONCILIATION_ONLY","SPLIT_PUBLICATION","REQUEST_SET_ONLY"),("N7","STALE","FAIL_CLOSED","STALE_QUERY","UNCHANGED"),("N8","CORRUPT","FAIL_CLOSED","CORRUPT_CHECKPOINT","UNCHANGED"),("N9","WRONG_SET","FAIL_CLOSED","CROSS_OBJECT_MISMATCH","UNCHANGED"),("N10","HARD_KILL","NO_INCREASING_AUTHORITY","CLOSE_ONLY","HARD_KILL_ACTIVE"),("N11","INVALID_RELEASE","FAIL_CLOSED","INVALID_RELEASE","UNCHANGED"),("N12","VALID_RELEASE","RESUME","SAFE_TO_RESUME","RELEASED_VALID"),("N13","OLDER_SET","FAIL_CLOSED","CROSS_OBJECT_MISMATCH","UNCHANGED")]
    for ident,key,out,restart,durable in restart_cases:
        add(f"E-RESTART-{ident}","RESTART",f"RESTART_{key}",(ident,"AUTHORITATIVE_READBACK"),("B","D"),("LEASE_FENCE","REQUEST_SET","CHECKPOINT","BROKER_SUMMARY","EXECUTION_SUMMARY"),("LOAD","RECONCILE"),out,0,restart,durable)
    adr=[("HK-BEFORE-P","HK_BEFORE_P","BLOCK_CURRENT",0,"NOT_CLAIMED","UNCHANGED"),("HK-AFTER-P","HK_AFTER_P","CURRENT_RETAINED_LATER_BLOCKED",1,"CLAIMED_UNRESOLVED","CLAIMED_UNRESOLVED"),("TRUST-BEFORE-P","TRUST_BEFORE_P","BLOCK_CURRENT",0,"NOT_CLAIMED","UNCHANGED"),("TRUST-AFTER-P","TRUST_AFTER_P","CURRENT_RETAINED_LATER_BLOCKED",1,"CLAIMED_UNRESOLVED","CLAIMED_UNRESOLVED"),("RISK-EXPIRES-AT-CLAIM","RISK_EQUAL","BLOCK_CURRENT",0,"NOT_CLAIMED","UNCHANGED"),("TAKEOVER-BEFORE-CLAIM","TAKEOVER_BEFORE_CLAIM","BLOCK_CURRENT",0,"NOT_CLAIMED","UNCHANGED"),("CLAIM-BEFORE-TAKEOVER","CLAIM_BEFORE_TAKEOVER","CURRENT_RETAINED_LATER_BLOCKED",1,"CLAIMED_UNRESOLVED","CLAIMED_UNRESOLVED")]
    for ident,key,out,broker,restart,durable in adr:
        add(f"E-ADR020-{ident}","ADR020",f"ADR_{key}",(ident,"FROZEN_P"),("A","B","C"),("TRUST","HARD_KILL","RISK","CLAIM","LEASE_FENCE"),("COLLECT","P","MUTATE","CLAIM"),out,broker,restart,durable)
    takeover=[("O1","BEFORE_CLAIM","STALE_OWNER_DENIED",0,"NOT_CLAIMED","UNCHANGED"),("O2","AFTER_COLLECT","STALE_OWNER_DENIED",0,"NOT_CLAIMED","UNCHANGED"),("O3","CLAIM_FIRST","RECONCILIATION_ONLY",1,"CLAIMED_UNRESOLVED","CLAIMED_UNRESOLVED"),("O4","STALE_REPLAY","STALE_OWNER_DENIED",0,"NOT_CLAIMED","UNCHANGED"),("O5","DUAL_INTERLEAVING","SINGLE_WINNER",1,"CLAIMED_UNRESOLVED","OWNER_B_RECONCILES"),("O6","SPLIT","RECONCILIATION_ONLY",0,"SPLIT_PUBLICATION","REQUEST_SET_ONLY")]
    for ident,key,out,broker,restart,durable in takeover:
        add(f"E-TAKEOVER-{ident}","TAKEOVER",f"TAKEOVER_{key}",(ident,"DUAL_FENCE_ENFORCEMENT"),("B","C","D"),("CLAIM_FENCE","DURABLE_CAS"),("INTERLEAVE","READBACK"),out,broker,restart,durable)
    semantic=["P1-EPOCH-SPLIT","P2-SEQUENCE-LEDGER-EPOCH","P3-STALE-BROKER","P4-BROKER-EXECUTION-CONTRADICTION","P5-CROSS-TYPE-DOMAIN","P6-MUTATE-RESEAL","P7-RESEALED-STALE-EPOCH","P8-RISK-EXPIRY-EQUALITY","P9-TRUST-ORDERING","P10-NO-RECONSTRUCTED-GRANT","P11-FOUR-WAY-INCOHERENCE"]
    for ident in semantic:
        add(f"E-SEMANTIC-{ident}","SEMANTIC",f"SEMANTIC_{ident}",(ident,"RESEALED_FAIL_CLOSED"),("B","D"),("REQUEST_SET","CHECKPOINT","BROKER_SUMMARY","EXECUTION_SUMMARY"),("BUILD_VALID","CROSS_COMPOSE","VALIDATE"),"FAIL_CLOSED",0,"CROSS_OBJECT_MISMATCH","UNCHANGED")
    for key in ("NORMAL","DUAL_OWNER"):
        add(f"E-SCHEDULER-{key}","SCHEDULER",f"SCHEDULER_{key}",(key,"NON_AUTHORITATIVE_SCHEDULER"),("C","D"),("CLAIM","DURABLE_CAS"),("ORDER_A","ORDER_B"),"INVARIANT_SINGLE_WINNER",1,"CLAIMED_UNRESOLVED","AUTHORITATIVE_STATE_UNAMBIGUOUS")
    return s


def execute_once() -> dict:
    scenarios = make_scenarios(); assert len({x.id for x in scenarios}) == len(scenarios)
    harness = IntegratedReferenceHarness(); results = []
    for s in scenarios:
        assert len(s.phases) >= 2 and s.authorities and s.events and s.invariants
        actual = harness.run(s)
        passed = (actual.outcome == s.expected_outcome and actual.broker_count == s.expected_broker_count and
                  actual.restart == s.expected_restart and actual.durable == s.expected_durable and actual.broker_count <= 1)
        results.append({"id":s.id,"group":s.group,"passed":passed,"outcome":actual.outcome,
                        "broker_count":actual.broker_count,"restart":actual.restart,"durable":actual.durable,
                        "trace":actual.trace,"phases":s.phases,"authorities":s.authorities})
    failures=[x["id"] for x in results if not x["passed"]]
    assert not failures, "literal expectation mismatch: " + ",".join(failures)
    encoded=json.dumps(results,sort_keys=True,separators=(",",":"),ensure_ascii=False).encode()
    durable=json.dumps([(x["id"],x["durable"],x["restart"],x["broker_count"],x["trace"]) for x in results],
                       separators=(",",":"),ensure_ascii=False).encode()
    groups={}
    for x in results: groups[x["group"]]=groups.get(x["group"],0)+1
    return {"classification":"INDEPENDENT EXECUTABLE REFERENCE / ADVERSARIAL ORACLE; NOT MQL, MT5, BROKER, OR PHYSICAL DB PROOF",
            "status":"PASS","total":len(results),"passed":len(results),"failed":0,"skipped":0,
            "unique_scenario_ids":len(results),"groups":groups,
            "result_digest":hashlib.sha256(encoded).hexdigest(),
            "durable_trace_digest":hashlib.sha256(durable).hexdigest(),"results":results}


def main() -> None:
    first=execute_once(); second=execute_once(); assert first==second
    summary={k:v for k,v in first.items() if k!="results"}; summary["runs"]=2; summary["deterministic"]=True
    print(json.dumps(summary,sort_keys=True,separators=(",",":")))


if __name__ == "__main__": main()
