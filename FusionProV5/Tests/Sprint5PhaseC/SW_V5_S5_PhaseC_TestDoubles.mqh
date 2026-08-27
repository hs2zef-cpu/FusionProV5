#ifndef SW_V5_S5_PHASE_C_TEST_DOUBLES_MQH
#define SW_V5_S5_PHASE_C_TEST_DOUBLES_MQH

// TEST ONLY / NON-PRODUCTION / NO BROKER ACCESS
// Deterministic in-memory doubles. They provide no durability or atomicity proof.

#include "../../ExecutionLayer/Coordinator/SW_V5_S5_Coordinator.mqh"
#include "../Sprint5PhaseB/SW_V5_S5_PhaseB_Assertions.mqh"

class SWV5S5_ScriptedAdmissionPreparation : public ISWV5S5CoordinatorAdmissionPreparation
{
public:
   bool allow;
   bool corrupt_prepared_command;
   int call_count;

   SWV5S5_ScriptedAdmissionPreparation(void) { allow=true; corrupt_prepared_command=false; call_count=0; }

   virtual bool PrepareSameEvent(const SWV5S5_CoordinatorAdmissionEvent &event,
                                 SWV5S5_CoordinatorPreparedAdmission &prepared)
   {
      call_count++;
      ZeroMemory(prepared);
      if(!allow) return false;
      prepared.event_id=event.event_id;
      prepared.event_ordinal=event.event_ordinal;
      prepared.operation_token=event.event_id+"|"+(string)event.event_ordinal+"|"+event.preparation_seed.command_digest;
      prepared.claim_command=event.preparation_seed;
      SWV5_ContractValidationContext context;
      SWV5S5_TestContext(context,event.preparation_seed.claim_clock.observed_at,
                         event.preparation_seed.claim_clock.clock_sequence);
      bool ok=SWV5S5_PrepareInvocationClaimTransition(context,SWV5S5_TEST_RISK,
                                                       prepared.claim_command,prepared.transition);
      if(ok && corrupt_prepared_command)
      {
         prepared.claim_command.expected_authority_revision++;
      }
      return ok;
   }
};

class SWV5S5_ScriptedClaimAuthority : public ISWV5S5CoordinatorInvocationClaimAuthority
{
private:
   bool claimed;
public:
   SWV5S5_ClaimDisposition next_disposition;
   int call_count;
   SWV5S5_InvocationClaimResult scripted_result;
   bool replay_prior_event_binding;

   SWV5S5_ScriptedClaimAuthority(void)
   {
      claimed=false;
      next_disposition=SWV5S5_CLAIM_GRANTED_NOW;
      call_count=0;
      replay_prior_event_binding=false;
      ZeroMemory(scripted_result);
   }

   void ConfigureValid(const SWV5S5_InvocationClaimTransition &transition)
   {
      ZeroMemory(scripted_result); SWV5S5_InitContractVersion(scripted_result.contract_version);
      scripted_result.disposition=SWV5S5_CLAIM_GRANTED_NOW;
      scripted_result.claim_granted_now=true;
      scripted_result.resulting_authority_record=transition.proposed_next_record;
      scripted_result.reason_code="SCRIPTED_COMPLETE_FROZEN_VALID_CLAIM";
   }

   virtual bool TryClaimInvocation(const SWV5S5_InvocationClaimCommand &command,
                                   const string event_id,const ulong event_ordinal,
                                   const string operation_token,
                                   SWV5S5_CoordinatorClaimOperationResult &operation)
   {
      call_count++;
      ZeroMemory(operation);
      operation.event_id=(replay_prior_event_binding ? "PRIOR-EVENT" : event_id);
      operation.event_ordinal=(replay_prior_event_binding ? event_ordinal-1 : event_ordinal);
      operation.operation_token=(replay_prior_event_binding ? "PRIOR-TOKEN" : operation_token);
      SWV5S5_InvocationClaimResult result;
      ZeroMemory(result); SWV5S5_InitContractVersion(result.contract_version);
      if(claimed || next_disposition==SWV5S5_CLAIM_ALREADY_CLAIMED)
      {
         result.disposition=SWV5S5_CLAIM_ALREADY_CLAIMED;
         result.claim_granted_now=false;
         result.resulting_authority_record.state=SWV5S5_INVOCATION_CLAIMED_UNRESOLVED;
         result.reason_code="SCRIPTED_ALREADY_CLAIMED_NO_GRANT";
         operation.claim=result;
         return true;
      }
      if(next_disposition!=SWV5S5_CLAIM_GRANTED_NOW)
      {
         result.disposition=next_disposition;
         result.claim_granted_now=false;
         result.resulting_authority_record.state=SWV5S5_COMMITTED_NOT_INVOKED;
         result.reason_code="SCRIPTED_CLAIM_DENIED";
         operation.claim=result;
         return false;
      }
      claimed=true;
      result=scripted_result;
      operation.claim=result;
      return true;
   }
};

