# Phase 06 Context

**Phase**: 06 — Phase Conventions
**Intent**: Make DEBT.x and PARK.x conventions config-driven, update workflows to read from config
**Approach**: Update config.json, fix review-pr skill, document lifecycle

## What this phase delivers

- Updated config.json with `DEBT` and `PARK` prefixes (replacing 999/9999)
- review-pr skill updated to read conventions from config
- Documented lifecycle semantics in PROJECT.md

## What's out of scope

- Auto-creation of phase directories (on-demand is fine)
- Workflow tooling for DEBT/PARK management

## Key files that will change

| File | Action | Why |
|------|--------|-----|
| `.planning/config.json` | UPDATE | Change `cleanup_series: 999` to `cleanup_prefix: "DEBT"` |
| `~/.claude/skills/review-pr/SKILL.md` | UPDATE | Replace `grep -v "999"` with config-driven check |
| `.planning/PROJECT.md` | UPDATE | Document DEBT.x/PARK.x lifecycle |

## Existing patterns to follow

- `~/.claude/skills/review-pr/SKILL.md:196` — existing phase filtering logic
- Node.js config access: `node -pe "require('./.planning/config.json').phase_conventions"`

## Constraints

- Use Node.js for config access (jq not installed)
- Milestone-scoped: `.planning/milestones/M001-phases/DEBT.1-cleanup/`
- Manual increment: closing DEBT.1, user creates DEBT.2 for next batch
- PARK.x completes when promoted to sequential phase

## Success criteria

- [ ] config.json uses `cleanup_prefix: "DEBT"` and `backlog_prefix: "PARK"`
- [ ] review-pr skill reads phase conventions from config
- [ ] PROJECT.md documents lifecycle (manual increment, promotion = completion)
- [ ] Phase directories sort correctly: 01, 02, ..., DEBT.1, PARK.1

## Validation commands

- `node -pe "require('./.planning/config.json').phase_conventions"`
- `ls .planning/milestones/M001-phases/ | sort` (verify sort order)
