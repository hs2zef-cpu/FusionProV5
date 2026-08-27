#ifndef SW_V5_S5_DETERMINISTIC_COORDINATOR_MQH
#define SW_V5_S5_DETERMINISTIC_COORDINATOR_MQH

// SPRINT 5 PHASE C CANDIDATE
// SINGLE-THREADED EVENT-LOCAL COORDINATOR / NO DURABILITY OR PLATFORM ACCESS

#include "SW_V5_S5_CoordinatorCommon.mqh"

class SWV5S5_DeterministicCoordinator
{
private:
   bool EqualLedgerIndexEntry(const SWV5S5_IngressLedgerIndexEntry &a,
                              const SWV5S5_IngressLedgerIndexEntry &b)
   {
      return a.ingress_identity==b.ingress_identity &&
             a.publication_sequence==b.publication_sequence &&
             a.payload_digest==b.payload_digest &&
             a.lifecycle_state==b.lifecycle_state &&
             a.logical_correlation_id==b.logical_correlation_id &&
             a.reserved_request_sequence==b.reserved_request_sequence &&
             a.accepted_at==b.accepted_at &&
             a.bound_request_id==b.bound_request_id &&
             a.terminal_trust_disposition==b.terminal_trust_disposition &&
             a.record_sequence==b.record_sequence &&
             a.record_revision==b.record_revision &&
             a.record_digest==b.record_digest;
   }

   bool EqualLedgerRecord(const SWV5S5_IngressLedgerRecord &a,
                          const SWV5S5_IngressLedgerRecord &b)
   {
      return SWV5S5_EqualContractVersion(a.contract_version,b.contract_version) &&
             a.ingress_identity==b.ingress_identity &&
             a.payload_digest==b.payload_digest &&
             a.publication_sequence==b.publication_sequence &&
             a.lifecycle_state==b.lifecycle_state &&
             a.logical_correlation_id==b.logical_correlation_id &&
             a.reserved_request_sequence==b.reserved_request_sequence &&
             a.accepted_at==b.accepted_at &&
             a.bound_request_id==b.bound_request_id &&
             a.terminal_disposition==b.terminal_disposition &&
             a.record_sequence==b.record_sequence &&
             a.record_revision==b.record_revision &&
             a.record_digest==b.record_digest;
   }

   bool EqualSequenceIndexEntry(const SWV5S5_RequestSequenceIndexEntry &a,
                                const SWV5S5_RequestSequenceIndexEntry &b)
   {
      return a.logical_correlation_id==b.logical_correlation_id &&
             a.reserved_sequence==b.reserved_sequence &&
             a.reservation_revision==b.reservation_revision &&
             a.binding_digest==b.binding_digest;
   }

   bool ValidateLedgerSnapshot(const SWV5S5_IngressLedgerHeader &header,
                               const SWV5S5_IngressLedgerIndexEntry &entries[],
                               const SWV5S5_IngressLedgerRecord &records[])
   {
      string digest;
      return SWV5S5_IsCandidateVersion(header.contract_version) &&
             SWV5S5_DeriveLedgerHeaderDigest(header,entries,digest) &&
             header.ledger_digest==digest &&
             SWV5S5_ValidateLedgerRecordIndexLinkage(entries,records);
   }

   bool DeriveLedgerProposalDigest(const SWV5S5_IngressLedgerProposal &proposal,
                                   string &digest)
   {
      string body="",field;
      if(!SWV5S5_CanonicalString("expected_ledger_digest",proposal.expected_header.ledger_digest,field)) return false;
      body+=field;
      if(!SWV5S5_CanonicalString("proposed_record_digest",proposal.proposed_record.record_digest,field)) return false;
      body+=field;
      if(!SWV5S5_CanonicalUInt("proposed_next_revision",proposal.proposed_next_revision,field)) return false;
      body+=field;
      return SWV5S5_DomainDigest(SWV5S5_DOMAIN_INGRESS_LEDGER,body,digest);
   }

   bool PrepareLedgerProposal(const SWV5S5_CoordinatorIngressEvent &event,
                              const SWV5S5_IngressLedgerHeader &expected,
                              const string correlation,const ulong reservation,
                              const SWV5S5_IngressLifecycleState lifecycle,
                              SWV5S5_IngressLedgerProposal &proposal)
   {
      if(expected.revision==18446744073709551615) return false;
      ZeroMemory(proposal);
      proposal.expected_header=expected;
      proposal.proposed_next_revision=expected.revision+1;
      SWV5S5_InitContractVersion(proposal.proposed_record.contract_version);
      proposal.proposed_record.ingress_identity=event.ingress.ingress_identity;
      proposal.proposed_record.payload_digest=event.ingress.payload_digest;
      proposal.proposed_record.publication_sequence=event.ingress.publication.publication_sequence;
      proposal.proposed_record.lifecycle_state=lifecycle;
      proposal.proposed_record.logical_correlation_id=correlation;
      proposal.proposed_record.reserved_request_sequence=reservation;
      proposal.proposed_record.accepted_at=event.context.clock_time;
      proposal.proposed_record.bound_request_id="";
      proposal.proposed_record.terminal_disposition=(lifecycle==SWV5S5_REJECTED_NO_ENTRY ? "NO_ENTRY" : "");
      proposal.proposed_record.record_sequence=(ulong)expected.membership_count+1;
      proposal.proposed_record.record_revision=proposal.proposed_next_revision;
      if(!SWV5S5_DeriveLedgerRecordDigest(proposal.proposed_record,proposal.proposed_record.record_digest) ||
         !SWV5S5_ValidLedgerLifecycle(proposal.proposed_record)) return false;
      return DeriveLedgerProposalDigest(proposal,proposal.proposal_digest);
   }