class SWV5S5_ScriptedLedgerAuthority : public ISWV5S5CoordinatorLedgerAuthority
{
private:
   SWV5S5_IngressLedgerHeader header;
   SWV5S5_IngressLedgerIndexEntry entries[];
   SWV5S5_IngressLedgerRecord records[];

   void SortState(void)
   {
      for(int i=0;i<ArraySize(entries);i++)
         for(int j=i+1;j<ArraySize(entries);j++)
            if(StringCompare(entries[i].ingress_identity,entries[j].ingress_identity)>0)
            {
               SWV5S5_IngressLedgerIndexEntry e=entries[i]; entries[i]=entries[j]; entries[j]=e;
               SWV5S5_IngressLedgerRecord r=records[i]; records[i]=records[j]; records[j]=r;
            }
   }

public:
   int call_count;
   int read_count;
   int read_corruption;
   int operation_corruption;

   SWV5S5_ScriptedLedgerAuthority(void)
   {
      call_count=0; read_count=0; read_corruption=0; operation_corruption=0;
      ZeroMemory(header); ArrayResize(entries,0); ArrayResize(records,0);
   }

   bool Configure(const SWV5_PersistenceNamespace &scope,const SWV5_OwnershipFence &fence,
                  const SWV5S5_ProducerTrustRecord &trust,const SWV5S5_IngressEnvelope &ingress)
   {
      ZeroMemory(header); SWV5S5_InitContractVersion(header.contract_version);
      header.policy_id=SWV5S5_POLICY_ID; header.persistence_namespace=scope; header.ownership_fence=fence;
      header.producer_authority_record_id=trust.authority_record_id;
      header.producer_authority_generation=trust.authority_generation;
      header.producer_instance=ingress.producer.producer_instance;
      header.producer_epoch=ingress.producer.producer_epoch;
      header.revision=1; header.previous_revision=0; header.compaction_generation=0;
      header.membership_count=0; header.highest_accepted_publication_sequence=0;
      ArrayResize(entries,0); ArrayResize(records,0);
      return SWV5S5_DeriveLedgerIndexDigest(entries,header.membership_binding_index_digest) &&
             SWV5S5_DeriveLedgerHeaderDigest(header,entries,header.ledger_digest);
   }

   virtual bool ReadSnapshot(const string event_id,const ulong event_ordinal,
                             SWV5S5_IngressLedgerHeader &out_header,
                             SWV5S5_IngressLedgerIndexEntry &out_entries[],
                             SWV5S5_IngressLedgerRecord &out_records[])
   {
      read_count++; out_header=header;
      ArrayResize(out_entries,ArraySize(entries));
      for(int i=0;i<ArraySize(entries);i++) out_entries[i]=entries[i];
      ArrayResize(out_records,ArraySize(records));
      for(int i=0;i<ArraySize(records);i++) out_records[i]=records[i];
      if(read_corruption==1) out_header.ledger_digest=SWV5S5_SHA256_EMPTY;
      if(read_corruption==2) out_header.membership_count++;
      if(read_corruption==3 && ArraySize(out_records)>0) ArrayResize(out_records,ArraySize(out_records)-1);
      if(read_corruption==4 && ArraySize(out_records)>0) out_records[0].record_digest=SWV5S5_SHA256_EMPTY;
      if(read_corruption==5 && ArraySize(out_entries)>0) out_entries[0].accepted_at++;
      if(read_corruption==6 && ArraySize(out_entries)>0) out_entries[0].logical_correlation_id="CORRUPT";
      if(read_corruption==7 && ArraySize(out_entries)>0) out_entries[0].reserved_request_sequence++;
      return true;
   }

