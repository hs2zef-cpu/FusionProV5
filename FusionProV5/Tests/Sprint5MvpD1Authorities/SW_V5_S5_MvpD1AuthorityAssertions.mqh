#ifndef SW_V5_S5_MVP_D1_AUTHORITY_ASSERTIONS_MQH
#define SW_V5_S5_MVP_D1_AUTHORITY_ASSERTIONS_MQH

// TEST ONLY / NOT FOR PRODUCTION / NO BROKER ACCESS

#include "../../ExecutionLayer/RuntimeAuthority/SW_V5_S5_MvpIngressRequestAuthorities.mqh"
#include "../../ExecutionLayer/ControlledDemo/SW_V5_S5_MvpSignalIngressAdapter.mqh"
#include "../../ExecutionLayer/ControlledDemo/SW_V5_S5_MvpControlledDemoAuthorityPort.mqh"
#include "../../ExecutionLayer/RuntimeAuthority/SW_V5_S5_MvpPermitClaimAuthorities.mqh"
#include "../ContractVerification/SW_V5_TestFixtures.mqh"
#include "../Sprint5PhaseB/SW_V5_S5_PhaseB_Assertions.mqh"
#include "../ContractVerification/SW_V5_ReferenceValidators.mqh"

struct SWV5S5_MvpD1Collector
{
   uint total;
   uint passed;
   uint failed;
   ulong signature;
};

void SWV5S5_MvpD1Record(SWV5S5_MvpD1Collector &c,const string id,const bool passed)
{
   c.total++; if(passed)c.passed++; else c.failed++;
   const string item=id+":"+(passed ? "PASS" : "FAIL");
   for(int i=0;i<StringLen(item);i++) c.signature=(c.signature^(ulong)StringGetCharacter(item,i))*1099511628211;
   Print("MVP_D1_AUTHORITY_TEST|",id,"|",(passed ? "PASS" : "FAIL"));
}

void SWV5S5_MvpD1MakeContext(SWV5_ContractValidationContext &context)
{
   ZeroMemory(context); SWV5S5_InitContractVersion(context.expected_version);
   context.clock_id="BROKER-SERVER-CLOCK"; context.clock_authority=SWV5_TIME_AUTHORITY_BROKER_SERVER;
   context.clock_time=SWV5_TEST_TIME; context.clock_sequence=100; context.evaluation_sequence=100;
   context.price_tolerance=0.0000001; context.volume_tolerance=0.0000001;
}

void SWV5S5_MvpD1MakeAllowedRisk(const SWV5_ContractValidationContext &context,
                                 SWV5_RiskEvaluationInput &candidate)
{
   SWV5_TestMakeRiskInput(candidate);
   SWV5S5_MvpLoadRiskLimits(candidate.limits);
   candidate.account.observed_at=context.clock_time;
   candidate.exposure.observed_at=context.clock_time;
   candidate.basket.observed_at=context.clock_time;
   candidate.projected.calculated_at=context.clock_time;
   candidate.projected.symbol=SWV5S5_MVP_SYMBOL;
   candidate.projected.projected_volume=0.01;
   candidate.projected.projected_symbol_volume=0.01;
   candidate.projected.projected_aggregate_volume=0.01;
   candidate.projected.projected_notional=35.0;
   candidate.projected.margin_evidence.projected_account_margin=124.0;
   candidate.projected.basket_risk_evidence.resulting_basket_maximum_loss=4.0;
   candidate.projected.projected_maximum_loss=4.0;
   candidate.exposure.live_basket_count=0;
   candidate.basket.lifecycle.cumulative_recovery_attempts=0;
   candidate.intent.normalized_volume=0.01;
   candidate.intent.authorization_expires_at=context.clock_time+5;
   candidate.margin_authority_record.requested_volume=0.01;
   candidate.margin_authority_record.symbol=SWV5S5_MVP_SYMBOL;
   candidate.margin_authority_record.authority_record_digest="";
   SWV5S5_MvpDeriveMarginAuthorityDigest(candidate.margin_authority_record,
                                          candidate.margin_authority_record.authority_record_digest);
   candidate.projected.margin_evidence.authority_record_digest=candidate.margin_authority_record.authority_record_digest;
   candidate.basket_risk_authority_record.symbol=SWV5S5_MVP_SYMBOL;
   candidate.basket_risk_authority_record.resulting_basket_maximum_loss=4.0;
   candidate.basket_risk_authority_record.authority_record_digest="";
   SWV5S5_MvpDeriveBasketRiskAuthorityDigest(candidate.basket_risk_authority_record,
                                              candidate.basket_risk_authority_record.authority_record_digest);
   candidate.projected.basket_risk_evidence.authority_record_digest=candidate.basket_risk_authority_record.authority_record_digest;
   candidate.projected.basket_risk_evidence.resulting_basket_maximum_loss=4.0;
   candidate.hard_kill_state.state=SWV5_HARD_KILL_INACTIVE;
   candidate.intent.risk_authorization_id="";
}

bool SWV5S5_MvpD1PrepareReservation(const SWV5S5_RequestSequenceAuthority &authority,
                                    const SWV5S5_RequestSequenceIndexEntry &entries[],
                                    const string correlation,const string binding_digest,
                                    SWV5S5_RequestSequenceReservation &proposal)
{
   ZeroMemory(proposal); SWV5S5_InitContractVersion(proposal.contract_version);
   proposal.persistence_namespace=authority.persistence_namespace; proposal.ownership_fence=authority.ownership_fence;
   proposal.logical_correlation_id=correlation; proposal.binding_digest=binding_digest;
   proposal.expected_allocator_revision=authority.allocator_revision;
   proposal.expected_authority_digest=authority.authority_digest;
   proposal.observed_high_watermark=authority.request_sequence_high_watermark;
   const int found=SWV5S5_FindSequenceReservation(entries,correlation);
   proposal.proposed_sequence=(found>=0 ? entries[found].reserved_sequence : authority.request_sequence_high_watermark+1);
   proposal.proposed_allocator_revision=(found>=0 ? authority.allocator_revision : authority.allocator_revision+1);
   return SWV5S5_DeriveSequenceReservationDigest(proposal,proposal.reservation_digest);
}

bool SWV5S5_MvpD1PrepareLedgerProposal(const SWV5S5_IngressLedgerHeader &header,
                                       const string ingress_identity,const string payload_digest,
                                       const ulong publication_sequence,const string correlation,
                                       const ulong reservation,const datetime accepted_at,
                                       SWV5S5_IngressLedgerProposal &proposal)
{
   ZeroMemory(proposal); proposal.expected_header=header; proposal.proposed_next_revision=header.revision+1;
   SWV5S5_InitContractVersion(proposal.proposed_record.contract_version);
   proposal.proposed_record.ingress_identity=ingress_identity; proposal.proposed_record.payload_digest=payload_digest;
   proposal.proposed_record.publication_sequence=publication_sequence;
   proposal.proposed_record.lifecycle_state=SWV5S5_ACCEPTED_REQUEST_PENDING;
   proposal.proposed_record.logical_correlation_id=correlation;
   proposal.proposed_record.reserved_request_sequence=reservation;
   proposal.proposed_record.accepted_at=accepted_at; proposal.proposed_record.bound_request_id="";
   proposal.proposed_record.terminal_disposition=""; proposal.proposed_record.record_sequence=header.membership_count+1;
   proposal.proposed_record.record_revision=proposal.proposed_next_revision;
   return SWV5S5_DeriveLedgerRecordDigest(proposal.proposed_record,proposal.proposed_record.record_digest) &&
      SWV5S5_MvpDeriveLedgerProposalDigest(proposal,proposal.proposal_digest);
}

void SWV5S5_MvpD1SignalAssertions(SWV5S5_MvpD1Collector &c,const string path,
                                  const string namespace_digest)
{
   SWV5_ContractValidationContext context; SWV5S5_MvpD1MakeContext(context);
   SWV5S5_ProducerTrustRecord trust; ZeroMemory(trust); SWV5S5_InitContractVersion(trust.contract_version);
   trust.authority_record_id="TRUST-SIGNAL"; trust.authority_generation=1;
   trust.issuer_identity="ISSUER"; trust.issuer_policy_id="POLICY";
   trust.producer_component="DECISION"; trust.producer_instance=SWV5S5_MVP_PRODUCER_INSTANCE;
   trust.producer_epoch=1; trust.symbol=SWV5S5_MVP_SYMBOL; trust.timeframe=(int)PERIOD_M15;
   trust.execution_mode=(int)SWV5_EXECUTION_EVERY_TICK; trust.clock_id=context.clock_id;
   trust.clock_authority=context.clock_authority; trust.status=SWV5S5_TRUST_AUTHORIZED;
   trust.valid_from=context.clock_time-10; trust.valid_until=context.clock_time+10;
   trust.superseding_record_id="";
   SWV5_EngineInput engine; ZeroMemory(engine);
   SWV5_InitHeader(engine.market.header,41,7,SWV5_EXECUTION_EVERY_TICK,SWV5S5_MVP_SYMBOL,PERIOD_M15,context.clock_time-1);
   SWV5_DecisionResult decision; ZeroMemory(decision);
   decision.header.engine_kind=SWV5_ENGINE_DECISION; decision.header.health=SWV5_HEALTH_HEALTHY;
   decision.header.valid=true; decision.header.score=1.0; decision.header.confidence=1.0;
   decision.header.snapshot_sequence=engine.market.header.sequence;
   decision.header.history_generation=engine.market.header.history_generation;
   decision.action=SWV5_ACTION_BUY; decision.direction=1; decision.state="BUY";
   decision.blocking_engine=SWV5_ENGINE_DECISION;
   SWV5S5_MvpSignalIngressAdapter adapter; SWV5S5_IngressEnvelope first,replay; bool replayed=false,replayed_again=false;
   const bool first_ok=adapter.Configure(path,namespace_digest) &&
      adapter.Publish(engine,decision,trust,context,first,replayed);
   SWV5S5_MvpD1Record(c,"SIGNAL-01",first_ok && !replayed && first.publication.publication_sequence==1);
   SWV5S5_MvpD1Record(c,"SIGNAL-02",first_ok && first.snapshot.sequence==engine.market.header.sequence &&
      first.snapshot.data_quality_flags==engine.market.header.data_quality_flags &&
      first.decision.reason_flags==decision.header.reason_flags && first.decision.direction==decision.direction);
   SWV5S5_MvpSignalIngressAdapter restarted;
   const bool replay_ok=restarted.Configure(path,namespace_digest) &&
      restarted.Publish(engine,decision,trust,context,replay,replayed_again);
   SWV5S5_MvpD1Record(c,"SIGNAL-03",replay_ok && replayed_again &&
      replay.ingress_identity==first.ingress_identity && replay.payload_digest==first.payload_digest &&
      replay.publication.publication_sequence==first.publication.publication_sequence);
   SWV5_DecisionResult mismatched=decision; mismatched.header.snapshot_sequence++;
   SWV5S5_IngressEnvelope denied; bool denied_replay=false;
   SWV5S5_MvpD1Record(c,"SIGNAL-04",!restarted.Publish(engine,mismatched,trust,context,denied,denied_replay));
   mismatched=decision; mismatched.direction=-1;
   SWV5S5_MvpD1Record(c,"SIGNAL-05",!restarted.Publish(engine,mismatched,trust,context,denied,denied_replay));
   SWV5_DecisionResult wait_decision=decision; wait_decision.action=SWV5_ACTION_WAIT;
   wait_decision.direction=0; wait_decision.state="WAIT";
   SWV5S5_IngressEnvelope wait_ingress; bool wait_replay=false;
   const bool wait_ok=restarted.Publish(engine,wait_decision,trust,context,wait_ingress,wait_replay);
   SWV5S5_MvpD1Record(c,"SIGNAL-06",wait_ok && !wait_replay && wait_ingress.decision.action==0 &&
      wait_ingress.publication.publication_sequence==2 && wait_ingress.ingress_identity!=first.ingress_identity);
}

