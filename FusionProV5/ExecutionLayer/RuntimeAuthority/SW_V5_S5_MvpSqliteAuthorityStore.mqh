#ifndef SW_V5_S5_MVP_SQLITE_AUTHORITY_STORE_MQH
#define SW_V5_S5_MVP_SQLITE_AUTHORITY_STORE_MQH

// FUSION V5 DEMO MVP RUNTIME AUTHORITY FOUNDATION.
// Durable authority storage only. No broker submission or trading API exists here.

#include "../Contracts/SW_V5_S5_Contracts.mqh"

const string SWV5S5_MVP_STORE_SCHEMA_ID="SWV5-S5-STORE-SCHEMA-V1";
const uint   SWV5S5_MVP_STORE_SCHEMA_VERSION=1;
const uint   SWV5S5_MVP_STORE_MINIMUM_COMPATIBLE_VERSION=1;
const string SWV5S5_MVP_STORE_REVISION_DOMAIN="SWV5-S5-MVP-STORE-REVISION-V1";

struct SWV5S5_MvpAuthorityRow
{
   string domain_key;
   string record_key;
   ulong  logical_revision;
   string store_revision;
   int    state;
   string payload_digest;
   string payload;
   datetime updated_at;
};

class SWV5S5_MvpSqliteAuthorityStore
{
private:
   int    m_database;
   string m_relative_path;
   string m_namespace_digest;
   bool   m_open;

   bool Execute(const string sql)
   {
      return m_open && DatabaseExecute(m_database,sql);
   }

   bool BindText(const int statement,const int index,const string value)
   {
      return DatabaseBind(statement,index,value);
   }

   bool BindLong(const int statement,const int index,const long value)
   {
      return DatabaseBind(statement,index,value);
   }

   bool StepWrite(const int statement)
   {
      ResetLastError();
      if(DatabaseRead(statement)) return true;
      // A prepared INSERT/UPDATE has no result row. MQL reports the normal
      // completion sentinel ERR_DATABASE_NO_MORE_DATA after executing it.
      return GetLastError()==ERR_DATABASE_NO_MORE_DATA;
   }

   bool ReadMetadata(string &schema_id,long &schema_version,long &minimum_version,
                     string &namespace_digest)
   {
      schema_id=""; schema_version=0; minimum_version=0; namespace_digest="";
      const int statement=DatabasePrepare(m_database,
         "SELECT schema_id,schema_version,minimum_compatible_version,namespace_digest "
         "FROM swv5_store_metadata WHERE singleton_id=1;");
      if(statement==INVALID_HANDLE) return false;
      const bool found=DatabaseRead(statement);
      if(found)
      {
         int schema_value=0,minimum_value=0;
         if(!DatabaseColumnText(statement,0,schema_id) ||
            !DatabaseColumnInteger(statement,1,schema_value) ||
            !DatabaseColumnInteger(statement,2,minimum_value) ||
            !DatabaseColumnText(statement,3,namespace_digest))
         { DatabaseFinalize(statement); return false; }
         schema_version=(long)schema_value;
         minimum_version=(long)minimum_value;
      }
      DatabaseFinalize(statement);
      return found;
   }

   bool InsertMetadata()
   {
      const int statement=DatabasePrepare(m_database,
         "INSERT INTO swv5_store_metadata(singleton_id,schema_id,schema_version,"
         "minimum_compatible_version,namespace_digest) VALUES(1,?1,?2,?3,?4);");
      if(statement==INVALID_HANDLE) return false;
      bool ok=BindText(statement,0,SWV5S5_MVP_STORE_SCHEMA_ID) &&
              BindLong(statement,1,(long)SWV5S5_MVP_STORE_SCHEMA_VERSION) &&
              BindLong(statement,2,(long)SWV5S5_MVP_STORE_MINIMUM_COMPATIBLE_VERSION) &&
              BindText(statement,3,m_namespace_digest) && StepWrite(statement);
      DatabaseFinalize(statement);
      return ok;
   }

