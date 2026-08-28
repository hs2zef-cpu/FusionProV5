#ifndef SW_V5_S5_REFERENCE_PUBLICATION_STORE_MQH
#define SW_V5_S5_REFERENCE_PUBLICATION_STORE_MQH

// REFERENCE ONLY / NOT FOR PRODUCTION / NO BROKER ACCESS

#include "SW_V5_S5_FakeTransactionalStore.mqh"

struct SWV5S5_ReferencePublicationState
{
   ulong logical_revision;
   ulong store_revision;
   ulong record_sequence;
   string content_digest;
   string ownership_fence_digest;
   ulong takeover_generation;
   bool clean_shutdown;
};

class SWV5S5_ReferencePublicationStore
{
private:
   SWV5S5_ReferencePublicationState m_request_set;
   SWV5S5_ReferencePublicationState m_checkpoint;
   bool m_request_set_reloaded;

   bool ExactExpected(const SWV5S5_ReferencePublicationState &current,
                      const SWV5S5_ReferencePublicationState &expected) const
   {
      return current.logical_revision==expected.logical_revision &&
             current.store_revision==expected.store_revision &&
             current.record_sequence==expected.record_sequence &&
             current.content_digest==expected.content_digest &&
             current.ownership_fence_digest==expected.ownership_fence_digest &&
             current.takeover_generation==expected.takeover_generation;
   }

public:
   void Initialize(const SWV5S5_ReferencePublicationState &request_set,
                   const SWV5S5_ReferencePublicationState &checkpoint)
   {
      m_request_set=request_set;
      m_checkpoint=checkpoint;
      m_request_set_reloaded=false;
   }

   bool CompareAndPublishRequestSet(const SWV5S5_ReferencePublicationState &expected,
                                    const SWV5S5_ReferencePublicationState &proposed)
   {
      if(!ExactExpected(m_request_set,expected) ||
         proposed.logical_revision!=expected.logical_revision+1 ||
         proposed.store_revision!=expected.store_revision+1 ||
         proposed.record_sequence!=expected.record_sequence+1 ||
         proposed.ownership_fence_digest!=expected.ownership_fence_digest ||
         proposed.takeover_generation!=expected.takeover_generation ||
         proposed.content_digest=="")
         return false;
      m_request_set=proposed;
      m_request_set_reloaded=false;
      return true;
   }

   bool AuthoritativeReloadRequestSet(const string expected_digest)
   {
      m_request_set_reloaded=(m_request_set.content_digest==expected_digest);
      return m_request_set_reloaded;
   }

   bool CompareAndPublishCheckpoint(const SWV5S5_ReferencePublicationState &expected,
                                    const SWV5S5_ReferencePublicationState &proposed)
   {
      if(!m_request_set_reloaded || !ExactExpected(m_checkpoint,expected) ||
         proposed.logical_revision!=expected.logical_revision+1 ||
         proposed.store_revision!=expected.store_revision+1 ||
         proposed.record_sequence!=expected.record_sequence+1 ||
         proposed.ownership_fence_digest!=expected.ownership_fence_digest ||
         proposed.takeover_generation!=expected.takeover_generation ||
         proposed.content_digest=="")
         return false;
      m_checkpoint=proposed;
      return true;
   }

   bool IsSplitPublication(void) const
   {
      return m_request_set.logical_revision>m_checkpoint.logical_revision;
   }
};

#endif
