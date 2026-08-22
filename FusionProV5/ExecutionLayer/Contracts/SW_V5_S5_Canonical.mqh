#ifndef SW_V5_S5_CANONICAL_MQH
#define SW_V5_S5_CANONICAL_MQH

// SPRINT 5 PHASE B CANDIDATE CONTRACT
// PURE CANONICAL ENCODING / NO BROKER, CLOCK, OR PHYSICAL STORE ACCESS

#include "SW_V5_S5_Common.mqh"

bool SWV5S5_AppendByte(uchar &bytes[],const uchar value)
{
   int n=ArraySize(bytes);
   if(ArrayResize(bytes,n+1)!=n+1) return false;
   bytes[n]=value;
   return true;
}

bool SWV5S5_StrictUtf8(const string value,uchar &bytes[])
{
   ArrayResize(bytes,0);
   int n=StringLen(value);
   for(int i=0;i<n;i++)
   {
      uint cp=(uint)StringGetCharacter(value,i);
      if(cp>=0xD800 && cp<=0xDBFF)
      {
         if(i+1>=n) return false;
         uint low=(uint)StringGetCharacter(value,++i);
         if(low<0xDC00 || low>0xDFFF) return false;
         cp=0x10000+((cp-0xD800)<<10)+(low-0xDC00);
      }
      else if(cp>=0xDC00 && cp<=0xDFFF) return false;

      if(cp<=0x7F)
      {
         if(!SWV5S5_AppendByte(bytes,(uchar)cp)) return false;
      }
      else if(cp<=0x7FF)
      {
         if(!SWV5S5_AppendByte(bytes,(uchar)(0xC0|(cp>>6))) ||
            !SWV5S5_AppendByte(bytes,(uchar)(0x80|(cp&0x3F)))) return false;
      }
      else if(cp<=0xFFFF)
      {
         if(!SWV5S5_AppendByte(bytes,(uchar)(0xE0|(cp>>12))) ||
            !SWV5S5_AppendByte(bytes,(uchar)(0x80|((cp>>6)&0x3F))) ||
            !SWV5S5_AppendByte(bytes,(uchar)(0x80|(cp&0x3F)))) return false;
      }
      else if(cp<=0x10FFFF)
      {
         if(!SWV5S5_AppendByte(bytes,(uchar)(0xF0|(cp>>18))) ||
            !SWV5S5_AppendByte(bytes,(uchar)(0x80|((cp>>12)&0x3F))) ||
            !SWV5S5_AppendByte(bytes,(uchar)(0x80|((cp>>6)&0x3F))) ||
            !SWV5S5_AppendByte(bytes,(uchar)(0x80|(cp&0x3F)))) return false;
      }
      else return false;
   }
   return true;
}

bool SWV5S5_CanonicalField(const string name,const string type_token,
                           const string value,string &field)
{
   uchar name_bytes[],value_bytes[];
   if(name=="" || StringLen(type_token)!=1 ||
      !SWV5S5_StrictUtf8(name,name_bytes) || !SWV5S5_StrictUtf8(value,value_bytes)) return false;
   for(int i=0;i<ArraySize(name_bytes);i++)
      if(!((name_bytes[i]>='a' && name_bytes[i]<='z') ||
           (name_bytes[i]>='A' && name_bytes[i]<='Z') ||
           (name_bytes[i]>='0' && name_bytes[i]<='9') || name_bytes[i]=='_')) return false;
   if(type_token!="s" && type_token!="b" && type_token!="i" && type_token!="u" &&
      type_token!="d" && type_token!="x") return false;
   field=name+":"+type_token+":"+IntegerToString(ArraySize(value_bytes))+":"+value;
   return true;
}

bool SWV5S5_CanonicalString(const string name,const string value,string &field)
{ return SWV5S5_CanonicalField(name,"s",value,field); }

bool SWV5S5_CanonicalBool(const string name,const bool value,string &field)
{ return SWV5S5_CanonicalField(name,"b",value ? "1" : "0",field); }

