//+------------------------------------------------------------------+
//| TEST ONLY                                                        |
//| NOT FOR PRODUCTION                                               |
//| NO BROKER ACCESS                                                 |
//| Deterministic LP1 decoder used only for reconstructive tests.    |
//+------------------------------------------------------------------+
#ifndef SW_V5_CANONICAL_DECODER_MQH
#define SW_V5_CANONICAL_DECODER_MQH

class SWV5_TestCanonicalReader
{
private:
   string m_text;
   int    m_offset;

public:
   void Init(const string text) { m_text=text; m_offset=0; }
   bool AtEnd() const { return m_offset==StringLen(m_text); }

   bool ReadRaw(const string name,const string type,string &value)
   {
      const string prefix=name+":"+type+":";
      if(StringSubstr(m_text,m_offset,StringLen(prefix))!=prefix) return false;
      int cursor=m_offset+StringLen(prefix);
      const int total=StringLen(m_text);
      const int first=cursor;
      while(cursor<total)
      {
         const ushort character=StringGetCharacter(m_text,cursor);
         if(character==58) break;
         if(character<48 || character>57) return false;
         cursor++;
      }
      if(cursor==first || cursor>=total) return false;
      const string length_text=StringSubstr(m_text,first,cursor-first);
      if(StringLen(length_text)>1 && StringGetCharacter(length_text,0)==48) return false;
      const long declared=StringToInteger(length_text);
      if(declared<0 || declared>2147483647) return false;
      const int payload_start=cursor+1;
      if(declared>(long)(total-payload_start)) return false;
      value=StringSubstr(m_text,payload_start,(int)declared);
      m_offset=payload_start+(int)declared;
      return true;
   }

   bool ReadString(const string name,string &value) { return ReadRaw(name,"s",value); }
   bool ReadNested(const string name,string &value) { return ReadRaw(name,"x",value); }

   bool ReadInteger(const string name,long &value)
   {
      string raw;
      if(!ReadRaw(name,"i",raw) || raw=="") return false;
      value=StringToInteger(raw);
      return IntegerToString(value)==raw;
   }

   bool ReadUnsigned(const string name,ulong &value)
   {
      string raw;
      if(!ReadRaw(name,"u",raw) || raw=="" || StringGetCharacter(raw,0)==45) return false;
      const long parsed=StringToInteger(raw);
      if(parsed<0) return false;
      value=(ulong)parsed;
      return StringFormat("%I64u",value)==raw;
   }

   bool ReadUnsigned(const string name,uint &value)
   {
      ulong parsed=0;
      if(!ReadUnsigned(name,parsed) || parsed>4294967295) return false;
      value=(uint)parsed;
      return true;
   }

   bool ReadDouble(const string name,double &value)
   {
      string raw;
      if(!ReadRaw(name,"d",raw) || raw=="") return false;
      value=StringToDouble(raw);
      if(!MathIsValidNumber(value)) return false;
      const double normalized=(MathAbs(value)<0.00000000000000005 ? 0.0 : value);
      return DoubleToString(normalized,16)==raw;
   }

   bool ReadBool(const string name,bool &value)
   {
      string raw;
      if(!ReadRaw(name,"b",raw) || (raw!="0" && raw!="1")) return false;
      value=(raw=="1");
      return true;
   }
};

bool SWV5_TestDecodeVersionText(const string text,SWV5_ContractVersion &value)
{
   ZeroMemory(value);
   SWV5_TestCanonicalReader reader; reader.Init(text);
   long schema=0,minimum=0;
   if(!reader.ReadString("contract_name",value.contract_name) ||
      !reader.ReadInteger("schema_version",schema) ||
      !reader.ReadInteger("minimum_compatible_version",minimum) ||
      !reader.ReadString("policy_id",value.policy_id) || !reader.AtEnd()) return false;
   value.schema_version=(int)schema;
   value.minimum_compatible_version=(int)minimum;
   return value.contract_name==SWV5_PRODUCTION_CONTRACT_NAME &&
          value.schema_version==SWV5_PRODUCTION_CONTRACT_VERSION &&
          value.minimum_compatible_version==SWV5_PRODUCTION_MINIMUM_COMPATIBLE_VERSION &&
          value.policy_id==SWV5_PRODUCTION_CONTRACT_POLICY;
}

bool SWV5_TestDecodeVersion(SWV5_TestCanonicalReader &reader,const string name,SWV5_ContractVersion &value)
{
   string nested; return reader.ReadNested(name,nested) && SWV5_TestDecodeVersionText(nested,value);
}

bool SWV5_TestDecodeKeyText(const string text,SWV5_OwnershipKey &value)
{
   ZeroMemory(value); SWV5_TestCanonicalReader r; r.Init(text);
   return r.ReadInteger("account_login",value.account_login) && r.ReadString("broker_identity",value.broker_identity) &&
          r.ReadString("server",value.server) && r.ReadString("symbol",value.symbol) &&
          r.ReadString("strategy_id",value.strategy_id) && r.ReadUnsigned("magic",value.magic) && r.AtEnd();
}

bool SWV5_TestDecodeKey(SWV5_TestCanonicalReader &r,const string name,SWV5_OwnershipKey &value)
{ string nested; return r.ReadNested(name,nested) && SWV5_TestDecodeKeyText(nested,value); }

bool SWV5_TestDecodeOwnerText(const string text,SWV5_OwnerIdentity &value)
{
   ZeroMemory(value); SWV5_TestCanonicalReader r; r.Init(text);
   return SWV5_TestDecodeKey(r,"key",value.key) && r.ReadString("instance_id",value.instance_id) &&
          r.ReadString("process_fingerprint",value.process_fingerprint) && r.ReadInteger("started_at",value.started_at) && r.AtEnd();
}

bool SWV5_TestDecodeOwner(SWV5_TestCanonicalReader &r,const string name,SWV5_OwnerIdentity &value)
{ string nested; return r.ReadNested(name,nested) && SWV5_TestDecodeOwnerText(nested,value); }

bool SWV5_TestDecodeFenceText(const string text,SWV5_OwnershipFence &value)
{
   ZeroMemory(value); SWV5_TestCanonicalReader r; r.Init(text);
   return SWV5_TestDecodeVersion(r,"contract_version",value.contract_version) &&
          SWV5_TestDecodeKey(r,"ownership_namespace",value.ownership_namespace) &&
          SWV5_TestDecodeOwner(r,"owner",value.owner) && r.ReadUnsigned("lease_version",value.lease_version) &&
          r.ReadUnsigned("takeover_generation",value.takeover_generation) &&
          r.ReadString("fencing_token_digest",value.fencing_token_digest) && r.AtEnd();
}

bool SWV5_TestDecodeFence(SWV5_TestCanonicalReader &r,const string name,SWV5_OwnershipFence &value)
{ string nested; return r.ReadNested(name,nested) && SWV5_TestDecodeFenceText(nested,value); }

