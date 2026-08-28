#ifndef SW_V5_S5_FAKE_AUTHORITATIVE_CLOCK_MQH
#define SW_V5_S5_FAKE_AUTHORITATIVE_CLOCK_MQH

// REFERENCE ONLY / NOT FOR PRODUCTION / NO BROKER ACCESS

#include "SW_V5_S5_ReferenceStoreCommon.mqh"

struct SWV5S5_ReferenceClockObservation
{
   string clock_id;
   SWV5_TimeAuthority authority;
   string source_symbol;
   ulong observation_sequence;
   datetime observed_at;
   string event_identity;
   bool current_event_provenance;
   string validation_digest;
};

class SWV5S5_FakeAuthoritativeClock
{
private:
   string m_clock_id;
   string m_symbol;
   SWV5_TimeAuthority m_authority;
   ulong m_last_sequence;
   datetime m_last_time;
   string m_last_event_identity;
   string m_last_validation_digest;

   bool DeriveValidationDigest(const SWV5S5_ReferenceClockObservation &observation,string &digest) const
   {
      string body="",f;
      if(!SWV5S5_CanonicalString("clock_id",observation.clock_id,f)) return false; body+=f;
      if(!SWV5S5_CanonicalInt("authority",observation.authority,f)) return false; body+=f;
      if(!SWV5S5_CanonicalString("source_symbol",observation.source_symbol,f)) return false; body+=f;
      if(!SWV5S5_CanonicalUInt("observation_sequence",observation.observation_sequence,f)) return false; body+=f;
      if(!SWV5S5_CanonicalDatetime("observed_at",observation.observed_at,f)) return false; body+=f;
      if(!SWV5S5_CanonicalString("event_identity",observation.event_identity,f)) return false; body+=f;
      if(!SWV5S5_CanonicalBool("current_event_provenance",observation.current_event_provenance,f)) return false; body+=f;
      return SWV5S5_DomainDigest("SWV5-S5-PHASE-D1-VALIDATED-CLOCK",body,digest);
   }

public:
   SWV5S5_FakeAuthoritativeClock(void):m_authority(SWV5_TIME_AUTHORITY_NONE),m_last_sequence(0),m_last_time(0) {}

   void Configure(const string clock_id,const SWV5_TimeAuthority authority,const string symbol)
   {
      m_clock_id=clock_id;
      m_authority=authority;
      m_symbol=symbol;
      m_last_sequence=0;
      m_last_time=0;
      m_last_event_identity="";
      m_last_validation_digest="";
   }

   bool AcceptAndSeal(const SWV5S5_ReferenceClockObservation &candidate,
                      SWV5S5_ReferenceClockObservation &validated)
   {
      if(candidate.validation_digest!="" || candidate.clock_id!=m_clock_id || candidate.authority!=m_authority ||
         candidate.source_symbol!=m_symbol || !candidate.current_event_provenance ||
         candidate.event_identity=="" || candidate.observed_at<=0 ||
         candidate.observation_sequence<=m_last_sequence || candidate.observed_at<m_last_time)
         return false;
      validated=candidate;
      if(!DeriveValidationDigest(validated,validated.validation_digest)) return false;
      m_last_sequence=validated.observation_sequence;
      m_last_time=validated.observed_at;
      m_last_event_identity=validated.event_identity;
      m_last_validation_digest=validated.validation_digest;
      return true;
   }

   bool ValidateAccepted(const SWV5S5_ReferenceClockObservation &observation) const
   {
      string digest;
      return observation.clock_id==m_clock_id && observation.authority==m_authority &&
         observation.source_symbol==m_symbol && observation.current_event_provenance &&
         observation.observation_sequence==m_last_sequence && observation.observed_at==m_last_time &&
         observation.event_identity==m_last_event_identity &&
         DeriveValidationDigest(observation,digest) && digest==observation.validation_digest &&
         digest==m_last_validation_digest;
   }

   ulong LastSequence(void) const { return m_last_sequence; }
   datetime LastTime(void) const { return m_last_time; }
};

#endif
