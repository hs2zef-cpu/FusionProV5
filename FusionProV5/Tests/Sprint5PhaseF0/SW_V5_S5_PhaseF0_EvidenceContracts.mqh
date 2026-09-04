#ifndef SW_V5_S5_PHASE_F0_EVIDENCE_CONTRACTS_MQH
#define SW_V5_S5_PHASE_F0_EVIDENCE_CONTRACTS_MQH

// TEST ONLY / F0 / DEMO ONLY / NOT FOR PRODUCTION / NO PRODUCTION DEPENDENCY.
// Evidence DTOs below grant no execution, recovery, or policy authority.
#ifndef SWV5S5_F0_TEST_ONLY_BUILD
   #error "Phase F0 evidence contracts require explicit test-only build marker"
#endif

enum SWV5S5_F0RetcodeClass
  {
   SWV5S5_F0_R0_ADAPTER_LOCAL_REJECT=0,
   SWV5S5_F0_R1_BROKER_EXPLICIT_REJECT_CANDIDATE=1,
   SWV5S5_F0_R2_ACCEPTED_SUBMISSION=2,
   SWV5S5_F0_R3_PROVISIONAL_SYNC_EVIDENCE=3,
   SWV5S5_F0_R4_AMBIGUOUS=4,
   SWV5S5_F0_R5_TRANSPORT_PLATFORM_FAILURE=5
  };

enum SWV5S5_F0QueryCompleteness
  {
   SWV5S5_F0_QUERY_FAILED=0,
   SWV5S5_F0_QUERY_INCOMPLETE=1,
   SWV5S5_F0_QUERY_COMPLETE_EMPTY=2,
   SWV5S5_F0_QUERY_COMPLETE_NONEMPTY=3
  };

struct SWV5S5_F0EnvironmentEvidence
  {
   string            run_id;
   string            broker;
   string            server;
   string            login_redacted_hash;
   bool              demo_attested;
   ENUM_ACCOUNT_MARGIN_MODE margin_mode;
   long              terminal_build;
   long              mql_build;
   string            symbol;
   datetime          server_time;
   datetime          local_time;
   bool              connected;
  };

struct SWV5S5_F0QueryEvidence
  {
   string                       domain;
   SWV5S5_F0QueryCompleteness   completeness;
   datetime                     window_from;
   datetime                     window_to;
   long                         enumerated_count;
   string                       filter_description;
   string                       evidence_digest;
  };

struct SWV5S5_F0SynchronousEvidence
  {
   ulong                 terminal_session_request_id;
   uint                  retcode;
   int                   retcode_external;
   ulong                 order_ticket;
   ulong                 deal_ticket;
   double                volume;
   double                price;
   string                comment;
   SWV5S5_F0RetcodeClass classification;
  };

#endif