bool SWV5_TestDecodeNamespaceText(const string text,SWV5_PersistenceNamespace &value)
{
   ZeroMemory(value); SWV5_TestCanonicalReader r; r.Init(text);
   return SWV5_TestDecodeVersion(r,"contract_version",value.contract_version) &&
          SWV5_TestDecodeKey(r,"ownership_namespace",value.ownership_namespace) &&
          r.ReadString("basket_id",value.basket_id.value) && r.AtEnd();
}

bool SWV5_TestDecodeNamespace(SWV5_TestCanonicalReader &r,const string name,SWV5_PersistenceNamespace &value)
{ string nested; return r.ReadNested(name,nested) && SWV5_TestDecodeNamespaceText(nested,value); }

bool SWV5_TestDecodeRequestIdentityText(const string text,SWV5_ExecutionRequestIdentity &value)
{
   ZeroMemory(value); SWV5_TestCanonicalReader r; r.Init(text);
   return SWV5_TestDecodeVersion(r,"contract_version",value.contract_version) &&
          r.ReadString("correlation_id",value.request_id.correlation_id) &&
          r.ReadString("attempt_id",value.request_id.attempt_id) &&
          r.ReadString("parent_attempt_id",value.request_id.parent_attempt_id) &&
          r.ReadUnsigned("monotonic_sequence",value.request_id.monotonic_sequence) &&
          r.ReadInteger("created_at",value.request_id.created_at) &&
          r.ReadString("idempotency_key",value.idempotency_key) && r.AtEnd();
}

bool SWV5_TestDecodeRequestIdentity(SWV5_TestCanonicalReader &r,const string name,SWV5_ExecutionRequestIdentity &value)
{ string nested; return r.ReadNested(name,nested) && SWV5_TestDecodeRequestIdentityText(nested,value); }

bool SWV5_TestDecodeBrokerIdentityText(const string text,SWV5_BrokerExecutionIdentity &value)
{
   ZeroMemory(value); SWV5_TestCanonicalReader r; r.Init(text);
   return SWV5_TestDecodeVersion(r,"contract_version",value.contract_version) &&
          r.ReadUnsigned("order_ticket",value.order_ticket) && r.ReadUnsigned("deal_ticket",value.deal_ticket) &&
          r.ReadUnsigned("position_identifier",value.position_identifier) &&
          r.ReadString("broker_event_id",value.broker_event_id) &&
          r.ReadUnsigned("transaction_sequence",value.transaction_sequence) && r.AtEnd();
}

bool SWV5_TestDecodeBrokerIdentity(SWV5_TestCanonicalReader &r,const string name,SWV5_BrokerExecutionIdentity &value)
{ string nested; return r.ReadNested(name,nested) && SWV5_TestDecodeBrokerIdentityText(nested,value); }

bool SWV5_TestDecodeCorrelationText(const string text,SWV5_ExecutionCorrelation &value)
{
   ZeroMemory(value); SWV5_TestCanonicalReader r; r.Init(text); long phase=0;
   if(!SWV5_TestDecodeVersion(r,"contract_version",value.contract_version) || !r.ReadInteger("phase",phase) ||
      !SWV5_TestDecodeRequestIdentity(r,"request_identity",value.request_identity) ||
      !SWV5_TestDecodeBrokerIdentity(r,"broker_identity",value.broker_identity) || !r.AtEnd()) return false;
   value.phase=(SWV5_ExecutionLifecyclePhase)phase; return true;
}

bool SWV5_TestDecodeCorrelation(SWV5_TestCanonicalReader &r,const string name,SWV5_ExecutionCorrelation &value)
{ string nested; return r.ReadNested(name,nested) && SWV5_TestDecodeCorrelationText(nested,value); }

bool SWV5_TestDecodeQueriesText(const string text,SWV5_AuthoritativeQuerySet &value)
{
   ZeroMemory(value); SWV5_TestCanonicalReader r; r.Init(text); long component=0,source=0;
   if(!SWV5_TestDecodeVersion(r,"contract_version",value.contract_version) ||
      !r.ReadUnsigned("required_flags",value.required_flags) || !r.ReadUnsigned("completed_flags",value.completed_flags) ||
      !r.ReadUnsigned("authoritative_flags",value.authoritative_flags) ||
      !r.ReadUnsigned("observation_sequence",value.observation_sequence) ||
      !r.ReadInteger("observed_at",value.observed_at) || !r.ReadInteger("issuing_component",component) ||
      !r.ReadInteger("authority_source",source) || !r.ReadString("snapshot_id",value.snapshot_id) ||
      !r.ReadString("snapshot_digest",value.snapshot_digest) || !r.AtEnd()) return false;
   value.issuing_component=(SWV5_ComponentAuthority)component;
   value.authority_source=(SWV5_AuthoritySource)source;
   return value.snapshot_digest==SWV5_TestQuerySnapshotDigest(value);
}

bool SWV5_TestDecodeQueries(SWV5_TestCanonicalReader &r,const string name,SWV5_AuthoritativeQuerySet &value)
{ string nested; return r.ReadNested(name,nested) && SWV5_TestDecodeQueriesText(nested,value); }

bool SWV5_TestDecodeAcceptedQueryWatermarkProposal(const string text,SWV5_AcceptedQueryWatermarkProposal &value)
{
   ZeroMemory(value); SWV5_TestCanonicalReader r; r.Init(text);
   if(!SWV5_TestDecodeVersion(r,"contract_version",value.contract_version) ||
      !SWV5_TestDecodeNamespace(r,"persistence_namespace",value.persistence_namespace) ||
      !SWV5_TestDecodeFence(r,"ownership_fence",value.ownership_fence) ||
      !r.ReadString("expected_store_revision",value.expected_store_revision) ||
      !r.ReadUnsigned("expected_record_sequence",value.expected_record_sequence) ||
      !r.ReadUnsigned("accepted_broker_query_high_watermark",value.accepted_broker_query_high_watermark) ||
      !r.ReadUnsigned("accepted_execution_query_high_watermark",value.accepted_execution_query_high_watermark) ||
      !r.ReadUnsigned("broker_snapshot_observation_sequence",value.broker_snapshot_observation_sequence) ||
      !r.ReadUnsigned("execution_snapshot_observation_sequence",value.execution_snapshot_observation_sequence) ||
      !r.ReadUnsigned("next_reconciliation_revision",value.next_reconciliation_revision) ||
      !r.ReadString("proposal_digest",value.proposal_digest) || !r.AtEnd()) return false;
   return value.proposal_digest==SWV5_TestAcceptedQueryWatermarkProposalDigest(value);
}

bool SWV5_TestDecodeAccountNamespaceText(const string text,SWV5_AccountRiskNamespace &value)
{
   ZeroMemory(value); SWV5_TestCanonicalReader r; r.Init(text); long mode=0,source=0;
   if(!SWV5_TestDecodeVersion(r,"contract_version",value.contract_version) ||
      !r.ReadString("broker_identity",value.broker_identity) || !r.ReadString("server",value.server) ||
      !r.ReadInteger("account_login",value.account_login) || !r.ReadString("account_currency",value.account_currency) ||
      !r.ReadString("strategy_id",value.strategy_id) || !r.ReadUnsigned("magic",value.magic) ||
      !r.ReadInteger("account_mode",mode) || !r.ReadInteger("authoritative_source",source) ||
      !r.ReadUnsigned("snapshot_epoch",value.snapshot_epoch) ||
      !r.ReadUnsigned("snapshot_sequence",value.snapshot_sequence) || !r.AtEnd()) return false;
   value.account_mode=(SWV5_AccountPositionMode)mode; value.authoritative_source=(SWV5_AuthoritySource)source; return true;
}

