//+------------------------------------------------------------------+
//| TEST ONLY                                                        |
//| NOT FOR PRODUCTION                                               |
//| NO BROKER ACCESS                                                 |
//+------------------------------------------------------------------+
#ifndef SW_V5_REFERENCE_VALIDATORS_MQH
#define SW_V5_REFERENCE_VALIDATORS_MQH

#include "SW_V5_TestFixtures.mqh"

bool SWV5_TestReadCanonicalField(const string canonical,int &offset,const string expected_name,const string expected_type,string &value);
bool SWV5_TestHardKillReleaseValid(const SWV5_ContractValidationContext &context,
                                   const SWV5_HardKillState &state,
                                   const SWV5_HardKillReleaseEvidence &evidence,
                                   const SWV5_HardKillReleaseValidationMode mode);
bool SWV5_TestHardKillReleaseValid(const SWV5_ContractValidationContext &context,
                                   const SWV5_HardKillState &state,
                                   const SWV5_HardKillReleaseEvidence &evidence);
bool SWV5_TestHistoricalHardKillReleaseValid(const SWV5_ContractValidationContext &context,
                                   const SWV5_HardKillState &state,
                                   const SWV5_HardKillReleaseEvidence &checkpoint_evidence,
                                   const SWV5_HardKillReleaseAuthorityRecord &authority_record);

enum SWV5_TestBasketRule
{
   SWV5_TEST_BASKET_FORBID=0,
   SWV5_TEST_BASKET_ALLOW=1,
   SWV5_TEST_BASKET_SAME=2
};

bool SWV5_TestNear(const double left,const double right,const double tolerance)
{
   return SWV5_IsFiniteNumber(left) && SWV5_IsFiniteNumber(right) &&
          SWV5_IsFiniteNumber(tolerance) && tolerance>=0.0 && MathAbs(left-right)<=tolerance;
}

bool SWV5_TestVersionEqual(const SWV5_ContractVersion &left,const SWV5_ContractVersion &right)
{
   return left.contract_name==right.contract_name &&
          left.schema_version==right.schema_version &&
          left.minimum_compatible_version==right.minimum_compatible_version &&
          left.policy_id==right.policy_id;
}

bool SWV5_TestVersionValid(const SWV5_ContractVersion &version)
{
   return version.contract_name==SWV5_PRODUCTION_CONTRACT_NAME &&
          version.schema_version==SWV5_PRODUCTION_CONTRACT_VERSION &&
          version.minimum_compatible_version==SWV5_PRODUCTION_MINIMUM_COMPATIBLE_VERSION &&
          version.policy_id==SWV5_PRODUCTION_CONTRACT_POLICY;
}

bool SWV5_TestContextValid(const SWV5_ContractValidationContext &context)
{
   return SWV5_TestVersionValid(context.expected_version) &&
          context.clock_id!="" &&
          context.clock_authority!=SWV5_TIME_AUTHORITY_NONE &&
          context.clock_time>0 &&
          context.clock_sequence>0 &&
          context.evaluation_sequence>0 &&
          SWV5_IsFiniteNumber(context.price_tolerance) && context.price_tolerance>=0.0 &&
          SWV5_IsFiniteNumber(context.volume_tolerance) && context.volume_tolerance>=0.0;
}

bool SWV5_TestExecutionPhaseValid(const SWV5_ExecutionLifecyclePhase phase)
{
   switch(phase)
   {
      case SWV5_EXECUTION_PHASE_INTENT:
      case SWV5_EXECUTION_PHASE_SUBMISSION:
      case SWV5_EXECUTION_PHASE_ACKNOWLEDGEMENT:
      case SWV5_EXECUTION_PHASE_AUTHORITATIVE_CONFIRMATION:
      case SWV5_EXECUTION_PHASE_PARTIAL_FILL:
      case SWV5_EXECUTION_PHASE_COMPLETED:
      case SWV5_EXECUTION_PHASE_REJECTED:
      case SWV5_EXECUTION_PHASE_UNCERTAIN: return true;
   }
   return false;
}

bool SWV5_TestRetryEligiblePhase(const SWV5_ExecutionLifecyclePhase phase)
{
   switch(phase)
   {
      case SWV5_EXECUTION_PHASE_SUBMISSION:
      case SWV5_EXECUTION_PHASE_ACKNOWLEDGEMENT: return true;
   }
   return false;
}

bool SWV5_TestIntentTypeValid(const SWV5_ExecutionIntentType intent_type)
{
   switch(intent_type)
   {
      case SWV5_INTENT_OPEN:
      case SWV5_INTENT_INCREASE:
      case SWV5_INTENT_REDUCE:
      case SWV5_INTENT_CLOSE:
      case SWV5_INTENT_CANCEL_PENDING: return true;
   }
   return false;
}

bool SWV5_TestPendingStateValid(const SWV5_PendingRequestState state)
{
   switch(state)
   {
      case SWV5_REQUEST_CREATED:
      case SWV5_REQUEST_RISK_AUTHORIZED:
      case SWV5_REQUEST_SUBMISSION_PENDING:
      case SWV5_REQUEST_ACKNOWLEDGED:
      case SWV5_REQUEST_CONFIRMATION_PENDING:
      case SWV5_REQUEST_CONFIRMED:
      case SWV5_REQUEST_PARTIALLY_CONFIRMED:
      case SWV5_REQUEST_REJECTED:
      case SWV5_REQUEST_EXPIRED:
      case SWV5_REQUEST_RECONCILIATION_REQUIRED:
      case SWV5_REQUEST_CANCELLED: return true;
   }
   return false;
}

bool SWV5_TestRetryEligiblePendingState(const SWV5_PendingRequestState state)
{
   switch(state)
   {
      case SWV5_REQUEST_SUBMISSION_PENDING:
      case SWV5_REQUEST_ACKNOWLEDGED:
      case SWV5_REQUEST_CONFIRMATION_PENDING: return true;
   }
   return false;
}

bool SWV5_TestRetryDispositionValid(const SWV5_RetryDisposition disposition)
{
   switch(disposition)
   {
      case SWV5_RETRY_FORBIDDEN:
      case SWV5_RETRY_AFTER_REVALIDATION:
      case SWV5_RETRY_AFTER_BACKOFF:
      case SWV5_RETRY_REQUIRES_NEW_AUTHORIZATION:
      case SWV5_RETRY_REQUIRES_RECONCILIATION: return true;
   }
   return false;
}

bool SWV5_TestRetryDispositionEligible(const SWV5_RetryDisposition disposition)
{
   switch(disposition)
   {
      case SWV5_RETRY_AFTER_REVALIDATION:
      case SWV5_RETRY_AFTER_BACKOFF:
      case SWV5_RETRY_REQUIRES_NEW_AUTHORIZATION: return true;
   }
   return false;
}

bool SWV5_TestRetcodeClassValid(const SWV5_ResultRetcodeClass value)
{
   switch(value)
   {
      case SWV5_RETCODE_UNCLASSIFIED:
      case SWV5_RETCODE_ACCEPTED_PENDING_CONFIRMATION:
      case SWV5_RETCODE_SYNCHRONOUS_DEAL_REPORTED_PENDING_EVIDENCE:
      case SWV5_RETCODE_REJECTED_PERMANENT:
      case SWV5_RETCODE_REJECTED_TRANSIENT:
      case SWV5_RETCODE_PRICE_CHANGED:
      case SWV5_RETCODE_VOLUME_CHANGED:
      case SWV5_RETCODE_MARKET_CLOSED:
      case SWV5_RETCODE_CONNECTION_UNCERTAIN:
      case SWV5_RETCODE_OWNERSHIP_CONFLICT:
      case SWV5_RETCODE_RECONCILIATION_REQUIRED: return true;
   }
   return false;
}

bool SWV5_TestConfirmationStatusValid(const SWV5_ConfirmationStatus value)
{
   switch(value)
   {
      case SWV5_CONFIRMATION_NOT_STARTED:
      case SWV5_CONFIRMATION_PENDING:
      case SWV5_CONFIRMATION_CONFIRMED:
      case SWV5_CONFIRMATION_REJECTED:
      case SWV5_CONFIRMATION_PARTIAL:
      case SWV5_CONFIRMATION_EXPIRED:
      case SWV5_CONFIRMATION_CONFLICT: return true;
   }
   return false;
}

bool SWV5_TestHardKillStateValid(const SWV5_HardKillLatchState value)
{
   switch(value)
   {
      case SWV5_HARD_KILL_INACTIVE:
      case SWV5_HARD_KILL_ACTIVE:
      case SWV5_HARD_KILL_RELEASE_PENDING:
      case SWV5_HARD_KILL_RELEASED: return true;
   }
   return false;
}

SWV5_ContractCompatibility SWV5_TestCompatibility(const SWV5_ContractVersion &candidate,
                                                   const SWV5_ContractValidationContext &context)
{
   if(!SWV5_TestContextValid(context) || candidate.contract_name=="" || candidate.policy_id!=SWV5_PRODUCTION_CONTRACT_POLICY)
      return SWV5_COMPATIBILITY_REJECTED;
   if(candidate.schema_version<SWV5_PRODUCTION_MINIMUM_COMPATIBLE_VERSION ||
      candidate.minimum_compatible_version>SWV5_PRODUCTION_CONTRACT_VERSION)
      return SWV5_COMPATIBILITY_MIGRATION_REQUIRED;
   if(SWV5_TestVersionEqual(candidate,context.expected_version))
      return SWV5_COMPATIBILITY_EXACT;
   return SWV5_COMPATIBILITY_REJECTED;
}

bool SWV5_TestOwnershipKeyEqual(const SWV5_OwnershipKey &left,const SWV5_OwnershipKey &right)
{
   return left.account_login==right.account_login &&
          left.broker_identity==right.broker_identity &&
          left.server==right.server &&
          left.symbol==right.symbol &&
          left.strategy_id==right.strategy_id &&
          left.magic==right.magic;
}

bool SWV5_TestOwnerEqual(const SWV5_OwnerIdentity &left,const SWV5_OwnerIdentity &right)
{
   return SWV5_TestOwnershipKeyEqual(left.key,right.key) &&
          left.instance_id==right.instance_id &&
          left.process_fingerprint==right.process_fingerprint &&
          left.started_at==right.started_at;
}

bool SWV5_TestFenceEqual(const SWV5_OwnershipFence &left,const SWV5_OwnershipFence &right)
{
   return SWV5_TestVersionEqual(left.contract_version,right.contract_version) &&
          SWV5_TestOwnershipKeyEqual(left.ownership_namespace,right.ownership_namespace) &&
          SWV5_TestOwnerEqual(left.owner,right.owner) &&
          left.lease_version==right.lease_version &&
          left.takeover_generation==right.takeover_generation &&
          left.fencing_token_digest==right.fencing_token_digest;
}

bool SWV5_TestFenceComplete(const SWV5_OwnershipFence &fence)
{
   return SWV5_TestVersionValid(fence.contract_version) &&
          fence.owner.instance_id!="" && fence.owner.process_fingerprint!="" &&
          SWV5_TestOwnershipKeyEqual(fence.ownership_namespace,fence.owner.key) &&
          fence.lease_version>0 && fence.takeover_generation>0 &&
          fence.fencing_token_digest!="";
}

bool SWV5_TestNamespaceEqual(const SWV5_PersistenceNamespace &left,const SWV5_PersistenceNamespace &right)
{
   return SWV5_TestVersionEqual(left.contract_version,right.contract_version) &&
          SWV5_TestOwnershipKeyEqual(left.ownership_namespace,right.ownership_namespace) &&
          left.basket_id.value==right.basket_id.value;
}

bool SWV5_TestNamespaceComplete(const SWV5_PersistenceNamespace &space)
{
   return SWV5_TestVersionValid(space.contract_version) &&
          space.ownership_namespace.account_login>0 &&
          space.ownership_namespace.broker_identity!="" &&
          space.ownership_namespace.server!="" &&
          space.ownership_namespace.symbol!="" &&
          space.ownership_namespace.strategy_id!="" &&
          space.ownership_namespace.magic>0 &&
          space.basket_id.value!="";
}

bool SWV5_TestRequestEqual(const SWV5_RequestID &left,const SWV5_RequestID &right)
{
   return left.correlation_id==right.correlation_id &&
          left.attempt_id==right.attempt_id &&
          left.parent_attempt_id==right.parent_attempt_id &&
          left.monotonic_sequence==right.monotonic_sequence &&
          left.created_at==right.created_at;
}

bool SWV5_TestRequestIdentityEqual(const SWV5_ExecutionRequestIdentity &left,
                                   const SWV5_ExecutionRequestIdentity &right)
{
   return SWV5_TestVersionEqual(left.contract_version,right.contract_version) &&
          SWV5_TestRequestEqual(left.request_id,right.request_id) &&
          left.idempotency_key==right.idempotency_key;
}

bool SWV5_TestRequestIdentityComplete(const SWV5_ExecutionRequestIdentity &identity)
{
   return SWV5_TestVersionValid(identity.contract_version) &&
          identity.request_id.correlation_id!="" && identity.request_id.attempt_id!="" &&
          identity.request_id.monotonic_sequence>0 && identity.request_id.created_at>0 &&
          identity.idempotency_key!="";
}

bool SWV5_TestCorrelationEqual(const SWV5_ExecutionCorrelation &left,const SWV5_ExecutionCorrelation &right)
{
   return SWV5_TestVersionEqual(left.contract_version,right.contract_version) &&
          left.phase==right.phase &&
          SWV5_TestRequestIdentityEqual(left.request_identity,right.request_identity) &&
          SWV5_TestVersionEqual(left.broker_identity.contract_version,right.broker_identity.contract_version) &&
          left.broker_identity.order_ticket==right.broker_identity.order_ticket &&
          left.broker_identity.deal_ticket==right.broker_identity.deal_ticket &&
          left.broker_identity.position_identifier==right.broker_identity.position_identifier &&
          left.broker_identity.broker_event_id==right.broker_identity.broker_event_id &&
          left.broker_identity.transaction_sequence==right.broker_identity.transaction_sequence;
}

bool SWV5_TestBrokerIdentityEqual(const SWV5_BrokerExecutionIdentity &left,const SWV5_BrokerExecutionIdentity &right)
{
   return SWV5_TestVersionEqual(left.contract_version,right.contract_version) &&
          left.order_ticket==right.order_ticket && left.deal_ticket==right.deal_ticket &&
          left.position_identifier==right.position_identifier && left.broker_event_id==right.broker_event_id &&
          left.transaction_sequence==right.transaction_sequence;
}

bool SWV5_TestCorrelationComplete(const SWV5_ExecutionCorrelation &correlation)
{
   if(!SWV5_TestVersionValid(correlation.contract_version) ||
      !SWV5_TestRequestIdentityComplete(correlation.request_identity) ||
      !SWV5_TestExecutionPhaseValid(correlation.phase))
      return false;
   if(correlation.phase==SWV5_EXECUTION_PHASE_INTENT || correlation.phase==SWV5_EXECUTION_PHASE_SUBMISSION)
      return correlation.broker_identity.order_ticket==0 && correlation.broker_identity.deal_ticket==0 &&
             correlation.broker_identity.position_identifier==0 && correlation.broker_identity.broker_event_id=="" &&
             correlation.broker_identity.transaction_sequence==0;
   if(!SWV5_TestVersionValid(correlation.broker_identity.contract_version))
      return false;
   if(correlation.phase==SWV5_EXECUTION_PHASE_ACKNOWLEDGEMENT)
      return correlation.broker_identity.order_ticket>0 &&
             correlation.broker_identity.deal_ticket==0 && correlation.broker_identity.position_identifier==0;
   switch(correlation.phase)
   {
      case SWV5_EXECUTION_PHASE_AUTHORITATIVE_CONFIRMATION:
      case SWV5_EXECUTION_PHASE_PARTIAL_FILL:
      case SWV5_EXECUTION_PHASE_COMPLETED:
      case SWV5_EXECUTION_PHASE_REJECTED:
      case SWV5_EXECUTION_PHASE_UNCERTAIN:
         return correlation.broker_identity.broker_event_id!="" &&
                correlation.broker_identity.transaction_sequence>0 &&
                (correlation.broker_identity.order_ticket>0 || correlation.broker_identity.deal_ticket>0 ||
                 correlation.broker_identity.position_identifier>0);
   }
   return false;
}

bool SWV5_TestEventIdentitySetContains(const SWV5_DurableEventIdentitySet &set,
                                        const SWV5_BrokerExecutionIdentity &identity)
{
   if(identity.broker_event_id=="" || identity.transaction_sequence==0)
      return false;
   int offset=0;
   while(offset<StringLen(set.canonical_event_index))
   {
      string entry,event_id,sequence_text;
      if(!SWV5_TestReadCanonicalField(set.canonical_event_index,offset,"entry","x",entry))
         return false;
      int entry_offset=0;
      if(!SWV5_TestReadCanonicalField(entry,entry_offset,"event_id","s",event_id) ||
         !SWV5_TestReadCanonicalField(entry,entry_offset,"transaction_sequence","u",sequence_text) ||
         entry_offset!=StringLen(entry))
         return false;
      const ulong sequence=(ulong)StringToInteger(sequence_text);
      if(event_id==identity.broker_event_id && sequence==identity.transaction_sequence)
         return true;
   }
   return false;
}

bool SWV5_TestEventSetIntegrityValid(const SWV5_DurableEventIdentitySet &set)
{
   if(!SWV5_TestVersionValid(set.contract_version) || set.compaction_generation==0 ||
      (set.fingerprint_policy!=SWV5_DURABLE_FINGERPRINT_IDENTITY_ONLY &&
       set.fingerprint_policy!=SWV5_DURABLE_FINGERPRINT_REQUIRED) ||
      set.identity_set_digest!=SWV5_TestEventSetDigest(set))
      return false;
   string event_ids[];
   ulong sequences[];
   ArrayResize(event_ids,0);
   ArrayResize(sequences,0);
   int offset=0,count=0;
   ulong highest=0;
   while(offset<StringLen(set.canonical_event_index))
   {
      string entry,event_id,sequence_text;
      if(!SWV5_TestReadCanonicalField(set.canonical_event_index,offset,"entry","x",entry))
         return false;
      int entry_offset=0;
      if(!SWV5_TestReadCanonicalField(entry,entry_offset,"event_id","s",event_id) ||
         !SWV5_TestReadCanonicalField(entry,entry_offset,"transaction_sequence","u",sequence_text) ||
         entry_offset!=StringLen(entry) || event_id=="" || sequence_text=="")
         return false;
      const ulong sequence=(ulong)StringToInteger(sequence_text);
      if(sequence==0 || StringFormat("%I64u",sequence)!=sequence_text)
         return false;
      for(int prior=0;prior<count;prior++)
         if(event_ids[prior]==event_id || sequences[prior]==sequence)
            return false;
      ArrayResize(event_ids,count+1);
      ArrayResize(sequences,count+1);
      event_ids[count]=event_id;
      sequences[count]=sequence;
      if(sequence>highest) highest=sequence;
      count++;
   }
   if(count!=(int)set.accepted_identity_count || highest!=set.highest_transaction_sequence ||
      (count==0 && set.canonical_event_index!="") || (count>0 && set.index_revision==0))
      return false;
   if(set.fingerprint_policy==SWV5_DURABLE_FINGERPRINT_IDENTITY_ONLY)
      return set.canonical_fingerprint_index=="";

   bool fingerprint_mapped[];
   ArrayResize(fingerprint_mapped,count);
   ArrayInitialize(fingerprint_mapped,false);
   int fingerprint_offset=0,fingerprint_count=0;
   while(fingerprint_offset<StringLen(set.canonical_fingerprint_index))
   {
      string entry,identity_value,fingerprint,event_id,sequence_text;
      if(!SWV5_TestReadCanonicalField(set.canonical_fingerprint_index,fingerprint_offset,"entry","x",entry))
         return false;
      int entry_offset=0,identity_offset=0;
      if(!SWV5_TestReadCanonicalField(entry,entry_offset,"identity","x",identity_value) ||
         !SWV5_TestReadCanonicalField(entry,entry_offset,"fingerprint","x",fingerprint) ||
         entry_offset!=StringLen(entry) || fingerprint=="" ||
         !SWV5_TestReadCanonicalField(identity_value,identity_offset,"event_id","s",event_id) ||
         !SWV5_TestReadCanonicalField(identity_value,identity_offset,"transaction_sequence","u",sequence_text) ||
         identity_offset!=StringLen(identity_value) || event_id=="" || sequence_text=="")
         return false;
      const ulong sequence=(ulong)StringToInteger(sequence_text);
      if(sequence==0 || StringFormat("%I64u",sequence)!=sequence_text)
         return false;
      int matched_index=-1;
      for(int index=0;index<count;index++)
         if(event_ids[index]==event_id && sequences[index]==sequence) { matched_index=index; break; }
      // Fingerprint-required sets are canonical in accepted-event order and
      // contain exactly one mapping for every accepted identity.
      if(matched_index<0 || matched_index!=fingerprint_count || fingerprint_mapped[matched_index])
         return false;
      fingerprint_mapped[matched_index]=true;
      fingerprint_count++;
   }
   if(fingerprint_count!=count)
      return false;
   for(int index=0;index<count;index++)
      if(!fingerprint_mapped[index]) return false;
   return true;
}

SWV5_StatisticsIdentityDisposition SWV5_TestAppendEventIdentity(const string event_id,
                                                                 const ulong sequence,
                                                                 const SWV5_DurableEventIdentitySet &current,
                                                                 SWV5_DurableEventIdentitySet &next)
{
   next=current;
   if(event_id=="" || sequence==0 || current.fingerprint_policy!=SWV5_DURABLE_FINGERPRINT_IDENTITY_ONLY ||
      !SWV5_TestEventSetIntegrityValid(current))
      return SWV5_STAT_IDENTITY_CONFLICT;
   int offset=0;
   while(offset<StringLen(current.canonical_event_index))
   {
      string entry,stored_event_id,stored_sequence_text;
      if(!SWV5_TestReadCanonicalField(current.canonical_event_index,offset,"entry","x",entry))
         return SWV5_STAT_IDENTITY_CONFLICT;
      int entry_offset=0;
      if(!SWV5_TestReadCanonicalField(entry,entry_offset,"event_id","s",stored_event_id) ||
         !SWV5_TestReadCanonicalField(entry,entry_offset,"transaction_sequence","u",stored_sequence_text) ||
         entry_offset!=StringLen(entry))
         return SWV5_STAT_IDENTITY_CONFLICT;
      const ulong stored_sequence=(ulong)StringToInteger(stored_sequence_text);
      if(stored_event_id==event_id && stored_sequence==sequence)
         return SWV5_STAT_IDENTITY_DUPLICATE;
      if(stored_event_id==event_id || stored_sequence==sequence)
         return SWV5_STAT_IDENTITY_CONFLICT;
   }
   next.canonical_event_index+=SWV5_TestCanonicalDurableEventEntry(event_id,sequence);
   next.accepted_identity_count++;
   if(sequence>next.highest_transaction_sequence)
      next.highest_transaction_sequence=sequence;
   next.index_revision++;
   next.identity_set_digest=SWV5_TestEventSetDigest(next);
   return sequence<current.highest_transaction_sequence ? SWV5_STAT_IDENTITY_OUT_OF_ORDER_NEW : SWV5_STAT_IDENTITY_NEW;
}

