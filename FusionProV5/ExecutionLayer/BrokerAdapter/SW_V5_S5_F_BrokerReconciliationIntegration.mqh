#ifndef SW_V5_S5_F_BROKER_RECONCILIATION_INTEGRATION_MQH
#define SW_V5_S5_F_BROKER_RECONCILIATION_INTEGRATION_MQH

// SPRINT 5 PHASE F BROKER RECONCILIATION INTEGRATION
// PURE PROJECTION ONLY / NO PLATFORM ACCESS / NO SUBMISSION / NO RETRY

#include "SW_V5_S5_F_BrokerAdapterCore.mqh"

bool SWV5S5_F_AdapterSyncResultBound(const SWV5S5_F_ReconciliationBinding &binding,
                                     const SWV5S5_F_AdapterSyncResult &sync_result)
{
   string digest;
   return sync_result.invocation_attempted && !sync_result.final_confirmation && !sync_result.retry_allowed &&
      sync_result.claim_id==binding.invocation_claim_id &&
      sync_result.claim_record_digest==binding.claim_record_digest &&
      sync_result.request_correlation_id==binding.request_identity.request_id.correlation_id &&
      sync_result.attempt_id==binding.request_identity.request_id.attempt_id &&
      sync_result.profile_digest==binding.profile.profile_digest &&
      SWV5S5_F_DeriveAdapterSyncResultDigest(sync_result,digest) && sync_result.result_digest==digest;
}

bool SWV5S5_F_AdapterDeriveOrderedDealSet(const SWV5S5_F_BrokerQuerySnapshot &snapshot,
                                          const ulong order_ticket,const ulong position_identifier,
                                          const int expected_direction,
                                          string &digest,uint &deal_count,double &confirmed_volume,
                                          ulong &first_deal_ticket,double &first_price,
                                          ulong &first_deal_position,bool &all_rows_read)
{
   string body="",f,row;
   deal_count=0; confirmed_volume=0.0; first_deal_ticket=0; first_price=0.0;
   first_deal_position=0; all_rows_read=true;
   for(int i=0;i<ArraySize(snapshot.history_deals);i++)
   {
      const SWV5S5_F_BrokerDealRow deal=snapshot.history_deals[i];
      if(!deal.read_success){ all_rows_read=false; continue; }
      if(deal.order_ticket!=order_ticket || deal.position_identifier!=position_identifier) continue;
      const int deal_direction=(deal.deal_type==0 ? 1 : (deal.deal_type==1 ? -1 : 0));
      if(deal_direction!=expected_direction || !MathIsValidNumber(deal.volume) ||
         !MathIsValidNumber(deal.price) || deal.volume<=0.0 || deal.price<=0.0)
      { all_rows_read=false; return false; }
      row="";
      if(!SWV5S5_CanonicalUInt("ticket",deal.ticket,f)) return false; row+=f;
      if(!SWV5S5_CanonicalUInt("order",deal.order_ticket,f)) return false; row+=f;
      if(!SWV5S5_CanonicalUInt("position",deal.position_identifier,f)) return false; row+=f;
      if(!SWV5S5_CanonicalInt("deal_type",deal.deal_type,f)) return false; row+=f;
      if(!SWV5S5_CanonicalInt("entry_type",deal.entry_type,f)) return false; row+=f;
      if(!SWV5S5_CanonicalDouble("volume",deal.volume,f)) return false; row+=f;
      if(!SWV5S5_CanonicalDouble("price",deal.price,f)) return false; row+=f;
      if(!SWV5S5_CanonicalDatetime("time_msc",deal.time_msc,f)) return false; row+=f;
      if(!SWV5S5_CanonicalIndexed("deal",(ulong)deal_count,row,f)) return false; body+=f;
      if(deal_count==0){ first_deal_ticket=deal.ticket; first_price=deal.price; first_deal_position=deal.position_identifier; }
      deal_count++; confirmed_volume+=deal.volume;
   }
   if(deal_count==0) return false;
   return SWV5S5_DomainDigest(SWV5S5_F_DOMAIN_POSITIVE_EVIDENCE,body,digest);
}

