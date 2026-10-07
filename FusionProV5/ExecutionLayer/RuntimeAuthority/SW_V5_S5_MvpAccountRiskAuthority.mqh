#ifndef SW_V5_S5_MVP_ACCOUNT_RISK_AUTHORITY_MQH
#define SW_V5_S5_MVP_ACCOUNT_RISK_AUTHORITY_MQH

// Canonical locked-Demo account namespace owner. NO BROKER MUTATION.
// Namespace generation is durable; financial observations are NOT this token.
#include "SW_V5_S5_MvpOwnershipAuthority.mqh"
#include "SW_V5_S5_MvpAccountRiskRecordCodec.mqh"

bool SWV5S5_EqualAccountNamespace(const SWV5_AccountRiskNamespace &left,const SWV5_AccountRiskNamespace &right)
{
   string a,b;
   return SWV5S5_CanonicalAccountNamespace("account",left,a) &&
      SWV5S5_CanonicalAccountNamespace("account",right,b) && a==b;
}

bool SWV5S5_MvpAccountScopeMatches(const SWV5_PersistenceNamespace &scope,
                                    const SWV5_AccountRiskNamespace &account,
                                    const SWV5S5_MvpRuntimeProfileObservation &live)
{
   return SWV5S5_IsV5Version(scope.contract_version) && SWV5S5_IsV5Version(account.contract_version) &&
      SWV5S5_MvpProfileMatches(live,ACCOUNT_TRADE_MODE_DEMO) &&
      scope.ownership_namespace.symbol==live.symbol && scope.ownership_namespace.strategy_id==SWV5S5_MVP_PROFILE_ID &&
      scope.ownership_namespace.magic==SWV5_RUNTIME_STRATEGY_MAGIC && scope.basket_id.value!="" &&
      account.broker_identity==live.broker_identity && account.server==live.server && account.account_login==live.account_login &&
      account.account_currency==live.account_currency && account.account_mode==live.account_mode &&
      account.broker_identity==scope.ownership_namespace.broker_identity && account.server==scope.ownership_namespace.server &&
      account.account_login==scope.ownership_namespace.account_login && account.strategy_id==scope.ownership_namespace.strategy_id &&
      account.magic==scope.ownership_namespace.magic && account.authoritative_source==SWV5_AUTHORITY_LIVE_BROKER_STATE;
}

