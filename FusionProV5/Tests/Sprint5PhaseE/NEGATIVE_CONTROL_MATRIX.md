# Sprint 5 Phase E Mutation-Control Matrix

TEST ONLY / NOT FOR PRODUCTION / NO BROKER ACCESS.

These are Python-only, deliberately broken test-double controls. They are
separate from ordinary semantic negatives and do not constitute MQL runtime,
MT5, broker, or physical-persistence evidence. Each mutant first produces the
target unsafe result; a separate observer then applies the named invariant.

The prior Phase-E generation contained three controls: a missing logical Claim
fence, stale-CAS equality, and broker deduplication. AiPASS post-patch review
found that coverage insufficient. This correction expands and separates the
targeted mutation classes without changing frozen source.

| Test ID | Deliberately broken behavior | Correct fixture | Unsafe result produced? | Intended detector/assertion | Detected? | Result | Detection reason | Proof source |
|---|---|---|---:|---|---:|---|---|---|
| `MC-P` | Provisional P is effective after Claim failure | Valid provisional ADR-020 point; Claim fails | YES | P effective iff the same uninterrupted operation wins Claim | YES | PASS | Mutant exposes broker eligibility without successful Claim | `control_p`, `_mutant_p_effective` |
| `MC-JOINT` | Reconciliation performs only per-object seal checks | P11 Checkpoint/Request Set/Broker/Execution objects, all locally sealed but from worlds A/B/C/D | YES | All four objects must describe one coherent world | YES | PASS | All local guards pass before the independent world-coherence assertion detects acceptance | `control_joint`, `_mutant_local_only_reconciliation`, `_joint_world_coherent` |
| `MC-DOMAIN` | Validator verifies source seal but ignores required target domain | Validly sealed Request Set presented at Checkpoint boundary | YES | Distinct frozen digest/type domains are not interchangeable | YES | PASS | Correct path rejects the domain mismatch while mutant accepts the valid source seal | `control_domain`, `_mutant_domain_ignored`, `_correct_domain_validation` |
| `MC-OWNERSHIP-LOGICAL` | Claim checks request identity only | Permit/Snapshot from owner A; current owner/lease/fence/takeover belong to B | YES | Permit, Snapshot and current Claim ownership bindings must all agree | YES | PASS | Request ID passes; complete-binding observer detects stale ownership | `control_ownership_logical`, `_mutant_logical_claim`, `_logical_ownership_coherent` |
| `MC-OWNERSHIP-DURABLE` | Submission Authority CAS omits ownership/fence re-observation inside serialization | Unchanged submission row; takeover advances fence 7→8; old epoch 7 claims | YES | Claim CAS must re-observe current fence at the serialization boundary | YES | PASS | Broken CAS commits stale-owner Claim authority even though the row is unchanged | `control_ownership_durable`, `BrokenSubmissionAuthorityStore.mutant_claim_cas` |
| `MC-GRANT` | Restart maps persisted claimed-unresolved state to event-local grant | Valid `INVOCATION_CLAIMED_UNRESOLVED` read after restart/takeover | YES | Restart must never recreate `CLAIM_GRANTED_NOW` or reinvocation eligibility | YES | PASS | Mutant recreates both the grant and retry eligibility | `control_grant`, `_mutant_restart_claim_state` |
| `MC-BROKER-DEDUPE` | Fake broker silently suppresses duplicate identity | Two physical presentations of `CLAIM-1` | YES | Dumb broker logs/counts every presented invocation | YES | PASS | Two presentations produce one logged call | `control_broker_dedupe`, `MutantDeduplicatingBroker.invoke` |
| `MC-STALE-CAS-EQUALITY` | Generic store accepts stale epoch when bytes are equal | Epoch 6 writes current epoch-7 bytes unchanged | YES | Fence is load-bearing even for byte-identical content | YES | PASS | Equality shortcut bypasses the stale fence | `control_stale_cas_equality`, `MutantEqualityBypassStore.cas` |

Result: **8/8 PASS**, 0 failed. Two repeated executions are deterministic.
Mutation digest: `7273fffd9d72e5c455968979f2544eddc6abb15964b883d1ac034884c066d42f`.

The normal fixture broker remains dumb. None of these mutants alters frozen
Phase B/C/D, Production V5, or ADR code.