// Durable positive evidence requires the persisted sync-to-Claim mapping plus
// the broker-owned ordered order/deal/position relationship. Magic/comment only
// scope candidate rows and are never sufficient correlation authority.
bool SWV5S5_F_AdapterBuildPositiveEvidence(const SWV5_ContractValidationContext &context,
                                           const SWV5S5_F_ReconciliationBinding &binding,
                                           const SWV5S5_F_CorrelationPolicy &policy,
                                           const SWV5S5_F_CapabilityProof &capability_proof,
                                           const SWV5S5_F_AdapterSyncResult &sync_result,
                                           const SWV5S5_F_BrokerQuerySnapshot &snapshot,
                                           bool &runtime_side_effect_shape_found,
                                           SWV5S5_F_TargetedPositiveEvidence &evidence)
{
   ZeroMemory(evidence); SWV5S5_F_InitVersion(evidence.contract_version);
   runtime_side_effect_shape_found=false;
   if(!SWV5S5_F_EqualProfile(binding.profile,snapshot.profile) ||
      snapshot.snapshot_digest=="" || snapshot.query_set.snapshot_digest!=snapshot.snapshot_digest) return false;
   ulong selected_order=sync_result.order_ticket;
   if(selected_order==0) return false;
   SWV5S5_F_BrokerOrderRow order; ZeroMemory(order);
   bool order_found=false;
   for(int i=0;i<ArraySize(snapshot.history_orders);i++)
   {
      if(snapshot.history_orders[i].read_success && snapshot.history_orders[i].ticket==selected_order)
      { order=snapshot.history_orders[i]; order_found=true; break; }
   }
   if(!order_found || order.position_identifier==0 || order.symbol!=binding.profile.symbol ||
      order.magic!=SWV5_RUNTIME_STRATEGY_MAGIC) return false;
   const int order_direction=(order.order_type==0 ? 1 : (order.order_type==1 ? -1 : 0));
   bool linked_deal_shape=false;
   for(int i=0;i<ArraySize(snapshot.history_deals);i++)
      if(snapshot.history_deals[i].read_success && snapshot.history_deals[i].order_ticket==order.ticket &&
         snapshot.history_deals[i].position_identifier==order.position_identifier)
      { linked_deal_shape=true; break; }
   runtime_side_effect_shape_found=linked_deal_shape;

   uint deal_count=0; double confirmed=0.0,first_price=0.0;
   ulong first_deal=0,first_deal_position=0; bool all_rows_read=false; string deal_set_digest;
   if(order_direction==0 || !SWV5S5_F_AdapterDeriveOrderedDealSet(snapshot,order.ticket,order.position_identifier,
      order_direction,
      deal_set_digest,deal_count,confirmed,first_deal,first_price,first_deal_position,all_rows_read)) return false;

   evidence.profile=binding.profile;
   evidence.request_identity=binding.request_identity;
   evidence.invocation_claim_id=sync_result.claim_id;
   evidence.claim_record_digest=sync_result.claim_record_digest;
   evidence.correlation_policy_id=policy.policy_id;
   evidence.correlation_policy_version=policy.policy_version;
   evidence.correlation_policy_digest=policy.policy_digest;
   evidence.capability_proof_id=capability_proof.artifact_id;
   evidence.capability_proof_version=capability_proof.artifact_version;
   evidence.capability_proof_digest=capability_proof.proof_digest;
   evidence.independently_query_confirmed=snapshot.history_orders_enumeration_complete &&
      snapshot.history_deals_enumeration_complete && snapshot.row_read_failures==0;
   evidence.magic_used_as_sole_authority=false;
   evidence.comment_used_as_sole_authority=false;
   evidence.query_set=snapshot.query_set;
   evidence.query_set.required_flags=SWV5_QUERY_ORDERS|SWV5_QUERY_DEALS;
   evidence.query_set.completed_flags=SWV5_QUERY_ORDERS|SWV5_QUERY_DEALS;
   evidence.query_set.authoritative_flags=(SWV5S5_F_IsCapabilityProofValid(binding,capability_proof) &&
      capability_proof.correlation_capability_proven ? evidence.query_set.completed_flags : 0);
   evidence.query_set.issuing_component=SWV5_COMPONENT_AUTHORITY_BROKER_ADAPTER;
   evidence.query_set.authority_source=SWV5_AUTHORITY_DEAL_HISTORY;
   evidence.order_ticket=order.ticket;
   evidence.deal_ticket=first_deal;
   evidence.deal_order_ticket=order.ticket;
   evidence.deal_count=deal_count;
   evidence.ordered_deal_set_digest=deal_set_digest;
   evidence.all_deals_linked_to_order_and_position=true;
   evidence.all_rows_read_successfully=all_rows_read;
   evidence.position_identifier=order.position_identifier;
   evidence.order_position_identifier=order.position_identifier;
   evidence.deal_position_identifier=first_deal_position;
   evidence.symbol=order.symbol;
   evidence.direction=order_direction;
   evidence.execution_price=first_price;
   evidence.cumulative_confirmed_volume=confirmed;
   evidence.requested_volume=binding.requested_volume;
   evidence.observed_magic=order.magic;
   evidence.observed_comment=order.comment;
   evidence.observed_at=snapshot.observed_at;
   if(!SWV5S5_F_DerivePositiveEvidenceDigest(evidence,evidence.evidence_digest)) return false;
   return SWV5S5_F_AdapterSyncResultBound(binding,sync_result) &&
      SWV5S5_F_IsPositiveEvidenceValid(context,binding,policy,capability_proof,evidence);
}

