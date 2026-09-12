#ifndef SW_V5_S5_MVP_DEMO_AUTHORITY_PROVIDERS_MQH
#define SW_V5_S5_MVP_DEMO_AUTHORITY_PROVIDERS_MQH

// Locked FUSION-V5-DEMO-MVP-V1 Unit, Margin, Basket-risk and Risk authorities.
// Read-only platform calculations only. No broker mutation API exists here.

#include "SW_V5_S5_MvpReadOnlyPlatform.mqh"

const string SWV5S5_MVP_DOMAIN_SYMBOL_SPEC="MVP_SYMBOL_SPECIFICATION";
const string SWV5S5_MVP_DOMAIN_MARGIN="MVP_MARGIN_AUTHORITY";
const string SWV5S5_MVP_DOMAIN_BASKET_RISK="MVP_BASKET_RISK_AUTHORITY";

void SWV5S5_MvpSetDecision(const SWV5_ContractValidationContext &context,const bool allow,
                           const string reason,SWV5_ContractDecision &decision)
{
   ZeroMemory(decision);
   decision.contract_version=context.expected_version;
   decision.disposition=(allow ? SWV5_DISPOSITION_ALLOW : SWV5_DISPOSITION_DENY);
   decision.reason_code=reason;
   decision.reason_text=reason;
   decision.evaluated_schema_version=context.expected_version.schema_version;
   decision.evaluation_sequence=context.clock_sequence;
   decision.evaluated_at=context.clock_time;
}

bool SWV5S5_MvpVersionExact(const SWV5_ContractValidationContext &context,
                            const SWV5_ContractVersion &version)
{
   return version.contract_name==context.expected_version.contract_name &&
      version.schema_version==context.expected_version.schema_version &&
      version.minimum_compatible_version==context.expected_version.minimum_compatible_version &&
      version.policy_id==context.expected_version.policy_id;
}

bool SWV5S5_MvpSpecificationValid(const SWV5_ContractValidationContext &context,
                                  const SWV5_SymbolUnitSpecification &specification)
{
   return SWV5S5_MvpVersionExact(context,specification.contract_version) && specification.complete &&
      specification.symbol==SWV5S5_MVP_SYMBOL && specification.specification_sequence>0 &&
      specification.digits==SWV5S5_MVP_DIGITS &&
      SWV5S5_MvpNear(specification.point_size,SWV5S5_MVP_POINT_SIZE) &&
      SWV5S5_MvpNear(specification.pip_size,specification.point_size*100.0) &&
      specification.tick_size>0.0 && specification.tick_value_profit>0.0 &&
      specification.tick_value_loss>0.0 && specification.contract_size>0.0 &&
      specification.calculation_mode==SWV5_SYMBOL_CALCULATION_XAU_QUANTITY &&
      specification.tick_value_basis_volume>0.0 && specification.volume_minimum>0.0 &&
      specification.volume_maximum>=specification.volume_minimum && specification.volume_step>0.0 &&
      specification.stops_level_points>=0 && specification.freeze_level_points>=0 &&
      specification.account_currency==SWV5S5_MVP_ACCOUNT_CURRENCY &&
      specification.tick_value_currency==SWV5S5_MVP_ACCOUNT_CURRENCY &&
      specification.authority_source==SWV5_AUTHORITY_LIVE_BROKER_STATE &&
      specification.observed_at>0 && specification.observed_at<=context.clock_time &&
      context.clock_time<specification.valid_until &&
      specification.valid_until==specification.observed_at+(datetime)SWV5S5_MVP_SPECIFICATION_LIFETIME_SECONDS;
}

double SWV5S5_MvpRoundToStep(const double value,const double step,
                             const SWV5_NormalizationDirection direction)
{
   const double units=value/step;
   if(direction==SWV5_NORMALIZE_DOWN) return MathFloor(units+1.0e-10)*step;
   if(direction==SWV5_NORMALIZE_UP) return MathCeil(units-1.0e-10)*step;
   return MathRound(units)*step;
}

class SWV5S5_MvpUnitSystemContract : public ISWV5UnitSystemContract
{
public:
   virtual string ContractName(void) { return "ISWV5UnitSystemContract/FUSION-V5-DEMO-MVP-V1"; }

   virtual bool ValidateSpecification(const SWV5_ContractValidationContext &context,
                                      const SWV5_SymbolUnitSpecification &specification,
                                      SWV5_UnitValidationResult &result)
   {
      ZeroMemory(result); result.contract_version=context.expected_version;
      const bool valid=SWV5S5_MvpSpecificationValid(context,specification);
      SWV5S5_MvpSetDecision(context,valid,valid ? "MVP_SPECIFICATION_VALID" : "MVP_SPECIFICATION_DENIED",result.decision);
      result.validation_flags=(valid ? SWV5_UNIT_POINT_VALID|SWV5_UNIT_TICK_VALID|SWV5_UNIT_PIP_EXPLICIT|
         SWV5_UNIT_VOLUME_RANGE_VALID|SWV5_UNIT_VOLUME_STEP_VALID|SWV5_UNIT_TICK_VALUE_VALID|
         SWV5_UNIT_TICK_VALUE_CURRENCY_VALID|SWV5_UNIT_SPECIFICATION_FRESH|
         SWV5_UNIT_STOPS_LEVEL_VALID|SWV5_UNIT_FREEZE_LEVEL_VALID : 0);
      return valid;
   }