class SWV5S5_MvpD1ReadOnlyPlatform : public ISWV5S5MvpReadOnlyPlatform
{
public:
   virtual bool CaptureProfile(const string symbol,SWV5S5_MvpRuntimeProfileObservation &profile,
                               datetime &observed_at)
   {
      ZeroMemory(profile); observed_at=SWV5_TEST_TIME;
      profile.broker_identity="APPROVED-DEMO-BROKER"; profile.server="APPROVED-DEMO-SERVER";
      profile.account_login=123456; profile.account_currency=SWV5S5_MVP_ACCOUNT_CURRENCY;
      profile.symbol=symbol; profile.account_trade_mode=ACCOUNT_TRADE_MODE_DEMO;
      profile.account_mode=SWV5_ACCOUNT_MODE_HEDGING; profile.connected=true;
      profile.account_trade_allowed=true; profile.account_trade_expert=true;
      return symbol==SWV5S5_MVP_SYMBOL;
   }
   virtual bool CaptureSymbolSpecification(const string symbol,const ulong sequence,
                                            const datetime observed_at,
                                            SWV5_SymbolUnitSpecification &specification)
   {
      ZeroMemory(specification);
      if(symbol!=SWV5S5_MVP_SYMBOL || sequence==0 || observed_at!=SWV5_TEST_TIME) return false;
      SWV5S5_MvpInitProductionVersion(specification.contract_version);
      specification.symbol=symbol; specification.specification_sequence=sequence;
      specification.digits=SWV5S5_MVP_DIGITS; specification.point_size=SWV5S5_MVP_POINT_SIZE;
      specification.tick_size=0.01; specification.pip_size=0.10;
      specification.tick_value_profit=1.0; specification.tick_value_loss=1.0;
      specification.contract_size=100.0; specification.calculation_mode=SWV5_SYMBOL_CALCULATION_XAU_QUANTITY;
      specification.tick_value_basis_volume=1.0; specification.volume_minimum=0.01;
      specification.volume_maximum=100.0; specification.volume_step=0.01;
      specification.stops_level_points=10; specification.freeze_level_points=0;
      specification.account_currency=SWV5S5_MVP_ACCOUNT_CURRENCY;
      specification.tick_value_currency=SWV5S5_MVP_ACCOUNT_CURRENCY;
      specification.authority_source=SWV5_AUTHORITY_LIVE_BROKER_STATE;
      specification.observed_at=observed_at;
      specification.valid_until=observed_at+(datetime)SWV5S5_MVP_SPECIFICATION_LIFETIME_SECONDS;
      specification.complete=true; return true;
   }
   virtual bool CaptureFlatAccount(const datetime observed_at,SWV5S5_MvpAccountObservation &account)
   {
      ZeroMemory(account); datetime profile_at=0;
      if(observed_at!=SWV5_TEST_TIME || !CaptureProfile(SWV5S5_MVP_SYMBOL,account.profile,profile_at) ||
         profile_at!=observed_at) return false;
      account.balance=10000.0; account.equity=10000.0; account.margin=0.0;
      account.free_margin=10000.0; account.daily_realized_net=0.0; account.daily_unrealized_net=0.0;
      account.trading_day_start=observed_at-3600; account.observed_at=observed_at;
      account.positions_total=0; account.orders_total=0; account.history_complete=true; account.complete=true;
      return true;
   }
   virtual bool CalculateMargin(const int direction,const string symbol,const double volume,
                                const double price,double &margin)
   { margin=1.0; return (direction==1 || direction==-1) && symbol==SWV5S5_MVP_SYMBOL &&
        volume==0.01 && price>0.0; }
   virtual bool CalculateProfit(const int direction,const string symbol,const double volume,
                                const double entry_price,const double stop_price,double &profit)
   { profit=-2.0; return (direction==1 || direction==-1) && symbol==SWV5S5_MVP_SYMBOL &&
        volume==0.01 && entry_price>0.0 && stop_price>0.0; }
};

class SWV5S5_MvpD1NonMutatingBoundary : public ISWV5S5_MvpControlledDemoSubmissionBoundary
{
public:
   uint calls;
   SWV5S5_MvpD1NonMutatingBoundary(void) { calls=0; }
   virtual bool SubmitExactlyOnce(SWV5S5_F_AdapterSubmissionCommand &command,
                                  ISWV5S5FBrokerEvidenceStore &evidence_store,
                                  SWV5S5_F_AdapterSyncResult &captured)
   {
      calls++; ZeroMemory(captured); string reason;
      captured.invocation_attempted=false; captured.retry_allowed=false;
      return SWV5S5_F_AdapterValidatePreflight(command,reason)==
         SWV5S5_F_ADAPTER_PREFLIGHT_READY_CURRENT_CLAIM;
   }
};

void SWV5S5_MvpD1MakeScope(SWV5_PersistenceNamespace &scope,SWV5_InstanceLease &lease,
                           string &namespace_digest)
{
   ZeroMemory(scope); ZeroMemory(lease); SWV5S5_MvpInitProductionVersion(scope.contract_version);
   scope.ownership_namespace.account_login=123456;
   scope.ownership_namespace.broker_identity="APPROVED-DEMO-BROKER";
   scope.ownership_namespace.server="APPROVED-DEMO-SERVER";
   scope.ownership_namespace.symbol=SWV5S5_MVP_SYMBOL;
   scope.ownership_namespace.strategy_id=SWV5S5_MVP_PROFILE_ID;
   scope.ownership_namespace.magic=SWV5_RUNTIME_STRATEGY_MAGIC;
   scope.basket_id.value="MVP-D1-BASKET";
   SWV5S5_MvpInitProductionVersion(lease.contract_version);
   SWV5S5_MvpInitProductionVersion(lease.fence.contract_version);
   lease.fence.ownership_namespace=scope.ownership_namespace;
   lease.fence.owner.key=scope.ownership_namespace;
   lease.fence.owner.instance_id="MVP-D1-INSTANCE";
   lease.fence.owner.process_fingerprint="MVP-D1-OFFLINE-PROCESS";
   lease.fence.owner.started_at=SWV5_TEST_TIME-100;
   lease.fence.lease_version=1; lease.fence.takeover_generation=1;
   SWV5S5_SHA256("MVP-D1-FENCE",lease.fence.fencing_token_digest);
   lease.status=SWV5_LOCK_ACQUIRED; SWV5S5_SHA256("MVP-D1-LEASE-STORE",lease.store_revision);
   lease.heartbeat_sequence=1; lease.clock_id="BROKER-SERVER-CLOCK";
   lease.clock_authority=SWV5_TIME_AUTHORITY_BROKER_SERVER;
   lease.acquired_clock_sequence=90; lease.heartbeat_clock_sequence=100; lease.expiry_clock_sequence=110;
   lease.acquired_at=SWV5_TEST_TIME-100; lease.heartbeat_at=SWV5_TEST_TIME;
   lease.expires_at=SWV5_TEST_TIME+60;
   SWV5S5_MvpOwnershipNamespaceDigest(scope.ownership_namespace,namespace_digest);
}

void SWV5S5_MvpD1MakeAccountNamespace(const SWV5_PersistenceNamespace &scope,
                                      SWV5_AccountRiskNamespace &account)
{
   ZeroMemory(account); SWV5S5_MvpInitProductionVersion(account.contract_version);
   account.broker_identity=scope.ownership_namespace.broker_identity;
   account.server=scope.ownership_namespace.server; account.account_login=scope.ownership_namespace.account_login;
   account.account_currency=SWV5S5_MVP_ACCOUNT_CURRENCY;
   account.strategy_id=scope.ownership_namespace.strategy_id; account.magic=scope.ownership_namespace.magic;
   account.account_mode=SWV5_ACCOUNT_MODE_HEDGING;
   account.authoritative_source=SWV5_AUTHORITY_LIVE_BROKER_STATE;
   account.snapshot_epoch=1; account.snapshot_sequence=1;
}

