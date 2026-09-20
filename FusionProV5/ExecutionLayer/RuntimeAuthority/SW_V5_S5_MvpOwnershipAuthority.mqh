#ifndef SW_V5_S5_MVP_OWNERSHIP_AUTHORITY_MQH
#define SW_V5_S5_MVP_OWNERSHIP_AUTHORITY_MQH

// CONTROLLED DEMO MVP OWNERSHIP AUTHORITY.
// Physical SQLite authority only. No broker mutation, retry, heartbeat, release,
// or takeover path is implemented here.

#include "SW_V5_S5_MvpManualProvisioningAuthorities.mqh"

const string SWV5S5_MVP_OWNERSHIP_CLOCK_KEY="LEASE_CLOCK_CURRENT";
const string SWV5S5_MVP_OWNERSHIP_CLOCK_FORMAT="SWV5-MVP-LEASE-CLOCK-PHYSICAL-V1";
const string SWV5S5_MVP_OWNERSHIP_CLOCK_ID_PREFIX="SWV5-MQL5-TIMECURRENT-LAST-KNOWN-SERVER-V1";
const string SWV5S5_MVP_OWNERSHIP_NAMESPACE_DOMAIN="SWV5-S5-PHASE-D1-OWNERSHIP-NAMESPACE";
const string SWV5S5_MVP_OWNERSHIP_FENCE_DOMAIN="SWV5-S5-PHASE-D1-OWNERSHIP-FENCE";
const string SWV5S5_MVP_LEASE_RECORD_REVISION_DOMAIN="SWV5-S5-MVP-LEASE-RECORD-REVISION-V1";

enum SWV5S5_MvpLeaseClockSource
{
   SWV5S5_MVP_CLOCK_SOURCE_NONE=0,
   SWV5S5_MVP_CLOCK_SOURCE_CURRENT_SYMBOL_ONTICK=1,
   SWV5S5_MVP_CLOCK_SOURCE_ONINIT=2,
   SWV5S5_MVP_CLOCK_SOURCE_ONTIMER=3
};

struct SWV5S5_MvpLeaseClockObservation
{
   string clock_id;
   SWV5_TimeAuthority clock_authority;
   datetime observed_at;
   ulong clock_sequence;
   string broker_identity;
   string server;
   long account_login;
   string source_symbol;
   SWV5S5_MvpLeaseClockSource source;
   string platform_observation_id;
};

enum SWV5S5_MvpInitialAcquireDisposition
{
   SWV5S5_MVP_ACQUIRE_REJECTED=0,
   SWV5S5_MVP_ACQUIRED_NOW=1,
   SWV5S5_MVP_ACQUIRE_PRIOR_STATE_REMAINS=2,
   SWV5S5_MVP_ACQUIRE_EXACT_PROPOSAL_DURABLE=3,
   SWV5S5_MVP_ACQUIRE_CONFLICTING_STATE=4
};

struct SWV5S5_MvpInitialAcquireResult
{
   SWV5S5_MvpInitialAcquireDisposition disposition;
   bool acquired_now;
   string reason_code;
   SWV5_InstanceLease proposed_lease;
   SWV5_InstanceLease authoritative_lease;
   SWV5S5_MvpAuthorityRow authoritative_row;
};

bool SWV5S5_MvpOwnershipKeyComplete(const SWV5_OwnershipKey &key)
{
   return key.account_login>0 && key.broker_identity!="" && key.server!="" &&
      key.symbol==SWV5S5_MVP_SYMBOL && key.strategy_id==SWV5S5_MVP_PROFILE_ID &&
      key.magic==SWV5_RUNTIME_STRATEGY_MAGIC;
}

bool SWV5S5_MvpOwnerComplete(const SWV5_OwnerIdentity &owner)
{
   return SWV5S5_MvpOwnershipKeyComplete(owner.key) && owner.instance_id!="" &&
      owner.process_fingerprint!="" && owner.started_at>0;
}

