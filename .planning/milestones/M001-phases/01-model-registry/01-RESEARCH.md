# Phase 01: Model Registry + Config Schema - Research

**Researched:** 2026-04-18
**Domain:** Model registry design, configuration schema, availability checking
**Confidence:** HIGH

## Summary

This research establishes patterns for a central model registry that routing decisions can consume. The existing `config.json` already has a solid `models` section structure. The key gaps are: (1) capability metadata needs expansion for routing decisions, (2) availability checking must work without jq since it's not installed, and (3) schema validation should use ajv-cli or Python fallback for simplicity.

The recommended approach is to extend the existing config schema with standardized capability fields, implement availability checks using bash/curl/Python fallback patterns (since jq is unavailable), and defer JSON Schema validation to a later cleanup phase since it adds complexity without immediate value.

**Primary recommendation:** Extend `config.json` models section with capability metadata, create a `model-registry.sh` library that loads and caches model data using Python fallback (jq not available), and implement per-provider availability checks.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Python 3 | 3.x (system) | JSON parsing fallback | Already used in ai-delegate, always available |
| curl | (system) | HTTP availability probes | Standard POSIX, no dependencies |
| bash | 5.x | Shell scripting | Script host |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| ajv-cli | 5.0.0 | JSON Schema validation | Optional validation step, not blocking |
| pydantic | 2.12.5 | Python schema validation | If Python validation preferred |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| jq for parsing | Python fallback | Python slightly slower but always available |
| ajv-cli validation | No validation | Less safety but simpler implementation |
| Custom availability checks | Health endpoints | Providers don't offer consistent health APIs |

**Installation:**
```bash
# Optional: JSON Schema validation (not required for MVP)
npm install -g ajv-cli
```

**Version verification:** [VERIFIED: npm registry] ajv-cli 5.0.0 is current stable.

## Architecture Patterns

### Recommended Project Structure
```
.archon/
└── lib/
    └── model-registry.sh    # CREATE: Registry loader + availability checks
.planning/
└── config.json              # UPDATE: Extended model metadata schema
```

### Pattern 1: Config-Driven Model Registry
**What:** All model definitions live in `config.json`, loaded once per session and cached in shell variables.
**When to use:** Always - single source of truth.
**Example:**
```bash
# Source: Current ai-delegate implementation
# Load model by name, return JSON blob
get_model_config() {
    local model_name="$1"
    python3 -c "
import json, sys
with open('$CONFIG_FILE') as f:
    cfg = json.load(f)
model = cfg.get('models', {}).get('$model_name', {})
print(json.dumps(model))
"
}
```

### Pattern 2: Provider-Specific Availability Checks
**What:** Each provider has a dedicated check function that probes actual availability.
**When to use:** Before routing to a model - ensures we don't route to unavailable backends.
**Example:**
```bash
# Ollama: Check if daemon running and model pulled
check_ollama_model() {
    local model_id="$1"
    # First check if ollama is running
    curl -sf http://localhost:11434/api/tags >/dev/null 2>&1 || return 1
    # Then check if specific model is available
    curl -sf http://localhost:11434/api/tags | \
        python3 -c "import json,sys; models=[m['name'] for m in json.load(sys.stdin).get('models',[])]; sys.exit(0 if '$model_id' in models else 1)"
}

# Gemini CLI: Check command exists
check_gemini() {
    command -v gemini &>/dev/null
}

# Codex CLI: Check command exists
check_codex() {
    command -v codex &>/dev/null
}

# z.ai: Check endpoint reachable with auth
check_zai() {
    [[ -n "${ZHIPU_API_KEY:-}" ]] && \
    curl -sf -H "Authorization: Bearer $ZHIPU_API_KEY" \
        https://api.z.ai/api/paas/v4/models >/dev/null 2>&1
}
```

### Pattern 3: Capability Metadata Schema
**What:** Standardized fields that routing can query without parsing task descriptions.
**When to use:** When implementing task routing logic.
**Example:**
```json
{
  "models": {
    "claude-opus": {
      "provider": "anthropic",
      "model_id": "claude-opus-4-5-20251101",
      "capabilities": ["judgment", "architecture", "complex-reasoning", "code-review"],
      "cost_tier": "high",
      "check_command": null,
      "metadata": {
        "max_input_tokens": 200000,
        "max_output_tokens": 8192,
        "supports_tools": true,
        "supports_images": true,
        "supports_streaming": true
      }
    }
  }
}
```

### Anti-Patterns to Avoid
- **Hardcoded model names:** Never check `if model == "claude-opus"`, use capabilities/properties instead
- **Assuming availability:** Always check before routing - models can be offline, rate-limited, or misconfigured
- **Parsing task text for routing:** Use explicit task_type or capability matching, not keyword heuristics

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| JSON parsing in bash | sed/awk hacks | Python json module | Edge cases (nested objects, escaping) are endless |
| HTTP requests | netcat, /dev/tcp | curl | SSL, timeouts, redirects handled |
| Config validation | Custom checks | ajv-cli or pydantic | Schema evolution, error messages |