bool SWV5_TestDecodeAccountNamespace(SWV5_TestCanonicalReader &r,const string name,SWV5_AccountRiskNamespace &value)
{ string nested; return r.ReadNested(name,nested) && SWV5_TestDecodeAccountNamespaceText(nested,value); }

bool SWV5_TestDecodeMonetaryBasisText(const string text,SWV5_RiskMonetaryBasis &value)
{
   ZeroMemory(value); SWV5_TestCanonicalReader r; r.Init(text); long basis=0,sign=0;
   if(!SWV5_TestDecodeVersion(r,"contract_version",value.contract_version) || !r.ReadString("currency",value.currency) ||
      !r.ReadString("account_currency",value.account_currency) ||
      !r.ReadDouble("conversion_rate_to_account_currency",value.conversion_rate_to_account_currency) ||
      !r.ReadString("conversion_source",value.conversion_source) || !r.ReadInteger("valuation_at",value.valuation_at) ||
      !r.ReadInteger("calculation_basis",basis) || !r.ReadInteger("sign_convention",sign) ||
      !r.ReadBool("includes_realized",value.includes_realized) || !r.ReadBool("includes_unrealized",value.includes_unrealized) ||
      !r.ReadBool("includes_commission",value.includes_commission) || !r.ReadBool("includes_swap",value.includes_swap) ||
      !r.ReadBool("includes_fee",value.includes_fee) || !r.AtEnd()) return false;
   value.calculation_basis=(SWV5_RiskCalculationBasis)basis; value.sign_convention=(SWV5_RiskSignConvention)sign; return true;
}

bool SWV5_TestDecodeMonetaryBasis(SWV5_TestCanonicalReader &r,const string name,SWV5_RiskMonetaryBasis &value)
{ string nested; return r.ReadNested(name,nested) && SWV5_TestDecodeMonetaryBasisText(nested,value); }

bool SWV5_TestDecodeTypedReconciliationText(const string text,SWV5_TypedReconciliationEvidence &value)
{
   ZeroMemory(value); SWV5_TestCanonicalReader r; r.Init(text); long component=0,source=0;
   if(!SWV5_TestDecodeVersion(r,"contract_version",value.contract_version) ||
      !SWV5_TestDecodeNamespace(r,"persistence_namespace",value.persistence_namespace) ||
      !r.ReadString("evidence_id",value.evidence_id) || !r.ReadInteger("issuing_component",component) ||
      !r.ReadInteger("authority_source",source) || !r.ReadUnsigned("evidence_sequence",value.evidence_sequence) ||
      !r.ReadInteger("observed_at",value.observed_at) || !r.ReadString("state_digest",value.state_digest) || !r.AtEnd()) return false;
   value.issuing_component=(SWV5_ComponentAuthority)component; value.authority_source=(SWV5_AuthoritySource)source; return true;
}

bool SWV5_TestDecodeTypedReconciliation(SWV5_TestCanonicalReader &r,const string name,SWV5_TypedReconciliationEvidence &value)
{ string nested; return r.ReadNested(name,nested) && SWV5_TestDecodeTypedReconciliationText(nested,value); }

bool SWV5_TestDecodeExposureText(const string text,SWV5_ExposureReductionEvidence &value)
{
   ZeroMemory(value); SWV5_TestCanonicalReader r; r.Init(text); long component=0,source=0;
   if(!SWV5_TestDecodeVersion(r,"contract_version",value.contract_version) || !r.ReadString("evidence_id",value.evidence_id) ||
      !r.ReadInteger("issuing_component",component) || !r.ReadInteger("authority_source",source) ||
      !r.ReadDouble("observed_exposure_volume",value.observed_exposure_volume) ||
      !r.ReadDouble("prior_exposure_volume",value.prior_exposure_volume) ||
      !r.ReadBool("zero_or_reducing",value.zero_or_reducing) ||
      !r.ReadUnsigned("evidence_sequence",value.evidence_sequence) || !r.ReadInteger("observed_at",value.observed_at) || !r.AtEnd()) return false;
   value.issuing_component=(SWV5_ComponentAuthority)component; value.authority_source=(SWV5_AuthoritySource)source; return true;
}

bool SWV5_TestDecodeExposure(SWV5_TestCanonicalReader &r,const string name,SWV5_ExposureReductionEvidence &value)
{ string nested; return r.ReadNested(name,nested) && SWV5_TestDecodeExposureText(nested,value); }

bool SWV5_TestDecodeOperatorText(const string text,SWV5_OperatorIdentity &value)
{
   ZeroMemory(value); SWV5_TestCanonicalReader r; r.Init(text);
   return r.ReadString("operator_id",value.operator_id) && r.ReadString("authority_role",value.authority_role) &&
          r.ReadString("authentication_reference",value.authentication_reference) &&
          r.ReadInteger("authenticated_at",value.authenticated_at) && r.AtEnd();
}

bool SWV5_TestDecodeOperator(SWV5_TestCanonicalReader &r,const string name,SWV5_OperatorIdentity &value)
{ string nested; return r.ReadNested(name,nested) && SWV5_TestDecodeOperatorText(nested,value); }

bool SWV5_TestDecodeMarginEvidence(const string text,SWV5_MarginProjectionEvidence &value)
{
   ZeroMemory(value); SWV5_TestCanonicalReader r; r.Init(text); long intent=0,direction=0,component=0,source=0;
   if(!SWV5_TestDecodeVersion(r,"contract_version",value.contract_version) ||
      !SWV5_TestDecodeNamespace(r,"persistence_namespace",value.persistence_namespace) ||
      !SWV5_TestDecodeAccountNamespace(r,"account_namespace",value.account_namespace) ||
      !SWV5_TestDecodeFence(r,"ownership_fence",value.ownership_fence) ||
      !SWV5_TestDecodeRequestIdentity(r,"request_identity",value.request_identity) ||
      !r.ReadString("basket_id",value.basket_id.value) || !r.ReadString("symbol",value.symbol) ||
      !r.ReadUnsigned("symbol_specification_sequence",value.symbol_specification_sequence) ||
      !r.ReadInteger("intent_type",intent) || !r.ReadInteger("direction",direction) ||
      !r.ReadDouble("requested_volume",value.requested_volume) || !r.ReadDouble("requested_price",value.requested_price) ||
      !r.ReadDouble("current_account_margin",value.current_account_margin) ||
      !r.ReadDouble("current_free_margin",value.current_free_margin) ||
      !r.ReadDouble("projected_account_margin",value.projected_account_margin) ||
      !r.ReadDouble("additional_margin",value.additional_margin) ||
      !r.ReadString("account_currency",value.account_currency) || !r.ReadInteger("issuing_component",component) ||
      !r.ReadInteger("authority_source",source) || !r.ReadString("calculation_reference",value.calculation_reference) ||
      !r.ReadInteger("observed_at",value.observed_at) || !r.ReadInteger("calculated_at",value.calculated_at) ||
      !r.ReadUnsigned("evidence_sequence",value.evidence_sequence) ||
       !r.ReadString("authority_record_id",value.authority_record_id) ||
       !r.ReadUnsigned("authority_record_sequence",value.authority_record_sequence) ||
       !r.ReadString("authority_record_digest",value.authority_record_digest) ||
       !r.ReadString("evidence_digest",value.evidence_digest) || !r.AtEnd()) return false;
   value.intent_type=(SWV5_ExecutionIntentType)intent; value.direction=(int)direction;
   value.issuing_component=(SWV5_ComponentAuthority)component; value.authority_source=(SWV5_AuthoritySource)source;
   return value.evidence_digest==SWV5_TestMarginEvidenceDigest(value);
}