bool SWV5_TestReadCanonicalField(const string canonical,
                                 int &offset,
                                 const string expected_name,
                                 const string expected_type,
                                 string &value)
{
   const int name_end=StringFind(canonical,":",offset);
   if(name_end<offset) return false;
   const int type_end=StringFind(canonical,":",name_end+1);
   if(type_end<=name_end+1) return false;
   const int length_end=StringFind(canonical,":",type_end+1);
   if(length_end<=type_end+1) return false;
   const string name=StringSubstr(canonical,offset,name_end-offset);
   const string type=StringSubstr(canonical,name_end+1,type_end-name_end-1);
   const int length=(int)StringToInteger(StringSubstr(canonical,type_end+1,length_end-type_end-1));
   const int value_start=length_end+1;
   if(name!=expected_name || type!=expected_type || length<0 || value_start+length>StringLen(canonical))
      return false;
   value=StringSubstr(canonical,value_start,length);
   offset=value_start+length;
   return true;
}

string SWV5_TestCanonicalExecutionIdentity(const SWV5_BrokerExecutionIdentity &identity)
{
   return SWV5_TestCanonicalField("event_id","s",identity.broker_event_id)+
          SWV5_TestCanonicalUnsignedField("transaction_sequence",identity.transaction_sequence);
}

string SWV5_TestCanonicalExecutionFingerprintEntry(const SWV5_TransactionEvidence &evidence,
                                                    const string fingerprint)
{
   const string entry=SWV5_TestCanonicalField("identity","x",SWV5_TestCanonicalExecutionIdentity(evidence.correlation.broker_identity))+
                      SWV5_TestCanonicalField("fingerprint","x",fingerprint);
   return SWV5_TestCanonicalField("entry","x",entry);
}

string SWV5_TestCanonicalDurableIdentity(const string event_id,const ulong sequence)
{
   return SWV5_TestCanonicalField("event_id","s",event_id)+
          SWV5_TestCanonicalUnsignedField("transaction_sequence",sequence);
}

string SWV5_TestCanonicalDurableFingerprintEntry(const string event_id,
                                                  const ulong sequence,
                                                  const string fingerprint)
{
   const string entry=SWV5_TestCanonicalField("identity","x",SWV5_TestCanonicalDurableIdentity(event_id,sequence))+
                      SWV5_TestCanonicalField("fingerprint","x",fingerprint);
   return SWV5_TestCanonicalField("entry","x",entry);
}

SWV5_StatisticsIdentityDisposition SWV5_TestClassifyDurableFingerprint(const string event_id,
                                                                       const ulong sequence,
                                                                       const string fingerprint,
                                                                       const SWV5_DurableEventIdentitySet &current)
{
   if(!SWV5_TestEventSetIntegrityValid(current) ||
      current.fingerprint_policy!=SWV5_DURABLE_FINGERPRINT_REQUIRED ||
      event_id=="" || sequence==0 || fingerprint=="")
      return SWV5_STAT_IDENTITY_CONFLICT;
   int index_offset=0;
   bool exact_identity_found=false;
   string exact_fingerprint="";
   bool identity_component_conflict=false;
   while(index_offset<StringLen(current.canonical_fingerprint_index))
   {
      string entry;
      if(!SWV5_TestReadCanonicalField(current.canonical_fingerprint_index,index_offset,"entry","x",entry))
         return SWV5_STAT_IDENTITY_CONFLICT;
      int entry_offset=0;
      string identity_value,stored_fingerprint;
      if(!SWV5_TestReadCanonicalField(entry,entry_offset,"identity","x",identity_value) ||
         !SWV5_TestReadCanonicalField(entry,entry_offset,"fingerprint","x",stored_fingerprint) ||
         entry_offset!=StringLen(entry))
         return SWV5_STAT_IDENTITY_CONFLICT;
      int identity_offset=0;
      string stored_event_id,stored_sequence_text;
      if(!SWV5_TestReadCanonicalField(identity_value,identity_offset,"event_id","s",stored_event_id) ||
         !SWV5_TestReadCanonicalField(identity_value,identity_offset,"transaction_sequence","u",stored_sequence_text) ||
         identity_offset!=StringLen(identity_value))
         return SWV5_STAT_IDENTITY_CONFLICT;
      const ulong stored_sequence=(ulong)StringToInteger(stored_sequence_text);
      const bool same_event_id=stored_event_id==event_id;
      const bool same_sequence=stored_sequence==sequence;
      if(same_event_id && same_sequence)
      {
         if(exact_identity_found) return SWV5_STAT_IDENTITY_CONFLICT;
         exact_identity_found=true;
         exact_fingerprint=stored_fingerprint;
      }
      else if(same_event_id || same_sequence)
         identity_component_conflict=true;
   }
   if(exact_identity_found)
      return exact_fingerprint==fingerprint ? SWV5_STAT_IDENTITY_DUPLICATE : SWV5_STAT_IDENTITY_CONFLICT;
   if(identity_component_conflict)
      return SWV5_STAT_IDENTITY_CONFLICT;
   return sequence<current.highest_transaction_sequence ? SWV5_STAT_IDENTITY_OUT_OF_ORDER_NEW : SWV5_STAT_IDENTITY_NEW;
}

SWV5_StatisticsIdentityDisposition SWV5_TestAppendDurableFingerprint(const string event_id,
                                                                     const ulong sequence,
                                                                     const string fingerprint,
                                                                     const SWV5_DurableEventIdentitySet &current,
                                                                     SWV5_DurableEventIdentitySet &next)
{
   next=current;
   if(current.fingerprint_policy!=SWV5_DURABLE_FINGERPRINT_REQUIRED)
      return SWV5_STAT_IDENTITY_CONFLICT;
   const SWV5_StatisticsIdentityDisposition disposition=SWV5_TestClassifyDurableFingerprint(event_id,sequence,fingerprint,current);
   if(disposition!=SWV5_STAT_IDENTITY_NEW && disposition!=SWV5_STAT_IDENTITY_OUT_OF_ORDER_NEW)
      return disposition;
   next.canonical_event_index+=SWV5_TestCanonicalDurableEventEntry(event_id,sequence);
   next.canonical_fingerprint_index+=SWV5_TestCanonicalDurableFingerprintEntry(event_id,sequence,fingerprint);
   next.accepted_identity_count++;
   if(sequence>next.highest_transaction_sequence)
      next.highest_transaction_sequence=sequence;
   next.index_revision++;
   next.identity_set_digest=SWV5_TestEventSetDigest(next);
   return disposition;
}

SWV5_StatisticsIdentityDisposition SWV5_TestClassifyExecutionEvidence(const SWV5_TransactionEvidence &evidence,
                                                                      const SWV5_DurableEventIdentitySet &current,
                                                                      string &fingerprint)
{
   fingerprint=SWV5_TestCanonicalTransactionEvidence(evidence);
   return SWV5_TestClassifyDurableFingerprint(evidence.correlation.broker_identity.broker_event_id,
                                              evidence.correlation.broker_identity.transaction_sequence,
                                              fingerprint,current);
}

SWV5_StatisticsIdentityDisposition SWV5_TestAppendExecutionEvidence(const SWV5_TransactionEvidence &evidence,
                                                                    const SWV5_DurableEventIdentitySet &current,
                                                                    SWV5_DurableEventIdentitySet &next,
                                                                    string &fingerprint)
{
   next=current;
   const SWV5_StatisticsIdentityDisposition disposition=SWV5_TestClassifyExecutionEvidence(evidence,current,fingerprint);
   if(disposition!=SWV5_STAT_IDENTITY_NEW && disposition!=SWV5_STAT_IDENTITY_OUT_OF_ORDER_NEW)
      return disposition;
   return SWV5_TestAppendDurableFingerprint(evidence.correlation.broker_identity.broker_event_id,
                                            evidence.correlation.broker_identity.transaction_sequence,
                                            fingerprint,current,next);
}

bool SWV5_TestQueriesComplete(const SWV5_AuthoritativeQuerySet &queries)
{
   return SWV5_TestVersionValid(queries.contract_version) &&
          queries.required_flags>0 &&
          (queries.completed_flags&queries.required_flags)==queries.required_flags &&
          (queries.authoritative_flags&queries.required_flags)==queries.required_flags &&
          queries.observation_sequence>0;
}

SWV5_TestBasketRule SWV5_TestBasketPairRule(const SWV5_BasketState from_state,const SWV5_BasketState to_state)
{
   if(from_state<SWV5_BASKET_IDLE || from_state>SWV5_BASKET_ERROR ||
      to_state<SWV5_BASKET_IDLE || to_state>SWV5_BASKET_ERROR)
      return SWV5_TEST_BASKET_FORBID;
   if(from_state==to_state)
      return SWV5_TEST_BASKET_SAME;
   const int key=((int)from_state*7)+(int)to_state;
   switch(key)
   {
      case 1: case 5:
      case 9: case 11: case 12: case 13:
      case 17: case 18: case 19: case 20:
      case 23: case 25: case 26: case 27:
      case 28: case 33: case 34:
      case 35: case 39: case 41:
      case 47:
         return SWV5_TEST_BASKET_ALLOW;
   }
   return SWV5_TEST_BASKET_FORBID;
}

bool SWV5_TestBasketCauseValid(const SWV5_BasketState from_state,
                               const SWV5_BasketState to_state,
                               const SWV5_BasketTransitionCause cause)
{
   if(from_state==to_state)
      return cause==SWV5_TRANSITION_NONE;
   if(from_state==SWV5_BASKET_IDLE && to_state==SWV5_BASKET_OPENING)
      return cause==SWV5_TRANSITION_OPEN_AUTHORIZED;
   if(from_state==SWV5_BASKET_IDLE && to_state==SWV5_BASKET_HALTED)
      return cause==SWV5_TRANSITION_HARD_KILL || cause==SWV5_TRANSITION_OPERATOR_HALT;
   if(from_state==SWV5_BASKET_OPENING && to_state==SWV5_BASKET_ACTIVE)
      return cause==SWV5_TRANSITION_OPEN_CONFIRMED;
   if(from_state==SWV5_BASKET_OPENING && to_state==SWV5_BASKET_CLOSING)
      return cause==SWV5_TRANSITION_OPEN_PARTIAL || cause==SWV5_TRANSITION_CLOSE_AUTHORIZED;
   if((from_state==SWV5_BASKET_OPENING || from_state==SWV5_BASKET_ACTIVE ||
       from_state==SWV5_BASKET_RECOVERY || from_state==SWV5_BASKET_CLOSING) && to_state==SWV5_BASKET_HALTED)
      return cause==SWV5_TRANSITION_HARD_KILL || cause==SWV5_TRANSITION_OWNERSHIP_LOST ||
             cause==SWV5_TRANSITION_BROKER_STATE_UNCERTAIN;
   if(from_state==SWV5_BASKET_ACTIVE && to_state==SWV5_BASKET_RECOVERY)
      return cause==SWV5_TRANSITION_RECOVERY_AUTHORIZED;
   if((from_state==SWV5_BASKET_ACTIVE || from_state==SWV5_BASKET_RECOVERY) && to_state==SWV5_BASKET_CLOSING)
      return cause==SWV5_TRANSITION_CLOSE_AUTHORIZED || cause==SWV5_TRANSITION_MANDATORY_RISK_REDUCTION;
   if(from_state==SWV5_BASKET_RECOVERY && to_state==SWV5_BASKET_ACTIVE)
      return cause==SWV5_TRANSITION_RECOVERY_CONFIRMED;
   if(from_state==SWV5_BASKET_CLOSING && to_state==SWV5_BASKET_IDLE)
      return cause==SWV5_TRANSITION_CLOSE_CONFIRMED_EMPTY;
   if(from_state==SWV5_BASKET_HALTED && to_state==SWV5_BASKET_IDLE)
      return cause==SWV5_TRANSITION_OPERATOR_RESET;
   if(from_state==SWV5_BASKET_HALTED && to_state==SWV5_BASKET_CLOSING)
      return cause==SWV5_TRANSITION_CLOSE_AUTHORIZED || cause==SWV5_TRANSITION_RECONCILIATION_CONFIRMED;
   if(from_state==SWV5_BASKET_ERROR && to_state==SWV5_BASKET_HALTED)
      return cause==SWV5_TRANSITION_RECONCILIATION_CONFIRMED;
   if(to_state==SWV5_BASKET_ERROR)
      return cause==SWV5_TRANSITION_CONTRACT_VIOLATION || cause==SWV5_TRANSITION_RECONCILIATION_FAILED;
   return false;
}

bool SWV5_TestRecoveryRequestCommonValid(const SWV5_ContractValidationContext &context,
                                         const SWV5_BasketLifecycleSnapshot &snapshot,
                                         const SWV5_BasketTransitionRequest &request)
{
   return SWV5_TestContextValid(context) &&
          SWV5_TestVersionEqual(snapshot.contract_version,context.expected_version) &&
          SWV5_TestVersionEqual(request.contract_version,context.expected_version) &&
          SWV5_TestVersionEqual(request.recovery_evidence.contract_version,context.expected_version) &&
          snapshot.basket_id.value!="" && snapshot.basket_id.value==request.basket_id.value &&
          SWV5_TestFenceComplete(snapshot.ownership_fence) &&
          SWV5_TestFenceEqual(snapshot.ownership_fence,request.ownership_fence) &&
          SWV5_TestCorrelationComplete(request.correlation) &&
          SWV5_TestRequestIdentityComplete(request.recovery_evidence.request_identity) &&
          SWV5_TestRequestIdentityEqual(request.recovery_evidence.request_identity,request.correlation.request_identity) &&
          request.from_state==SWV5_BASKET_ACTIVE && request.to_state==SWV5_BASKET_RECOVERY &&
          request.cause==SWV5_TRANSITION_RECOVERY_AUTHORIZED &&
          request.risk_decision.disposition==SWV5_DISPOSITION_ALLOW &&
          request.risk_decision.evaluation_sequence>0 &&
          request.risk_decision.evaluated_at>0 && request.risk_decision.evaluated_at<=context.clock_time &&
          request.reconciliation_state==SWV5_RECONCILIATION_STATE_MATCHED &&
          request.confirmation_authority==SWV5_AUTHORITY_TRANSACTION_EVENT &&
          SWV5_TestQueriesComplete(request.broker_queries) &&
          request.recovery_evidence.authorization_id!="" &&
          request.recovery_evidence.evidence_identity!="" &&
          request.recovery_evidence.evidence_sequence>0 &&
          request.recovery_evidence.evidenced_at>0 &&
          request.recovery_evidence.evidenced_at<=request.evidence_time &&
          request.evidence_time<=context.clock_time &&
          request.recovery_evidence.proposed_cumulative_recovery_attempts==request.recovery_evidence.prior_cumulative_recovery_attempts+1 &&
          request.recovery_evidence.proposed_recovery_layer==request.recovery_evidence.prior_recovery_layer+1 &&
          snapshot.accepted_recovery_evidence.fingerprint_policy==SWV5_DURABLE_FINGERPRINT_REQUIRED &&
          SWV5_TestEventSetIntegrityValid(snapshot.accepted_recovery_evidence);
}

bool SWV5_TestRecoveryNewEnvelopeValid(const SWV5_ContractValidationContext &context,
                                       const SWV5_BasketLifecycleSnapshot &snapshot,
                                       const SWV5_BasketTransitionRequest &request)
{
   return SWV5_TestRecoveryRequestCommonValid(context,snapshot,request) &&
          snapshot.state==SWV5_BASKET_ACTIVE &&
          request.expected_state_version==snapshot.state_version &&
          request.recovery_evidence.prior_cumulative_recovery_attempts==snapshot.cumulative_recovery_attempts &&
          request.recovery_evidence.prior_recovery_layer==snapshot.current_recovery_layer;
}

bool SWV5_TestRecoveryReplayEnvelopeValid(const SWV5_ContractValidationContext &context,
                                          const SWV5_BasketLifecycleSnapshot &snapshot,
                                          const SWV5_BasketTransitionRequest &request)
{
   return SWV5_TestRecoveryRequestCommonValid(context,snapshot,request) &&
          snapshot.state==SWV5_BASKET_RECOVERY &&
          request.expected_state_version+1==snapshot.state_version &&
          request.recovery_evidence.proposed_cumulative_recovery_attempts==snapshot.cumulative_recovery_attempts &&
          request.recovery_evidence.proposed_recovery_layer==snapshot.current_recovery_layer;
}

bool SWV5_TestBasketEvidenceValid(const SWV5_ContractValidationContext &context,
                                  const SWV5_BasketLifecycleSnapshot &snapshot,
                                  const SWV5_BasketTransitionRequest &request)
{
   if(!SWV5_TestVersionValid(snapshot.contract_version) ||
      !SWV5_TestVersionValid(request.contract_version) ||
      snapshot.basket_id.value=="" ||
      snapshot.basket_id.value!=request.basket_id.value ||
      !SWV5_TestFenceEqual(snapshot.ownership_fence,request.ownership_fence) ||
      snapshot.state!=request.from_state ||
      snapshot.state_version!=request.expected_state_version ||
      !SWV5_TestBasketCauseValid(request.from_state,request.to_state,request.cause) ||
      !SWV5_TestQueriesComplete(request.broker_queries))
      return false;
   if(request.to_state==SWV5_BASKET_IDLE)
      return SWV5_TestNear(request.residual_volume,0.0,0.0000001) &&
             request.live_position_count==0 && request.live_order_count==0 && request.pending_request_count==0;
   if(request.from_state==SWV5_BASKET_IDLE && request.to_state==SWV5_BASKET_OPENING)
      return SWV5_TestNear(request.residual_volume,0.0,0.0000001) &&
             request.live_position_count==0 && request.live_order_count==0 && request.pending_request_count==0 &&
             request.risk_decision.disposition==SWV5_DISPOSITION_ALLOW &&
             request.reconciliation_state==SWV5_RECONCILIATION_STATE_MATCHED;
   if(request.to_state==SWV5_BASKET_ACTIVE)
      return request.confirmation_authority==SWV5_AUTHORITY_TRANSACTION_EVENT &&
             request.reconciliation_state==SWV5_RECONCILIATION_STATE_MATCHED;
   if(request.from_state==SWV5_BASKET_HALTED && request.to_state==SWV5_BASKET_CLOSING)
      return request.residual_volume>0.0 && request.reconciliation_state==SWV5_RECONCILIATION_STATE_MATCHED;
   if(request.from_state==SWV5_BASKET_ACTIVE && request.to_state==SWV5_BASKET_RECOVERY)
      return SWV5_TestRecoveryNewEnvelopeValid(context,snapshot,request);
   return true;
}

SWV5_TestBasketRule SWV5_TestEvaluateBasketTransition(const SWV5_ContractValidationContext &context,
                                                       const SWV5_BasketLifecycleSnapshot &snapshot,
                                                       const SWV5_BasketTransitionRequest &request,
                                                       ulong &resulting_version)
{
   resulting_version=snapshot.state_version;
   if(!SWV5_TestContextValid(context))
      return SWV5_TEST_BASKET_FORBID;
   const SWV5_TestBasketRule rule=SWV5_TestBasketPairRule(snapshot.state,request.to_state);
   if(rule==SWV5_TEST_BASKET_SAME)
      return rule;
   if(rule==SWV5_TEST_BASKET_ALLOW && SWV5_TestBasketEvidenceValid(context,snapshot,request))
   {
      resulting_version=snapshot.state_version+1;
      return SWV5_TEST_BASKET_ALLOW;
   }
   return SWV5_TEST_BASKET_FORBID;
}

bool SWV5_TestAggregateIdentityValid(const SWV5_BasketAggregate &basket)
{
   return SWV5_TestNamespaceComplete(basket.persistence_namespace) &&
          basket.persistence_namespace.basket_id.value==basket.lifecycle.basket_id.value &&
          SWV5_TestFenceComplete(basket.lifecycle.ownership_fence) &&
          basket.account_mode==SWV5_ACCOUNT_MODE_HEDGING;
}

bool SWV5_TestPartialCloseValid(const SWV5_BasketAggregate &basket,const SWV5_PartialCloseEvidence &evidence)
{
   return SWV5_TestNamespaceEqual(basket.persistence_namespace,evidence.persistence_namespace) &&
          SWV5_TestFenceEqual(basket.lifecycle.ownership_fence,evidence.ownership_fence) &&
          SWV5_TestCorrelationComplete(evidence.correlation) &&
          evidence.authority==SWV5_AUTHORITY_TRANSACTION_EVENT &&
          evidence.closed_volume>0.0 && evidence.closed_volume<=evidence.volume_before &&
          SWV5_TestNear(evidence.volume_before-evidence.closed_volume,evidence.residual_volume,0.0000001);
}

bool SWV5_TestCloseComplete(const SWV5_CloseVerificationEvidence &evidence)
{
   return evidence.state==SWV5_CLOSE_ZERO_RESIDUAL_CONFIRMED &&
          SWV5_TestNear(evidence.broker_residual_volume,0.0,0.0000001) &&
          evidence.broker_position_count==0 && evidence.broker_order_count==0 &&
          evidence.pending_request_count==0 && SWV5_TestQueriesComplete(evidence.broker_queries);
}

bool SWV5_TestSpecificationValid(const SWV5_ContractValidationContext &context,
                                 const SWV5_SymbolUnitSpecification &specification)
{
   return SWV5_TestVersionValid(specification.contract_version) && specification.complete &&
          specification.symbol!="" && specification.specification_sequence>0 &&
          specification.point_size>0.0 && specification.tick_size>0.0 && specification.pip_size>0.0 &&
          specification.tick_value_profit>0.0 && specification.tick_value_loss>0.0 &&
          specification.tick_value_basis_volume>0.0 && specification.contract_size>0.0 &&
          specification.calculation_mode==SWV5_SYMBOL_CALCULATION_XAU_QUANTITY &&
          specification.volume_minimum>0.0 && specification.volume_maximum>=specification.volume_minimum &&
          specification.volume_step>0.0 && specification.account_currency!="" &&
          specification.tick_value_currency==specification.account_currency &&
          specification.authority_source==SWV5_AUTHORITY_LIVE_BROKER_STATE &&
          specification.observed_at<=context.clock_time && specification.valid_until>=context.clock_time;
}

