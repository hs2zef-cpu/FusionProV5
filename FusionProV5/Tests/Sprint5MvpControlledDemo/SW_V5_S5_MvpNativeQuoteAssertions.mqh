#ifndef SW_V5_S5_MVP_NATIVE_QUOTE_ASSERTIONS_MQH
#define SW_V5_S5_MVP_NATIVE_QUOTE_ASSERTIONS_MQH
// TEST ONLY / NOT FOR PRODUCTION / NO BROKER MUTATION.
// Native reads/calculations execute in Demo Strategy Tester; no adapter send.
class SWV5S5_TestQuoteCalculationPlatform : public SWV5S5_MvpMt5ReadOnlyPlatform
{
public:
   double margin_entry,loss_entry;
   SWV5S5_TestQuoteCalculationPlatform(void) { margin_entry=0.0; loss_entry=0.0; }
   virtual bool CalculateMargin(const int direction,const string symbol,const double volume,
                                const double price,double &margin)
   { margin_entry=price; return SWV5S5_MvpMt5ReadOnlyPlatform::CalculateMargin(direction,symbol,volume,price,margin); }
   virtual bool CalculateProfit(const int direction,const string symbol,const double volume,
                                const double entry_price,const double stop_price,double &profit)
   { loss_entry=entry_price; return SWV5S5_MvpMt5ReadOnlyPlatform::CalculateProfit(direction,symbol,volume,entry_price,stop_price,profit); }
};

void SWV5S5_TestQuoteUnitNegatives(SWV5S5_MvpD1Collector &c,const SWV5S5_MvpMarketQuoteObservation &native,
   const SWV5_ContractValidationContext &context,ISWV5S5MvpReadOnlyPlatform &platform)
{
   SWV5_SymbolUnitSpecification spec; SWV5_UnitNormalizationRequest unit; ZeroMemory(unit);
   const bool captured=platform.CaptureSymbolSpecification(_Symbol,context.clock_sequence,context.clock_time,spec);
   if(!captured) { SWV5S5_MvpD1Record(c,"QUOTE-SPEC-REQUIRED",false); return; }
   // Independent deterministic fixture: 200 ticks, NOT observer prices.
   SWV5S5_MvpMarketQuoteObservation fixture=native;
   fixture.ask=MathRound(3500.0/spec.tick_size)*spec.tick_size;
   fixture.bid=fixture.ask-200.0*spec.tick_size;
   const bool bound=captured && SWV5S5_MvpBindQuoteToUnit(fixture,spec,context.clock_time,1,
      fixture.ask-2.0,fixture.ask+3.0,unit);
   SWV5S5_MvpD1Record(c,"QUOTE-02",bound && MathAbs(unit.market_bid-fixture.bid)<spec.tick_size*1e-6 &&
      MathAbs(unit.market_ask-fixture.ask)<spec.tick_size*1e-6 && unit.market_ask-unit.market_bid>spec.point_size*10.0);
   SWV5S5_MvpD1Record(c,"QUOTE-19",bound && unit.market_bid!=unit.raw_price-spec.point_size);
   for(int n=0;n<5;n++)
   {
      SWV5S5_MvpMarketQuoteObservation bad=fixture;
      if(n==0) { bad.tick_time--; bad.tick_time_msc-=1000; }
      if(n==1) bad.observed_at--;
      if(n==2) bad.bid+=spec.tick_size*0.5;
      if(n==3) bad.complete=false;
      if(n==4) bad.source=SWV5_AUTHORITY_NONE;
      const bool rejected=!SWV5S5_MvpBindQuoteToUnit(bad,spec,context.clock_time,1,fixture.ask-2.0,0.0,unit);
      SWV5S5_MvpD1Record(c,"QUOTE-07-"+IntegerToString(n),captured && rejected);
   }
   SWV5S5_MvpMarketQuoteObservation bad=fixture; bad.symbol="EURUSD";
   SWV5S5_MvpD1Record(c,"QUOTE-08",captured && !SWV5S5_MvpBindQuoteToUnit(bad,spec,context.clock_time,1,fixture.ask-2.0,0.0,unit));
   bad=fixture; bad.bid=0.0;
   const bool zero_rejected=!SWV5S5_MvpBindQuoteToUnit(bad,spec,context.clock_time,1,fixture.ask-2.0,0.0,unit);
   bad=fixture; bad.ask=bad.bid-spec.tick_size;
   SWV5S5_MvpD1Record(c,"QUOTE-09",captured && zero_rejected &&
      !SWV5S5_MvpBindQuoteToUnit(bad,spec,context.clock_time,1,fixture.ask-2.0,0.0,unit));
   SWV5S5_MvpD1Record(c,"QUOTE-10",captured &&
      !SWV5S5_MvpBindQuoteToUnit(fixture,spec,context.clock_time,1,fixture.ask+1.0,0.0,unit) &&
      !SWV5S5_MvpBindQuoteToUnit(fixture,spec,context.clock_time,1,fixture.ask,0.0,unit));
   SWV5S5_MvpD1Record(c,"QUOTE-11",captured &&
      !SWV5S5_MvpBindQuoteToUnit(fixture,spec,context.clock_time,1,fixture.ask-2.0,fixture.ask-1.0,unit) &&
      !SWV5S5_MvpBindQuoteToUnit(fixture,spec,context.clock_time,1,fixture.ask-2.0,fixture.ask,unit) &&
      SWV5S5_MvpBindQuoteToUnit(fixture,spec,context.clock_time,1,fixture.ask-2.0,fixture.ask+3.0,unit));
}

