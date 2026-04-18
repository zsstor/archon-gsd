# Phase 04: z.ai + Ollama Integration - Research

**Researched:** 2026-04-18
**Domain:** AI API Integration (z.ai cloud API + Ollama local inference)
**Confidence:** HIGH

## Summary

This phase adds GLM-5.1 as a delegation target through two pathways: z.ai's cloud API for production use and Ollama for local/free inference. Both providers support OpenAI-compatible APIs, which simplifies integration significantly. The current `ai-delegate` script already has a clean architecture for adding new backends via `run_*` functions and availability checks.

The z.ai API uses standard OpenAI-compatible chat completions with Bearer token authentication. Ollama exposes both a native API and an OpenAI-compatible endpoint at `/v1/chat/completions`. The key challenge is response normalization and robust error handling (Ollama not running, z.ai rate limits, model not downloaded).

**Primary recommendation:** Implement two lightweight wrapper scripts (`zai-run` and `ollama-run`) that normalize responses to a common format, then integrate them into `ai-delegate`'s fallback chain. Use the OpenAI-compatible endpoints for both to minimize code duplication.

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| bash | 5.x | Shell scripting | Already used by ai-delegate |
| curl | 8.x | HTTP requests | Universal, no dependencies |
| jq | 1.7+ | JSON parsing | Already used by ai-delegate |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| ollama CLI | 0.21.0+ | Local model management | Pull models, check availability |
| timeout | coreutils | Request timeouts | Wrap curl for safety |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| curl | Python requests | Adds dependency; bash is already used |
| bash scripts | Node.js wrappers | More code; ai-delegate is bash |
| Direct API calls | litellm | Heavier; overkill for two providers |

**Installation:**
```bash
# Ollama (if not installed)
curl -fsSL https://ollama.com/install.sh | sh

# Pull GLM-5.1 cloud model
ollama pull glm-5.1:cloud

# jq (usually pre-installed)
apt-get install jq  # Debian/Ubuntu
```

**Version verification:** [VERIFIED: ollama CLI 0.21.0 on local system, jq available]

## Architecture Patterns

### Recommended Project Structure

```
~/dev/.meta/bin/
├── ai-delegate           # Main orchestrator (UPDATE)
├── zai-run              # z.ai API wrapper (CREATE)
└── ollama-run           # Ollama wrapper (CREATE)
```

### Pattern 1: OpenAI-Compatible API Abstraction

**What:** Both z.ai and Ollama expose OpenAI-compatible `/v1/chat/completions` endpoints. Use the same request format for both, only changing the base URL.

**When to use:** Any time you're calling either provider.

**Example:**
```bash
# Source: https://docs.z.ai/guides/overview/quick-start
# z.ai endpoint
curl -s "https://api.z.ai/api/paas/v4/chat/completions" \
  -H "Authorization: Bearer $ZAI_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "glm-5.1",
    "messages": [{"role": "user", "content": "Hello"}],
    "stream": false
  }'

# Ollama endpoint (same format!)
# Source: https://docs.ollama.com/api/openai-compatibility
curl -s "http://localhost:11434/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "glm-5.1:cloud",
    "messages": [{"role": "user", "content": "Hello"}],
    "stream": false
  }'
```

### Pattern 2: Availability Check Before Invocation

**What:** Check if provider is available before attempting to use it.

**When to use:** In routing logic, before adding to fallback chain.

**Example:**
```bash
# Source: https://docs.ollama.com/api/introduction
# Ollama health check
ollama_available() {
    curl -s --max-time 2 http://localhost:11434/ | grep -q "Ollama is running"
}

# Ollama model check
ollama_has_model() {
    local model="$1"
    ollama list 2>/dev/null | grep -q "${model%%:*}"
}

# z.ai reachability (just check if API key exists)
zai_available() {
    [[ -n "${ZAI_API_KEY:-}" ]]
}
```