double SWV5_TestRoundToStep(const double value,const double step,const SWV5_NormalizationDirection direction)
{
   const double units=value/step;
   if(direction==SWV5_NORMALIZE_DOWN)
      return MathFloor(units+0.0000000001)*step;
   if(direction==SWV5_NORMALIZE_UP)
      return MathCeil(units-0.0000000001)*step;
   return MathRound(units)*step;
}

SWV5_UnitOperationSemantic SWV5_TestDeriveUnitSemantic(const SWV5_ContractValidationContext &context,
                                                       const SWV5_SymbolUnitSpecification &specification,
                                                       const SWV5_UnitNormalizationRequest &request)
{
   if(!SWV5_TestVersionEqual(request.contract_version,context.expected_version) ||
      !SWV5_TestNamespaceComplete(request.persistence_namespace) || !SWV5_TestFenceComplete(request.ownership_fence) ||
      !SWV5_TestOwnershipKeyEqual(request.persistence_namespace.ownership_namespace,request.ownership_fence.ownership_namespace) ||
      request.persistence_namespace.ownership_namespace.symbol!=specification.symbol ||
      (request.direction!=1 && request.direction!=-1) || request.raw_volume<0.0 ||
      request.current_exposure_volume<0.0 || request.target_exposure_volume<0.0)
      return SWV5_UNIT_OPERATION_INVALID;
   const bool increasing_kind=request.operation_kind==SWV5_OPERATION_MARKET_ENTRY || request.operation_kind==SWV5_OPERATION_PENDING_ENTRY;
   if(increasing_kind)
   {
      const bool open=request.intent_type==SWV5_INTENT_OPEN && request.current_exposure_volume<=context.volume_tolerance;
      const bool increase=request.intent_type==SWV5_INTENT_INCREASE && request.current_exposure_volume>context.volume_tolerance;
      if(request.purpose!=SWV5_PRICE_ENTRY || (!open && !increase) || !request.exposure_increasing || request.protective_operation ||
         request.target_exposure_volume<=request.current_exposure_volume+context.volume_tolerance ||
         !SWV5_TestNear(request.raw_volume,request.target_exposure_volume-request.current_exposure_volume,context.volume_tolerance))
         return SWV5_UNIT_OPERATION_INVALID;
      return open ? SWV5_UNIT_OPERATION_OPEN : SWV5_UNIT_OPERATION_INCREASE;
   }
   if(request.operation_kind==SWV5_OPERATION_REDUCE)
   {
      if(request.intent_type!=SWV5_INTENT_REDUCE || request.purpose!=SWV5_PRICE_CLOSE || request.exposure_increasing || request.protective_operation ||
         request.current_exposure_volume<=request.target_exposure_volume+context.volume_tolerance ||
         request.target_exposure_volume<=context.volume_tolerance ||
         !SWV5_TestNear(request.raw_volume,request.current_exposure_volume-request.target_exposure_volume,context.volume_tolerance))
         return SWV5_UNIT_OPERATION_INVALID;
      return SWV5_UNIT_OPERATION_REDUCE;
   }
   if(request.operation_kind==SWV5_OPERATION_CLOSE)
   {
      if(request.intent_type!=SWV5_INTENT_CLOSE || request.purpose!=SWV5_PRICE_CLOSE || request.exposure_increasing || request.protective_operation ||
         request.current_exposure_volume<=context.volume_tolerance || request.target_exposure_volume>context.volume_tolerance ||
         !SWV5_TestNear(request.raw_volume,request.current_exposure_volume,context.volume_tolerance))
         return SWV5_UNIT_OPERATION_INVALID;
      const bool aligned=SWV5_TestNear(request.current_exposure_volume/specification.volume_step,
                                       MathRound(request.current_exposure_volume/specification.volume_step),context.volume_tolerance);
      if(aligned && request.current_exposure_volume>=specification.volume_minimum-context.volume_tolerance)
         return SWV5_UNIT_OPERATION_FULL_CLOSE;
      if(request.current_exposure_volume<specification.volume_minimum-context.volume_tolerance)
         return SWV5_UNIT_OPERATION_RESIDUAL_CLOSE;
      return SWV5_UNIT_OPERATION_INVALID;
   }
   if(request.operation_kind==SWV5_OPERATION_MODIFY_STOP)
   {
      if(request.purpose!=SWV5_PRICE_STOP_LOSS || request.exposure_increasing || !request.protective_operation ||
         request.current_exposure_volume<=context.volume_tolerance ||
         !SWV5_TestNear(request.current_exposure_volume,request.target_exposure_volume,context.volume_tolerance) ||
         request.raw_volume>context.volume_tolerance || request.raw_stop_price<=0.0)
         return SWV5_UNIT_OPERATION_INVALID;
      return SWV5_UNIT_OPERATION_PROTECTIVE_STOP;
   }
   if(request.operation_kind==SWV5_OPERATION_MODIFY_LIMIT)
   {
      if(request.purpose!=SWV5_PRICE_TAKE_PROFIT || request.exposure_increasing || request.protective_operation ||
         request.current_exposure_volume<=context.volume_tolerance ||
         !SWV5_TestNear(request.current_exposure_volume,request.target_exposure_volume,context.volume_tolerance) ||
         request.raw_volume>context.volume_tolerance || request.raw_limit_price<=0.0)
         return SWV5_UNIT_OPERATION_INVALID;
      return SWV5_UNIT_OPERATION_LIMIT_TARGET;
   }
   return SWV5_UNIT_OPERATION_INVALID;
}

bool SWV5_TestNormalize(const SWV5_ContractValidationContext &context,
                        const SWV5_SymbolUnitSpecification &specification,
                        const SWV5_UnitNormalizationRequest &request,
                        SWV5_NormalizedUnits &normalized)
{
   if(!SWV5_TestContextValid(context) || !SWV5_TestSpecificationValid(context,specification) ||
      request.expected_specification_sequence!=specification.specification_sequence ||
      request.market_bid<=0.0 || request.market_ask<=0.0 || request.market_ask<request.market_bid ||
      request.reference_market_price<=0.0 || request.operation_price<=0.0)
      return false;
   const SWV5_UnitOperationSemantic semantic=SWV5_TestDeriveUnitSemantic(context,specification,request);
   if(semantic==SWV5_UNIT_OPERATION_INVALID)
      return false;
   normalized.contract_version=request.contract_version;
   normalized.persistence_namespace=request.persistence_namespace;
   normalized.ownership_fence=request.ownership_fence;
   normalized.derived_operation_semantic=semantic;
   const bool closing=semantic==SWV5_UNIT_OPERATION_REDUCE || semantic==SWV5_UNIT_OPERATION_FULL_CLOSE || semantic==SWV5_UNIT_OPERATION_RESIDUAL_CLOSE;
   const SWV5_NormalizationDirection entry_rounding=(closing ? (request.direction>0 ? SWV5_NORMALIZE_DOWN : SWV5_NORMALIZE_UP) :
                                                      (request.direction>0 ? SWV5_NORMALIZE_UP : SWV5_NORMALIZE_DOWN));
   const SWV5_NormalizationDirection stop_rounding=(request.direction>0 ? SWV5_NORMALIZE_DOWN : SWV5_NORMALIZE_UP);
   const SWV5_NormalizationDirection limit_rounding=(request.direction>0 ? SWV5_NORMALIZE_DOWN : SWV5_NORMALIZE_UP);
   const SWV5_NormalizationDirection volume_rounding=(semantic==SWV5_UNIT_OPERATION_OPEN || semantic==SWV5_UNIT_OPERATION_INCREASE || semantic==SWV5_UNIT_OPERATION_REDUCE ?
                                                       SWV5_NORMALIZE_DOWN : SWV5_NORMALIZE_NEAREST);
   normalized.price=SWV5_TestRoundToStep(request.raw_price,specification.tick_size,entry_rounding);
   normalized.stop_price=(request.raw_stop_price>0.0 ? SWV5_TestRoundToStep(request.raw_stop_price,specification.tick_size,stop_rounding) : 0.0);
   normalized.limit_price=(request.raw_limit_price>0.0 ? SWV5_TestRoundToStep(request.raw_limit_price,specification.tick_size,limit_rounding) : 0.0);
   const bool exact_close=semantic==SWV5_UNIT_OPERATION_FULL_CLOSE || semantic==SWV5_UNIT_OPERATION_RESIDUAL_CLOSE;
   const bool price_only=semantic==SWV5_UNIT_OPERATION_PROTECTIVE_STOP || semantic==SWV5_UNIT_OPERATION_LIMIT_TARGET;
   normalized.volume=(exact_close ? request.current_exposure_volume : (price_only ? 0.0 : SWV5_TestRoundToStep(request.raw_volume,specification.volume_step,volume_rounding)));
   normalized.current_exposure_volume=request.current_exposure_volume;
   normalized.target_exposure_volume=request.target_exposure_volume;
   if(semantic==SWV5_UNIT_OPERATION_OPEN || semantic==SWV5_UNIT_OPERATION_INCREASE)
      normalized.resulting_exposure_volume=request.current_exposure_volume+normalized.volume;
   else if(semantic==SWV5_UNIT_OPERATION_REDUCE)
      normalized.resulting_exposure_volume=MathMax(0.0,request.current_exposure_volume-normalized.volume);
   else if(exact_close)
      normalized.resulting_exposure_volume=0.0;
   else
      normalized.resulting_exposure_volume=request.current_exposure_volume;
   normalized.residual_exposure_volume=MathAbs(normalized.resulting_exposure_volume-request.target_exposure_volume);
   normalized.stop_distance_price=MathAbs(request.operation_price-normalized.stop_price);
   normalized.stop_distance_points=(request.raw_stop_price>0.0 ? normalized.stop_distance_price/specification.point_size : 0.0);
   normalized.stop_distance_ticks=(request.raw_stop_price>0.0 ? normalized.stop_distance_price/specification.tick_size : 0.0);
   normalized.monetary_tick_value_per_volume_unit=specification.tick_value_profit/specification.tick_value_basis_volume;
   normalized.monetary_value_currency=specification.tick_value_currency;
   normalized.specification_sequence=specification.specification_sequence;
   normalized.applied_entry_rounding=entry_rounding;
   normalized.applied_stop_rounding=stop_rounding;
   normalized.applied_limit_rounding=limit_rounding;
   normalized.applied_volume_rounding=volume_rounding;
   normalized.price_aligned_to_tick=SWV5_TestNear(normalized.price/specification.tick_size,
                                                  MathRound(normalized.price/specification.tick_size),context.price_tolerance);
   normalized.volume_aligned_to_step=(price_only || SWV5_TestNear(normalized.volume/specification.volume_step,
                                                   MathRound(normalized.volume/specification.volume_step),context.volume_tolerance));
   normalized.stops_level_satisfied=request.raw_stop_price<=0.0 || normalized.stop_distance_points+context.price_tolerance>=specification.stops_level_points;
   const bool stop_side_valid=(request.raw_stop_price<=0.0) ||
                              (request.direction>0 ? normalized.stop_price<request.operation_price : normalized.stop_price>request.operation_price);
   const bool limit_side_valid=(request.raw_limit_price<=0.0) ||
                               (request.direction>0 ? normalized.limit_price>request.operation_price : normalized.limit_price<request.operation_price);
   const double operation_market_side=(request.direction>0 ? request.market_bid : request.market_ask);
   const double market_distance_points=MathAbs(request.operation_price-operation_market_side)/specification.point_size;
   const bool modification=semantic==SWV5_UNIT_OPERATION_PROTECTIVE_STOP || semantic==SWV5_UNIT_OPERATION_LIMIT_TARGET;
   normalized.freeze_level_satisfied=!modification || market_distance_points+context.price_tolerance>=specification.freeze_level_points;
   normalized.caller_flags_consistent=true;
   const bool residual_close_valid=semantic==SWV5_UNIT_OPERATION_RESIDUAL_CLOSE &&
                                   normalized.volume>context.volume_tolerance &&
                                   normalized.volume<specification.volume_minimum-context.volume_tolerance;
   const bool volume_range_valid=price_only || residual_close_valid ||
                                 (normalized.volume>=specification.volume_minimum-context.volume_tolerance &&
                                  normalized.volume<=specification.volume_maximum+context.volume_tolerance);
   return volume_range_valid && (residual_close_valid || normalized.volume_aligned_to_step) &&
          normalized.price_aligned_to_tick && stop_side_valid && limit_side_valid &&
          normalized.stops_level_satisfied && normalized.freeze_level_satisfied;
}

bool SWV5_TestActiveOwnedStatus(const SWV5_InstanceLockStatus status)
{
   return status==SWV5_LOCK_ACQUIRED || status==SWV5_LOCK_RENEWED;
}

bool SWV5_TestInstanceLeaseEqual(const SWV5_InstanceLease &left,const SWV5_InstanceLease &right)
{
   return SWV5_TestVersionEqual(left.contract_version,right.contract_version) &&
          SWV5_TestFenceEqual(left.fence,right.fence) && left.status==right.status &&
          left.store_revision==right.store_revision &&
          left.heartbeat_sequence==right.heartbeat_sequence && left.clock_id==right.clock_id &&
          left.clock_authority==right.clock_authority &&
          left.acquired_clock_sequence==right.acquired_clock_sequence &&
          left.heartbeat_clock_sequence==right.heartbeat_clock_sequence &&
          left.expiry_clock_sequence==right.expiry_clock_sequence &&
          left.acquired_at==right.acquired_at && left.heartbeat_at==right.heartbeat_at &&
          left.expires_at==right.expires_at;
}

bool SWV5_TestTypedTakeoverReconciliationValid(const SWV5_TypedReconciliationEvidence &evidence,
                                                const SWV5_ComponentAuthority component,
                                                const SWV5_AuthoritySource source,
                                                const SWV5_OwnershipKey &observed_namespace,
                                                const SWV5_ContractValidationContext &context)
{
   return SWV5_TestVersionEqual(evidence.contract_version,context.expected_version) &&
          SWV5_TestNamespaceComplete(evidence.persistence_namespace) &&
          SWV5_TestOwnershipKeyEqual(evidence.persistence_namespace.ownership_namespace,observed_namespace) &&
          evidence.evidence_id!="" && evidence.state_digest!="" &&
          evidence.issuing_component==component && evidence.authority_source==source &&
          evidence.evidence_sequence>0 && evidence.observed_at>0 && evidence.observed_at<=context.clock_time;
}

bool SWV5_TestCanTakeover(const SWV5_ContractValidationContext &context,
                          const SWV5_OwnershipClaim &claim,
                          const SWV5_InstanceLease &observed)
{
   const SWV5_OwnershipTakeoverEvidence evidence=claim.takeover_evidence;
   const SWV5_LeaseExpiryEvidence expiry=evidence.lease_expiry;
   return SWV5_TestContextValid(context) &&
          SWV5_TestVersionEqual(observed.contract_version,context.expected_version) &&
          SWV5_TestVersionEqual(claim.contract_version,context.expected_version) &&
          SWV5_TestVersionEqual(evidence.contract_version,context.expected_version) &&
          SWV5_TestVersionEqual(expiry.contract_version,context.expected_version) &&
          observed.status==SWV5_LOCK_EXPIRED && SWV5_TestFenceComplete(observed.fence) &&
          observed.clock_id==context.clock_id && observed.clock_authority==context.clock_authority &&
          context.clock_sequence>=observed.expiry_clock_sequence && context.clock_time>=observed.expires_at &&
          expiry.expired &&
          SWV5_TestOwnershipKeyEqual(expiry.observed_ownership_key,observed.fence.ownership_namespace) &&
          SWV5_TestOwnerEqual(expiry.observed_owner,observed.fence.owner) &&
          SWV5_TestOwnershipKeyEqual(expiry.observed_ownership_namespace,observed.fence.ownership_namespace) &&
          expiry.clock_id==observed.clock_id && expiry.clock_authority==observed.clock_authority &&
          expiry.observed_clock_sequence==evidence.observed_clock_sequence &&
          expiry.observed_clock_sequence>=observed.expiry_clock_sequence &&
          expiry.observed_clock_sequence<=context.clock_sequence &&
          expiry.observed_at==evidence.observed_at && expiry.observed_at<=context.clock_time &&
          expiry.observed_lease_version==observed.fence.lease_version &&
          expiry.observed_heartbeat_sequence==observed.heartbeat_sequence &&
          expiry.observed_store_revision==observed.store_revision &&
          expiry.observed_expiry_time==observed.expires_at &&
          expiry.observed_takeover_generation==observed.fence.takeover_generation &&
          SWV5_TestOwnershipKeyEqual(evidence.observed_ownership_key,observed.fence.ownership_namespace) &&
          SWV5_TestOwnerEqual(evidence.observed_owner,observed.fence.owner) &&
          SWV5_TestOwnershipKeyEqual(evidence.observed_ownership_namespace,observed.fence.ownership_namespace) &&
          evidence.observed_lease_version==observed.fence.lease_version &&
          evidence.observed_store_revision==observed.store_revision &&
          evidence.observed_heartbeat_sequence==observed.heartbeat_sequence &&
          evidence.observed_clock_id==observed.clock_id &&
          evidence.observed_clock_authority==observed.clock_authority &&
          evidence.observed_expiry_time==observed.expires_at &&
          evidence.observed_takeover_generation==observed.fence.takeover_generation &&
          evidence.proposed_takeover_generation>observed.fence.takeover_generation &&
          evidence.authority!=SWV5_COMPONENT_AUTHORITY_NONE &&
          evidence.authority!=SWV5_COMPONENT_AUTHORITY_EXECUTION &&
          evidence.authority!=SWV5_COMPONENT_AUTHORITY_TEST_FIXTURE &&
          evidence.independent_authority_source==SWV5_AUTHORITY_OPERATOR &&
          evidence.evidence_sequence>0 && evidence.evidenced_at>0 && evidence.evidenced_at<=context.clock_time &&
          SWV5_TestTypedTakeoverReconciliationValid(evidence.broker_reconciliation,SWV5_COMPONENT_AUTHORITY_BROKER_ADAPTER,
                                                    SWV5_AUTHORITY_LIVE_BROKER_STATE,observed.fence.ownership_namespace,context) &&
          SWV5_TestTypedTakeoverReconciliationValid(evidence.persistence_reconciliation,SWV5_COMPONENT_AUTHORITY_PERSISTENCE,
                                                    SWV5_AUTHORITY_PERSISTED_CHECKPOINT,observed.fence.ownership_namespace,context) &&
          SWV5_TestOwnershipKeyEqual(claim.claimant.key,observed.fence.ownership_namespace) &&
          SWV5_TestFenceEqual(claim.expected_fence,observed.fence) &&
          claim.expected_store_revision==observed.store_revision;
}

bool SWV5_TestOwnershipKeyComplete(const SWV5_OwnershipKey &key)
{
   return key.account_login>0 && key.broker_identity!="" && key.server!="" &&
          key.symbol!="" && key.strategy_id!="" && key.magic>0;
}

bool SWV5_TestOwnerComplete(const SWV5_OwnerIdentity &owner)
{
   return SWV5_TestOwnershipKeyComplete(owner.key) && owner.instance_id!="" &&
          owner.process_fingerprint!="" && owner.started_at>0;
}

bool SWV5_TestUnclaimedClaimValid(const SWV5_ContractValidationContext &context,
                                  const SWV5_OwnershipClaim &claim,
                                  const SWV5_InstanceLease &observed)
{
   return SWV5_TestContextValid(context) &&
          SWV5_TestVersionEqual(claim.contract_version,context.expected_version) &&
          SWV5_TestVersionEqual(observed.contract_version,context.expected_version) &&
          observed.status==SWV5_LOCK_UNCLAIMED &&
          SWV5_TestFenceComplete(observed.fence) &&
          SWV5_TestFenceEqual(claim.expected_fence,observed.fence) &&
          SWV5_TestOwnershipKeyComplete(observed.fence.ownership_namespace) &&
          SWV5_TestOwnerComplete(claim.claimant) &&
          SWV5_TestOwnershipKeyEqual(claim.claimant.key,observed.fence.ownership_namespace) &&
            observed.store_revision!="" && claim.expected_store_revision==observed.store_revision &&
           observed.clock_id==context.clock_id && observed.clock_authority==context.clock_authority &&
          observed.fence.lease_version>0 && observed.fence.takeover_generation>0 &&
          claim.lease_duration_seconds>0 && claim.lease_duration_seconds<=86400;
}

bool SWV5_TestAcquiredLeaseCoherent(const SWV5_ContractValidationContext &context,
                                    const SWV5_OwnershipClaim &claim,
                                    const SWV5_InstanceLease &observed,
                                    const SWV5_InstanceLease &result)
{
   return SWV5_TestVersionEqual(result.contract_version,context.expected_version) &&
          result.status==SWV5_LOCK_ACQUIRED &&
          SWV5_TestFenceComplete(result.fence) &&
          SWV5_TestOwnerEqual(result.fence.owner,claim.claimant) &&
          SWV5_TestOwnershipKeyEqual(result.fence.ownership_namespace,claim.claimant.key) &&
          result.fence.lease_version==observed.fence.lease_version+1 &&
          result.fence.takeover_generation==observed.fence.takeover_generation &&
          result.store_revision!="" && result.store_revision!=observed.store_revision &&
          result.fence.fencing_token_digest!="" &&
           result.heartbeat_sequence==1 &&
           result.clock_id==context.clock_id && result.clock_authority==context.clock_authority &&
          result.acquired_clock_sequence==context.clock_sequence &&
          result.heartbeat_clock_sequence==context.clock_sequence &&
          result.expiry_clock_sequence==context.clock_sequence+claim.lease_duration_seconds &&
          result.acquired_at==context.clock_time && result.heartbeat_at==context.clock_time &&
          result.expires_at==context.clock_time+(datetime)claim.lease_duration_seconds;
}