bool SWV5_TestDecodeBasketRiskEvidence(const string text,SWV5_BasketRiskProjectionEvidence &value)
{
   ZeroMemory(value); SWV5_TestCanonicalReader r; r.Init(text); long component=0,source=0;
   if(!SWV5_TestDecodeVersion(r,"contract_version",value.contract_version) ||
      !SWV5_TestDecodeNamespace(r,"persistence_namespace",value.persistence_namespace) ||
      !SWV5_TestDecodeAccountNamespace(r,"account_namespace",value.account_namespace) ||
      !SWV5_TestDecodeFence(r,"ownership_fence",value.ownership_fence) ||
      !r.ReadString("basket_id",value.basket_id.value) || !r.ReadUnsigned("basket_state_version",value.basket_state_version) ||
      !SWV5_TestDecodeRequestIdentity(r,"request_identity",value.request_identity) || !r.ReadString("symbol",value.symbol) ||
      !r.ReadUnsigned("symbol_specification_sequence",value.symbol_specification_sequence) ||
      !r.ReadDouble("existing_bounded_basket_loss",value.existing_bounded_basket_loss) ||
      !r.ReadDouble("incremental_request_bounded_loss",value.incremental_request_bounded_loss) ||
      !r.ReadDouble("interaction_or_offset_adjustment",value.interaction_or_offset_adjustment) ||
      !r.ReadDouble("resulting_basket_maximum_loss",value.resulting_basket_maximum_loss) ||
      !r.ReadDouble("realized_loss_basis",value.realized_loss_basis) ||
      !r.ReadDouble("unrealized_loss_basis",value.unrealized_loss_basis) ||
      !r.ReadDouble("accrued_cost_basis",value.accrued_cost_basis) ||
      !SWV5_TestDecodeMonetaryBasis(r,"monetary_basis",value.monetary_basis) ||
      !r.ReadString("calculation_policy_id",value.calculation_policy_id) ||
      !r.ReadString("source_snapshot_digest",value.source_snapshot_digest) ||
      !r.ReadInteger("issuing_component",component) || !r.ReadInteger("authority_source",source) ||
      !r.ReadInteger("observed_at",value.observed_at) || !r.ReadInteger("calculated_at",value.calculated_at) ||
      !r.ReadUnsigned("evidence_sequence",value.evidence_sequence) ||
       !r.ReadString("authority_record_id",value.authority_record_id) ||
       !r.ReadUnsigned("authority_record_sequence",value.authority_record_sequence) ||
       !r.ReadString("authority_record_digest",value.authority_record_digest) ||
       !r.ReadString("evidence_digest",value.evidence_digest) || !r.AtEnd()) return false;
   value.issuing_component=(SWV5_ComponentAuthority)component; value.authority_source=(SWV5_AuthoritySource)source;
   return value.evidence_digest==SWV5_TestBasketRiskEvidenceDigest(value);
}

bool SWV5_TestDecodeBrokerSummary(const string text,SWV5_AuthoritativeBrokerSummary &value)
{
   ZeroMemory(value); SWV5_TestCanonicalReader r; r.Init(text); long mode=0,authority=0,authority_source=0;
   if(!SWV5_TestDecodeVersion(r,"contract_version",value.contract_version) ||
      !SWV5_TestDecodeNamespace(r,"persistence_namespace",value.persistence_namespace) ||
      !r.ReadDouble("symbol_long_volume",value.symbol_long_volume) || !r.ReadDouble("symbol_short_volume",value.symbol_short_volume) ||
      !r.ReadDouble("symbol_net_volume",value.symbol_net_volume) ||
      !r.ReadDouble("aggregate_position_volume",value.aggregate_position_volume) ||
      !r.ReadString("basket_id",value.basket_id.value) || !r.ReadDouble("basket_open_volume",value.basket_open_volume) ||
      !r.ReadDouble("residual_volume",value.residual_volume) || !r.ReadUnsigned("position_count",value.position_count) ||
      !r.ReadUnsigned("order_count",value.order_count) ||
      !SWV5_TestDecodeCorrelation(r,"latest_confirmed_correlation",value.latest_confirmed_correlation) ||
      !SWV5_TestDecodeBrokerIdentity(r,"latest_broker_event_identity",value.latest_broker_event_identity) ||
      !r.ReadUnsigned("transaction_high_watermark",value.transaction_high_watermark) ||
       !r.ReadUnsigned("observation_sequence",value.observation_sequence) || !r.ReadInteger("account_mode",mode) ||
       !SWV5_TestDecodeQueries(r,"queries",value.queries) || !r.ReadInteger("observed_at",value.observed_at) ||
       !r.ReadInteger("authority",authority) ||
       !r.ReadString("complete_summary_digest",value.complete_summary_digest) || !r.AtEnd()) return false;
   value.account_mode=(SWV5_AccountPositionMode)mode; value.authority=(SWV5_AuthoritySource)authority;
   return value.complete_summary_digest==SWV5_TestBrokerSummaryDigest(value);
}

bool SWV5_TestDecodeRestartRequestSummary(const string text,SWV5_AuthoritativeRestartRequestSummary &value)
{
   ZeroMemory(value); SWV5_TestCanonicalReader r; r.Init(text); long mode=0,authority=0,authority_source=0;
   if(!SWV5_TestDecodeVersion(r,"contract_version",value.contract_version) ||
      !SWV5_TestDecodeNamespace(r,"persistence_namespace",value.persistence_namespace) ||
      !r.ReadString("basket_id",value.basket_id.value) || !r.ReadInteger("account_mode",mode) ||
      !r.ReadUnsigned("pending_request_count",value.pending_request_count) ||
      !r.ReadString("request_set_digest",value.request_set_digest) ||
      !r.ReadString("request_set_revision",value.request_set_revision) ||
      !r.ReadUnsigned("reconciliation_revision",value.reconciliation_revision) ||
      !r.ReadUnsigned("observation_sequence",value.observation_sequence) ||
       !r.ReadInteger("observed_at",value.observed_at) || !r.ReadInteger("authority",authority) ||
       !r.ReadInteger("authority_source",authority_source) ||
       !SWV5_TestDecodeQueries(r,"pending_request_query",value.pending_request_query) ||
       !r.ReadString("complete_summary_digest",value.complete_summary_digest) || !r.AtEnd()) return false;
   value.account_mode=(SWV5_AccountPositionMode)mode; value.authority=(SWV5_ComponentAuthority)authority;
   value.authority_source=(SWV5_AuthoritySource)authority_source;
   return value.complete_summary_digest==SWV5_TestRestartRequestSummaryDigest(value);
}