### Pattern 3: Response Normalization

**What:** Extract content from provider-specific response format into common structure.

**When to use:** After every API call.

**Example:**
```bash
# Both providers return OpenAI-compatible format when using /v1 endpoint
normalize_response() {
    local response="$1"
    # Extract content from: {"choices":[{"message":{"content":"..."}}]}
    echo "$response" | jq -r '.choices[0].message.content // empty'
}
```

### Anti-Patterns to Avoid

- **Hardcoding model names:** Use config.json model_id field instead
- **Ignoring streaming:** z.ai supports streaming but start with non-streaming for simplicity
- **No timeout:** Always wrap curl with timeout to prevent hanging
- **Swallowing errors:** Log detailed error information for debugging

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| JSON parsing | regex/awk | jq | Edge cases, nested structures |
| HTTP requests | netcat/bash sockets | curl | TLS, redirects, error codes |
| Timeout handling | background process + kill | timeout command | Race conditions |
| Model registry | hardcoded arrays | config.json | Already exists, single source of truth |

**Key insight:** The infrastructure is already in place (config.json, ai-delegate patterns). This phase is about wiring up two new backends, not rebuilding the system.

## Common Pitfalls

### Pitfall 1: Ollama Not Running

**What goes wrong:** curl to localhost:11434 hangs or fails with connection refused.

**Why it happens:** Ollama server not started, or crashed.

**How to avoid:** Check health endpoint before making requests.

**Warning signs:** Connection timeout, "Connection refused" error.

**Detection code:**
```bash
# Source: https://docs.ollama.com/api/introduction
if ! curl -s --max-time 2 http://localhost:11434/ | grep -q "Ollama"; then
    log "Ollama not running"
    return 127
fi
```

### Pitfall 2: Model Not Downloaded in Ollama

**What goes wrong:** Ollama returns error that model doesn't exist.

**Why it happens:** GLM-5.1 cloud model not pulled yet.

**How to avoid:** Check with `ollama list` before first use, or handle error gracefully.

**Warning signs:** Error message containing "model not found" or "pull".

**Detection code:**
```bash
# From config.json check_command
ollama list | grep -q glm
```

### Pitfall 3: z.ai Rate Limits (429)

**What goes wrong:** API returns 429 "Too Many Requests" or error code 1302/1303.

**Why it happens:** Exceeded requests per minute or tokens per minute.

**How to avoid:** Implement exponential backoff, honor Retry-After header.

**Warning signs:** HTTP 429, error codes 1302, 1303, 1308.

**Detection code:**
```bash
# Source: https://docs.z.ai/api-reference/api-code
if echo "$response" | grep -qE '"code":\s*"(1302|1303|1308|429)"'; then
    log "Rate limit hit, backing off"
    sleep 5
    return 2  # Signal retry-able error
fi
```

### Pitfall 4: z.ai Wrong Endpoint for Coding Plan

**What goes wrong:** Error 1113 "Insufficient balance" even with active subscription.

**Why it happens:** Coding Plan keys require the `/api/coding/paas/v4` endpoint, not `/api/paas/v4`.

**How to avoid:** Use the correct endpoint based on plan type (check config or environment).

**Warning signs:** Error 1113 despite having credits.

**Config option:**
```json
{
  "glm-zai": {
    "endpoint": "https://api.z.ai/api/coding/paas/v4"
  }
}
```

### Pitfall 5: Model Name Mismatch

**What goes wrong:** Model not found on one provider.

**Why it happens:** z.ai uses `glm-5.1`, Ollama uses `glm-5.1:cloud`.

**How to avoid:** Store provider-specific model_id in config.json (already done).

**Warning signs:** "Model not found" error from one provider but not the other.

## Code Examples

### z.ai Wrapper (zai-run)