bool SWV5_TestHeartbeatValid(const SWV5_ContractValidationContext &context,
                               const SWV5_InstanceLease &caller,
                               const SWV5_InstanceLease &observed)
{
   if(!SWV5_TestContextValid(context) || !SWV5_TestActiveOwnedStatus(caller.status) ||
      !SWV5_TestActiveOwnedStatus(observed.status) || !SWV5_TestInstanceLeaseEqual(caller,observed) ||
      !SWV5_TestVersionEqual(observed.contract_version,context.expected_version) ||
      !SWV5_TestFenceComplete(observed.fence) || !SWV5_TestOwnerComplete(observed.fence.owner) ||
      !SWV5_TestOwnershipKeyEqual(observed.fence.owner.key,observed.fence.ownership_namespace) ||
      observed.clock_id!=context.clock_id || observed.clock_authority!=context.clock_authority ||
      observed.clock_authority==SWV5_TIME_AUTHORITY_NONE)
      return false;
   if(observed.heartbeat_sequence==0 || observed.acquired_clock_sequence>observed.heartbeat_clock_sequence ||
      observed.heartbeat_clock_sequence>=observed.expiry_clock_sequence ||
      observed.acquired_at>observed.heartbeat_at || observed.heartbeat_at>=observed.expires_at)
      return false;
   const ulong sequence_duration=observed.expiry_clock_sequence-observed.heartbeat_clock_sequence;
   const datetime time_duration=observed.expires_at-observed.heartbeat_at;
   if(sequence_duration==0 || sequence_duration>86400 || time_duration<=0 || time_duration>86400)
      return false;
   return context.clock_sequence>observed.heartbeat_clock_sequence &&
          context.clock_sequence<observed.expiry_clock_sequence &&
          context.clock_time>observed.heartbeat_at && context.clock_time<observed.expires_at;
}

bool SWV5_TestExecutionVersionExact(const SWV5_ContractValidationContext &context,
                                    const SWV5_ContractVersion &candidate)
{
   return SWV5_TestContextValid(context) &&
          context.expected_version.contract_name==SWV5_PRODUCTION_CONTRACT_NAME &&
          context.expected_version.policy_id==SWV5_PRODUCTION_CONTRACT_POLICY &&
          SWV5_TestVersionEqual(candidate,context.expected_version) &&
          SWV5_TestCompatibility(candidate,context)==SWV5_COMPATIBILITY_EXACT;
}

bool SWV5_TestExecutionNamespaceValid(const SWV5_ContractValidationContext &context,
                                      const SWV5_PersistenceNamespace &space)
{
   return SWV5_TestExecutionVersionExact(context,space.contract_version) &&
          SWV5_TestNamespaceComplete(space);
}

bool SWV5_TestExecutionFenceBelongsToNamespace(const SWV5_ContractValidationContext &context,
                                                const SWV5_OwnershipFence &fence,
                                                const SWV5_PersistenceNamespace &space)
{
   return SWV5_TestExecutionNamespaceValid(context,space) &&
          SWV5_TestExecutionVersionExact(context,fence.contract_version) &&
          SWV5_TestFenceComplete(fence) &&
          SWV5_TestOwnershipKeyEqual(fence.ownership_namespace,space.ownership_namespace) &&
          SWV5_TestOwnershipKeyEqual(fence.owner.key,space.ownership_namespace);
}

bool SWV5_TestExecutionRequestIdentityValid(const SWV5_ContractValidationContext &context,
                                            const SWV5_ExecutionRequestIdentity &identity)
{
   return SWV5_TestExecutionVersionExact(context,identity.contract_version) &&
          SWV5_TestRequestIdentityComplete(identity) &&
          identity.request_id.created_at<=context.clock_time;
}

bool SWV5_TestExecutionCorrelationVersionsExact(const SWV5_ContractValidationContext &context,
                                                const SWV5_ExecutionCorrelation &correlation)
{
   return SWV5_TestExecutionVersionExact(context,correlation.contract_version) &&
          SWV5_TestExecutionRequestIdentityValid(context,correlation.request_identity) &&
          SWV5_TestExecutionVersionExact(context,correlation.broker_identity.contract_version);
}

bool SWV5_TestExecutionIntentSemanticsValid(const SWV5_ContractValidationContext &context,
                                            const SWV5_ExecutionIntent &intent)
{
   if(!SWV5_TestIntentTypeValid(intent.intent_type) ||
      !SWV5_IsFiniteNumber(intent.normalized_volume) ||
      !SWV5_IsFiniteNumber(intent.normalized_price) ||
      !SWV5_IsFiniteNumber(intent.normalized_stop_price) ||
      !SWV5_IsFiniteNumber(intent.normalized_limit_price))
      return false;
   const bool trading_intent=(intent.intent_type==SWV5_INTENT_OPEN ||
                              intent.intent_type==SWV5_INTENT_INCREASE ||
                              intent.intent_type==SWV5_INTENT_REDUCE ||
                              intent.intent_type==SWV5_INTENT_CLOSE);
   const bool cancel_intent=(intent.intent_type==SWV5_INTENT_CANCEL_PENDING);
   if(!trading_intent && !cancel_intent)
      return false;
   if(cancel_intent)
      return intent.direction==0 &&
             MathAbs(intent.normalized_volume)<=context.volume_tolerance &&
             MathAbs(intent.normalized_price)<=context.price_tolerance &&
             MathAbs(intent.normalized_stop_price)<=context.price_tolerance &&
             MathAbs(intent.normalized_limit_price)<=context.price_tolerance;
   if((intent.direction!=1 && intent.direction!=-1) ||
      intent.normalized_volume<=context.volume_tolerance || intent.normalized_price<=0.0 ||
      intent.normalized_stop_price<0.0 || intent.normalized_limit_price<0.0)
      return false;
   if(intent.direction==1)
   {
      if(intent.normalized_stop_price>0.0 &&
         intent.normalized_stop_price>=intent.normalized_price-context.price_tolerance)
         return false;
      if(intent.normalized_limit_price>0.0 &&
         intent.normalized_limit_price<=intent.normalized_price+context.price_tolerance)
         return false;
   }
   else
   {
      if(intent.normalized_stop_price>0.0 &&
         intent.normalized_stop_price<=intent.normalized_price+context.price_tolerance)
         return false;
      if(intent.normalized_limit_price>0.0 &&
         intent.normalized_limit_price>=intent.normalized_price-context.price_tolerance)
         return false;
   }
   return true;
}

bool SWV5_TestIntentValid(const SWV5_ContractValidationContext &context,const SWV5_ExecutionIntent &intent)
{
   return SWV5_TestExecutionVersionExact(context,intent.contract_version) &&
          SWV5_TestExecutionNamespaceValid(context,intent.persistence_namespace) &&
          SWV5_TestExecutionFenceBelongsToNamespace(context,intent.ownership_fence,intent.persistence_namespace) &&
          SWV5_TestExecutionRequestIdentityValid(context,intent.request_identity) &&
          intent.account_mode==SWV5_ACCOUNT_MODE_HEDGING &&
          SWV5_TestExecutionIntentSemanticsValid(context,intent) &&
          intent.symbol_specification_sequence>0 && intent.expected_basket_version>0 &&
          intent.risk_authorization_id!="" && intent.authorization_expires_at>=context.clock_time;
}

bool SWV5_TestPendingExecutionEnvelopeValid(const SWV5_ContractValidationContext &context,
                                             const SWV5_PendingRequest &pending)
{
   if(!SWV5_TestExecutionVersionExact(context,pending.contract_version) ||
      !SWV5_TestIntentValid(context,pending.intent) ||
      !SWV5_TestExecutionPhaseValid(pending.lifecycle_phase) ||
      !SWV5_TestPendingStateValid(pending.state) ||
      !SWV5_TestRetryDispositionValid(pending.retry_disposition) ||
      !SWV5_TestRetcodeClassValid(pending.latest_retcode_classification.classification) ||
      !SWV5_TestRetryDispositionValid(pending.latest_retcode_classification.retry_disposition) ||
      !SWV5_TestConfirmationStatusValid(pending.latest_authoritative_confirmation.status) ||
      !SWV5_IsFiniteNumber(pending.cumulative_confirmed_volume) ||
      !SWV5_IsFiniteNumber(pending.residual_requested_volume) ||
      !SWV5_IsFiniteNumber(pending.latest_authoritative_confirmation.cumulative_confirmed_volume) ||
      !SWV5_IsFiniteNumber(pending.latest_authoritative_confirmation.residual_volume) ||
      pending.account_mode!=SWV5_ACCOUNT_MODE_HEDGING || pending.account_mode!=pending.intent.account_mode ||
      !SWV5_TestExecutionVersionExact(context,pending.latest_submission.contract_version) ||
      !SWV5_TestExecutionRequestIdentityValid(context,pending.latest_submission.request_identity) ||
      !SWV5_TestRequestIdentityEqual(pending.latest_submission.request_identity,pending.intent.request_identity) ||
      pending.latest_submission.submission_attempt_count!=pending.submission_attempt_count ||
      pending.latest_submission.submitted_at<pending.intent.request_identity.request_id.created_at ||
      pending.latest_submission.submitted_at>context.clock_time ||
      !SWV5_TestExecutionVersionExact(context,pending.latest_retcode.contract_version) ||
      !SWV5_TestExecutionNamespaceValid(context,pending.latest_retcode.persistence_namespace) ||
      !SWV5_TestNamespaceEqual(pending.latest_retcode.persistence_namespace,pending.intent.persistence_namespace) ||
      !SWV5_TestExecutionFenceBelongsToNamespace(context,pending.latest_retcode.ownership_fence,pending.latest_retcode.persistence_namespace) ||
      !SWV5_TestFenceEqual(pending.latest_retcode.ownership_fence,pending.intent.ownership_fence) ||
      !SWV5_TestExecutionCorrelationVersionsExact(context,pending.latest_retcode.correlation) ||
      !SWV5_TestCorrelationComplete(pending.latest_retcode.correlation) ||
      !SWV5_TestRequestIdentityEqual(pending.latest_retcode.correlation.request_identity,pending.intent.request_identity) ||
      pending.latest_retcode.observed_at<pending.latest_submission.submitted_at ||
      pending.latest_retcode.observed_at>context.clock_time ||
      !SWV5_TestExecutionVersionExact(context,pending.latest_retcode_classification.contract_version) ||
      !SWV5_TestExecutionVersionExact(context,pending.latest_retcode_classification.decision.contract_version) ||
      pending.latest_retcode_classification.mapping_policy_id=="" ||
      pending.latest_retcode_classification.decision.evaluated_schema_version!=context.expected_version.schema_version ||
      !SWV5_TestExecutionVersionExact(context,pending.latest_authoritative_confirmation.contract_version) ||
      !SWV5_TestExecutionCorrelationVersionsExact(context,pending.latest_authoritative_confirmation.correlation) ||
      !SWV5_TestCorrelationComplete(pending.latest_authoritative_confirmation.correlation) ||
      !SWV5_TestRequestIdentityEqual(pending.latest_authoritative_confirmation.correlation.request_identity,pending.intent.request_identity) ||
      !SWV5_TestExecutionVersionExact(context,pending.accepted_event_identities.contract_version) ||
      pending.accepted_event_identities.fingerprint_policy!=SWV5_DURABLE_FINGERPRINT_REQUIRED ||
      !SWV5_TestEventSetIntegrityValid(pending.accepted_event_identities) ||
      pending.authorization_identity!=pending.intent.risk_authorization_id ||
      pending.normalization_identity=="" || pending.last_changed_at>context.clock_time ||
      pending.cumulative_confirmed_volume<0.0 || pending.residual_requested_volume<0.0 ||
      !SWV5_TestNear(pending.cumulative_confirmed_volume+pending.residual_requested_volume,
                     pending.intent.normalized_volume,context.volume_tolerance))
      return false;
   bool state_phase_coherent=false;
   switch(pending.state)
   {
      case SWV5_REQUEST_CREATED:
      case SWV5_REQUEST_RISK_AUTHORIZED:
         state_phase_coherent=(pending.lifecycle_phase==SWV5_EXECUTION_PHASE_INTENT); break;
      case SWV5_REQUEST_SUBMISSION_PENDING:
         state_phase_coherent=(pending.lifecycle_phase==SWV5_EXECUTION_PHASE_SUBMISSION); break;
      case SWV5_REQUEST_ACKNOWLEDGED:
      case SWV5_REQUEST_CONFIRMATION_PENDING:
         state_phase_coherent=(pending.lifecycle_phase==SWV5_EXECUTION_PHASE_ACKNOWLEDGEMENT); break;
      case SWV5_REQUEST_CONFIRMED:
         state_phase_coherent=(pending.lifecycle_phase==SWV5_EXECUTION_PHASE_COMPLETED); break;
      case SWV5_REQUEST_PARTIALLY_CONFIRMED:
         state_phase_coherent=(pending.lifecycle_phase==SWV5_EXECUTION_PHASE_PARTIAL_FILL); break;
      case SWV5_REQUEST_REJECTED:
         state_phase_coherent=(pending.lifecycle_phase==SWV5_EXECUTION_PHASE_REJECTED); break;
      case SWV5_REQUEST_EXPIRED:
      case SWV5_REQUEST_RECONCILIATION_REQUIRED:
         state_phase_coherent=(pending.lifecycle_phase==SWV5_EXECUTION_PHASE_UNCERTAIN); break;
      case SWV5_REQUEST_CANCELLED:
         state_phase_coherent=(pending.lifecycle_phase==SWV5_EXECUTION_PHASE_REJECTED ||
                               pending.lifecycle_phase==SWV5_EXECUTION_PHASE_COMPLETED); break;
   }
   if(!state_phase_coherent)
      return false;
   if(pending.latest_authoritative_confirmation.status==SWV5_CONFIRMATION_NOT_STARTED)
      return pending.latest_authoritative_confirmation.authority==SWV5_AUTHORITY_NONE &&
             pending.latest_authoritative_confirmation.confirmation_sequence==0 &&
             pending.latest_authoritative_confirmation.confirmed_at==0 &&
             SWV5_TestNear(pending.latest_authoritative_confirmation.cumulative_confirmed_volume,pending.cumulative_confirmed_volume,context.volume_tolerance) &&
             SWV5_TestNear(pending.latest_authoritative_confirmation.residual_volume,pending.residual_requested_volume,context.volume_tolerance);
   if(pending.latest_authoritative_confirmation.status==SWV5_CONFIRMATION_PARTIAL ||
      pending.latest_authoritative_confirmation.status==SWV5_CONFIRMATION_CONFIRMED)
      return pending.latest_authoritative_confirmation.authority!=SWV5_AUTHORITY_NONE &&
             pending.latest_authoritative_confirmation.confirmation_sequence>0 &&
             pending.latest_authoritative_confirmation.confirmed_at>0 &&
             pending.latest_authoritative_confirmation.confirmed_at<=context.clock_time &&
             SWV5_TestNear(pending.latest_authoritative_confirmation.cumulative_confirmed_volume,pending.cumulative_confirmed_volume,context.volume_tolerance) &&
             SWV5_TestNear(pending.latest_authoritative_confirmation.residual_volume,pending.residual_requested_volume,context.volume_tolerance);
   return true;
}

bool SWV5_TestRetryFreshnessValid(const SWV5_ContractValidationContext &context,
                                  const SWV5_PendingRequest &pending,
                                  const SWV5_RetryPolicy &policy,
                                  const SWV5_RetryRiskFreshnessEvidence &risk_evidence,
                                  const SWV5_RetryNormalizationFreshnessEvidence &normalization_evidence)
{
   if(!SWV5_TestContextValid(context) || !SWV5_TestPendingExecutionEnvelopeValid(context,pending) ||
      !SWV5_TestRetryEligiblePhase(pending.lifecycle_phase) ||
      !SWV5_TestRetryEligiblePendingState(pending.state) ||
      !SWV5_TestRetryDispositionValid(policy.disposition) ||
      !SWV5_TestRetryDispositionValid(pending.retry_disposition) ||
      !SWV5_TestRetryDispositionEligible(policy.disposition) ||
      !SWV5_TestRetcodeClassValid(pending.latest_retcode_classification.classification) ||
      pending.latest_retcode_classification.classification==SWV5_RETCODE_UNCLASSIFIED ||
      !SWV5_IsFiniteNumber(risk_evidence.authorized_volume) ||
      !SWV5_IsFiniteNumber(normalization_evidence.normalized_volume) ||
      !SWV5_IsFiniteNumber(normalization_evidence.normalized_price) ||
      !SWV5_IsFiniteNumber(normalization_evidence.normalized_stop_price) ||
      !SWV5_IsFiniteNumber(normalization_evidence.normalized_limit_price) ||
      !SWV5_TestExecutionVersionExact(context,policy.contract_version) || policy.maximum_attempts==0 ||
      pending.submission_attempt_count>=policy.maximum_attempts ||
      policy.disposition==SWV5_RETRY_FORBIDDEN || policy.disposition==SWV5_RETRY_REQUIRES_RECONCILIATION ||
      pending.retry_disposition!=policy.disposition || policy.earliest_retry_at>context.clock_time ||
      context.clock_time>=policy.authorization_deadline || pending.intent.authorization_expires_at<=context.clock_time ||
      pending.authorization_identity=="" || pending.normalization_identity=="" ||
      pending.last_changed_at<pending.latest_submission.submitted_at || pending.last_changed_at>context.clock_time)
      return false;

   if(pending.lifecycle_phase==SWV5_EXECUTION_PHASE_COMPLETED ||
      pending.lifecycle_phase==SWV5_EXECUTION_PHASE_PARTIAL_FILL ||
      pending.lifecycle_phase==SWV5_EXECUTION_PHASE_AUTHORITATIVE_CONFIRMATION ||
      pending.lifecycle_phase==SWV5_EXECUTION_PHASE_UNCERTAIN ||
      pending.state==SWV5_REQUEST_CONFIRMED || pending.state==SWV5_REQUEST_PARTIALLY_CONFIRMED ||
      pending.state==SWV5_REQUEST_REJECTED || pending.state==SWV5_REQUEST_EXPIRED ||
      pending.state==SWV5_REQUEST_RECONCILIATION_REQUIRED || pending.state==SWV5_REQUEST_CANCELLED ||
      pending.latest_authoritative_confirmation.status==SWV5_CONFIRMATION_CONFLICT ||
      pending.latest_authoritative_confirmation.status==SWV5_CONFIRMATION_CONFIRMED ||
      pending.latest_authoritative_confirmation.status==SWV5_CONFIRMATION_REJECTED ||
      pending.latest_authoritative_confirmation.status==SWV5_CONFIRMATION_EXPIRED)
      return false;

   const bool risk_current=SWV5_TestExecutionVersionExact(context,risk_evidence.contract_version) &&
      SWV5_TestExecutionNamespaceValid(context,risk_evidence.persistence_namespace) &&
      SWV5_TestNamespaceEqual(risk_evidence.persistence_namespace,pending.intent.persistence_namespace) &&
      SWV5_TestExecutionFenceBelongsToNamespace(context,risk_evidence.ownership_fence,risk_evidence.persistence_namespace) &&
      SWV5_TestFenceEqual(risk_evidence.ownership_fence,pending.intent.ownership_fence) &&
      SWV5_TestExecutionRequestIdentityValid(context,risk_evidence.request_identity) &&
      SWV5_TestRequestIdentityEqual(risk_evidence.request_identity,pending.intent.request_identity) &&
      risk_evidence.account_mode==pending.account_mode &&
      risk_evidence.expected_basket_version==pending.intent.expected_basket_version &&
      risk_evidence.symbol_specification_sequence==pending.intent.symbol_specification_sequence &&
      risk_evidence.authorization_id==pending.authorization_identity &&
      SWV5_TestNear(risk_evidence.authorized_volume,pending.intent.normalized_volume,context.volume_tolerance) &&
      risk_evidence.evidenced_at>0 && risk_evidence.evidenced_at<=context.clock_time &&
      risk_evidence.expires_at==pending.intent.authorization_expires_at && risk_evidence.expires_at>context.clock_time &&
      risk_evidence.evidence_sequence>0 && risk_evidence.issuing_component==SWV5_COMPONENT_AUTHORITY_RISK_GOVERNANCE;
   if(!risk_current || (policy.require_fresh_risk_authorization &&
      (risk_evidence.evidenced_at<=pending.last_changed_at || risk_evidence.evidence_sequence!=context.evaluation_sequence)))
      return false;

   const bool normalization_current=SWV5_TestExecutionVersionExact(context,normalization_evidence.contract_version) &&
      SWV5_TestExecutionNamespaceValid(context,normalization_evidence.persistence_namespace) &&
      SWV5_TestNamespaceEqual(normalization_evidence.persistence_namespace,pending.intent.persistence_namespace) &&
      SWV5_TestExecutionFenceBelongsToNamespace(context,normalization_evidence.ownership_fence,normalization_evidence.persistence_namespace) &&
      SWV5_TestFenceEqual(normalization_evidence.ownership_fence,pending.intent.ownership_fence) &&
      SWV5_TestExecutionRequestIdentityValid(context,normalization_evidence.request_identity) &&
      SWV5_TestRequestIdentityEqual(normalization_evidence.request_identity,pending.intent.request_identity) &&
      normalization_evidence.account_mode==pending.account_mode &&
      normalization_evidence.expected_basket_version==pending.intent.expected_basket_version &&
      normalization_evidence.symbol_specification_sequence==pending.intent.symbol_specification_sequence &&
      normalization_evidence.intent_type==pending.intent.intent_type && normalization_evidence.direction==pending.intent.direction &&
      SWV5_TestNear(normalization_evidence.normalized_volume,pending.intent.normalized_volume,context.volume_tolerance) &&
      SWV5_TestNear(normalization_evidence.normalized_price,pending.intent.normalized_price,context.price_tolerance) &&
      SWV5_TestNear(normalization_evidence.normalized_stop_price,pending.intent.normalized_stop_price,context.price_tolerance) &&
      SWV5_TestNear(normalization_evidence.normalized_limit_price,pending.intent.normalized_limit_price,context.price_tolerance) &&
      normalization_evidence.normalization_identity==pending.normalization_identity &&
      normalization_evidence.evidenced_at>0 && normalization_evidence.evidenced_at<=context.clock_time &&
      normalization_evidence.evidence_sequence>0 && normalization_evidence.issuing_component==SWV5_COMPONENT_AUTHORITY_UNIT_SYSTEM;
   if(!normalization_current || (policy.require_fresh_unit_normalization &&
      (normalization_evidence.evidenced_at<=pending.last_changed_at || normalization_evidence.evidence_sequence!=context.evaluation_sequence)))
      return false;
   return true;
}