uint SWV5S5_F_AdapterMatchingBrokerRows(const SWV5S5_F_ReconciliationBinding &binding,
                                        const SWV5S5_F_BrokerQuerySnapshot &snapshot,
                                        uint &positions,uint &orders,uint &deals,uint &transactions,
                                        uint &unrelated)
{
   positions=0; orders=0; deals=0; transactions=0; unrelated=0;
   for(int i=0;i<ArraySize(snapshot.positions);i++)
      if(snapshot.positions[i].read_success && snapshot.positions[i].symbol==binding.profile.symbol &&
         snapshot.positions[i].magic==SWV5_RUNTIME_STRATEGY_MAGIC) positions++; else unrelated++;
   for(int i=0;i<ArraySize(snapshot.orders);i++)
      if(snapshot.orders[i].read_success && snapshot.orders[i].symbol==binding.profile.symbol &&
         snapshot.orders[i].magic==SWV5_RUNTIME_STRATEGY_MAGIC) orders++; else unrelated++;
   for(int i=0;i<ArraySize(snapshot.history_orders);i++)
      if(snapshot.history_orders[i].read_success && snapshot.history_orders[i].symbol==binding.profile.symbol &&
         snapshot.history_orders[i].magic==SWV5_RUNTIME_STRATEGY_MAGIC) orders++; else unrelated++;
   for(int i=0;i<ArraySize(snapshot.history_deals);i++)
      if(snapshot.history_deals[i].read_success && snapshot.history_deals[i].symbol==binding.profile.symbol &&
         snapshot.history_deals[i].magic==SWV5_RUNTIME_STRATEGY_MAGIC) deals++; else unrelated++;
   for(int i=0;i<ArraySize(snapshot.callback_transactions);i++)
      if(snapshot.callback_transactions[i].profile_digest==binding.profile.profile_digest &&
         snapshot.callback_transactions[i].request_correlation_id==binding.request_identity.request_id.correlation_id &&
         snapshot.callback_transactions[i].attempt_id==binding.request_identity.request_id.attempt_id &&
         snapshot.callback_transactions[i].invocation_claim_id==binding.invocation_claim_id &&
         snapshot.callback_transactions[i].claim_record_digest==binding.claim_record_digest) transactions++; else unrelated++;
   return positions+orders+deals+transactions;
}