**Key insight:** The existing ai-delegate already uses Python fallback for JSON parsing. Continue this pattern - it's reliable and portable.

## Common Pitfalls

### Pitfall 1: jq Dependency
**What goes wrong:** Scripts fail on systems without jq.
**Why it happens:** jq is common in dev environments but not universal.
**How to avoid:** Always implement Python fallback (as ai-delegate does).
**Warning signs:** `jq: command not found` in CI/fresh systems.

### Pitfall 2: Stale Availability Cache
**What goes wrong:** Routing to a model that was available at startup but is now down.
**Why it happens:** Ollama can be stopped, API keys rotated, rate limits hit.
**How to avoid:** Re-check availability on first routing failure, then cache for session.
**Warning signs:** Repeated failures to same model.

### Pitfall 3: Blocking Availability Checks
**What goes wrong:** Startup takes 10+ seconds checking all providers.
**Why it happens:** Sequential HTTP calls with default timeouts.
**How to avoid:** Lazy checking - only probe when first routing to that model.
**Warning signs:** Slow `ai-delegate status` command.

### Pitfall 4: No z.ai Auth Discovery
**What goes wrong:** z.ai check passes but calls fail with 401.
**Why it happens:** `ZHIPU_API_KEY` not set or invalid.
**How to avoid:** Check env var presence AND make authenticated probe.
**Warning signs:** 401 errors after routing decision.

## Code Examples

### Loading Model Registry (Python fallback)
```bash
# Source: Pattern from ai-delegate, extended for models section
load_model_registry() {
    # Cache registry in a temp file for session
    local cache="/tmp/.model-registry-$$"
    if [[ -f "$cache" ]]; then
        cat "$cache"
        return
    fi

    python3 -c "
import json
with open('${CONFIG_FILE}') as f:
    cfg = json.load(f)
print(json.dumps(cfg.get('models', {})))
" | tee "$cache"
}

# Get specific model property
get_model_prop() {
    local model="$1" prop="$2"
    python3 -c "
import json
models = json.loads('''$(load_model_registry)''')
m = models.get('$model', {})
v = m.get('$prop')
if v is not None:
    if isinstance(v, (list, dict)):
        print(json.dumps(v))
    else:
        print(v)
"
}
```

### Availability Check Dispatcher
```bash
# Source: New pattern based on config.json check_command field
check_model_available() {
    local model="$1"
    local check_cmd=$(get_model_prop "$model" "check_command")
    local provider=$(get_model_prop "$model" "provider")

    # If explicit check_command, use it
    if [[ -n "$check_cmd" && "$check_cmd" != "null" ]]; then
        eval "$check_cmd" && return 0 || return 1
    fi

    # Otherwise use provider-specific check
    case "$provider" in
        anthropic) return 0 ;;  # Always available (API)
        google) command -v gemini &>/dev/null ;;
        openai) command -v codex &>/dev/null ;;
        ollama) check_ollama_model "$(get_model_prop "$model" "model_id")" ;;
        zhipu) check_zai ;;
        *) return 1 ;;
    esac
}
```

### Ollama Model Availability (API-based)
```bash
# Source: [CITED: https://github.com/ollama/ollama/blob/main/docs/api.md]
check_ollama_model() {
    local model_id="$1"

    # Check daemon running
    curl -sf --connect-timeout 2 http://localhost:11434/api/tags >/dev/null 2>&1 || {
        return 1
    }

    # Check model present (uses /api/tags endpoint)
    curl -sf http://localhost:11434/api/tags | \
        python3 -c "
import json, sys
data = json.load(sys.stdin)
models = [m['name'].split(':')[0] for m in data.get('models', [])]
sys.exit(0 if '$model_id' in models else 1)
"
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Single model routing | Model mesh/multi-model | 2024-2025 | Cost optimization via routing |
| Hardcoded capabilities | Capability metadata | 2025-2026 | Flexible routing without code changes |
| Sync availability checks | Lazy + cached checks | 2025 | Startup performance |

**Deprecated/outdated:**
- Gemini Flash 1.0: Use 2.5 series [VERIFIED: Gemini CLI 0.36.0 supports gemini-2.5-flash]
- OpenAI o3: Codex CLI now defaults to gpt-5.4 [VERIFIED: ~/.codex/config.toml]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | z.ai /models endpoint exists and returns model list | Code Examples | Check would fail silently; fallback to env var check only |
| A2 | Ollama model names match config model_id exactly | Code Examples | Model availability check would return false negatives |
| A3 | Claude/Anthropic always available (no CLI check needed) | Code Examples | Would route to unavailable model |

## Open Questions

1. **z.ai API models endpoint**
   - What we know: Base URL is `https://api.z.ai/api/paas/v4`, auth via Bearer token
   - What's unclear: Does `/models` endpoint exist? Response format?
   - Recommendation: Test with real API key in implementation; fall back to env var check if no endpoint

