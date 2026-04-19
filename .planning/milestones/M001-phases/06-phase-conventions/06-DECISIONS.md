# Phase 06 Decisions

**Locked**: 2025-04-18
**Phase**: 06 — Phase Conventions

## Decision 1: Use DEBT.x and PARK.x naming

**Decision**: Replace numeric 999.x/9999.x with semantic `DEBT.x` and `PARK.x` prefixes.

**Rationale**:
- `DEBT.x` — deferred technical debt, cleanup items (was 999.x)
- `PARK.x` — parking lot for ideas awaiting prioritization (was 9999.x)

Clearer intent, sorts after numeric phases alphabetically.

**Alternatives rejected**:
- `999.x`/`9999.x` — clunky, magic numbers
- `FIX.x` — might conflict with bug fix phases
- Single-letter prefixes (`D.x`, `B.x`) — too terse, requires learning

**Constraints for plan/execute**:
- Update config.json `phase_conventions` section
- Update any workflows/skills referencing old conventions

---

## Decision 2: Manual increment on DEBT.x close

**Decision**: DEBT.1 is a catch-all; when closed, next deferral creates DEBT.2 manually.

**Rationale**: Avoids runaway auto-creation. User explicitly decides when a debt batch is done and starts a new one.

**Alternatives rejected**:
- Auto-increment on close — could create unwanted phases
- Single DEBT phase forever — no way to batch/archive completed work

**Constraints for plan/execute**:
- Document the lifecycle in PROJECT.md
- No auto-creation logic needed

---

## Decision 3: Milestone-scoped phases

**Decision**: DEBT.x and PARK.x are scoped to current milestone.

**Rationale**: Each milestone has its own cleanup backlog; archived together when milestone completes. Clean separation.

**Alternatives rejected**:
- Project-wide — mixes concerns across milestones

**Constraints for plan/execute**:
- Phase directories: `.planning/milestones/M001-phases/DEBT.1-cleanup/`
- Naming consistent with other milestone phases

---

## Decision 4: PARK.x completes on promotion

**Decision**: A PARK.x phase completes when its item is promoted to a sequential phase number.

**Rationale**: The parking lot is for ideas awaiting prioritization. Once prioritized (moved to phase 12, etc.), the parking slot is done.

**Alternatives rejected**:
- Manual close — extra ceremony for no benefit
- Never close — clutter

**Constraints for plan/execute**:
- Document promotion = completion semantics
- Promotion might be to current or future milestone

---

## Decision 5: Directory location follows milestone pattern

**Decision**: Use `.planning/milestones/M001-phases/DEBT.1-cleanup/` pattern.

**Rationale**: Consistent with other phases, lives with its milestone, easy to archive.

**Alternatives rejected**:
- Separate `.planning/debt/` directory — breaks milestone cohesion

**Constraints for plan/execute**:
- Phase directories follow existing pattern
- Slug after the prefix (e.g., `DEBT.1-cleanup`, `PARK.1-model-ideas`)

---

## Deferred Items

None.

## Open Risks

- Alphabetic prefixes sort after numbers — intended, but verify tooling handles it
