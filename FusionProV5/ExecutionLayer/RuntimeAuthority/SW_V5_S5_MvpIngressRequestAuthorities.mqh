#ifndef SW_V5_S5_MVP_INGRESS_REQUEST_AUTHORITIES_MQH
#define SW_V5_S5_MVP_INGRESS_REQUEST_AUTHORITIES_MQH

// CONTROLLED DEMO MVP PHYSICAL AUTHORITIES.
// Durable request bootstrap only. No broker access and no submission retry path.

#include "SW_V5_S5_MvpAuthorityRecordCodec.mqh"

const string SWV5S5_MVP_DOMAIN_INGRESS_LEDGER="MVP_INGRESS_LEDGER";
const string SWV5S5_MVP_DOMAIN_REQUEST_SEQUENCE="MVP_REQUEST_SEQUENCE";
const string SWV5S5_MVP_DOMAIN_REQUEST_SET="MVP_EXECUTION_PENDING_STATE";
const string SWV5S5_MVP_CURRENT_KEY="CURRENT";
const string SWV5S5_MVP_REQUEST_SET_KEY="REQUEST_SET";
const string SWV5S5_MVP_BOUND_REQUEST_ID_DOMAIN="SWV5-SPRINT5-LEDGER-BOUND-REQUEST-ID-V1";

void SWV5S5_MvpInitV5Version(SWV5_ContractVersion &version)
{
   ZeroMemory(version);
   version.contract_name=SWV5_PRODUCTION_CONTRACT_NAME;
   version.schema_version=SWV5_PRODUCTION_CONTRACT_VERSION;
   version.minimum_compatible_version=SWV5_PRODUCTION_MINIMUM_COMPATIBLE_VERSION;
   version.policy_id=SWV5_PRODUCTION_CONTRACT_POLICY;
}

bool SWV5S5_MvpDeriveBoundRequestId(const SWV5_ExecutionRequestIdentity &identity,
                                    string &bound_request_id)
{
   string body;
   if(identity.request_id.correlation_id=="" || identity.request_id.attempt_id=="" ||
      identity.request_id.monotonic_sequence==0 || identity.request_id.created_at<=0 ||
      identity.idempotency_key=="" ||
      !SWV5S5_CanonicalRequestIdentity("request_identity",identity,body)) return false;
   return SWV5S5_DomainDigest(SWV5S5_MVP_BOUND_REQUEST_ID_DOMAIN,body,bound_request_id) &&
          SWV5S5_IsDigest64Lower(bound_request_id);
}

bool SWV5S5_MvpBuildRequestBindingSeed(const SWV5_PersistenceNamespace &persistence_namespace,
                                       const string ingress_identity,const datetime accepted_at,
                                       const ulong reserved_sequence,SWV5S5_RequestBinding &binding,
                                       SWV5_ExecutionRequestIdentity &identity)
{
   ZeroMemory(binding); ZeroMemory(identity);
   if(accepted_at<=0 || reserved_sequence==0) return false;
   SWV5S5_InitContractVersion(binding.contract_version);
   binding.binding_policy_id=SWV5S5_REQUEST_BINDING_POLICY_ID;
   binding.binding_policy_version=SWV5S5_REQUEST_BINDING_POLICY_VERSION;
   binding.persistence_namespace=persistence_namespace;
   binding.accepted_ingress_identity=ingress_identity;
   binding.accepted_at=accepted_at;
   binding.logical_request_sequence=reserved_sequence;
   binding.attempt_ordinal=0;
   if(!SWV5S5_DeriveRequestBinding(persistence_namespace,binding.binding_policy_id,
      binding.binding_policy_version,ingress_identity,binding.attempt_ordinal,
      binding.logical_correlation_id,binding.attempt_id,binding.idempotency_key) ||
      !SWV5S5_DeriveRequestBindingDigest(binding,binding.binding_digest)) return false;
   SWV5S5_MvpInitV5Version(identity.contract_version);
   identity.request_id.correlation_id=binding.logical_correlation_id;
   identity.request_id.attempt_id=binding.attempt_id;
   identity.request_id.parent_attempt_id="";
   identity.request_id.monotonic_sequence=binding.logical_request_sequence;
   identity.request_id.created_at=binding.accepted_at;
   identity.idempotency_key=binding.idempotency_key;
   return true;
}

bool SWV5S5_MvpEncodeSequenceState(const SWV5S5_RequestSequenceAuthority &authority,
                                   const SWV5S5_RequestSequenceIndexEntry &entries[],string &payload)
{
   payload=""; string nested,f;
   if(!SWV5S5_MvpCodecEncode_SWV5_ContractVersion(authority.contract_version,nested) ||
      !SWV5S5_CanonicalNested("contract_version",nested,f)) return false; payload+=f;
   if(!SWV5S5_CanonicalString("policy_id",authority.policy_id,f)) return false; payload+=f;
   if(!SWV5S5_CanonicalUInt("policy_version",authority.policy_version,f)) return false; payload+=f;
   if(!SWV5S5_MvpCodecEncode_SWV5_PersistenceNamespace(authority.persistence_namespace,nested) ||
      !SWV5S5_CanonicalNested("persistence_namespace",nested,f)) return false; payload+=f;
   if(!SWV5S5_MvpCodecEncode_SWV5_OwnershipFence(authority.ownership_fence,nested) ||
      !SWV5S5_CanonicalNested("ownership_fence",nested,f)) return false; payload+=f;
   if(!SWV5S5_CanonicalUInt("allocator_revision",authority.allocator_revision,f)) return false; payload+=f;
   if(!SWV5S5_CanonicalUInt("request_sequence_high_watermark",authority.request_sequence_high_watermark,f)) return false; payload+=f;
   if(!SWV5S5_CanonicalUInt("reservation_count",authority.reservation_count,f)) return false; payload+=f;
   if(!SWV5S5_CanonicalString("reservation_index_digest",authority.reservation_index_digest,f)) return false; payload+=f;
   if(!SWV5S5_CanonicalString("authority_digest",authority.authority_digest,f)) return false; payload+=f;
   if(!SWV5S5_CanonicalUInt("entries_count",(ulong)ArraySize(entries),f)) return false; payload+=f;
   for(int i=0;i<ArraySize(entries);i++)
   {
      nested="";
      if(!SWV5S5_CanonicalString("logical_correlation_id",entries[i].logical_correlation_id,f)) return false; nested+=f;
      if(!SWV5S5_CanonicalUInt("reserved_sequence",entries[i].reserved_sequence,f)) return false; nested+=f;
      if(!SWV5S5_CanonicalUInt("reservation_revision",entries[i].reservation_revision,f)) return false; nested+=f;
      if(!SWV5S5_CanonicalString("binding_digest",entries[i].binding_digest,f)) return false; nested+=f;
      if(!SWV5S5_CanonicalNested("entry_"+IntegerToString(i),nested,f)) return false; payload+=f;
   }
   return true;
}