2. **Schema validation priority**
   - What we know: ajv-cli works, pydantic available
   - What's unclear: Is validation worth the complexity for config.json?
   - Recommendation: Defer to Phase 06 (Phase Conventions) or cleanup phase

3. **Capability taxonomy**
   - What we know: Current capabilities are task-oriented (judgment, bulk-coding, etc.)
   - What's unclear: Should metadata include technical caps (tools, images) separately?
   - Recommendation: Add `metadata` sub-object for technical caps, keep `capabilities` for task routing

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Python 3 | JSON parsing | Yes | 3.x | None needed |
| curl | HTTP probes | Yes | (system) | None needed |
| jq | JSON parsing | No | - | Python fallback |
| ollama | Local inference | Yes (not running) | - | Skip Ollama models |
| gemini CLI | Gemini tasks | Yes | 0.36.0 | - |
| codex CLI | Codex tasks | Yes | 0.114.0 | - |
| z.ai endpoint | GLM-5 tasks | Reachable | - | Requires ZHIPU_API_KEY |

**Missing dependencies with no fallback:**
- None blocking

**Missing dependencies with fallback:**
- jq: Python fallback already implemented in ai-delegate

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | N/A - this phase is local config |
| V3 Session Management | No | N/A |
| V4 Access Control | No | N/A |
| V5 Input Validation | Yes | Config schema validation (optional ajv-cli) |
| V6 Cryptography | No | N/A |

### Known Threat Patterns for Shell/Config

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Config injection | Tampering | Validate JSON before loading |
| Secret exposure | Info Disclosure | Never log API keys from config |
| Command injection | Elevation | Quote all variables, avoid eval |

## Sources

### Primary (HIGH confidence)
- [VERIFIED: npm registry] ajv-cli 5.0.0, ajv 8.18.0 current
- [VERIFIED: local system] Gemini CLI 0.36.0, Codex CLI 0.114.0, Ollama installed (not running)
- [CITED: https://github.com/ollama/ollama/blob/main/docs/api.md] Ollama API endpoints

### Secondary (MEDIUM confidence)
- [CITED: https://aider.chat/docs/config/adv-model-settings.html] Aider model metadata patterns
- [CITED: https://docs.z.ai/guides/overview/quick-start] z.ai API authentication
- [CITED: https://github.com/lm-sys/RouteLLM] RouteLLM routing architecture patterns

### Tertiary (LOW confidence)
- z.ai /models endpoint existence [ASSUMED]

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - verified tool availability locally
- Architecture: HIGH - patterns derived from working ai-delegate code
- Pitfalls: MEDIUM - based on observed issues + industry patterns

**Research date:** 2026-04-18
**Valid until:** 2026-05-18 (30 days - stable domain)

---

## Appendix: Current Config Schema Analysis

### Fields Already Supported in config.json

From current `/home/zzs/dev/zarchon/.planning/config.json`:

```json
{
  "version": "M001",
  "models": {
    "<model-name>": {
      "provider": "string",      // anthropic, google, openai, zhipu, ollama
      "model_id": "string",      // Actual model identifier for API calls
      "capabilities": ["array"], // Task-type capabilities for routing
      "cost_tier": "string",     // high, medium, low, free
      "check_command": "string|null", // Shell command to check availability
      "endpoint": "string",      // Optional: API endpoint override
      "notes": "string"          // Optional: Human-readable notes
    }
  },
  "task_routing": { ... },       // Task type -> model preference lists
  "escalation": { ... },         // Escalation configuration
  "review": { ... },             // Review workflow configuration
  "phase_conventions": { ... },  // Phase numbering conventions
  "learning": { ... }            // Outcome logging configuration
}
```

### Fields Already Implemented in ai-delegate

The current implementation reads from `delegation.*` namespace:
- `delegation.preferred_tool`
- `delegation.gemini_model`
- `delegation.codex_model`
- `delegation.fallback_chain`
- `delegation.task_routing`

**Gap:** ai-delegate reads `delegation.*` but config.json has `models.*`, `task_routing.*` at root level. Phase implementation should align these.

### Recommended Schema Extensions

Add `metadata` sub-object to each model for technical capabilities:

```json
{
  "models": {
    "claude-opus": {
      "provider": "anthropic",
      "model_id": "claude-opus-4-5-20251101",
      "capabilities": ["judgment", "architecture"],
      "cost_tier": "high",
      "check_command": null,
      "metadata": {
        "max_input_tokens": 200000,
        "max_output_tokens": 8192,
        "supports_tools": true,
        "supports_images": true,
        "supports_streaming": true,
        "supports_caching": true
      }
    }
  }
}
```

This separates:
- `capabilities`: Task-type routing (semantic, what it's good at)
- `metadata`: Technical limits (context window, features)
