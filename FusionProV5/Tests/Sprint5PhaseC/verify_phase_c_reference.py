#!/usr/bin/env python3
"""TEST ONLY. Phase C orchestration model, not a frozen Phase B oracle or MQL run."""
from __future__ import annotations
import hashlib, json
from dataclasses import dataclass, field
from typing import Any

FROZEN = {
    "correlation": "71b35f2e560c20300183f3b5400289def1cc7c8cee98d20e29d96387e8211d06",
    "attempt0": "5d202482a3f1981ba7fae20b52cf33855fc371b255e3ee575c792e4c2e993d1a",
    "attempt1": "953204b64927dc3aded48de51b90b98e601102dedbd9289061554ff67a37a77c",
    "idempotency": "5378f4b150446114669e6d8f09647018bfa9dd84e1f6ec5179598b0092fb4df4",
}

def local_binding(ingress: str, ordinal: int = 0) -> tuple[str, str, str]:
    """Scenario labels only; explicitly not Phase B canonical identities."""
    correlation = f"REFERENCE-MODEL-LOCAL-ID:correlation:{ingress}"
    return correlation, f"REFERENCE-MODEL-LOCAL-ID:attempt:{ingress}:{ordinal}", f"REFERENCE-MODEL-LOCAL-ID:idempotency:{ingress}"