bool SWV5S5_F_AdapterBuildNegativeObservation(const SWV5S5_F_ReconciliationBinding &binding,
                                              const SWV5S5_F_CorrelationPolicy &correlation_policy,
                                              const SWV5S5_F_CapabilityProof &capability_proof,
                                              const SWV5S5_F_BrokerQuerySnapshot &broker,
                                              const SWV5S5_F_ExecutionPendingSnapshot &execution,
                                              SWV5S5_F_NegativeQueryObservation &observation)
{
   ZeroMemory(observation); SWV5S5_F_InitVersion(observation.contract_version);
   if(!SWV5S5_F_EqualProfile(binding.profile,broker.profile) ||
      !SWV5S5_F_EqualProfile(binding.profile,execution.profile) ||
      broker.snapshot_digest=="" || execution.snapshot_digest=="" ||
      broker.query_set.snapshot_digest!=broker.snapshot_digest ||
      execution.query_set.snapshot_digest!=execution.snapshot_digest) return false;
   observation.profile=binding.profile;
   observation.request_identity=binding.request_identity;
   observation.invocation_claim_id=binding.invocation_claim_id;
   observation.claim_record_digest=binding.claim_record_digest;
   observation.correlation_policy_id=correlation_policy.policy_id;
   observation.correlation_policy_version=correlation_policy.policy_version;
   observation.correlation_policy_digest=correlation_policy.policy_digest;
   observation.capability_proof_id=capability_proof.artifact_id;
   observation.capability_proof_version=capability_proof.artifact_version;
   observation.capability_proof_digest=capability_proof.proof_digest;
   observation.magic_used_as_sole_authority=false;
   observation.comment_used_as_sole_authority=false;
   observation.broker_query_set=broker.query_set;
   observation.execution_query_set=execution.query_set;
   observation.broker_operation_success=true;
   observation.execution_operation_success=execution.operation_success;
   observation.broker_enumeration_complete=broker.positions_enumeration_complete &&
      broker.orders_enumeration_complete && broker.history_orders_enumeration_complete &&
      broker.history_deals_enumeration_complete && broker.callback_transactions_enumeration_complete;
   observation.execution_enumeration_complete=execution.enumeration_complete;
   observation.broker_row_read_failures=broker.row_read_failures;
   observation.execution_row_read_failures=execution.row_read_failures;
   observation.history_from=broker.history_from; observation.history_to=broker.history_to;
   observation.connection_generation=broker.connection_generation;
   observation.restart_generation=broker.restart_generation;
   observation.broker_read_path_id=broker.broker_read_path_id;
   observation.execution_read_path_id=execution.execution_read_path_id;
   observation.broker_authority_instance_id=broker.broker_authority_instance_id;
   observation.execution_authority_instance_id=execution.execution_authority_instance_id;
   uint unrelated=0;
   SWV5S5_F_AdapterMatchingBrokerRows(binding,broker,observation.matching_positions,
      observation.matching_orders,observation.matching_deals,observation.matching_transactions,unrelated);
   observation.matching_pending_requests=execution.matching_pending_requests;
   observation.unrelated_rows=unrelated+execution.unrelated_rows;
   return SWV5S5_F_DeriveNegativeObservationDigest(observation,observation.observation_digest);
}