   bool VerifyLedgerCommitted(const SWV5S5_IngressLedgerHeader &before,
                              const SWV5S5_IngressLedgerIndexEntry &before_entries[],
                              const SWV5S5_IngressLedgerRecord &before_records[],
                              const SWV5S5_IngressLedgerProposal &proposal,
                              const SWV5S5_IngressLedgerHeader &after,
                              const SWV5S5_IngressLedgerIndexEntry &after_entries[],
                              const SWV5S5_IngressLedgerRecord &after_records[],
                              SWV5S5_IngressLedgerRecord &committed)
   {
      if(!ValidateLedgerSnapshot(after,after_entries,after_records) ||
         !SWV5S5_EqualContractVersion(after.contract_version,before.contract_version) ||
         after.policy_id!=before.policy_id ||
         !SWV5S5_EqualNamespace(after.persistence_namespace,before.persistence_namespace) ||
         !SWV5S5_EqualFence(after.ownership_fence,before.ownership_fence) ||
         after.producer_authority_record_id!=before.producer_authority_record_id ||
         after.producer_authority_generation!=before.producer_authority_generation ||
         after.producer_instance!=before.producer_instance || after.producer_epoch!=before.producer_epoch ||
         after.compaction_generation!=before.compaction_generation ||
         after.revision!=proposal.proposed_next_revision ||
         after.previous_revision!=before.revision ||
         after.membership_count!=before.membership_count+1 ||
         after.highest_accepted_publication_sequence!=proposal.proposed_record.publication_sequence ||
         ArraySize(after_entries)!=ArraySize(before_entries)+1) return false;
      for(int i=0;i<ArraySize(before_entries);i++)
      {
         int preserved=SWV5S5_FindLedgerMembership(after_entries,before_entries[i].ingress_identity);
         if(preserved<0 || preserved>=ArraySize(after_records) || i>=ArraySize(before_records) ||
            !EqualLedgerIndexEntry(after_entries[preserved],before_entries[i]) ||
            !EqualLedgerRecord(after_records[preserved],before_records[i])) return false;
      }
      int found=SWV5S5_FindLedgerMembership(after_entries,proposal.proposed_record.ingress_identity);
      if(found<0 || found>=ArraySize(after_records)) return false;
      committed=after_records[found];
      return committed.record_digest==proposal.proposed_record.record_digest &&
             committed.ingress_identity==proposal.proposed_record.ingress_identity &&
             committed.payload_digest==proposal.proposed_record.payload_digest &&
             committed.publication_sequence==proposal.proposed_record.publication_sequence &&
             committed.lifecycle_state==proposal.proposed_record.lifecycle_state &&
             committed.logical_correlation_id==proposal.proposed_record.logical_correlation_id &&
             committed.reserved_request_sequence==proposal.proposed_record.reserved_request_sequence &&
             committed.accepted_at==proposal.proposed_record.accepted_at &&
             committed.bound_request_id==proposal.proposed_record.bound_request_id &&
             committed.terminal_disposition==proposal.proposed_record.terminal_disposition &&
             committed.record_sequence==proposal.proposed_record.record_sequence &&
             committed.record_revision==proposal.proposed_record.record_revision;
   }

   bool CommitLedger(const SWV5S5_CoordinatorIngressEvent &event,
                     ISWV5S5CoordinatorLedgerAuthority &ledger_authority,
                     const SWV5S5_IngressLedgerHeader &expected,
                     const SWV5S5_IngressLedgerIndexEntry &expected_entries[],
                     const SWV5S5_IngressLedgerRecord &expected_records[],
                     const string correlation,const ulong reservation,
                     const SWV5S5_IngressLifecycleState lifecycle,
                     SWV5S5_IngressLedgerHeader &resulting_header,
                     SWV5S5_IngressLedgerIndexEntry &resulting_entries[],
                     SWV5S5_IngressLedgerRecord &resulting_records[],
                     SWV5S5_IngressLedgerRecord &committed)
   {
      SWV5S5_IngressLedgerProposal proposal;
      if(!PrepareLedgerProposal(event,expected,correlation,reservation,lifecycle,proposal)) return false;
      SWV5S5_CoordinatorLedgerOperationResult operation;
      ZeroMemory(operation);
      if(!ledger_authority.TryCommitAcceptance(expected,expected_entries,expected_records,proposal,
                                                event.event_id,event.event_ordinal,operation) ||
         operation.event_id!=event.event_id || operation.event_ordinal!=event.event_ordinal ||
         operation.proposal_digest!=proposal.proposal_digest ||
         !SWV5S5_IsCandidateVersion(operation.authoritative_result.contract_version) ||
         operation.authoritative_result.disposition!=SWV5_DISPOSITION_ALLOW ||
         operation.authoritative_result.evaluation_sequence!=event.context.evaluation_sequence ||
         operation.authoritative_result.evaluated_at!=event.context.clock_time ||
         !ledger_authority.ReadSnapshot(event.event_id,event.event_ordinal,resulting_header,
                                        resulting_entries,resulting_records)) return false;
      return VerifyLedgerCommitted(expected,expected_entries,expected_records,proposal,resulting_header,
                                   resulting_entries,resulting_records,committed);
   }

   bool ValidateSequenceState(const SWV5S5_RequestSequenceAuthority &authority,
                              const SWV5S5_RequestSequenceIndexEntry &entries[])
   {
      string digest;
      return SWV5S5_IsCandidateVersion(authority.contract_version) &&
             authority.policy_id==SWV5S5_REQUEST_BINDING_POLICY_ID &&
             authority.policy_version==SWV5S5_REQUEST_BINDING_POLICY_VERSION &&
             SWV5S5_DeriveSequenceAuthorityDigest(authority,entries,digest) &&
             authority.authority_digest==digest &&
             SWV5S5_ValidateSequenceIndex(entries,authority.request_sequence_high_watermark,
                                          authority.allocator_revision);
   }