bool SWV5S5_MvpOwnershipNamespaceDigest(const SWV5_OwnershipKey &key,string &digest)
{
   string canonical;
   return SWV5S5_MvpOwnershipKeyComplete(key) &&
      SWV5S5_CanonicalOwnershipKey("ownership_namespace",key,canonical) &&
      SWV5S5_DomainDigest(SWV5S5_MVP_OWNERSHIP_NAMESPACE_DOMAIN,canonical,digest);
}

bool SWV5S5_MvpDeriveFenceToken(const SWV5_OwnershipFence &fence,string &digest)
{
   string body="",field;
   if(!SWV5S5_CanonicalOwnershipKey("namespace",fence.ownership_namespace,field)) return false; body+=field;
   if(!SWV5S5_CanonicalOwnershipKey("owner_key",fence.owner.key,field)) return false; body+=field;
   if(!SWV5S5_CanonicalString("instance",fence.owner.instance_id,field)) return false; body+=field;
   if(!SWV5S5_CanonicalString("process",fence.owner.process_fingerprint,field)) return false; body+=field;
   if(!SWV5S5_CanonicalDatetime("started_at",fence.owner.started_at,field)) return false; body+=field;
   if(!SWV5S5_CanonicalUInt("lease_version",fence.lease_version,field)) return false; body+=field;
   if(!SWV5S5_CanonicalUInt("takeover_generation",fence.takeover_generation,field)) return false; body+=field;
   return SWV5S5_DomainDigest(SWV5S5_MVP_OWNERSHIP_FENCE_DOMAIN,body,digest);
}

bool SWV5S5_MvpLeaseClockId(const string broker_identity,const string server,const long account_login,
                            const string symbol,string &clock_id)
{
   if(broker_identity=="" || server=="" || account_login<=0 || symbol!=SWV5S5_MVP_SYMBOL) return false;
   clock_id=SWV5S5_MVP_OWNERSHIP_CLOCK_ID_PREFIX+"/"+broker_identity+"/"+server+"/"+
      IntegerToString(account_login)+"/"+symbol;
   return true;
}

bool SWV5S5_MvpLeaseClockPayload(const SWV5S5_MvpLeaseClockObservation &observation,string &payload,string &digest)
{
   payload=""; string field;
   if(!SWV5S5_CanonicalString("physical_format",SWV5S5_MVP_OWNERSHIP_CLOCK_FORMAT,field)) return false; payload+=field;
   if(!SWV5S5_CanonicalString("clock_id",observation.clock_id,field)) return false; payload+=field;
   if(!SWV5S5_CanonicalInt("clock_authority",observation.clock_authority,field)) return false; payload+=field;
   if(!SWV5S5_CanonicalDatetime("observed_at",observation.observed_at,field)) return false; payload+=field;
   if(!SWV5S5_CanonicalUInt("clock_sequence",observation.clock_sequence,field)) return false; payload+=field;
   if(!SWV5S5_CanonicalString("broker_identity",observation.broker_identity,field)) return false; payload+=field;
   if(!SWV5S5_CanonicalString("server",observation.server,field)) return false; payload+=field;
   if(!SWV5S5_CanonicalInt("account_login",observation.account_login,field)) return false; payload+=field;
   if(!SWV5S5_CanonicalString("source_symbol",observation.source_symbol,field)) return false; payload+=field;
   if(!SWV5S5_CanonicalInt("source",observation.source,field)) return false; payload+=field;
   if(!SWV5S5_CanonicalString("platform_observation_id",observation.platform_observation_id,field)) return false; payload+=field;
   return SWV5S5_DomainDigest(SWV5S5_MVP_DOMAIN_OWNERSHIP,payload,digest);
}