bool SWV5S5_CanonicalBoolToken(const string name,const string token,string &field)
{
   if(token!="0" && token!="1") return false;
   return SWV5S5_CanonicalField(name,"b",token,field);
}

bool SWV5S5_IsCanonicalSignedToken(const string token)
{
   int n=StringLen(token);
   if(n==0 || token=="-0") return false;
   int start=0;
   if(StringGetCharacter(token,0)==45)
   {
      if(n==1) return false;
      start=1;
   }
   if(n-start>1 && StringGetCharacter(token,start)==48) return false;
   for(int i=start;i<n;i++)
   {
      ushort c=StringGetCharacter(token,i);
      if(c<48 || c>57) return false;
   }
   return true;
}

string SWV5S5_UIntToString(ulong value)
{
   if(value==0) return "0";
   string result="";
   while(value>0)
   {
      uint digit=(uint)(value%10);
      result=StringFormat("%u",digit)+result;
      value/=10;
   }
   return result;
}

bool SWV5S5_CanonicalInt(const string name,const long value,string &field)
{ return SWV5S5_CanonicalField(name,"i",IntegerToString(value),field); }

bool SWV5S5_CanonicalUInt(const string name,const ulong value,string &field)
{ return SWV5S5_CanonicalField(name,"u",SWV5S5_UIntToString(value),field); }

bool SWV5S5_CanonicalDatetime(const string name,const datetime value,string &field)
{
   if(value<0) return false;
   return SWV5S5_CanonicalField(name,"i",IntegerToString(value),field);
}

bool SWV5S5_CanonicalDouble(const string name,const double value,string &field)
{
   if(!SWV5_IsFiniteNumber(value)) return false;
   double normalized=(value==0.0 ? 0.0 : value);
   return SWV5S5_CanonicalField(name,"d",DoubleToString(normalized,16),field);
}

bool SWV5S5_CanonicalNested(const string name,const string canonical_value,string &field)
{ return SWV5S5_CanonicalField(name,"x",canonical_value,field); }

bool SWV5S5_CanonicalIndexed(const string array_name,const ulong index,
                             const string canonical_value,string &field)
{
   return SWV5S5_CanonicalNested(array_name+"_"+SWV5S5_UIntToString(index),canonical_value,field);
}

uint SWV5S5_Ror32(const uint x,const uint n)
{ return (x>>n)|(x<<(32-n)); }

uint SWV5S5_ReadBE32(const uchar &data[],const int offset)
{
   return ((uint)data[offset]<<24)|((uint)data[offset+1]<<16)|
          ((uint)data[offset+2]<<8)|(uint)data[offset+3];
}

void SWV5S5_WriteBE32(const uint value,uchar &data[],const int offset)
{
   data[offset]=(uchar)(value>>24); data[offset+1]=(uchar)(value>>16);
   data[offset+2]=(uchar)(value>>8); data[offset+3]=(uchar)value;
}