bool SWV5_TestRetcodeEnvelopeValid(const SWV5_ContractValidationContext &context,
                                   const SWV5_ResultRetcodeEvidence &evidence)
{
   if(!SWV5_TestExecutionVersionExact(context,evidence.contract_version) ||
      !SWV5_TestExecutionNamespaceValid(context,evidence.persistence_namespace) ||
      !SWV5_TestExecutionFenceBelongsToNamespace(context,evidence.ownership_fence,evidence.persistence_namespace) ||
      !SWV5_TestExecutionCorrelationVersionsExact(context,evidence.correlation) ||
      evidence.observed_at<evidence.correlation.request_identity.request_id.created_at ||
      evidence.observed_at>context.clock_time)
      return false;
   if(evidence.correlation.phase==SWV5_EXECUTION_PHASE_SUBMISSION)
      return evidence.correlation.broker_identity.order_ticket==0 &&
             evidence.correlation.broker_identity.deal_ticket==0 &&
             evidence.correlation.broker_identity.position_identifier==0;
   if(evidence.correlation.phase!=SWV5_EXECUTION_PHASE_ACKNOWLEDGEMENT)
      return false;
   const bool event_pair_empty=(evidence.correlation.broker_identity.broker_event_id=="" &&
                                evidence.correlation.broker_identity.transaction_sequence==0);
   const bool event_pair_complete=(evidence.correlation.broker_identity.broker_event_id!="" &&
                                   evidence.correlation.broker_identity.transaction_sequence>0);
   return evidence.correlation.broker_identity.order_ticket>0 &&
          evidence.correlation.broker_identity.deal_ticket==0 &&
          evidence.correlation.broker_identity.position_identifier==0 &&
          (event_pair_empty || event_pair_complete);
}

SWV5_ResultRetcodeClass SWV5_TestClassifyRetcode(const uint raw_retcode)
{
   switch(raw_retcode)
   {
      case 1: return SWV5_RETCODE_ACCEPTED_PENDING_CONFIRMATION;
      case 2: return SWV5_RETCODE_SYNCHRONOUS_DEAL_REPORTED_PENDING_EVIDENCE;
      case 3: return SWV5_RETCODE_REJECTED_PERMANENT;
      case 4: return SWV5_RETCODE_CONNECTION_UNCERTAIN;
      case 5: return SWV5_RETCODE_PRICE_CHANGED;
      case 6: return SWV5_RETCODE_VOLUME_CHANGED;
   }
   return SWV5_RETCODE_UNCLASSIFIED;
}

SWV5_TransactionEvidenceDisposition SWV5_TestTransactionEvidenceDisposition(const SWV5_TransactionEvidence &evidence)
{
   if(evidence.event_kind==SWV5_TRANSACTION_EVENT_ORDER_ACCEPTED ||
      evidence.event_kind==SWV5_TRANSACTION_EVENT_ORDER_REMOVED)
      return SWV5_TRANSACTION_EVIDENCE_ACKNOWLEDGEMENT_ONLY;
   if(evidence.event_kind==SWV5_TRANSACTION_EVENT_POSITION_CHANGED)
      return SWV5_TRANSACTION_EVIDENCE_RECONCILIATION_REQUIRED;
   if(evidence.event_kind==SWV5_TRANSACTION_EVENT_DEAL_ADDED &&
      evidence.authority==SWV5_AUTHORITY_TRANSACTION_EVENT && evidence.history_cross_checked)
      return SWV5_TRANSACTION_EVIDENCE_AUTHORITATIVE_CONFIRMATION;
   if(evidence.event_kind==SWV5_TRANSACTION_EVENT_HISTORY_CONFIRMED &&
      evidence.authority==SWV5_AUTHORITY_DEAL_HISTORY && evidence.history_cross_checked)
      return SWV5_TRANSACTION_EVIDENCE_AUTHORITATIVE_CONFIRMATION;
   return SWV5_TRANSACTION_EVIDENCE_INVALID;
}

bool SWV5_TestTransactionEnvelopeValid(const SWV5_ContractValidationContext &context,
                                        const SWV5_PendingRequest &pending,
                                        const SWV5_TransactionEvidence &evidence)
{
   if(!SWV5_IsFiniteNumber(evidence.confirmed_volume) ||
      !SWV5_IsFiniteNumber(evidence.confirmed_price) ||
      !SWV5_TestPendingExecutionEnvelopeValid(context,pending) ||
      !SWV5_TestExecutionVersionExact(context,evidence.contract_version) ||
      !SWV5_TestExecutionNamespaceValid(context,evidence.persistence_namespace) ||
      !SWV5_TestNamespaceEqual(pending.intent.persistence_namespace,evidence.persistence_namespace) ||
      !SWV5_TestExecutionFenceBelongsToNamespace(context,evidence.ownership_fence,evidence.persistence_namespace) ||
      !SWV5_TestFenceEqual(pending.intent.ownership_fence,evidence.ownership_fence) ||
      !SWV5_TestExecutionCorrelationVersionsExact(context,evidence.correlation) ||
      !SWV5_TestRequestIdentityEqual(pending.intent.request_identity,evidence.correlation.request_identity) ||
      evidence.expected_basket_version!=pending.intent.expected_basket_version ||
      evidence.symbol_specification_sequence!=pending.intent.symbol_specification_sequence ||
      evidence.transaction_time<pending.latest_submission.submitted_at ||
      evidence.transaction_time>context.clock_time ||
      evidence.received_at<evidence.transaction_time || evidence.received_at>context.clock_time)
      return false;

   const SWV5_BrokerExecutionIdentity broker=evidence.correlation.broker_identity;
   const bool durable_broker_event=(broker.broker_event_id!="" && broker.transaction_sequence>0);
   if(evidence.event_kind==SWV5_TRANSACTION_EVENT_ORDER_ACCEPTED ||
      evidence.event_kind==SWV5_TRANSACTION_EVENT_ORDER_REMOVED)
      return evidence.correlation.phase==SWV5_EXECUTION_PHASE_ACKNOWLEDGEMENT &&
             broker.order_ticket>0 && broker.deal_ticket==0 && broker.position_identifier==0 &&
             durable_broker_event && evidence.authority==SWV5_AUTHORITY_TRANSACTION_EVENT &&
             !evidence.history_cross_checked &&
             MathAbs(evidence.confirmed_volume)<=context.volume_tolerance &&
             MathAbs(evidence.confirmed_price)<=context.price_tolerance;
   if(evidence.event_kind==SWV5_TRANSACTION_EVENT_POSITION_CHANGED)
      return evidence.correlation.phase==SWV5_EXECUTION_PHASE_AUTHORITATIVE_CONFIRMATION &&
             broker.position_identifier>0 && durable_broker_event &&
             evidence.authority==SWV5_AUTHORITY_TRANSACTION_EVENT;
   if(evidence.event_kind==SWV5_TRANSACTION_EVENT_DEAL_ADDED)
      return evidence.correlation.phase==SWV5_EXECUTION_PHASE_AUTHORITATIVE_CONFIRMATION &&
             broker.deal_ticket>0 && durable_broker_event &&
             evidence.authority==SWV5_AUTHORITY_TRANSACTION_EVENT && evidence.history_cross_checked;
   if(evidence.event_kind==SWV5_TRANSACTION_EVENT_HISTORY_CONFIRMED)
      return evidence.correlation.phase==SWV5_EXECUTION_PHASE_AUTHORITATIVE_CONFIRMATION &&
             broker.deal_ticket>0 && durable_broker_event &&
             evidence.authority==SWV5_AUTHORITY_DEAL_HISTORY && evidence.history_cross_checked;
   return false;
}

SWV5_ConfirmationStatus SWV5_TestConfirmExecution(const SWV5_ContractValidationContext &context,
                                                   const SWV5_PendingRequest &pending,
                                                   const SWV5_TransactionEvidence &evidence,
                                                   SWV5_TransactionEvidenceDisposition &evidence_disposition,
                                                   double &confirmed_volume,
                                                   double &residual_volume)
{
   confirmed_volume=pending.cumulative_confirmed_volume;
   residual_volume=pending.residual_requested_volume;
   evidence_disposition=SWV5_TRANSACTION_EVIDENCE_INVALID;
   if(!SWV5_IsFiniteNumber(pending.cumulative_confirmed_volume) ||
      !SWV5_IsFiniteNumber(pending.residual_requested_volume) ||
      !SWV5_IsFiniteNumber(evidence.confirmed_volume) ||
      !SWV5_IsFiniteNumber(evidence.confirmed_price))
      return SWV5_CONFIRMATION_CONFLICT;
   evidence_disposition=SWV5_TestTransactionEvidenceDisposition(evidence);
   if(evidence_disposition==SWV5_TRANSACTION_EVIDENCE_ACKNOWLEDGEMENT_ONLY ||
      evidence_disposition==SWV5_TRANSACTION_EVIDENCE_RECONCILIATION_REQUIRED)
      return SWV5_CONFIRMATION_PENDING;
   if(evidence_disposition!=SWV5_TRANSACTION_EVIDENCE_AUTHORITATIVE_CONFIRMATION ||
      evidence.correlation.phase!=SWV5_EXECUTION_PHASE_AUTHORITATIVE_CONFIRMATION ||
       (pending.lifecycle_phase!=SWV5_EXECUTION_PHASE_ACKNOWLEDGEMENT &&
        pending.lifecycle_phase!=SWV5_EXECUTION_PHASE_AUTHORITATIVE_CONFIRMATION &&
        pending.lifecycle_phase!=SWV5_EXECUTION_PHASE_PARTIAL_FILL &&
        pending.lifecycle_phase!=SWV5_EXECUTION_PHASE_COMPLETED) ||
      evidence.confirmed_volume<=context.volume_tolerance ||
      evidence.confirmed_volume>pending.intent.normalized_volume+context.volume_tolerance ||
      evidence.confirmed_price<=0.0)
   {
      evidence_disposition=SWV5_TRANSACTION_EVIDENCE_INVALID;
      return SWV5_CONFIRMATION_CONFLICT;
   }
   confirmed_volume+=evidence.confirmed_volume;
   residual_volume=MathMax(0.0,pending.intent.normalized_volume-confirmed_volume);
   if(residual_volume>0.0000001)
      return SWV5_CONFIRMATION_PARTIAL;
   return SWV5_CONFIRMATION_CONFIRMED;
}

bool SWV5_TestDecisionEqual(const SWV5_ContractDecision &left,const SWV5_ContractDecision &right)
{
   return SWV5_TestVersionEqual(left.contract_version,right.contract_version) &&
          left.disposition==right.disposition &&
          left.reason_flags==right.reason_flags &&
          left.reason_code==right.reason_code &&
          left.reason_text==right.reason_text &&
          left.evaluated_schema_version==right.evaluated_schema_version &&
          left.evaluation_sequence==right.evaluation_sequence &&
          left.evaluated_at==right.evaluated_at;
}

bool SWV5_TestIntentEqual(const SWV5_ExecutionIntent &left,const SWV5_ExecutionIntent &right)
{
   return SWV5_TestVersionEqual(left.contract_version,right.contract_version) &&
          SWV5_TestNamespaceEqual(left.persistence_namespace,right.persistence_namespace) &&
          SWV5_TestFenceEqual(left.ownership_fence,right.ownership_fence) &&
          SWV5_TestRequestIdentityEqual(left.request_identity,right.request_identity) &&
          left.account_mode==right.account_mode &&
          left.intent_type==right.intent_type &&
          left.direction==right.direction &&
          left.normalized_volume==right.normalized_volume &&
          left.normalized_price==right.normalized_price &&
          left.normalized_stop_price==right.normalized_stop_price &&
          left.normalized_limit_price==right.normalized_limit_price &&
          left.symbol_specification_sequence==right.symbol_specification_sequence &&
          left.expected_basket_version==right.expected_basket_version &&
          left.risk_authorization_id==right.risk_authorization_id &&
          left.authorization_expires_at==right.authorization_expires_at;
}

bool SWV5_TestSubmissionEqual(const SWV5_SubmissionEvidence &left,const SWV5_SubmissionEvidence &right)
{
   return SWV5_TestVersionEqual(left.contract_version,right.contract_version) &&
          SWV5_TestRequestIdentityEqual(left.request_identity,right.request_identity) &&
          left.submission_attempt_count==right.submission_attempt_count &&
          left.submitted_at==right.submitted_at &&
          left.authority==right.authority;
}

bool SWV5_TestRetcodeEvidenceEqual(const SWV5_ResultRetcodeEvidence &left,const SWV5_ResultRetcodeEvidence &right)
{
   return SWV5_TestVersionEqual(left.contract_version,right.contract_version) &&
          SWV5_TestNamespaceEqual(left.persistence_namespace,right.persistence_namespace) &&
          SWV5_TestFenceEqual(left.ownership_fence,right.ownership_fence) &&
          SWV5_TestCorrelationEqual(left.correlation,right.correlation) &&
          left.raw_retcode==right.raw_retcode &&
          left.broker_comment==right.broker_comment &&
          left.observed_at==right.observed_at;
}

bool SWV5_TestRetcodeClassificationEqual(const SWV5_ResultRetcodeClassification &left,
                                         const SWV5_ResultRetcodeClassification &right)
{
   return SWV5_TestVersionEqual(left.contract_version,right.contract_version) &&
          left.classification==right.classification &&
          left.retry_disposition==right.retry_disposition &&
          left.mapping_policy_id==right.mapping_policy_id &&
          SWV5_TestDecisionEqual(left.decision,right.decision);
}

bool SWV5_TestAuthoritativeConfirmationEqual(const SWV5_AuthoritativeConfirmationEvidence &left,
                                             const SWV5_AuthoritativeConfirmationEvidence &right)
{
   return SWV5_TestVersionEqual(left.contract_version,right.contract_version) &&
          SWV5_TestCorrelationEqual(left.correlation,right.correlation) &&
          left.status==right.status &&
          left.cumulative_confirmed_volume==right.cumulative_confirmed_volume &&
          left.residual_volume==right.residual_volume &&
          left.authority==right.authority &&
          left.confirmation_sequence==right.confirmation_sequence &&
          left.confirmed_at==right.confirmed_at;
}

bool SWV5_TestEventIdentitySetEqual(const SWV5_DurableEventIdentitySet &left,
                                    const SWV5_DurableEventIdentitySet &right)
{
   return SWV5_TestVersionEqual(left.contract_version,right.contract_version) &&
          left.fingerprint_policy==right.fingerprint_policy &&
          left.canonical_event_index==right.canonical_event_index &&
          left.canonical_fingerprint_index==right.canonical_fingerprint_index &&
          left.identity_set_digest==right.identity_set_digest &&
          left.accepted_identity_count==right.accepted_identity_count &&
          left.highest_transaction_sequence==right.highest_transaction_sequence &&
          left.index_revision==right.index_revision &&
          left.compaction_generation==right.compaction_generation;
}

bool SWV5_TestPendingRequestEqual(const SWV5_PendingRequest &left,const SWV5_PendingRequest &right)
{
   return SWV5_TestVersionEqual(left.contract_version,right.contract_version) &&
          SWV5_TestIntentEqual(left.intent,right.intent) &&
          left.account_mode==right.account_mode &&
          left.lifecycle_phase==right.lifecycle_phase &&
          left.state==right.state &&
          left.submission_attempt_count==right.submission_attempt_count &&
          SWV5_TestSubmissionEqual(left.latest_submission,right.latest_submission) &&
          SWV5_TestRetcodeEvidenceEqual(left.latest_retcode,right.latest_retcode) &&
          SWV5_TestRetcodeClassificationEqual(left.latest_retcode_classification,right.latest_retcode_classification) &&
          SWV5_TestAuthoritativeConfirmationEqual(left.latest_authoritative_confirmation,right.latest_authoritative_confirmation) &&
          left.cumulative_confirmed_volume==right.cumulative_confirmed_volume &&
          left.residual_requested_volume==right.residual_requested_volume &&
          SWV5_TestEventIdentitySetEqual(left.accepted_event_identities,right.accepted_event_identities) &&
          left.retry_disposition==right.retry_disposition &&
          left.authorization_identity==right.authorization_identity &&
          left.normalization_identity==right.normalization_identity &&
          left.last_changed_at==right.last_changed_at;
}

bool SWV5_TestPersistedRequestEqual(const SWV5_PersistedRequestEvidence &left,
                                    const SWV5_PersistedRequestEvidence &right)
{
   return SWV5_TestVersionEqual(left.contract_version,right.contract_version) &&
          SWV5_TestNamespaceEqual(left.persistence_namespace,right.persistence_namespace) &&
          SWV5_TestFenceEqual(left.ownership_fence,right.ownership_fence) &&
          SWV5_TestPendingRequestEqual(left.pending_request,right.pending_request) &&
          left.account_mode==right.account_mode &&
          left.record_sequence==right.record_sequence &&
          left.recorded_at==right.recorded_at;
}

bool SWV5_TestPersistedRequestValid(const SWV5_ContractValidationContext &context,
                                    const SWV5_PersistedRequestEvidence &record,
                                    const SWV5_PersistenceNamespace &expected_namespace)
{
   const SWV5_PendingRequest pending=record.pending_request;
   return SWV5_TestContextValid(context) &&
          SWV5_TestExecutionVersionExact(context,record.contract_version) &&
          SWV5_TestNamespaceEqual(record.persistence_namespace,expected_namespace) &&
          SWV5_TestExecutionNamespaceValid(context,record.persistence_namespace) &&
          SWV5_TestExecutionFenceBelongsToNamespace(context,record.ownership_fence,record.persistence_namespace) &&
          SWV5_TestPendingExecutionEnvelopeValid(context,pending) &&
          SWV5_TestNamespaceEqual(pending.intent.persistence_namespace,expected_namespace) &&
          SWV5_TestFenceEqual(record.ownership_fence,pending.intent.ownership_fence) &&
          record.account_mode==SWV5_ACCOUNT_MODE_HEDGING &&
          pending.account_mode==record.account_mode &&
          pending.intent.account_mode==record.account_mode &&
          pending.accepted_event_identities.fingerprint_policy==SWV5_DURABLE_FINGERPRINT_REQUIRED &&
          SWV5_TestEventSetIntegrityValid(pending.accepted_event_identities) &&
          pending.authorization_identity!="" && pending.normalization_identity!="" &&
          pending.last_changed_at>0 && pending.last_changed_at<=context.clock_time &&
          record.record_sequence>0 && record.recorded_at>=pending.last_changed_at && record.recorded_at<=context.clock_time;
}

bool SWV5_TestBasketStateValueValid(const SWV5_BasketState state)
{
   switch(state)
   {
      case SWV5_BASKET_IDLE:
      case SWV5_BASKET_OPENING:
      case SWV5_BASKET_ACTIVE:
      case SWV5_BASKET_RECOVERY:
      case SWV5_BASKET_CLOSING:
      case SWV5_BASKET_HALTED:
      case SWV5_BASKET_ERROR: return true;
   }
   return false;
}

bool SWV5_TestReconciliationStateValid(const SWV5_ReconciliationState state)
{
   switch(state)
   {
      case SWV5_RECONCILIATION_STATE_NOT_STARTED:
      case SWV5_RECONCILIATION_STATE_MATCHED:
      case SWV5_RECONCILIATION_STATE_REQUIRED:
      case SWV5_RECONCILIATION_STATE_CONFLICT:
      case SWV5_RECONCILIATION_STATE_MANUAL: return true;
   }
   return false;
}

bool SWV5_TestCheckpointBasketSemanticValid(const SWV5_ContractValidationContext &context,
                                             const SWV5_BasketAggregate &basket,
                                             const SWV5_PersistenceNamespace &expected_namespace,
                                             const SWV5_OwnershipFence &expected_fence)
{
   if(!SWV5_TestExecutionVersionExact(context,basket.contract_version) ||
      !SWV5_TestExecutionVersionExact(context,basket.lifecycle.contract_version) ||
      !SWV5_TestNamespaceEqual(basket.persistence_namespace,expected_namespace) ||
      basket.account_mode!=SWV5_ACCOUNT_MODE_HEDGING ||
      basket.lifecycle.basket_id.value!=expected_namespace.basket_id.value ||
      !SWV5_TestFenceEqual(basket.lifecycle.ownership_fence,expected_fence) ||
      !SWV5_TestBasketStateValueValid(basket.lifecycle.state) || basket.lifecycle.state_version==0 ||
      !SWV5_TestReconciliationStateValid(basket.lifecycle.reconciliation_state) ||
      !SWV5_TestEventSetIntegrityValid(basket.lifecycle.accepted_recovery_evidence) ||
      !SWV5_TestQueriesComplete(basket.lifecycle.broker_queries) ||
      !SWV5_IsFiniteNumber(basket.initial_volume) || !SWV5_IsFiniteNumber(basket.aggregate_closed_volume) ||
      !SWV5_IsFiniteNumber(basket.lifecycle.aggregate_open_volume) || !SWV5_IsFiniteNumber(basket.lifecycle.residual_volume) ||
      basket.initial_volume<0.0 || basket.aggregate_closed_volume<0.0 ||
      basket.aggregate_closed_volume>basket.initial_volume+context.volume_tolerance ||
      basket.lifecycle.aggregate_open_volume<0.0 || basket.lifecycle.residual_volume<0.0 ||
      basket.opened_at<=0 || basket.updated_at<basket.opened_at || basket.updated_at>context.clock_time ||
      basket.lifecycle.state_entered_at<=0 || basket.lifecycle.state_entered_at>context.clock_time)
      return false;
   if(basket.lifecycle.state==SWV5_BASKET_IDLE)
      return SWV5_TestNear(basket.lifecycle.aggregate_open_volume,0.0,context.volume_tolerance) &&
             SWV5_TestNear(basket.lifecycle.residual_volume,0.0,context.volume_tolerance) &&
             basket.lifecycle.live_position_count==0 && basket.lifecycle.live_order_count==0 &&
             basket.lifecycle.pending_request_count==0 && basket.close_verification==SWV5_CLOSE_ZERO_RESIDUAL_CONFIRMED;
   if(basket.lifecycle.state==SWV5_BASKET_ACTIVE || basket.lifecycle.state==SWV5_BASKET_RECOVERY ||
      basket.lifecycle.state==SWV5_BASKET_CLOSING)
      return basket.lifecycle.aggregate_open_volume>context.volume_tolerance && basket.lifecycle.live_position_count>0;
   return true;
}

