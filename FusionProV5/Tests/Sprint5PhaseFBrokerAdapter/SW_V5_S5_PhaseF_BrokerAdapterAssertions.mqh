#ifndef SW_V5_S5_PHASE_F_BROKER_ADAPTER_ASSERTIONS_MQH
#define SW_V5_S5_PHASE_F_BROKER_ADAPTER_ASSERTIONS_MQH

// TEST ONLY / NOT FOR PRODUCTION / NO BROKER ACCESS.
// Pure MQL assertions for the Phase F Broker Adapter audit boundaries.

#include "../../ExecutionLayer/BrokerAdapter/SW_V5_S5_F_BrokerAdapter.mqh"

struct SWV5S5_F_MqlAssertionResult
{
   int total;
   int passed;
   int failed;
   int skipped;
   string signature_material;
};

void SWV5S5_F_MqlAssert(const string test_id,const bool condition,
                        SWV5S5_F_MqlAssertionResult &result)
{
   result.total++;
   if(condition) result.passed++; else result.failed++;
   result.signature_material+=test_id+"="+(condition ? "PASS" : "FAIL")+";";
   PrintFormat("S5F_BROKER_MQL_ASSERT|id=%s|result=%s",test_id,
               condition ? "PASS" : "FAIL");
}

void SWV5S5_F_MqlBuildWire(SWV5S5_F_AdapterWireRequest &wire)
{
   ZeroMemory(wire);
   wire.action=(int)TRADE_ACTION_DEAL;
   wire.magic=1179670069;
   wire.symbol="AUDIT_XAUUSD";
   wire.volume=0.30;
   wire.price=2500.10;
   wire.stop_loss_price=2499.90;
   wire.take_profit_price=2500.30;
   wire.order_type=(int)ORDER_TYPE_BUY;
   wire.filling_type=(int)ORDER_FILLING_FOK;
   wire.time_type=(int)ORDER_TIME_GTC;
   wire.comment="AUDIT-NO-SEND";
}