   virtual bool Normalize(const SWV5_ContractValidationContext &context,
                          const SWV5_SymbolUnitSpecification &specification,
                          const SWV5_UnitNormalizationRequest &request,
                          SWV5_NormalizedUnits &normalized,
                          SWV5_UnitValidationResult &result)
   {
      ZeroMemory(normalized); ZeroMemory(result); result.contract_version=context.expected_version;
      const bool request_shape=SWV5S5_MvpVersionExact(context,request.contract_version) &&
         request.intent_type==SWV5_INTENT_OPEN && request.operation_kind==SWV5_OPERATION_MARKET_ENTRY &&
         request.purpose==SWV5_PRICE_ENTRY && request.direction!=0 && MathAbs(request.direction)==1 &&
         request.exposure_increasing && !request.protective_operation &&
         request.current_exposure_volume<=context.volume_tolerance &&
         request.target_exposure_volume>0.0 && request.target_exposure_volume<=SWV5S5_MVP_MAX_VOLUME &&
         SWV5S5_MvpNear(request.raw_volume,request.target_exposure_volume,context.volume_tolerance) &&
         request.raw_price>0.0 && request.raw_stop_price>0.0 && request.raw_limit_price>=0.0 &&
         request.market_bid>0.0 && request.market_ask>=request.market_bid && request.operation_price>0.0 &&
         request.expected_specification_sequence==specification.specification_sequence &&
         SWV5S5_EqualFence(request.ownership_fence,request.ownership_fence) &&
         request.persistence_namespace.ownership_namespace.symbol==SWV5S5_MVP_SYMBOL;
      if(!request_shape || !SWV5S5_MvpSpecificationValid(context,specification))
      {
         SWV5S5_MvpSetDecision(context,false,"MVP_NORMALIZATION_INPUT_DENIED",result.decision);
         return false;
      }
      const SWV5_NormalizationDirection entry_rounding=(request.direction>0 ? SWV5_NORMALIZE_UP : SWV5_NORMALIZE_DOWN);
      const SWV5_NormalizationDirection stop_rounding=(request.direction>0 ? SWV5_NORMALIZE_DOWN : SWV5_NORMALIZE_UP);
      const SWV5_NormalizationDirection limit_rounding=(request.direction>0 ? SWV5_NORMALIZE_DOWN : SWV5_NORMALIZE_UP);
      normalized.contract_version=request.contract_version;
      normalized.persistence_namespace=request.persistence_namespace;
      normalized.ownership_fence=request.ownership_fence;
      normalized.derived_operation_semantic=SWV5_UNIT_OPERATION_OPEN;
      normalized.price=SWV5S5_MvpRoundToStep(request.raw_price,specification.tick_size,entry_rounding);
      normalized.stop_price=SWV5S5_MvpRoundToStep(request.raw_stop_price,specification.tick_size,stop_rounding);
      normalized.limit_price=(request.raw_limit_price>0.0 ?
         SWV5S5_MvpRoundToStep(request.raw_limit_price,specification.tick_size,limit_rounding) : 0.0);
      normalized.volume=SWV5S5_MvpRoundToStep(request.raw_volume,specification.volume_step,SWV5_NORMALIZE_DOWN);
      normalized.current_exposure_volume=0.0;
      normalized.target_exposure_volume=request.target_exposure_volume;
      normalized.resulting_exposure_volume=normalized.volume;
      normalized.residual_exposure_volume=MathAbs(normalized.volume-request.target_exposure_volume);
      normalized.stop_distance_price=MathAbs(request.operation_price-normalized.stop_price);
      normalized.stop_distance_points=normalized.stop_distance_price/specification.point_size;
      normalized.stop_distance_ticks=normalized.stop_distance_price/specification.tick_size;
      normalized.monetary_tick_value_per_volume_unit=specification.tick_value_profit/specification.tick_value_basis_volume;
      normalized.monetary_value_currency=specification.tick_value_currency;
      normalized.specification_sequence=specification.specification_sequence;
      normalized.applied_entry_rounding=entry_rounding;
      normalized.applied_stop_rounding=stop_rounding;
      normalized.applied_limit_rounding=limit_rounding;
      normalized.applied_volume_rounding=SWV5_NORMALIZE_DOWN;
      normalized.price_aligned_to_tick=SWV5S5_MvpNear(normalized.price/specification.tick_size,
                                                       MathRound(normalized.price/specification.tick_size),context.price_tolerance);
      normalized.volume_aligned_to_step=SWV5S5_MvpNear(normalized.volume/specification.volume_step,
                                                        MathRound(normalized.volume/specification.volume_step),context.volume_tolerance);
      normalized.stops_level_satisfied=normalized.stop_distance_points+context.price_tolerance>=specification.stops_level_points;
      normalized.freeze_level_satisfied=true;
      normalized.caller_flags_consistent=true;
      const bool stop_side=(request.direction>0 ? normalized.stop_price<normalized.price : normalized.stop_price>normalized.price);
      const bool limit_side=normalized.limit_price<=0.0 ||
         (request.direction>0 ? normalized.limit_price>normalized.price : normalized.limit_price<normalized.price);
      const bool valid=normalized.volume>=specification.volume_minimum-context.volume_tolerance &&
         normalized.volume<=SWV5S5_MVP_MAX_VOLUME+context.volume_tolerance &&
         normalized.price_aligned_to_tick && normalized.volume_aligned_to_step &&
         normalized.stops_level_satisfied && stop_side && limit_side;
      SWV5S5_MvpSetDecision(context,valid,valid ? "MVP_UNITS_NORMALIZED" : "MVP_UNITS_DENIED",result.decision);
      result.validation_flags=(valid ? SWV5_UNIT_POINT_VALID|SWV5_UNIT_TICK_VALID|SWV5_UNIT_PIP_EXPLICIT|
         SWV5_UNIT_VOLUME_RANGE_VALID|SWV5_UNIT_VOLUME_STEP_VALID|SWV5_UNIT_TICK_VALUE_VALID|
         SWV5_UNIT_TICK_VALUE_CURRENCY_VALID|SWV5_UNIT_SPECIFICATION_FRESH|
         SWV5_UNIT_STOPS_LEVEL_VALID|SWV5_UNIT_FREEZE_LEVEL_VALID : 0);
      return valid;
   }
};

