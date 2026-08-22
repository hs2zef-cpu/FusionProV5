#ifndef SW_V5_S5_PHASE_B_TEST_VECTORS_MQH
#define SW_V5_S5_PHASE_B_TEST_VECTORS_MQH

// TEST ONLY / NOT FOR PRODUCTION / NO BROKER ACCESS
// Compile-time fixture functions. Phase B does not execute MT5 or Strategy Tester.

#define SWV5S5_SHA256_EMPTY "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
#define SWV5S5_SHA256_ABC "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"

bool SWV5S5_VectorSHA256Empty()
{
   string digest;
   return SWV5S5_SHA256("",digest) && digest==SWV5S5_SHA256_EMPTY;
}

bool SWV5S5_VectorSHA256Abc()
{
   string digest;
   return SWV5S5_SHA256("abc",digest) && digest==SWV5S5_SHA256_ABC;
}

bool SWV5S5_VectorCanonicalScalars()
{
   string f;
   if(!SWV5S5_CanonicalString("empty","",f) || f!="empty:s:0:") return false;
   if(!SWV5S5_CanonicalString("ascii","abc",f) || f!="ascii:s:3:abc") return false;
   if(!SWV5S5_CanonicalString("utf8","\x0E44\x0E17\x0E22",f) || f!="utf8:s:9:\x0E44\x0E17\x0E22") return false;
   if(!SWV5S5_CanonicalBool("flag",true,f) || f!="flag:b:1:1") return false;
   if(SWV5S5_CanonicalBoolToken("flag","2",f)) return false;
   if(!SWV5S5_IsCanonicalSignedToken("0") || !SWV5S5_IsCanonicalSignedToken("-42") ||
      SWV5S5_IsCanonicalSignedToken("-0") || SWV5S5_IsCanonicalSignedToken("01")) return false;
   if(!SWV5S5_CanonicalInt("zero",0,f) || f!="zero:i:1:0") return false;
   if(!SWV5S5_CanonicalInt("negative",-42,f) || f!="negative:i:3:-42") return false;
   if(!SWV5S5_CanonicalUInt("unsigned",42,f) || f!="unsigned:u:2:42") return false;
   if(SWV5S5_UIntToString(18446744073709551615)!="18446744073709551615") return false;
   if(!SWV5S5_CanonicalDatetime("time",1700000000,f) || f!="time:i:10:1700000000") return false;
   if(!SWV5S5_CanonicalDouble("double",-0.0,f) || f!="double:d:18:0.0000000000000000") return false;
   return true;
}

bool SWV5S5_VectorNestedIndexed()
{
   string nested,indexed;
   return SWV5S5_CanonicalString("child","value",nested) &&
          SWV5S5_CanonicalIndexed("items",0,nested,indexed) &&
          StringFind(indexed,"items_0:x:")==0;
}

bool SWV5S5_VectorDomainSeparation()
{
   string a,b;
   return SWV5S5_DomainDigest(SWV5S5_DOMAIN_INGRESS_ID,"body",a) &&
          SWV5S5_DomainDigest(SWV5S5_DOMAIN_INGRESS_PAYLOAD,"body",b) && a!=b;
}

bool SWV5S5_VectorRequestIdentity(const SWV5_PersistenceNamespace &scope,
                                  const string ingress)
{
   string c0,a0,k0,c1,a1,k1,cr,ar,kr;
   if(!SWV5S5_DeriveRequestBinding(scope,ingress,7,0,c0,a0,k0)) return false;
   if(!SWV5S5_DeriveRequestBinding(scope,ingress,7,0,c1,a1,k1)) return false;
   if(!SWV5S5_DeriveRequestBinding(scope,ingress,7,1,cr,ar,kr)) return false;
   return c0==c1 && a0==a1 && k0==k1 && c0==cr && k0==kr && a0!=ar;
}

bool SWV5S5_VectorPermitIdentity(const SWV5S5_SubmissionPermit &permit)
{
   string first,second;
   return SWV5S5_DerivePermitId(permit,first) && SWV5S5_DerivePermitId(permit,second) && first==second;
}

#endif
