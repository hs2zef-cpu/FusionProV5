#ifndef SW_V5_S5_REFERENCE_STORE_COMMON_MQH
#define SW_V5_S5_REFERENCE_STORE_COMMON_MQH

// REFERENCE ONLY / NOT FOR PRODUCTION / NO BROKER ACCESS
// Deterministic in-memory Phase D model. No physical persistence is provided.

#include "../Contracts/SW_V5_S5_Contracts.mqh"

const string SWV5S5_REFERENCE_SCHEMA_ID = "SWV5-S5-STORE-SCHEMA-V1";
const uint   SWV5S5_REFERENCE_SCHEMA_VERSION = 1;
const uint   SWV5S5_REFERENCE_MINIMUM_COMPATIBLE = 1;

enum SWV5S5_ReferenceDomain
{
   SWV5S5_REF_DOMAIN_GENESIS = 0,
   SWV5S5_REF_DOMAIN_LEASE = 1,
   SWV5S5_REF_DOMAIN_LEDGER = 2,
   SWV5S5_REF_DOMAIN_SEQUENCE = 3,
   SWV5S5_REF_DOMAIN_SUBMISSION = 4,
   SWV5S5_REF_DOMAIN_REQUEST_SET = 5,
   SWV5S5_REF_DOMAIN_CHECKPOINT = 6
};

enum SWV5S5_ReferenceTransactionDisposition
{
   SWV5S5_REF_COMMITTED = 0,
   SWV5S5_REF_EXPECTED_STATE_MISMATCH = 1,
   SWV5S5_REF_CONFLICT = 2,
   SWV5S5_REF_BUSY_LOCKED = 3,
   SWV5S5_REF_CRASH_BEFORE_MUTATION = 4,
   SWV5S5_REF_CRASH_DURING_TRANSACTION = 5,
   SWV5S5_REF_COMMIT_OUTCOME_UNCERTAIN = 6,
   SWV5S5_REF_CORRUPT_STATE = 7,
   SWV5S5_REF_READBACK_MISMATCH = 8,
   SWV5S5_REF_SCHEMA_INCOMPATIBLE = 9
};

enum SWV5S5_ReferenceFaultPoint
{
   SWV5S5_REF_FAULT_NONE = 0,
   SWV5S5_REF_FAULT_AFTER_SNAPSHOT = 1,
   SWV5S5_REF_FAULT_BEFORE_EXPECTED_COMPARE = 2,
   SWV5S5_REF_FAULT_AFTER_EXPECTED_VALIDATION = 3,
   SWV5S5_REF_FAULT_BEFORE_MUTATION = 4,
   SWV5S5_REF_FAULT_AFTER_STAGED_MUTATION = 5,
   SWV5S5_REF_FAULT_BEFORE_COMMIT = 6,
   SWV5S5_REF_FAULT_AFTER_DURABLE_COMMIT = 7,
   SWV5S5_REF_FAULT_BEFORE_READBACK = 8
};

struct SWV5S5_ReferenceDomainRow
{
   SWV5S5_ReferenceDomain domain;
   string persistence_namespace_digest;
   ulong store_revision;
   string authority_fence_digest;
   string payload;
   string payload_digest;
   bool corrupt;
};

struct SWV5S5_ReferenceTransactionResult
{
   SWV5S5_ReferenceTransactionDisposition disposition;
   string transaction_id;
   SWV5S5_ReferenceDomain domain;
   ulong expected_revision;
   ulong durable_revision;
   bool this_transaction_won;
   bool durable_state_matches_proposal;
   string durable_payload_digest;
   string diagnostic;
};

struct SWV5S5_ReferenceTraceEntry
{
   string transaction_id;
   SWV5S5_ReferenceDomain domain;
   string step;
   ulong expected_revision;
   ulong durable_revision;
   SWV5S5_ReferenceTransactionDisposition disposition;
};

string SWV5S5_ReferenceDigest(const string domain,const string value)
{
   string canonical_value="",hex="";
   if(!SWV5S5_CanonicalString("value",value,canonical_value) ||
      !SWV5S5_DomainDigest(domain,canonical_value,hex))
      return "";
   return hex;
}

bool SWV5S5_ReferenceSchemaCompatible(const string schema_id,
                                      const uint schema_version,
                                      const uint minimum_compatible)
{
   return schema_id==SWV5S5_REFERENCE_SCHEMA_ID &&
          schema_version==SWV5S5_REFERENCE_SCHEMA_VERSION &&
          minimum_compatible==SWV5S5_REFERENCE_MINIMUM_COMPATIBLE;
}

#endif