class SWV5S5_MvpSymbolSpecificationAuthority
{
public:
   bool Refresh(SWV5S5_MvpSqliteAuthorityStore &store,ISWV5S5MvpReadOnlyPlatform &platform,
                const datetime observed_at,SWV5S5_SymbolSpecificationAuthorityView &view)
   {
      ZeroMemory(view);
      SWV5S5_MvpAuthorityRow current,committed; bool found=false;
      if(!store.ReadRow(SWV5S5_MVP_DOMAIN_SYMBOL_SPEC,SWV5S5_MVP_SYMBOL,current,found)) return false;
      const ulong sequence=(found ? current.logical_revision+1 : 1);
      if(!platform.CaptureSymbolSpecification(SWV5S5_MVP_SYMBOL,sequence,observed_at,view.specification) ||
         !SWV5S5_DeriveSymbolProjection(view)) return false;
      const string payload=SWV5S5_MVP_PROFILE_ID+"|"+view.projection_digest;
      if(!store.CompareAndSet(SWV5S5_MVP_DOMAIN_SYMBOL_SPEC,SWV5S5_MVP_SYMBOL,
         found ? current.logical_revision : 0,found ? current.store_revision : "",
         found ? current.payload_digest : "",found ? current.state : 0,
         sequence,1,view.projection_digest,payload,observed_at,committed)) return false;
      return committed.logical_revision==view.specification.specification_sequence;
   }
};

struct SWV5S5_MvpIncreasingAuthorityInput
{
   SWV5_ContractValidationContext context;
   SWV5_PersistenceNamespace persistence_namespace;
   SWV5_AccountRiskNamespace account_namespace;
   SWV5_OwnershipFence ownership_fence;
   SWV5_ExecutionRequestIdentity request_identity;
   SWV5_BasketLifecycleSnapshot basket;
   SWV5S5_SymbolSpecificationAuthorityView symbol;
   SWV5_NormalizedUnits normalized;
   SWV5S5_MvpAccountObservation account;
   int direction;
   bool active_fusion_operation;
   bool unresolved_fusion_request;
   bool session_can_cross_rollover;
};

bool SWV5S5_MvpIncreasingInputFlat(const SWV5S5_MvpIncreasingAuthorityInput &candidate)
{
   return candidate.account.complete && candidate.account.history_complete && candidate.account.positions_total==0 &&
      candidate.account.orders_total==0 && candidate.account.margin<=SWV5S5_MVP_MAX_EXISTING_MARGIN &&
      !candidate.active_fusion_operation && !candidate.unresolved_fusion_request && !candidate.session_can_cross_rollover &&
      candidate.basket.state==SWV5_BASKET_IDLE && candidate.basket.aggregate_open_volume<=candidate.context.volume_tolerance &&
      candidate.basket.pending_request_count==0 && candidate.normalized.derived_operation_semantic==SWV5_UNIT_OPERATION_OPEN &&
      (candidate.direction==1 || candidate.direction==-1) &&
      candidate.normalized.volume>0.0 && candidate.normalized.volume<=SWV5S5_MVP_MAX_VOLUME &&
      candidate.normalized.stop_price>0.0 && candidate.symbol.specification.specification_sequence==candidate.normalized.specification_sequence &&
      SWV5S5_MvpSpecificationValid(candidate.context,candidate.symbol.specification) &&
      SWV5S5_MvpProfileMatches(candidate.account.profile,ACCOUNT_TRADE_MODE_DEMO);
}