bool SWV5S5_MvpDecodeSequenceState(const string payload,SWV5S5_RequestSequenceAuthority &authority,
                                   SWV5S5_RequestSequenceIndexEntry &entries[])
{
   ZeroMemory(authority); ArrayResize(entries,0);
   SWV5S5_MvpCodecReader reader; reader.Init(payload); string nested; ulong count=0; long number=0;
   if(!reader.ReadNested("contract_version",nested) ||
      !SWV5S5_MvpCodecDecode_SWV5_ContractVersion(nested,authority.contract_version) ||
      !reader.ReadString("policy_id",authority.policy_id) ||
      !reader.ReadUnsigned("policy_version",authority.policy_version) ||
      !reader.ReadNested("persistence_namespace",nested) ||
      !SWV5S5_MvpCodecDecode_SWV5_PersistenceNamespace(nested,authority.persistence_namespace) ||
      !reader.ReadNested("ownership_fence",nested) ||
      !SWV5S5_MvpCodecDecode_SWV5_OwnershipFence(nested,authority.ownership_fence) ||
      !reader.ReadUnsigned("allocator_revision",authority.allocator_revision) ||
      !reader.ReadUnsigned("request_sequence_high_watermark",authority.request_sequence_high_watermark) ||
      !reader.ReadUnsigned("reservation_count",authority.reservation_count) ||
      !reader.ReadString("reservation_index_digest",authority.reservation_index_digest) ||
      !reader.ReadString("authority_digest",authority.authority_digest) ||
      !reader.ReadUnsigned("entries_count",count) || count>100000) return false;
   ArrayResize(entries,(int)count);
   for(ulong i=0;i<count;i++)
   {
      if(!reader.ReadNested("entry_"+IntegerToString((long)i),nested)) return false;
      SWV5S5_MvpCodecReader entry; entry.Init(nested);
      if(!entry.ReadString("logical_correlation_id",entries[(int)i].logical_correlation_id) ||
         !entry.ReadUnsigned("reserved_sequence",entries[(int)i].reserved_sequence) ||
         !entry.ReadUnsigned("reservation_revision",entries[(int)i].reservation_revision) ||
         !entry.ReadString("binding_digest",entries[(int)i].binding_digest) || !entry.AtEnd()) return false;
   }
   return reader.AtEnd();
}

class SWV5S5_MvpRequestSequenceAuthority : public ISWV5S5RequestSequenceAuthority
{
private:
   SWV5S5_MvpSqliteAuthorityStore m_store;
   bool LoadRow(SWV5S5_RequestSequenceAuthority &authority,SWV5S5_RequestSequenceIndexEntry &entries[],
                SWV5S5_MvpAuthorityRow &row)
   {
      bool found=false; string digest,authority_digest,index_digest;
      return m_store.ReadRow(SWV5S5_MVP_DOMAIN_REQUEST_SEQUENCE,SWV5S5_MVP_CURRENT_KEY,row,found) && found &&
         SWV5S5_DomainDigest(SWV5S5_MVP_DOMAIN_REQUEST_SEQUENCE,row.payload,digest) && digest==row.payload_digest &&
         SWV5S5_MvpDecodeSequenceState(row.payload,authority,entries) &&
         SWV5S5_DeriveSequenceIndexDigest(entries,index_digest) && index_digest==authority.reservation_index_digest &&
         SWV5S5_DeriveSequenceAuthorityDigest(authority,entries,authority_digest) && authority_digest==authority.authority_digest;
   }
public:
   bool Configure(const string relative_path,const string namespace_digest)
   { return m_store.Open(relative_path,namespace_digest); }

   bool Initialize(const SWV5_PersistenceNamespace &persistence_namespace,
                   const SWV5_OwnershipFence &ownership_fence,const datetime now)
   {
      SWV5S5_MvpAuthorityRow row; bool found=false;
      if(!m_store.ReadRow(SWV5S5_MVP_DOMAIN_REQUEST_SEQUENCE,SWV5S5_MVP_CURRENT_KEY,row,found)) return false;
      if(found)
      {
         SWV5S5_RequestSequenceAuthority loaded; SWV5S5_RequestSequenceIndexEntry entries[];
         return LoadRow(loaded,entries,row) && SWV5S5_EqualNamespace(loaded.persistence_namespace,persistence_namespace) &&
            SWV5S5_EqualFence(loaded.ownership_fence,ownership_fence);
      }
      SWV5S5_RequestSequenceAuthority authority; ZeroMemory(authority);
      SWV5S5_RequestSequenceIndexEntry entries[];
      SWV5S5_InitContractVersion(authority.contract_version);
      authority.policy_id=SWV5S5_REQUEST_BINDING_POLICY_ID;
      authority.policy_version=SWV5S5_REQUEST_BINDING_POLICY_VERSION;
      authority.persistence_namespace=persistence_namespace; authority.ownership_fence=ownership_fence;
      if(!SWV5S5_DeriveSequenceIndexDigest(entries,authority.reservation_index_digest) ||
         !SWV5S5_DeriveSequenceAuthorityDigest(authority,entries,authority.authority_digest)) return false;
      string payload,digest;
      if(!SWV5S5_MvpEncodeSequenceState(authority,entries,payload) ||
         !SWV5S5_DomainDigest(SWV5S5_MVP_DOMAIN_REQUEST_SEQUENCE,payload,digest)) return false;
      return m_store.CompareAndSet(SWV5S5_MVP_DOMAIN_REQUEST_SEQUENCE,SWV5S5_MVP_CURRENT_KEY,
         0,"","",0,1,1,digest,payload,now,row);
   }