bool SWV5S5_MvpD1ProvisionGenesis(const string path,const string namespace_digest,
                                  const SWV5S5_MvpOperatorInvocation &operator_invocation,
                                  const datetime now)
{
   SWV5S5_MvpManualGenesisProvisioner genesis;
   return genesis.Configure(path,namespace_digest) && genesis.Begin(operator_invocation,now) &&
      genesis.InitializeAllDomains(now) && genesis.FinalizeReadyForReconciliation(now);
}

struct SWV5S5_MvpD1PhysicalSeedStatus
{
   bool genesis_valid;
   bool lease_clock_valid;
   bool lease_round_trip;
   bool trust_round_trip;
   bool hard_kill_valid;
   bool producer_sequence_initialized;
   bool request_sequence_initialized;
   bool ledger_initialized;
   bool request_set_initialized;
};

bool SWV5S5_MvpD1ProvisionPhysicalSeed(const string path,const string namespace_digest,
                                       const SWV5_PersistenceNamespace &scope,
                                       SWV5S5_MvpControlledDemoAuthoritySeed &seed,
                                       SWV5S5_MvpD1PhysicalSeedStatus &status)
{
   ZeroMemory(status);
   FileDelete(path,FILE_COMMON); FileDelete(path+"-wal",FILE_COMMON); FileDelete(path+"-shm",FILE_COMMON);
   SWV5S5_MvpOperatorInvocation operator_invocation; ZeroMemory(operator_invocation);
   operator_invocation.operator_id="MVP-D1-OFFLINE-OPERATOR";
   operator_invocation.authority_role=SWV5S5_MVP_OPERATOR_ROLE;
   operator_invocation.authentication_reference="MVP-D1-OFFLINE-AUTH";
   operator_invocation.authenticated_at=seed.context.clock_time;
   if(!SWV5S5_MvpD1ProvisionGenesis(path,namespace_digest,operator_invocation,seed.context.clock_time))
   { Print("MVP_D1_E2E_SETUP_FAIL|GENESIS|error=",GetLastError()); return false; }
   SWV5S5_MvpManualGenesisProvisioner genesis_check; bool reconciliation_ready=false;
   status.genesis_valid=genesis_check.Configure(path,namespace_digest) &&
      genesis_check.IsReadyForReconciliation(reconciliation_ready) && reconciliation_ready;
   if(!status.genesis_valid) { Print("MVP_D1_E2E_SETUP_FAIL|GENESIS_READBACK"); return false; }
   SWV5S5_MvpSqliteAuthorityStore store; SWV5S5_MvpAuthorityRow committed;
   SWV5S5_MvpLeasePublicationAuthority lease_authority;
   SWV5S5_LeaseLivenessAuthorityView lease_view; lease_view.lease=seed.current_lease;
   status.lease_clock_valid=SWV5S5_IsV5Version(seed.current_lease.contract_version) &&
      SWV5S5_DeriveLeaseProjection(lease_view) &&
      SWV5S5_MvpLeaseCurrentForClock(seed.context,seed.current_lease.fence,seed.current_lease);
   if(!status.lease_clock_valid) { Print("MVP_D1_E2E_SETUP_FAIL|LEASE_CLOCK"); return false; }
   if(!store.Open(path,namespace_digest) ||
      !lease_authority.Publish(store,seed.current_lease,0,"","",0,seed.context.clock_time,committed))
   { Print("MVP_D1_E2E_SETUP_FAIL|LEASE|error=",GetLastError()); return false; }
   SWV5_InstanceLease persisted_lease; SWV5S5_MvpAuthorityRow persisted_lease_row;
   status.lease_round_trip=lease_authority.LoadCurrentLease(store,
      seed.current_lease.fence.ownership_namespace,seed.current_lease.fence,
      persisted_lease,persisted_lease_row) && SWV5S5_MvpLeaseExact(seed.current_lease,persisted_lease);
   if(!status.lease_round_trip) { Print("MVP_D1_E2E_SETUP_FAIL|LEASE_READBACK"); return false; }
   store.Close();
   ZeroMemory(seed.trust_anchor); seed.trust_anchor.issuer_identity="MVP-D1-TRUST-ISSUER";
   seed.trust_anchor.issuer_policy_id="MVP-D1-TRUST-POLICY";
   seed.trust_anchor.trust_anchor_id="MVP-D1-TRUST-ANCHOR";
   seed.trust_anchor.current_authority_record_id="MVP-D1-TRUST-RECORD";
   seed.trust_anchor.current_authority_generation=1;
   SWV5S5_ProducerTrustScope trust_scope; ZeroMemory(trust_scope);
   trust_scope.persistence_namespace=scope; trust_scope.producer_component="DECISION";
   trust_scope.producer_instance=SWV5S5_MVP_PRODUCER_INSTANCE; trust_scope.producer_epoch=1;
   trust_scope.symbol=SWV5S5_MVP_SYMBOL; trust_scope.timeframe=(int)PERIOD_M15;
   trust_scope.execution_mode=(int)SWV5_EXECUTION_EVERY_TICK;
   trust_scope.publication_clock_id=seed.context.clock_id;
   trust_scope.publication_clock_authority=seed.context.clock_authority;
   SWV5S5_MvpManualProducerTrustProvisioner trust;
   if(!trust.Configure(path,namespace_digest) ||
      !trust.Provision(operator_invocation,seed.trust_anchor,trust_scope,
                       seed.context.clock_time,seed.current_trust))
   { Print("MVP_D1_E2E_SETUP_FAIL|TRUST|error=",GetLastError()); return false; }
   SWV5S5_ProducerTrustRecord persisted_trust; SWV5S5_ProducerTrustAnchor persisted_anchor;
   string persisted_operator,persisted_authentication; bool trust_found=false;
   status.trust_round_trip=trust.LoadCurrent(persisted_trust,persisted_anchor,persisted_operator,
      persisted_authentication,trust_found) && trust_found &&
      persisted_trust.record_digest==seed.current_trust.record_digest &&
      persisted_anchor.current_authority_record_id==seed.trust_anchor.current_authority_record_id &&
      persisted_anchor.current_authority_generation==seed.trust_anchor.current_authority_generation &&
      persisted_operator==operator_invocation.operator_id &&
      persisted_authentication==operator_invocation.authentication_reference;
   if(!status.trust_round_trip) { Print("MVP_D1_E2E_SETUP_FAIL|TRUST_READBACK"); return false; }
   SWV5S5_MvpAuthorityRow current_hard_kill; bool found=false; string payload,digest;
   if(!store.Open(path,namespace_digest) ||
      !store.ReadRow(SWV5S5_MVP_DOMAIN_HARD_KILL,"CURRENT",current_hard_kill,found) || !found ||
      !SWV5S5_CanonicalHardKillState("hard_kill",seed.hard_kill_state,payload) ||
      !SWV5S5_DomainDigest(SWV5S5_MVP_DOMAIN_HARD_KILL,payload,digest) ||
      !store.CompareAndSet(SWV5S5_MVP_DOMAIN_HARD_KILL,"CURRENT",current_hard_kill.logical_revision,
         current_hard_kill.store_revision,current_hard_kill.payload_digest,current_hard_kill.state,
          current_hard_kill.logical_revision+1,(int)SWV5_HARD_KILL_INACTIVE,digest,payload,
          seed.context.clock_time,committed))
   { Print("MVP_D1_E2E_SETUP_FAIL|HARD_KILL|error=",GetLastError()); return false; }
   SWV5S5_MvpAuthorityRow hard_kill_readback; bool hard_kill_found=false;
   status.hard_kill_valid=store.ReadRow(SWV5S5_MVP_DOMAIN_HARD_KILL,"CURRENT",
      hard_kill_readback,hard_kill_found) && hard_kill_found &&
      hard_kill_readback.state==(int)SWV5_HARD_KILL_INACTIVE &&
      hard_kill_readback.payload==payload && hard_kill_readback.payload_digest==digest;
   if(!status.hard_kill_valid) { Print("MVP_D1_E2E_SETUP_FAIL|HARD_KILL_READBACK"); return false; }
   store.Close();
   SWV5S5_MvpSignalIngressAdapter producer_sequence; ulong producer_high=0;
   SWV5S5_MvpProducerSequenceEntry producer_entries[];
   status.producer_sequence_initialized=producer_sequence.Configure(path,namespace_digest) &&
      producer_sequence.Initialize(seed.context.clock_time) &&
      producer_sequence.ReadState(producer_high,producer_entries) && producer_high==0 && ArraySize(producer_entries)==0;
   if(!status.producer_sequence_initialized) { Print("MVP_D1_E2E_SETUP_FAIL|PRODUCER_SEQUENCE"); return false; }
   SWV5S5_MvpRequestSequenceAuthority request_sequence; SWV5S5_RequestSequenceAuthority request_sequence_state;
   SWV5S5_RequestSequenceIndexEntry request_sequence_entries[];
   status.request_sequence_initialized=request_sequence.Configure(path,namespace_digest) &&
      request_sequence.Initialize(scope,seed.current_lease.fence,seed.context.clock_time) &&
      request_sequence.ReadState(request_sequence_state,request_sequence_entries) &&
      SWV5S5_IsCandidateVersion(request_sequence_state.contract_version) &&
      request_sequence_state.request_sequence_high_watermark==0 && ArraySize(request_sequence_entries)==0;
   if(!status.request_sequence_initialized) { Print("MVP_D1_E2E_SETUP_FAIL|REQUEST_SEQUENCE"); return false; }
   SWV5S5_MvpIngressLedgerAuthority ledger; SWV5S5_IngressLedgerHeader ledger_header;
   SWV5S5_IngressLedgerIndexEntry ledger_entries[]; SWV5S5_IngressLedgerRecord ledger_records[];
   status.ledger_initialized=ledger.Configure(path,namespace_digest) &&
      ledger.Initialize(scope,seed.current_lease.fence,seed.current_trust,seed.context.clock_time) &&
      ledger.ReadSnapshot(ledger_header,ledger_entries,ledger_records) &&
      SWV5S5_IsCandidateVersion(ledger_header.contract_version) &&
      ArraySize(ledger_entries)==0 && ArraySize(ledger_records)==0;
   if(!status.ledger_initialized) { Print("MVP_D1_E2E_SETUP_FAIL|LEDGER"); return false; }
   SWV5S5_MvpRequestSetPublicationAuthority request_set; SWV5S5_RequestSetPublicationAuthority request_authority;
   SWV5_PendingRequest requests[];
   status.request_set_initialized=request_set.Configure(path,namespace_digest) &&
      request_set.Initialize(scope,seed.current_lease.fence,seed.context.clock_time) &&
      request_set.ReadState(request_authority,requests) &&
      SWV5S5_IsCandidateVersion(request_authority.contract_version) &&
      SWV5S5_IsV5Version(request_authority.current_set_header.contract_version) && ArraySize(requests)==0;
   if(!status.request_set_initialized) { Print("MVP_D1_E2E_SETUP_FAIL|REQUEST_SET"); return false; }
   return true;
}

