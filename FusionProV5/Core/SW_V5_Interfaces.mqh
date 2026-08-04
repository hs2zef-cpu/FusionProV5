#ifndef SW_V5_INTERFACES_MQH
#define SW_V5_INTERFACES_MQH

#include "SW_V5_Types.mqh"

class ISWV5ExecutionPolicy
{
public:
   virtual string Name() = 0;
   virtual bool EvaluatePolicy(const SWV5_EngineInput &engineInput, const SWV5_LegacyResult &legacy, SWV5_PolicyResult &policy) = 0;
};

#endif