   bool ReadState(SWV5S5_RequestSequenceAuthority &authority,SWV5S5_RequestSequenceIndexEntry &entries[])
   { SWV5S5_MvpAuthorityRow row; return LoadRow(authority,entries,row); }

   virtual bool TryReserveRequestSequence(const SWV5S5_RequestSequenceAuthority &expected,
                                          const SWV5S5_RequestSequenceIndexEntry &expected_entries[],
                                          const SWV5S5_RequestSequenceReservation &proposal,
                                          SWV5S5_RequestSequenceResult &result)
   {
      ZeroMemory(result); SWV5S5_RequestSequenceAuthority current; SWV5S5_RequestSequenceIndexEntry entries[];
      SWV5S5_MvpAuthorityRow row;
      string expected_payload,current_payload;
      if(!LoadRow(current,entries,row) || !SWV5S5_MvpEncodeSequenceState(expected,expected_entries,expected_payload) ||
         !SWV5S5_MvpEncodeSequenceState(current,entries,current_payload) || expected_payload!=current_payload ||
         !SWV5S5_PrepareSequenceReservation(current,entries,proposal,result)) return false;
      if(result.disposition==SWV5S5_SEQUENCE_EXISTING_IDEMPOTENT) return true;
      if(result.disposition!=SWV5S5_SEQUENCE_PROPOSAL_VALID) return false;
      SWV5S5_RequestSequenceAuthority next=current;
      SWV5S5_RequestSequenceIndexEntry next_entries[]; const int count=ArraySize(entries);
      ArrayResize(next_entries,count+1); int insert=count;
      for(int i=0;i<count;i++) if(insert==count && StringCompare(proposal.logical_correlation_id,entries[i].logical_correlation_id)<0) insert=i;
      for(int i=0;i<insert;i++) next_entries[i]=entries[i];
      next_entries[insert].logical_correlation_id=proposal.logical_correlation_id;
      next_entries[insert].reserved_sequence=proposal.proposed_sequence;
      next_entries[insert].reservation_revision=proposal.proposed_allocator_revision;
      next_entries[insert].binding_digest=proposal.binding_digest;
      for(int i=insert;i<count;i++) next_entries[i+1]=entries[i];
      next.allocator_revision=proposal.proposed_allocator_revision;
      next.request_sequence_high_watermark=proposal.proposed_sequence;
      next.reservation_count=(uint)(count+1);
      if(!SWV5S5_DeriveSequenceIndexDigest(next_entries,next.reservation_index_digest) ||
         !SWV5S5_DeriveSequenceAuthorityDigest(next,next_entries,next.authority_digest)) return false;
      string payload,digest;
      if(!SWV5S5_MvpEncodeSequenceState(next,next_entries,payload) ||
         !SWV5S5_DomainDigest(SWV5S5_MVP_DOMAIN_REQUEST_SEQUENCE,payload,digest)) return false;
      SWV5S5_MvpAuthorityRow committed;
      if(!m_store.CompareAndSet(SWV5S5_MVP_DOMAIN_REQUEST_SEQUENCE,SWV5S5_MVP_CURRENT_KEY,
         row.logical_revision,row.store_revision,row.payload_digest,row.state,row.logical_revision+1,1,
         digest,payload,(datetime)proposal.proposed_allocator_revision,committed)) return false;
      SWV5S5_RequestSequenceAuthority readback; SWV5S5_RequestSequenceIndexEntry readback_entries[];
      SWV5S5_MvpAuthorityRow readback_row;
      if(!LoadRow(readback,readback_entries,readback_row) || readback.authority_digest!=next.authority_digest) return false;
      SWV5S5_InitContractVersion(result.contract_version); result.disposition=SWV5S5_SEQUENCE_RESERVED_NEW;
      result.logical_correlation_id=proposal.logical_correlation_id; result.reserved_sequence=proposal.proposed_sequence;
      result.resulting_allocator_revision=next.allocator_revision; result.resulting_authority_digest=next.authority_digest;
      result.reason_code="SEQUENCE_RESERVED_NEW"; return true;
   }
};