bool SWV5_TestReconciliationVectorValid(const SWV5_ContractValidationContext &context,
                                         const SWV5_PersistedCheckpoint &checkpoint)
{
   const SWV5_PersistedReconciliationVector persisted_vector=checkpoint.reconciliation_vector;
   return SWV5_TestVersionEqual(persisted_vector.contract_version,context.expected_version) &&
          SWV5_TestNamespaceEqual(persisted_vector.persistence_namespace,checkpoint.header.persistence_namespace) &&
          persisted_vector.basket_id.value==checkpoint.header.persistence_namespace.basket_id.value &&
          persisted_vector.account_mode==checkpoint.basket.account_mode && persisted_vector.account_mode==SWV5_ACCOUNT_MODE_HEDGING &&
          SWV5_IsFiniteNumber(persisted_vector.symbol_long_volume) && SWV5_IsFiniteNumber(persisted_vector.symbol_short_volume) &&
          SWV5_IsFiniteNumber(persisted_vector.symbol_net_volume) && SWV5_IsFiniteNumber(persisted_vector.aggregate_position_volume) &&
          SWV5_IsFiniteNumber(persisted_vector.basket_open_volume) && SWV5_IsFiniteNumber(persisted_vector.residual_volume) &&
          persisted_vector.symbol_long_volume>=0.0 && persisted_vector.symbol_short_volume>=0.0 &&
          SWV5_TestNear(persisted_vector.symbol_net_volume,persisted_vector.symbol_long_volume-persisted_vector.symbol_short_volume,context.volume_tolerance) &&
          persisted_vector.aggregate_position_volume>=0.0 && persisted_vector.basket_open_volume>=0.0 && persisted_vector.residual_volume>=0.0 &&
          SWV5_TestNear(persisted_vector.basket_open_volume,checkpoint.basket.lifecycle.aggregate_open_volume,context.volume_tolerance) &&
          SWV5_TestNear(persisted_vector.residual_volume,checkpoint.basket.lifecycle.residual_volume,context.volume_tolerance) &&
          persisted_vector.position_count==checkpoint.basket.lifecycle.live_position_count &&
          persisted_vector.order_count==checkpoint.basket.lifecycle.live_order_count &&
          persisted_vector.pending_request_count==checkpoint.pending_request_set.request_count &&
          persisted_vector.pending_request_count==checkpoint.basket.lifecycle.pending_request_count &&
          SWV5_TestCorrelationEqual(persisted_vector.latest_confirmed_correlation,checkpoint.last_confirmed_correlation) &&
          SWV5_TestBrokerIdentityEqual(persisted_vector.latest_broker_event_identity,checkpoint.last_confirmed_correlation.broker_identity) &&
          persisted_vector.transaction_high_watermark==persisted_vector.latest_broker_event_identity.transaction_sequence &&
          persisted_vector.request_set_digest==checkpoint.pending_request_set.request_set_digest &&
          persisted_vector.request_set_revision==checkpoint.pending_request_set.request_index_revision &&
          persisted_vector.basket_state==checkpoint.basket.lifecycle.state && persisted_vector.basket_state_version==checkpoint.basket.lifecycle.state_version &&
          persisted_vector.hard_kill_generation==checkpoint.hard_kill_state.latch_generation &&
          SWV5_TestFenceEqual(persisted_vector.ownership_fence,checkpoint.header.ownership_fence) &&
          persisted_vector.reconciliation_revision>0 &&
          persisted_vector.source_summary_digest==SWV5_TestReconciliationSourceDigest(persisted_vector);
}

bool SWV5_TestCheckpointHardKillSemanticValid(const SWV5_ContractValidationContext &context,
                                               const SWV5_HardKillState &state,
                                               const SWV5_PersistenceNamespace &expected_namespace)
{
   if(!SWV5_TestExecutionVersionExact(context,state.contract_version) ||
      !SWV5_TestNamespaceEqual(state.persistence_namespace,expected_namespace) ||
      !SWV5_TestRiskAccountNamespaceComplete(context,state.account_namespace) ||
      !SWV5_TestRiskAccountNamespaceBelongsToPersistence(state.account_namespace,expected_namespace) ||
      !SWV5_TestHardKillStateValid(state.state) || state.latch_id=="" || state.latch_generation==0 ||
      !SWV5_TestExecutionVersionExact(context,state.release_evidence.contract_version) ||
      !SWV5_TestExecutionVersionExact(context,state.release_evidence.broker_evidence.contract_version) ||
      !SWV5_TestExecutionVersionExact(context,state.release_evidence.persistence_evidence.contract_version) ||
      !SWV5_TestExecutionVersionExact(context,state.release_evidence.exposure_evidence.contract_version) ||
      !SWV5_TestNamespaceEqual(state.release_evidence.persistence_namespace,expected_namespace) ||
      state.release_evidence.latch_id!=state.latch_id || state.release_evidence.latch_generation!=state.latch_generation)
      return false;
   switch(state.state)
   {
      case SWV5_HARD_KILL_INACTIVE:
         return state.activation_reason=="" && state.release_generation==0 && state.release_evidence.release_id=="";
      case SWV5_HARD_KILL_ACTIVE:
         return state.activation_reason!="" && state.activated_at>0 && state.activated_at<=context.clock_time &&
                state.activation_authority!="" && state.release_evidence.release_id=="";
      case SWV5_HARD_KILL_RELEASE_PENDING:
         return SWV5_TestHardKillReleaseValid(context,state,state.release_evidence,SWV5_HARD_KILL_RELEASE_CURRENT_EXECUTION);
      case SWV5_HARD_KILL_RELEASED:
         // Persistence validates checkpoint content and a complete external
         // authority reference. It cannot validate or recreate authority.
         return SWV5_TestHardKillReleaseValid(context,state,state.release_evidence,SWV5_HARD_KILL_RELEASE_HISTORICAL_PERSISTED) &&
                SWV5_TestVersionEqual(state.release_authority_reference.contract_version,context.expected_version) &&
                state.release_authority_reference.authority_record_id!="" &&
                state.release_authority_reference.authority_record_sequence>0 &&
                state.release_authority_reference.authority_record_digest!="" &&
                state.release_authority_reference.release_id==state.release_evidence.release_id &&
                state.release_authority_reference.latch_generation==state.latch_generation &&
                state.release_authority_reference.release_generation==state.release_generation;
   }
   return false;
}

bool SWV5_TestPersistenceRecordValid(const SWV5_ContractValidationContext &context,
                                     const SWV5_PersistedCheckpoint &checkpoint)
{
   return SWV5_TestContextValid(context) &&
           SWV5_TestExecutionVersionExact(context,checkpoint.header.contract_version) &&
           SWV5_TestExecutionNamespaceValid(context,checkpoint.header.persistence_namespace) &&
           SWV5_TestExecutionFenceBelongsToNamespace(context,checkpoint.header.ownership_fence,checkpoint.header.persistence_namespace) &&
           SWV5_TestExecutionVersionExact(context,checkpoint.pending_request_set.contract_version) &&
           SWV5_TestNamespaceEqual(checkpoint.header.persistence_namespace,checkpoint.basket.persistence_namespace) &&
           SWV5_TestNamespaceEqual(checkpoint.header.persistence_namespace,checkpoint.hard_kill_state.persistence_namespace) &&
           SWV5_TestFenceEqual(checkpoint.header.ownership_fence,checkpoint.basket.lifecycle.ownership_fence) &&
           checkpoint.header.record_sequence>checkpoint.header.previous_record_sequence &&
           checkpoint.header.store_revision!="" &&
           checkpoint.header.payload_digest==SWV5_TestCheckpointPayloadDigest(checkpoint) &&
           checkpoint.header.payload_size==SWV5_TestCheckpointPayloadSize(checkpoint) &&
           checkpoint.header.written_at>0 && checkpoint.header.written_at<=context.clock_time &&
           checkpoint.header.persistence_namespace.basket_id.value==checkpoint.basket.lifecycle.basket_id.value &&
           SWV5_TestCheckpointBasketSemanticValid(context,checkpoint.basket,checkpoint.header.persistence_namespace,checkpoint.header.ownership_fence) &&
           SWV5_TestCorrelationComplete(checkpoint.last_confirmed_correlation) &&
           checkpoint.last_confirmed_correlation.phase==SWV5_EXECUTION_PHASE_AUTHORITATIVE_CONFIRMATION &&
            SWV5_TestCheckpointHardKillSemanticValid(context,checkpoint.hard_kill_state,checkpoint.header.persistence_namespace) &&
            SWV5_TestReconciliationVectorValid(context,checkpoint) &&
           ((!checkpoint.has_latest_pending_request && checkpoint.pending_request_set.request_count==0) ||
            (checkpoint.has_latest_pending_request && checkpoint.pending_request_set.request_count>0 &&
             SWV5_TestPersistedRequestValid(context,checkpoint.latest_pending_request,checkpoint.header.persistence_namespace)));
}

bool SWV5_TestRequestSetValid(const SWV5_ContractValidationContext &context,
                              const SWV5_PersistenceNamespace &persistence_namespace,
                              const SWV5_PersistedRequestEvidence &requests[],
                              const SWV5_PersistedRequestSetHeader &header)
{
   if(!SWV5_TestNamespaceComplete(persistence_namespace) || !SWV5_TestVersionValid(header.contract_version) ||
      !SWV5_TestVersionEqual(header.contract_version,persistence_namespace.contract_version) ||
      ArraySize(requests)!=(int)header.request_count || header.record_sequence==0 ||
      header.request_set_digest!=SWV5_TestRequestSetDigest(requests) ||
      header.request_index_revision!=SWV5_TestRequestSetRevision(requests,header.record_sequence))
      return false;
   ulong previous_sequence=0;
   for(int index=0;index<ArraySize(requests);index++)
   {
      if(!SWV5_TestPersistedRequestValid(context,requests[index],persistence_namespace) ||
         requests[index].record_sequence<=previous_sequence || requests[index].record_sequence>header.record_sequence)
         return false;
      previous_sequence=requests[index].record_sequence;
   }
   return true;
}

SWV5_ReconciliationStatus SWV5_TestRestartDisposition(const SWV5_ContractValidationContext &context,
                                                        const SWV5_RestartReconciliationInput &engineInput,
                                                        const SWV5_PersistedRequestEvidence &pending_requests[],
                                                        SWV5_RestartReadinessDisposition &readiness)
{
   readiness=SWV5_RESTART_HALTED;
   if(!SWV5_TestContextValid(context) ||
      !SWV5_TestExecutionVersionExact(context,engineInput.contract_version) ||
      engineInput.persistence_status!=SWV5_PERSISTENCE_LOADED ||
      !SWV5_TestPersistenceRecordValid(context,engineInput.persisted))
      return SWV5_RECONCILIATION_CORRUPT_HALT;
   if(!SWV5_TestExecutionVersionExact(context,engineInput.broker.contract_version) ||
      !SWV5_TestExecutionNamespaceValid(context,engineInput.broker.persistence_namespace) ||
      engineInput.broker.account_mode!=SWV5_ACCOUNT_MODE_HEDGING ||
      engineInput.broker.authority!=SWV5_AUTHORITY_LIVE_BROKER_STATE ||
      engineInput.broker.observed_at<=0 || engineInput.broker.observed_at>context.clock_time ||
      !SWV5_IsFiniteNumber(engineInput.broker.aggregate_position_volume) ||
      !SWV5_IsFiniteNumber(engineInput.broker.residual_volume) ||
      engineInput.broker.aggregate_position_volume<0.0 || engineInput.broker.residual_volume<0.0 ||
      !SWV5_TestCorrelationComplete(engineInput.broker.latest_confirmed_correlation) ||
      !SWV5_TestVersionValid(engineInput.broker.latest_broker_event_identity.contract_version) ||
      engineInput.broker.latest_broker_event_identity.broker_event_id=="" ||
      engineInput.broker.latest_broker_event_identity.transaction_sequence==0 ||
      engineInput.broker.transaction_high_watermark==0 || engineInput.broker.observation_sequence==0 ||
      engineInput.broker.complete_summary_digest!=SWV5_TestBrokerSummaryDigest(engineInput.broker))
      return SWV5_RECONCILIATION_CONFLICT_HALT;
   if(!SWV5_TestNamespaceComplete(engineInput.persistence_namespace))
      return SWV5_RECONCILIATION_CONFLICT_HALT;
   if(!SWV5_TestNamespaceEqual(engineInput.persistence_namespace,engineInput.persisted.header.persistence_namespace) ||
      !SWV5_TestNamespaceEqual(engineInput.persistence_namespace,engineInput.broker.persistence_namespace))
      return SWV5_RECONCILIATION_CONFLICT_HALT;
   if(!SWV5_TestFenceEqual(engineInput.claimant_fence,engineInput.persisted.header.ownership_fence))
      return SWV5_RECONCILIATION_OWNERSHIP_CONFLICT_HALT;
   if(engineInput.persisted.hard_kill_state.state==SWV5_HARD_KILL_RELEASED &&
      (!engineInput.has_release_authority_record ||
       !SWV5_TestHistoricalHardKillReleaseValid(context,
                                                engineInput.persisted.hard_kill_state,
                                                engineInput.persisted.hard_kill_state.release_evidence,
                                                engineInput.release_authority_record)))
      return SWV5_RECONCILIATION_CONFLICT_HALT;
   if(!SWV5_TestQueriesComplete(engineInput.broker.queries))
      return SWV5_RECONCILIATION_MANUAL_REQUIRED;
   if(!engineInput.persisted.clean_shutdown ||
      engineInput.persisted.basket.lifecycle.reconciliation_state!=SWV5_RECONCILIATION_STATE_MATCHED)
   {
      readiness=SWV5_RESTART_RECONCILIATION_REQUIRED;
      return SWV5_RECONCILIATION_MANUAL_REQUIRED;
   }
   const SWV5_PersistedReconciliationVector persisted_vector=engineInput.persisted.reconciliation_vector;
   if(!SWV5_TestNear(engineInput.broker.symbol_long_volume,persisted_vector.symbol_long_volume,context.volume_tolerance) ||
      !SWV5_TestNear(engineInput.broker.symbol_short_volume,persisted_vector.symbol_short_volume,context.volume_tolerance) ||
      !SWV5_TestNear(engineInput.broker.symbol_net_volume,persisted_vector.symbol_net_volume,context.volume_tolerance) ||
      !SWV5_TestNear(engineInput.broker.aggregate_position_volume,persisted_vector.aggregate_position_volume,context.volume_tolerance) ||
      engineInput.broker.position_count!=persisted_vector.position_count || engineInput.broker.order_count!=persisted_vector.order_count ||
      engineInput.broker.pending_request_count!=persisted_vector.pending_request_count ||
      !SWV5_TestCorrelationEqual(engineInput.broker.latest_confirmed_correlation,persisted_vector.latest_confirmed_correlation) ||
      !SWV5_TestBrokerIdentityEqual(engineInput.broker.latest_broker_event_identity,persisted_vector.latest_broker_event_identity) ||
      engineInput.broker.transaction_high_watermark!=persisted_vector.transaction_high_watermark ||
      persisted_vector.request_set_digest!=engineInput.persisted.pending_request_set.request_set_digest ||
      persisted_vector.request_set_revision!=engineInput.persisted.pending_request_set.request_index_revision)
      return SWV5_RECONCILIATION_CONFLICT_HALT;
   // Broker/persistence exposure divergence is a valid, integrity-checked reconciliation
   // outcome. Classify it before comparing the broker-derived summary digest, which is
   // expected to differ whenever authoritative residual exposure differs.
   const double persisted_volume=persisted_vector.residual_volume;
   const double broker_volume=engineInput.broker.residual_volume;
   if(broker_volume>persisted_volume+0.0000001)
      return SWV5_RECONCILIATION_BROKER_AHEAD_HALT;
   if(persisted_volume>broker_volume+0.0000001)
      return SWV5_RECONCILIATION_PERSISTENCE_AHEAD_HALT;
   if(engineInput.persisted.pending_request_set.request_count!=engineInput.broker.pending_request_count ||
      !SWV5_TestRequestSetValid(context,engineInput.persistence_namespace,pending_requests,engineInput.persisted.pending_request_set))
      return SWV5_RECONCILIATION_CONFLICT_HALT;
   if(ArraySize(pending_requests)==0)
   {
      if(engineInput.persisted.has_latest_pending_request)
         return SWV5_RECONCILIATION_CONFLICT_HALT;
      if(engineInput.persisted.hard_kill_state.state==SWV5_HARD_KILL_ACTIVE ||
         engineInput.persisted.hard_kill_state.state==SWV5_HARD_KILL_RELEASE_PENDING)
      {
         readiness=SWV5_RESTART_CLOSE_ONLY;
         return SWV5_RECONCILIATION_MATCHED_CHECKPOINT_REQUIRED;
      }
      readiness=SWV5_RESTART_SAFE_TO_RESUME;
      return SWV5_RECONCILIATION_MATCHED_CHECKPOINT_REQUIRED;
   }
   if(!engineInput.persisted.has_latest_pending_request ||
      !SWV5_TestPersistedRequestEqual(engineInput.persisted.latest_pending_request,pending_requests[ArraySize(pending_requests)-1]))
      return SWV5_RECONCILIATION_CONFLICT_HALT;
   bool reconciliation_required=false;
   bool retry_forbidden=false;
   for(int index=0;index<ArraySize(pending_requests);index++)
   {
      const SWV5_PendingRequest pending=pending_requests[index].pending_request;
      if(pending_requests[index].account_mode!=engineInput.broker.account_mode ||
         !SWV5_TestNamespaceEqual(pending_requests[index].persistence_namespace,engineInput.persistence_namespace) ||
         !SWV5_TestFenceEqual(pending_requests[index].ownership_fence,engineInput.claimant_fence) ||
         !SWV5_TestRequestIdentityComplete(pending.intent.request_identity))
         return SWV5_RECONCILIATION_CONFLICT_HALT;
      const double expected_residual=MathMax(0.0,pending.intent.normalized_volume-pending.cumulative_confirmed_volume);
      if(!SWV5_TestNear(expected_residual,pending.residual_requested_volume,0.0000001))
         return SWV5_RECONCILIATION_CONFLICT_HALT;
      if(pending.lifecycle_phase==SWV5_EXECUTION_PHASE_UNCERTAIN || pending.state==SWV5_REQUEST_RECONCILIATION_REQUIRED)
         reconciliation_required=true;
      else if(pending.retry_disposition==SWV5_RETRY_FORBIDDEN && pending.state!=SWV5_REQUEST_CONFIRMED)
         retry_forbidden=true;
      else if(pending.state!=SWV5_REQUEST_CONFIRMED && pending.state!=SWV5_REQUEST_CANCELLED && pending.state!=SWV5_REQUEST_REJECTED)
         reconciliation_required=true;
   }
   if(engineInput.persisted.hard_kill_state.state==SWV5_HARD_KILL_ACTIVE ||
      engineInput.persisted.hard_kill_state.state==SWV5_HARD_KILL_RELEASE_PENDING)
      readiness=SWV5_RESTART_CLOSE_ONLY;
   else if(reconciliation_required)
      readiness=SWV5_RESTART_RECONCILIATION_REQUIRED;
   else if(retry_forbidden)
      readiness=SWV5_RESTART_RETRY_FORBIDDEN;
   else
      readiness=SWV5_RESTART_SAFE_TO_RESUME;
   return SWV5_RECONCILIATION_MATCHED_CHECKPOINT_REQUIRED;
}

bool SWV5_TestMonetaryBasisComplete(const SWV5_RiskMonetaryBasis &basis)
{
   return SWV5_TestVersionValid(basis.contract_version) && basis.currency!="" && basis.account_currency!="" &&
          SWV5_IsFiniteNumber(basis.conversion_rate_to_account_currency) &&
          basis.conversion_rate_to_account_currency>0.0 && basis.conversion_source!="" && basis.valuation_at>0 &&
          basis.calculation_basis!=SWV5_RISK_BASIS_UNDEFINED && basis.sign_convention!=SWV5_RISK_SIGN_UNDEFINED &&
          basis.includes_realized && basis.includes_unrealized && basis.includes_commission && basis.includes_swap && basis.includes_fee;
}

bool SWV5_TestRiskVersionExact(const SWV5_ContractValidationContext &context,
                               const SWV5_ContractVersion &candidate)
{
   return SWV5_TestExecutionVersionExact(context,candidate);
}

bool SWV5_TestRiskMonetaryBasisComplete(const SWV5_ContractValidationContext &context,
                                        const SWV5_RiskMonetaryBasis &basis)
{
   return SWV5_TestRiskVersionExact(context,basis.contract_version) &&
          SWV5_TestMonetaryBasisComplete(basis);
}

bool SWV5_TestMonetaryBasisEqual(const SWV5_RiskMonetaryBasis &left,
                                 const SWV5_RiskMonetaryBasis &right,
                                 const SWV5_ContractValidationContext &context)
{
   return SWV5_TestVersionEqual(left.contract_version,right.contract_version) &&
          left.currency==right.currency && left.account_currency==right.account_currency &&
          SWV5_TestNear(left.conversion_rate_to_account_currency,right.conversion_rate_to_account_currency,context.price_tolerance) &&
          left.conversion_source==right.conversion_source && left.valuation_at==right.valuation_at &&
          left.calculation_basis==right.calculation_basis && left.sign_convention==right.sign_convention &&
          left.includes_realized==right.includes_realized && left.includes_unrealized==right.includes_unrealized &&
          left.includes_commission==right.includes_commission && left.includes_swap==right.includes_swap &&
          left.includes_fee==right.includes_fee;
}

bool SWV5_TestRiskLimitsComplete(const SWV5_RiskLimits &limits)
{
   return SWV5_TestVersionValid(limits.contract_version) && limits.contract_id!="" &&
          SWV5_IsFiniteNumber(limits.minimum_equity) && SWV5_IsFiniteNumber(limits.maximum_daily_net_loss) &&
          SWV5_IsFiniteNumber(limits.maximum_account_margin_fraction) && SWV5_IsFiniteNumber(limits.maximum_basket_loss) &&
          SWV5_IsFiniteNumber(limits.maximum_basket_volume) && SWV5_IsFiniteNumber(limits.maximum_symbol_volume) &&
          SWV5_IsFiniteNumber(limits.maximum_aggregate_volume) && SWV5_IsFiniteNumber(limits.maximum_aggregate_notional) &&
          limits.minimum_equity>0.0 && limits.maximum_daily_net_loss>0.0 &&
          limits.maximum_account_margin_fraction>0.0 && limits.maximum_account_margin_fraction<=1.0 &&
          limits.maximum_basket_loss>0.0 && limits.maximum_basket_volume>0.0 &&
          limits.maximum_symbol_volume>0.0 && limits.maximum_aggregate_volume>0.0 &&
          limits.maximum_aggregate_notional>0.0 && limits.maximum_live_baskets>0 &&
          limits.maximum_cumulative_recovery_attempts>0 && limits.maximum_snapshot_age_seconds>0 &&
          limits.trading_day_policy!=SWV5_TRADING_DAY_UNDEFINED;
}

bool SWV5_TestRiskLimitsComplete(const SWV5_ContractValidationContext &context,
                                 const SWV5_RiskLimits &limits)
{
   return SWV5_TestRiskVersionExact(context,limits.contract_version) &&
          SWV5_TestRiskLimitsComplete(limits);
}