   virtual bool TryCommitAcceptance(const SWV5S5_IngressLedgerHeader &expected_header,
                                    const SWV5S5_IngressLedgerIndexEntry &expected_entries[],
                                    const SWV5S5_IngressLedgerRecord &expected_records[],
                                    const SWV5S5_IngressLedgerProposal &proposal,
                                    const string event_id,const ulong event_ordinal,
                                    SWV5S5_CoordinatorLedgerOperationResult &result)
   {
      call_count++; ZeroMemory(result);
      result.event_id=(operation_corruption==1 ? "PRIOR" : event_id);
      result.event_ordinal=event_ordinal;
      result.proposal_digest=(operation_corruption==2 ? SWV5S5_SHA256_EMPTY : proposal.proposal_digest);
      SWV5_ContractValidationContext context; SWV5S5_TestContext(context,proposal.proposed_record.accepted_at,event_ordinal);
      string expected_digest;
      if(!SWV5S5_DeriveLedgerHeaderDigest(expected_header,expected_entries,expected_digest) ||
         expected_header.ledger_digest!=expected_digest ||
         !SWV5S5_ValidateLedgerRecordIndexLinkage(expected_entries,expected_records) ||
         expected_header.ledger_digest!=header.ledger_digest ||
         proposal.expected_header.ledger_digest!=header.ledger_digest ||
         ArraySize(expected_entries)!=ArraySize(entries) || ArraySize(expected_records)!=ArraySize(records) ||
         proposal.proposed_next_revision!=header.revision+1 ||
         SWV5S5_FindLedgerMembership(entries,proposal.proposed_record.ingress_identity)>=0)
      { SWV5S5_Deny(context,"TEST_LEDGER_CAS_REJECTED","",result.authoritative_result); return false; }
      if(operation_corruption==3)
      { SWV5S5_Allow(context,"FABRICATED_WITHOUT_STATE_CHANGE",result.authoritative_result); return true; }
      int n=ArraySize(entries); ArrayResize(entries,n+1); ArrayResize(records,n+1);
      records[n]=proposal.proposed_record;
      ZeroMemory(entries[n]);
      entries[n].ingress_identity=records[n].ingress_identity;
      entries[n].publication_sequence=records[n].publication_sequence;
      entries[n].payload_digest=records[n].payload_digest;
      entries[n].lifecycle_state=records[n].lifecycle_state;
      entries[n].logical_correlation_id=records[n].logical_correlation_id;
      entries[n].reserved_request_sequence=records[n].reserved_request_sequence;
      entries[n].accepted_at=records[n].accepted_at;
      entries[n].bound_request_id=records[n].bound_request_id;
      entries[n].terminal_trust_disposition=records[n].terminal_disposition;
      entries[n].record_sequence=records[n].record_sequence;
      entries[n].record_revision=records[n].record_revision;
      entries[n].record_digest=records[n].record_digest;
      SortState();
      header.previous_revision=header.revision; header.revision=proposal.proposed_next_revision;
      header.membership_count=(uint)ArraySize(entries);
      if(proposal.proposed_record.publication_sequence>header.highest_accepted_publication_sequence)
         header.highest_accepted_publication_sequence=proposal.proposed_record.publication_sequence;
      SWV5S5_DeriveLedgerIndexDigest(entries,header.membership_binding_index_digest);
      SWV5S5_DeriveLedgerHeaderDigest(header,entries,header.ledger_digest);
      if(operation_corruption==4) header.ledger_digest=SWV5S5_SHA256_EMPTY;
      SWV5S5_Allow(context,"TEST_LEDGER_COMMITTED",result.authoritative_result);
      return true;
   }
};

class SWV5S5_ScriptedRequestSequenceAuthority : public ISWV5S5CoordinatorRequestSequenceAuthority
{
private:
   SWV5S5_RequestSequenceAuthority authority;
   SWV5S5_RequestSequenceIndexEntry entries[];

   void SortState(void)
   {
      for(int i=0;i<ArraySize(entries);i++)
         for(int j=i+1;j<ArraySize(entries);j++)
            if(StringCompare(entries[i].logical_correlation_id,entries[j].logical_correlation_id)>0)
            { SWV5S5_RequestSequenceIndexEntry e=entries[i]; entries[i]=entries[j]; entries[j]=e; }
   }

public:
   int call_count;
   int read_count;
   int read_corruption;
   int operation_corruption;

   SWV5S5_ScriptedRequestSequenceAuthority(void)
   { call_count=0; read_count=0; read_corruption=0; operation_corruption=0; ZeroMemory(authority); ArrayResize(entries,0); }