bool SWV5S5_F_AdapterBuildExecutionPendingSnapshot(
   const SWV5S5_F_ReconciliationBinding &binding,const SWV5_PendingRequest &requests[],
   const bool &row_read_success[],const bool operation_success,const bool enumeration_complete,
   const string execution_read_path_id,const string execution_authority_instance_id,
   const ulong owner_query_sequence,const ulong connection_generation,
   const ulong restart_generation,const datetime observed_at,
   SWV5S5_F_ExecutionPendingSnapshot &snapshot)
{
   ZeroMemory(snapshot); SWV5S5_F_InitVersion(snapshot.contract_version);
   snapshot.profile=binding.profile;
   snapshot.execution_read_path_id=execution_read_path_id;
   snapshot.execution_authority_instance_id=execution_authority_instance_id;
   snapshot.owner_query_sequence=owner_query_sequence;
   snapshot.connection_generation=connection_generation;
   snapshot.restart_generation=restart_generation;
   snapshot.observed_at=observed_at;
   snapshot.operation_success=operation_success;
   snapshot.enumeration_complete=enumeration_complete;
   if(ArraySize(requests)!=ArraySize(row_read_success) || execution_read_path_id=="" ||
      execution_authority_instance_id=="" || owner_query_sequence==0 ||
      connection_generation==0 || restart_generation==0 || observed_at<=0) return false;
   string body="",f,row;
   if(!SWV5S5_CanonicalString("profile_digest",binding.profile.profile_digest,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("read_path",execution_read_path_id,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("authority_instance",execution_authority_instance_id,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("sequence",owner_query_sequence,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("connection_generation",connection_generation,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("restart_generation",restart_generation,f)) return false; body+=f;
   if(!SWV5S5_CanonicalDatetime("observed_at",observed_at,f)) return false; body+=f;
   if(!SWV5S5_CanonicalBool("operation_success",operation_success,f)) return false; body+=f;
   for(int i=0;i<ArraySize(requests);i++)
   {
      if(!row_read_success[i]){ snapshot.row_read_failures++; snapshot.enumeration_complete=false; continue; }
      if(!SWV5S5_CanonicalPendingRequest(requests[i],row))
      { snapshot.row_read_failures++; snapshot.enumeration_complete=false; continue; }
      if(!SWV5S5_CanonicalIndexed("pending",(ulong)i,row,f)) return false; body+=f;
      if(SWV5S5_EqualRequestIdentity(requests[i].intent.request_identity,binding.request_identity))
         snapshot.matching_pending_requests++;
      else snapshot.unrelated_rows++;
   }
   if(!SWV5S5_CanonicalBool("enumeration_complete",snapshot.enumeration_complete,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("row_read_failures",snapshot.row_read_failures,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("matching_pending",snapshot.matching_pending_requests,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("unrelated_rows",snapshot.unrelated_rows,f)) return false; body+=f;
   if(!SWV5S5_DomainDigest(SWV5S5_F_ADAPTER_DOMAIN_EXECUTION_QUERY,body,snapshot.snapshot_digest)) return false;
   SWV5S5_InitContractVersion(snapshot.query_set.contract_version);
   snapshot.query_set.required_flags=SWV5_QUERY_PENDING_REQUESTS;
   snapshot.query_set.completed_flags=(snapshot.operation_success && snapshot.enumeration_complete ? SWV5_QUERY_PENDING_REQUESTS : 0);
   snapshot.query_set.authoritative_flags=(snapshot.row_read_failures==0 ? snapshot.query_set.completed_flags : 0);
   snapshot.query_set.observation_sequence=owner_query_sequence;
   snapshot.query_set.observed_at=observed_at;
   snapshot.query_set.issuing_component=SWV5_COMPONENT_AUTHORITY_EXECUTION;
   snapshot.query_set.authority_source=SWV5_AUTHORITY_EXECUTION_REQUEST_STATE;
   snapshot.query_set.snapshot_id=execution_authority_instance_id+":"+IntegerToString((long)owner_query_sequence);
   snapshot.query_set.snapshot_digest=snapshot.snapshot_digest;
   return true;
}

bool SWV5S5_F_AdapterEvaluate(const SWV5_ContractValidationContext &context,
                              const SWV5S5_F_ReconciliationInput &candidate,
                              SWV5S5_F_ReconciliationResult &result)
{
   // The accepted contract remains the sole terminal-state evaluator.
   return SWV5S5_F_EvaluateReconciliation(context,candidate,result);
}

bool SWV5S5_F_AdapterPublishResult(const SWV5_ContractValidationContext &context,
                                   SWV5S5_F_ReconciliationPublication &publication,
                                   ISWV5S5FReconciliationPublicationAuthority &authority,
                                   string &committed_store_revision)
{
   committed_store_revision="";
   if(!SWV5S5_F_AdapterValidatePublication(context,publication)) return false;
   return authority.TryPublishReconciliation(publication,committed_store_revision);
}

#endif // SW_V5_S5_F_BROKER_RECONCILIATION_INTEGRATION_MQH