```bash
#!/usr/bin/env bash
# Source: https://docs.z.ai/guides/overview/quick-start
# Source: https://docs.z.ai/api-reference/api-code

set -euo pipefail

ZAI_ENDPOINT="${ZAI_ENDPOINT:-https://api.z.ai/api/paas/v4/chat/completions}"
ZAI_MODEL="${ZAI_MODEL:-glm-5.1}"
ZAI_TIMEOUT="${ZAI_TIMEOUT:-300}"

die() { echo "[zai-run] ERROR: $*" >&2; exit 1; }
log() { echo "[zai-run] $*" >&2; }

[[ -z "${ZAI_API_KEY:-}" ]] && die "ZAI_API_KEY not set"

prompt="$1"
output_file="${2:-/dev/stdout}"

response=$(timeout "$ZAI_TIMEOUT" curl -s "$ZAI_ENDPOINT" \
    -H "Authorization: Bearer $ZAI_API_KEY" \
    -H "Content-Type: application/json" \
    -d "$(jq -n --arg model "$ZAI_MODEL" --arg prompt "$prompt" '{
        model: $model,
        messages: [{role: "user", content: $prompt}],
        stream: false
    }')")

# Check for errors
# Source: https://docs.z.ai/api-reference/api-code
if echo "$response" | jq -e '.error' &>/dev/null; then
    error_code=$(echo "$response" | jq -r '.error.code // "unknown"')
    error_msg=$(echo "$response" | jq -r '.error.message // "Unknown error"')

    case "$error_code" in
        1113) die "Insufficient balance (use coding endpoint?)" ;;
        1302|1303|1308) log "Rate limited"; exit 2 ;;
        1211) die "Model $ZAI_MODEL not found" ;;
        *) die "API error $error_code: $error_msg" ;;
    esac
fi

# Extract content
content=$(echo "$response" | jq -r '.choices[0].message.content // empty')
[[ -z "$content" ]] && die "Empty response from z.ai"

echo "$content" > "$output_file"
log "Success"
```

### Ollama Wrapper (ollama-run)

```bash
#!/usr/bin/env bash
# Source: https://docs.ollama.com/api/openai-compatibility
# Source: https://docs.ollama.com/api/introduction

set -euo pipefail

OLLAMA_HOST="${OLLAMA_HOST:-http://localhost:11434}"
OLLAMA_MODEL="${OLLAMA_MODEL:-glm-5.1:cloud}"
OLLAMA_TIMEOUT="${OLLAMA_TIMEOUT:-300}"

die() { echo "[ollama-run] ERROR: $*" >&2; exit 1; }
log() { echo "[ollama-run] $*" >&2; }

# Health check
if ! curl -s --max-time 2 "$OLLAMA_HOST/" | grep -q "Ollama"; then
    die "Ollama not running at $OLLAMA_HOST"
fi

# Model check
if ! ollama list 2>/dev/null | grep -q "${OLLAMA_MODEL%%:*}"; then
    log "Model $OLLAMA_MODEL not found, attempting pull..."
    ollama pull "$OLLAMA_MODEL" || die "Failed to pull $OLLAMA_MODEL"
fi

prompt="$1"
output_file="${2:-/dev/stdout}"

response=$(timeout "$OLLAMA_TIMEOUT" curl -s "$OLLAMA_HOST/v1/chat/completions" \
    -H "Content-Type: application/json" \
    -d "$(jq -n --arg model "$OLLAMA_MODEL" --arg prompt "$prompt" '{
        model: $model,
        messages: [{role: "user", content: $prompt}],
        stream: false
    }')")

# Check for errors
if echo "$response" | jq -e '.error' &>/dev/null; then
    error_msg=$(echo "$response" | jq -r '.error // "Unknown error"')
    die "Ollama error: $error_msg"
fi

# Extract content
content=$(echo "$response" | jq -r '.choices[0].message.content // empty')
[[ -z "$content" ]] && die "Empty response from Ollama"

echo "$content" > "$output_file"
log "Success"
```