   bool ReserveAuthoritativeSequence(const SWV5S5_CoordinatorMaterializationInput &materialization,
                                     ISWV5S5CoordinatorRequestSequenceAuthority &sequence_authority,
                                     const string correlation,
                                     SWV5S5_RequestSequenceResult &authoritative)
   {
      SWV5S5_RequestSequenceAuthority expected;
      SWV5S5_RequestSequenceIndexEntry before[];
      if(!sequence_authority.ReadState(materialization.event_id,materialization.event_ordinal,expected,before) ||
         !ValidateSequenceState(expected,before) ||
         !SWV5S5_EqualNamespace(expected.persistence_namespace,materialization.ledger.header.persistence_namespace) ||
         !SWV5S5_EqualFence(expected.ownership_fence,materialization.ledger.header.ownership_fence)) return false;
      int existing=SWV5S5_FindSequenceReservation(before,correlation);
      SWV5S5_RequestSequenceReservation proposal;
      ZeroMemory(proposal); SWV5S5_InitContractVersion(proposal.contract_version);
      proposal.persistence_namespace=expected.persistence_namespace;
      proposal.ownership_fence=expected.ownership_fence;
      proposal.logical_correlation_id=correlation;
      proposal.binding_digest=materialization.accepted_ingress.payload_digest;
      proposal.expected_allocator_revision=expected.allocator_revision;
      proposal.expected_authority_digest=expected.authority_digest;
      proposal.observed_high_watermark=expected.request_sequence_high_watermark;
      proposal.proposed_sequence=(existing>=0 ? before[existing].reserved_sequence : expected.request_sequence_high_watermark+1);
      proposal.proposed_allocator_revision=(existing>=0 ? expected.allocator_revision : expected.allocator_revision+1);
      if(!SWV5S5_DeriveSequenceReservationDigest(proposal,proposal.reservation_digest)) return false;
      SWV5S5_RequestSequenceResult prepared;
      if(!SWV5S5_PrepareSequenceReservation(expected,before,proposal,prepared) ||
         (prepared.disposition!=SWV5S5_SEQUENCE_PROPOSAL_VALID &&
          prepared.disposition!=SWV5S5_SEQUENCE_EXISTING_IDEMPOTENT)) return false;
      SWV5S5_CoordinatorSequenceOperationResult operation;
      ZeroMemory(operation);
      if(!sequence_authority.TryReserveRequestSequence(expected,before,proposal,
                                                       materialization.event_id,materialization.event_ordinal,operation) ||
         operation.event_id!=materialization.event_id || operation.event_ordinal!=materialization.event_ordinal ||
         operation.reservation_digest!=proposal.reservation_digest) return false;
      authoritative=operation.authoritative_result;
      const SWV5S5_RequestSequenceDisposition required=(existing>=0 ?
         SWV5S5_SEQUENCE_EXISTING_IDEMPOTENT : SWV5S5_SEQUENCE_RESERVED_NEW);
      if(!SWV5S5_IsCandidateVersion(authoritative.contract_version) ||
         authoritative.disposition!=required || authoritative.logical_correlation_id!=correlation ||
         authoritative.reserved_sequence!=proposal.proposed_sequence || authoritative.reserved_sequence==0 ||
         authoritative.resulting_allocator_revision!=proposal.proposed_allocator_revision ||
         authoritative.resulting_authority_digest=="") return false;
      SWV5S5_RequestSequenceAuthority after;
      SWV5S5_RequestSequenceIndexEntry after_entries[];
      if(!sequence_authority.ReadState(materialization.event_id,materialization.event_ordinal,after,after_entries) ||
         !ValidateSequenceState(after,after_entries) ||
         !SWV5S5_EqualContractVersion(after.contract_version,expected.contract_version) ||
         after.policy_id!=expected.policy_id || after.policy_version!=expected.policy_version ||
         !SWV5S5_EqualNamespace(after.persistence_namespace,expected.persistence_namespace) ||
         !SWV5S5_EqualFence(after.ownership_fence,expected.ownership_fence) ||
         after.authority_digest!=authoritative.resulting_authority_digest ||
         after.allocator_revision!=authoritative.resulting_allocator_revision) return false;
      for(int i=0;i<ArraySize(before);i++)
      {
         int preserved=SWV5S5_FindSequenceReservation(after_entries,before[i].logical_correlation_id);
         if(preserved<0 || !EqualSequenceIndexEntry(after_entries[preserved],before[i])) return false;
      }
      int found=SWV5S5_FindSequenceReservation(after_entries,correlation);
      if(found<0 || after_entries[found].reserved_sequence!=authoritative.reserved_sequence ||
         after_entries[found].binding_digest!=proposal.binding_digest) return false;
      if(existing>=0)
         return after.authority_digest==expected.authority_digest && ArraySize(after_entries)==ArraySize(before);
      return after_entries[found].reservation_revision==proposal.proposed_allocator_revision &&
             after.request_sequence_high_watermark==expected.request_sequence_high_watermark+1 &&
             after.reservation_count==expected.reservation_count+1 &&
             ArraySize(after_entries)==ArraySize(before)+1;
   }

   bool ValidateProgressedRequestPreservation(const SWV5_ContractValidationContext &context,
                                              const SWV5_PendingRequest &created,
                                              const SWV5_PendingRequest &progressed,
                                              ISWV5ExecutionContract &lifecycle_authority)
   {
      SWV5_ContractDecision decision;
      ZeroMemory(decision);
      if(created.state!=SWV5_REQUEST_CREATED || created.lifecycle_phase!=SWV5_EXECUTION_PHASE_INTENT ||
         progressed.state!=SWV5_REQUEST_SUBMISSION_PENDING ||
         progressed.lifecycle_phase!=SWV5_EXECUTION_PHASE_SUBMISSION ||
         !lifecycle_authority.ValidatePhaseTransition(context,created.lifecycle_phase,
                                                      progressed.lifecycle_phase,decision) ||
         !SWV5S5_IsV5Version(decision.contract_version) ||
         decision.disposition!=SWV5_DISPOSITION_ALLOW ||
         decision.evaluation_sequence!=context.evaluation_sequence ||
         decision.evaluated_at!=context.clock_time ||
         progressed.last_changed_at!=context.clock_time ||
         progressed.last_changed_at<created.last_changed_at) return false;
      SWV5_PendingRequest normalized=progressed;
      normalized.state=created.state;
      normalized.lifecycle_phase=created.lifecycle_phase;
      normalized.last_changed_at=created.last_changed_at;
      string created_record,normalized_record;
      return SWV5S5_CanonicalPendingRequest(created,created_record) &&
             SWV5S5_CanonicalPendingRequest(normalized,normalized_record) &&
             created_record==normalized_record;
   }