class SWV5S5_MvpAccountRiskAuthority
{
private:
   string m_failure;
   bool GenesisReady(SWV5S5_MvpSqliteAuthorityStore &store)
   {
      SWV5S5_MvpAuthorityRow row; bool found=false; string digest,revision,manifest,value;
      return store.ReadRow(SWV5S5_MVP_DOMAIN_GENESIS,"GENESIS",row,found) && found && row.logical_revision==2 &&
         row.state==SWV5S5_MVP_GENESIS_READY_FOR_RECONCILIATION &&
         SWV5S5_DomainDigest(row.domain_key,row.payload,digest) && digest==row.payload_digest &&
         store.DeriveStoreRevision(row.domain_key,row.record_key,row.logical_revision,digest,revision) && revision==row.store_revision &&
         SWV5S5_MvpGenesisManifestDigest(manifest) &&
         SWV5S5_MvpCanonicalScalar(row.payload,"completed_manifest_digest","s",value) && value==manifest &&
         SWV5S5_MvpCanonicalScalar(row.payload,"namespace_digest","s",value) && value==store.NamespaceDigest() &&
         SWV5S5_MvpCanonicalScalar(row.payload,"policy_id","s",value) && value==SWV5S5_MVP_GENESIS_POLICY;
   }
   bool NoDependentState(SWV5S5_MvpSqliteAuthorityStore &store)
   {
      // Closed allowlist: only Genesis infrastructure and current Ownership may
      // precede issuance. Unknown/unindexed rows cannot prove a fresh namespace.
      SWV5S5_MvpAuthorityRow rows[]; string digest,revision;
      if(!store.ReadAllRows(rows)) return false;
      for(int i=0;i<ArraySize(rows);i++)
      {
         if(!store.DeriveStoreRevision(rows[i].domain_key,rows[i].record_key,rows[i].logical_revision,rows[i].payload_digest,revision) ||
            revision!=rows[i].store_revision) return false;
         if(rows[i].domain_key==SWV5S5_MVP_DOMAIN_OWNERSHIP)
         { if(rows[i].record_key!="GENESIS" && rows[i].record_key!=SWV5S5_MVP_OWNERSHIP_KEY &&
              rows[i].record_key!=SWV5S5_MVP_OWNERSHIP_CLOCK_KEY) return false; continue; }
         // Ownership CURRENT uses its frozen lease projection digest, not the
         // generic physical-envelope digest. Provision already validates that
         // entire lease through its independent owner before this scan.
         if(!SWV5S5_DomainDigest(rows[i].domain_key,rows[i].payload,digest) || digest!=rows[i].payload_digest) return false;
         if(rows[i].domain_key==SWV5S5_MVP_DOMAIN_GENESIS || rows[i].domain_key==SWV5S5_MVP_DOMAIN_OPERATOR)
         { if(rows[i].record_key!="GENESIS") return false; continue; }
         bool seeded=false;
         for(int d=0;d<SWV5S5_MvpGenesisDomainCount();d++)
            if(rows[i].domain_key==SWV5S5_MvpGenesisDomain(d)) seeded=true;
         if(!seeded || rows[i].logical_revision!=1 ||
            (rows[i].record_key!="GENESIS" && !(rows[i].domain_key==SWV5S5_MVP_DOMAIN_HARD_KILL &&
                                              rows[i].record_key=="CURRENT"))) return false;
         string value;
         if(!SWV5S5_MvpCanonicalScalar(rows[i].payload,"domain","s",value) || value!=rows[i].domain_key ||
            !SWV5S5_MvpCanonicalScalar(rows[i].payload,"genesis_generation","u",value) || value!="1") return false;
         if(rows[i].record_key=="CURRENT")
         {
            SWV5S5_MvpAuthorityRow seed; bool found=false;
            if(!store.ReadRow(rows[i].domain_key,"GENESIS",seed,found) || !found ||
               rows[i].payload!=seed.payload || rows[i].payload_digest!=seed.payload_digest || rows[i].state!=seed.state) return false;
         }
      }
      return true;
   }
public:
   string LastFailure(void) const { return m_failure; }
   bool Load(SWV5S5_MvpSqliteAuthorityStore &store,SWV5S5_MvpAccountRiskAuthorityRecord &record,
             SWV5S5_MvpAuthorityRow &row,bool &found)
   {
      ZeroMemory(record); found=false; string scope_digest;
      m_failure="ACCOUNT_AUTHORITY_MISSING_OR_CORRUPT";
      if(!store.ReadRow(SWV5S5_MVP_DOMAIN_ACCOUNT_RISK,"CURRENT",row,found)) return false;
      if(!found) return true;
      return SWV5S5_MvpAccountRiskValidateRow(store,row,record) &&
         SWV5S5_MvpOwnershipNamespaceDigest(record.persistence_namespace.ownership_namespace,scope_digest) &&
         scope_digest==store.NamespaceDigest();
   }
   bool ValidateCurrent(SWV5S5_MvpSqliteAuthorityStore &store,const SWV5_PersistenceNamespace &scope,
                        const SWV5S5_MvpRuntimeProfileObservation &live,
                        SWV5S5_MvpAccountRiskAuthorityRecord &record,SWV5S5_MvpAuthorityRow &row)
   {
      bool found=false;
      const bool ok=GenesisReady(store) && Load(store,record,row,found) && found &&
         SWV5S5_EqualNamespace(scope,record.persistence_namespace) &&
         SWV5S5_MvpAccountScopeMatches(scope,record.account_namespace,live);
      if(ok) m_failure=""; return ok;
   }
   bool Provision(SWV5S5_MvpSqliteAuthorityStore &store,const SWV5_ContractValidationContext &context,
                   const SWV5_PersistenceNamespace &scope,const SWV5_InstanceLease &lease,
                   ISWV5S5MvpReadOnlyPlatform &platform,
                   SWV5S5_MvpAccountRiskAuthorityRecord &record,SWV5S5_MvpAuthorityRow &committed)
   {
      ZeroMemory(record); SWV5S5_MvpAuthorityRow guard; SWV5_InstanceLease current;
      SWV5S5_MvpLeasePublicationAuthority ownership; SWV5S5_MvpAccountObservation observed;
      m_failure="ACCOUNT_AUTHORITY_GENESIS_LEASE_OBSERVATION";
      if(!GenesisReady(store) || !SWV5S5_MvpLeaseCurrentForClock(context,lease.fence,lease) ||
         !ownership.LoadCurrentLease(store,scope.ownership_namespace,lease.fence,current,guard) ||
         !SWV5S5_MvpLeaseExact(current,lease) || !platform.CaptureFlatAccount(context.clock_time,observed) ||
         !observed.complete || !observed.history_complete || observed.observed_at!=context.clock_time) return false;
      SWV5S5_MvpAccountRiskAuthorityRecord existing; SWV5S5_MvpAuthorityRow row; bool found=false;
      if(!Load(store,existing,row,found)) return false;
      if(found)
      {
         if(!ValidateCurrent(store,scope,observed.profile,existing,row)) return false;
         record=existing; committed=row; m_failure=""; return true;
      }
      m_failure="ACCOUNT_AUTHORITY_DEPENDENT_STATE_PREVENTS_INITIAL_ISSUANCE";
      if(!NoDependentState(store)) return false;
      record.format=SWV5S5_MVP_ACCOUNT_RISK_FORMAT; record.persistence_namespace=scope;
      SWV5_AccountRiskNamespace account; ZeroMemory(account); SWV5S5_MvpInitProductionVersion(account.contract_version);
      account.broker_identity=observed.profile.broker_identity; account.server=observed.profile.server;
      account.account_login=observed.profile.account_login; account.account_currency=observed.profile.account_currency;
      account.strategy_id=scope.ownership_namespace.strategy_id; account.magic=scope.ownership_namespace.magic;
      account.account_mode=observed.profile.account_mode; account.authoritative_source=SWV5_AUTHORITY_LIVE_BROKER_STATE;
      // Sole initial issuer. These tokens become authority only after guarded
      // physical commit AND complete canonical readback below.
      account.snapshot_epoch=1; account.snapshot_sequence=1;
      if(!SWV5S5_MvpAccountScopeMatches(scope,account,observed.profile)) return false;
      record.account_namespace=account; record.authority_epoch=1; record.publication_sequence=1;
      record.record_revision=1; record.created_at=context.clock_time; record.status=1;
      string payload,digest;
      if(!SWV5S5_DomainDigest(SWV5S5_MVP_DOMAIN_ACCOUNT_RISK+"/ID",store.NamespaceDigest(),record.record_id) ||
         !SWV5S5_MvpAccountRiskEncode(record,payload) || !SWV5S5_DomainDigest(SWV5S5_MVP_DOMAIN_ACCOUNT_RISK,payload,digest)) return false;
      m_failure="ACCOUNT_AUTHORITY_CAS_OR_READBACK";
      if(!store.CompareAndSetWithGuard(SWV5S5_MVP_DOMAIN_ACCOUNT_RISK,"CURRENT",0,"","",0,1,1,digest,payload,
         context.clock_time,guard.domain_key,guard.record_key,guard.logical_revision,guard.store_revision,guard.payload_digest,
         guard.state,committed) || !ValidateCurrent(store,scope,observed.profile,record,row) ||
         row.store_revision!=committed.store_revision) return false;
      m_failure=""; return true;
   }
};

#endif // SW_V5_S5_MVP_ACCOUNT_RISK_AUTHORITY_MQH