int SWV5S5_F_RunBrokerAdapterMqlAssertions(SWV5S5_F_MqlAssertionResult &result)
{
   ZeroMemory(result);
   long units=0;
   SWV5S5_F_MqlAssert("MQL-GRID-01-BINARY-DECIMAL",
      SWV5S5_F_AdapterCanonicalGridUnits(0.30,0.10,false,units) && units==3,result);
   SWV5S5_F_MqlAssert("MQL-GRID-02-OFF-GRID",
      !SWV5S5_F_AdapterCanonicalGridUnits(0.305,0.10,false,units),result);
   SWV5S5_F_MqlAssert("MQL-GRID-03-ZERO-OPTIONAL",
      SWV5S5_F_AdapterCanonicalGridUnits(0.0,0.01,true,units) && units==0,result);
   SWV5S5_F_MqlAssert("MQL-GRID-04-ZERO-REQUIRED",
      !SWV5S5_F_AdapterCanonicalGridUnits(0.0,0.01,false,units),result);
   SWV5S5_F_MqlAssert("MQL-GRID-05-CANONICAL-EQUALITY",
      SWV5S5_F_AdapterCanonicalGridEqual(0.1+0.2,0.3,0.1,false),result);

   ENUM_ORDER_TYPE_FILLING filling=ORDER_FILLING_RETURN;
   SWV5S5_F_MqlAssert("MQL-FILL-01-FOK-EXACT",
      SWV5S5_F_AdapterResolveFilling(1,3,filling) && filling==ORDER_FILLING_FOK,result);
   SWV5S5_F_MqlAssert("MQL-FILL-02-IOC-EXACT",
      SWV5S5_F_AdapterResolveFilling(2,3,filling) && filling==ORDER_FILLING_IOC,result);
   SWV5S5_F_MqlAssert("MQL-FILL-03-COMBINED-REJECT",
      !SWV5S5_F_AdapterResolveFilling(3,3,filling),result);
   SWV5S5_F_MqlAssert("MQL-FILL-04-UNSUPPORTED-REJECT",
      !SWV5S5_F_AdapterResolveFilling(1,2,filling),result);

   SWV5S5_F_MqlAssert("MQL-PRICE-01-BUY-SEMANTICS",
      SWV5S5_F_AdapterMarketProtectionValid(1,2500.10,2499.90,2500.30,0.10),result);
   SWV5S5_F_MqlAssert("MQL-PRICE-02-SELL-SEMANTICS",
      SWV5S5_F_AdapterMarketProtectionValid(-1,2500.10,2500.30,2499.90,0.10),result);
   SWV5S5_F_MqlAssert("MQL-PRICE-03-BUY-WRONG-SIDE",
      !SWV5S5_F_AdapterMarketProtectionValid(1,2500.10,2500.20,2500.30,0.10),result);
   SWV5S5_F_MqlAssert("MQL-PRICE-04-OFF-TICK",
      !SWV5S5_F_AdapterMarketProtectionValid(1,2500.105,2499.90,2500.30,0.10),result);

   SWV5S5_F_AdapterWireRequest wire,mutated_wire;
   SWV5S5_F_MqlBuildWire(wire);
   SWV5S5_F_MqlBuildWire(mutated_wire);
   string first_digest="",second_digest="",mutated_digest="";
   const bool first_ok=SWV5S5_F_DeriveAdapterWirePayloadDigest(wire,first_digest);
   const bool second_ok=SWV5S5_F_DeriveAdapterWirePayloadDigest(wire,second_digest);
   mutated_wire.take_profit_price=2500.40;
   const bool mutation_ok=SWV5S5_F_DeriveAdapterWirePayloadDigest(mutated_wire,mutated_digest);
   SWV5S5_F_MqlAssert("MQL-WIRE-01-DETERMINISTIC",
      first_ok && second_ok && first_digest==second_digest && first_digest!="",result);
   SWV5S5_F_MqlAssert("MQL-WIRE-02-MUTATION-SENSITIVE",
      first_ok && mutation_ok && first_digest!=mutated_digest,result);

   SWV5S5_F_AdapterEnvironment first_environment,second_environment;
   ZeroMemory(first_environment); ZeroMemory(second_environment);
   first_environment.broker_identity="BROKER-A";
   first_environment.server="DEMO-SERVER";
   first_environment.account_login=42;
   first_environment.account_currency="USD";
   first_environment.symbol="AUDIT_XAUUSD";
   first_environment.terminal_build=1;
   first_environment.mql_build=1;
   first_environment.account_trade_mode=0;
   first_environment.account_mode=SWV5_ACCOUNT_MODE_NETTING;
   first_environment.connected=true;
   first_environment.terminal_trade_allowed=true;
   first_environment.mql_trade_allowed=true;
   first_environment.account_trade_allowed=true;
   first_environment.account_trade_expert=true;
   first_environment.symbol_trade_mode=1;
   first_environment.symbol_execution_mode=2;
   first_environment.symbol_filling_mask=3;
   first_environment.symbol_digits=2;
   first_environment.point=0.01;
   first_environment.tick_size=0.10;
   first_environment.volume_min=0.01;
   first_environment.volume_max=100.0;
   first_environment.volume_step=0.01;
   first_environment.runtime_magic=1179670069;
   second_environment=first_environment;
   SWV5S5_F_MqlAssert("MQL-TOCTOU-01-STABLE-SAMPLE",
      SWV5S5_F_AdapterEnvironmentStable(first_environment,second_environment),result);
   second_environment.account_trade_expert=false;
   SWV5S5_F_MqlAssert("MQL-TOCTOU-02-PERMISSION-CHANGE",
      !SWV5S5_F_AdapterEnvironmentStable(first_environment,second_environment),result);
   second_environment=first_environment;
   second_environment.tick_size=0.01;
   SWV5S5_F_MqlAssert("MQL-TOCTOU-03-SPEC-CHANGE",
      !SWV5S5_F_AdapterEnvironmentStable(first_environment,second_environment),result);

   SWV5S5_F_BrokerQuerySnapshot broker;
   SWV5S5_F_ExecutionPendingSnapshot execution;
   ZeroMemory(broker); ZeroMemory(execution);
   broker.positions_enumeration_complete=true;
   broker.orders_enumeration_complete=true;
   broker.history_orders_enumeration_complete=true;
   broker.history_deals_enumeration_complete=true;
   broker.callback_transactions_enumeration_complete=true;
   SWV5S5_F_MqlAssert("MQL-QUERY-01-EMPTY-COMPLETE",
      SWV5S5_F_AdapterBrokerQueryShapeComplete(broker),result);
   broker.positions_reported_total=1;
   SWV5S5_F_MqlAssert("MQL-QUERY-02-OMITTED-ROW-REJECT",
      !SWV5S5_F_AdapterBrokerQueryShapeComplete(broker),result);
   broker.positions_reported_total=0;
   broker.broker_read_path_id="BROKER-READ";
   broker.broker_authority_instance_id="BROKER-AUTH";
   broker.broker_sequence_authority_id="BROKER-SEQ";
   broker.query_set.snapshot_id="BROKER-SNAPSHOT";
   broker.query_set.snapshot_digest="BROKER-DIGEST";
   execution.execution_read_path_id="EXECUTION-READ";
   execution.execution_authority_instance_id="EXECUTION-AUTH";
   execution.execution_sequence_authority_id="EXECUTION-SEQ";
   execution.query_set.snapshot_id="EXECUTION-SNAPSHOT";
   execution.query_set.snapshot_digest="EXECUTION-DIGEST";
   execution.operation_success=true;
   execution.enumeration_complete=true;
   SWV5S5_F_MqlAssert("MQL-EVIDENCE-01-INDEPENDENT",
      SWV5S5_F_AdapterEvidenceSourcesIndependent(broker,execution),result);
   execution.execution_sequence_authority_id=broker.broker_sequence_authority_id;
   SWV5S5_F_MqlAssert("MQL-EVIDENCE-02-SHARED-AUTHORITY-REJECT",
      !SWV5S5_F_AdapterEvidenceSourcesIndependent(broker,execution),result);
   execution.execution_sequence_authority_id="EXECUTION-SEQ";
   SWV5S5_F_MqlAssert("MQL-QUERY-03-EXECUTION-COMPLETE",
      SWV5S5_F_AdapterExecutionQueryShapeComplete(execution),result);
   execution.reported_total=1;
   SWV5S5_F_MqlAssert("MQL-QUERY-04-EXECUTION-OMISSION-REJECT",
      !SWV5S5_F_AdapterExecutionQueryShapeComplete(execution),result);

   string signature="";
   SWV5S5_DomainDigest("SWV5-SPRINT5-PHASE-F-BROKER-MQL-ASSERTIONS-V1",
                       result.signature_material,signature);
   PrintFormat("S5F_BROKER_MQL_RESULT|total=%d|passed=%d|failed=%d|skipped=%d|signature=%s|broker_calls=0",
               result.total,result.passed,result.failed,result.skipped,signature);
   return result.failed;
}

#endif