   bool DeriveDirectionalRequestBinding(const SWV5_PersistenceNamespace &persistence_namespace,
                                        const string ingress_identity,const int direction,
                                        string &correlation_id,string &attempt_id,string &idempotency_key)
   {
      correlation_id=""; attempt_id=""; idempotency_key="";
      if(direction!=1 && direction!=-1) return false;
      return SWV5S5_DeriveRequestBinding(persistence_namespace,
                                         SWV5S5_REQUEST_BINDING_POLICY_ID,
                                         SWV5S5_REQUEST_BINDING_POLICY_VERSION,
                                         ingress_identity,0,
                                         correlation_id,attempt_id,idempotency_key);
   }

   void Emit(ISWV5S5CoordinatorTraceSink &sink,
             const SWV5S5_CoordinatorAdmissionEvent &event,
             const SWV5S5_CoordinatorTraceStep step,const int domain_disposition,
             const bool grant,const bool invoked,
             const SWV5S5_CoordinatorDisposition final_disposition)
   {
      SWV5S5_CoordinatorTraceEntry trace;
      ZeroMemory(trace);
      trace.event_id=event.event_id;
      trace.event_ordinal=event.event_ordinal;
      trace.step=step;
      trace.request_correlation_id=event.request_correlation_id;
      trace.attempt_id=event.attempt_id;
      trace.domain_disposition=domain_disposition;
      trace.claim_granted_in_current_event=grant;
      trace.fake_broker_invoked=invoked;
      trace.final_disposition=final_disposition;
      sink.Append(trace);
   }

   bool EventValid(const SWV5S5_CoordinatorAdmissionEvent &event)
   {
      return event.event_id!="" && event.event_ordinal>0 &&
             event.request_correlation_id!="" && event.attempt_id!="" &&
             event.normalized_payload_identity!="";
   }

   bool PreparedCommandCoherent(const SWV5S5_CoordinatorPreparedAdmission &prepared)
   {
      return prepared.claim_command.expected_authority_revision==
                prepared.claim_command.expected_authority_record.authority_revision &&
             prepared.transition.proposed_next_record.authority_revision==
                prepared.claim_command.expected_authority_revision+1 &&
             prepared.transition.proposed_next_record.permit.permit_id==
                prepared.claim_command.expected_authority_record.permit.permit_id &&
             prepared.transition.proposed_next_record.permit.permit_digest==
                prepared.claim_command.expected_authority_record.permit.permit_digest &&
             prepared.transition.proposed_next_record.invocation_claim_id==prepared.claim_command.claim_id &&
             prepared.transition.proposed_next_record.admission_snapshot_digest==
                prepared.claim_command.admission_proof.snapshot.snapshot_digest;
   }