bool SWV5S5_MvpDecodeLeaseClockPayload(const string payload,SWV5S5_MvpLeaseClockObservation &observation)
{
   ZeroMemory(observation); SWV5S5_MvpCodecReader reader; reader.Init(payload);
   string format; long number=0;
   if(!reader.ReadString("physical_format",format) || format!=SWV5S5_MVP_OWNERSHIP_CLOCK_FORMAT ||
      !reader.ReadString("clock_id",observation.clock_id) ||
      !reader.ReadInteger("clock_authority",number)) return false;
   observation.clock_authority=(SWV5_TimeAuthority)number;
   if(!reader.ReadInteger("observed_at",number)) return false; observation.observed_at=(datetime)number;
   if(!reader.ReadUnsigned("clock_sequence",observation.clock_sequence) ||
      !reader.ReadString("broker_identity",observation.broker_identity) ||
      !reader.ReadString("server",observation.server) ||
      !reader.ReadInteger("account_login",observation.account_login) ||
      !reader.ReadString("source_symbol",observation.source_symbol) ||
      !reader.ReadInteger("source",number)) return false;
   observation.source=(SWV5S5_MvpLeaseClockSource)number;
   return reader.ReadString("platform_observation_id",observation.platform_observation_id) && reader.AtEnd();
}

bool SWV5S5_MvpLeaseClockObservationValid(const SWV5S5_MvpLeaseClockObservation &observation)
{
   string expected_id;
   return SWV5S5_MvpLeaseClockId(observation.broker_identity,observation.server,
      observation.account_login,observation.source_symbol,expected_id) &&
      observation.clock_id==expected_id &&
      observation.clock_authority==SWV5_TIME_AUTHORITY_BROKER_SERVER &&
      observation.observed_at>0 && observation.clock_sequence>0 &&
      observation.source_symbol==SWV5S5_MVP_SYMBOL &&
      observation.source==SWV5S5_MVP_CLOCK_SOURCE_CURRENT_SYMBOL_ONTICK &&
      observation.platform_observation_id!="";
}

class SWV5S5_MvpLeaseClockAuthority
{
private:
   SWV5S5_MvpSqliteAuthorityStore m_store;
   bool m_fresh_since_open;
   SWV5S5_MvpLeaseClockObservation m_fresh;

   bool LoadVerified(SWV5S5_MvpLeaseClockObservation &observation,
                     SWV5S5_MvpAuthorityRow &row,bool &found)
   {
      ZeroMemory(observation); ZeroMemory(row); found=false;
      if(!m_store.ReadRow(SWV5S5_MVP_DOMAIN_OWNERSHIP,SWV5S5_MVP_OWNERSHIP_CLOCK_KEY,row,found)) return false;
      if(!found) return true;
      string payload,digest,physical_revision;
      if(row.logical_revision==0 || row.state!=1 ||
         !SWV5S5_MvpDecodeLeaseClockPayload(row.payload,observation) ||
         !SWV5S5_MvpLeaseClockObservationValid(observation) ||
         !SWV5S5_MvpLeaseClockPayload(observation,payload,digest) || payload!=row.payload ||
         digest!=row.payload_digest || observation.clock_sequence!=row.logical_revision ||
         !m_store.DeriveStoreRevision(row.domain_key,row.record_key,row.logical_revision,
            row.payload_digest,physical_revision) || physical_revision!=row.store_revision)
      { ZeroMemory(observation); ZeroMemory(row); found=false; return false; }
      return true;
   }

public:
   SWV5S5_MvpLeaseClockAuthority(void) { m_fresh_since_open=false; ZeroMemory(m_fresh); }

   bool Configure(const string relative_path,const string namespace_digest)
   {
      m_fresh_since_open=false; ZeroMemory(m_fresh);
      return m_store.Open(relative_path,namespace_digest);
   }

   void Close(void) { m_store.Close(); m_fresh_since_open=false; ZeroMemory(m_fresh); }

   bool LoadStored(SWV5S5_MvpLeaseClockObservation &observation,
                   SWV5S5_MvpAuthorityRow &row,bool &found)
   { return LoadVerified(observation,row,found); }