bool SWV5S5_MvpD1BuildE2ESeed(const string path,SWV5S5_MvpControlledDemoAuthoritySeed &seed,
                               string &namespace_digest,SWV5S5_MvpD1PhysicalSeedStatus &status)
{
   ZeroMemory(seed); SWV5S5_MvpD1MakeContext(seed.context);
   SWV5S5_MvpInitProductionVersion(seed.context.expected_version);
   SWV5_PersistenceNamespace scope;
   SWV5S5_MvpD1MakeScope(scope,seed.current_lease,namespace_digest);
   SWV5_InitHeader(seed.engine_input.market.header,41,7,SWV5_EXECUTION_EVERY_TICK,
                   SWV5S5_MVP_SYMBOL,PERIOD_M15,seed.context.clock_time-1);
   seed.decision.header.engine_kind=SWV5_ENGINE_DECISION;
   seed.decision.header.health=SWV5_HEALTH_HEALTHY; seed.decision.header.valid=true;
   seed.decision.header.score=1.0; seed.decision.header.confidence=1.0;
   seed.decision.header.snapshot_sequence=seed.engine_input.market.header.sequence;
   seed.decision.header.history_generation=seed.engine_input.market.header.history_generation;
   seed.decision.action=SWV5_ACTION_BUY; seed.decision.direction=1; seed.decision.state="BUY";
   seed.decision.blocking_engine=SWV5_ENGINE_DECISION;
   SWV5_AccountRiskNamespace account_namespace;
   SWV5S5_MvpD1MakeAccountNamespace(scope,account_namespace);
   SWV5_TestMakeRiskInput(seed.risk_observation);
   SWV5S5_MvpInitProductionVersion(seed.risk_observation.contract_version);
   seed.risk_observation.account_namespace=account_namespace;
   seed.risk_observation.account_mode=SWV5_ACCOUNT_MODE_HEDGING;
   SWV5S5_MvpInitProductionVersion(seed.risk_observation.account.contract_version);
   seed.risk_observation.account.account_namespace=account_namespace;
   seed.risk_observation.account.balance=10000.0; seed.risk_observation.account.equity=10000.0;
   seed.risk_observation.account.margin=0.0; seed.risk_observation.account.free_margin=10000.0;
   seed.risk_observation.account.daily_realized_net=0.0; seed.risk_observation.account.daily_unrealized_net=0.0;
   seed.risk_observation.account.trading_day_start=seed.context.clock_time-3600;
   seed.risk_observation.account.observed_at=seed.context.clock_time;
   seed.risk_observation.account.authoritative=true;
   SWV5S5_MvpInitProductionVersion(seed.risk_observation.exposure.contract_version);
   seed.risk_observation.exposure.account_namespace=account_namespace;
   seed.risk_observation.exposure.symbol=SWV5S5_MVP_SYMBOL;
   seed.risk_observation.exposure.symbol_long_volume=0.0;
   seed.risk_observation.exposure.symbol_short_volume=0.0;
   seed.risk_observation.exposure.symbol_net_volume=0.0;
   seed.risk_observation.exposure.aggregate_volume=0.0;
   seed.risk_observation.exposure.aggregate_notional=0.0;
   seed.risk_observation.exposure.live_basket_count=0;
   seed.risk_observation.exposure.observed_at=seed.context.clock_time;
   seed.risk_observation.exposure.complete=true;
   SWV5S5_MvpInitProductionVersion(seed.risk_observation.basket.contract_version);
   seed.risk_observation.basket.account_namespace=account_namespace;
   SWV5_TestMakeLifecycle(seed.risk_observation.basket.lifecycle,SWV5_BASKET_IDLE);
   seed.risk_observation.basket.lifecycle.basket_id=scope.basket_id;
   seed.risk_observation.basket.lifecycle.ownership_fence=seed.current_lease.fence;
   seed.risk_observation.basket.lifecycle.state_version=1;
   seed.risk_observation.basket.lifecycle.cumulative_recovery_attempts=0;
   seed.risk_observation.basket.lifecycle.current_recovery_layer=0;
   seed.risk_observation.basket.lifecycle.state_entered_at=seed.context.clock_time-100;
   seed.risk_observation.basket.realized_net=0.0; seed.risk_observation.basket.unrealized_net=0.0;
   seed.risk_observation.basket.maximum_adverse_net=0.0;
   seed.risk_observation.basket.observed_at=seed.context.clock_time;
   SWV5S5_MvpInitProductionVersion(seed.risk_observation.projected.contract_version);
   seed.risk_observation.projected.account_namespace=account_namespace;
   SWV5_TestMakeMonetaryBasis(seed.risk_observation.projected.monetary_basis);
   seed.risk_observation.projected.monetary_basis.currency=SWV5S5_MVP_ACCOUNT_CURRENCY;
   seed.risk_observation.projected.monetary_basis.account_currency=SWV5S5_MVP_ACCOUNT_CURRENCY;
   seed.risk_observation.projected.monetary_basis.conversion_source=SWV5S5_MVP_CONVERSION_SOURCE;
   seed.risk_observation.projected.monetary_basis.valuation_at=seed.context.clock_time;
   SWV5_TestMakeHardKill(seed.hard_kill_state,SWV5_HARD_KILL_INACTIVE);
   seed.hard_kill_state.persistence_namespace=scope;
   seed.hard_kill_state.account_namespace=account_namespace;
   seed.hard_kill_state.latch_id="MVP-D1-HARD-KILL"; seed.hard_kill_state.latch_generation=1;
   seed.hard_kill_state.activation_reason=""; seed.hard_kill_state.activation_authority="";
   seed.hard_kill_state.activated_at=0; seed.hard_kill_state.release_generation=0;
   seed.risk_observation.hard_kill_state=seed.hard_kill_state;
   seed.risk_observation.ownership_fence=seed.current_lease.fence;
   seed.adapter_environment.broker_identity=scope.ownership_namespace.broker_identity;
   seed.adapter_environment.server=scope.ownership_namespace.server;
   seed.adapter_environment.account_login=scope.ownership_namespace.account_login;
   seed.adapter_environment.account_currency=SWV5S5_MVP_ACCOUNT_CURRENCY;
   seed.adapter_environment.symbol=SWV5S5_MVP_SYMBOL;
   seed.adapter_environment.terminal_build=5000; seed.adapter_environment.mql_build=5000;
   seed.adapter_environment.account_trade_mode=ACCOUNT_TRADE_MODE_DEMO;
   seed.adapter_environment.account_mode=SWV5_ACCOUNT_MODE_HEDGING;
   seed.adapter_environment.connected=true; seed.adapter_environment.terminal_trade_allowed=true;
   seed.adapter_environment.mql_trade_allowed=true; seed.adapter_environment.account_trade_allowed=true;
   seed.adapter_environment.account_trade_expert=true;
   seed.adapter_environment.symbol_trade_mode=SYMBOL_TRADE_MODE_FULL;
   seed.adapter_environment.symbol_execution_mode=SYMBOL_TRADE_EXECUTION_MARKET;
   seed.adapter_environment.symbol_filling_mask=1; seed.adapter_environment.symbol_digits=SWV5S5_MVP_DIGITS;
   seed.adapter_environment.point=SWV5S5_MVP_POINT_SIZE; seed.adapter_environment.tick_size=0.01;
   seed.adapter_environment.volume_min=0.01; seed.adapter_environment.volume_max=100.0;
   seed.adapter_environment.volume_step=0.01; seed.adapter_environment.runtime_magic=SWV5_RUNTIME_STRATEGY_MAGIC;
   seed.filling_mode=1; seed.comment_metadata="FUSION-V5-MVP-D1-OFFLINE";
   return SWV5S5_MvpD1ProvisionPhysicalSeed(path,namespace_digest,scope,seed,status);
}