bool SWV5S5_MvpEncodeLedgerHeader(const SWV5S5_IngressLedgerHeader &v,string &body)
{
   body=""; string nested,f;
   if(!SWV5S5_MvpCodecEncode_SWV5_ContractVersion(v.contract_version,nested) || !SWV5S5_CanonicalNested("contract_version",nested,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("policy_id",v.policy_id,f)) return false; body+=f;
   if(!SWV5S5_MvpCodecEncode_SWV5_PersistenceNamespace(v.persistence_namespace,nested) || !SWV5S5_CanonicalNested("persistence_namespace",nested,f)) return false; body+=f;
   if(!SWV5S5_MvpCodecEncode_SWV5_OwnershipFence(v.ownership_fence,nested) || !SWV5S5_CanonicalNested("ownership_fence",nested,f)) return false; body+=f;
#define MVP_LH_S(n,x) if(!SWV5S5_CanonicalString(n,x,f)) return false; else body+=f
#define MVP_LH_U(n,x) if(!SWV5S5_CanonicalUInt(n,x,f)) return false; else body+=f
   MVP_LH_S("producer_authority_record_id",v.producer_authority_record_id); MVP_LH_U("producer_authority_generation",v.producer_authority_generation);
   MVP_LH_S("producer_instance",v.producer_instance); MVP_LH_U("producer_epoch",v.producer_epoch);
   MVP_LH_U("highest_accepted_publication_sequence",v.highest_accepted_publication_sequence); MVP_LH_U("revision",v.revision);
   MVP_LH_U("previous_revision",v.previous_revision); MVP_LH_U("compaction_generation",v.compaction_generation);
   MVP_LH_U("membership_count",v.membership_count); MVP_LH_S("membership_binding_index_digest",v.membership_binding_index_digest);
   MVP_LH_S("ledger_digest",v.ledger_digest);
#undef MVP_LH_S
#undef MVP_LH_U
   return true;
}

bool SWV5S5_MvpDecodeLedgerHeader(const string text,SWV5S5_IngressLedgerHeader &v)
{
   ZeroMemory(v); SWV5S5_MvpCodecReader r; r.Init(text); string nested;
   return r.ReadNested("contract_version",nested) && SWV5S5_MvpCodecDecode_SWV5_ContractVersion(nested,v.contract_version) &&
      r.ReadString("policy_id",v.policy_id) && r.ReadNested("persistence_namespace",nested) &&
      SWV5S5_MvpCodecDecode_SWV5_PersistenceNamespace(nested,v.persistence_namespace) &&
      r.ReadNested("ownership_fence",nested) && SWV5S5_MvpCodecDecode_SWV5_OwnershipFence(nested,v.ownership_fence) &&
      r.ReadString("producer_authority_record_id",v.producer_authority_record_id) &&
      r.ReadUnsigned("producer_authority_generation",v.producer_authority_generation) &&
      r.ReadString("producer_instance",v.producer_instance) && r.ReadUnsigned("producer_epoch",v.producer_epoch) &&
      r.ReadUnsigned("highest_accepted_publication_sequence",v.highest_accepted_publication_sequence) &&
      r.ReadUnsigned("revision",v.revision) && r.ReadUnsigned("previous_revision",v.previous_revision) &&
      r.ReadUnsigned("compaction_generation",v.compaction_generation) && r.ReadUnsigned("membership_count",v.membership_count) &&
      r.ReadString("membership_binding_index_digest",v.membership_binding_index_digest) &&
      r.ReadString("ledger_digest",v.ledger_digest) && r.AtEnd();
}

bool SWV5S5_MvpEncodeLedgerRecord(const SWV5S5_IngressLedgerRecord &v,string &body)
{
   body=""; string nested,f;
   if(!SWV5S5_MvpCodecEncode_SWV5_ContractVersion(v.contract_version,nested) || !SWV5S5_CanonicalNested("contract_version",nested,f)) return false; body+=f;
#define MVP_LR_S(n,x) if(!SWV5S5_CanonicalString(n,x,f)) return false; else body+=f
#define MVP_LR_U(n,x) if(!SWV5S5_CanonicalUInt(n,x,f)) return false; else body+=f
#define MVP_LR_I(n,x) if(!SWV5S5_CanonicalInt(n,x,f)) return false; else body+=f
   MVP_LR_S("ingress_identity",v.ingress_identity); MVP_LR_S("payload_digest",v.payload_digest); MVP_LR_U("publication_sequence",v.publication_sequence);
   MVP_LR_I("lifecycle_state",v.lifecycle_state); MVP_LR_S("logical_correlation_id",v.logical_correlation_id);
   MVP_LR_U("reserved_request_sequence",v.reserved_request_sequence); MVP_LR_I("accepted_at",v.accepted_at);
   MVP_LR_S("bound_request_id",v.bound_request_id); MVP_LR_S("terminal_disposition",v.terminal_disposition);
   MVP_LR_U("record_sequence",v.record_sequence); MVP_LR_U("record_revision",v.record_revision); MVP_LR_S("record_digest",v.record_digest);
#undef MVP_LR_S
#undef MVP_LR_U
#undef MVP_LR_I
   return true;
}

bool SWV5S5_MvpDecodeLedgerRecord(const string text,SWV5S5_IngressLedgerRecord &v)
{
   ZeroMemory(v); SWV5S5_MvpCodecReader r; r.Init(text); string nested; long number=0;
   if(!r.ReadNested("contract_version",nested) || !SWV5S5_MvpCodecDecode_SWV5_ContractVersion(nested,v.contract_version) ||
      !r.ReadString("ingress_identity",v.ingress_identity) || !r.ReadString("payload_digest",v.payload_digest) ||
      !r.ReadUnsigned("publication_sequence",v.publication_sequence) || !r.ReadInteger("lifecycle_state",number)) return false;
   v.lifecycle_state=(SWV5S5_IngressLifecycleState)number;
   if(!r.ReadString("logical_correlation_id",v.logical_correlation_id) ||
      !r.ReadUnsigned("reserved_request_sequence",v.reserved_request_sequence) || !r.ReadInteger("accepted_at",number)) return false;
   v.accepted_at=(datetime)number;
   return r.ReadString("bound_request_id",v.bound_request_id) && r.ReadString("terminal_disposition",v.terminal_disposition) &&
      r.ReadUnsigned("record_sequence",v.record_sequence) && r.ReadUnsigned("record_revision",v.record_revision) &&
      r.ReadString("record_digest",v.record_digest) && r.AtEnd();
}

bool SWV5S5_MvpEncodeLedgerState(const SWV5S5_IngressLedgerHeader &header,
                                 const SWV5S5_IngressLedgerIndexEntry &entries[],
                                 const SWV5S5_IngressLedgerRecord &records[],string &payload)
{
   payload=""; string nested,f;
   if(!SWV5S5_MvpEncodeLedgerHeader(header,nested) || !SWV5S5_CanonicalNested("header",nested,f)) return false; payload+=f;
   if(!SWV5S5_CanonicalUInt("records_count",(ulong)ArraySize(records),f) || ArraySize(entries)!=ArraySize(records)) return false; payload+=f;
   for(int i=0;i<ArraySize(records);i++)
   {
      if(!SWV5S5_MvpEncodeLedgerRecord(records[i],nested) || !SWV5S5_CanonicalNested("record_"+IntegerToString(i),nested,f)) return false; payload+=f;
   }
   return true;
}

bool SWV5S5_MvpDecodeLedgerState(const string payload,SWV5S5_IngressLedgerHeader &header,
                                 SWV5S5_IngressLedgerIndexEntry &entries[],SWV5S5_IngressLedgerRecord &records[])
{
   ZeroMemory(header); ArrayResize(entries,0); ArrayResize(records,0);
   SWV5S5_MvpCodecReader r; r.Init(payload); string nested; ulong count=0;
   if(!r.ReadNested("header",nested) || !SWV5S5_MvpDecodeLedgerHeader(nested,header) ||
      !r.ReadUnsigned("records_count",count) || count>100000) return false;
   ArrayResize(entries,(int)count); ArrayResize(records,(int)count);
   for(ulong i=0;i<count;i++)
   {
      if(!r.ReadNested("record_"+IntegerToString((long)i),nested) || !SWV5S5_MvpDecodeLedgerRecord(nested,records[(int)i])) return false;
      entries[(int)i].ingress_identity=records[(int)i].ingress_identity;
      entries[(int)i].publication_sequence=records[(int)i].publication_sequence;
      entries[(int)i].payload_digest=records[(int)i].payload_digest;
      entries[(int)i].lifecycle_state=records[(int)i].lifecycle_state;
      entries[(int)i].logical_correlation_id=records[(int)i].logical_correlation_id;
      entries[(int)i].reserved_request_sequence=records[(int)i].reserved_request_sequence;
      entries[(int)i].accepted_at=records[(int)i].accepted_at;
      entries[(int)i].bound_request_id=records[(int)i].bound_request_id;
      entries[(int)i].terminal_trust_disposition=records[(int)i].terminal_disposition;
      entries[(int)i].record_sequence=records[(int)i].record_sequence;
      entries[(int)i].record_revision=records[(int)i].record_revision;
      entries[(int)i].record_digest=records[(int)i].record_digest;
   }
   return r.AtEnd();
}

bool SWV5S5_MvpDeriveLedgerProposalDigest(const SWV5S5_IngressLedgerProposal &proposal,string &digest)
{
   string body="",f;
   if(!SWV5S5_CanonicalString("expected_ledger_digest",proposal.expected_header.ledger_digest,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("proposed_record_digest",proposal.proposed_record.record_digest,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("proposed_next_revision",proposal.proposed_next_revision,f)) return false; body+=f;
   return SWV5S5_DomainDigest(SWV5S5_DOMAIN_INGRESS_LEDGER,body,digest);
}

class SWV5S5_MvpIngressLedgerAuthority : public ISWV5S5IngressLedgerContract
{
private:
   SWV5S5_MvpSqliteAuthorityStore m_store;
   bool LoadRow(SWV5S5_IngressLedgerHeader &header,SWV5S5_IngressLedgerIndexEntry &entries[],
                SWV5S5_IngressLedgerRecord &records[],SWV5S5_MvpAuthorityRow &row)
   {
      bool found=false; string digest,header_digest;
      return m_store.ReadRow(SWV5S5_MVP_DOMAIN_INGRESS_LEDGER,SWV5S5_MVP_CURRENT_KEY,row,found) && found &&
         SWV5S5_DomainDigest(SWV5S5_MVP_DOMAIN_INGRESS_LEDGER,row.payload,digest) && digest==row.payload_digest &&
         SWV5S5_MvpDecodeLedgerState(row.payload,header,entries,records) &&
         SWV5S5_DeriveLedgerHeaderDigest(header,entries,header_digest) && header_digest==header.ledger_digest &&
         SWV5S5_ValidateLedgerRecordIndexLinkage(entries,records);
   }
   bool CommitState(const SWV5S5_MvpAuthorityRow &row,const SWV5S5_IngressLedgerHeader &header,
                    const SWV5S5_IngressLedgerIndexEntry &entries[],const SWV5S5_IngressLedgerRecord &records[],
                    const datetime now)
   {
      string payload,digest; SWV5S5_MvpAuthorityRow committed;
      return SWV5S5_MvpEncodeLedgerState(header,entries,records,payload) &&
         SWV5S5_DomainDigest(SWV5S5_MVP_DOMAIN_INGRESS_LEDGER,payload,digest) &&
         m_store.CompareAndSet(SWV5S5_MVP_DOMAIN_INGRESS_LEDGER,SWV5S5_MVP_CURRENT_KEY,
            row.logical_revision,row.store_revision,row.payload_digest,row.state,row.logical_revision+1,1,
            digest,payload,now,committed);
   }
public:
   bool Configure(const string relative_path,const string namespace_digest)
   { return m_store.Open(relative_path,namespace_digest); }
   bool Initialize(const SWV5_PersistenceNamespace &scope,const SWV5_OwnershipFence &fence,
                   const SWV5S5_ProducerTrustRecord &trust,const datetime now)
   {
      SWV5S5_MvpAuthorityRow row; bool found=false;
      if(!m_store.ReadRow(SWV5S5_MVP_DOMAIN_INGRESS_LEDGER,SWV5S5_MVP_CURRENT_KEY,row,found)) return false;
      if(found)
      {
         SWV5S5_IngressLedgerHeader h; SWV5S5_IngressLedgerIndexEntry e[]; SWV5S5_IngressLedgerRecord r[];
         return LoadRow(h,e,r,row) && SWV5S5_EqualNamespace(h.persistence_namespace,scope) && SWV5S5_EqualFence(h.ownership_fence,fence);
      }
      SWV5S5_IngressLedgerHeader h; ZeroMemory(h); SWV5S5_IngressLedgerIndexEntry e[]; SWV5S5_IngressLedgerRecord r[];
      SWV5S5_InitContractVersion(h.contract_version); h.policy_id=SWV5S5_POLICY_ID;
      h.persistence_namespace=scope; h.ownership_fence=fence;
      h.producer_authority_record_id=trust.authority_record_id; h.producer_authority_generation=trust.authority_generation;
      h.producer_instance=trust.producer_instance; h.producer_epoch=trust.producer_epoch;
      h.revision=1; h.previous_revision=0; h.compaction_generation=0; h.membership_count=0;
      if(!SWV5S5_DeriveLedgerIndexDigest(e,h.membership_binding_index_digest) ||
         !SWV5S5_DeriveLedgerHeaderDigest(h,e,h.ledger_digest)) return false;
      string payload,digest;
      if(!SWV5S5_MvpEncodeLedgerState(h,e,r,payload) || !SWV5S5_DomainDigest(SWV5S5_MVP_DOMAIN_INGRESS_LEDGER,payload,digest)) return false;
      return m_store.CompareAndSet(SWV5S5_MVP_DOMAIN_INGRESS_LEDGER,SWV5S5_MVP_CURRENT_KEY,0,"","",0,1,1,digest,payload,now,row);
   }
   bool ReadSnapshot(SWV5S5_IngressLedgerHeader &header,SWV5S5_IngressLedgerIndexEntry &entries[],SWV5S5_IngressLedgerRecord &records[])
   { SWV5S5_MvpAuthorityRow row; return LoadRow(header,entries,records,row); }

   virtual bool TryCommitAcceptance(const SWV5S5_IngressLedgerHeader &expected_header,
                                    const SWV5S5_IngressLedgerIndexEntry &expected_entries[],
                                    const SWV5S5_IngressLedgerRecord &expected_records[],
                                    const SWV5S5_IngressLedgerProposal &proposal,
                                    SWV5S5_ValidationResult &result)
   {
      ZeroMemory(result); SWV5S5_IngressLedgerHeader current; SWV5S5_IngressLedgerIndexEntry entries[]; SWV5S5_IngressLedgerRecord records[];
      SWV5S5_MvpAuthorityRow row; string expected_payload,current_payload,proposal_digest;
      SWV5S5_InitContractVersion(result.contract_version); result.disposition=SWV5_DISPOSITION_DENY;
      if(!LoadRow(current,entries,records,row)) { result.reason_code="LEDGER_CURRENT_INVALID"; return false; }
      if(!SWV5S5_MvpEncodeLedgerState(expected_header,expected_entries,expected_records,expected_payload) ||
         !SWV5S5_MvpEncodeLedgerState(current,entries,records,current_payload) || expected_payload!=current_payload)
      { result.reason_code="LEDGER_EXPECTED_CURRENT_MISMATCH"; return false; }
      if(proposal.expected_header.ledger_digest!=current.ledger_digest || proposal.proposed_next_revision!=current.revision+1)
      { result.reason_code="LEDGER_PROPOSAL_REVISION_MISMATCH"; return false; }
      if(!SWV5S5_MvpDeriveLedgerProposalDigest(proposal,proposal_digest) || proposal_digest!=proposal.proposal_digest)
      { result.reason_code="LEDGER_PROPOSAL_DIGEST_INVALID"; return false; }
      if(!SWV5S5_ValidLedgerLifecycle(proposal.proposed_record) ||
         proposal.proposed_record.record_revision!=proposal.proposed_next_revision)
      { result.reason_code="LEDGER_RECORD_INVALID"; return false; }
      if(SWV5S5_FindLedgerMembership(entries,proposal.proposed_record.ingress_identity)>=0 ||
         proposal.proposed_record.publication_sequence<=current.highest_accepted_publication_sequence)
      { result.reason_code="LEDGER_INGRESS_NOT_NEW"; return false; }
      const int count=ArraySize(records); SWV5S5_IngressLedgerIndexEntry next_entries[]; SWV5S5_IngressLedgerRecord next_records[];
      ArrayResize(next_entries,count+1); ArrayResize(next_records,count+1); int insert=count;
      for(int i=0;i<count;i++) if(insert==count && StringCompare(proposal.proposed_record.ingress_identity,records[i].ingress_identity)<0) insert=i;
      for(int i=0;i<insert;i++) next_records[i]=records[i]; next_records[insert]=proposal.proposed_record;
      for(int i=insert;i<count;i++) next_records[i+1]=records[i];
      SWV5S5_IngressLedgerHeader next=current; next.previous_revision=current.revision; next.revision=proposal.proposed_next_revision;
      next.highest_accepted_publication_sequence=proposal.proposed_record.publication_sequence; next.membership_count=(uint)(count+1);
      for(int i=0;i<count+1;i++)
      {
         next_entries[i].ingress_identity=next_records[i].ingress_identity; next_entries[i].publication_sequence=next_records[i].publication_sequence;
         next_entries[i].payload_digest=next_records[i].payload_digest; next_entries[i].lifecycle_state=next_records[i].lifecycle_state;
         next_entries[i].logical_correlation_id=next_records[i].logical_correlation_id; next_entries[i].reserved_request_sequence=next_records[i].reserved_request_sequence;
         next_entries[i].accepted_at=next_records[i].accepted_at; next_entries[i].bound_request_id=next_records[i].bound_request_id;
         next_entries[i].terminal_trust_disposition=next_records[i].terminal_disposition; next_entries[i].record_sequence=next_records[i].record_sequence;
         next_entries[i].record_revision=next_records[i].record_revision; next_entries[i].record_digest=next_records[i].record_digest;
      }
      if(!SWV5S5_DeriveLedgerIndexDigest(next_entries,next.membership_binding_index_digest) ||
         !SWV5S5_DeriveLedgerHeaderDigest(next,next_entries,next.ledger_digest) ||
         !SWV5S5_ValidateLedgerRecordIndexLinkage(next_entries,next_records) ||
         !CommitState(row,next,next_entries,next_records,proposal.proposed_record.accepted_at)) return false;
      SWV5S5_InitContractVersion(result.contract_version); result.disposition=SWV5_DISPOSITION_ALLOW;
      result.reason_code="LEDGER_COMMITTED"; result.evaluation_sequence=proposal.proposed_next_revision;
      result.evaluated_at=proposal.proposed_record.accepted_at; return true;
   }

   bool TransitionBound(const string ingress_identity,const SWV5_ExecutionRequestIdentity &request_identity,
                        const datetime now,SWV5S5_IngressLedgerRecord &bound_record)
   {
      ZeroMemory(bound_record); SWV5S5_IngressLedgerHeader h; SWV5S5_IngressLedgerIndexEntry e[]; SWV5S5_IngressLedgerRecord r[];
      SWV5S5_MvpAuthorityRow row; string bound_id;
      if(!LoadRow(h,e,r,row) || !SWV5S5_MvpDeriveBoundRequestId(request_identity,bound_id)) return false;
      const int found=SWV5S5_FindLedgerMembership(e,ingress_identity); if(found<0) return false;
      if(r[found].lifecycle_state==SWV5S5_BOUND_TO_REQUEST)
      { bound_record=r[found]; return r[found].bound_request_id==bound_id; }
      if(r[found].lifecycle_state!=SWV5S5_ACCEPTED_REQUEST_PENDING || h.revision==18446744073709551615) return false;
      r[found].lifecycle_state=SWV5S5_BOUND_TO_REQUEST; r[found].bound_request_id=bound_id;
      r[found].record_revision=h.revision+1; r[found].record_digest="";
      if(!SWV5S5_DeriveLedgerRecordDigest(r[found],r[found].record_digest)) return false;
      e[found].lifecycle_state=r[found].lifecycle_state; e[found].bound_request_id=bound_id;
      e[found].record_revision=r[found].record_revision; e[found].record_digest=r[found].record_digest;
      h.previous_revision=h.revision; h.revision++;
      if(!SWV5S5_DeriveLedgerIndexDigest(e,h.membership_binding_index_digest) ||
         !SWV5S5_DeriveLedgerHeaderDigest(h,e,h.ledger_digest) || !SWV5S5_ValidateLedgerRecordIndexLinkage(e,r) ||
         !CommitState(row,h,e,r,now)) return false;
      bound_record=r[found]; return true;
   }
};

struct SWV5S5_MvpRequestSetPhysicalState
{
   string logical_store_revision;
   SWV5S5_PendingRequestSetAuthorityView view;
};

bool SWV5S5_MvpEncodeRequestSetState(const SWV5S5_MvpRequestSetPhysicalState &state,string &payload)
{
   string f,nested; payload="";
   if(!SWV5S5_CanonicalString("logical_store_revision",state.logical_store_revision,f)) return false; payload+=f;
   if(!SWV5S5_MvpCodecEncode_SWV5S5_PendingRequestSetAuthorityView(state.view,nested) ||
      !SWV5S5_CanonicalNested("view",nested,f)) return false; payload+=f; return true;
}

bool SWV5S5_MvpDecodeRequestSetState(const string payload,SWV5S5_MvpRequestSetPhysicalState &state)
{
   ZeroMemory(state); SWV5S5_MvpCodecReader r; r.Init(payload); string nested;
   return r.ReadString("logical_store_revision",state.logical_store_revision) && r.ReadNested("view",nested) &&
      SWV5S5_MvpCodecDecode_SWV5S5_PendingRequestSetAuthorityView(nested,state.view) && r.AtEnd();
}

class SWV5S5_MvpRequestSetPublicationAuthority : public ISWV5S5FencedRuntimePublicationAuthority
{
private:
   SWV5S5_MvpSqliteAuthorityStore m_store;
   bool LoadRow(SWV5S5_MvpRequestSetPhysicalState &state,SWV5S5_MvpAuthorityRow &row)
   {
      bool found=false; string digest,stored_projection;
      return m_store.ReadRow(SWV5S5_MVP_DOMAIN_REQUEST_SET,SWV5S5_MVP_REQUEST_SET_KEY,row,found) && found &&
         SWV5S5_DomainDigest(SWV5S5_MVP_DOMAIN_REQUEST_SET,row.payload,digest) && digest==row.payload_digest &&
         SWV5S5_MvpDecodeRequestSetState(row.payload,state) &&
         (stored_projection=state.view.projection_digest)!="" && SWV5S5_DeriveRequestSetProjection(state.view) &&
         state.view.projection_digest==stored_projection;
   }
public:
   bool Configure(const string relative_path,const string namespace_digest)
   { return m_store.Open(relative_path,namespace_digest); }
   bool Initialize(const SWV5_PersistenceNamespace &scope,const SWV5_OwnershipFence &fence,const datetime now)
   {
      SWV5S5_MvpAuthorityRow row; bool found=false;
      if(!m_store.ReadRow(SWV5S5_MVP_DOMAIN_REQUEST_SET,SWV5S5_MVP_REQUEST_SET_KEY,row,found)) return false;
      if(found) { SWV5S5_MvpRequestSetPhysicalState state; return LoadRow(state,row); }
      SWV5S5_MvpRequestSetPhysicalState state; ZeroMemory(state); state.logical_store_revision="GENESIS";
      state.view.persistence_namespace=scope; state.view.ownership_fence=fence;
      SWV5S5_MvpInitV5Version(state.view.header.contract_version); state.view.header.request_count=0;
      state.view.header.request_index_revision="GENESIS"; state.view.header.record_sequence=0;
      if(!SWV5S5_DeriveCompleteRequestSetDigest(state.view.requests,state.view.header.request_set_digest) ||
         !SWV5S5_DeriveRequestSetProjection(state.view)) return false;
      string payload,digest; if(!SWV5S5_MvpEncodeRequestSetState(state,payload) ||
         !SWV5S5_DomainDigest(SWV5S5_MVP_DOMAIN_REQUEST_SET,payload,digest)) return false;
      return m_store.CompareAndSet(SWV5S5_MVP_DOMAIN_REQUEST_SET,SWV5S5_MVP_REQUEST_SET_KEY,0,"","",0,1,1,digest,payload,now,row);
   }
   bool ReadState(SWV5S5_RequestSetPublicationAuthority &authority,SWV5_PendingRequest &requests[])
   {
      SWV5S5_MvpRequestSetPhysicalState state; SWV5S5_MvpAuthorityRow row;
      if(!LoadRow(state,row)) return false;
      SWV5S5_InitContractVersion(authority.contract_version); authority.policy_id=SWV5S5_PUBLICATION_POLICY_ID;
      authority.policy_version=SWV5S5_PUBLICATION_POLICY_VERSION; authority.persistence_namespace=state.view.persistence_namespace;
      authority.ownership_fence=state.view.ownership_fence; authority.store_revision=state.logical_store_revision;
      authority.current_set_header=state.view.header; authority.current_complete_set_digest=state.view.header.request_set_digest;
      ArrayResize(requests,ArraySize(state.view.requests)); for(int i=0;i<ArraySize(requests);i++) requests[i]=state.view.requests[i]; return true;
   }
   virtual bool TryPublishRequestSet(const SWV5S5_RequestSetPublicationProposal &proposal,
                                     const SWV5_PendingRequest &proposed_requests[],
                                     SWV5S5_FencedPublicationResult &result)
   {
      SWV5S5_MvpRequestSetPhysicalState current; SWV5S5_MvpAuthorityRow row; SWV5S5_RequestSetPublicationAuthority authority;
      SWV5_PendingRequest current_requests[];
      if(!LoadRow(current,row) || !ReadState(authority,current_requests) ||
         !SWV5S5_EvaluateRequestSetPublication(authority,current_requests,proposal,proposed_requests,result) ||
         result.disposition!=SWV5S5_PUBLICATION_PROPOSAL_VALID) return false;
      SWV5S5_MvpRequestSetPhysicalState next; ZeroMemory(next); next.logical_store_revision=proposal.proposed_store_revision;
      next.view.persistence_namespace=proposal.persistence_namespace; next.view.ownership_fence=proposal.expected_ownership_fence;
      next.view.header=proposal.proposed_set_header; ArrayResize(next.view.requests,ArraySize(proposed_requests));
      for(int i=0;i<ArraySize(proposed_requests);i++) next.view.requests[i]=proposed_requests[i];
      if(!SWV5S5_DeriveRequestSetProjection(next.view)) return false;
      string payload,digest; SWV5S5_MvpAuthorityRow committed;
      if(!SWV5S5_MvpEncodeRequestSetState(next,payload) || !SWV5S5_DomainDigest(SWV5S5_MVP_DOMAIN_REQUEST_SET,payload,digest) ||
         ArraySize(proposed_requests)==0 || proposed_requests[ArraySize(proposed_requests)-1].last_changed_at<=0 ||
         !m_store.CompareAndSet(SWV5S5_MVP_DOMAIN_REQUEST_SET,SWV5S5_MVP_REQUEST_SET_KEY,row.logical_revision,row.store_revision,
            row.payload_digest,row.state,row.logical_revision+1,1,digest,payload,
            proposed_requests[ArraySize(proposed_requests)-1].last_changed_at,committed)) return false;
      SWV5S5_MvpRequestSetPhysicalState readback; SWV5S5_MvpAuthorityRow readback_row;
      if(!LoadRow(readback,readback_row) || readback.view.projection_digest!=next.view.projection_digest) return false;
      SWV5S5_InitContractVersion(result.contract_version); result.disposition=SWV5S5_PUBLICATION_COMMITTED;
      result.proposed_store_revision=proposal.proposed_store_revision; result.proposed_record_sequence=proposal.proposed_set_header.record_sequence;
      result.resulting_projection_digest=next.view.header.request_set_digest; result.reason_code="REQUEST_SET_COMMITTED"; return true;
   }
   virtual bool TryPublishCheckpoint(const SWV5S5_CheckpointPublicationProposal &proposal,
                                     SWV5S5_FencedPublicationResult &result)
   { ZeroMemory(result); SWV5S5_InitContractVersion(result.contract_version); result.disposition=SWV5S5_PUBLICATION_CONFLICT; result.reason_code="MVP_REQUEST_SET_ONLY"; return false; }
   bool FindExactBoundRequest(const string bound_request_id,const SWV5_PendingRequest &expected,SWV5_PendingRequest &found)
   {
      ZeroMemory(found); SWV5S5_MvpRequestSetPhysicalState state; SWV5S5_MvpAuthorityRow row; string id,left,right; int matches=0;
      if(!LoadRow(state,row) || !SWV5S5_CanonicalPendingRequest(expected,left)) return false;
      for(int i=0;i<ArraySize(state.view.requests);i++)
         if(SWV5S5_MvpDeriveBoundRequestId(state.view.requests[i].intent.request_identity,id) && id==bound_request_id)
         { found=state.view.requests[i]; matches++; }
      return matches==1 && SWV5S5_CanonicalPendingRequest(found,right) && left==right;
   }
};

#endif // SW_V5_S5_MVP_INGRESS_REQUEST_AUTHORITIES_MQH