   // Deterministic entry used by the real-MQL SQLite suite. Production callers
   // reach it only through ObserveFromCurrentSymbolOnTick below.
   bool ObserveAcceptedEvent(const SWV5S5_MvpLeaseClockSource source,const string event_symbol,
                             const string broker_identity,const string server,const long account_login,
                             const datetime broker_server_time,const string platform_observation_id,
                             SWV5S5_MvpLeaseClockObservation &accepted,SWV5S5_MvpAuthorityRow &committed)
   {
      ZeroMemory(accepted); ZeroMemory(committed);
      if(source!=SWV5S5_MVP_CLOCK_SOURCE_CURRENT_SYMBOL_ONTICK ||
         event_symbol!=SWV5S5_MVP_SYMBOL || broker_server_time<=0 ||
         platform_observation_id=="") return false;
      SWV5S5_MvpLeaseClockObservation prior; SWV5S5_MvpAuthorityRow prior_row; bool found=false;
      if(!LoadVerified(prior,prior_row,found)) return false;
      if(found && (broker_server_time<prior.observed_at ||
         platform_observation_id==prior.platform_observation_id)) return false;
      accepted.broker_identity=broker_identity; accepted.server=server;
      accepted.account_login=account_login; accepted.source_symbol=event_symbol;
      accepted.source=source; accepted.observed_at=broker_server_time;
      accepted.clock_sequence=(found ? prior.clock_sequence+1 : 1);
      accepted.clock_authority=SWV5_TIME_AUTHORITY_BROKER_SERVER;
      accepted.platform_observation_id=platform_observation_id;
      if(!SWV5S5_MvpLeaseClockId(broker_identity,server,account_login,event_symbol,accepted.clock_id) ||
         (found && accepted.clock_id!=prior.clock_id)) return false;
      string payload,digest;
      if(!SWV5S5_MvpLeaseClockPayload(accepted,payload,digest) ||
         !m_store.CompareAndSet(SWV5S5_MVP_DOMAIN_OWNERSHIP,SWV5S5_MVP_OWNERSHIP_CLOCK_KEY,
            (found ? prior_row.logical_revision : 0),(found ? prior_row.store_revision : ""),
            (found ? prior_row.payload_digest : ""),(found ? prior_row.state : 0),
            (found ? prior_row.logical_revision+1 : 1),1,digest,payload,broker_server_time,committed))
      { ZeroMemory(accepted); return false; }
      SWV5S5_MvpLeaseClockObservation readback; SWV5S5_MvpAuthorityRow readback_row; bool readback_found=false;
      if(!LoadVerified(readback,readback_row,readback_found) || !readback_found ||
         readback_row.store_revision!=committed.store_revision ||
         readback.platform_observation_id!=accepted.platform_observation_id ||
         readback.clock_sequence!=accepted.clock_sequence)
      { ZeroMemory(accepted); ZeroMemory(committed); return false; }
      m_fresh=readback; m_fresh_since_open=true; committed=readback_row; accepted=readback;
      return true;
   }

   // This is the only production clock sampler. It must be invoked directly by
   // the current XAUUSD OnTick handler; OnInit/OnTimer have no accepted route.
   bool ObserveFromCurrentSymbolOnTick(const string event_symbol,const string platform_observation_id,
                                       SWV5S5_MvpLeaseClockObservation &accepted,
                                       SWV5S5_MvpAuthorityRow &committed)
   {
      if(event_symbol!=SWV5S5_MVP_SYMBOL || _Symbol!=SWV5S5_MVP_SYMBOL) return false;
      const string broker=AccountInfoString(ACCOUNT_COMPANY);
      const string server=AccountInfoString(ACCOUNT_SERVER);
      const long login=AccountInfoInteger(ACCOUNT_LOGIN);
      const datetime broker_server_time=TimeCurrent();
      return ObserveAcceptedEvent(SWV5S5_MVP_CLOCK_SOURCE_CURRENT_SYMBOL_ONTICK,event_symbol,
         broker,server,login,broker_server_time,platform_observation_id,accepted,committed);
   }