   void Finish(SWV5S5_CoordinatorResult &result,
               const SWV5S5_CoordinatorDisposition disposition,
               const string reason,const bool grant,const bool invoked,
               const bool reconcile)
   {
      result.disposition=disposition;
      result.reason_code=reason;
      result.claim_granted_in_current_event=grant;
      result.fake_broker_invoked=invoked;
      result.reconciliation_required=reconcile;
   }

public:
   bool ProcessIngress(const SWV5S5_CoordinatorIngressEvent &event,
                       ISWV5S5CoordinatorLedgerAuthority &ledger_authority,
                       ISWV5S5CoordinatorTraceSink &trace_sink,
                       SWV5S5_CoordinatorLedgerEvaluation &ledger_evaluation,
                       SWV5S5_IngressLedgerIndexEntry &ledger_entries[],
                       SWV5S5_IngressLedgerRecord &ledger_records[],
                       SWV5S5_CoordinatorResult &result)
   {
      ZeroMemory(result);
      result.event_id=event.event_id;
      result.event_ordinal=event.event_ordinal;
      SWV5S5_CoordinatorAdmissionEvent diagnostic;
      ZeroMemory(diagnostic);
      diagnostic.event_id=event.event_id;
      diagnostic.event_ordinal=event.event_ordinal;
      SWV5S5_IngressValidationResult authoritative_result;
      ZeroMemory(authoritative_result);
      ZeroMemory(ledger_evaluation);
      ArrayResize(ledger_entries,0);
      ArrayResize(ledger_records,0);
      if(event.event_id=="" || event.event_ordinal==0 ||
         !SWV5S5_ValidateTrustedIngressForAcceptance(event.context,event.ingress,event.freshness,
                                                      event.current_trust,event.trust_anchor,event.trust_scope,
                                                      authoritative_result))
      {
         Finish(result,SWV5S5_COORD_ADMISSION_DENIED,"TRUSTED_INGRESS_DENIED",false,false,false);
         Emit(trace_sink,diagnostic,SWV5S5_COORD_TRACE_INGRESS_VALIDATED,
              (int)authoritative_result.disposition,false,false,result.disposition);
         return false;
      }
      if(!ledger_authority.ReadSnapshot(event.event_id,event.event_ordinal,ledger_evaluation.header,
                                        ledger_entries,ledger_records) ||
         !ValidateLedgerSnapshot(ledger_evaluation.header,ledger_entries,ledger_records) ||
         ledger_evaluation.header.policy_id!=SWV5S5_POLICY_ID ||
         !SWV5S5_EqualNamespace(ledger_evaluation.header.persistence_namespace,event.persistence_namespace) ||
         ledger_evaluation.header.producer_authority_record_id!=event.current_trust.authority_record_id ||
         ledger_evaluation.header.producer_authority_generation!=event.current_trust.authority_generation ||
         ledger_evaluation.header.producer_instance!=event.ingress.producer.producer_instance ||
         ledger_evaluation.header.producer_epoch!=event.ingress.producer.producer_epoch)
      {
         Finish(result,SWV5S5_COORD_ADMISSION_DENIED,"LEDGER_AUTHORITY_DENIED_OR_MISMATCHED",false,false,false);
         Emit(trace_sink,diagnostic,SWV5S5_COORD_TRACE_COMPLETED,
              (int)ledger_evaluation.disposition,false,false,result.disposition);
         return false;
      }
      ledger_evaluation.disposition=SWV5S5_EvaluateLedgerIngress(ledger_evaluation.header,ledger_entries,
         ledger_records,event.ingress.ingress_identity,event.ingress.payload_digest,
         event.ingress.publication.publication_sequence);
      ledger_evaluation.matched_index=SWV5S5_FindLedgerMembership(ledger_entries,event.ingress.ingress_identity);
      if(ledger_evaluation.matched_index>=0)
         ledger_evaluation.matched_record=ledger_records[ledger_evaluation.matched_index];
      if(ledger_evaluation.disposition==SWV5S5_INGRESS_EVALUATION_INVALID ||
         ledger_evaluation.disposition==SWV5S5_INGRESS_EVALUATION_CONFLICT ||
         ledger_evaluation.disposition==SWV5S5_INGRESS_EVALUATION_DENIED)
      { Finish(result,SWV5S5_COORD_ADMISSION_DENIED,"LEDGER_EVALUATION_FAIL_CLOSED",false,false,false); return false; }
      if(ledger_evaluation.disposition==SWV5S5_INGRESS_EVALUATION_DUPLICATE)
      {
         result.request_correlation_id=ledger_evaluation.matched_record.logical_correlation_id;
         if(authoritative_result.no_entry)
         {
            if(ledger_evaluation.matched_record.lifecycle_state!=SWV5S5_REJECTED_NO_ENTRY) return false;
            Finish(result,SWV5S5_COORD_NO_ENTRY,"DUPLICATE_NO_ENTRY_NO_REQUEST",false,false,false);
            return true;
         }
         if(ledger_evaluation.matched_record.lifecycle_state!=SWV5S5_ACCEPTED_REQUEST_PENDING &&
            ledger_evaluation.matched_record.lifecycle_state!=SWV5S5_BOUND_TO_REQUEST) return false;
         Finish(result,SWV5S5_COORD_LEDGER_DUPLICATE,"LEDGER_DUPLICATE_NO_NEW_SEQUENCE",false,false,false);
         Emit(trace_sink,diagnostic,SWV5S5_COORD_TRACE_COMPLETED,(int)ledger_evaluation.disposition,false,false,result.disposition);
         return true;
      }
      if(authoritative_result.no_entry)
      {
         SWV5S5_IngressLedgerHeader after_header;
         SWV5S5_IngressLedgerIndexEntry after_entries[];
         SWV5S5_IngressLedgerRecord after_records[],committed;
         if(!CommitLedger(event,ledger_authority,ledger_evaluation.header,ledger_entries,ledger_records,
                          "",0,SWV5S5_REJECTED_NO_ENTRY,after_header,after_entries,after_records,committed))
         { Finish(result,SWV5S5_COORD_ADMISSION_DENIED,"LEDGER_NO_ENTRY_COMMIT_INVALID",false,false,false); return false; }
         ledger_evaluation.header=after_header;
         ledger_evaluation.matched_record=committed;
         ledger_evaluation.matched_index=SWV5S5_FindLedgerMembership(after_entries,event.ingress.ingress_identity);
         ArrayResize(ledger_entries,ArraySize(after_entries));
         for(int i=0;i<ArraySize(after_entries);i++) ledger_entries[i]=after_entries[i];
         ArrayResize(ledger_records,ArraySize(after_records));
         for(int i=0;i<ArraySize(after_records);i++) ledger_records[i]=after_records[i];
         Finish(result,SWV5S5_COORD_NO_ENTRY,"WAIT_OR_BLOCKED_NO_REQUEST",false,false,false);
         return true;
      }
      if(!authoritative_result.directional_nomination || ledger_evaluation.disposition!=SWV5S5_INGRESS_EVALUATION_NEW)
      {
         Finish(result,SWV5S5_COORD_ADMISSION_DENIED,"LEDGER_DIRECTIONAL_ACCEPTANCE_DENIED",false,false,false);
         Emit(trace_sink,diagnostic,SWV5S5_COORD_TRACE_INGRESS_VALIDATED,
              (int)authoritative_result.disposition,false,false,result.disposition);
         return false;
      }
      string correlation,attempt,idempotency;
      if(!DeriveDirectionalRequestBinding(event.persistence_namespace,event.ingress.ingress_identity,
                                          event.ingress.decision.direction,correlation,attempt,idempotency)) return false;
      result.request_correlation_id=correlation;
      diagnostic.request_correlation_id=result.request_correlation_id;
      Finish(result,SWV5S5_COORD_LEDGER_ACCEPTED_NEW,
             (event.ingress.decision.direction==1 ? "BUY_LEDGER_NEW_VALIDATED" : "SELL_LEDGER_NEW_VALIDATED"),
             false,false,false);
      Emit(trace_sink,diagnostic,SWV5S5_COORD_TRACE_REQUEST_BOUND,
           (int)authoritative_result.disposition,false,false,result.disposition);
      return true;
   }

