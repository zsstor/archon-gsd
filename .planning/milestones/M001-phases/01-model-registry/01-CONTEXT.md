# Phase 01 Context

**Phase**: 01 — Model Registry + Config Schema
**Intent**: Central registry of available models with capability metadata for routing decisions
**Approach**: Extend config.json with `metadata` sub-objects, create registry helper for ai-delegate

## What this phase delivers

- Extended config.json with `metadata` section per model (context_window, supports_tools, etc.)
- Registry helper script/functions for ai-delegate to query model availability and capabilities
- Python fallback for JSON parsing (jq not installed)

## What's out of scope

- JSON Schema validation (deferred to DEBT.x)
- Actual routing logic (that's phase 02)
- z.ai/Ollama wrappers (that's phase 04)

## Key files that will change

| File | Action | Why |
|------|--------|-----|
| `.planning/config.json` | UPDATE | Add `metadata` sub-objects to each model |
| `~/dev/.meta/bin/model-registry` | CREATE | Helper to query registry from shell |
| `~/dev/.meta/bin/ai-delegate` | UPDATE | Import registry helper, use for availability checks |

## Existing patterns to follow

- `~/dev/.meta/bin/ai-delegate:70-90` — Python fallback for JSON parsing
- `.planning/config.json` — existing model structure to extend

## Constraints

- No jq dependency — use Python fallback
- Graceful failure when models unavailable
- Keep `models.*` and `delegation.*` namespaces separate

## Success criteria

- [ ] Each model in config has `metadata` with context_window, supports_tools, supports_images
- [ ] `model-registry` script can list available models, check availability, query capabilities
- [ ] ai-delegate uses registry for availability checks instead of inline logic
- [ ] No regressions in existing delegation flow

## Validation commands

- `~/dev/.meta/bin/model-registry list`
- `~/dev/.meta/bin/model-registry check gemini-flash`
- `~/dev/.meta/bin/ai-delegate status`
