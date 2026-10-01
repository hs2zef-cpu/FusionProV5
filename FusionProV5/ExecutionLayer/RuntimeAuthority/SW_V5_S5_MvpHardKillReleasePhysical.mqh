#ifndef SW_V5_S5_MVP_HARD_KILL_RELEASE_PHYSICAL_MQH
#define SW_V5_S5_MVP_HARD_KILL_RELEASE_PHYSICAL_MQH

// DEMO MVP AUTHORITY ONLY. No broker access or authority issuance.
#include "SW_V5_S5_MvpAuthorityRecordCodec.mqh"

const string SWV5S5_MVP_DOMAIN_RELEASE_COMPLETE="MVP_HARD_KILL_COMPLETE_RELEASE";
const string SWV5S5_MVP_DOMAIN_RELEASE_HISTORY="MVP_HARD_KILL_ACTIVATION_HISTORY";

bool SWV5S5_MvpReleaseBundle(const SWV5_HardKillState &released,
                            const SWV5_HardKillReleaseAuthorityRecord &authority,string &payload,string &digest)
{
   string state,record,a,b;
   if(!SWV5S5_MvpCodecEncode_SWV5_HardKillState(released,state) ||
      !SWV5S5_MvpCodecEncode_SWV5_HardKillReleaseAuthorityRecord(authority,record) ||
      !SWV5S5_CanonicalNested("released",state,a) || !SWV5S5_CanonicalNested("authority",record,b)) return false;
   payload=a+b;
   return SWV5S5_DomainDigest(SWV5S5_MVP_DOMAIN_RELEASE_COMPLETE,payload,digest);
}

bool SWV5S5_MvpDecodeReleaseBundle(const string payload,SWV5_HardKillState &released,
                                  SWV5_HardKillReleaseAuthorityRecord &authority)
{
   SWV5S5_MvpCodecReader reader; reader.Init(payload); string nested;
   return reader.ReadNested("released",nested) && SWV5S5_MvpCodecDecode_SWV5_HardKillState(nested,released) &&
      reader.ReadNested("authority",nested) && SWV5S5_MvpCodecDecode_SWV5_HardKillReleaseAuthorityRecord(nested,authority) &&
      reader.AtEnd();
}

// Validate the complete independent record, not merely the MVP historical
// interface's identity subset. Frozen Risk decisions remain unchanged.
bool SWV5S5_MvpCompleteReleaseValid(const SWV5_ContractValidationContext &context,
                                   const SWV5_HardKillState &released,
                                   const SWV5_HardKillReleaseAuthorityRecord &record)
{
   string digest,a,b;
   if(released.state!=SWV5_HARD_KILL_RELEASED || released.release_generation==0 ||
      !SWV5S5_MvpVersionExact(context,record.contract_version) ||
      !SWV5S5_MvpVersionExact(context,record.persistence_namespace.contract_version) ||
      !SWV5S5_MvpVersionExact(context,record.account_namespace.contract_version) ||
      !SWV5S5_EqualNamespace(released.persistence_namespace,record.persistence_namespace) ||
      !SWV5S5_CanonicalAccountNamespace("account",released.account_namespace,a) ||
      !SWV5S5_CanonicalAccountNamespace("account",record.account_namespace,b) || a!=b ||
      record.account_namespace.account_currency!=SWV5S5_MVP_ACCOUNT_CURRENCY ||
      record.account_namespace.account_mode!=SWV5_ACCOUNT_MODE_HEDGING ||
      record.authority_record_id=="" || record.release_record_sequence==0 ||
      record.issuing_component!=SWV5_COMPONENT_AUTHORITY_RISK_GOVERNANCE ||
      record.authority_source!=SWV5_AUTHORITY_HARD_KILL_RELEASE_RECORD ||
      !SWV5S5_MvpHardKillAuthorityRecordDigest(record,digest) || digest!=record.authority_record_digest) return false;
   SWV5_HardKillReleaseAuthorityReference reference; ZeroMemory(reference);
   reference.contract_version=record.contract_version; reference.authority_record_id=record.authority_record_id;
   reference.authority_record_sequence=record.release_record_sequence;
   reference.authority_record_digest=record.authority_record_digest; reference.release_id=record.release_id;
   reference.latch_generation=record.latch_generation; reference.release_generation=record.release_generation;
   if(!SWV5S5_MvpCodecEncode_SWV5_HardKillReleaseAuthorityReference(reference,a) ||
      !SWV5S5_MvpCodecEncode_SWV5_HardKillReleaseAuthorityReference(released.release_authority_reference,b) || a!=b) return false;
   SWV5_HardKillReleaseEvidence expected=released.release_evidence;
   expected.contract_version=record.contract_version; expected.persistence_namespace=record.persistence_namespace;
   expected.latch_id=record.latch_id; expected.latch_generation=record.latch_generation;
   expected.release_id=record.release_id; expected.release_generation=record.release_generation;
   expected.operator_identity=record.operator_identity; expected.approving_component=record.approving_component;
   expected.approval_policy_id=record.approval_policy_id; expected.approval_sequence=record.approval_sequence;
   expected.broker_evidence=record.broker_evidence_reference; expected.persistence_evidence=record.persistence_evidence_reference;
   expected.exposure_evidence=record.exposure_evidence_reference; expected.approved_at=record.approved_at;
   expected.released_at=record.released_at; expected.expires_at=record.expires_at;
   expected.release_record_sequence=record.release_record_sequence;
   if(!SWV5S5_MvpCodecEncode_SWV5_HardKillReleaseEvidence(expected,a) ||
      !SWV5S5_MvpCodecEncode_SWV5_HardKillReleaseEvidence(released.release_evidence,b) || a!=b ||
      record.latch_id!=released.latch_id || record.latch_generation!=released.latch_generation ||
      record.release_generation!=released.release_generation) return false;
   SWV5_HardKillState pending=released;
   pending.state=SWV5_HARD_KILL_RELEASE_PENDING; pending.release_generation=released.release_generation-1;
   SWV5S5_MvpRiskContract risk; SWV5_ContractDecision decision;
   return SWV5S5_MvpHardKillReleaseValid(context,pending,released.release_evidence) &&
      risk.ValidateHistoricalHardKillRelease(context,released,released.release_evidence,record,decision);
}

#endif