   bool Configure(const SWV5_PersistenceNamespace &scope,const SWV5_OwnershipFence &fence)
   {
      ZeroMemory(authority); SWV5S5_InitContractVersion(authority.contract_version);
      authority.policy_id=SWV5S5_REQUEST_BINDING_POLICY_ID;
      authority.policy_version=SWV5S5_REQUEST_BINDING_POLICY_VERSION;
      authority.persistence_namespace=scope; authority.ownership_fence=fence;
      authority.allocator_revision=1; authority.request_sequence_high_watermark=0;
      authority.reservation_count=0; ArrayResize(entries,0);
      return SWV5S5_DeriveSequenceIndexDigest(entries,authority.reservation_index_digest) &&
             SWV5S5_DeriveSequenceAuthorityDigest(authority,entries,authority.authority_digest);
   }

   virtual bool ReadState(const string event_id,const ulong event_ordinal,
                          SWV5S5_RequestSequenceAuthority &out_authority,
                          SWV5S5_RequestSequenceIndexEntry &out_entries[])
   {
      read_count++; out_authority=authority;
      ArrayResize(out_entries,ArraySize(entries));
      for(int i=0;i<ArraySize(entries);i++) out_entries[i]=entries[i];
      if(read_corruption==1) out_authority.authority_digest=SWV5S5_SHA256_EMPTY;
      if(read_corruption==2) out_authority.reservation_index_digest=SWV5S5_SHA256_EMPTY;
      return true;
   }

   virtual bool TryReserveRequestSequence(const SWV5S5_RequestSequenceAuthority &expected,
                                          const SWV5S5_RequestSequenceIndexEntry &expected_entries[],
                                          const SWV5S5_RequestSequenceReservation &proposal,
                                          const string event_id,const ulong event_ordinal,
                                          SWV5S5_CoordinatorSequenceOperationResult &operation)
   {
      call_count++; ZeroMemory(operation);
      operation.event_id=(operation_corruption==1 ? "PRIOR" : event_id);
      operation.event_ordinal=event_ordinal;
      operation.reservation_digest=(operation_corruption==2 ? SWV5S5_SHA256_EMPTY : proposal.reservation_digest);
      if(operation_corruption==10)
      {
         authority.allocator_revision++;
         SWV5S5_DeriveSequenceIndexDigest(entries,authority.reservation_index_digest);
         SWV5S5_DeriveSequenceAuthorityDigest(authority,entries,authority.authority_digest);
      }
      string expected_digest;
      SWV5S5_RequestSequenceResult prepared;
      if(!SWV5S5_DeriveSequenceAuthorityDigest(expected,expected_entries,expected_digest) ||
         expected.authority_digest!=expected_digest || expected.authority_digest!=authority.authority_digest ||
         ArraySize(expected_entries)!=ArraySize(entries) ||
         !SWV5S5_PrepareSequenceReservation(authority,entries,proposal,prepared)) return false;
      if(operation_corruption==3)
      {
         operation.authoritative_result=prepared;
         operation.authoritative_result.disposition=SWV5S5_SEQUENCE_RESERVED_NEW;
         operation.authoritative_result.resulting_authority_digest=SWV5S5_SHA256_ABC;
         return true;
      }
      int found=SWV5S5_FindSequenceReservation(entries,proposal.logical_correlation_id);
      if(found<0)
      {
         int n=ArraySize(entries); ArrayResize(entries,n+1); ZeroMemory(entries[n]);
         entries[n].logical_correlation_id=proposal.logical_correlation_id;
         entries[n].reserved_sequence=proposal.proposed_sequence;
         entries[n].reservation_revision=proposal.proposed_allocator_revision;
         entries[n].binding_digest=proposal.binding_digest;
         SortState();
         authority.allocator_revision=proposal.proposed_allocator_revision;
         authority.request_sequence_high_watermark=proposal.proposed_sequence;
         authority.reservation_count=(uint)ArraySize(entries);
         SWV5S5_DeriveSequenceIndexDigest(entries,authority.reservation_index_digest);
         SWV5S5_DeriveSequenceAuthorityDigest(authority,entries,authority.authority_digest);
         ZeroMemory(operation.authoritative_result); SWV5S5_InitContractVersion(operation.authoritative_result.contract_version);
         operation.authoritative_result.disposition=SWV5S5_SEQUENCE_RESERVED_NEW;
         operation.authoritative_result.logical_correlation_id=proposal.logical_correlation_id;
         operation.authoritative_result.reserved_sequence=proposal.proposed_sequence;
         operation.authoritative_result.resulting_allocator_revision=authority.allocator_revision;
         operation.authoritative_result.resulting_authority_digest=authority.authority_digest;
         operation.authoritative_result.reason_code="TEST_SEQUENCE_RESERVED_NEW";
      }
      else
      {
         operation.authoritative_result=prepared;
      }
      if(operation_corruption==4) operation.authoritative_result.resulting_allocator_revision=0;
      if(operation_corruption==5) operation.authoritative_result.resulting_authority_digest="";
      if(operation_corruption==6) operation.authoritative_result.logical_correlation_id="OTHER";
      if(operation_corruption==7) operation.authoritative_result.reserved_sequence++;
      if(operation_corruption==8 && found>=0)
      {
         entries[found].reserved_sequence++;
         authority.request_sequence_high_watermark=entries[found].reserved_sequence;
         SWV5S5_DeriveSequenceIndexDigest(entries,authority.reservation_index_digest);
         SWV5S5_DeriveSequenceAuthorityDigest(authority,entries,authority.authority_digest);
         operation.authoritative_result.reserved_sequence=entries[found].reserved_sequence;
         operation.authoritative_result.resulting_authority_digest=authority.authority_digest;
      }
      if(operation_corruption==9 && ArraySize(entries)>0)
      {
         int n=ArraySize(entries); ArrayResize(entries,n+1); entries[n]=entries[0];
         entries[n].logical_correlation_id="OTHER-CORRELATION";
         entries[n].reservation_revision=authority.allocator_revision;
         authority.reservation_count=(uint)ArraySize(entries);
         SWV5S5_DeriveSequenceIndexDigest(entries,authority.reservation_index_digest);
         SWV5S5_DeriveSequenceAuthorityDigest(authority,entries,authority.authority_digest);
      }
      return true;
   }
};