   bool VerifyMetadata()
   {
      string schema_id,namespace_digest;
      long schema_version=0,minimum_version=0;
      if(!ReadMetadata(schema_id,schema_version,minimum_version,namespace_digest)) return false;
      return schema_id==SWV5S5_MVP_STORE_SCHEMA_ID &&
             schema_version==(long)SWV5S5_MVP_STORE_SCHEMA_VERSION &&
             minimum_version==(long)SWV5S5_MVP_STORE_MINIMUM_COMPATIBLE_VERSION &&
             namespace_digest==m_namespace_digest;
   }

   bool ReadRowInternal(const string domain_key,const string record_key,
                        SWV5S5_MvpAuthorityRow &row,bool &found)
   {
      ZeroMemory(row); found=false;
      if(!m_open || domain_key=="" || record_key=="") return false;
      const int statement=DatabasePrepare(m_database,
         "SELECT logical_revision,store_revision,state,payload_digest,payload,updated_at "
         "FROM swv5_authority_rows WHERE namespace_digest=?1 AND domain_key=?2 AND record_key=?3;");
      if(statement==INVALID_HANDLE) return false;
      if(!BindText(statement,0,m_namespace_digest) || !BindText(statement,1,domain_key) ||
         !BindText(statement,2,record_key))
      { DatabaseFinalize(statement); return false; }
      found=DatabaseRead(statement);
      if(found)
      {
         int revision=0,state=0,updated=0;
         row.domain_key=domain_key;
         row.record_key=record_key;
         if(!DatabaseColumnInteger(statement,0,revision) ||
            !DatabaseColumnText(statement,1,row.store_revision) ||
            !DatabaseColumnInteger(statement,2,state) ||
            !DatabaseColumnText(statement,3,row.payload_digest) ||
            !DatabaseColumnText(statement,4,row.payload) ||
            !DatabaseColumnInteger(statement,5,updated))
         { DatabaseFinalize(statement); return false; }
         row.logical_revision=(ulong)revision;
         row.state=state;
         row.updated_at=(datetime)updated;
      }
      DatabaseFinalize(statement);
      return true;
   }

   bool InsertRow(const SWV5S5_MvpAuthorityRow &row)
   {
      const int statement=DatabasePrepare(m_database,
         "INSERT INTO swv5_authority_rows(namespace_digest,domain_key,record_key,logical_revision,"
         "store_revision,state,payload_digest,payload,updated_at) VALUES(?1,?2,?3,?4,?5,?6,?7,?8,?9);");
      if(statement==INVALID_HANDLE) return false;
      const bool ok=BindText(statement,0,m_namespace_digest) && BindText(statement,1,row.domain_key) &&
         BindText(statement,2,row.record_key) && BindLong(statement,3,(long)row.logical_revision) &&
         BindText(statement,4,row.store_revision) && BindLong(statement,5,(long)row.state) &&
         BindText(statement,6,row.payload_digest) && BindText(statement,7,row.payload) &&
         BindLong(statement,8,(long)row.updated_at) && StepWrite(statement);
      DatabaseFinalize(statement);
      return ok;
   }

   bool UpdateRow(const SWV5S5_MvpAuthorityRow &row,const ulong expected_revision,
                  const string expected_store_revision,const string expected_payload_digest,
                  const int expected_state)
   {
      const int statement=DatabasePrepare(m_database,
         "UPDATE swv5_authority_rows SET logical_revision=?1,store_revision=?2,state=?3,"
         "payload_digest=?4,payload=?5,updated_at=?6 WHERE namespace_digest=?7 AND domain_key=?8 "
         "AND record_key=?9 AND logical_revision=?10 AND store_revision=?11 AND payload_digest=?12 AND state=?13;");
      if(statement==INVALID_HANDLE) return false;
      const bool ok=BindLong(statement,0,(long)row.logical_revision) && BindText(statement,1,row.store_revision) &&
         BindLong(statement,2,(long)row.state) && BindText(statement,3,row.payload_digest) &&
         BindText(statement,4,row.payload) && BindLong(statement,5,(long)row.updated_at) &&
         BindText(statement,6,m_namespace_digest) && BindText(statement,7,row.domain_key) &&
         BindText(statement,8,row.record_key) && BindLong(statement,9,(long)expected_revision) &&
         BindText(statement,10,expected_store_revision) && BindText(statement,11,expected_payload_digest) &&
         BindLong(statement,12,(long)expected_state) && StepWrite(statement);
      DatabaseFinalize(statement);
      return ok;
   }

