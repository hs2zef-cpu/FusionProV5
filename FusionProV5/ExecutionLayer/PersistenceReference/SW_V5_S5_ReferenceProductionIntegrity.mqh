#ifndef SW_V5_S5_REFERENCE_PRODUCTION_INTEGRITY_MQH
#define SW_V5_S5_REFERENCE_PRODUCTION_INTEGRITY_MQH

// REFERENCE ONLY / NOT FOR PRODUCTION / NO BROKER ACCESS
// Reuses the frozen Production V5 LP1/LP2 canonical verification helpers.
// This explicit reference dependency does not authorize runtime or platform use.
#include "..\..\Tests\ContractVerification\SW_V5_TestFixtures.mqh"

bool SWV5S5_ReferenceZeroBrokerIdentity(const SWV5_BrokerExecutionIdentity &identity)
{
   return SWV5S5_IsV5Version(identity.contract_version) && identity.order_ticket==0 &&
      identity.deal_ticket==0 && identity.position_identifier==0 &&
      identity.broker_event_id=="" && identity.transaction_sequence==0;
}

bool SWV5S5_ReferenceZeroCorrelation(const SWV5_ExecutionCorrelation &correlation)
{
   return SWV5S5_IsV5Version(correlation.contract_version) &&
      correlation.phase==SWV5_EXECUTION_PHASE_INTENT &&
      SWV5S5_IsV5Version(correlation.request_identity.contract_version) &&
      correlation.request_identity.request_id.correlation_id=="" &&
      correlation.request_identity.request_id.attempt_id=="" &&
      correlation.request_identity.request_id.parent_attempt_id=="" &&
      correlation.request_identity.request_id.monotonic_sequence==0 &&
      correlation.request_identity.request_id.created_at==0 &&
      correlation.request_identity.idempotency_key=="" &&
      SWV5S5_ReferenceZeroBrokerIdentity(correlation.broker_identity);
}

bool SWV5S5_ReferenceCheckpointProductionIntegrityValid(const SWV5_PersistedCheckpoint &checkpoint,
                                                         const SWV5_ContractValidationContext &context)
{
   return SWV5S5_IsV5Version(checkpoint.header.contract_version) &&
      SWV5S5_IsV5Version(checkpoint.header.persistence_namespace.contract_version) &&
      SWV5S5_IsV5Version(checkpoint.header.ownership_fence.contract_version) &&
      checkpoint.header.persistence_namespace.basket_id.value!="" &&
      checkpoint.header.record_sequence>0 &&
      checkpoint.header.previous_record_sequence<checkpoint.header.record_sequence &&
      checkpoint.header.store_revision!="" && checkpoint.header.payload_digest!="" &&
      checkpoint.header.payload_size==SWV5_TestCheckpointPayloadSize(checkpoint) &&
      checkpoint.header.payload_digest==SWV5_TestCheckpointPayloadDigest(checkpoint) &&
      SWV5S5_IsDigest64Lower(checkpoint.header.payload_digest) &&
      checkpoint.header.written_at>0 && checkpoint.header.written_at<=context.clock_time;
}

bool SWV5S5_ReferenceReconciliationSourceDigest(const SWV5_PersistedReconciliationVector &reconciliation,
                                                string &digest)
{
   digest=SWV5_TestReconciliationSourceDigest(reconciliation);
   return SWV5S5_IsDigest64Lower(digest);
}

bool SWV5S5_ReferenceReleaseEvidenceDigest(const SWV5_HardKillReleaseEvidence &evidence,
                                           string &digest)
{
   digest=SWV5_TestHardKillReleaseDigest(evidence);
   return SWV5S5_IsDigest64Lower(digest);
}

#endif