bool SWV5S5_MvpDeriveMarginAuthorityDigest(const SWV5_MarginAuthorityRecord &record,string &digest)
{
   string body="",f,format;
#define MVP_M_S(n,v) if(!SWV5S5_CanonicalString(n,v,f)) return false; else body+=f
#define MVP_M_I(n,v) if(!SWV5S5_CanonicalInt(n,v,f)) return false; else body+=f
#define MVP_M_U(n,v) if(!SWV5S5_CanonicalUInt(n,v,f)) return false; else body+=f
#define MVP_M_D(n,v) if(!SWV5S5_CanonicalDouble(n,v,f)) return false; else body+=f
   if(!SWV5S5_CanonicalContractVersion("contract_version",record.contract_version,f)) return false; body+=f;
   if(!SWV5S5_CanonicalNamespace("persistence_namespace",record.persistence_namespace,f)) return false; body+=f;
   if(!SWV5S5_CanonicalAccountNamespace("account_namespace",record.account_namespace,f)) return false; body+=f;
   if(!SWV5S5_CanonicalFence("ownership_fence",record.ownership_fence,f)) return false; body+=f;
   if(!SWV5S5_CanonicalRequestIdentity("request_identity",record.request_identity,f)) return false; body+=f;
   MVP_M_S("basket_id",record.basket_id.value); MVP_M_S("symbol",record.symbol);
   MVP_M_U("symbol_specification_sequence",record.symbol_specification_sequence); MVP_M_I("intent_type",record.intent_type);
   MVP_M_I("direction",record.direction); MVP_M_D("requested_volume",record.requested_volume);
   MVP_M_D("requested_price",record.requested_price); MVP_M_D("current_account_margin",record.current_account_margin);
   MVP_M_D("projected_account_margin",record.projected_account_margin); MVP_M_D("additional_margin",record.additional_margin);
   MVP_M_D("current_free_margin",record.current_free_margin); MVP_M_S("account_currency",record.account_currency);
   MVP_M_S("broker_calculation_reference",record.broker_calculation_reference); MVP_M_U("observation_sequence",record.observation_sequence);
   MVP_M_I("observed_at",record.observed_at); MVP_M_I("calculated_at",record.calculated_at);
   MVP_M_S("authority_record_id",record.authority_record_id); MVP_M_U("authority_record_sequence",record.authority_record_sequence);
   MVP_M_I("issuing_component",record.issuing_component); MVP_M_I("authority_source",record.authority_source);
#undef MVP_M_S
#undef MVP_M_I
#undef MVP_M_U
#undef MVP_M_D
   return SWV5S5_CanonicalString("format","SWV5-MARGIN-AUTHORITY-V5-LP1",format) &&
      SWV5S5_SHA256(format+body,digest);
}

bool SWV5S5_MvpDeriveBasketRiskAuthorityDigest(const SWV5_BasketRiskAuthorityRecord &record,string &digest)
{
   string body="",f,format;
#define MVP_B_S(n,v) if(!SWV5S5_CanonicalString(n,v,f)) return false; else body+=f
#define MVP_B_I(n,v) if(!SWV5S5_CanonicalInt(n,v,f)) return false; else body+=f
#define MVP_B_U(n,v) if(!SWV5S5_CanonicalUInt(n,v,f)) return false; else body+=f
#define MVP_B_D(n,v) if(!SWV5S5_CanonicalDouble(n,v,f)) return false; else body+=f
   if(!SWV5S5_CanonicalContractVersion("contract_version",record.contract_version,f)) return false; body+=f;
   if(!SWV5S5_CanonicalNamespace("persistence_namespace",record.persistence_namespace,f)) return false; body+=f;
   if(!SWV5S5_CanonicalAccountNamespace("account_namespace",record.account_namespace,f)) return false; body+=f;
   if(!SWV5S5_CanonicalFence("ownership_fence",record.ownership_fence,f)) return false; body+=f;
   MVP_B_S("basket_id",record.basket_id.value); MVP_B_U("basket_state_version",record.basket_state_version);
   if(!SWV5S5_CanonicalRequestIdentity("request_identity",record.request_identity,f)) return false; body+=f;
   MVP_B_S("symbol",record.symbol); MVP_B_U("symbol_specification_sequence",record.symbol_specification_sequence);
   MVP_B_S("source_snapshot_id",record.source_snapshot_id); MVP_B_S("source_snapshot_digest",record.source_snapshot_digest);
   MVP_B_D("existing_bounded_basket_loss",record.existing_bounded_basket_loss);
   MVP_B_D("incremental_request_bounded_loss",record.incremental_request_bounded_loss);
   MVP_B_D("interaction_or_offset_adjustment",record.interaction_or_offset_adjustment);
   MVP_B_D("resulting_basket_maximum_loss",record.resulting_basket_maximum_loss);
   MVP_B_D("realized_loss_basis",record.realized_loss_basis); MVP_B_D("unrealized_loss_basis",record.unrealized_loss_basis);
   MVP_B_D("accrued_cost_basis",record.accrued_cost_basis);
   if(!SWV5S5_CanonicalMonetaryBasis("monetary_basis",record.monetary_basis,f)) return false; body+=f;
   MVP_B_S("calculation_policy_id",record.calculation_policy_id); MVP_B_U("observation_sequence",record.observation_sequence);
   MVP_B_I("observed_at",record.observed_at); MVP_B_I("calculated_at",record.calculated_at);
   MVP_B_S("authority_record_id",record.authority_record_id); MVP_B_U("authority_record_sequence",record.authority_record_sequence);
   MVP_B_I("issuing_component",record.issuing_component); MVP_B_I("authority_source",record.authority_source);
#undef MVP_B_S
#undef MVP_B_I
#undef MVP_B_U
#undef MVP_B_D
   return SWV5S5_CanonicalString("format","SWV5-BASKET-RISK-AUTHORITY-V5-LP1",format) &&
      SWV5S5_SHA256(format+body,digest);
}