@dataclass
class Model:
    ledger: dict[str, dict[str, Any]] = field(default_factory=dict)
    ledger_revision: int = 1
    sequences: dict[str, int] = field(default_factory=dict)
    sequence_revision: int = 1
    requests: dict[str, dict[str, Any]] = field(default_factory=dict)
    claims: dict[str, dict[str, Any]] = field(default_factory=dict)
    broker: list[dict[str, Any]] = field(default_factory=list)
    trace: list[dict[str, Any]] = field(default_factory=list)

    def emit(self, event: str, step: str, outcome: str) -> None:
        self.trace.append({"event": event, "step": step, "outcome": outcome})

    def ingress(self, event: str, ingress: str, direction: int, trusted: bool = True,
                ledger_valid: bool = True, sequence_valid: bool = True) -> str:
        if not trusted: self.emit(event,"TRUST","DENIED"); return "DENIED"
        if not ledger_valid: self.emit(event,"LEDGER_SNAPSHOT","INVALID_FAIL_CLOSED"); return "DENIED"
        if direction in (0,9): self.emit(event,"LEDGER","NO_ENTRY"); return "NO_ENTRY"
        if direction not in (-1,1): self.emit(event,"INGRESS","INVALID"); return "DENIED"
        if ingress in self.ledger: self.emit(event,"LEDGER","DUPLICATE"); return "DUPLICATE"
        correlation,attempt,key=local_binding(ingress,0)
        if not sequence_valid: self.emit(event,"SEQUENCE_STATE","INVALID_FAIL_CLOSED"); return "DENIED"
        sequence=len(self.sequences)+1
        self.sequence_revision+=1
        self.sequences[correlation]=sequence
        self.ledger_revision+=1
        self.ledger[ingress]={"correlation":correlation,"attempt":attempt,"key":key,"direction":direction,
                              "sequence":sequence,"record_revision":self.ledger_revision,
                              "record_digest":f"REFERENCE-LEDGER-DIGEST:{ingress}:{sequence}:{self.ledger_revision}"}
        self.requests[attempt]={"state":"CREATED","phase":"INTENT","direction":direction,"ordinal":0}
        self.emit(event,"LEDGER_SEQUENCE_LEDGER_BLUEPRINT","COMPLETE_READBACK_CREATED_ORDINAL_0")
        return "CREATED"

    def progress(self,event: str,ingress: str,terminal: bool=False,returned_direction: int|None=None) -> str:
        attempt=self.ledger[ingress]["attempt"]
        if terminal: self.emit(event,"PROGRESSION","TERMINAL_BLOCKED"); return "BLOCKED"
        if returned_direction is not None and returned_direction!=self.requests[attempt]["direction"]:
            self.emit(event,"V5_PHASE_AND_CONTENT_PRESERVATION","DIRECTION_REVERSAL_FAIL_CLOSED")
            return "BLOCKED"
        self.requests[attempt]={**self.requests[attempt],"state":"SUBMISSION_PENDING","phase":"SUBMISSION"}
        self.emit(event,"V5_PHASE_AND_CONTENT_PRESERVATION","SUBMISSION_PENDING"); return "READY"

    def dispatch(self,event: str,kind: str,**payload: Any) -> str:
        self.emit(event,"QUEUE_DISPATCH",kind)
        if kind=="ACCEPTED_INGRESS": return self.ingress(event,**payload)
        if kind=="REQUEST_PROGRESSION": return self.progress(event,**payload)
        if kind=="SUBMISSION_ADMISSION": return self.admission(event,**payload)
        raise AssertionError(kind)

    def admission(self,event: str,ingress: str,*,owner_ok=True,hard_kill=False,trust=True,
                  now=99,expiry=100,interrupt="",mutation="",replay_binding=False) -> str:
        request=self.ledger[ingress]; attempt=request["attempt"]
        if self.requests[attempt]["state"]!="SUBMISSION_PENDING": self.emit(event,"ADMISSION","LIFECYCLE_DENIED"); return "DENIED"
        if hard_kill or not trust or now>=expiry: self.emit(event,"PREPARE","DENIED"); return "DENIED"
        prepared={"revision":2,"permit":"P","permit_digest":"PD","snapshot":"S","snapshot_digest":"SD",
                  "claim_id":"C","durable_digest":"DD","owner":"A","event":event}
        self.emit(event,"PREPARE","COHERENT_PACKAGE")
        if interrupt=="BEFORE": self.emit(event,"INTERRUPT","P_LOST_RECOLLECT"); return "RECOLLECT"
        if not owner_ok: self.emit(event,"CLAIM","STALE_OWNER"); return "STALE_OWNER"
        if attempt in self.claims: self.emit(event,"CLAIM","ALREADY_CLAIMED_NO_GRANT"); return "RECONCILE"
        result=dict(prepared)
        if mutation: result[mutation]="CORRUPT"
        operation_event="PRIOR" if replay_binding else event
        valid=(result==prepared and operation_event==event)
        if not valid: self.emit(event,"VALIDATE_AUTHORITATIVE_CLAIM","FAIL_CLOSED"); return "INVALID_CLAIM"
        self.claims[attempt]=result
        self.emit(event,"CLAIM","CLAIM_GRANTED_NOW")
        if interrupt=="AFTER": self.emit(event,"INTERRUPT","RECONCILE_NO_CALL"); return "RECONCILE"
        self.broker.append({"event":event,"attempt":attempt,"direction":self.requests[attempt]["direction"],"outcome":"REQUEST_RECEIVED"})
        self.emit(event,"FAKE_BROKER","ACK_NOT_CONFIRMATION")
        return "INVOKED"