   bool MaterializeAndProgress(const SWV5S5_CoordinatorMaterializationInput &materialization,
                               const SWV5S5_IngressLedgerIndexEntry &ledger_entries[],
                               const SWV5S5_IngressLedgerRecord &ledger_records[],
                               ISWV5S5CoordinatorLedgerAuthority &ledger_authority,
                               ISWV5S5CoordinatorRequestSequenceAuthority &sequence_authority,
                               ISWV5S5CoordinatorBlueprintAuthority &blueprint_authority,
                               ISWV5S5CoordinatorRequestProgressionAuthority &progression_authority,
                               ISWV5ExecutionContract &lifecycle_authority,
                               SWV5S5_CoordinatorMaterializationResult &result)
   {
      ZeroMemory(result);
      string correlation,attempt,idempotency,binding_digest;
      if(materialization.ledger.disposition!=SWV5S5_INGRESS_EVALUATION_NEW ||
         !ValidateLedgerSnapshot(materialization.ledger.header,ledger_entries,ledger_records) ||
         SWV5S5_EvaluateLedgerIngress(materialization.ledger.header,ledger_entries,ledger_records,
            materialization.accepted_ingress.ingress_identity,materialization.accepted_ingress.payload_digest,
            materialization.accepted_ingress.publication.publication_sequence)!=SWV5S5_INGRESS_EVALUATION_NEW ||
         !DeriveDirectionalRequestBinding(materialization.ledger.header.persistence_namespace,
                                           materialization.accepted_ingress.ingress_identity,
                                           materialization.accepted_ingress.decision.direction,
                                           correlation,attempt,idempotency))
      { result.reason_code="ORDINAL_ZERO_BINDING_FAILED"; return false; }
      if(!ReserveAuthoritativeSequence(materialization,sequence_authority,correlation,result.sequence))
      { result.reason_code="SEQUENCE_AUTHORITY_DENIED"; return false; }
      SWV5S5_CoordinatorIngressEvent ledger_event;
      ZeroMemory(ledger_event);
      ledger_event.event_id=materialization.event_id;
      ledger_event.event_ordinal=materialization.event_ordinal;
      ledger_event.persistence_namespace=materialization.ledger.header.persistence_namespace;
      ledger_event.context=materialization.context;
      ledger_event.ingress=materialization.accepted_ingress;
      SWV5S5_IngressLedgerHeader committed_header;
      SWV5S5_IngressLedgerIndexEntry committed_entries[];
      SWV5S5_IngressLedgerRecord committed_records[],committed_record;
      if(!CommitLedger(ledger_event,ledger_authority,materialization.ledger.header,ledger_entries,ledger_records,
                       correlation,result.sequence.reserved_sequence,SWV5S5_ACCEPTED_REQUEST_PENDING,
                       committed_header,committed_entries,committed_records,committed_record))
      { result.reason_code="LEDGER_AUTHORITATIVE_COMMIT_INVALID"; return false; }
      ZeroMemory(result.binding); SWV5S5_InitContractVersion(result.binding.contract_version);
      result.binding.binding_policy_id=SWV5S5_REQUEST_BINDING_POLICY_ID;
      result.binding.binding_policy_version=SWV5S5_REQUEST_BINDING_POLICY_VERSION;
      result.binding.persistence_namespace=committed_header.persistence_namespace;
      result.binding.accepted_ingress_identity=materialization.accepted_ingress.ingress_identity;
      result.binding.accepted_at=committed_record.accepted_at;
      result.binding.logical_correlation_id=correlation;
      result.binding.logical_request_sequence=result.sequence.reserved_sequence;
      result.binding.attempt_ordinal=0;
      result.binding.attempt_id=attempt;
      result.binding.idempotency_key=idempotency;
      if(!SWV5S5_DeriveRequestBindingDigest(result.binding,binding_digest))
      { result.reason_code="BINDING_DIGEST_FAILED"; return false; }
      result.binding.binding_digest=binding_digest;
      SWV5S5_CoordinatorMaterializationInput authoritative_materialization=materialization;
      authoritative_materialization.ledger.header=committed_header;
      authoritative_materialization.ledger.matched_record=committed_record;
      authoritative_materialization.ledger.matched_index=SWV5S5_FindLedgerMembership(committed_entries,
         committed_record.ingress_identity);
      if(!blueprint_authority.BuildInitial(authoritative_materialization,result.binding,result.blueprint))
      { result.reason_code="BLUEPRINT_AUTHORITY_DENIED"; return false; }
      SWV5S5_ValidationResult blueprint_validation;
      if(!SWV5S5_ValidateInitialBlueprint(materialization.context,result.blueprint,materialization.accepted_ingress,
                                           committed_record,materialization.normalized_payload,
                                           materialization.normalization_identity,materialization.risk_authorization,
                                           blueprint_validation))
      { result.reason_code="FROZEN_INITIAL_BLUEPRINT_INVALID"; return false; }
      if(!progression_authority.ProgressToSubmission(result.blueprint.pending_request,result.progressed_request) ||
         !ValidateProgressedRequestPreservation(materialization.context,result.blueprint.pending_request,
                                                result.progressed_request,lifecycle_authority))
      { result.reason_code="REQUEST_PROGRESSION_NOT_ADMISSIBLE"; return false; }
      result.disposition=SWV5S5_COORD_REQUEST_SUBMISSION_READY;
      result.reason_code="OWNER_RETURNED_SUBMISSION_PENDING";
      return true;
   }

   bool ProcessTakeover(const string request_correlation_id,
                        ISWV5S5CoordinatorOwnershipAuthority &ownership_authority,
                        SWV5S5_CoordinatorResult &result)
   {
      ZeroMemory(result);
      SWV5S5_CoordinatorDisposition owner_result=SWV5S5_COORD_INVALID;
      if(request_correlation_id=="" ||
         !ownership_authority.EvaluateTakeover(request_correlation_id,owner_result))
      { result.disposition=SWV5S5_COORD_INVALID; result.reason_code="TAKEOVER_AUTHORITY_DENIED"; return false; }
      result.request_correlation_id=request_correlation_id;
      result.disposition=owner_result;
      result.reconciliation_required=(owner_result==SWV5S5_COORD_TAKEOVER_RECONCILIATION ||
                                      owner_result==SWV5S5_COORD_ALREADY_CLAIMED_UNCERTAIN);
      result.reason_code="OWNER_RETURNED_TAKEOVER_DISPOSITION";
      return true;
   }

