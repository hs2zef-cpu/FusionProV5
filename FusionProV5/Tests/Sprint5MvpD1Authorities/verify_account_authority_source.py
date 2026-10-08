"""TEST ONLY: source/isolation checks, not MQL behavioral evidence."""
from pathlib import Path
import re
import subprocess

repo = Path(__file__).resolve().parents[3]
runtime = repo / "FusionProV5/ExecutionLayer/RuntimeAuthority"
control = repo / "FusionProV5/ExecutionLayer/ControlledDemo"
owner = (runtime / "SW_V5_S5_MvpAccountRiskAuthority.mqh").read_text(encoding="utf-8")
producer = (runtime / "SW_V5_S5_MvpAccountObservationProducer.mqh").read_text(encoding="utf-8")
providers = (runtime / "SW_V5_S5_MvpDemoAuthorityProviders.mqh").read_text(encoding="utf-8")
codec = (runtime / "SW_V5_S5_MvpAccountRiskRecordCodec.mqh").read_text(encoding="utf-8")
port = (control / "SW_V5_S5_MvpControlledDemoAuthorityPort.mqh").read_text(encoding="utf-8")
setup = (control / "SW_V5_S5_MvpManualDemoSetup.mqh").read_text(encoding="utf-8")
store = (runtime / "SW_V5_S5_MvpSqliteAuthorityStore.mqh").read_text(encoding="utf-8")
checks = []

def check(name, condition):
    checks.append((name, bool(condition)))
    print(f"ACCOUNT_SOURCE|{name}|{'PASS' if condition else 'FAIL'}")

def code(text):
    return re.sub(r'//[^\n]*|/\*.*?\*/|"(?:\\.|[^"\\])*"', '', text, flags=re.S)

check("independent-runtime-owner", "class SWV5S5_MvpAccountRiskAuthority" in owner)
check("dedicated-versioned-record", "MVP_ACCOUNT_RISK_AUTHORITY" in codec and "SWV5-MVP-ACCOUNT-RISK-PHYSICAL-V1" in codec)
check("strict-complete-codec", "r.AtEnd()" in codec and "payload==row.payload" in codec)
check("domain-sha-and-store-token", "SWV5S5_DomainDigest" in codec and "revision==row.store_revision" in codec)
check("physical-current-lease", "ownership.LoadCurrentLease" in owner and "MvpLeaseExact(current,lease)" in owner)
check("guarded-create-and-readback", "CompareAndSetWithGuard" in owner and "row.store_revision!=committed.store_revision" in owner)
check("live-profile-source", "ACCOUNT_TRADE_MODE_DEMO" in owner and "SWV5_AUTHORITY_LIVE_BROKER_STATE" in owner)
check("stable-owner-token-not-read-counter", "snapshot_sequence++" not in code(owner + producer + setup + port))
check("observations-load-owner", "owner.ValidateCurrent" in producer and "CaptureFlatAccount" in producer)
check("observations-check-independent-basket", "basket_owner.ValidateCurrentBasket" in producer)
check("complete-account-exposure-digests", "MvpObservationDigests" in producer and all(s in providers for s in ("CanonicalAccountRiskSnapshot", "CanonicalExposureRiskSnapshot")))
check("one-financial-capture-in-port", "CaptureFlatAccount(" not in code(port) and code(producer).count("CaptureFlatAccount(") == 1)
check("margin-and-basket-consume-same-envelope", "increasing.observation=m_account_observation" in port and "MvpObservationValid(candidate.context" in providers)
check("risk-and-admission-observation-gates", "risk.EvaluateObserved" in port and "MvpRiskObservationMatches(m_seed.context" in port)
check("complete-source-identity", "candidate.observation.combined_digest" in providers and "/OBS/" in providers)
check("account-before-trust", setup.index("account_owner.Provision") < setup.index("trust.Provision"))
check("both-admission-collections-load", "LoadAccountAuthority(collection.account.account_namespace)" in port)
check("claim-revalidates-both-admitted-namespaces", all(f"snapshot.collect_v{v}.account.account_namespace" in port for v in (1, 2)))
check("d6-reloads-owner", "account_owner.ValidateCurrent(store,claimed.permit.persistence_namespace" in port)
readonly = store[store.index("bool OpenReadOnly("):store.index("bool Open(")]
check("readonly-no-create-or-ddl", "DATABASE_OPEN_READONLY" in readonly and "DATABASE_OPEN_CREATE" not in readonly and "Execute(" not in readonly)
check("no-test-import-in-production", not re.search(r'#include\s+"[^"\n]*(?:Tests|TestFixtures|ReferenceValidators)', owner + producer + codec + setup + port))
check("no-broker-mutation-in-new-owner", not re.search(r'\b(?:OrderSend(?:Async)?|CTrade|PositionOpen|PositionClose)\s*\(', code(owner + producer + codec)))
sites = []
for path in (repo / "FusionProV5/ExecutionLayer").rglob("*.mqh"):
    sites.extend((path, m.start()) for m in re.finditer(r'\bOrderSend\s*\(', code(path.read_text(encoding="utf-8"))))
check("one-production-ordersend", len(sites) == 1 and sites[0][0].name == "SW_V5_S5_F_BrokerPlatformBoundary.mqh")
account_commit = "3d0224e7a0d8bd42a0b9eec91e8bdf3f8c048dd7"
# Keep the original Account patch scope check IMMUTABLE. The later attended
# launch has a separately checked native enum translation fix, not an Account
# patch exemption permitting arbitrary Broker changes.
changed = subprocess.check_output(["git", "diff", "--name-only", "03bc0b3927036ce6a64264421153898282b3fe1b", account_commit], cwd=repo, text=True).splitlines()
check("frozen-contracts-and-signal-unchanged", not any(p.startswith(("FusionProV5/ProductionArchitecture/", "FusionProV5/ExecutionLayer/Contracts/", "FusionProV5/Engines/", "FusionProV5/Decision/", "FusionProV5/Orchestration/", "FusionProV5/ExecutionLayer/BrokerAdapter/")) for p in changed))
failures = [name for name, ok in checks if not ok]
print(f"ACCOUNT_SOURCE_SUMMARY|total={len(checks)}|passed={len(checks)-len(failures)}|failed={len(failures)}|mql_executed=false")
if failures:
    raise SystemExit(', '.join(failures))