def run(name: str) -> dict[str,Any]:
    m=Model(); out=[]
    def ready(ingress="I",direction=1):
        out.append(m.dispatch("E1","ACCEPTED_INGRESS",ingress=ingress,direction=direction))
        out.append(m.dispatch("E2","REQUEST_PROGRESSION",ingress=ingress))
    if name=="buy": ready(direction=1); out.append(m.dispatch("E3","SUBMISSION_ADMISSION",ingress="I")); assert m.broker[0]["direction"]==1
    elif name=="sell": ready(direction=-1); out.append(m.dispatch("E3","SUBMISSION_ADMISSION",ingress="I")); assert m.broker[0]["direction"]==-1
    elif name=="duplicate_ingress": out += [m.ingress("E1","I",1),m.ingress("E2","I",1)]; assert len(m.sequences)==1
    elif name=="wait": out.append(m.ingress("E1","I",0)); assert not m.requests
    elif name=="blocked": out.append(m.ingress("E1","I",9)); assert not m.requests
    elif name=="two_requests": out += [m.ingress("E1","A",1),m.ingress("E2","B",-1)]; assert len(m.requests)==2
    elif name=="progression": ready(); assert list(m.requests.values())[0]["state"]=="SUBMISSION_PENDING"
    elif name=="ledger_malformed": out.append(m.ingress("E1","I",1,ledger_valid=False)); assert not m.sequences and not m.requests
    elif name=="sequence_malformed": out.append(m.ingress("E1","I",1,sequence_valid=False)); assert not m.ledger and not m.requests
    elif name=="direction_reversal":
        out.append(m.ingress("E1","BUY",1)); out.append(m.progress("E2","BUY",returned_direction=-1))
        out.append(m.ingress("E3","SELL",-1)); out.append(m.progress("E4","SELL",returned_direction=1))
        assert not m.broker and all(r["state"]=="CREATED" for r in m.requests.values())
    elif name in ("duplicate_admission","claim_before_takeover"):
        ready(); out += [m.admission("E3","I"),m.admission("E4","I")]; assert len(m.broker)==1
    elif name=="takeover_before": ready(); out.append(m.admission("E3","I",owner_ok=False)); assert not m.broker
    elif name=="crash_before": ready(); out.append(m.admission("E3","I",interrupt="BEFORE")); out.append(m.admission("E4","I")); assert len(m.broker)==1
    elif name in ("crash_after","uncertain_followup"):
        ready(); out.append(m.admission("E3","I",interrupt="AFTER")); out.append(m.admission("E4","I")); assert not m.broker
    elif name=="claim_mismatch":
        for key in ("revision","permit","permit_digest","snapshot","snapshot_digest","claim_id","durable_digest","owner"):
            n=Model(); n.ingress("E1","I",1); n.progress("E2","I"); assert n.admission("E3","I",mutation=key)=="INVALID_CLAIM" and not n.broker
        out.append("ALL_MISMATCHES_DENIED")
    elif name=="grant_replay": ready(); out.append(m.admission("E3","I",replay_binding=True)); assert not m.broker
    elif name=="hard_kill": ready(); out.append(m.admission("E3","I",hard_kill=True)); assert not m.broker
    elif name=="trust": ready(); out.append(m.admission("E3","I",trust=False)); assert not m.broker
    elif name=="risk_expiry":
        ready("A"); ready("B"); ready("C"); out += [m.admission("E7","A",now=99),m.admission("E8","B",now=100),m.admission("E9","C",now=101)]; assert len(m.broker)==1
    elif name=="broker_response": ready(); out.append(m.admission("E3","I")); out.append("ACK_NOT_CONFIRMATION")
    else: raise AssertionError(name)
    return {"scenario":name,"outcomes":out,"broker":m.broker,"trace":m.trace}

SCENARIOS=["buy","sell","duplicate_ingress","wait","blocked","two_requests","progression","ledger_malformed",
           "sequence_malformed","direction_reversal","duplicate_admission",
           "takeover_before","claim_before_takeover","crash_before","crash_after","uncertain_followup","claim_mismatch",
           "grant_replay","hard_kill","trust","risk_expiry","broker_response"]

def main() -> int:
    assert FROZEN["attempt0"]!=FROZEN["attempt1"]
    first=[run(x) for x in SCENARIOS]; second=[run(x) for x in SCENARIOS]; assert first==second
    payload=json.dumps(first,sort_keys=True,separators=(",",":"))
    print(json.dumps({"classification":"PHASE C ORCHESTRATION MODEL; NOT FROZEN PHASE B OR MQL EVIDENCE",
      "scenarios":len(first),"runs":2,"deterministic":True,"status":"PASS",
      "trace_digest_sha256":hashlib.sha256(payload.encode()).hexdigest(),"initial_ordinal":0},sort_keys=True))
    return 0
if __name__=="__main__": raise SystemExit(main())