   bool ProcessReconciliationRequired(const SWV5S5_SubmissionAuthorityRecord &record,
                                      SWV5S5_CoordinatorResult &result)
   {
      ZeroMemory(result);
      if(record.state!=SWV5S5_INVOCATION_CLAIMED_UNRESOLVED)
      { result.disposition=SWV5S5_COORD_INVALID; result.reason_code="RECONCILIATION_STATE_INVALID"; return false; }
      result.request_correlation_id=record.permit.request_identity.request_id.correlation_id;
      result.attempt_id=record.permit.unique_attempt_id;
      result.disposition=SWV5S5_COORD_CLAIMED_RECONCILIATION_REQUIRED;
      result.reconciliation_required=true;
      result.fake_broker_invoked=false;
      result.reason_code="CLAIMED_UNRESOLVED_NO_RETRY";
      return true;
   }

   bool ProcessFakeBrokerResponse(const SWV5S5_FakeBrokerResult &response,
                                  SWV5S5_CoordinatorResult &result)
   {
      ZeroMemory(result);
      if(response.outcome==SWV5S5_FAKE_BROKER_REQUEST_RECEIVED)
      {
         result.disposition=SWV5S5_COORD_BROKER_ACKNOWLEDGED;
         result.reason_code="ACKNOWLEDGEMENT_NOT_EXECUTION_CONFIRMATION";
         return true;
      }
      if(response.outcome==SWV5S5_FAKE_BROKER_REJECTED)
      {
         result.disposition=SWV5S5_COORD_FAKE_BROKER_REJECTED;
         result.reason_code="SCRIPTED_REJECTION_NOT_BASKET_MUTATION";
         return true;
      }
      result.disposition=SWV5S5_COORD_FAKE_BROKER_UNCERTAIN;
      result.reconciliation_required=true;
      result.reason_code="UNKNOWN_RESPONSE_RECONCILIATION_REQUIRED";
      return true;
   }