class SWV5S5_ScriptedBlueprintAuthority : public ISWV5S5CoordinatorBlueprintAuthority
{
public:
   int direction_override;
   int call_count;
   SWV5S5_ScriptedBlueprintAuthority(void) { direction_override=0; call_count=0; }
   virtual bool BuildInitial(const SWV5S5_CoordinatorMaterializationInput &materialization,
                             const SWV5S5_RequestBinding &binding,
                             SWV5S5_InitialRequestBlueprint &blueprint)
   {
      call_count++;
      ZeroMemory(blueprint); SWV5S5_InitContractVersion(blueprint.contract_version);
      blueprint.binding=binding;
      SWV5S5_TestInitV5(blueprint.pending_request.contract_version);
      SWV5S5_TestInitV5(blueprint.pending_request.intent.contract_version);
      blueprint.pending_request.intent.persistence_namespace=binding.persistence_namespace;
      blueprint.pending_request.intent.ownership_fence=materialization.normalized_payload.ownership_fence;
      SWV5S5_TestInitV5(blueprint.pending_request.intent.request_identity.contract_version);
      blueprint.pending_request.intent.request_identity.request_id.correlation_id=binding.logical_correlation_id;
      blueprint.pending_request.intent.request_identity.request_id.attempt_id=binding.attempt_id;
      blueprint.pending_request.intent.request_identity.request_id.parent_attempt_id="";
      blueprint.pending_request.intent.request_identity.request_id.monotonic_sequence=binding.logical_request_sequence;
      blueprint.pending_request.intent.request_identity.request_id.created_at=binding.accepted_at;
      blueprint.pending_request.intent.request_identity.idempotency_key=binding.idempotency_key;
      blueprint.pending_request.intent.account_mode=SWV5_ACCOUNT_MODE_HEDGING;
      blueprint.pending_request.intent.intent_type=SWV5_INTENT_OPEN;
      blueprint.pending_request.intent.direction=(direction_override==0 ? materialization.accepted_ingress.decision.direction : direction_override);
      blueprint.pending_request.intent.normalized_volume=materialization.normalized_payload.volume;
      blueprint.pending_request.intent.normalized_price=materialization.normalized_payload.price;
      blueprint.pending_request.intent.normalized_stop_price=materialization.normalized_payload.stop_price;
      blueprint.pending_request.intent.normalized_limit_price=materialization.normalized_payload.limit_price;
      blueprint.pending_request.intent.symbol_specification_sequence=materialization.normalized_payload.specification_sequence;
      blueprint.pending_request.intent.expected_basket_version=materialization.risk_authorization.basket_state_version;
      blueprint.pending_request.intent.risk_authorization_id=materialization.risk_authorization.authorization_id;
      blueprint.pending_request.intent.authorization_expires_at=materialization.risk_authorization.expires_at;
      blueprint.pending_request.account_mode=SWV5_ACCOUNT_MODE_HEDGING;
      blueprint.pending_request.lifecycle_phase=SWV5_EXECUTION_PHASE_INTENT;
      blueprint.pending_request.state=SWV5_REQUEST_CREATED;
      blueprint.pending_request.submission_attempt_count=0;
      blueprint.pending_request.cumulative_confirmed_volume=0.0;
      blueprint.pending_request.residual_requested_volume=materialization.normalized_payload.volume;
      blueprint.pending_request.retry_disposition=SWV5_RETRY_FORBIDDEN;
      blueprint.pending_request.authorization_identity=materialization.risk_authorization.authorization_id;
      blueprint.pending_request.normalization_identity=materialization.normalization_identity;
      blueprint.pending_request.last_changed_at=binding.accepted_at;
      return SWV5S5_DeriveInitialBlueprintDigest(blueprint,blueprint.blueprint_digest);
   }
};