bool SWV5_TestDecodeReconciliationVector(const string text,SWV5_PersistedReconciliationVector &value)
{
   ZeroMemory(value); SWV5_TestCanonicalReader r; r.Init(text); long mode=0,state=0;
   if(!SWV5_TestDecodeVersion(r,"contract_version",value.contract_version) ||
      !SWV5_TestDecodeNamespace(r,"persistence_namespace",value.persistence_namespace) ||
      !r.ReadString("basket_id",value.basket_id.value) || !r.ReadInteger("account_mode",mode) ||
      !r.ReadDouble("symbol_long_volume",value.symbol_long_volume) || !r.ReadDouble("symbol_short_volume",value.symbol_short_volume) ||
      !r.ReadDouble("symbol_net_volume",value.symbol_net_volume) ||
      !r.ReadDouble("aggregate_position_volume",value.aggregate_position_volume) ||
      !r.ReadDouble("basket_open_volume",value.basket_open_volume) || !r.ReadDouble("residual_volume",value.residual_volume) ||
      !r.ReadUnsigned("position_count",value.position_count) || !r.ReadUnsigned("order_count",value.order_count) ||
      !r.ReadUnsigned("pending_request_count",value.pending_request_count) ||
      !SWV5_TestDecodeCorrelation(r,"latest_confirmed_correlation",value.latest_confirmed_correlation) ||
      !SWV5_TestDecodeBrokerIdentity(r,"latest_broker_event_identity",value.latest_broker_event_identity) ||
      !r.ReadUnsigned("transaction_high_watermark",value.transaction_high_watermark) ||
      !r.ReadUnsigned("broker_query_sequence_high_watermark",value.broker_query_sequence_high_watermark) ||
      !r.ReadUnsigned("request_query_sequence_high_watermark",value.request_query_sequence_high_watermark) ||
      !r.ReadString("request_set_digest",value.request_set_digest) || !r.ReadString("request_set_revision",value.request_set_revision) ||
      !r.ReadInteger("basket_state",state) || !r.ReadUnsigned("basket_state_version",value.basket_state_version) ||
      !r.ReadUnsigned("hard_kill_generation",value.hard_kill_generation) ||
      !SWV5_TestDecodeFence(r,"ownership_fence",value.ownership_fence) ||
      !r.ReadUnsigned("reconciliation_revision",value.reconciliation_revision) ||
      !r.ReadString("source_summary_digest",value.source_summary_digest) || !r.AtEnd()) return false;
   value.account_mode=(SWV5_AccountPositionMode)mode; value.basket_state=(SWV5_BasketState)state; return true;
}

bool SWV5_TestDecodeHardKillRelease(const string text,SWV5_HardKillReleaseEvidence &value)
{
   ZeroMemory(value); SWV5_TestCanonicalReader r; r.Init(text); long component=0;
   if(!SWV5_TestDecodeVersion(r,"contract_version",value.contract_version) ||
      !SWV5_TestDecodeNamespace(r,"persistence_namespace",value.persistence_namespace) ||
      !r.ReadString("release_id",value.release_id) || !r.ReadString("latch_id",value.latch_id) ||
      !r.ReadUnsigned("latch_generation",value.latch_generation) || !r.ReadUnsigned("release_generation",value.release_generation) ||
      !r.ReadString("approval_policy_id",value.approval_policy_id) || !r.ReadUnsigned("approval_sequence",value.approval_sequence) ||
      !SWV5_TestDecodeOperator(r,"operator_identity",value.operator_identity) || !r.ReadInteger("approving_component",component) ||
      !SWV5_TestDecodeTypedReconciliation(r,"broker_evidence",value.broker_evidence) ||
      !SWV5_TestDecodeTypedReconciliation(r,"persistence_evidence",value.persistence_evidence) ||
       !SWV5_TestDecodeExposure(r,"exposure_evidence",value.exposure_evidence) ||
       !r.ReadInteger("approved_at",value.approved_at) || !r.ReadInteger("released_at",value.released_at) ||
       !r.ReadInteger("expires_at",value.expires_at) || !r.ReadUnsigned("release_record_sequence",value.release_record_sequence) ||
       !r.ReadString("audit_reference",value.audit_reference) ||
       !r.ReadString("release_record_digest",value.release_record_digest) || !r.AtEnd()) return false;
   value.approving_component=(SWV5_ComponentAuthority)component;
   return value.release_record_digest==SWV5_TestHardKillReleaseDigest(value);
}

bool SWV5_TestDecodeHardKillAuthorityRecord(const string text,SWV5_HardKillReleaseAuthorityRecord &value)
{
   ZeroMemory(value); SWV5_TestCanonicalReader r; r.Init(text); long approving=0,issuing=0,source=0;
   if(!SWV5_TestDecodeVersion(r,"contract_version",value.contract_version) ||
      !SWV5_TestDecodeNamespace(r,"persistence_namespace",value.persistence_namespace) ||
      !SWV5_TestDecodeAccountNamespace(r,"account_namespace",value.account_namespace) ||
      !r.ReadString("latch_id",value.latch_id) || !r.ReadUnsigned("latch_generation",value.latch_generation) ||
      !r.ReadString("release_id",value.release_id) || !r.ReadUnsigned("release_generation",value.release_generation) ||
      !SWV5_TestDecodeOperator(r,"operator_identity",value.operator_identity) || !r.ReadInteger("approving_component",approving) ||
      !r.ReadString("approval_policy_id",value.approval_policy_id) || !r.ReadUnsigned("approval_sequence",value.approval_sequence) ||
      !SWV5_TestDecodeTypedReconciliation(r,"broker_evidence_reference",value.broker_evidence_reference) ||
      !SWV5_TestDecodeTypedReconciliation(r,"persistence_evidence_reference",value.persistence_evidence_reference) ||
      !SWV5_TestDecodeExposure(r,"exposure_evidence_reference",value.exposure_evidence_reference) ||
      !r.ReadInteger("approved_at",value.approved_at) || !r.ReadInteger("released_at",value.released_at) ||
       !r.ReadInteger("expires_at",value.expires_at) || !r.ReadUnsigned("release_record_sequence",value.release_record_sequence) ||
       !r.ReadString("authority_record_id",value.authority_record_id) || !r.ReadInteger("issuing_component",issuing) ||
       !r.ReadInteger("authority_source",source) ||
       !r.ReadString("authority_record_digest",value.authority_record_digest) || !r.AtEnd()) return false;
   value.approving_component=(SWV5_ComponentAuthority)approving; value.issuing_component=(SWV5_ComponentAuthority)issuing;
   value.authority_source=(SWV5_AuthoritySource)source;
   return value.authority_record_digest==SWV5_TestHardKillAuthorityRecordDigest(value);
}