   bool CurrentFreshObservation(SWV5S5_MvpLeaseClockObservation &observation)
   {
      ZeroMemory(observation);
      if(!m_fresh_since_open || !SWV5S5_MvpLeaseClockObservationValid(m_fresh)) return false;
      SWV5S5_MvpLeaseClockObservation current; SWV5S5_MvpAuthorityRow row; bool found=false;
      if(!LoadVerified(current,row,found) || !found ||
         current.clock_sequence!=m_fresh.clock_sequence ||
         current.platform_observation_id!=m_fresh.platform_observation_id) return false;
      observation=current; return true;
   }
};

bool SWV5S5_MvpDeriveLeaseRecordRevision(const SWV5_InstanceLease &lease,string &revision)
{
   string body="",field;
   if(!SWV5S5_CanonicalString("lifecycle_write","INITIAL_ACQUIRE",field)) return false; body+=field;
   if(!SWV5S5_CanonicalOwnershipKey("ownership_namespace",lease.fence.ownership_namespace,field)) return false; body+=field;
   if(!SWV5S5_CanonicalString("fencing_token_digest",lease.fence.fencing_token_digest,field)) return false; body+=field;
   if(!SWV5S5_CanonicalUInt("heartbeat_sequence",lease.heartbeat_sequence,field)) return false; body+=field;
   if(!SWV5S5_CanonicalUInt("clock_sequence",lease.heartbeat_clock_sequence,field)) return false; body+=field;
   if(!SWV5S5_CanonicalDatetime("heartbeat_at",lease.heartbeat_at,field)) return false; body+=field;
   return SWV5S5_DomainDigest(SWV5S5_MVP_LEASE_RECORD_REVISION_DOMAIN,body,revision);
}

bool SWV5S5_MvpGenesisRowValid(SWV5S5_MvpSqliteAuthorityStore &store,const string domain,
                               const string record_key,const int expected_state,
                               SWV5S5_MvpAuthorityRow &row)
{
   bool found=false; string digest,physical_revision;
   return store.ReadRow(domain,record_key,row,found) && found && row.logical_revision>0 &&
      row.state==expected_state && SWV5S5_DomainDigest(domain,row.payload,digest) &&
      digest==row.payload_digest && store.DeriveStoreRevision(row.domain_key,row.record_key,
      row.logical_revision,row.payload_digest,physical_revision) && physical_revision==row.store_revision;
}

class SWV5S5_MvpInitialOwnershipAuthority
{
private:
   SWV5S5_MvpSqliteAuthorityStore m_store;
   string m_namespace_digest;

   bool BuildProposed(const SWV5_OwnerIdentity &claimant,const uint lease_duration_seconds,
                      const SWV5S5_MvpLeaseClockObservation &clock,SWV5_InstanceLease &lease)
   {
      ZeroMemory(lease);
      if(!SWV5S5_MvpOwnerComplete(claimant) || claimant.started_at!=clock.observed_at ||
         lease_duration_seconds==0 ||
         lease_duration_seconds>SWV5S5_MVP_MANUAL_AUTHORITY_LIFETIME_SECONDS) return false;
      lease.contract_version.contract_name=SWV5_PRODUCTION_CONTRACT_NAME;
      lease.contract_version.schema_version=SWV5_PRODUCTION_CONTRACT_VERSION;
      lease.contract_version.minimum_compatible_version=SWV5_PRODUCTION_MINIMUM_COMPATIBLE_VERSION;
      lease.contract_version.policy_id=SWV5_PRODUCTION_CONTRACT_POLICY;
      lease.fence.contract_version=lease.contract_version;
      lease.fence.ownership_namespace=claimant.key; lease.fence.owner=claimant;
      lease.fence.lease_version=1; lease.fence.takeover_generation=0;
      if(!SWV5S5_MvpDeriveFenceToken(lease.fence,lease.fence.fencing_token_digest)) return false;
      lease.status=SWV5_LOCK_ACQUIRED; lease.heartbeat_sequence=1;
      lease.clock_id=clock.clock_id; lease.clock_authority=clock.clock_authority;
      lease.acquired_clock_sequence=clock.clock_sequence;
      lease.heartbeat_clock_sequence=clock.clock_sequence;
      lease.expiry_clock_sequence=clock.clock_sequence+(ulong)lease_duration_seconds;
      lease.acquired_at=clock.observed_at; lease.heartbeat_at=clock.observed_at;
      lease.expires_at=clock.observed_at+(datetime)lease_duration_seconds;
      return SWV5S5_MvpDeriveLeaseRecordRevision(lease,lease.store_revision);
   }

public:
   bool Configure(const string relative_path,const string namespace_digest)
   { m_namespace_digest=namespace_digest; return m_store.Open(relative_path,namespace_digest); }