### Integration into ai-delegate

```bash
# Add to ai-delegate after has_codex()

has_glm_ollama() {
    curl -s --max-time 2 http://localhost:11434/ | grep -q "Ollama" && \
    ollama list 2>/dev/null | grep -q glm
}

has_glm_zai() {
    [[ -n "${ZAI_API_KEY:-}" ]]
}

run_glm_ollama() {
    local prompt="$1"
    local output_file="$2"

    if ! has_glm_ollama; then
        log "Ollama GLM not available"
        return 127
    fi

    log "Starting Ollama GLM task..."
    local exit_code=0

    timeout "$AI_TIMEOUT" ~/dev/.meta/bin/ollama-run "$prompt" "$output_file" || exit_code=$?

    return $exit_code
}

run_glm_zai() {
    local prompt="$1"
    local output_file="$2"

    if ! has_glm_zai; then
        log "z.ai API key not set"
        return 127
    fi

    log "Starting z.ai GLM task..."
    local exit_code=0

    timeout "$AI_TIMEOUT" ~/dev/.meta/bin/zai-run "$prompt" "$output_file" || exit_code=$?

    return $exit_code
}
```

## API Reference Summary

### z.ai API

| Property | Value |
|----------|-------|
| Base URL (general) | `https://api.z.ai/api/paas/v4` |
| Base URL (coding) | `https://api.z.ai/api/coding/paas/v4` |
| Chat endpoint | `/chat/completions` |
| Auth header | `Authorization: Bearer $ZAI_API_KEY` |
| Model ID | `glm-5.1` |
| Context window | 200K tokens |
| Max output | 128K tokens |