void SWV5S5_TestQuotePhysicalBindings(SWV5S5_MvpD1Collector &c,const bool ran,const bool loaded,
   const SWV5S5_MvpMarketQuoteObservation &event_quote,const SWV5S5_MvpControlledDemoInvocation &invocation,
   SWV5S5_TestQuoteCalculationPlatform &platform,SWV5S5_MvpControlledDemoAuthorityPort &port,
   const SWV5S5_SubmissionAuthorityRecord &claimed,const SWV5S5_F_AdapterSubmissionCommand &command,const uint seam_calls)
{
   SWV5S5_MvpMarketQuoteObservation quote; SWV5_UnitNormalizationRequest unit; SWV5_NormalizedUnits normalized;
   const bool bound=ran && loaded && port.ReadPreparedMarketBinding(quote,unit,normalized);
   double tick_size=0.0; const bool tick_ok=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE,tick_size) && tick_size>0.0;
   SWV5S5_MvpD1Record(c,"QUOTE-03",bound && tick_ok && MathAbs(normalized.price-event_quote.ask)<=tick_size*1e-6 && unit.raw_price==event_quote.ask);
   SWV5S5_MvpD1Record(c,"QUOTE-04",bound && unit.market_bid==event_quote.bid);
   SWV5S5_MvpD1Record(c,"QUOTE-05",bound && unit.market_ask==event_quote.ask);
   SWV5S5_MvpD1Record(c,"QUOTE-06",bound && tick_ok && normalized.price!=invocation.requested_price && MathAbs(normalized.price-event_quote.ask)<=tick_size*1e-6);
   SWV5S5_MvpD1Record(c,"QUOTE-12",bound && platform.margin_entry==normalized.price &&
      claimed.permit.margin_authority.requested_price==normalized.price);
   SWV5S5_MvpD1Record(c,"QUOTE-13",bound && platform.loss_entry==normalized.price &&
      claimed.permit.basket_risk_authority.incremental_request_bounded_loss>0.0);
   SWV5_RiskEvaluationInput risk; SWV5_RiskAuthorization authorization;
   SWV5S5_MvpD1Record(c,"QUOTE-14",bound && port.ReadPreparedRiskBinding(risk,authorization) &&
      risk.intent.normalized_price==normalized.price && authorization.authorized_price==normalized.price &&
      authorization.authorized_stop_price==normalized.stop_price && authorization.authorized_limit_price==normalized.limit_price);
   SWV5S5_MvpD1Record(c,"QUOTE-15",bound && claimed.permit.normalized_payload.price==normalized.price &&
      claimed.permit.normalized_payload.stop_price==normalized.stop_price && claimed.permit.normalized_payload.limit_price==normalized.limit_price);
   SWV5S5_AdmissionSnapshot snapshot;
   SWV5S5_MvpD1Record(c,"QUOTE-16",bound && port.ReadAdmissionCollections(snapshot) &&
      snapshot.collect_v1.normalized_payload.payload.price==normalized.price && snapshot.collect_v2.normalized_payload.payload.price==normalized.price &&
      claimed.admission_snapshot.collect_v1.normalized_payload.payload.price==normalized.price &&
      claimed.admission_snapshot.collect_v2.normalized_payload.payload.price==normalized.price);
   SWV5S5_MvpD1Record(c,"QUOTE-17",bound && command.authoritative_claim.claim_granted_now &&
      command.authoritative_claim.resulting_authority_record.permit.normalized_payload.price==normalized.price);
   SWV5S5_MvpD1Record(c,"QUOTE-18",bound && command.price==normalized.price && command.stop_price==normalized.stop_price && command.limit_price==normalized.limit_price);
   // Coupled with static seam/no-send proof: one NON-MUTATING seam invocation,
   // not the runner's simulated transport counter masquerading as native calls.
   SWV5S5_MvpD1Record(c,"QUOTE-20",bound && tick_ok && seam_calls==1 && MathAbs(command.price-event_quote.ask)<=tick_size*1e-6);
   Print("QUOTE_EVIDENCE|actual_broker_submission_calls=0|non_mutating_seam_calls=",seam_calls,
      "|authorized_price=",DoubleToString(normalized.price,8),"|bid=",DoubleToString(unit.market_bid,8),"|ask=",DoubleToString(unit.market_ask,8));
}
#endif