bool SWV5_TestRiskLimitsEqual(const SWV5_RiskLimits &left,
                              const SWV5_RiskLimits &right,
                              const SWV5_ContractValidationContext &context)
{
   return SWV5_TestVersionEqual(left.contract_version,right.contract_version) &&
          left.contract_id==right.contract_id &&
          SWV5_TestNear(left.minimum_equity,right.minimum_equity,context.price_tolerance) &&
          SWV5_TestNear(left.maximum_daily_net_loss,right.maximum_daily_net_loss,context.price_tolerance) &&
          SWV5_TestNear(left.maximum_account_margin_fraction,right.maximum_account_margin_fraction,context.price_tolerance) &&
          SWV5_TestNear(left.maximum_basket_loss,right.maximum_basket_loss,context.price_tolerance) &&
          SWV5_TestNear(left.maximum_basket_volume,right.maximum_basket_volume,context.volume_tolerance) &&
          SWV5_TestNear(left.maximum_symbol_volume,right.maximum_symbol_volume,context.volume_tolerance) &&
          SWV5_TestNear(left.maximum_aggregate_volume,right.maximum_aggregate_volume,context.volume_tolerance) &&
          SWV5_TestNear(left.maximum_aggregate_notional,right.maximum_aggregate_notional,context.price_tolerance) &&
          left.maximum_live_baskets==right.maximum_live_baskets &&
          left.maximum_cumulative_recovery_attempts==right.maximum_cumulative_recovery_attempts &&
          left.maximum_snapshot_age_seconds==right.maximum_snapshot_age_seconds &&
          left.trading_day_policy==right.trading_day_policy &&
          left.trading_day_utc_offset_minutes==right.trading_day_utc_offset_minutes &&
          left.hard_kill_enabled==right.hard_kill_enabled;
}

bool SWV5_TestAccountNamespaceEqual(const SWV5_AccountRiskNamespace &left,
                                    const SWV5_AccountRiskNamespace &right,
                                    const bool require_sequence=true)
{
   return SWV5_TestVersionEqual(left.contract_version,right.contract_version) &&
          left.broker_identity==right.broker_identity && left.server==right.server &&
          left.account_login==right.account_login && left.account_currency==right.account_currency &&
          left.strategy_id==right.strategy_id && left.magic==right.magic &&
          left.account_mode==right.account_mode && left.authoritative_source==right.authoritative_source &&
          left.snapshot_epoch==right.snapshot_epoch && (!require_sequence || left.snapshot_sequence==right.snapshot_sequence);
}

bool SWV5_TestRiskAccountNamespaceComplete(const SWV5_ContractValidationContext &context,
                                           const SWV5_AccountRiskNamespace &space)
{
   return SWV5_TestRiskVersionExact(context,space.contract_version) &&
          space.broker_identity!="" && space.server!="" && space.account_login>0 &&
          space.account_currency!="" && space.strategy_id!="" && space.magic>0 &&
          space.account_mode==SWV5_ACCOUNT_MODE_HEDGING &&
          space.authoritative_source==SWV5_AUTHORITY_LIVE_BROKER_STATE &&
          space.snapshot_epoch>0 && space.snapshot_sequence>0;
}

bool SWV5_TestRiskAccountNamespaceBelongsToPersistence(const SWV5_AccountRiskNamespace &account_space,
                                                       const SWV5_PersistenceNamespace &persistence_space)
{
   const SWV5_OwnershipKey key=persistence_space.ownership_namespace;
   return account_space.broker_identity==key.broker_identity &&
          account_space.server==key.server && account_space.account_login==key.account_login &&
          account_space.strategy_id==key.strategy_id && account_space.magic==key.magic;
}

bool SWV5_TestRiskBasketEnvelopeValid(const SWV5_ContractValidationContext &context,
                                      const SWV5_BasketRiskSnapshot &basket,
                                      const SWV5_PersistenceNamespace &persistence_space,
                                      const SWV5_OwnershipFence &fence)
{
   return SWV5_TestRiskVersionExact(context,basket.contract_version) &&
          SWV5_TestRiskVersionExact(context,basket.lifecycle.contract_version) &&
          SWV5_TestRiskVersionExact(context,basket.lifecycle.ownership_fence.contract_version) &&
          SWV5_TestRiskVersionExact(context,basket.lifecycle.accepted_recovery_evidence.contract_version) &&
          SWV5_TestRiskVersionExact(context,basket.lifecycle.broker_queries.contract_version) &&
          basket.lifecycle.basket_id.value==persistence_space.basket_id.value &&
          basket.lifecycle.state>=SWV5_BASKET_IDLE && basket.lifecycle.state<=SWV5_BASKET_ERROR &&
          basket.lifecycle.state_version>0 &&
          SWV5_TestFenceEqual(basket.lifecycle.ownership_fence,fence);
}

bool SWV5_TestRiskHardKillEnvelopeValid(const SWV5_ContractValidationContext &context,
                                        const SWV5_HardKillState &state,
                                        const SWV5_PersistenceNamespace &persistence_space,
                                        const SWV5_AccountRiskNamespace &account_space)
{
   return SWV5_TestRiskVersionExact(context,state.contract_version) &&
          SWV5_TestExecutionNamespaceValid(context,state.persistence_namespace) &&
          SWV5_TestNamespaceEqual(state.persistence_namespace,persistence_space) &&
          SWV5_TestRiskAccountNamespaceComplete(context,state.account_namespace) &&
          SWV5_TestAccountNamespaceEqual(state.account_namespace,account_space,true) &&
          SWV5_TestRiskAccountNamespaceBelongsToPersistence(state.account_namespace,state.persistence_namespace) &&
          state.latch_id!="" && state.latch_generation>0 &&
          state.state>=SWV5_HARD_KILL_INACTIVE && state.state<=SWV5_HARD_KILL_RELEASED &&
          SWV5_TestRiskVersionExact(context,state.release_evidence.contract_version) &&
          SWV5_TestRiskVersionExact(context,state.release_evidence.broker_evidence.contract_version) &&
          SWV5_TestRiskVersionExact(context,state.release_evidence.persistence_evidence.contract_version) &&
          SWV5_TestRiskVersionExact(context,state.release_evidence.exposure_evidence.contract_version);
}

bool SWV5_TestMarginEvidenceValid(const SWV5_ContractValidationContext &context,
                                   const SWV5_RiskEvaluationInput &current)
{
   const SWV5_MarginProjectionEvidence evidence=current.projected.margin_evidence;
   const SWV5_MarginAuthorityRecord authority=current.margin_authority_record;
   const bool increasing=current.intent.intent_type==SWV5_INTENT_OPEN || current.intent.intent_type==SWV5_INTENT_INCREASE;
   return SWV5_TestRiskVersionExact(context,evidence.contract_version) &&
          SWV5_TestNamespaceEqual(evidence.persistence_namespace,current.intent.persistence_namespace) &&
          SWV5_TestAccountNamespaceEqual(evidence.account_namespace,current.account_namespace,true) &&
          SWV5_TestFenceEqual(evidence.ownership_fence,current.ownership_fence) &&
          SWV5_TestRequestIdentityEqual(evidence.request_identity,current.intent.request_identity) &&
          evidence.basket_id.value==current.intent.persistence_namespace.basket_id.value &&
          evidence.symbol==current.symbol_specification.symbol &&
          evidence.symbol_specification_sequence==current.symbol_specification.specification_sequence &&
          evidence.symbol_specification_sequence==current.intent.symbol_specification_sequence &&
          evidence.intent_type==current.intent.intent_type && evidence.direction==current.intent.direction &&
          SWV5_TestNear(evidence.requested_volume,current.intent.normalized_volume,context.volume_tolerance) &&
          SWV5_TestNear(evidence.requested_price,current.intent.normalized_price,context.price_tolerance) &&
          SWV5_IsFiniteNumber(evidence.current_account_margin) && SWV5_IsFiniteNumber(evidence.current_free_margin) &&
          SWV5_IsFiniteNumber(evidence.projected_account_margin) && SWV5_IsFiniteNumber(evidence.additional_margin) &&
          evidence.current_account_margin>=0.0 && evidence.current_free_margin>=0.0 &&
          evidence.projected_account_margin>=0.0 && evidence.additional_margin>=0.0 &&
          SWV5_TestNear(evidence.current_account_margin,current.account.margin,context.price_tolerance) &&
          SWV5_TestNear(evidence.current_free_margin,current.account.free_margin,context.price_tolerance) &&
          SWV5_TestNear(evidence.additional_margin,evidence.projected_account_margin-evidence.current_account_margin,context.price_tolerance) &&
          (!increasing || evidence.additional_margin>context.price_tolerance) &&
          evidence.additional_margin<=evidence.current_free_margin+context.price_tolerance &&
          evidence.projected_account_margin<=current.account.equity*current.limits.maximum_account_margin_fraction+context.price_tolerance &&
          evidence.account_currency==current.account_namespace.account_currency &&
          evidence.issuing_component==SWV5_COMPONENT_AUTHORITY_BROKER_ADAPTER &&
          evidence.authority_source==SWV5_AUTHORITY_LIVE_BROKER_STATE && evidence.calculation_reference!="" &&
          evidence.observed_at>0 && evidence.observed_at<=evidence.calculated_at && evidence.calculated_at<=context.clock_time &&
          evidence.calculated_at>=context.clock_time-(datetime)current.limits.maximum_snapshot_age_seconds &&
          evidence.evidence_sequence>0 && evidence.evidence_digest==SWV5_TestMarginEvidenceDigest(evidence) &&
          (!increasing ||
           (current.has_margin_authority_record &&
            SWV5_TestRiskVersionExact(context,authority.contract_version) &&
            SWV5_TestNamespaceEqual(authority.persistence_namespace,evidence.persistence_namespace) &&
            SWV5_TestAccountNamespaceEqual(authority.account_namespace,evidence.account_namespace,true) &&
            SWV5_TestFenceEqual(authority.ownership_fence,evidence.ownership_fence) &&
            SWV5_TestRequestIdentityEqual(authority.request_identity,evidence.request_identity) &&
            authority.basket_id.value==evidence.basket_id.value && authority.symbol==evidence.symbol &&
            authority.symbol_specification_sequence==evidence.symbol_specification_sequence &&
            authority.intent_type==evidence.intent_type && authority.direction==evidence.direction &&
            SWV5_TestNear(authority.requested_volume,evidence.requested_volume,context.volume_tolerance) &&
            SWV5_TestNear(authority.requested_price,evidence.requested_price,context.price_tolerance) &&
            SWV5_TestNear(authority.current_account_margin,evidence.current_account_margin,context.price_tolerance) &&
            SWV5_TestNear(authority.projected_account_margin,evidence.projected_account_margin,context.price_tolerance) &&
            SWV5_TestNear(authority.additional_margin,evidence.additional_margin,context.price_tolerance) &&
            SWV5_TestNear(authority.current_free_margin,evidence.current_free_margin,context.price_tolerance) &&
            authority.account_currency==evidence.account_currency &&
            authority.broker_calculation_reference==evidence.calculation_reference &&
            authority.observation_sequence>0 && authority.observed_at==evidence.observed_at &&
            authority.calculated_at==evidence.calculated_at &&
            authority.authority_record_id==evidence.authority_record_id && authority.authority_record_id!="" &&
            authority.authority_record_sequence==evidence.authority_record_sequence && authority.authority_record_sequence>0 &&
            authority.authority_record_digest==evidence.authority_record_digest &&
            authority.authority_record_digest==SWV5_TestMarginAuthorityDigest(authority) &&
            authority.issuing_component==SWV5_COMPONENT_AUTHORITY_BROKER_ADAPTER &&
            authority.authority_source==SWV5_AUTHORITY_LIVE_BROKER_STATE));
}

bool SWV5_TestBasketRiskEvidenceValid(const SWV5_ContractValidationContext &context,
                                      const SWV5_RiskEvaluationInput &current)
{
   const SWV5_BasketRiskProjectionEvidence evidence=current.projected.basket_risk_evidence;
   const SWV5_BasketRiskAuthorityRecord authority=current.basket_risk_authority_record;
   const bool increasing=current.intent.intent_type==SWV5_INTENT_OPEN || current.intent.intent_type==SWV5_INTENT_INCREASE;
   return SWV5_TestRiskVersionExact(context,evidence.contract_version) &&
          SWV5_TestNamespaceEqual(evidence.persistence_namespace,current.intent.persistence_namespace) &&
          SWV5_TestAccountNamespaceEqual(evidence.account_namespace,current.account_namespace,true) &&
          SWV5_TestFenceEqual(evidence.ownership_fence,current.ownership_fence) &&
          evidence.basket_id.value==current.intent.persistence_namespace.basket_id.value &&
          evidence.basket_state_version==current.basket.lifecycle.state_version &&
          SWV5_TestRequestIdentityEqual(evidence.request_identity,current.intent.request_identity) &&
          evidence.symbol==current.symbol_specification.symbol &&
          evidence.symbol_specification_sequence==current.symbol_specification.specification_sequence &&
          SWV5_IsFiniteNumber(evidence.existing_bounded_basket_loss) &&
          SWV5_IsFiniteNumber(evidence.incremental_request_bounded_loss) &&
          SWV5_IsFiniteNumber(evidence.interaction_or_offset_adjustment) &&
          SWV5_IsFiniteNumber(evidence.resulting_basket_maximum_loss) &&
          SWV5_IsFiniteNumber(evidence.realized_loss_basis) && SWV5_IsFiniteNumber(evidence.unrealized_loss_basis) &&
          SWV5_IsFiniteNumber(evidence.accrued_cost_basis) &&
          evidence.existing_bounded_basket_loss>=0.0 && evidence.incremental_request_bounded_loss>=0.0 &&
          evidence.resulting_basket_maximum_loss>=0.0 &&
          SWV5_TestNear(evidence.resulting_basket_maximum_loss,evidence.existing_bounded_basket_loss+
                        evidence.incremental_request_bounded_loss+evidence.interaction_or_offset_adjustment,context.price_tolerance) &&
          SWV5_TestMonetaryBasisEqual(evidence.monetary_basis,current.projected.monetary_basis,context) &&
          evidence.calculation_policy_id=="RESULTING_BASKET_MAXIMUM_ACCOUNT_CURRENCY_LOSS/V5" &&
          evidence.source_snapshot_digest!="" && evidence.issuing_component==SWV5_COMPONENT_AUTHORITY_RISK_GOVERNANCE &&
          evidence.authority_source==SWV5_AUTHORITY_LIVE_BROKER_STATE &&
          evidence.observed_at>0 && evidence.observed_at<=evidence.calculated_at && evidence.calculated_at<=context.clock_time &&
          evidence.calculated_at>=context.clock_time-(datetime)current.limits.maximum_snapshot_age_seconds &&
          evidence.evidence_sequence>0 && evidence.evidence_digest==SWV5_TestBasketRiskEvidenceDigest(evidence) &&
          evidence.resulting_basket_maximum_loss<=current.limits.maximum_basket_loss+context.price_tolerance &&
          (!increasing ||
           (current.has_basket_risk_authority_record &&
            SWV5_TestRiskVersionExact(context,authority.contract_version) &&
            SWV5_TestNamespaceEqual(authority.persistence_namespace,evidence.persistence_namespace) &&
            SWV5_TestAccountNamespaceEqual(authority.account_namespace,evidence.account_namespace,true) &&
            SWV5_TestFenceEqual(authority.ownership_fence,evidence.ownership_fence) &&
            authority.basket_id.value==evidence.basket_id.value && authority.basket_state_version==evidence.basket_state_version &&
            SWV5_TestRequestIdentityEqual(authority.request_identity,evidence.request_identity) &&
            authority.symbol==evidence.symbol && authority.symbol_specification_sequence==evidence.symbol_specification_sequence &&
            authority.source_snapshot_id!="" && authority.source_snapshot_digest==evidence.source_snapshot_digest &&
            SWV5_TestNear(authority.existing_bounded_basket_loss,evidence.existing_bounded_basket_loss,context.price_tolerance) &&
            SWV5_TestNear(authority.incremental_request_bounded_loss,evidence.incremental_request_bounded_loss,context.price_tolerance) &&
            SWV5_TestNear(authority.interaction_or_offset_adjustment,evidence.interaction_or_offset_adjustment,context.price_tolerance) &&
            SWV5_TestNear(authority.resulting_basket_maximum_loss,evidence.resulting_basket_maximum_loss,context.price_tolerance) &&
            SWV5_TestNear(authority.realized_loss_basis,evidence.realized_loss_basis,context.price_tolerance) &&
            SWV5_TestNear(authority.unrealized_loss_basis,evidence.unrealized_loss_basis,context.price_tolerance) &&
            SWV5_TestNear(authority.accrued_cost_basis,evidence.accrued_cost_basis,context.price_tolerance) &&
            SWV5_TestMonetaryBasisEqual(authority.monetary_basis,evidence.monetary_basis,context) &&
            authority.calculation_policy_id==evidence.calculation_policy_id && authority.observation_sequence>0 &&
            authority.observed_at==evidence.observed_at && authority.calculated_at==evidence.calculated_at &&
            authority.authority_record_id==evidence.authority_record_id && authority.authority_record_id!="" &&
            authority.authority_record_sequence==evidence.authority_record_sequence && authority.authority_record_sequence>0 &&
            authority.authority_record_digest==evidence.authority_record_digest &&
            authority.authority_record_digest==SWV5_TestBasketRiskAuthorityDigest(authority) &&
            authority.issuing_component==SWV5_COMPONENT_AUTHORITY_RISK_GOVERNANCE &&
            authority.authority_source==SWV5_AUTHORITY_RISK_GOVERNANCE_RECORD));
}

SWV5_RiskDisposition SWV5_TestRiskPrecheck(const SWV5_HardKillState &hard_kill,
                                           const SWV5_OwnershipFence &required_fence,
                                           const SWV5_OwnershipFence &observed_fence)
{
   if(hard_kill.state==SWV5_HARD_KILL_ACTIVE || hard_kill.state==SWV5_HARD_KILL_RELEASE_PENDING)
      return SWV5_RISK_HARD_KILL;
   if(!SWV5_TestFenceComplete(required_fence) || !SWV5_TestFenceEqual(required_fence,observed_fence))
      return SWV5_RISK_RECONCILIATION_REQUIRED;
   return SWV5_RISK_ALLOW;
}