bool SWV5S5_MvpDeriveSourceSnapshot(const SWV5S5_MvpIncreasingAuthorityInput &candidate,
                                    string &snapshot_id,string &snapshot_digest)
{
   string body="",f;
   if(!SWV5S5_CanonicalNamespace("scope",candidate.persistence_namespace,f)) return false; body+=f;
   if(!SWV5S5_CanonicalAccountNamespace("account",candidate.account_namespace,f)) return false; body+=f;
   if(!SWV5S5_CanonicalFence("fence",candidate.ownership_fence,f)) return false; body+=f;
   if(!SWV5S5_CanonicalRequestIdentity("request",candidate.request_identity,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("symbol_projection",candidate.symbol.projection_digest,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("basket_version",candidate.basket.state_version,f)) return false; body+=f;
   if(!SWV5S5_CanonicalInt("basket_state",candidate.basket.state,f)) return false; body+=f;
   if(!SWV5S5_CanonicalDouble("balance",candidate.account.balance,f)) return false; body+=f;
   if(!SWV5S5_CanonicalDouble("equity",candidate.account.equity,f)) return false; body+=f;
   if(!SWV5S5_CanonicalDouble("margin",candidate.account.margin,f)) return false; body+=f;
   if(!SWV5S5_CanonicalDouble("daily_net",candidate.account.daily_realized_net,f)) return false; body+=f;
   if(!SWV5S5_DomainDigest("FUSION-V5-DEMO-MVP-SOURCE-SNAPSHOT-V1",body,snapshot_digest)) return false;
   snapshot_id="MVP-SNAPSHOT/"+snapshot_digest;
   return true;
}

class SWV5S5_MvpMarginAuthority
{
public:
   bool Issue(SWV5S5_MvpSqliteAuthorityStore &store,ISWV5S5MvpReadOnlyPlatform &platform,
              const SWV5S5_MvpIncreasingAuthorityInput &candidate,SWV5_MarginAuthorityRecord &record)
   {
      ZeroMemory(record);
      if(!SWV5S5_MvpIncreasingInputFlat(candidate)) return false;
      double margin=0.0;
      if(!platform.CalculateMargin(candidate.direction,SWV5S5_MVP_SYMBOL,
         candidate.normalized.volume,candidate.normalized.price,margin) || !MathIsValidNumber(margin) || margin<=0.0) return false;
      SWV5S5_InitContractVersion(record.contract_version);
      record.persistence_namespace=candidate.persistence_namespace; record.account_namespace=candidate.account_namespace;
      record.ownership_fence=candidate.ownership_fence; record.request_identity=candidate.request_identity;
      record.basket_id=candidate.persistence_namespace.basket_id; record.symbol=SWV5S5_MVP_SYMBOL;
      record.symbol_specification_sequence=candidate.symbol.specification.specification_sequence;
      record.intent_type=SWV5_INTENT_OPEN;
      record.direction=candidate.direction;
      record.requested_volume=candidate.normalized.volume; record.requested_price=candidate.normalized.price;
      record.current_account_margin=candidate.account.margin; record.additional_margin=margin;
      record.projected_account_margin=candidate.account.margin+margin; record.current_free_margin=candidate.account.free_margin;
      record.account_currency=SWV5S5_MVP_ACCOUNT_CURRENCY;
      record.broker_calculation_reference="MT5/OrderCalcMargin/FUSION-V5-DEMO-MVP-V1";
      record.observation_sequence=candidate.account_namespace.snapshot_sequence;
      record.observed_at=candidate.account.observed_at; record.calculated_at=candidate.context.clock_time;
      string key=candidate.request_identity.request_id.correlation_id+"/"+candidate.request_identity.request_id.attempt_id;
      string id_body="",f;
      if(key=="" || !SWV5S5_CanonicalString("request_key",key,f)) return false; id_body+=f;
      if(!SWV5S5_CanonicalUInt("sequence",1,f)) return false; id_body+=f;
      if(!SWV5S5_DomainDigest("FUSION-V5-DEMO-MVP-MARGIN-ID-V1",id_body,record.authority_record_id)) return false;
      record.authority_record_sequence=1; record.issuing_component=SWV5_COMPONENT_AUTHORITY_BROKER_ADAPTER;
      record.authority_source=SWV5_AUTHORITY_LIVE_BROKER_STATE;
      if(!SWV5S5_MvpDeriveMarginAuthorityDigest(record,record.authority_record_digest)) return false;
      string payload;
      if(!SWV5S5_CanonicalMarginAuthority("margin_authority",record,payload)) return false;
      SWV5S5_MvpAuthorityRow committed;
      return store.CompareAndSet(SWV5S5_MVP_DOMAIN_MARGIN,key,0,"","",0,1,1,
         record.authority_record_digest,payload,candidate.context.clock_time,committed);
   }
};

class SWV5S5_MvpBasketRiskAuthority
{
public:
   bool Issue(SWV5S5_MvpSqliteAuthorityStore &store,ISWV5S5MvpReadOnlyPlatform &platform,
              const SWV5S5_MvpIncreasingAuthorityInput &candidate,SWV5_BasketRiskAuthorityRecord &record)
   {
      ZeroMemory(record);
      if(!SWV5S5_MvpIncreasingInputFlat(candidate)) return false;
      const int direction=candidate.direction;
      double calculated_profit=0.0;
      if(!platform.CalculateProfit(direction,SWV5S5_MVP_SYMBOL,candidate.normalized.volume,
         candidate.normalized.price,candidate.normalized.stop_price,calculated_profit) ||
         !MathIsValidNumber(calculated_profit) || calculated_profit>=0.0) return false;
      const double incremental=-calculated_profit+SWV5S5_MVP_COST_RESERVE_USD;
      if(!MathIsValidNumber(incremental) || incremental>5.0) return false;
      string source_id,source_digest;
      if(!SWV5S5_MvpDeriveSourceSnapshot(candidate,source_id,source_digest)) return false;
      SWV5S5_InitContractVersion(record.contract_version);
      record.persistence_namespace=candidate.persistence_namespace; record.account_namespace=candidate.account_namespace;
      record.ownership_fence=candidate.ownership_fence; record.basket_id=candidate.persistence_namespace.basket_id;
      record.basket_state_version=candidate.basket.state_version; record.request_identity=candidate.request_identity;
      record.symbol=SWV5S5_MVP_SYMBOL; record.symbol_specification_sequence=candidate.symbol.specification.specification_sequence;
      record.source_snapshot_id=source_id; record.source_snapshot_digest=source_digest;
      record.existing_bounded_basket_loss=0.0; record.incremental_request_bounded_loss=incremental;
      record.interaction_or_offset_adjustment=0.0; record.resulting_basket_maximum_loss=incremental;
      record.realized_loss_basis=0.0; record.unrealized_loss_basis=0.0; record.accrued_cost_basis=0.0;
      SWV5S5_InitContractVersion(record.monetary_basis.contract_version);
      record.monetary_basis.currency=SWV5S5_MVP_ACCOUNT_CURRENCY;
      record.monetary_basis.account_currency=SWV5S5_MVP_ACCOUNT_CURRENCY;
      record.monetary_basis.conversion_rate_to_account_currency=1.0;
      record.monetary_basis.conversion_source=SWV5S5_MVP_CONVERSION_SOURCE;
      record.monetary_basis.valuation_at=candidate.context.clock_time;
      record.monetary_basis.calculation_basis=SWV5_RISK_BASIS_PROTECTIVE_STOP;
      record.monetary_basis.sign_convention=SWV5_RISK_LOSS_POSITIVE;
      record.monetary_basis.includes_realized=true; record.monetary_basis.includes_unrealized=true;
      record.monetary_basis.includes_commission=true; record.monetary_basis.includes_swap=true;
      record.monetary_basis.includes_fee=true;
      record.calculation_policy_id=SWV5S5_MVP_BASKET_RISK_POLICY;
      record.observation_sequence=candidate.account_namespace.snapshot_sequence;
      record.observed_at=candidate.account.observed_at; record.calculated_at=candidate.context.clock_time;
      const string key=candidate.request_identity.request_id.correlation_id+"/"+candidate.request_identity.request_id.attempt_id;
      string id_body="",f;
      if(key=="" || !SWV5S5_CanonicalString("request_key",key,f)) return false; id_body+=f;
      if(!SWV5S5_CanonicalString("source_snapshot",source_digest,f)) return false; id_body+=f;
      if(!SWV5S5_DomainDigest("FUSION-V5-DEMO-MVP-BASKET-RISK-ID-V1",id_body,record.authority_record_id)) return false;
      record.authority_record_sequence=1; record.issuing_component=SWV5_COMPONENT_AUTHORITY_RISK_GOVERNANCE;
      record.authority_source=SWV5_AUTHORITY_RISK_GOVERNANCE_RECORD;
      if(!SWV5S5_MvpDeriveBasketRiskAuthorityDigest(record,record.authority_record_digest)) return false;
      string payload;
      if(!SWV5S5_CanonicalBasketRiskAuthority("basket_risk_authority",record,payload)) return false;
      SWV5S5_MvpAuthorityRow committed;
      return store.CompareAndSet(SWV5S5_MVP_DOMAIN_BASKET_RISK,key,0,"","",0,1,1,
         record.authority_record_digest,payload,candidate.context.clock_time,committed);
   }
};

bool SWV5S5_MvpRiskInputAllowed(const SWV5_ContractValidationContext &context,
                                const SWV5_RiskEvaluationInput &candidate)
{
   const bool fresh=candidate.account.observed_at>=context.clock_time-5 && candidate.account.observed_at<=context.clock_time &&
      candidate.exposure.observed_at>=context.clock_time-5 && candidate.exposure.observed_at<=context.clock_time &&
      candidate.basket.observed_at>=context.clock_time-5 && candidate.basket.observed_at<=context.clock_time &&
      candidate.projected.calculated_at>=context.clock_time-5 && candidate.projected.calculated_at<=context.clock_time;
   const double daily_loss=-(candidate.account.daily_realized_net+candidate.account.daily_unrealized_net);
   string margin_digest,basket_digest;
   const bool authority_digests=SWV5S5_MvpDeriveMarginAuthorityDigest(candidate.margin_authority_record,margin_digest) &&
      margin_digest==candidate.margin_authority_record.authority_record_digest &&
      SWV5S5_MvpDeriveBasketRiskAuthorityDigest(candidate.basket_risk_authority_record,basket_digest) &&
      basket_digest==candidate.basket_risk_authority_record.authority_record_digest;
   return SWV5S5_MvpRiskLimitsExact(candidate.limits) && candidate.account_mode==SWV5_ACCOUNT_MODE_HEDGING &&
      candidate.account_namespace.account_currency==SWV5S5_MVP_ACCOUNT_CURRENCY &&
      candidate.account.authoritative && candidate.exposure.complete && candidate.projected.complete && fresh &&
      candidate.account.equity>=100.0 && daily_loss<=10.0 &&
      candidate.account.margin<=candidate.account.equity*0.10 &&
      candidate.projected.margin_evidence.projected_account_margin<=candidate.account.equity*0.10 &&
      candidate.projected.basket_risk_evidence.resulting_basket_maximum_loss<=5.0 &&
      candidate.projected.projected_volume<=0.01 && candidate.projected.projected_symbol_volume<=0.01 &&
      candidate.projected.projected_aggregate_volume<=0.01 && candidate.projected.projected_notional<=10000.0 &&
      candidate.exposure.live_basket_count<=1 && candidate.basket.lifecycle.cumulative_recovery_attempts<=1 &&
      candidate.intent.intent_type==SWV5_INTENT_OPEN && candidate.intent.normalized_volume<=0.01 &&
      candidate.intent.normalized_stop_price>0.0 && candidate.hard_kill_state.state==SWV5_HARD_KILL_INACTIVE &&
      candidate.has_margin_authority_record && candidate.has_basket_risk_authority_record && authority_digests;
}

class SWV5S5_MvpRiskContract : public ISWV5RiskContract
{
public:
   virtual string ContractName(void) { return "ISWV5RiskContract/FUSION-V5-DEMO-MVP-V1"; }

   virtual bool ValidateLimits(const SWV5_ContractValidationContext &context,
                               const SWV5_RiskLimits &limits,SWV5_ContractDecision &decision)
   {
      const bool valid=SWV5S5_MvpVersionExact(context,limits.contract_version) && SWV5S5_MvpRiskLimitsExact(limits);
      SWV5S5_MvpSetDecision(context,valid,valid ? "MVP_RISK_LIMITS_VALID" : "MVP_RISK_LIMITS_DENIED",decision);
      return valid;
   }

   virtual bool Evaluate(const SWV5_ContractValidationContext &context,
                         const SWV5_RiskEvaluationInput &candidate,SWV5_RiskAuthorization &authorization)
   {
      ZeroMemory(authorization);
      if(!SWV5S5_MvpRiskInputAllowed(context,candidate)) return false;
      authorization.contract_version=context.expected_version;
      authorization.authorization_id=candidate.intent.risk_authorization_id;
      authorization.limits_contract_id=candidate.limits.contract_id;
      authorization.authorized_limits=candidate.limits; authorization.request_identity=candidate.intent.request_identity;
      authorization.persistence_namespace=candidate.intent.persistence_namespace;
      authorization.ownership_fence=candidate.ownership_fence; authorization.account_namespace=candidate.account_namespace;
      authorization.account_mode=candidate.account_mode; authorization.disposition=SWV5_RISK_ALLOW;
      authorization.blocking_domain=SWV5_RISK_DOMAIN_NONE; authorization.reason_flags=0;
      authorization.basket_state_version=candidate.intent.expected_basket_version;
      authorization.symbol_specification_sequence=candidate.intent.symbol_specification_sequence;
      authorization.authorized_intent_type=candidate.intent.intent_type; authorization.authorized_direction=candidate.intent.direction;
      authorization.authorized_volume=candidate.intent.normalized_volume; authorization.authorized_price=candidate.intent.normalized_price;
      authorization.authorized_stop_price=candidate.intent.normalized_stop_price;
      authorization.authorized_limit_price=candidate.intent.normalized_limit_price;
      authorization.risk_snapshot_epoch=candidate.account_namespace.snapshot_epoch;
      authorization.risk_snapshot_sequence=candidate.account_namespace.snapshot_sequence;
      authorization.authorized_projected_loss=candidate.projected.basket_risk_evidence.resulting_basket_maximum_loss;
      authorization.authorized_projected_notional=candidate.projected.projected_notional;
      authorization.authorized_projected_margin=candidate.projected.margin_evidence.additional_margin;
      authorization.hard_kill_latch_id=candidate.hard_kill_state.latch_id;
      authorization.hard_kill_latch_generation=candidate.hard_kill_state.latch_generation;
      authorization.monetary_basis=candidate.projected.monetary_basis;
      authorization.evaluated_at=context.clock_time;
      const datetime policy_expiry=context.clock_time+5;
      authorization.expires_at=(candidate.intent.authorization_expires_at<policy_expiry ? candidate.intent.authorization_expires_at : policy_expiry);
      authorization.reason_text="FUSION-V5-DEMO-MVP-RISK-ALLOW";
      return authorization.authorization_id!="" && authorization.expires_at>authorization.evaluated_at;
   }

   virtual bool ValidateAuthorization(const SWV5_ContractValidationContext &context,
                                      const SWV5_RiskAuthorization &authorization,
                                      const SWV5_RiskEvaluationInput &current_binding,
                                      SWV5_ContractDecision &decision)
   {
      SWV5_RiskAuthorization expected;
      const bool evaluated=Evaluate(context,current_binding,expected);
      string left="",right="";
      const bool valid=evaluated && context.clock_time<authorization.expires_at &&
         SWV5S5_CanonicalRiskAuthorization("risk",authorization,left) &&
         SWV5S5_CanonicalRiskAuthorization("risk",expected,right) && left==right;
      SWV5S5_MvpSetDecision(context,valid,valid ? "MVP_RISK_AUTHORIZATION_VALID" : "MVP_RISK_AUTHORIZATION_DENIED",decision);
      return valid;
   }

   virtual bool ValidateHardKillRelease(const SWV5_ContractValidationContext &context,
                                        const SWV5_HardKillState &current_state,
                                        const SWV5_HardKillReleaseEvidence &evidence,
                                        SWV5_ContractDecision &decision)
   {
      return ValidateHardKillReleaseMode(context,current_state,evidence,
         SWV5_HARD_KILL_RELEASE_CURRENT_EXECUTION,decision);
   }

   virtual bool ValidateHardKillReleaseMode(const SWV5_ContractValidationContext &context,
                                            const SWV5_HardKillState &current_state,
                                            const SWV5_HardKillReleaseEvidence &evidence,
                                            const SWV5_HardKillReleaseValidationMode mode,
                                            SWV5_ContractDecision &decision)
   {
      const bool valid=mode==SWV5_HARD_KILL_RELEASE_CURRENT_EXECUTION &&
         current_state.state==SWV5_HARD_KILL_ACTIVE && evidence.release_id!="" &&
         evidence.latch_id==current_state.latch_id && evidence.latch_generation==current_state.latch_generation &&
         evidence.approved_at>0 && evidence.approved_at<=context.clock_time && context.clock_time<evidence.expires_at;
      SWV5S5_MvpSetDecision(context,valid,valid ? "MVP_HARD_KILL_RELEASE_VALID" : "MVP_HARD_KILL_RELEASE_DENIED",decision);
      return valid;
   }

   virtual bool ValidateHistoricalHardKillRelease(const SWV5_ContractValidationContext &context,
                                                   const SWV5_HardKillState &persisted_state,
                                                   const SWV5_HardKillReleaseEvidence &checkpoint_evidence,
                                                   const SWV5_HardKillReleaseAuthorityRecord &authority_record,
                                                   SWV5_ContractDecision &decision)
   {
      const bool valid=persisted_state.state==SWV5_HARD_KILL_RELEASED &&
         checkpoint_evidence.release_id!="" && authority_record.release_id==checkpoint_evidence.release_id &&
         authority_record.authority_record_id==persisted_state.release_authority_reference.authority_record_id &&
         authority_record.authority_record_digest==persisted_state.release_authority_reference.authority_record_digest;
      SWV5S5_MvpSetDecision(context,valid,valid ? "MVP_HISTORICAL_RELEASE_VALID" : "MVP_HISTORICAL_RELEASE_DENIED",decision);
      if(!valid) decision.disposition=SWV5_DISPOSITION_HALT;
      return valid;
   }
};

#endif // SW_V5_S5_MVP_DEMO_AUTHORITY_PROVIDERS_MQH