class SWV5S5_ScriptedRequestProgressionAuthority : public ISWV5S5CoordinatorRequestProgressionAuthority
{
public:
   datetime changed_at;
   int mutation;
   int call_count;
   SWV5S5_ScriptedRequestProgressionAuthority(void) { changed_at=1000; mutation=0; call_count=0; }
   virtual bool ProgressToSubmission(const SWV5_PendingRequest &created,SWV5_PendingRequest &progressed)
   {
      call_count++;
      progressed=created;
      progressed.state=SWV5_REQUEST_SUBMISSION_PENDING;
      progressed.lifecycle_phase=SWV5_EXECUTION_PHASE_SUBMISSION;
      progressed.last_changed_at=changed_at;
      if(mutation==1) progressed.intent.direction=-created.intent.direction;
      if(mutation==2) progressed.intent.normalized_volume+=0.01;
      if(mutation==3) progressed.intent.normalized_price+=0.01;
      if(mutation==4) progressed.intent.symbol_specification_sequence++;
      if(mutation==5) progressed.intent.risk_authorization_id="OTHER-RISK";
      if(mutation==6) progressed.account_mode=SWV5_ACCOUNT_MODE_NETTING;
      if(mutation==7) progressed.intent.expected_basket_version++;
      if(mutation==8) progressed.intent.persistence_namespace.basket_id.value="OTHER-BASKET";
      if(mutation==9) progressed.intent.ownership_fence.takeover_generation++;
      if(mutation==10) progressed.intent.request_identity.request_id.attempt_id="OTHER-ATTEMPT";
      if(mutation==11) progressed.intent.request_identity.idempotency_key="OTHER-IDEMPOTENCY";
      if(mutation==12) progressed.state=SWV5_REQUEST_CONFIRMED;
      if(mutation==13) progressed.lifecycle_phase=SWV5_EXECUTION_PHASE_ACKNOWLEDGEMENT;
      if(mutation==14) progressed.normalization_identity="OTHER-NORMALIZATION";
      if(mutation==15) progressed.intent.authorization_expires_at++;
      if(mutation==16) progressed.state=SWV5_REQUEST_RISK_AUTHORIZED;
      return true;
   }
};

class SWV5S5_ScriptedExecutionLifecycleAuthority : public ISWV5ExecutionContract
{
public:
   bool allow;
   int call_count;
   SWV5S5_ScriptedExecutionLifecycleAuthority(void) { allow=true; call_count=0; }
   virtual string ContractName(void)
   {
      return "TEST-ONLY-SCRIPTED-EXECUTION-LIFECYCLE-AUTHORITY";
   }
   virtual bool ValidateIntent(const SWV5_ContractValidationContext &context,
                               const SWV5_ExecutionIntent &intent,
                               SWV5_ContractDecision &decision)
   {
      ZeroMemory(decision);
      decision.contract_version=context.expected_version;
      decision.disposition=SWV5_DISPOSITION_DENY;
      decision.reason_code="TEST_ONLY_UNSUPPORTED_VALIDATE_INTENT";
      decision.evaluation_sequence=context.evaluation_sequence;
      decision.evaluated_at=context.clock_time;
      return false;
   }
   virtual bool ValidatePhaseTransition(const SWV5_ContractValidationContext &context,
                                        const SWV5_ExecutionLifecyclePhase current_phase,
                                        const SWV5_ExecutionLifecyclePhase proposed_phase,
                                        SWV5_ContractDecision &decision)
   {
      call_count++; ZeroMemory(decision); decision.contract_version=context.expected_version;
      bool valid=allow && current_phase==SWV5_EXECUTION_PHASE_INTENT &&
                 proposed_phase==SWV5_EXECUTION_PHASE_SUBMISSION;
      decision.disposition=(valid ? SWV5_DISPOSITION_ALLOW : SWV5_DISPOSITION_DENY);
      decision.reason_code=(valid ? "V5_PHASE_TRANSITION_ALLOWED" : "V5_PHASE_TRANSITION_DENIED");
      decision.evaluation_sequence=context.evaluation_sequence;
      decision.evaluated_at=context.clock_time;
      return valid;
   }
   virtual bool ClassifyResultRetcode(const SWV5_ContractValidationContext &context,
                                      const SWV5_ResultRetcodeEvidence &evidence,
                                      SWV5_ResultRetcodeClassification &classification)
   {
      ZeroMemory(classification);
      return false;
   }
   virtual bool AcceptTransactionEvidence(const SWV5_ContractValidationContext &context,
                                          const SWV5_PendingRequest &pending,
                                          const SWV5_TransactionEvidence &evidence,
                                          SWV5_ExecutionConfirmation &confirmation)
   {
      ZeroMemory(confirmation);
      return false;
   }
   virtual bool EvaluateRetry(const SWV5_ContractValidationContext &context,
                              const SWV5_PendingRequest &pending,
                              const SWV5_RetryPolicy &policy,
                              const SWV5_RetryRiskFreshnessEvidence &risk_evidence,
                              const SWV5_RetryNormalizationFreshnessEvidence &normalization_evidence,
                              SWV5_ContractDecision &decision)
   {
      ZeroMemory(decision);
      decision.contract_version=context.expected_version;
      decision.disposition=SWV5_DISPOSITION_DENY;
      decision.reason_code="TEST_ONLY_UNSUPPORTED_RETRY";
      decision.evaluation_sequence=context.evaluation_sequence;
      decision.evaluated_at=context.clock_time;
      return false;
   }
};