bool SWV5_TestDecodeDecisionText(const string text,SWV5_ContractDecision &value)
{
   ZeroMemory(value); SWV5_TestCanonicalReader r; r.Init(text); long disposition=0,schema=0;
   if(!SWV5_TestDecodeVersion(r,"contract_version",value.contract_version) || !r.ReadInteger("disposition",disposition) ||
      !r.ReadUnsigned("reason_flags",value.reason_flags) || !r.ReadString("reason_code",value.reason_code) ||
      !r.ReadString("reason_text",value.reason_text) || !r.ReadInteger("evaluated_schema_version",schema) ||
      !r.ReadUnsigned("evaluation_sequence",value.evaluation_sequence) || !r.ReadInteger("evaluated_at",value.evaluated_at) || !r.AtEnd()) return false;
   value.disposition=(SWV5_ContractDisposition)disposition; value.evaluated_schema_version=(int)schema; return true;
}

bool SWV5_TestDecodeDecision(SWV5_TestCanonicalReader &r,const string name,SWV5_ContractDecision &value)
{ string nested; return r.ReadNested(name,nested) && SWV5_TestDecodeDecisionText(nested,value); }

bool SWV5_TestDecodeIntentText(const string text,SWV5_ExecutionIntent &value)
{
   ZeroMemory(value); SWV5_TestCanonicalReader r; r.Init(text); long mode=0,intent=0,direction=0;
   if(!SWV5_TestDecodeVersion(r,"contract_version",value.contract_version) ||
      !SWV5_TestDecodeNamespace(r,"persistence_namespace",value.persistence_namespace) ||
      !SWV5_TestDecodeFence(r,"ownership_fence",value.ownership_fence) ||
      !SWV5_TestDecodeRequestIdentity(r,"request_identity",value.request_identity) ||
      !r.ReadInteger("account_mode",mode) || !r.ReadInteger("intent_type",intent) || !r.ReadInteger("direction",direction) ||
      !r.ReadDouble("normalized_volume",value.normalized_volume) || !r.ReadDouble("normalized_price",value.normalized_price) ||
      !r.ReadDouble("normalized_stop_price",value.normalized_stop_price) ||
      !r.ReadDouble("normalized_limit_price",value.normalized_limit_price) ||
      !r.ReadUnsigned("symbol_specification_sequence",value.symbol_specification_sequence) ||
      !r.ReadUnsigned("expected_basket_version",value.expected_basket_version) ||
      !r.ReadString("risk_authorization_id",value.risk_authorization_id) ||
      !r.ReadInteger("authorization_expires_at",value.authorization_expires_at) || !r.AtEnd()) return false;
   value.account_mode=(SWV5_AccountPositionMode)mode; value.intent_type=(SWV5_ExecutionIntentType)intent; value.direction=(int)direction; return true;
}

bool SWV5_TestDecodeIntent(SWV5_TestCanonicalReader &r,const string name,SWV5_ExecutionIntent &value)
{ string nested; return r.ReadNested(name,nested) && SWV5_TestDecodeIntentText(nested,value); }

bool SWV5_TestDecodeEventSetText(const string text,SWV5_DurableEventIdentitySet &value)
{
   ZeroMemory(value); SWV5_TestCanonicalReader r; r.Init(text); long policy=0;
   if(!SWV5_TestDecodeVersion(r,"contract_version",value.contract_version) || !r.ReadInteger("fingerprint_policy",policy) ||
      !r.ReadString("canonical_event_index",value.canonical_event_index) ||
      !r.ReadString("canonical_fingerprint_index",value.canonical_fingerprint_index) ||
      !r.ReadString("identity_set_digest",value.identity_set_digest) ||
      !r.ReadUnsigned("accepted_identity_count",value.accepted_identity_count) ||
      !r.ReadUnsigned("highest_transaction_sequence",value.highest_transaction_sequence) ||
      !r.ReadUnsigned("index_revision",value.index_revision) ||
      !r.ReadUnsigned("compaction_generation",value.compaction_generation) || !r.AtEnd()) return false;
   value.fingerprint_policy=(SWV5_DurableFingerprintPolicy)policy; return true;
}

bool SWV5_TestDecodeEventSet(SWV5_TestCanonicalReader &r,const string name,SWV5_DurableEventIdentitySet &value)
{ string nested; return r.ReadNested(name,nested) && SWV5_TestDecodeEventSetText(nested,value); }

bool SWV5_TestDecodeSubmissionText(const string text,SWV5_SubmissionEvidence &value)
{
   ZeroMemory(value); SWV5_TestCanonicalReader r; r.Init(text); long authority=0;
   if(!SWV5_TestDecodeVersion(r,"contract_version",value.contract_version) ||
      !SWV5_TestDecodeRequestIdentity(r,"request_identity",value.request_identity) ||
      !r.ReadUnsigned("submission_attempt_count",value.submission_attempt_count) ||
      !r.ReadInteger("submitted_at",value.submitted_at) || !r.ReadInteger("authority",authority) || !r.AtEnd()) return false;
   value.authority=(SWV5_AuthoritySource)authority; return true;
}

bool SWV5_TestDecodeSubmission(SWV5_TestCanonicalReader &r,const string name,SWV5_SubmissionEvidence &value)
{ string nested; return r.ReadNested(name,nested) && SWV5_TestDecodeSubmissionText(nested,value); }

bool SWV5_TestDecodeRetcodeText(const string text,SWV5_ResultRetcodeEvidence &value)
{
   ZeroMemory(value); SWV5_TestCanonicalReader r; r.Init(text);
   return SWV5_TestDecodeVersion(r,"contract_version",value.contract_version) &&
          SWV5_TestDecodeNamespace(r,"persistence_namespace",value.persistence_namespace) &&
          SWV5_TestDecodeFence(r,"ownership_fence",value.ownership_fence) &&
          SWV5_TestDecodeCorrelation(r,"correlation",value.correlation) && r.ReadUnsigned("raw_retcode",value.raw_retcode) &&
          r.ReadString("broker_comment",value.broker_comment) && r.ReadInteger("observed_at",value.observed_at) && r.AtEnd();
}

bool SWV5_TestDecodeRetcode(SWV5_TestCanonicalReader &r,const string name,SWV5_ResultRetcodeEvidence &value)
{ string nested; return r.ReadNested(name,nested) && SWV5_TestDecodeRetcodeText(nested,value); }

bool SWV5_TestDecodeClassificationText(const string text,SWV5_ResultRetcodeClassification &value)
{
   ZeroMemory(value); SWV5_TestCanonicalReader r; r.Init(text); long classification=0,retry=0;
   if(!SWV5_TestDecodeVersion(r,"contract_version",value.contract_version) || !r.ReadInteger("classification",classification) ||
      !r.ReadInteger("retry_disposition",retry) || !r.ReadString("mapping_policy_id",value.mapping_policy_id) ||
      !SWV5_TestDecodeDecision(r,"decision",value.decision) || !r.AtEnd()) return false;
   value.classification=(SWV5_ResultRetcodeClass)classification; value.retry_disposition=(SWV5_RetryDisposition)retry; return true;
}

