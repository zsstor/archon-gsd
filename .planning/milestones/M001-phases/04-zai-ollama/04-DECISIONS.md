# Phase 04 Decisions

**Locked**: 2025-04-18
**Phase**: 04 — z.ai + Ollama Integration

## Decision 1: Extract creds from OpenCode config

**Decision**: Extract z.ai API credentials from OpenCode's config directory rather than wrapping the CLI.

**Rationale**: Direct API access is faster, avoids process overhead, and doesn't require OpenCode to be running. One-time credential extraction, then direct `curl` calls.

**Alternatives rejected**:
- Wrap OpenCode CLI — extra process overhead, coupling to OpenCode availability
- Use z.ai CC plugin — overrides Claude Code models, not acceptable
- Manual credential entry — friction, duplication

**Constraints for plan/execute**:
- Research OpenCode config location during implementation
- Handle missing/expired credentials gracefully
- Document credential extraction in README

---

## Decision 2: Default to coding endpoint

**Decision**: Use z.ai coding endpoint by default (`/api/coding/paas/v4`), with `ZAI_ENDPOINT` env var override.

**Rationale**: Most users (including this user) are on Coding Plan. General Plan users can override. Using wrong endpoint returns error 1113.

**Alternatives rejected**:
- Default to general endpoint — would fail for Coding Plan users
- Auto-detect plan type — no reliable way without trial-and-error

**Constraints for plan/execute**:
- `ZAI_ENDPOINT` env var for override
- Clear error message when endpoint mismatch suspected

---

## Decision 3: Non-streaming first

**Decision**: Implement non-streaming API calls initially.

**Rationale**: Task delegation doesn't need real-time output. Simpler error handling, easier response normalization.

**Alternatives rejected**:
- Streaming from start — added complexity without benefit for this use case

**Constraints for plan/execute**:
- `stream: false` in API requests
- Can add streaming later if needed for interactive workflows

---

## Decision 4: Document 220GB local requirement

**Decision**: Document that true local GLM-5.1 inference requires 220GB+ storage; most users should use `:cloud` tag.

**Rationale**: Advanced users should know the tradeoff. Default config uses `:cloud` which routes through Ollama's cloud inference.

**Alternatives rejected**:
- Hide the complexity — leads to confused users hitting storage limits

**Constraints for plan/execute**:
- README section on local vs cloud inference
- Config defaults to `glm-5.1:cloud` for Ollama

---

## Decision 5: Config-driven model names

**Decision**: Model identifiers are config-driven with sensible defaults.

**Rationale**: z.ai uses `glm-5.1`, Ollama uses `glm-5.1:cloud`. Config already has this structure; implementation honors it.

**Alternatives rejected**:
- Hardcode model names — inflexible

**Constraints for plan/execute**:
- Read model_id from config.json
- Allow per-invocation override via env var

---

## Deferred Items

- Streaming support → PARK.x (if needed for interactive workflows)

## Open Risks

- OpenCode config location may vary by version — handle gracefully
- z.ai quota exhausted — test will fail, validates error path