bool SWV5S5_SHA256Bytes(const uchar &source_bytes[],string &hex)
{
   const uint k[64]={
      0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,
      0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,
      0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,
      0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,
      0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,
      0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,
      0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,
      0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2};
   int original=ArraySize(source_bytes);
   if(original<0) return false;
   ulong original_size=(ulong)original;
   if(original_size>((ulong)2147483647-72)) return false;
   ulong padded_size=((original_size+72)/64)*64;
   if(padded_size==0 || padded_size>2147483647) return false;
   int padded=(int)padded_size;
   uchar data[];
   if(ArrayResize(data,padded)!=padded) return false;
   ArrayInitialize(data,0);
   for(int i=0;i<original;i++) data[i]=source_bytes[i];
   data[original]=0x80;
   if(original_size>18446744073709551615/8) return false;
   ulong bit_length=original_size*8;
   for(int j=0;j<8;j++) data[padded-1-j]=(uchar)(bit_length>>(8*j));

   uint h[8]={0x6a09e667,0xbb67ae85,0x3c6ef372,0xa54ff53a,
              0x510e527f,0x9b05688c,0x1f83d9ab,0x5be0cd19};
   uint w[64];
   for(int block=0;block<padded;block+=64)
   {
      for(int t=0;t<16;t++) w[t]=SWV5S5_ReadBE32(data,block+4*t);
      for(int t=16;t<64;t++)
      {
         uint s0=SWV5S5_Ror32(w[t-15],7)^SWV5S5_Ror32(w[t-15],18)^(w[t-15]>>3);
         uint s1=SWV5S5_Ror32(w[t-2],17)^SWV5S5_Ror32(w[t-2],19)^(w[t-2]>>10);
         w[t]=w[t-16]+s0+w[t-7]+s1;
      }
      uint a=h[0],b=h[1],c=h[2],d=h[3],e=h[4],f=h[5],g=h[6],hh=h[7];
      for(int t=0;t<64;t++)
      {
         uint s1=SWV5S5_Ror32(e,6)^SWV5S5_Ror32(e,11)^SWV5S5_Ror32(e,25);
         uint ch=(e&f)^((~e)&g);
         uint temp1=hh+s1+ch+k[t]+w[t];
         uint s0=SWV5S5_Ror32(a,2)^SWV5S5_Ror32(a,13)^SWV5S5_Ror32(a,22);
         uint maj=(a&b)^(a&c)^(b&c);
         uint temp2=s0+maj;
         hh=g; g=f; f=e; e=d+temp1; d=c; c=b; b=a; a=temp1+temp2;
      }
      h[0]+=a; h[1]+=b; h[2]+=c; h[3]+=d;
      h[4]+=e; h[5]+=f; h[6]+=g; h[7]+=hh;
   }
   uchar digest[]; ArrayResize(digest,32);
   for(int z=0;z<8;z++) SWV5S5_WriteBE32(h[z],digest,4*z);
   hex="";
   for(int z=0;z<32;z++) hex+=StringFormat("%02x",digest[z]);
   return SWV5S5_IsDigest64Lower(hex);
}

bool SWV5S5_SHA256(const string canonical,string &hex)
{
   uchar bytes[];
   if(!SWV5S5_StrictUtf8(canonical,bytes)) return false;
   return SWV5S5_SHA256Bytes(bytes,hex);
}

bool SWV5S5_DomainDigest(const string domain,const string canonical_body,string &hex)
{
   string d,b;
   if(!SWV5S5_CanonicalString("domain",domain,d) ||
      !SWV5S5_CanonicalNested("body",canonical_body,b)) return false;
   return SWV5S5_SHA256(d+b,hex);
}

bool SWV5S5_CanonicalContractVersion(const string name,const SWV5_ContractVersion &version,string &field)
{
   string a,b,c,d,body;
   if(!SWV5S5_CanonicalString("contract_name",version.contract_name,a) ||
      !SWV5S5_CanonicalInt("schema_version",version.schema_version,b) ||
      !SWV5S5_CanonicalInt("minimum_compatible_version",version.minimum_compatible_version,c) ||
      !SWV5S5_CanonicalString("policy_id",version.policy_id,d)) return false;
   body=a+b+c+d;
   return SWV5S5_CanonicalNested(name,body,field);
}

bool SWV5S5_CanonicalOwnershipKey(const string name,const SWV5_OwnershipKey &key,string &field)
{
   string a,b,c,d,e,f,body;
   if(!SWV5S5_CanonicalInt("account_login",key.account_login,a) ||
      !SWV5S5_CanonicalString("broker_identity",key.broker_identity,b) ||
      !SWV5S5_CanonicalString("server",key.server,c) ||
      !SWV5S5_CanonicalString("symbol",key.symbol,d) ||
      !SWV5S5_CanonicalString("strategy_id",key.strategy_id,e) ||
      !SWV5S5_CanonicalUInt("magic",key.magic,f)) return false;
   body=a+b+c+d+e+f;
   return SWV5S5_CanonicalNested(name,body,field);
}