class SWV5S5_ScriptedOwnershipAuthority : public ISWV5S5CoordinatorOwnershipAuthority
{
public:
   SWV5S5_CoordinatorDisposition scripted;
   SWV5S5_ScriptedOwnershipAuthority(void) { scripted=SWV5S5_COORD_TAKEOVER_RECONCILIATION; }
   virtual bool EvaluateTakeover(const string request_correlation_id,SWV5S5_CoordinatorDisposition &result)
   { result=scripted; return true; }
};

class SWV5S5_ScriptedFakeBroker : public ISWV5S5CoordinatorFakeBrokerPort
{
public:
   SWV5S5_FakeBrokerInvocation invocations[];
   SWV5S5_FakeBrokerOutcomeKind next_outcome;

   SWV5S5_ScriptedFakeBroker(void)
   {
      ArrayResize(invocations,0);
      next_outcome=SWV5S5_FAKE_BROKER_REQUEST_RECEIVED;
   }

   virtual bool InvokeFake(const SWV5S5_FakeBrokerInvocation &invocation,
                           SWV5S5_FakeBrokerResult &result)
   {
      int n=ArraySize(invocations);
      ArrayResize(invocations,n+1);
      invocations[n]=invocation;
      result.outcome=next_outcome;
      result.scripted_code="TEST_ONLY_SCRIPTED_OUTCOME";
      return next_outcome!=SWV5S5_FAKE_BROKER_OUTCOME_UNDEFINED;
   }

   int InvocationCount(void) { return ArraySize(invocations); }
};

class SWV5S5_TestTraceSink : public ISWV5S5CoordinatorTraceSink
{
public:
   SWV5S5_CoordinatorTraceEntry entries[];

   SWV5S5_TestTraceSink(void) { ArrayResize(entries,0); }

   virtual void Append(const SWV5S5_CoordinatorTraceEntry &entry)
   {
      int n=ArraySize(entries);
      ArrayResize(entries,n+1);
      entries[n]=entry;
   }

   int Count(void) { return ArraySize(entries); }
};

struct SWV5S5_TestQueueEvent
{
   SWV5S5_CoordinatorEventKind kind;
   string event_id;
   ulong ordinal;
};

class SWV5S5_DeterministicInMemoryTestQueue
{
private:
   SWV5S5_TestQueueEvent items[];
   int cursor;
public:
   SWV5S5_DeterministicInMemoryTestQueue(void)
   {
      ArrayResize(items,0);
      cursor=0;
   }

   void Enqueue(const SWV5S5_TestQueueEvent &event)
   {
      int n=ArraySize(items);
      ArrayResize(items,n+1);
      items[n]=event;
   }

   bool TryDequeue(SWV5S5_TestQueueEvent &event)
   {
      if(cursor>=ArraySize(items)) return false;
      event=items[cursor++];
      return true;
   }

   int Pending(void) { return ArraySize(items)-cursor; }
};