[VERIFIED: https://docs.z.ai/guides/overview/quick-start]

**Key Error Codes:**
| Code | Meaning | Action |
|------|---------|--------|
| 1113 | Insufficient balance / wrong endpoint | Check endpoint for plan type |
| 1211 | Model not found | Check model name |
| 1302 | High concurrency | Backoff + retry |
| 1303 | High frequency | Backoff + retry |
| 1308 | Usage limit reached | Wait for reset |

[VERIFIED: https://docs.z.ai/api-reference/api-code]

### Ollama API

| Property | Value |
|----------|-------|
| Base URL | `http://localhost:11434` |
| OpenAI-compat endpoint | `/v1/chat/completions` |
| Native chat endpoint | `/api/chat` |
| Health check | `GET /` returns "Ollama is running" |
| List models | `GET /api/tags` or `ollama list` |
| Running models | `GET /api/ps` or `ollama ps` |
| Model ID | `glm-5.1:cloud` |
| Context window | 198K tokens |

[VERIFIED: https://docs.ollama.com/api/openai-compatibility, local testing]

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Zhipu API at bigmodel.cn | z.ai unified platform | 2025 | New endpoint URLs |
| GLM-4 series | GLM-5.1 flagship | April 2026 | Better coding performance |
| Ollama native API only | OpenAI-compat `/v1` | 2024 | Easier integration |
| ollama run | ollama run + ollama launch | Jan 2026 | Direct coding tool integration |

**Deprecated/outdated:**
- `open.bigmodel.cn` endpoint: Still works but `api.z.ai` is preferred
- `zhipu/` LiteLLM prefix: Use `zai/` instead

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Ollama | glm-ollama provider | YES | 0.21.0 | Skip provider |
| curl | HTTP requests | YES | (standard) | None needed |
| jq | JSON parsing | YES | (standard) | Python fallback in ai-delegate |
| ZAI_API_KEY | glm-zai provider | NO | N/A | Skip provider |

[VERIFIED: Local system check]

**Missing dependencies with no fallback:**
- None (Ollama is installed; z.ai just needs API key)

**Missing dependencies with fallback:**
- GLM-5.1 model in Ollama: Not downloaded yet; `ollama pull glm-5.1:cloud` will fetch it on first use
- ZAI_API_KEY: User must set this to use z.ai; provider will be skipped if not set

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | z.ai Coding Plan requires `/api/coding/paas/v4` endpoint | Common Pitfalls | Confusing 1113 errors for users with Coding Plan |
| A2 | `glm-5.1:cloud` is the correct Ollama tag | Code Examples | Model pull fails |
| A3 | GLM-5.1 performs well for implementation tasks | Summary | Poor task quality |

## Open Questions

1. **Coding vs General Endpoint**
   - What we know: z.ai has separate endpoints for Coding Plan and general use
   - What's unclear: How to detect which plan the user has
   - Recommendation: Add `ZAI_ENDPOINT` env var override, document both endpoints

2. **Streaming Implementation**
   - What we know: Both providers support streaming
   - What's unclear: Whether ai-delegate needs streaming for task delegation
   - Recommendation: Start with non-streaming; add streaming later if needed for long responses

3. **Local GLM-5.1 Full Model**
   - What we know: `glm-5.1:cloud` routes through Ollama's cloud; full local requires 220GB+ quantized
   - What's unclear: Whether local inference is practical for target hardware
   - Recommendation: Use cloud tag initially; document local requirements for advanced users

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Bash (bats or manual) |
| Config file | None (shell scripts) |
| Quick run command | `zai-run "test" /tmp/out.txt && cat /tmp/out.txt` |
| Full suite command | Manual integration test |

### Phase Requirements -> Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| P04-01 | z.ai wrapper accepts prompt, returns response | integration | `ZAI_API_KEY=test zai-run "Hello"` | Wave 0 |
| P04-02 | Ollama wrapper checks health, runs model | integration | `ollama-run "Hello"` | Wave 0 |
| P04-03 | ai-delegate routes to glm providers | integration | `AI_TOOL=glm-ollama ai-delegate impl "Test"` | Wave 0 |
| P04-04 | Error handling for rate limits | unit | Mock 429 response | Wave 0 |
| P04-05 | Availability checks work | unit | `has_glm_ollama && echo ok` | Wave 0 |

### Wave 0 Gaps

- [ ] `zai-run` script - covers P04-01
- [ ] `ollama-run` script - covers P04-02
- [ ] Integration tests for new providers in ai-delegate
- [ ] Documentation for ZAI_API_KEY setup

## Sources

### Primary (HIGH confidence)

- [Z.AI Quick Start Docs](https://docs.z.ai/guides/overview/quick-start) - API structure, auth, endpoints
- [Z.AI Error Codes](https://docs.z.ai/api-reference/api-code) - Error handling
- [Z.AI Streaming](https://docs.z.ai/guides/capabilities/streaming) - SSE format
- [Ollama OpenAI Compatibility](https://docs.ollama.com/api/openai-compatibility) - /v1 endpoint
- [Ollama API Introduction](https://docs.ollama.com/api/introduction) - Health check, endpoints
- [Ollama GLM-5.1 Library](https://ollama.com/library/glm-5.1) - Model availability
- [LiteLLM Z.AI Provider](https://docs.litellm.ai/docs/providers/zai) - Model prefixes, env vars

### Secondary (MEDIUM confidence)

- [GitHub: ollama/ollama](https://github.com/ollama/ollama) - CLI commands
- [GLM-5.1 Hugging Face guide](https://explainx.ai/blog/glm-5-1-hugging-face-how-to-run-ollama) - Model naming differences

### Tertiary (LOW confidence)

- [WebSearch: Rate limit issues](https://github.com/openclaw/openclaw/issues/31234) - Community reports of 1113 errors

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - bash/curl/jq already used by ai-delegate
- Architecture: HIGH - OpenAI-compatible APIs are well-documented
- Pitfalls: MEDIUM - some rate limit behavior is community-reported, not official docs

**Research date:** 2026-04-18
**Valid until:** 2026-05-18 (30 days - APIs are stable)