   bool LoadCurrent(const SWV5_OwnershipKey &ownership_namespace,const SWV5_OwnershipFence &expected_fence,
                    SWV5_InstanceLease &lease,SWV5S5_MvpAuthorityRow &row)
   {
      SWV5S5_MvpLeasePublicationAuthority loader;
      return loader.LoadCurrentLease(m_store,ownership_namespace,expected_fence,lease,row);
   }

   bool LeaseCurrentForFreshClock(const SWV5_InstanceLease &lease,
                                  const SWV5S5_MvpLeaseClockObservation &clock)
   {
      SWV5_ContractValidationContext context; ZeroMemory(context);
      context.expected_version=lease.contract_version; context.clock_id=clock.clock_id;
      context.clock_authority=clock.clock_authority; context.clock_time=clock.observed_at;
      context.clock_sequence=clock.clock_sequence; context.evaluation_sequence=clock.clock_sequence;
      context.price_tolerance=0.0000001; context.volume_tolerance=0.0000001;
      return SWV5S5_MvpLeaseClockObservationValid(clock) &&
         SWV5S5_MvpLeaseCurrentForClock(context,lease.fence,lease);
   }

   bool AcquireInitial(const SWV5_OwnerIdentity &claimant,const uint lease_duration_seconds,
                       SWV5S5_MvpLeaseClockAuthority &clock_authority,
                       SWV5S5_MvpInitialAcquireResult &result)
   {
      ZeroMemory(result); result.disposition=SWV5S5_MVP_ACQUIRE_REJECTED;
      SWV5S5_MvpLeaseClockObservation clock;
      string expected_namespace;
      if(!SWV5S5_MvpOwnerComplete(claimant) ||
         !SWV5S5_MvpOwnershipNamespaceDigest(claimant.key,expected_namespace) ||
         expected_namespace!=m_namespace_digest ||
         !clock_authority.CurrentFreshObservation(clock) || claimant.started_at!=clock.observed_at ||
         claimant.key.account_login!=clock.account_login ||
         claimant.key.broker_identity!=clock.broker_identity || claimant.key.server!=clock.server ||
         claimant.key.symbol!=clock.source_symbol ||
         !BuildProposed(claimant,lease_duration_seconds,clock,result.proposed_lease))
      { result.reason_code="INITIAL_ACQUIRE_INPUT_REJECTED"; return false; }

      SWV5S5_MvpAuthorityRow global_genesis,ownership_genesis,current; bool current_found=false;
      if(!SWV5S5_MvpGenesisRowValid(m_store,SWV5S5_MVP_DOMAIN_GENESIS,"GENESIS",
            SWV5S5_MVP_GENESIS_READY_FOR_RECONCILIATION,global_genesis) ||
         !SWV5S5_MvpGenesisRowValid(m_store,SWV5S5_MVP_DOMAIN_OWNERSHIP,"GENESIS",
            (int)SWV5_LOCK_UNCLAIMED,ownership_genesis) ||
         !m_store.ReadRow(SWV5S5_MVP_DOMAIN_OWNERSHIP,SWV5S5_MVP_OWNERSHIP_KEY,current,current_found))
      { result.reason_code="INITIAL_ACQUIRE_GENESIS_INVALID"; return false; }
      if(current_found)
      {
         SWV5_InstanceLease decoded_existing;
         if(SWV5S5_MvpDecodeOwnershipLeasePhysical(current.payload,decoded_existing) &&
            SWV5S5_MvpLeaseExact(decoded_existing,result.proposed_lease))
         {
            result.authoritative_lease=decoded_existing; result.authoritative_row=current;
            result.disposition=SWV5S5_MVP_ACQUIRE_EXACT_PROPOSAL_DURABLE;
            result.reason_code="EXACT_PROPOSAL_DURABLE_NO_EVENT_LOCAL_GRANT";
         }
         else
         {
            result.disposition=SWV5S5_MVP_ACQUIRE_CONFLICTING_STATE;
            result.reason_code="CURRENT_LEASE_ALREADY_EXISTS";
         }
         return false;
      }

      SWV5S5_LeaseLivenessAuthorityView view; view.lease=result.proposed_lease;
      string payload;
      if(!SWV5S5_DeriveLeaseProjection(view))
      { result.reason_code="INITIAL_ACQUIRE_PROJECTION_INVALID"; return false; }
      if(!SWV5S5_MvpEncodeOwnershipLeasePhysical(result.proposed_lease,payload))
      { result.reason_code="INITIAL_ACQUIRE_ENCODING_INVALID"; return false; }
      SWV5S5_MvpAuthorityRow committed;
      const bool won=m_store.CompareAndSetWithGuard(SWV5S5_MVP_DOMAIN_OWNERSHIP,
         SWV5S5_MVP_OWNERSHIP_KEY,0,"","",0,1,(int)SWV5_LOCK_ACQUIRED,
         view.projection_digest,payload,clock.observed_at,
         SWV5S5_MVP_DOMAIN_OWNERSHIP,"GENESIS",ownership_genesis.logical_revision,
         ownership_genesis.store_revision,ownership_genesis.payload_digest,ownership_genesis.state,committed);
      if(won)
      {
         if(!LoadCurrent(result.proposed_lease.fence.ownership_namespace,result.proposed_lease.fence,
                         result.authoritative_lease,result.authoritative_row) ||
            !SWV5S5_MvpLeaseExact(result.proposed_lease,result.authoritative_lease))
         { result.reason_code="INITIAL_ACQUIRE_READBACK_FAILED"; return false; }
         result.disposition=SWV5S5_MVP_ACQUIRED_NOW; result.acquired_now=true;
         result.reason_code="INITIAL_ACQUIRE_COMMITTED_AND_READ_BACK"; return true;
      }

      // Commit uncertainty is resolved only by authoritative readback. Exact
      // durability is reported but never reconstructed as event-local success.
      SWV5S5_MvpAuthorityRow observed; bool observed_found=false;
      if(!m_store.ReadRow(SWV5S5_MVP_DOMAIN_OWNERSHIP,SWV5S5_MVP_OWNERSHIP_KEY,
                          observed,observed_found))
      { result.reason_code="INITIAL_ACQUIRE_OUTCOME_UNREADABLE"; return false; }
      if(!observed_found)
      { result.disposition=SWV5S5_MVP_ACQUIRE_PRIOR_STATE_REMAINS; result.reason_code="PRIOR_STATE_REMAINS"; return false; }
      SWV5_InstanceLease decoded;
      if(SWV5S5_MvpDecodeOwnershipLeasePhysical(observed.payload,decoded) &&
         SWV5S5_MvpLeaseExact(decoded,result.proposed_lease) &&
         observed.payload_digest==view.projection_digest)
      {
         result.authoritative_lease=decoded; result.authoritative_row=observed;
         result.disposition=SWV5S5_MVP_ACQUIRE_EXACT_PROPOSAL_DURABLE;
         result.reason_code="EXACT_PROPOSAL_DURABLE_NO_EVENT_LOCAL_GRANT"; return false;
      }
      result.disposition=SWV5S5_MVP_ACQUIRE_CONFLICTING_STATE;
      result.reason_code="CONFLICTING_CURRENT_LEASE"; return false;
   }
};

#endif // SW_V5_S5_MVP_OWNERSHIP_AUTHORITY_MQH
