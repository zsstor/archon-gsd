# Phase 04 Context

**Phase**: 04 — z.ai + Ollama Integration
**Intent**: Add GLM-5.1 as delegation target via z.ai (cloud) and Ollama (local/cloud)
**Approach**: Extract creds from OpenCode, create wrapper scripts, add to ai-delegate fallback chain

## What this phase delivers

- `zai-run` wrapper script for direct z.ai API calls
- `ollama-run` wrapper script for Ollama inference
- Both integrated into ai-delegate as delegation targets
- Response normalization to common format

## What's out of scope

- Streaming support (deferred to PARK.x if needed)
- True local inference (220GB+ storage) — document but don't require
- Automatic plan type detection for z.ai

## Key files that will change

| File | Action | Why |
|------|--------|-----|
| `~/dev/.meta/bin/zai-run` | CREATE | z.ai API wrapper |
| `~/dev/.meta/bin/ollama-run` | CREATE | Ollama API wrapper |
| `~/dev/.meta/bin/ai-delegate` | UPDATE | Add zai/ollama to routing |
| `.planning/config.json` | UPDATE | Endpoint URLs, model IDs |
| `README.md` | UPDATE | Document z.ai/Ollama setup |

## Existing patterns to follow

- `~/dev/.meta/bin/ai-delegate` — existing wrapper pattern for Gemini/Codex
- OpenAI-compatible API format — both providers use this

## Constraints

- Extract creds from OpenCode config (research location during impl)
- Default to z.ai coding endpoint (`/api/coding/paas/v4`)
- `ZAI_ENDPOINT` env var for override
- Non-streaming (`stream: false`)
- Ollama default to `glm-5.1:cloud` tag

## Success criteria

- [ ] `zai-run "prompt"` returns completion (or graceful error if quota exhausted)
- [ ] `ollama-run "prompt"` returns completion (or error if Ollama not running)
- [ ] ai-delegate can route to z.ai/Ollama via config
- [ ] Error handling for: Ollama not running, z.ai rate limit, wrong endpoint
- [ ] README documents setup and 220GB local storage caveat

## Validation commands

- `~/dev/.meta/bin/zai-run "Hello"` (may fail if quota exhausted — OK)
- `~/dev/.meta/bin/ollama-run "Hello"`
- `~/dev/.meta/bin/ai-delegate status` (shows z.ai/Ollama availability)