void SWV5S5_MvpD1E2EAssertions(SWV5S5_MvpD1Collector &c)
{
   const string path="mvp_d1_physical_e2e_v1.sqlite"; string namespace_digest;
   SWV5S5_MvpControlledDemoAuthoritySeed seed;
   SWV5S5_MvpD1PhysicalSeedStatus seed_status;
   const bool seeded=SWV5S5_MvpD1BuildE2ESeed(path,seed,namespace_digest,seed_status);
   SWV5S5_MvpD1Record(c,"SEED-01-GENESIS",seed_status.genesis_valid);
   if(!seed_status.genesis_valid) return;
   SWV5S5_MvpD1Record(c,"SEED-02-LEASE-CLOCK",seed_status.lease_clock_valid);
   if(!seed_status.lease_clock_valid) return;
   SWV5S5_MvpD1Record(c,"SEED-03-LEASE-ROUND-TRIP",seed_status.lease_round_trip);
   if(!seed_status.lease_round_trip) return;
   SWV5S5_MvpD1Record(c,"SEED-04-TRUST-ROUND-TRIP",seed_status.trust_round_trip);
   if(!seed_status.trust_round_trip) return;
   SWV5S5_MvpD1Record(c,"SEED-05-HARD-KILL",seed_status.hard_kill_valid);
   if(!seed_status.hard_kill_valid) return;
   SWV5S5_MvpD1Record(c,"SEED-06-PRODUCER-SEQUENCE",seed_status.producer_sequence_initialized);
   if(!seed_status.producer_sequence_initialized) return;
   SWV5S5_MvpD1Record(c,"SEED-07-REQUEST-SEQUENCE",seed_status.request_sequence_initialized);
   if(!seed_status.request_sequence_initialized) return;
   SWV5S5_MvpD1Record(c,"SEED-08-LEDGER",seed_status.ledger_initialized);
   if(!seed_status.ledger_initialized) return;
   SWV5S5_MvpD1Record(c,"SEED-09-REQUEST-SET",seed_status.request_set_initialized);
   if(!seed_status.request_set_initialized) return;
   SWV5S5_MvpD1Record(c,"E2E-01-PHYSICAL-PRECONDITIONS",seeded);
   if(!seeded) return;
   SWV5S5_MvpD1ReadOnlyPlatform platform; SWV5S5_MvpBrokerEvidenceStore evidence_store;
   SWV5S5_MvpControlledDemoAuthorityPort port;
   const bool configured=seeded && evidence_store.Configure(path,namespace_digest) &&
      port.Configure(path,namespace_digest,seed,&platform,&evidence_store);
   SWV5S5_MvpControlledDemoInvocation invocation; SWV5S5_MvpControlledDemoDefaults(invocation);
   invocation.mode=MODE_D1_BUY; invocation.armed_for_demo_submission=true;
   invocation.operator_confirmed_before_claim=true;
   invocation.expected_broker_identity="APPROVED-DEMO-BROKER";
   invocation.expected_server="APPROVED-DEMO-SERVER"; invocation.expected_demo_account_login=123456;
   invocation.persistence_namespace_identity=namespace_digest; invocation.relative_store_path=path;
   invocation.source_head="144814cb5076851b8bf59a739fb865d9d9c1ab7d";
   invocation.requested_volume=0.01; invocation.requested_price=3500.00;
   invocation.protective_stop_price=3499.00; invocation.optional_take_profit_price=3501.00;
   SWV5S5_MvpD1NonMutatingBoundary boundary; SWV5S5_MvpControlledDemoRunner runner;
   SWV5S5_MvpControlledDemoResult result;
   const bool ran=configured && runner.Run(invocation,port,boundary,result);
   if(!ran) Print("MVP_D1_E2E_RUN_FAIL|reason=",result.stop_reason,
                  "|port_stage=",port.LastStage(),"|configured=",configured,
                  "|boundary_calls=",boundary.calls);
   SWV5S5_MvpD1Record(c,"E2E-02-CLAIM-GRANTED-NOW",ran && result.claim_granted_now);
   SWV5S5_MvpD1Record(c,"E2E-03-NON-MUTATING-SEAM-ONCE",ran && boundary.calls==1 &&
      result.adapter_invoked_same_event && result.broker_submission_calls==0 && !result.synchronous_result.invocation_attempted);
   SWV5S5_MvpIngressLedgerAuthority ledger; SWV5S5_IngressLedgerHeader header;
   SWV5S5_IngressLedgerIndexEntry ledger_entries[]; SWV5S5_IngressLedgerRecord ledger_records[];
   const bool ledger_ok=ledger.Configure(path,namespace_digest) &&
      ledger.ReadSnapshot(header,ledger_entries,ledger_records) && ArraySize(ledger_records)==1 &&
      ledger_records[0].lifecycle_state==SWV5S5_BOUND_TO_REQUEST &&
      ledger_records[0].reserved_request_sequence==1 && ledger_records[0].bound_request_id!="";
   SWV5S5_MvpD1Record(c,"E2E-04-LEDGER-BOUND",ledger_ok);
   SWV5S5_MvpRequestSetPublicationAuthority request_set; SWV5S5_RequestSetPublicationAuthority request_authority;
   SWV5_PendingRequest requests[];
   const bool request_ok=request_set.Configure(path,namespace_digest) &&
      request_set.ReadState(request_authority,requests) && ArraySize(requests)==1 &&
      requests[0].state==SWV5_REQUEST_SUBMISSION_PENDING &&
      requests[0].intent.request_identity.request_id.correlation_id==result.request_correlation_id;
   SWV5S5_MvpD1Record(c,"E2E-05-REQUEST-SET-ROUND-TRIP",request_ok);
   SWV5S5_MvpSqliteAuthorityStore store; SWV5S5_SubmissionAuthorityRecord submission; bool found=false;
   const bool claim_round_trip=store.Open(path,namespace_digest) &&
      SWV5S5_MvpLoadSubmissionAuthority(store,result.request_correlation_id,result.attempt_id,submission,found) && found &&
      submission.state==SWV5S5_INVOCATION_CLAIMED_UNRESOLVED &&
      submission.invocation_claim_id!="" && submission.durable_record_digest!="";
   SWV5S5_MvpD1Record(c,"E2E-06-PERMIT-CLAIM-ROUND-TRIP",claim_round_trip);
   SWV5S5_MvpD1Record(c,"E2E-07-IDENTITY-CONTINUITY",ran && request_ok && claim_round_trip &&
      submission.permit.request_identity.request_id.correlation_id==result.request_correlation_id &&
      submission.permit.request_identity.request_id.attempt_id==result.attempt_id &&
      submission.permit.request_identity.request_id.monotonic_sequence==1);
   SWV5S5_MvpD1Record(c,"E2E-08-ZERO-BROKER-MUTATION",boundary.calls==1 &&
      runner.BrokerSubmissionCalls()==0 && result.broker_submission_calls==0);

   SWV5S5_MvpSignalIngressAdapter ingress_adapter; SWV5S5_IngressEnvelope ingress; bool ingress_replayed=false;
   const bool ingress_loaded=ingress_adapter.Configure(path,namespace_digest) &&
      ingress_adapter.Publish(seed.engine_input,seed.decision,seed.current_trust,seed.context,ingress,ingress_replayed) &&
      ingress_replayed;
   SWV5S5_ProducerTrustScope trust_scope; ZeroMemory(trust_scope);
   trust_scope.persistence_namespace=seed.current_trust.persistence_namespace;
   trust_scope.producer_component=seed.current_trust.producer_component;
   trust_scope.producer_instance=seed.current_trust.producer_instance;
   trust_scope.producer_epoch=seed.current_trust.producer_epoch;
   trust_scope.symbol=seed.current_trust.symbol; trust_scope.timeframe=seed.current_trust.timeframe;
   trust_scope.execution_mode=seed.current_trust.execution_mode;
   trust_scope.publication_clock_id=seed.current_trust.clock_id;
   trust_scope.publication_clock_authority=seed.current_trust.clock_authority;
   trust_scope.ingress_identity=ingress.ingress_identity;
   SWV5S5_IngressFreshnessPolicy freshness; ZeroMemory(freshness);
   freshness.policy_id=SWV5S5_POLICY_ID; freshness.clock_id=seed.context.clock_id;
   freshness.clock_authority=seed.context.clock_authority; freshness.max_age_seconds=5;
   freshness.max_future_skew_seconds=0;
   SWV5S5_IngressValidationResult ingress_validation;
   const bool ingress_valid=ingress_loaded && SWV5S5_ValidateTrustedIngressForAcceptance(seed.context,
      ingress,freshness,seed.current_trust,seed.trust_anchor,trust_scope,ingress_validation);

   SWV5_PendingRequest request; ZeroMemory(request);
   if(ArraySize(requests)==1) request=requests[0];
   SWV5S5_MvpExecutionLifecycleAuthority lifecycle; SWV5_ContractDecision intent_decision;
   const bool intent_valid=request_ok && lifecycle.ValidateIntent(seed.context,request.intent,intent_decision);
   string request_canonical;
   const bool pending_valid=request_ok && SWV5S5_IsV5Version(request.contract_version) &&
      SWV5S5_CanonicalPendingRequest(request,request_canonical) && request_canonical!="";
   const SWV5S5_AdmissionAuthorityCollection collect=submission.admission_snapshot.collect_v2;
   SWV5S5_MvpUnitSystemContract unit_contract; SWV5_UnitValidationResult unit_validation;
   const bool unit_valid=claim_round_trip && SWV5S5_IsV5Version(submission.permit.normalized_payload.contract_version) &&
      SWV5S5_IsV5Version(collect.symbol_specification.specification.contract_version) &&
      unit_contract.ValidateSpecification(seed.context,collect.symbol_specification.specification,unit_validation);
   SWV5S5_MvpRiskContract risk_contract; SWV5_ContractDecision risk_decision;
   const bool risk_valid=claim_round_trip &&
      SWV5S5_IsV5Version(submission.permit.risk_authorization.contract_version) &&
      SWV5S5_IsV5Version(collect.risk_authorization.current_binding.contract_version) &&
      SWV5S5_IsV5Version(collect.risk_authorization.current_binding.limits.contract_version) &&
      risk_contract.ValidateLimits(seed.context,collect.risk_authorization.current_binding.limits,risk_decision) &&
      risk_contract.ValidateAuthorization(seed.context,submission.permit.risk_authorization,
         collect.risk_authorization.current_binding,risk_decision);
   string margin_digest,basket_digest;
   const bool authority_versions=claim_round_trip &&
      SWV5S5_IsV5Version(submission.permit.margin_authority.contract_version) &&
      SWV5S5_IsV5Version(submission.permit.basket_risk_authority.contract_version) &&
      SWV5S5_IsV5Version(collect.risk_authorization.current_binding.projected.monetary_basis.contract_version) &&
      SWV5S5_MvpDeriveMarginAuthorityDigest(submission.permit.margin_authority,margin_digest) &&
      margin_digest==submission.permit.margin_authority.authority_record_digest &&
      SWV5S5_MvpDeriveBasketRiskAuthorityDigest(submission.permit.basket_risk_authority,basket_digest) &&
      basket_digest==submission.permit.basket_risk_authority.authority_record_digest;
   SWV5S5_MvpRequestSequenceAuthority sequence; SWV5S5_RequestSequenceAuthority sequence_state;
   SWV5S5_RequestSequenceIndexEntry sequence_entries[];
   const bool sequence_valid=sequence.Configure(path,namespace_digest) &&
      sequence.ReadState(sequence_state,sequence_entries) &&
      SWV5S5_IsCandidateVersion(sequence_state.contract_version) &&
      sequence_state.request_sequence_high_watermark==1 && ArraySize(sequence_entries)==1;
   string ledger_digest;
   const bool ledger_valid=ledger_ok && SWV5S5_IsCandidateVersion(header.contract_version) &&
      SWV5S5_IsCandidateVersion(ledger_records[0].contract_version) &&
      SWV5S5_DeriveLedgerRecordDigest(ledger_records[0],ledger_digest) &&
      ledger_digest==ledger_records[0].record_digest;
   const bool wrapper_versions=claim_round_trip &&
      SWV5S5_IsCandidateVersion(submission.contract_version) &&
      SWV5S5_IsCandidateVersion(submission.permit.contract_version) &&
      SWV5S5_IsCandidateVersion(submission.admission_snapshot.contract_version) &&
      SWV5S5_IsCandidateVersion(request_authority.contract_version) &&
      SWV5S5_IsV5Version(request_authority.current_set_header.contract_version);

   SWV5S5_RequestBinding binding; SWV5_ExecutionRequestIdentity rebuilt_identity;
   const bool binding_ready=ingress_valid && ledger_valid &&
      SWV5S5_MvpBuildRequestBindingSeed(seed.current_trust.persistence_namespace,ingress.ingress_identity,
         ledger_records[0].accepted_at,ledger_records[0].reserved_request_sequence,binding,rebuilt_identity);
   SWV5S5_CoordinatorMaterializationInput materialization; ZeroMemory(materialization);
   materialization.event_id="D1-BOOTSTRAP"; materialization.event_ordinal=1;
   materialization.context=seed.context; materialization.accepted_ingress=ingress;
   materialization.ledger.disposition=SWV5S5_INGRESS_EVALUATION_NEW;
   materialization.ledger.header=header; materialization.ledger.matched_record=ledger_records[0];
   materialization.ledger.matched_index=0; materialization.ledger.reason_code="LEDGER_ACCEPTED_NEW";
   materialization.normalized_payload=submission.permit.normalized_payload;
   materialization.normalization_identity=submission.permit.normalization_identity;
   materialization.risk_authorization=submission.permit.risk_authorization;
   SWV5S5_MvpBlueprintAuthority blueprint_authority; SWV5S5_InitialRequestBlueprint blueprint;
   SWV5S5_ValidationResult blueprint_validation;
   const bool blueprint_valid=binding_ready && blueprint_authority.BuildInitial(materialization,binding,blueprint) &&
      SWV5S5_ValidateInitialBlueprint(seed.context,blueprint,ingress,ledger_records[0],
         submission.permit.normalized_payload,submission.permit.normalization_identity,
         submission.permit.risk_authorization,blueprint_validation);

   SWV5S5_MvpD1Record(c,"VER-01-LEASE-PRODUCTION-V5",seeded &&
      SWV5S5_IsV5Version(seed.current_lease.contract_version) &&
      SWV5S5_IsV5Version(seed.current_lease.fence.contract_version));
   SWV5S5_MvpD1Record(c,"VER-02-REQUEST-IDENTITY-PRODUCTION-V5",request_ok &&
      SWV5S5_IsV5Version(request.intent.request_identity.contract_version));
   SWV5S5_MvpD1Record(c,"VER-03-INTENT-PRODUCTION-V5-VALIDATED",intent_valid &&
      SWV5S5_IsV5Version(request.intent.contract_version));
   SWV5S5_MvpD1Record(c,"VER-04-PENDING-PRODUCTION-V5-CANONICAL",pending_valid);
   SWV5S5_MvpD1Record(c,"VER-05-UNIT-SPEC-PRODUCTION-V5-VALIDATED",unit_valid);
   SWV5S5_MvpD1Record(c,"VER-06-RISK-PRODUCTION-V5-VALIDATED",risk_valid);
   SWV5S5_MvpD1Record(c,"VER-07-AUTHORITY-PRODUCTION-V5-DIGESTS",authority_versions);
   SWV5S5_MvpD1Record(c,"VER-08-INGRESS-CANDIDATE-VALIDATED",ingress_valid &&
      SWV5S5_IsCandidateVersion(ingress.contract_version));
   SWV5S5_MvpD1Record(c,"VER-09-SEQUENCE-CANDIDATE-ROUND-TRIP",sequence_valid);
   SWV5S5_MvpD1Record(c,"VER-10-LEDGER-CANDIDATE-ROUND-TRIP",ledger_valid);
   SWV5S5_MvpD1Record(c,"VER-11-WRAPPER-CANDIDATE-NESTED-V5",wrapper_versions);
   SWV5S5_MvpD1Record(c,"VER-12-FROZEN-BLUEPRINT-VALIDATOR",blueprint_valid);

   string bound_request_id;
   const bool bound_id_ready=request_ok && SWV5S5_MvpDeriveBoundRequestId(request.intent.request_identity,bound_request_id);
   SWV5S5_MvpD1Record(c,"REL-01-INGRESS-LEDGER",ingress_valid && ledger_valid &&
      ingress.ingress_identity==ledger_records[0].ingress_identity &&
      ingress.payload_digest==ledger_records[0].payload_digest);
   SWV5S5_MvpD1Record(c,"REL-02-LEDGER-BINDING",binding_ready &&
      binding.logical_correlation_id==ledger_records[0].logical_correlation_id &&
      binding.logical_request_sequence==ledger_records[0].reserved_request_sequence);
   SWV5S5_MvpD1Record(c,"REL-03-BINDING-REQUEST",binding_ready && request_ok &&
      SWV5S5_EqualRequestIdentity(rebuilt_identity,request.intent.request_identity));
   SWV5S5_MvpD1Record(c,"REL-04-REQUEST-PERMIT",request_ok && claim_round_trip &&
      SWV5S5_EqualRequestIdentity(request.intent.request_identity,submission.permit.request_identity));
   SWV5S5_MvpD1Record(c,"REL-05-PERMIT-RISK",claim_round_trip &&
      SWV5S5_EqualRequestIdentity(submission.permit.request_identity,
         submission.permit.risk_authorization.request_identity));
   SWV5S5_MvpD1Record(c,"REL-06-REQUEST-NORMALIZED",request_ok && claim_round_trip &&
      request.intent.normalized_volume==submission.permit.normalized_payload.volume &&
      request.intent.normalized_price==submission.permit.normalized_payload.price &&
      request.intent.symbol_specification_sequence==submission.permit.normalized_payload.specification_sequence);
   SWV5S5_MvpD1Record(c,"REL-07-MARGIN-BASKET-IDENTITY",claim_round_trip &&
      SWV5S5_EqualRequestIdentity(submission.permit.request_identity,submission.permit.margin_authority.request_identity) &&
      SWV5S5_EqualRequestIdentity(submission.permit.request_identity,submission.permit.basket_risk_authority.request_identity));
   SWV5S5_MvpD1Record(c,"REL-08-REQUEST-SET-COMPLETE",request_ok &&
      request_authority.current_set_header.request_count==1 &&
      request_authority.current_set_header.request_set_digest==request_authority.current_complete_set_digest);
   SWV5S5_MvpD1Record(c,"REL-09-ADMISSION-PERMIT",claim_round_trip &&
      submission.admission_snapshot.collect_v2.submission_permit.permit.permit_digest==submission.permit.permit_digest);
   SWV5S5_MvpD1Record(c,"REL-10-ADMISSION-REQUEST",claim_round_trip &&
      ArraySize(submission.admission_snapshot.collect_v2.request_set.requests)==1 &&
      SWV5S5_EqualRequestIdentity(submission.admission_snapshot.collect_v2.request_set.requests[0].intent.request_identity,
                                  submission.permit.request_identity));
   SWV5S5_MvpD1Record(c,"REL-11-CLAIM-OWNERSHIP",claim_round_trip &&
      SWV5S5_EqualFence(submission.claim_ownership_lease.fence,submission.permit.ownership_fence));
   SWV5S5_MvpD1Record(c,"REL-12-BOUND-ID",bound_id_ready && ledger_valid &&
      ledger_records[0].bound_request_id==bound_request_id);
}

