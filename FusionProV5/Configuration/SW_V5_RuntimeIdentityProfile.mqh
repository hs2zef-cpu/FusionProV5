#ifndef SW_V5_RUNTIME_IDENTITY_PROFILE_MQH
#define SW_V5_RUNTIME_IDENTITY_PROFILE_MQH

// Governed runtime strategy identity for Fusion Pro V5.
// Immutable across requests, retries, restarts, heartbeats, and takeovers.
// The number is not globally unique by itself: authority still derives from
// the existing ownership, permit, admission, and claim contracts. Test fixture
// and reference Magic values remain non-runtime identities.
const ulong SWV5_RUNTIME_STRATEGY_MAGIC = 1179670069;

#endif // SW_V5_RUNTIME_IDENTITY_PROFILE_MQH