bool SWV5S5_CanonicalNamespace(const string name,const SWV5_PersistenceNamespace &scope,string &field)
{
   string a,b,c,body;
   if(!SWV5S5_CanonicalContractVersion("version",scope.contract_version,a) ||
      !SWV5S5_CanonicalOwnershipKey("ownership_namespace",scope.ownership_namespace,b) ||
      !SWV5S5_CanonicalString("basket_id",scope.basket_id.value,c)) return false;
   body=a+b+c;
   return SWV5S5_CanonicalNested(name,body,field);
}

bool SWV5S5_CanonicalFence(const string name,const SWV5_OwnershipFence &fence,string &field)
{
   string a,b,c,d,e,f,g,h,i,body;
   if(!SWV5S5_CanonicalContractVersion("version",fence.contract_version,a) ||
      !SWV5S5_CanonicalOwnershipKey("ownership_namespace",fence.ownership_namespace,b) ||
      !SWV5S5_CanonicalOwnershipKey("owner_key",fence.owner.key,c) ||
      !SWV5S5_CanonicalString("instance_id",fence.owner.instance_id,d) ||
      !SWV5S5_CanonicalString("process_fingerprint",fence.owner.process_fingerprint,e) ||
      !SWV5S5_CanonicalDatetime("started_at",fence.owner.started_at,f) ||
      !SWV5S5_CanonicalUInt("lease_version",fence.lease_version,g) ||
      !SWV5S5_CanonicalUInt("takeover_generation",fence.takeover_generation,h) ||
      !SWV5S5_CanonicalString("fencing_token_digest",fence.fencing_token_digest,i)) return false;
   body=a+b+c+d+e+f+g+h+i;
   return SWV5S5_CanonicalNested(name,body,field);
}

bool SWV5S5_CanonicalInstanceLease(const string name,const SWV5_InstanceLease &lease,string &field)
{
   string body="",f;
   if(!SWV5S5_CanonicalContractVersion("version",lease.contract_version,f)) return false; body+=f;
   if(!SWV5S5_CanonicalFence("fence",lease.fence,f)) return false; body+=f;
   if(!SWV5S5_CanonicalInt("status",lease.status,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("store_revision",lease.store_revision,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("heartbeat_sequence",lease.heartbeat_sequence,f)) return false; body+=f;
   if(!SWV5S5_CanonicalString("clock_id",lease.clock_id,f)) return false; body+=f;
   if(!SWV5S5_CanonicalInt("clock_authority",lease.clock_authority,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("acquired_clock_sequence",lease.acquired_clock_sequence,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("heartbeat_clock_sequence",lease.heartbeat_clock_sequence,f)) return false; body+=f;
   if(!SWV5S5_CanonicalUInt("expiry_clock_sequence",lease.expiry_clock_sequence,f)) return false; body+=f;
   if(!SWV5S5_CanonicalDatetime("acquired_at",lease.acquired_at,f)) return false; body+=f;
   if(!SWV5S5_CanonicalDatetime("heartbeat_at",lease.heartbeat_at,f)) return false; body+=f;
   if(!SWV5S5_CanonicalDatetime("expires_at",lease.expires_at,f)) return false; body+=f;
   return SWV5S5_CanonicalNested(name,body,field);
}

bool SWV5S5_CanonicalRequestIdentity(const string name,const SWV5_ExecutionRequestIdentity &identity,string &field)
{
   string a,b,c,d,e,f,g,body;
   if(!SWV5S5_CanonicalContractVersion("version",identity.contract_version,a) ||
      !SWV5S5_CanonicalString("correlation_id",identity.request_id.correlation_id,b) ||
      !SWV5S5_CanonicalString("attempt_id",identity.request_id.attempt_id,c) ||
      !SWV5S5_CanonicalString("parent_attempt_id",identity.request_id.parent_attempt_id,d) ||
      !SWV5S5_CanonicalUInt("monotonic_sequence",identity.request_id.monotonic_sequence,e) ||
      !SWV5S5_CanonicalDatetime("created_at",identity.request_id.created_at,f) ||
      !SWV5S5_CanonicalString("idempotency_key",identity.idempotency_key,g)) return false;
   body=a+b+c+d+e+f+g;
   return SWV5S5_CanonicalNested(name,body,field);
}

#endif