void SWV5S5_RunMvpD1AuthorityAssertions(SWV5S5_MvpD1Collector &c)
{
   ZeroMemory(c); c.signature=1469598103934665603;
   SWV5_ContractValidationContext context; SWV5S5_MvpD1MakeContext(context);
   SWV5_PersistenceNamespace scope; SWV5_TestMakeNamespace(scope);
   SWV5_OwnershipFence fence; SWV5_TestMakeFence(fence);
   scope.ownership_namespace=fence.ownership_namespace;
   const string namespace_digest="d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1";
   const string path="mvp_d1_authorities_v1.sqlite";
   FileDelete(path,FILE_COMMON); FileDelete(path+"-wal",FILE_COMMON); FileDelete(path+"-shm",FILE_COMMON);
   SWV5S5_MvpD1SignalAssertions(c,path,namespace_digest);
   string payload_digest; SWV5S5_SHA256("AUTHENTIC-INGRESS-PAYLOAD",payload_digest);
   string correlation,attempt,idempotency;
   const bool correlation_ok=SWV5S5_DeriveRequestBinding(scope,SWV5S5_REQUEST_BINDING_POLICY_ID,
      SWV5S5_REQUEST_BINDING_POLICY_VERSION,"INGRESS-A",0,correlation,attempt,idempotency);

   SWV5S5_MvpRequestSequenceAuthority sequence;
   const bool sequence_ready=sequence.Configure(path,namespace_digest) && sequence.Initialize(scope,fence,context.clock_time);
   SWV5S5_RequestSequenceAuthority sequence_state; SWV5S5_RequestSequenceIndexEntry sequence_entries[];
   const bool sequence_loaded=sequence_ready && sequence.ReadState(sequence_state,sequence_entries);
   SWV5S5_RequestSequenceReservation reservation_proposal; SWV5S5_RequestSequenceResult reservation_result;
   const bool proposal_ok=sequence_loaded && correlation_ok && SWV5S5_MvpD1PrepareReservation(sequence_state,sequence_entries,
      correlation,payload_digest,reservation_proposal);
   const bool reserved=proposal_ok && sequence.TryReserveRequestSequence(sequence_state,sequence_entries,
      reservation_proposal,reservation_result);
   SWV5S5_MvpD1Record(c,"BOOT-01",reserved && reservation_result.reserved_sequence==1);
   SWV5S5_MvpD1Record(c,"BOOT-02",reservation_proposal.binding_digest==payload_digest);

   SWV5S5_RequestSequenceAuthority after_sequence; SWV5S5_RequestSequenceIndexEntry after_entries[];
   SWV5S5_RequestSequenceReservation replay_proposal; SWV5S5_RequestSequenceResult replay_result;
   const bool replayed=reserved && sequence.ReadState(after_sequence,after_entries) &&
      SWV5S5_MvpD1PrepareReservation(after_sequence,after_entries,correlation,payload_digest,replay_proposal) &&
      sequence.TryReserveRequestSequence(after_sequence,after_entries,replay_proposal,replay_result);
   SWV5S5_MvpD1Record(c,"BOOT-03",replayed && replay_result.disposition==SWV5S5_SEQUENCE_EXISTING_IDEMPOTENT &&
      replay_result.reserved_sequence==reservation_result.reserved_sequence);

   SWV5S5_RequestBinding binding; SWV5_ExecutionRequestIdentity identity;
   const bool binding_ok=SWV5S5_MvpBuildRequestBindingSeed(scope,"INGRESS-A",context.clock_time,
      reservation_result.reserved_sequence,binding,identity);
   SWV5S5_MvpD1Record(c,"BOOT-04",binding_ok && identity.request_id.correlation_id==binding.logical_correlation_id &&
      identity.request_id.attempt_id==binding.attempt_id && identity.request_id.monotonic_sequence==binding.logical_request_sequence &&
      identity.request_id.created_at==binding.accepted_at && identity.idempotency_key==binding.idempotency_key);
   SWV5S5_MvpD1Record(c,"BOOT-05",binding_ok && identity.request_id.monotonic_sequence>0);

   SWV5_RiskEvaluationInput risk; SWV5S5_MvpD1MakeAllowedRisk(context,risk);
   risk.intent.request_identity=identity; risk.margin_authority_record.request_identity=identity;
   risk.basket_risk_authority_record.request_identity=identity;
   risk.margin_authority_record.authority_record_digest="";
   SWV5S5_MvpDeriveMarginAuthorityDigest(risk.margin_authority_record,risk.margin_authority_record.authority_record_digest);
   risk.basket_risk_authority_record.authority_record_digest="";
   SWV5S5_MvpDeriveBasketRiskAuthorityDigest(risk.basket_risk_authority_record,risk.basket_risk_authority_record.authority_record_digest);
   string risk_id,risk_id_again;
   const bool risk_id_ok=SWV5S5_MvpDeriveRiskAuthorizationId(risk,risk_id) && SWV5S5_MvpDeriveRiskAuthorizationId(risk,risk_id_again);
   SWV5S5_MvpD1Record(c,"BOOT-06",risk.margin_authority_record.request_identity.request_id.attempt_id==identity.request_id.attempt_id);
   SWV5S5_MvpD1Record(c,"BOOT-07",risk.basket_risk_authority_record.request_identity.request_id.attempt_id==identity.request_id.attempt_id);
   SWV5S5_MvpD1Record(c,"BOOT-08",risk_id_ok && risk_id==risk_id_again && SWV5S5_IsDigest64Lower(risk_id));
   SWV5_RiskEvaluationInput changed=risk; changed.intent.request_identity.request_id.attempt_id="CHANGED"; string changed_id;
   SWV5S5_MvpD1Record(c,"BOOT-09",SWV5S5_MvpDeriveRiskAuthorizationId(changed,changed_id) && changed_id!=risk_id);
   changed=risk; changed.intent.normalized_volume=0.009; SWV5S5_MvpD1Record(c,"BOOT-10",
      SWV5S5_MvpDeriveRiskAuthorizationId(changed,changed_id) && changed_id!=risk_id);
   changed=risk; changed.margin_authority_record.authority_record_digest="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
   SWV5S5_MvpD1Record(c,"BOOT-11",SWV5S5_MvpDeriveRiskAuthorizationId(changed,changed_id) && changed_id!=risk_id);
   changed=risk; changed.basket_risk_authority_record.authority_record_digest="bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb";
   SWV5S5_MvpD1Record(c,"BOOT-12",SWV5S5_MvpDeriveRiskAuthorizationId(changed,changed_id) && changed_id!=risk_id);
   changed=risk; changed.hard_kill_state.latch_generation++;
   SWV5S5_MvpD1Record(c,"BOOT-13",SWV5S5_MvpDeriveRiskAuthorizationId(changed,changed_id) && changed_id!=risk_id);
   SWV5S5_MvpRiskContract risk_contract; SWV5_RiskAuthorization authorization;
   risk.intent.risk_authorization_id="ARBITRARY";
   SWV5S5_MvpD1Record(c,"BOOT-14",!risk_contract.Evaluate(context,risk,authorization));
   SWV5S5_ProducerTrustRecord denial_trust; ZeroMemory(denial_trust);
   denial_trust.authority_record_id="TRUST-1"; denial_trust.authority_generation=1;
   denial_trust.producer_instance="FUSION-V5-DECISION"; denial_trust.producer_epoch=1;
   SWV5S5_MvpIngressLedgerAuthority denied_ledger;
   const bool denied_ledger_empty=denied_ledger.Configure(path,namespace_digest) &&
      denied_ledger.Initialize(scope,fence,denial_trust,context.clock_time);
   SWV5S5_IngressLedgerHeader denied_header; SWV5S5_IngressLedgerIndexEntry denied_entries[];
   SWV5S5_IngressLedgerRecord denied_records[];
   const bool no_ledger_after_denial=denied_ledger_empty && denied_ledger.ReadSnapshot(denied_header,denied_entries,denied_records) &&
      ArraySize(denied_records)==0;
   SWV5S5_MvpD1Record(c,"BOOT-15",no_ledger_after_denial);
   SWV5S5_MvpRequestSetPublicationAuthority denied_request_set;
   SWV5S5_RequestSetPublicationAuthority denied_request_authority; SWV5_PendingRequest denied_requests[];
   const bool no_request_after_denial=denied_request_set.Configure(path,namespace_digest) &&
      denied_request_set.Initialize(scope,fence,context.clock_time) &&
      denied_request_set.ReadState(denied_request_authority,denied_requests) && ArraySize(denied_requests)==0;
   SWV5S5_MvpD1Record(c,"BOOT-16",no_request_after_denial);
   SWV5S5_MvpSqliteAuthorityStore denied_store; SWV5S5_MvpAuthorityRow denied_row; bool denied_found=false;
   string denied_submission_key; SWV5S5_MvpSubmissionRecordKey(correlation,attempt,denied_submission_key);
   const bool no_permit_or_claim_after_denial=denied_store.Open(path,namespace_digest) &&
      denied_store.ReadRow(SWV5S5_MVP_DOMAIN_SUBMISSION,denied_submission_key,denied_row,denied_found) && !denied_found;
   SWV5S5_MvpD1Record(c,"BOOT-17",no_permit_or_claim_after_denial);
   SWV5S5_MvpD1Record(c,"BOOT-18",replayed && replay_result.reserved_sequence==1);
   SWV5_ContractValidationContext trust_context; SWV5S5_ProducerTrustRecord current_trust;
   SWV5S5_ProducerTrustAnchor trust_anchor; SWV5S5_ProducerTrustScope trust_scope; SWV5S5_IngressEnvelope trusted_ingress;
   SWV5S5_ValidationResult trust_validation;
   SWV5S5_TestContext(trust_context,1000,3);
   SWV5_PersistenceNamespace trust_namespace; SWV5_OwnershipFence trust_fence;
   SWV5S5_TestScope(trust_namespace,trust_fence);
   const bool trust_ingress_ready=SWV5S5_TestIngress(trust_namespace,trusted_ingress);
   ZeroMemory(current_trust); SWV5S5_InitContractVersion(current_trust.contract_version);
   current_trust.authority_record_id="TRUST-A"; current_trust.authority_generation=5;
   current_trust.issuer_identity="TRUST-ISSUER"; current_trust.issuer_policy_id="TRUST-POLICY";
   current_trust.producer_component="DECISION"; current_trust.producer_instance="PRODUCER-A";
   current_trust.producer_epoch=6; current_trust.persistence_namespace=trust_namespace;
   current_trust.symbol="XAUUSD"; current_trust.timeframe=15; current_trust.execution_mode=1;
   current_trust.clock_id="TEST-CLOCK"; current_trust.clock_authority=SWV5_TIME_AUTHORITY_TEST_FIXTURE;
   current_trust.status=SWV5S5_TRUST_AUTHORIZED; current_trust.valid_from=900; current_trust.valid_until=1100;
   current_trust.superseding_record_id=""; current_trust.superseding_generation=0;
   ZeroMemory(trust_anchor); trust_anchor.issuer_identity=current_trust.issuer_identity;
   trust_anchor.issuer_policy_id=current_trust.issuer_policy_id; trust_anchor.trust_anchor_id="ANCHOR-A";
   trust_anchor.current_authority_record_id=current_trust.authority_record_id;
   trust_anchor.current_authority_generation=current_trust.authority_generation;
   ZeroMemory(trust_scope); trust_scope.persistence_namespace=trust_namespace;
   trust_scope.producer_component=current_trust.producer_component;
   trust_scope.producer_instance=current_trust.producer_instance; trust_scope.producer_epoch=current_trust.producer_epoch;
   trust_scope.symbol=current_trust.symbol; trust_scope.timeframe=current_trust.timeframe;
   trust_scope.execution_mode=current_trust.execution_mode; trust_scope.publication_clock_id=current_trust.clock_id;
   trust_scope.publication_clock_authority=current_trust.clock_authority;
   trust_scope.ingress_identity=trusted_ingress.ingress_identity;
   string trust_digest_check,trust_ingress_check,trust_payload_check;
   const bool trust_digest_ready=SWV5S5_DeriveProducerTrustDigest(current_trust,current_trust.record_digest) &&
      SWV5S5_DeriveProducerTrustDigest(current_trust,trust_digest_check);
   const bool trust_identity_ready=SWV5S5_DeriveIngressIdentityAndDigest(trusted_ingress,trust_ingress_check,trust_payload_check);
   const bool trust_fixture=trust_ingress_ready && trust_digest_ready && trust_identity_ready &&
      SWV5S5_ValidateProducerTrust(trust_context,current_trust,trust_anchor,trust_scope,trusted_ingress,trust_validation);
   SWV5S5_ProducerTrustRecord revoked_trust=current_trust; revoked_trust.status=SWV5S5_TRUST_REVOKED;
   revoked_trust.superseding_record_id=""; revoked_trust.superseding_generation=0;
   const bool revoked_digest_ready=trust_fixture &&
      SWV5S5_DeriveProducerTrustDigest(revoked_trust,revoked_trust.record_digest);
   const bool revoked_rejected=revoked_digest_ready &&
      !SWV5S5_ValidateProducerTrust(trust_context,revoked_trust,trust_anchor,trust_scope,trusted_ingress,trust_validation);
   SWV5S5_MvpD1Record(c,"BOOT-19",trust_fixture && revoked_digest_ready && revoked_rejected && no_ledger_after_denial);

   SWV5S5_ProducerTrustRecord trust; ZeroMemory(trust); trust.authority_record_id="TRUST-1";
   trust.authority_generation=1; trust.producer_instance="FUSION-V5-DECISION"; trust.producer_epoch=1;
   SWV5S5_MvpIngressLedgerAuthority ledger;
   const bool ledger_ready=ledger.Configure(path,namespace_digest) && ledger.Initialize(scope,fence,trust,context.clock_time);
   SWV5S5_IngressLedgerHeader ledger_header; SWV5S5_IngressLedgerIndexEntry ledger_entries[]; SWV5S5_IngressLedgerRecord ledger_records[];
   SWV5S5_IngressLedgerProposal ledger_proposal; SWV5S5_ValidationResult ledger_result;
   const bool ledger_loaded=ledger_ready && ledger.ReadSnapshot(ledger_header,ledger_entries,ledger_records);
   const bool ledger_prepared=ledger_loaded && SWV5S5_MvpD1PrepareLedgerProposal(ledger_header,"INGRESS-A",payload_digest,1,correlation,1,context.clock_time,ledger_proposal);
   const bool ledger_committed=ledger_prepared && ledger.TryCommitAcceptance(ledger_header,ledger_entries,ledger_records,ledger_proposal,ledger_result);
   SWV5S5_MvpD1Record(c,"BOOT-20",ledger_committed && ledger_result.disposition==SWV5_DISPOSITION_ALLOW &&
      ledger_header.policy_id==SWV5S5_POLICY_ID);

   string bound_id,bound_same; const bool bound_ok=SWV5S5_MvpDeriveBoundRequestId(identity,bound_id) &&
      SWV5S5_MvpDeriveBoundRequestId(identity,bound_same);
   SWV5S5_MvpD1Record(c,"BOUND-01",bound_ok && bound_id==bound_same);
   SWV5S5_MvpD1Record(c,"BOUND-02",bound_ok && SWV5S5_IsDigest64Lower(bound_id));
   SWV5_ExecutionRequestIdentity changed_identity=identity; changed_identity.request_id.attempt_id="ATT-CHANGED";
   SWV5S5_MvpD1Record(c,"BOUND-03",SWV5S5_MvpDeriveBoundRequestId(changed_identity,changed_id) && changed_id!=bound_id);
   changed_identity=identity; changed_identity.request_id.correlation_id="CORR-CHANGED";
   SWV5S5_MvpD1Record(c,"BOUND-04",SWV5S5_MvpDeriveBoundRequestId(changed_identity,changed_id) && changed_id!=bound_id);
   changed_identity=identity; changed_identity.request_id.monotonic_sequence++;
   SWV5S5_MvpD1Record(c,"BOUND-05",SWV5S5_MvpDeriveBoundRequestId(changed_identity,changed_id) && changed_id!=bound_id);
   changed_identity=identity; changed_identity.request_id.created_at++;
   SWV5S5_MvpD1Record(c,"BOUND-06",SWV5S5_MvpDeriveBoundRequestId(changed_identity,changed_id) && changed_id!=bound_id);
   changed_identity=identity; changed_identity.idempotency_key="IDEMP-CHANGED";
   SWV5S5_MvpD1Record(c,"BOUND-07",SWV5S5_MvpDeriveBoundRequestId(changed_identity,changed_id) && changed_id!=bound_id);
   SWV5S5_MvpD1Record(c,"BOUND-08",bound_id!=identity.request_id.attempt_id);
   SWV5S5_MvpD1Record(c,"BOUND-09",bound_id!=identity.request_id.correlation_id);

   SWV5S5_MvpRequestSetPublicationAuthority request_set;
   const bool request_set_ready=request_set.Configure(path,namespace_digest) && request_set.Initialize(scope,fence,context.clock_time);
   SWV5S5_RequestSetPublicationAuthority request_authority; SWV5_PendingRequest current_requests[];
   SWV5_PendingRequest proposed_requests[]; ArrayResize(proposed_requests,1); SWV5_TestMakePending(proposed_requests[0]);
   proposed_requests[0].intent.request_identity=identity; proposed_requests[0].intent.persistence_namespace=scope;
   proposed_requests[0].intent.ownership_fence=fence; proposed_requests[0].last_changed_at=context.clock_time;
   SWV5S5_RequestSetPublicationProposal publication; ZeroMemory(publication); SWV5S5_InitContractVersion(publication.contract_version);
   const bool publication_prepared=request_set_ready && request_set.ReadState(request_authority,current_requests) &&
      (publication.policy_id=SWV5S5_PUBLICATION_POLICY_ID)!="";
   publication.policy_version=SWV5S5_PUBLICATION_POLICY_VERSION; publication.persistence_namespace=scope;
   publication.expected_ownership_fence=fence; publication.expected_takeover_generation=fence.takeover_generation;
   publication.expected_store_revision=request_authority.store_revision;
   publication.expected_request_set_revision=request_authority.current_set_header.request_index_revision;
   publication.expected_request_set_digest=request_authority.current_complete_set_digest;
   publication.expected_record_sequence=request_authority.current_set_header.record_sequence;
   SWV5S5_SHA256("REQUEST-SET-STORE-REVISION-1",publication.proposed_store_revision);
   SWV5S5_MvpInitV5Version(publication.proposed_set_header.contract_version);
   publication.proposed_set_header.request_index_revision="REQUEST-SET-REVISION-1";
   publication.proposed_set_header.record_sequence=1; publication.proposed_set_header.request_count=1;
   SWV5S5_DeriveCompleteRequestSetDigest(proposed_requests,publication.proposed_set_header.request_set_digest);
   publication.proposed_complete_set_digest=publication.proposed_set_header.request_set_digest;
   SWV5S5_DeriveRequestSetProposalDigest(publication,publication.proposal_digest);
   SWV5S5_FencedPublicationResult publication_result;
   const bool published=publication_prepared && request_set.TryPublishRequestSet(publication,proposed_requests,publication_result);
   SWV5_PendingRequest readback;
   const bool exact_readback=published && request_set.FindExactBoundRequest(bound_id,proposed_requests[0],readback);
   SWV5S5_MvpD1Record(c,"BOUND-10",exact_readback);
   SWV5S5_IngressLedgerRecord bound_record;
   const bool transitioned=exact_readback && ledger.TransitionBound("INGRESS-A",identity,context.clock_time,bound_record);
   SWV5S5_MvpD1Record(c,"BOUND-11",transitioned && bound_record.record_sequence==ledger_proposal.proposed_record.record_sequence);
   SWV5S5_MvpD1Record(c,"BOUND-12",transitioned && bound_record.bound_request_id==bound_id);
   SWV5_ExecutionRequestIdentity wrong_identity=identity; wrong_identity.request_id.attempt_id="WRONG";
   SWV5S5_IngressLedgerRecord wrong_bound;
   SWV5S5_MvpD1Record(c,"BOUND-13",!ledger.TransitionBound("INGRESS-A",wrong_identity,context.clock_time,wrong_bound));
   SWV5S5_MvpIngressLedgerAuthority restarted_ledger; SWV5S5_IngressLedgerHeader restarted_header;
   SWV5S5_IngressLedgerIndexEntry restarted_entries[]; SWV5S5_IngressLedgerRecord restarted_records[];
   SWV5S5_MvpRequestSetPublicationAuthority restarted_request_set; SWV5_PendingRequest restarted_request;
   const bool restart_ok=restarted_ledger.Configure(path,namespace_digest) &&
      restarted_ledger.ReadSnapshot(restarted_header,restarted_entries,restarted_records) &&
      restarted_request_set.Configure(path,namespace_digest) &&
      restarted_request_set.FindExactBoundRequest(bound_id,proposed_requests[0],restarted_request);
   SWV5S5_MvpD1Record(c,"BOUND-14",restart_ok && ArraySize(restarted_records)==1 &&
      restarted_records[0].lifecycle_state==SWV5S5_BOUND_TO_REQUEST);
   SWV5S5_MvpD1E2EAssertions(c);
}

#endif