   bool ProcessAdmission(const SWV5S5_CoordinatorAdmissionEvent &event,
                         ISWV5S5CoordinatorAdmissionPreparation &preparation,
                         ISWV5S5CoordinatorInvocationClaimAuthority &claim_authority,
                         ISWV5S5CoordinatorFakeBrokerPort &fake_broker,
                         ISWV5S5CoordinatorTraceSink &trace_sink,
                         SWV5S5_CoordinatorResult &result)
   {
      ZeroMemory(result);
      result.event_id=event.event_id;
      result.event_ordinal=event.event_ordinal;
      result.request_correlation_id=event.request_correlation_id;
      result.attempt_id=event.attempt_id;
      Emit(trace_sink,event,SWV5S5_COORD_TRACE_EVENT_RECEIVED,0,false,false,SWV5S5_COORD_INVALID);

      if(!EventValid(event) ||
         event.request_state!=SWV5_REQUEST_SUBMISSION_PENDING ||
         event.request_phase!=SWV5_EXECUTION_PHASE_SUBMISSION)
      {
         Finish(result,SWV5S5_COORD_ADMISSION_DENIED,"REQUEST_LIFECYCLE_NOT_ADMISSIBLE",false,false,false);
         Emit(trace_sink,event,SWV5S5_COORD_TRACE_COMPLETED,0,false,false,result.disposition);
         return false;
      }

      SWV5S5_CoordinatorPreparedAdmission prepared;
      ZeroMemory(prepared);
      if(!preparation.PrepareSameEvent(event,prepared) ||
         prepared.event_id!=event.event_id || prepared.event_ordinal!=event.event_ordinal ||
         prepared.operation_token=="" || !prepared.transition.transition_eligible ||
         prepared.transition.disposition!=SWV5S5_CLAIM_TRANSITION_ELIGIBLE ||
         !PreparedCommandCoherent(prepared))
      {
         Finish(result,SWV5S5_COORD_ADMISSION_DENIED,"SAME_EVENT_ADMISSION_NOT_PREPARED",false,false,false);
         Emit(trace_sink,event,SWV5S5_COORD_TRACE_COMPLETED,(int)prepared.transition.disposition,false,false,result.disposition);
         return false;
      }
      Emit(trace_sink,event,SWV5S5_COORD_TRACE_ADMISSION_PREPARED,(int)prepared.transition.disposition,false,false,SWV5S5_COORD_INVALID);

      if(event.interruption_point==SWV5S5_COORD_INTERRUPT_BEFORE_CLAIM)
      {
         Finish(result,SWV5S5_COORD_INTERRUPTED_RECOLLECT,"PROVISIONAL_P_LOST_RECOLLECT",false,false,false);
         Emit(trace_sink,event,SWV5S5_COORD_TRACE_COMPLETED,(int)prepared.transition.disposition,false,false,result.disposition);
         return true;
      }

      SWV5S5_CoordinatorClaimOperationResult claim_operation;
      ZeroMemory(claim_operation);
      bool claim_call=claim_authority.TryClaimInvocation(prepared.claim_command,event.event_id,
         event.event_ordinal,prepared.operation_token,claim_operation);
      SWV5S5_InvocationClaimResult claim=claim_operation.claim;
      Emit(trace_sink,event,SWV5S5_COORD_TRACE_CLAIM_ATTEMPTED,(int)claim.disposition,claim.claim_granted_now,false,SWV5S5_COORD_INVALID);

      const bool operation_bound=claim_operation.event_id==event.event_id &&
         claim_operation.event_ordinal==event.event_ordinal &&
         claim_operation.operation_token==prepared.operation_token;
      const bool frozen_result_valid=claim_call && operation_bound &&
         SWV5S5_ValidateAuthoritativeClaimResult(prepared.transition,claim);

      const bool authoritative_grant=frozen_result_valid && claim.claim_granted_now &&
         claim.disposition==SWV5S5_CLAIM_GRANTED_NOW &&
         claim.resulting_authority_record.state==SWV5S5_INVOCATION_CLAIMED_UNRESOLVED &&
         claim.resulting_authority_record.permit.request_identity.request_id.correlation_id==event.request_correlation_id &&
         claim.resulting_authority_record.permit.request_identity.request_id.attempt_id==event.attempt_id &&
         claim.resulting_authority_record.permit.unique_attempt_id==event.attempt_id &&
         claim.resulting_authority_record.permit.normalization_identity==event.normalized_payload_identity;
      if(!authoritative_grant)
      {
         if(claim.claim_granted_now || claim.disposition==SWV5S5_CLAIM_GRANTED_NOW)
         {
            Finish(result,SWV5S5_COORD_INVALID,"AUTHORITATIVE_CLAIM_RESULT_INVALID_OR_REPLAYED",false,false,true);
            Emit(trace_sink,event,SWV5S5_COORD_TRACE_RECONCILIATION_REQUIRED,(int)claim.disposition,false,false,result.disposition);
            return false;
         }
         if(claim.resulting_authority_record.state==SWV5S5_INVOCATION_CLAIMED_UNRESOLVED ||
            claim.disposition==SWV5S5_CLAIM_ALREADY_CLAIMED)
         {
            Finish(result,SWV5S5_COORD_ALREADY_CLAIMED_UNCERTAIN,
                   "PERSISTED_CLAIM_HAS_NO_EVENT_LOCAL_GRANT",false,false,true);
            Emit(trace_sink,event,SWV5S5_COORD_TRACE_RECONCILIATION_REQUIRED,
                 (int)claim.disposition,false,false,result.disposition);
            return true;
         }
         SWV5S5_CoordinatorDisposition denied=(claim.disposition==SWV5S5_CLAIM_STALE_OWNER ?
                                                SWV5S5_COORD_STALE_OWNER : SWV5S5_COORD_CLAIM_DENIED);
         Finish(result,denied,"CLAIM_NOT_GRANTED_CURRENT_EVENT",false,false,false);
         Emit(trace_sink,event,SWV5S5_COORD_TRACE_COMPLETED,(int)claim.disposition,false,false,result.disposition);
         return false;
      }

      SWV5S5_ConditionalAdmissionResult completed;
      ZeroMemory(completed);
      SWV5S5_CompleteConditionalAdmission(claim,completed);
      if(!completed.claim_authorized || completed.operation_state!=SWV5S5_ADMISSION_COMPLETED)
      {
         Finish(result,SWV5S5_COORD_INVALID,"PHASE_B_ADMISSION_COMPLETION_REJECTED",false,false,true);
         Emit(trace_sink,event,SWV5S5_COORD_TRACE_RECONCILIATION_REQUIRED,(int)claim.disposition,false,false,result.disposition);
         return false;
      }
      Emit(trace_sink,event,SWV5S5_COORD_TRACE_CLAIM_GRANTED_CURRENT_EVENT,
           (int)claim.disposition,true,false,SWV5S5_COORD_INVALID);

      if(event.interruption_point==SWV5S5_COORD_INTERRUPT_AFTER_CLAIM_BEFORE_BROKER)
      {
         Finish(result,SWV5S5_COORD_CLAIMED_RECONCILIATION_REQUIRED,
                "CLAIM_COMMITTED_BROKER_NOT_INVOKED",true,false,true);
         Emit(trace_sink,event,SWV5S5_COORD_TRACE_RECONCILIATION_REQUIRED,(int)claim.disposition,true,false,result.disposition);
         return true;
      }

      SWV5S5_FakeBrokerInvocation invocation;
      ZeroMemory(invocation);
      invocation.event_id=event.event_id;
      invocation.event_ordinal=event.event_ordinal;
      invocation.event_local_invocation_sequence=1;
      // The broker record is projected from the complete owning-authority result,
      // never rebuilt from a locally asserted success state.
      invocation.request_correlation_id=claim.resulting_authority_record.permit.request_identity.request_id.correlation_id;
      invocation.attempt_id=claim.resulting_authority_record.permit.unique_attempt_id;
      invocation.normalized_payload_identity=claim.resulting_authority_record.permit.normalization_identity;
      invocation.claim_id=claim.resulting_authority_record.invocation_claim_id;
      invocation.direction=claim.resulting_authority_record.permit.risk_authorization.authorized_direction;
      if(invocation.direction!=1 && invocation.direction!=-1)
      {
         Finish(result,SWV5S5_COORD_INVALID,"AUTHORITATIVE_DIRECTION_INVALID",true,false,true);
         return false;
      }
      SWV5S5_FakeBrokerResult broker_result;
      ZeroMemory(broker_result);
      bool invoked=fake_broker.InvokeFake(invocation,broker_result);
      if(!invoked)
      {
         Finish(result,SWV5S5_COORD_FAKE_BROKER_UNCERTAIN,"FAKE_BROKER_NO_RESULT",true,true,true);
      }
      else if(broker_result.outcome==SWV5S5_FAKE_BROKER_REJECTED)
      {
         Finish(result,SWV5S5_COORD_FAKE_BROKER_REJECTED,"FAKE_BROKER_SCRIPTED_REJECTION",true,true,false);
      }
      else if(broker_result.outcome==SWV5S5_FAKE_BROKER_REQUEST_RECEIVED)
      {
         // Request receipt is only an acknowledgement, never execution confirmation.
         Finish(result,SWV5S5_COORD_FAKE_BROKER_INVOKED,"FAKE_BROKER_REQUEST_RECEIVED_NOT_CONFIRMED",true,true,false);
      }
      else
      {
         Finish(result,SWV5S5_COORD_FAKE_BROKER_UNCERTAIN,"FAKE_BROKER_UNCERTAIN",true,true,true);
      }
      Emit(trace_sink,event,SWV5S5_COORD_TRACE_FAKE_BROKER_INVOKED,(int)broker_result.outcome,true,true,result.disposition);
      return true;
   }
};

#endif