bool SWV5_TestRiskInputCoherent(const SWV5_ContractValidationContext &context,
                                const SWV5_RiskEvaluationInput &current)
{
   const datetime oldest_allowed=context.clock_time-(datetime)current.limits.maximum_snapshot_age_seconds;
   const bool namespace_coherent=SWV5_TestAccountNamespaceEqual(current.account_namespace,current.account.account_namespace,true) &&
                                 SWV5_TestAccountNamespaceEqual(current.account_namespace,current.exposure.account_namespace,true) &&
                                 SWV5_TestAccountNamespaceEqual(current.account_namespace,current.basket.account_namespace,true) &&
                                 SWV5_TestAccountNamespaceEqual(current.account_namespace,current.projected.account_namespace,true) &&
                                 SWV5_TestAccountNamespaceEqual(current.account_namespace,current.hard_kill_state.account_namespace,true);
   const double current_symbol_volume=current.exposure.symbol_long_volume+current.exposure.symbol_short_volume;
   const double current_basket_volume=current.basket.lifecycle.aggregate_open_volume;
   const double request_volume=current.intent.normalized_volume;
   const double requested_notional=request_volume*current.symbol_specification.contract_size*current.intent.normalized_price*
                                    current.projected.monetary_basis.conversion_rate_to_account_currency;
   const bool exposure_increasing=(current.intent.intent_type==SWV5_INTENT_OPEN ||
                                   current.intent.intent_type==SWV5_INTENT_INCREASE);
   double expected_basket=current_basket_volume;
   double expected_symbol=current_symbol_volume;
   double expected_aggregate=current.exposure.aggregate_volume;
   if(exposure_increasing)
   {
      expected_basket+=(current.intent.intent_type==SWV5_INTENT_OPEN ? request_volume : request_volume);
      expected_symbol+=request_volume;
      expected_aggregate+=request_volume;
   }
   else if(current.intent.intent_type==SWV5_INTENT_REDUCE)
   {
      expected_basket=MathMax(0.0,current_basket_volume-request_volume);
      expected_symbol=MathMax(0.0,current_symbol_volume-request_volume);
      expected_aggregate=MathMax(0.0,current.exposure.aggregate_volume-request_volume);
   }
   else if(current.intent.intent_type==SWV5_INTENT_CLOSE)
   {
      expected_basket=0.0;
      expected_symbol=MathMax(0.0,current_symbol_volume-current_basket_volume);
      expected_aggregate=MathMax(0.0,current.exposure.aggregate_volume-current_basket_volume);
   }
   const double permitted_margin=current.account.equity*current.limits.maximum_account_margin_fraction;
   const bool all_numeric_finite=
      SWV5_IsFiniteNumber(current.account.balance) && SWV5_IsFiniteNumber(current.account.equity) &&
      SWV5_IsFiniteNumber(current.account.margin) && SWV5_IsFiniteNumber(current.account.free_margin) &&
      SWV5_IsFiniteNumber(current.account.daily_realized_net) && SWV5_IsFiniteNumber(current.account.daily_unrealized_net) &&
      SWV5_IsFiniteNumber(current.exposure.symbol_long_volume) && SWV5_IsFiniteNumber(current.exposure.symbol_short_volume) &&
      SWV5_IsFiniteNumber(current.exposure.symbol_net_volume) && SWV5_IsFiniteNumber(current.exposure.aggregate_volume) &&
      SWV5_IsFiniteNumber(current.exposure.aggregate_notional) && SWV5_IsFiniteNumber(current.basket.lifecycle.aggregate_open_volume) &&
      SWV5_IsFiniteNumber(current.basket.lifecycle.residual_volume) && SWV5_IsFiniteNumber(current.basket.realized_net) &&
      SWV5_IsFiniteNumber(current.basket.unrealized_net) && SWV5_IsFiniteNumber(current.basket.maximum_adverse_net) &&
      SWV5_IsFiniteNumber(current.projected.projected_volume) && SWV5_IsFiniteNumber(current.projected.projected_symbol_volume) &&
      SWV5_IsFiniteNumber(current.projected.projected_aggregate_volume) && SWV5_IsFiniteNumber(current.projected.projected_notional) &&
      SWV5_IsFiniteNumber(current.projected.margin_evidence.additional_margin) &&
      SWV5_IsFiniteNumber(current.projected.basket_risk_evidence.resulting_basket_maximum_loss);
   const bool operation_coherent=
      (current.intent.intent_type!=SWV5_INTENT_OPEN ||
       (current.basket.lifecycle.state==SWV5_BASKET_IDLE && current_basket_volume<=context.volume_tolerance)) &&
      ((current.intent.intent_type!=SWV5_INTENT_INCREASE && current.intent.intent_type!=SWV5_INTENT_REDUCE &&
        current.intent.intent_type!=SWV5_INTENT_CLOSE) ||
       (current.basket.lifecycle.state==SWV5_BASKET_ACTIVE && current_basket_volume>context.volume_tolerance)) &&
      current.exposure.symbol_long_volume>=0.0 && current.exposure.symbol_short_volume>=0.0 &&
      SWV5_TestNear(current.exposure.symbol_net_volume,
                    current.exposure.symbol_long_volume-current.exposure.symbol_short_volume,context.volume_tolerance) &&
      current.exposure.aggregate_volume+context.volume_tolerance>=current_symbol_volume &&
      current.exposure.aggregate_notional>=0.0 &&
       (current.intent.intent_type==SWV5_INTENT_CANCEL_PENDING ?
       SWV5_TestNear(current.projected.projected_volume,current_basket_volume,context.volume_tolerance) &&
       SWV5_TestNear(current.projected.projected_symbol_volume,current_symbol_volume,context.volume_tolerance) &&
       SWV5_TestNear(current.projected.projected_aggregate_volume,current.exposure.aggregate_volume,context.volume_tolerance) &&
        SWV5_TestNear(current.projected.projected_notional,current.exposure.aggregate_notional,context.price_tolerance) :
       SWV5_TestNear(current.projected.projected_volume,expected_basket,context.volume_tolerance) &&
       SWV5_TestNear(current.projected.projected_symbol_volume,expected_symbol,context.volume_tolerance) &&
       SWV5_TestNear(current.projected.projected_aggregate_volume,expected_aggregate,context.volume_tolerance)) &&
      (!exposure_increasing ||
        (current.projected.projected_notional+context.price_tolerance>=current.exposure.aggregate_notional+requested_notional &&
         current.intent.normalized_stop_price>0.0)) &&
      (current.intent.intent_type!=SWV5_INTENT_REDUCE ||
       (request_volume<=current_basket_volume+context.volume_tolerance &&
        ((current.intent.direction>0 && request_volume<=current.exposure.symbol_long_volume+context.volume_tolerance) ||
         (current.intent.direction<0 && request_volume<=current.exposure.symbol_short_volume+context.volume_tolerance)) &&
        current.projected.projected_notional<=current.exposure.aggregate_notional+context.price_tolerance)) &&
      (current.intent.intent_type!=SWV5_INTENT_CLOSE ||
       (SWV5_TestNear(request_volume,current_basket_volume,context.volume_tolerance) &&
        current.projected.projected_notional<=current.exposure.aggregate_notional+context.price_tolerance));
   return SWV5_TestContextValid(context) &&
           all_numeric_finite && operation_coherent &&
           SWV5_TestRiskVersionExact(context,current.contract_version) &&
           SWV5_TestIntentValid(context,current.intent) &&
           SWV5_TestRiskAccountNamespaceComplete(context,current.account_namespace) &&
           SWV5_TestRiskLimitsComplete(context,current.limits) &&
           SWV5_TestRiskVersionExact(context,current.account.contract_version) &&
           SWV5_TestRiskVersionExact(context,current.exposure.contract_version) &&
           SWV5_TestRiskVersionExact(context,current.projected.contract_version) &&
            SWV5_TestRiskMonetaryBasisComplete(context,current.projected.monetary_basis) &&
            SWV5_TestSpecificationValid(context,current.symbol_specification) &&
            current.symbol_specification.symbol==current.intent.persistence_namespace.ownership_namespace.symbol &&
            current.symbol_specification.specification_sequence==current.intent.symbol_specification_sequence &&
           namespace_coherent &&
           current.account_mode==SWV5_ACCOUNT_MODE_HEDGING && current.intent.account_mode==current.account_mode &&
           current.account_namespace.account_mode==current.account_mode &&
           SWV5_TestRiskAccountNamespaceBelongsToPersistence(current.account_namespace,current.intent.persistence_namespace) &&
           SWV5_TestExecutionFenceBelongsToNamespace(context,current.ownership_fence,current.intent.persistence_namespace) &&
           SWV5_TestFenceEqual(current.ownership_fence,current.intent.ownership_fence) &&
           SWV5_TestRiskBasketEnvelopeValid(context,current.basket,current.intent.persistence_namespace,current.ownership_fence) &&
           SWV5_TestRiskHardKillEnvelopeValid(context,current.hard_kill_state,current.intent.persistence_namespace,current.account_namespace) &&
           current.basket.lifecycle.state_version==current.intent.expected_basket_version &&
           current.exposure.symbol==current.intent.persistence_namespace.ownership_namespace.symbol &&
           current.projected.symbol==current.intent.persistence_namespace.ownership_namespace.symbol &&
           current.account.authoritative && current.exposure.complete && current.projected.complete &&
           current.projected.monetary_basis.account_currency==current.account_namespace.account_currency &&
           current.account.observed_at>=oldest_allowed && current.account.observed_at<=context.clock_time &&
          current.exposure.observed_at>=oldest_allowed && current.exposure.observed_at<=context.clock_time &&
          current.basket.observed_at>=oldest_allowed && current.basket.observed_at<=context.clock_time &&
          current.projected.calculated_at>=oldest_allowed && current.projected.calculated_at<=context.clock_time &&
           current.projected.monetary_basis.valuation_at>=oldest_allowed && current.projected.monetary_basis.valuation_at<=context.clock_time &&
           current.hard_kill_state.state==SWV5_HARD_KILL_INACTIVE && current.hard_kill_state.latch_id!="" &&
           current.hard_kill_state.latch_generation>0 &&
           current.account.balance>0.0 && current.account.equity>0.0 &&
           current.account.margin>=0.0 && current.account.free_margin>=0.0 &&
           current.account.equity>=current.limits.minimum_equity-context.price_tolerance &&
           current.account.margin<=permitted_margin+context.price_tolerance &&
           -(current.account.daily_realized_net+current.account.daily_unrealized_net)<=current.limits.maximum_daily_net_loss+context.price_tolerance &&
           current.exposure.live_basket_count<=current.limits.maximum_live_baskets &&
           current.basket.lifecycle.cumulative_recovery_attempts<=current.limits.maximum_cumulative_recovery_attempts &&
           current.projected.projected_volume>=0.0 &&
           current.projected.projected_volume<=current.limits.maximum_basket_volume+context.volume_tolerance &&
           current.projected.projected_symbol_volume>=0.0 &&
           current.projected.projected_symbol_volume<=current.limits.maximum_symbol_volume+context.volume_tolerance &&
           current.projected.projected_aggregate_volume>=0.0 &&
           current.projected.projected_aggregate_volume<=current.limits.maximum_aggregate_volume+context.volume_tolerance &&
           current.projected.projected_volume<=current.projected.projected_symbol_volume+context.volume_tolerance &&
           current.projected.projected_symbol_volume<=current.projected.projected_aggregate_volume+context.volume_tolerance &&
           current.projected.projected_notional>=0.0 &&
           current.projected.projected_notional<=current.limits.maximum_aggregate_notional+context.price_tolerance &&
            SWV5_TestMarginEvidenceValid(context,current) &&
            SWV5_TestBasketRiskEvidenceValid(context,current) &&
            SWV5_TestNear(current.projected.projected_margin,current.projected.margin_evidence.additional_margin,context.price_tolerance) &&
            SWV5_TestNear(current.projected.projected_maximum_loss,current.projected.basket_risk_evidence.resulting_basket_maximum_loss,context.price_tolerance);
}

bool SWV5_TestAuthorizationMatches(const SWV5_ContractValidationContext &context,
                                    const SWV5_RiskAuthorization &authorization,
                                    const SWV5_RiskEvaluationInput &current)
{
   const datetime policy_expiry=authorization.evaluated_at+(datetime)authorization.authorized_limits.maximum_snapshot_age_seconds;
   const datetime expected_expiry=(current.intent.authorization_expires_at<policy_expiry ? current.intent.authorization_expires_at : policy_expiry);
   return SWV5_TestRiskInputCoherent(context,current) &&
          SWV5_TestVersionEqual(authorization.contract_version,context.expected_version) &&
          authorization.authorization_id!="" && authorization.authorization_id==current.intent.risk_authorization_id &&
          authorization.limits_contract_id!="" && authorization.limits_contract_id==current.limits.contract_id &&
          authorization.authorized_limits.contract_id==authorization.limits_contract_id &&
          SWV5_TestRiskLimitsEqual(authorization.authorized_limits,current.limits,context) &&
          SWV5_TestRequestIdentityEqual(authorization.request_identity,current.intent.request_identity) &&
          SWV5_TestNamespaceEqual(authorization.persistence_namespace,current.intent.persistence_namespace) &&
          SWV5_TestFenceEqual(authorization.ownership_fence,current.ownership_fence) &&
          SWV5_TestAccountNamespaceEqual(authorization.account_namespace,current.account_namespace,true) &&
          authorization.account_mode==current.account_mode && authorization.account_mode==SWV5_ACCOUNT_MODE_HEDGING &&
          authorization.disposition==SWV5_RISK_ALLOW && authorization.blocking_domain==SWV5_RISK_DOMAIN_NONE &&
          authorization.reason_flags==0 && authorization.reason_text!="" &&
          authorization.basket_state_version==current.basket.lifecycle.state_version &&
          authorization.basket_state_version==current.intent.expected_basket_version &&
          authorization.symbol_specification_sequence==current.intent.symbol_specification_sequence &&
          authorization.authorized_intent_type==current.intent.intent_type &&
          authorization.authorized_direction==current.intent.direction &&
          SWV5_TestNear(authorization.authorized_volume,current.intent.normalized_volume,context.volume_tolerance) &&
          SWV5_TestNear(authorization.authorized_price,current.intent.normalized_price,context.price_tolerance) &&
          SWV5_TestNear(authorization.authorized_stop_price,current.intent.normalized_stop_price,context.price_tolerance) &&
          SWV5_TestNear(authorization.authorized_limit_price,current.intent.normalized_limit_price,context.price_tolerance) &&
          authorization.risk_snapshot_epoch==current.account_namespace.snapshot_epoch && authorization.risk_snapshot_epoch>0 &&
          authorization.risk_snapshot_sequence==current.account_namespace.snapshot_sequence && authorization.risk_snapshot_sequence>0 &&
           SWV5_TestNear(authorization.authorized_projected_loss,current.projected.basket_risk_evidence.resulting_basket_maximum_loss,context.price_tolerance) &&
          SWV5_TestNear(authorization.authorized_projected_notional,current.projected.projected_notional,context.price_tolerance) &&
           SWV5_TestNear(authorization.authorized_projected_margin,current.projected.margin_evidence.additional_margin,context.price_tolerance) &&
          SWV5_TestMonetaryBasisEqual(authorization.monetary_basis,current.projected.monetary_basis,context) &&
          authorization.hard_kill_latch_id==current.hard_kill_state.latch_id && authorization.hard_kill_latch_id!="" &&
          authorization.hard_kill_latch_generation==current.hard_kill_state.latch_generation &&
          authorization.hard_kill_latch_generation>0 &&
          authorization.evaluated_at>0 && authorization.evaluated_at<=context.clock_time &&
          authorization.evaluated_at>=current.account.observed_at &&
          authorization.evaluated_at>=current.exposure.observed_at &&
          authorization.evaluated_at>=current.basket.observed_at &&
          authorization.evaluated_at>=current.projected.calculated_at &&
          authorization.evaluated_at>=current.projected.monetary_basis.valuation_at &&
          authorization.expires_at==expected_expiry && authorization.expires_at>=context.clock_time;
}

bool SWV5_TestHardKillReleaseValid(const SWV5_ContractValidationContext &context,
                                   const SWV5_HardKillState &state,
                                   const SWV5_HardKillReleaseEvidence &evidence,
                                   const SWV5_HardKillReleaseValidationMode mode)
{
   const bool approving_component_valid=(evidence.approving_component==SWV5_COMPONENT_AUTHORITY_RISK_GOVERNANCE ||
                                         evidence.approving_component==SWV5_COMPONENT_AUTHORITY_OPERATOR);
   const bool namespace_valid=SWV5_TestExecutionNamespaceValid(context,state.persistence_namespace) &&
                              SWV5_TestExecutionNamespaceValid(context,evidence.persistence_namespace) &&
                              SWV5_TestNamespaceEqual(state.persistence_namespace,evidence.persistence_namespace) &&
                              SWV5_TestRiskAccountNamespaceComplete(context,state.account_namespace) &&
                              SWV5_TestRiskAccountNamespaceBelongsToPersistence(state.account_namespace,state.persistence_namespace) &&
                              SWV5_TestExecutionNamespaceValid(context,evidence.broker_evidence.persistence_namespace) &&
                              SWV5_TestNamespaceEqual(evidence.broker_evidence.persistence_namespace,evidence.persistence_namespace) &&
                              SWV5_TestExecutionNamespaceValid(context,evidence.persistence_evidence.persistence_namespace) &&
                              SWV5_TestNamespaceEqual(evidence.persistence_evidence.persistence_namespace,evidence.persistence_namespace);
   const bool versions_valid=SWV5_TestRiskVersionExact(context,state.contract_version) &&
                             SWV5_TestRiskVersionExact(context,evidence.contract_version) &&
                             SWV5_TestRiskVersionExact(context,evidence.broker_evidence.contract_version) &&
                             SWV5_TestRiskVersionExact(context,evidence.persistence_evidence.contract_version) &&
                             SWV5_TestRiskVersionExact(context,evidence.exposure_evidence.contract_version);
   const bool historical=(mode==SWV5_HARD_KILL_RELEASE_HISTORICAL_PERSISTED);
   const bool current=(mode==SWV5_HARD_KILL_RELEASE_CURRENT_EXECUTION);
   const bool times_valid=evidence.operator_identity.authenticated_at>0 &&
                          evidence.broker_evidence.observed_at>=evidence.operator_identity.authenticated_at &&
                          evidence.persistence_evidence.observed_at>=evidence.operator_identity.authenticated_at &&
                          evidence.exposure_evidence.observed_at>=evidence.operator_identity.authenticated_at &&
                          evidence.broker_evidence.observed_at<=evidence.approved_at &&
                          evidence.persistence_evidence.observed_at<=evidence.approved_at &&
                          evidence.exposure_evidence.observed_at<=evidence.approved_at &&
                           evidence.approved_at>0 && evidence.approved_at<=evidence.released_at &&
                           evidence.released_at<evidence.expires_at &&
                           ((current && evidence.released_at<=context.clock_time && context.clock_time<evidence.expires_at) ||
                            (historical && evidence.released_at<=context.clock_time));
   return SWV5_TestContextValid(context) && versions_valid && namespace_valid &&
           (current || historical) &&
           ((current && state.state==SWV5_HARD_KILL_RELEASE_PENDING && evidence.release_generation==state.release_generation+1) ||
            (historical && state.state==SWV5_HARD_KILL_RELEASED && evidence.release_generation==state.release_generation)) &&
           state.latch_id!="" && state.latch_generation>0 &&
           evidence.release_id!="" && evidence.latch_id==state.latch_id && evidence.latch_generation==state.latch_generation &&
           evidence.approval_policy_id=="HARD-KILL-RELEASE-V5" && evidence.approval_sequence>0 &&
           evidence.operator_identity.operator_id!="" && evidence.operator_identity.authority_role!="" &&
          evidence.operator_identity.authentication_reference!="" && approving_component_valid && times_valid &&
          evidence.broker_evidence.evidence_id!="" && evidence.broker_evidence.state_digest!="" &&
          evidence.broker_evidence.issuing_component==SWV5_COMPONENT_AUTHORITY_BROKER_ADAPTER &&
          evidence.broker_evidence.authority_source==SWV5_AUTHORITY_LIVE_BROKER_STATE &&
          evidence.broker_evidence.evidence_sequence>0 &&
          evidence.persistence_evidence.evidence_id!="" && evidence.persistence_evidence.state_digest!="" &&
          evidence.persistence_evidence.issuing_component==SWV5_COMPONENT_AUTHORITY_PERSISTENCE &&
          evidence.persistence_evidence.authority_source==SWV5_AUTHORITY_PERSISTED_CHECKPOINT &&
          evidence.persistence_evidence.evidence_sequence>0 &&
          evidence.exposure_evidence.evidence_id!="" && evidence.exposure_evidence.zero_or_reducing &&
          evidence.exposure_evidence.issuing_component==SWV5_COMPONENT_AUTHORITY_RISK_GOVERNANCE &&
          evidence.exposure_evidence.authority_source==SWV5_AUTHORITY_LIVE_BROKER_STATE &&
          evidence.exposure_evidence.evidence_sequence>0 &&
          SWV5_IsFiniteNumber(evidence.exposure_evidence.observed_exposure_volume) &&
          SWV5_IsFiniteNumber(evidence.exposure_evidence.prior_exposure_volume) &&
          evidence.exposure_evidence.observed_exposure_volume>=0.0 && evidence.exposure_evidence.prior_exposure_volume>=0.0 &&
           evidence.exposure_evidence.observed_exposure_volume<=evidence.exposure_evidence.prior_exposure_volume+context.volume_tolerance &&
           evidence.release_record_sequence>0 && evidence.audit_reference!="" &&
           evidence.release_record_digest==SWV5_TestHardKillReleaseDigest(evidence);
}

bool SWV5_TestHistoricalHardKillReleaseValid(const SWV5_ContractValidationContext &context,
                                   const SWV5_HardKillState &state,
                                   const SWV5_HardKillReleaseEvidence &checkpoint_evidence,
                                   const SWV5_HardKillReleaseAuthorityRecord &record)
{
   const SWV5_HardKillReleaseAuthorityReference reference=state.release_authority_reference;
   const bool record_integrity=SWV5_TestVersionValid(record.contract_version) &&
                               SWV5_TestNamespaceEqual(record.persistence_namespace,state.persistence_namespace) &&
                               SWV5_TestAccountNamespaceEqual(record.account_namespace,state.account_namespace) &&
                               record.authority_record_id!="" && record.release_record_sequence>0 &&
                               record.authority_record_digest==SWV5_TestHardKillAuthorityRecordDigest(record) &&
                               record.issuing_component==SWV5_COMPONENT_AUTHORITY_RISK_GOVERNANCE &&
                               record.authority_source==SWV5_AUTHORITY_HARD_KILL_RELEASE_RECORD;
   const bool reference_binding=SWV5_TestVersionEqual(reference.contract_version,record.contract_version) &&
                                reference.authority_record_id==record.authority_record_id &&
                                reference.authority_record_sequence==record.release_record_sequence &&
                                reference.authority_record_digest==record.authority_record_digest &&
                                reference.release_id==record.release_id &&
                                reference.latch_generation==record.latch_generation &&
                                reference.release_generation==record.release_generation;
   const bool state_binding=record.latch_id==state.latch_id && record.latch_generation==state.latch_generation &&
                            record.release_id==checkpoint_evidence.release_id &&
                            record.release_generation==state.release_generation &&
                            record.release_generation==checkpoint_evidence.release_generation;
   const bool authority_binding=SWV5_TestCanonicalOperator(record.operator_identity)==SWV5_TestCanonicalOperator(checkpoint_evidence.operator_identity) &&
                                record.approving_component==checkpoint_evidence.approving_component &&
                                record.approval_policy_id==checkpoint_evidence.approval_policy_id &&
                                record.approval_sequence==checkpoint_evidence.approval_sequence &&
                                SWV5_TestCanonicalTypedReconciliation(record.broker_evidence_reference)==SWV5_TestCanonicalTypedReconciliation(checkpoint_evidence.broker_evidence) &&
                                SWV5_TestCanonicalTypedReconciliation(record.persistence_evidence_reference)==SWV5_TestCanonicalTypedReconciliation(checkpoint_evidence.persistence_evidence) &&
                                SWV5_TestCanonicalExposureEvidence(record.exposure_evidence_reference)==SWV5_TestCanonicalExposureEvidence(checkpoint_evidence.exposure_evidence) &&
                                record.approved_at==checkpoint_evidence.approved_at &&
                                record.released_at==checkpoint_evidence.released_at &&
                                record.expires_at==checkpoint_evidence.expires_at &&
                                record.release_record_sequence==checkpoint_evidence.release_record_sequence;
   return record_integrity && reference_binding && state_binding && authority_binding &&
          SWV5_TestHardKillReleaseValid(context,state,checkpoint_evidence,SWV5_HARD_KILL_RELEASE_HISTORICAL_PERSISTED);
}

bool SWV5_TestHardKillReleaseValid(const SWV5_ContractValidationContext &context,
                                   const SWV5_HardKillState &state,
                                   const SWV5_HardKillReleaseEvidence &evidence)
{
   return SWV5_TestHardKillReleaseValid(context,state,evidence,SWV5_HARD_KILL_RELEASE_CURRENT_EXECUTION);
}

bool SWV5_TestDealValid(const SWV5_AuthoritativeDeal &deal,const SWV5_StatisticsBuildContext &context)
{
   return SWV5_TestVersionValid(deal.contract_version) &&
          SWV5_TestNamespaceEqual(deal.persistence_namespace,context.persistence_namespace) &&
          SWV5_TestCorrelationComplete(deal.correlation) && deal.authority==SWV5_AUTHORITY_DEAL_HISTORY &&
          deal.volume>0.0 && deal.price>0.0 && deal.account_currency!="" &&
          deal.monetary_components_complete && context.account_mode==SWV5_ACCOUNT_MODE_HEDGING &&
          SWV5_TestQueriesComplete(context.history_queries);
}

bool SWV5_TestDedupEvidenceValid(const SWV5_StatisticsDeduplicationEvidence &evidence,
                                 const SWV5_StatisticsDeduplicationState &state)
{
   if(state.identities.fingerprint_policy!=SWV5_DURABLE_FINGERPRINT_IDENTITY_ONLY ||
      !SWV5_TestEventSetIntegrityValid(state.identities) ||
      evidence.prior_identity_index_revision!=state.identities.index_revision)
      return false;
   if(evidence.disposition==SWV5_STAT_IDENTITY_DUPLICATE)
      return evidence.membership_proof!="" && SWV5_TestEventIdentitySetContains(state.identities,evidence.correlation.broker_identity);
   if(evidence.disposition==SWV5_STAT_IDENTITY_NEW || evidence.disposition==SWV5_STAT_IDENTITY_OUT_OF_ORDER_NEW)
      return evidence.membership_proof=="" && SWV5_TestCorrelationComplete(evidence.correlation);
   return false;
}

double SWV5_TestDealNet(const SWV5_AuthoritativeDeal &deal)
{
   return deal.gross_profit+deal.commission+deal.swap+deal.fee;
}

#endif