   bool RowEqual(const SWV5S5_MvpAuthorityRow &left,const SWV5S5_MvpAuthorityRow &right) const
   {
      return left.domain_key==right.domain_key && left.record_key==right.record_key &&
         left.logical_revision==right.logical_revision && left.store_revision==right.store_revision &&
         left.state==right.state && left.payload_digest==right.payload_digest &&
         left.payload==right.payload && left.updated_at==right.updated_at;
   }

public:
   SWV5S5_MvpSqliteAuthorityStore(void)
   {
      m_database=INVALID_HANDLE; m_relative_path=""; m_namespace_digest=""; m_open=false;
   }

   ~SWV5S5_MvpSqliteAuthorityStore(void)
   {
      Close();
   }

   string RelativePath(void) const { return m_relative_path; }
   string NamespaceDigest(void) const { return m_namespace_digest; }
   bool IsOpen(void) const { return m_open; }

   bool Open(const string relative_path,const string namespace_digest)
   {
      Close();
      // MVP databases are filename-only artifacts in Terminal Common\Files.
      // Reject traversal, drive-qualified, and terminal-local path variants.
      if(StringLen(relative_path)<=7 || StringFind(relative_path,"\\")>=0 || StringFind(relative_path,"/")>=0 ||
         StringFind(relative_path,":")>=0 || StringFind(relative_path,"..")>=0 ||
         StringSubstr(relative_path,StringLen(relative_path)-7)!=".sqlite" ||
         !SWV5S5_IsDigest64Lower(namespace_digest)) return false;
      m_relative_path=relative_path;
      m_namespace_digest=namespace_digest;
      m_database=DatabaseOpen(relative_path,DATABASE_OPEN_READWRITE|DATABASE_OPEN_CREATE|DATABASE_OPEN_COMMON);
      if(m_database==INVALID_HANDLE) return false;
      m_open=true;
      if(!Execute("CREATE TABLE IF NOT EXISTS swv5_store_metadata("
                  "singleton_id INTEGER PRIMARY KEY CHECK(singleton_id=1),schema_id TEXT NOT NULL,"
                  "schema_version INTEGER NOT NULL,minimum_compatible_version INTEGER NOT NULL,"
                  "namespace_digest TEXT NOT NULL);") ||
         !Execute("CREATE TABLE IF NOT EXISTS swv5_authority_rows("
                  "namespace_digest TEXT NOT NULL,domain_key TEXT NOT NULL,record_key TEXT NOT NULL,"
                  "logical_revision INTEGER NOT NULL,store_revision TEXT NOT NULL,state INTEGER NOT NULL,"
                  "payload_digest TEXT NOT NULL,payload TEXT NOT NULL,updated_at INTEGER NOT NULL,"
                  "PRIMARY KEY(namespace_digest,domain_key,record_key));"))
      { Close(); return false; }
      string schema_id,stored_namespace;
      long schema_version=0,minimum_version=0;
      if(!ReadMetadata(schema_id,schema_version,minimum_version,stored_namespace))
      {
         if(!DatabaseTransactionBegin(m_database) || !InsertMetadata() ||
            !DatabaseTransactionCommit(m_database))
         { DatabaseTransactionRollback(m_database); Close(); return false; }
      }
      if(!VerifyMetadata()) { Close(); return false; }
      return true;
   }