class SWV5S5_DeterministicTestDispatcher
{
public:
   // TEST ONLY: this typed dispatcher carries fixture inputs between actual
   // coordinator handlers. It grants no Ledger, Sequence, lifecycle, Claim, or
   // broker authority; every success comes from an injected owner double.
   bool Dispatch(SWV5S5_DeterministicCoordinator &coordinator,
                 const SWV5S5_TestQueueEvent &queued,
                 SWV5S5_CoordinatorIngressEvent &ingress_event,
                 SWV5S5_CoordinatorMaterializationInput &materialization,
                 SWV5S5_CoordinatorAdmissionEvent &admission_event,
                 SWV5S5_FakeBrokerResult &broker_response,
                 SWV5S5_SubmissionAuthorityRecord &claimed_record,
                 SWV5S5_ScriptedLedgerAuthority &ledger,
                 SWV5S5_ScriptedRequestSequenceAuthority &sequence,
                 SWV5S5_ScriptedBlueprintAuthority &blueprint,
                 SWV5S5_ScriptedRequestProgressionAuthority &progression,
                 SWV5S5_ScriptedExecutionLifecycleAuthority &lifecycle,
                 SWV5S5_ScriptedAdmissionPreparation &preparation,
                 SWV5S5_ScriptedClaimAuthority &claim,
                 SWV5S5_ScriptedOwnershipAuthority &ownership,
                 SWV5S5_ScriptedFakeBroker &fake_broker,
                 SWV5S5_TestTraceSink &trace,
                 SWV5S5_CoordinatorLedgerEvaluation &ledger_evaluation,
                 SWV5S5_IngressLedgerIndexEntry &ledger_entries[],
                 SWV5S5_IngressLedgerRecord &ledger_records[],
                 SWV5S5_CoordinatorMaterializationResult &materialized,
                 SWV5S5_CoordinatorResult &result)
   {
      if(queued.kind==SWV5S5_COORD_EVENT_ACCEPTED_INGRESS)
      {
         ingress_event.event_id=queued.event_id; ingress_event.event_ordinal=queued.ordinal;
         ingress_event.context.clock_sequence=queued.ordinal;
         ingress_event.context.evaluation_sequence=queued.ordinal;
         bool ok=coordinator.ProcessIngress(ingress_event,ledger,trace,ledger_evaluation,
                                            ledger_entries,ledger_records,result);
         if(ok)
         {
            materialization.event_id=queued.event_id;
            materialization.event_ordinal=queued.ordinal;
            materialization.context=ingress_event.context;
            materialization.accepted_ingress=ingress_event.ingress;
            materialization.ledger=ledger_evaluation;
         }
         return ok;
      }
      if(queued.kind==SWV5S5_COORD_EVENT_REQUEST_PROGRESSION)
      {
         materialization.event_id=queued.event_id; materialization.event_ordinal=queued.ordinal;
         materialization.context.clock_sequence=queued.ordinal;
         materialization.context.evaluation_sequence=queued.ordinal;
         return coordinator.MaterializeAndProgress(materialization,ledger_entries,ledger_records,ledger,sequence,
            blueprint,progression,lifecycle,materialized);
      }
      if(queued.kind==SWV5S5_COORD_EVENT_SUBMISSION_ADMISSION)
      {
         admission_event.event_id=queued.event_id; admission_event.event_ordinal=queued.ordinal;
         admission_event.request_correlation_id=materialized.progressed_request.intent.request_identity.request_id.correlation_id;
         admission_event.attempt_id=materialized.progressed_request.intent.request_identity.request_id.attempt_id;
         admission_event.normalized_payload_identity=materialized.progressed_request.normalization_identity;
         admission_event.request_state=materialized.progressed_request.state;
         admission_event.request_phase=materialized.progressed_request.lifecycle_phase;
         return coordinator.ProcessAdmission(admission_event,preparation,claim,fake_broker,trace,result);
      }
      if(queued.kind==SWV5S5_COORD_EVENT_OWNERSHIP_TAKEOVER)
         return coordinator.ProcessTakeover(claimed_record.permit.request_identity.request_id.correlation_id,
                                            ownership,result);
      if(queued.kind==SWV5S5_COORD_EVENT_RECONCILIATION_REQUIRED)
         return coordinator.ProcessReconciliationRequired(claimed_record,result);
      if(queued.kind==SWV5S5_COORD_EVENT_FAKE_BROKER_RESPONSE)
         return coordinator.ProcessFakeBrokerResponse(broker_response,result);
      return false;
   }
};

#endif