bool SWV5_TestDecodeClassification(SWV5_TestCanonicalReader &r,const string name,SWV5_ResultRetcodeClassification &value)
{ string nested; return r.ReadNested(name,nested) && SWV5_TestDecodeClassificationText(nested,value); }

bool SWV5_TestDecodeAuthoritativeConfirmationText(const string text,SWV5_AuthoritativeConfirmationEvidence &value)
{
   ZeroMemory(value); SWV5_TestCanonicalReader r; r.Init(text); long status=0,authority=0;
   if(!SWV5_TestDecodeVersion(r,"contract_version",value.contract_version) ||
      !SWV5_TestDecodeCorrelation(r,"correlation",value.correlation) || !r.ReadInteger("status",status) ||
      !r.ReadDouble("cumulative_confirmed_volume",value.cumulative_confirmed_volume) ||
      !r.ReadDouble("residual_volume",value.residual_volume) || !r.ReadInteger("authority",authority) ||
      !r.ReadUnsigned("confirmation_sequence",value.confirmation_sequence) ||
      !r.ReadInteger("confirmed_at",value.confirmed_at) || !r.AtEnd()) return false;
   value.status=(SWV5_ConfirmationStatus)status; value.authority=(SWV5_AuthoritySource)authority; return true;
}

bool SWV5_TestDecodeAuthoritativeConfirmation(SWV5_TestCanonicalReader &r,const string name,SWV5_AuthoritativeConfirmationEvidence &value)
{ string nested; return r.ReadNested(name,nested) && SWV5_TestDecodeAuthoritativeConfirmationText(nested,value); }

bool SWV5_TestDecodePendingText(const string text,SWV5_PendingRequest &value)
{
   ZeroMemory(value); SWV5_TestCanonicalReader r; r.Init(text); long mode=0,phase=0,state=0,retry=0;
   if(!SWV5_TestDecodeVersion(r,"contract_version",value.contract_version) || !SWV5_TestDecodeIntent(r,"intent",value.intent) ||
      !r.ReadInteger("account_mode",mode) || !r.ReadInteger("lifecycle_phase",phase) || !r.ReadInteger("state",state) ||
      !r.ReadUnsigned("submission_attempt_count",value.submission_attempt_count) ||
      !SWV5_TestDecodeSubmission(r,"latest_submission",value.latest_submission) ||
      !SWV5_TestDecodeRetcode(r,"latest_retcode",value.latest_retcode) ||
      !SWV5_TestDecodeClassification(r,"latest_retcode_classification",value.latest_retcode_classification) ||
      !SWV5_TestDecodeAuthoritativeConfirmation(r,"latest_authoritative_confirmation",value.latest_authoritative_confirmation) ||
      !r.ReadDouble("cumulative_confirmed_volume",value.cumulative_confirmed_volume) ||
      !r.ReadDouble("residual_requested_volume",value.residual_requested_volume) ||
      !SWV5_TestDecodeEventSet(r,"accepted_event_identities",value.accepted_event_identities) ||
      !r.ReadInteger("retry_disposition",retry) || !r.ReadString("authorization_identity",value.authorization_identity) ||
      !r.ReadString("normalization_identity",value.normalization_identity) ||
      !r.ReadInteger("last_changed_at",value.last_changed_at) || !r.AtEnd()) return false;
   value.account_mode=(SWV5_AccountPositionMode)mode; value.lifecycle_phase=(SWV5_ExecutionLifecyclePhase)phase;
   value.state=(SWV5_PendingRequestState)state; value.retry_disposition=(SWV5_RetryDisposition)retry; return true;
}

bool SWV5_TestDecodePending(SWV5_TestCanonicalReader &r,const string name,SWV5_PendingRequest &value)
{ string nested; return r.ReadNested(name,nested) && SWV5_TestDecodePendingText(nested,value); }

bool SWV5_TestDecodePersistedRequestText(const string text,SWV5_PersistedRequestEvidence &value)
{
   ZeroMemory(value); SWV5_TestCanonicalReader r; r.Init(text); long mode=0;
   if(!SWV5_TestDecodeVersion(r,"contract_version",value.contract_version) ||
      !SWV5_TestDecodeNamespace(r,"persistence_namespace",value.persistence_namespace) ||
      !SWV5_TestDecodeFence(r,"ownership_fence",value.ownership_fence) ||
      !SWV5_TestDecodePending(r,"pending_request",value.pending_request) || !r.ReadInteger("account_mode",mode) ||
      !r.ReadUnsigned("record_sequence",value.record_sequence) || !r.ReadInteger("recorded_at",value.recorded_at) || !r.AtEnd()) return false;
   value.account_mode=(SWV5_AccountPositionMode)mode; return true;
}

bool SWV5_TestDecodePersistedRequest(SWV5_TestCanonicalReader &r,const string name,SWV5_PersistedRequestEvidence &value)
{ string nested; return r.ReadNested(name,nested) && SWV5_TestDecodePersistedRequestText(nested,value); }

bool SWV5_TestDecodeLifecycleText(const string text,SWV5_BasketLifecycleSnapshot &value)
{
   ZeroMemory(value); SWV5_TestCanonicalReader r; r.Init(text); long state=0,reconciliation=0;
   if(!SWV5_TestDecodeVersion(r,"contract_version",value.contract_version) || !r.ReadString("basket_id",value.basket_id.value) ||
      !SWV5_TestDecodeFence(r,"ownership_fence",value.ownership_fence) || !r.ReadInteger("state",state) ||
      !r.ReadUnsigned("state_version",value.state_version) ||
      !r.ReadUnsigned("cumulative_recovery_attempts",value.cumulative_recovery_attempts) ||
      !r.ReadUnsigned("current_recovery_layer",value.current_recovery_layer) ||
      !SWV5_TestDecodeEventSet(r,"accepted_recovery_evidence",value.accepted_recovery_evidence) ||
      !r.ReadDouble("aggregate_open_volume",value.aggregate_open_volume) || !r.ReadDouble("residual_volume",value.residual_volume) ||
      !r.ReadUnsigned("live_position_count",value.live_position_count) || !r.ReadUnsigned("live_order_count",value.live_order_count) ||
      !r.ReadUnsigned("pending_request_count",value.pending_request_count) || !r.ReadInteger("reconciliation_state",reconciliation) ||
      !SWV5_TestDecodeQueries(r,"broker_queries",value.broker_queries) ||
      !r.ReadInteger("state_entered_at",value.state_entered_at) || !r.AtEnd()) return false;
   value.state=(SWV5_BasketState)state; value.reconciliation_state=(SWV5_ReconciliationState)reconciliation; return true;
}

