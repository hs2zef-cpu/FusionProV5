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
};

class SWV5S5_FakeAuthoritativeClock
{
private:
   string m_clock_id;
   string m_symbol;
   SWV5_TimeAuthority m_authority;
   ulong m_last_sequence;
   datetime m_last_time;

public:
   SWV5S5_FakeAuthoritativeClock(void):m_authority(SWV5_TIME_AUTHORITY_NONE),m_last_sequence(0),m_last_time(0) {}

   void Configure(const string clock_id,const SWV5_TimeAuthority authority,const string symbol)
   {
      m_clock_id=clock_id;
      m_authority=authority;
      m_symbol=symbol;
      m_last_sequence=0;
      m_last_time=0;
   }

   bool Accept(const SWV5S5_ReferenceClockObservation &observation)
   {
      if(observation.clock_id!=m_clock_id || observation.authority!=m_authority ||
         observation.source_symbol!=m_symbol || !observation.current_event_provenance ||
         observation.event_identity=="" || observation.observed_at<=0 ||
         observation.observation_sequence<=m_last_sequence ||
         observation.observed_at<m_last_time)
         return false;
      m_last_sequence=observation.observation_sequence;
      m_last_time=observation.observed_at;
      return true;
   }

   ulong LastSequence(void) const { return m_last_sequence; }
   datetime LastTime(void) const { return m_last_time; }
};

#endif
