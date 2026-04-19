# Phase 01 Decisions

**Locked**: 2025-04-18
**Phase**: 01 — Model Registry + Config Schema

## Decision 1: Test z.ai via delegation

**Decision**: Test z.ai `/models` endpoint during implementation by attempting delegation.

**Rationale**: User currently out of quota, so test will return failure — but that validates error handling path. Success path tested when quota replenishes.

**Alternatives rejected**:
- Skip testing — would leave integration untested
- Mock the endpoint — wouldn't catch real API quirks

**Constraints for plan/execute**:
- Graceful failure handling required
- Log the attempt for debugging

---

## Decision 2: Defer schema validation

**Decision**: Defer JSON Schema validation to DEBT.x cleanup phase.

**Rationale**: Config is hand-edited, ajv-cli adds complexity without immediate value. Can add later when config stabilizes.

**Alternatives rejected**:
- Implement now — premature optimization
- Never validate — leaves door open for subtle config bugs

**Constraints for plan/execute**:
- Config errors should fail fast with clear messages
- No ajv dependency in this phase

---

## Decision 3: Split metadata from capabilities

**Decision**: Add `metadata` sub-object for technical attributes; keep `capabilities` for task routing.

**Rationale**:
- `capabilities`: what the model is good at (judgment, scaffolding, tdd-cycle)
- `metadata`: technical specs (context_window, supports_tools, supports_images)

Different consumers care about different things.

**Alternatives rejected**:
- Flat structure — mixes concerns, harder to extend

**Constraints for plan/execute**:
- Update config.json schema
- Document both sections in comments or README

---

## Decision 4: Keep both namespaces

**Decision**: Keep `models.*` and `delegation.*` as separate config sections.

**Rationale**:
- `models.*` = registry (what exists, capabilities, endpoints)
- `delegation.*` = routing config (task→model mappings, fallback chains)

They reference each other but serve different purposes.

**Alternatives rejected**:
- Merge into one — conflates registry with routing logic

**Constraints for plan/execute**:
- Ensure ai-delegate reads both sections appropriately
- Document the relationship

---

## Deferred Items

- JSON Schema validation → DEBT.x

## Open Risks

- z.ai quota exhausted — test will fail, but that's expected and validates error path