   void Close(void)
   {
      if(m_database!=INVALID_HANDLE) DatabaseClose(m_database);
      m_database=INVALID_HANDLE; m_open=false;
   }

   bool ReadRow(const string domain_key,const string record_key,
                SWV5S5_MvpAuthorityRow &row,bool &found)
   {
      if(!VerifyMetadata()) return false;
      return ReadRowInternal(domain_key,record_key,row,found);
   }

   bool DeriveStoreRevision(const string domain_key,const string record_key,const ulong logical_revision,
                            const string payload_digest,string &store_revision) const
   {
      string body="",f;
      if(domain_key=="" || record_key=="" || logical_revision==0 || !SWV5S5_IsDigest64Lower(payload_digest) ||
         !SWV5S5_CanonicalString("namespace_digest",m_namespace_digest,f)) return false;
      body+=f;
      if(!SWV5S5_CanonicalString("domain_key",domain_key,f)) return false; body+=f;
      if(!SWV5S5_CanonicalString("record_key",record_key,f)) return false; body+=f;
      if(!SWV5S5_CanonicalUInt("logical_revision",logical_revision,f)) return false; body+=f;
      if(!SWV5S5_CanonicalString("payload_digest",payload_digest,f)) return false; body+=f;
      return SWV5S5_DomainDigest(SWV5S5_MVP_STORE_REVISION_DOMAIN,body,store_revision);
   }

   bool CompareAndSet(const string domain_key,const string record_key,
                      const ulong expected_revision,const string expected_store_revision,
                      const string expected_payload_digest,const int expected_state,
                      const ulong proposed_revision,const int proposed_state,
                      const string proposed_payload_digest,const string proposed_payload,
                      const datetime updated_at,SWV5S5_MvpAuthorityRow &committed)
   {
      ZeroMemory(committed);
      if(!VerifyMetadata() || domain_key=="" || record_key=="" || proposed_revision==0 ||
         !SWV5S5_IsDigest64Lower(proposed_payload_digest) || proposed_payload=="" || updated_at<=0 ||
         proposed_revision!=expected_revision+1) return false;
      SWV5S5_MvpAuthorityRow proposed;
      proposed.domain_key=domain_key; proposed.record_key=record_key;
      proposed.logical_revision=proposed_revision; proposed.state=proposed_state;
      proposed.payload_digest=proposed_payload_digest; proposed.payload=proposed_payload;
      proposed.updated_at=updated_at;
      if(!DeriveStoreRevision(domain_key,record_key,proposed_revision,proposed_payload_digest,
                              proposed.store_revision)) return false;

      if(!DatabaseTransactionBegin(m_database)) return false;
      SWV5S5_MvpAuthorityRow current,inside;
      bool found=false,inside_found=false;
      bool ok=ReadRowInternal(domain_key,record_key,current,found);
      if(ok && expected_revision==0)
         ok=!found && expected_store_revision=="" && expected_payload_digest=="";
      else if(ok)
         ok=found && current.logical_revision==expected_revision &&
            current.store_revision==expected_store_revision &&
            current.payload_digest==expected_payload_digest && current.state==expected_state;
      if(ok)
         ok=(expected_revision==0 ? InsertRow(proposed) :
             UpdateRow(proposed,expected_revision,expected_store_revision,expected_payload_digest,expected_state));
      if(ok) ok=ReadRowInternal(domain_key,record_key,inside,inside_found) && inside_found && RowEqual(inside,proposed);
      if(!ok)
      { DatabaseTransactionRollback(m_database); return false; }
      if(!DatabaseTransactionCommit(m_database))
      { DatabaseTransactionRollback(m_database); return false; }
      SWV5S5_MvpAuthorityRow after;
      bool after_found=false;
      if(!ReadRowInternal(domain_key,record_key,after,after_found) || !after_found || !RowEqual(after,proposed)) return false;
      committed=after;
      return true;
   }