bool SWV5_TestDecodeLifecycle(SWV5_TestCanonicalReader &r,const string name,SWV5_BasketLifecycleSnapshot &value)
{ string nested; return r.ReadNested(name,nested) && SWV5_TestDecodeLifecycleText(nested,value); }

bool SWV5_TestDecodeBasketText(const string text,SWV5_BasketAggregate &value)
{
   ZeroMemory(value); SWV5_TestCanonicalReader r; r.Init(text); long mode=0,close=0;
   if(!SWV5_TestDecodeVersion(r,"contract_version",value.contract_version) ||
      !SWV5_TestDecodeNamespace(r,"persistence_namespace",value.persistence_namespace) || !r.ReadInteger("account_mode",mode) ||
      !SWV5_TestDecodeLifecycle(r,"lifecycle",value.lifecycle) || !r.ReadDouble("initial_volume",value.initial_volume) ||
      !r.ReadDouble("aggregate_closed_volume",value.aggregate_closed_volume) || !r.ReadInteger("close_verification",close) ||
      !r.ReadInteger("opened_at",value.opened_at) || !r.ReadInteger("updated_at",value.updated_at) || !r.AtEnd()) return false;
   value.account_mode=(SWV5_AccountPositionMode)mode; value.close_verification=(SWV5_CloseVerificationState)close; return true;
}

bool SWV5_TestDecodeBasket(SWV5_TestCanonicalReader &r,const string name,SWV5_BasketAggregate &value)
{ string nested; return r.ReadNested(name,nested) && SWV5_TestDecodeBasketText(nested,value); }

bool SWV5_TestDecodeRequestSetHeaderText(const string text,SWV5_PersistedRequestSetHeader &value)
{
   ZeroMemory(value); SWV5_TestCanonicalReader r; r.Init(text);
   return SWV5_TestDecodeVersion(r,"contract_version",value.contract_version) &&
          r.ReadUnsigned("request_count",value.request_count) && r.ReadString("request_set_digest",value.request_set_digest) &&
          r.ReadString("request_index_revision",value.request_index_revision) &&
          r.ReadUnsigned("record_sequence",value.record_sequence) && r.AtEnd();
}

bool SWV5_TestDecodeRequestSetHeader(SWV5_TestCanonicalReader &r,const string name,SWV5_PersistedRequestSetHeader &value)
{ string nested; return r.ReadNested(name,nested) && SWV5_TestDecodeRequestSetHeaderText(nested,value); }

bool SWV5_TestDecodeAuthorityReferenceText(const string text,SWV5_HardKillReleaseAuthorityReference &value)
{
   ZeroMemory(value); SWV5_TestCanonicalReader r; r.Init(text);
   return SWV5_TestDecodeVersion(r,"contract_version",value.contract_version) &&
          r.ReadString("authority_record_id",value.authority_record_id) &&
          r.ReadUnsigned("authority_record_sequence",value.authority_record_sequence) &&
          r.ReadString("authority_record_digest",value.authority_record_digest) && r.ReadString("release_id",value.release_id) &&
          r.ReadUnsigned("latch_generation",value.latch_generation) && r.ReadUnsigned("release_generation",value.release_generation) && r.AtEnd();
}

bool SWV5_TestDecodeAuthorityReference(SWV5_TestCanonicalReader &r,const string name,SWV5_HardKillReleaseAuthorityReference &value)
{ string nested; return r.ReadNested(name,nested) && SWV5_TestDecodeAuthorityReferenceText(nested,value); }

bool SWV5_TestDecodeHardKillText(const string text,SWV5_HardKillState &value)
{
   ZeroMemory(value); SWV5_TestCanonicalReader r; r.Init(text); long state=0; string release_text;
   if(!SWV5_TestDecodeVersion(r,"contract_version",value.contract_version) ||
      !SWV5_TestDecodeNamespace(r,"persistence_namespace",value.persistence_namespace) ||
      !SWV5_TestDecodeAccountNamespace(r,"account_namespace",value.account_namespace) ||
      !r.ReadString("latch_id",value.latch_id) || !r.ReadUnsigned("latch_generation",value.latch_generation) ||
      !r.ReadInteger("state",state) || !r.ReadString("activation_reason",value.activation_reason) ||
      !r.ReadInteger("activated_at",value.activated_at) || !r.ReadString("activation_authority",value.activation_authority) ||
      !r.ReadUnsigned("release_generation",value.release_generation) || !r.ReadNested("release_evidence",release_text) ||
      !SWV5_TestDecodeHardKillRelease(release_text,value.release_evidence) ||
      !SWV5_TestDecodeAuthorityReference(r,"release_authority_reference",value.release_authority_reference) || !r.AtEnd()) return false;
   value.state=(SWV5_HardKillLatchState)state;
   return true;
}

bool SWV5_TestDecodeHardKill(SWV5_TestCanonicalReader &r,const string name,SWV5_HardKillState &value)
{ string nested; return r.ReadNested(name,nested) && SWV5_TestDecodeHardKillText(nested,value); }

bool SWV5_TestDecodeCheckpoint(const string text,SWV5_PersistedCheckpoint &value)
{
   ZeroMemory(value); SWV5_TestCanonicalReader r; r.Init(text); string format;
   if(!r.ReadString("format",format) || format!="SWV5-CHECKPOINT-V5-LP2" ||
      !SWV5_TestDecodeVersion(r,"header_contract_version",value.header.contract_version) ||
      !SWV5_TestDecodeNamespace(r,"header_persistence_namespace",value.header.persistence_namespace) ||
      !SWV5_TestDecodeFence(r,"header_ownership_fence",value.header.ownership_fence) ||
      !r.ReadUnsigned("record_sequence",value.header.record_sequence) ||
      !r.ReadUnsigned("previous_record_sequence",value.header.previous_record_sequence) ||
      !r.ReadString("store_revision",value.header.store_revision) ||
      !r.ReadInteger("written_at",value.header.written_at) || !SWV5_TestDecodeBasket(r,"basket",value.basket) ||
      !SWV5_TestDecodeCorrelation(r,"last_confirmed_correlation",value.last_confirmed_correlation) ||
      !SWV5_TestDecodeRequestSetHeader(r,"pending_request_set",value.pending_request_set) ||
      !r.ReadBool("has_latest_pending_request",value.has_latest_pending_request) ||
      !SWV5_TestDecodePersistedRequest(r,"latest_pending_request",value.latest_pending_request) ||
      !SWV5_TestDecodeHardKill(r,"hard_kill_state",value.hard_kill_state)) return false;
   string reconciliation_text;
   if(!r.ReadNested("reconciliation_vector",reconciliation_text) ||
      !SWV5_TestDecodeReconciliationVector(reconciliation_text,value.reconciliation_vector) ||
       !r.ReadBool("clean_shutdown",value.clean_shutdown) ||
       !r.ReadUnsigned("header_payload_size",value.header.payload_size) ||
       !r.ReadString("header_payload_digest",value.header.payload_digest) || !r.AtEnd()) return false;
   return value.header.payload_size==SWV5_TestCheckpointPayloadSize(value) &&
          value.header.payload_digest==SWV5_TestCheckpointPayloadDigest(value);
}

#endif