   bool CompareAndSetWithGuard(const string domain_key,const string record_key,
                      const ulong expected_revision,const string expected_store_revision,
                      const string expected_payload_digest,const int expected_state,
                      const ulong proposed_revision,const int proposed_state,
                      const string proposed_payload_digest,const string proposed_payload,
                      const datetime updated_at,
                      const string guard_domain_key,const string guard_record_key,
                      const ulong guard_revision,const string guard_store_revision,
                      const string guard_payload_digest,const int guard_state,
                      SWV5S5_MvpAuthorityRow &committed)
   {
      ZeroMemory(committed);
      if(!VerifyMetadata() || domain_key=="" || record_key=="" || guard_domain_key=="" ||
         guard_record_key=="" || proposed_revision!=expected_revision+1 || proposed_revision==0 ||
         !SWV5S5_IsDigest64Lower(proposed_payload_digest) || !SWV5S5_IsDigest64Lower(guard_payload_digest) ||
         proposed_payload=="" || updated_at<=0 || !DatabaseTransactionBegin(m_database)) return false;
      SWV5S5_MvpAuthorityRow current,guard,proposed,inside;
      bool found=false,guard_found=false,inside_found=false;
      bool ok=ReadRowInternal(domain_key,record_key,current,found) &&
         ReadRowInternal(guard_domain_key,guard_record_key,guard,guard_found) && guard_found;
      if(ok && expected_revision==0)
         ok=!found && expected_store_revision=="" && expected_payload_digest=="";
      else if(ok)
         ok=found && current.logical_revision==expected_revision && current.store_revision==expected_store_revision &&
            current.payload_digest==expected_payload_digest && current.state==expected_state;
      if(ok) ok=guard.logical_revision==guard_revision && guard.store_revision==guard_store_revision &&
         guard.payload_digest==guard_payload_digest && guard.state==guard_state;
      proposed.domain_key=domain_key; proposed.record_key=record_key; proposed.logical_revision=proposed_revision;
      proposed.state=proposed_state; proposed.payload_digest=proposed_payload_digest;
      proposed.payload=proposed_payload; proposed.updated_at=updated_at;
      if(ok) ok=DeriveStoreRevision(domain_key,record_key,proposed_revision,proposed_payload_digest,
                                    proposed.store_revision) &&
         (expected_revision==0 ? InsertRow(proposed) :
          UpdateRow(proposed,expected_revision,expected_store_revision,expected_payload_digest,expected_state));
      if(ok) ok=ReadRowInternal(domain_key,record_key,inside,inside_found) && inside_found && RowEqual(inside,proposed);
      if(!ok)
      { DatabaseTransactionRollback(m_database); return false; }
      if(!DatabaseTransactionCommit(m_database))
      { DatabaseTransactionRollback(m_database); return false; }
      SWV5S5_MvpAuthorityRow after; bool after_found=false;
      if(!ReadRowInternal(domain_key,record_key,after,after_found) || !after_found || !RowEqual(after,proposed)) return false;
      committed=after;
      return true;
   }

   bool TestRollbackWrite(const string domain_key,const string record_key,
                          const string payload_digest,const string payload,const datetime updated_at)
   {
      if(!VerifyMetadata() || !SWV5S5_IsDigest64Lower(payload_digest) || payload=="" || updated_at<=0 ||
         !DatabaseTransactionBegin(m_database)) return false;
      SWV5S5_MvpAuthorityRow row;
      row.domain_key=domain_key; row.record_key=record_key; row.logical_revision=1;
      row.state=0; row.payload_digest=payload_digest; row.payload=payload; row.updated_at=updated_at;
      if(!DeriveStoreRevision(domain_key,record_key,1,payload_digest,row.store_revision) || !InsertRow(row))
      { DatabaseTransactionRollback(m_database); return false; }
      if(!DatabaseTransactionRollback(m_database)) return false;
      SWV5S5_MvpAuthorityRow ignored; bool found=false;
      return ReadRowInternal(domain_key,record_key,ignored,found) && !found;
   }
};

#endif // SW_V5_S5_MVP_SQLITE_AUTHORITY_STORE_MQH
