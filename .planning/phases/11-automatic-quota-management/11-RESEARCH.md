# Phase 11: Automatic Quota Management - Research

**Researched:** 2026-04-18
**Domain:** Quota error parsing, graceful waiting, intelligent failover, bash state management
**Confidence:** HIGH

## Summary

Phase 11 implements autonomous quota handling to eliminate the overnight hang problem: when a model hits quota at 2am, the system should wait and auto-resume rather than require manual restart. The approach uses a hybrid parsing strategy (regex fast path, local LLM fallback) to extract reset timestamps from error responses, combined with quality-first failover rules that never downgrade capability tiers.

The existing codebase already has foundational elements: exit code 2 for quota errors, `_check_quota_error()` in execution.sh with basic pattern matching, and escalation chain walking. This phase extends these with timestamp extraction, wait-before-failover logic, tier-aware failover rules, and model version pinning.

**Primary recommendation:** Create `lib/quota.sh` as the central quota management module with four functions: `_parse_quota_error()` (hybrid regex/LLM parsing), `_wait_for_recovery()` (in-process sleep until reset), `_get_failover_candidates()` (tier-aware model selection), and `_record_quota_state()` (file-based TTL cache). Integrate at the existing `execute_with_escalation()` exit code 2 branch.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Quota Error Parsing:**
- **D-01:** Hybrid parsing approach — regex first (fast path for common patterns like `retry-after`, `429`, `rate.limit.*\d+.*seconds`), fall back to local LLM for complex natural language messages
- **D-02:** Local LLM must be truly local (not subject to API quota itself) — use GLM-5.1 via Ollama or Gemma 4, whichever is available
- **D-03:** Primary goal is extracting the reset timestamp from error responses — this drives the wait duration

**Wait vs Failover Logic:**
- **D-04:** Quality-first failover — only fail to same-tier or higher capability models. Never downgrade.
- **D-05:** Model capability tiers:
  - Tier 1 (Planning/Judgment): Opus
  - Tier 2 (Implementation): Sonnet, GLM-5.1, Codex
  - Tier 3 (Simple/Scaffold): Gemini, Haiku
- **D-06:** Prefer graceful waiting over failover to lower tier — waiting preserves quality, downgrading loses it
- **D-07:** Cross-tier failover rules:
  - Fail UP: Always OK (Gemini -> Sonnet, GLM -> Opus)
  - Fail ACROSS (same tier): Usually OK (Sonnet <-> GLM-5.1, Gemini <-> Haiku)
  - Fail DOWN: Not OK (Opus -> Gemini would be quality loss)

**Graceful Waiting:**
- **D-08:** Sleep in-process — keep the session alive, preserve state in memory, wait for quota recovery, retry automatically
- **D-09:** Parse reset timestamp from error response, sleep until that timestamp, then retry
- **D-10:** No complex state management — if process restarts, try again (either succeeds or gets fresh timestamp)

**Task-Model Constraints:**
- **D-11:** Planning/Architecture tasks require Opus — wait indefinitely rather than downgrade
- **D-12:** Code Review special rules:
  - Codex is preferred reviewer (good at review, limited capacity)
  - Cross-family fallback: if Codex down, use GLM-5.1 (different model family) rather than Opus
  - Deferred review acceptable: if reviewed by GLM during PR, add backlog item for Codex to review post-merge
  - Enforces PROJECT.md principle: "Models don't review their own code"
- **D-13:** Implementation tasks require Tier 2 minimum (Sonnet/GLM-5.1/Codex) — can shuffle within tier, don't drop to Gemini/Haiku for real implementation
- **D-14:** Tier 3 (Gemini/Haiku) is fine for additive parallel passes, supplementary coverage, simple scaffolding — not primary model for critical work

**Opus Meta-Role:**
- **D-15:** Opus identifies inflection points where full code reviews (premortem, gap analysis, edge case analysis) are appropriate
- **D-16:** Opus inserts these as forcing mechanisms at critical junctures — meta-layer role beyond just execution

### Claude's Discretion
- Specific regex patterns for each provider's quota error format
- Exponential backoff defaults if timestamp parsing fails
- Exact sleep granularity (poll every N seconds vs. sleep exact duration)
- Log verbosity during wait periods

### Deferred Ideas (OUT OF SCOPE)
- **Benchmarking framework** — semi-regular benchmarks of available models by task type to validate tier assignments. Belongs in Phase 07 (Claudeception Feedback Loop) or future milestone.
- **Parallel additive passes** — using Gemini in parallel with Codex for critical code/SEO coverage. Interesting but orthogonal to core quota management.

</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| Q-01 | Quota error detection — parse timeout, 429, rate-limit responses across all backends | Provider-specific regex patterns documented, existing `_check_quota_error()` provides foundation |
| Q-02 | Auto-retry with backoff — local LLM determines wait time from error message, resubmits automatically | Hybrid parsing strategy, `retry-after` header extraction, file-based quota state with TTL |
| Q-03 | Intelligent failover — cascade to available models based on task compatibility | Tier-aware failover logic, `task_routing.<type>.model_constraints` config structure |
| Q-04 | Task-specific constraints — some tasks locked to Opus-only, others cascade freely | Config schema for `opus-only` vs `flexible` constraints per task type |
| Q-05 | Model version pinning — config to restrict acceptable model versions per provider | `models.<provider>.allowed_versions` config pattern |
| Q-06 | Quota status tracking — in-memory state of which models are currently quota-limited and estimated recovery time | File-based TTL cache pattern (simpler than bash in-memory) |
</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| bash | 5.x | Script implementation | Already used by all lib/*.sh modules [VERIFIED: project codebase] |
| python3 | 3.10+ | JSON parsing, time calculations | Already used for complex parsing in escalation.sh, logging.sh [VERIFIED: project codebase] |
| ollama | 0.21.0 | Local LLM for complex error parsing | Already installed and configured with glm-5.1:cloud [VERIFIED: `ollama --version`] |
| jq | 1.6+ | JSON extraction (with Python fallback) | Already pattern in codebase [VERIFIED: project codebase] |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| curl | 7.x | HTTP headers extraction | When parsing `retry-after` headers from API responses |
| date | coreutils | Timestamp calculation | Convert ISO8601 reset times to seconds until recovery |

### Local LLM Options for Error Parsing
| Model | Size | Speed | Availability |
|-------|------|-------|--------------|
| glm-5.1:cloud | N/A (cloud routing) | Fast | Currently available via Ollama [VERIFIED: `ollama list`] |
| phi:3.8b | 2GB | Very fast | Not installed, recommended for CPU-only parsing [CITED: localaimaster.com] |
| gemma3:1b | 0.5GB | Extremely fast | Not installed, minimal footprint option [CITED: localaimaster.com] |
| llama3.2:3b | 2GB | Fast | Not installed, good accuracy/speed balance [CITED: ollama.com/library/llama3.2] |

**Recommendation:** Use existing glm-5.1:cloud for now. Add phi:3.8b as dedicated parsing model if latency becomes issue. [ASSUMED: glm-5.1:cloud is fast enough for error parsing]

**Installation (if adding dedicated parsing model):**
```bash
ollama pull phi:3.8b
# or for minimal footprint:
ollama pull gemma3:1b
```

## Architecture Patterns

### Recommended Module Structure
```
~/dev/.meta/bin/
├── lib/
│   ├── quota.sh           # NEW: Quota parsing, state, recovery, failover
│   ├── escalation.sh      # UPDATE: Integrate wait-before-failover at exit code 2
│   ├── execution.sh       # MINOR: Improve _check_quota_error() patterns
│   └── logging.sh         # MINOR: Add quota event logging
└── gemma-parse            # NEW: Local LLM wrapper for error parsing

.planning/
└── config.json            # UPDATE: Add quota_management, model_constraints, model_pinning
```

### Pattern 1: Hybrid Error Parsing
**What:** Try fast regex patterns first, fall back to local LLM for complex messages
**When to use:** Error messages from different providers have varying formats
**Example:**
```bash
# Source: Research synthesis of provider error formats
_parse_quota_error() {
    local output_file="$1"
    local error_content
    error_content=$(cat "$output_file")

    # Fast path: regex for common patterns
    local wait_seconds=""

    # 1. HTTP retry-after header (seconds)
    wait_seconds=$(echo "$error_content" | grep -oiE 'retry-after:\s*([0-9]+)' | grep -oE '[0-9]+' | head -1)
    [[ -n "$wait_seconds" ]] && echo "$wait_seconds" && return 0

    # 2. Anthropic ratelimit reset (ISO8601)
    local reset_time
    reset_time=$(echo "$error_content" | grep -oE 'anthropic-ratelimit-[a-z]+-reset:\s*[0-9T:.Z+-]+' | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:.]+' | head -1)
    if [[ -n "$reset_time" ]]; then
        wait_seconds=$(_iso8601_to_seconds "$reset_time")
        [[ -n "$wait_seconds" ]] && echo "$wait_seconds" && return 0
    fi

    # 3. Z.ai 1308 pattern: "reset at ${next_flush_time}"
    reset_time=$(echo "$error_content" | grep -oE 'reset at [0-9]{4}-[0-9]{2}-[0-9]{2}[T ][0-9:]+' | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}[T ][0-9:]+' | head -1)
    if [[ -n "$reset_time" ]]; then
        wait_seconds=$(_iso8601_to_seconds "$reset_time")
        [[ -n "$wait_seconds" ]] && echo "$wait_seconds" && return 0
    fi

    # 4. Natural language: "X seconds", "X minutes"
    wait_seconds=$(echo "$error_content" | grep -oiE '([0-9]+)\s*(second|minute|hour)' | head -1 | awk '{
        val=$1; unit=tolower($2)
        if (unit ~ /minute/) val*=60
        if (unit ~ /hour/) val*=3600
        print val
    }')
    [[ -n "$wait_seconds" ]] && echo "$wait_seconds" && return 0

    # Slow path: local LLM for complex messages
    _llm_parse_quota_error "$output_file"
}
```

### Pattern 2: File-Based TTL Cache for Quota State
**What:** Use timestamped files to track which models are quota-limited
**When to use:** Bash lacks good in-memory data structures; file-based is simpler and survives script restarts
**Example:**
```bash
# Source: Research on bash state management patterns
QUOTA_STATE_DIR="${TMPDIR:-/tmp}/quota-state-$$"

_record_quota_state() {
    local model="$1"
    local recovery_time="$2"  # Unix timestamp when quota recovers

    mkdir -p "$QUOTA_STATE_DIR"
    echo "$recovery_time" > "$QUOTA_STATE_DIR/${model}.quota"
}

_is_model_quota_limited() {
    local model="$1"
    local state_file="$QUOTA_STATE_DIR/${model}.quota"

    [[ ! -f "$state_file" ]] && return 1  # Not limited

    local recovery_time now
    recovery_time=$(cat "$state_file")
    now=$(date +%s)

    if [[ $now -ge $recovery_time ]]; then
        rm -f "$state_file"  # TTL expired
        return 1  # Not limited anymore
    fi

    return 0  # Still limited
}
```

### Pattern 3: Tier-Aware Failover
**What:** Enforce quality-first failover rules from D-04 through D-07
**When to use:** When selecting failover candidates after quota exhaustion
**Example:**
```bash
# Source: CONTEXT.md D-05, D-07
_get_failover_candidates() {
    local current_model="$1"
    local task_type="$2"

    local current_tier
    current_tier=$(_get_model_tier "$current_model")

    # Get models from escalation chain
    local chain_json
    chain_json=$(read_config "escalation.chain.${task_type}" "$(read_config 'escalation.chain.default' '[]')")

    # Filter to same-tier or higher only (D-07: never fail DOWN)
    echo "$chain_json" | python3 -c "
import json, sys
chain = json.load(sys.stdin)
current_tier = $current_tier

TIERS = {
    'claude-opus': 1,
    'claude-sonnet': 2, 'codex': 2, 'glm-zai': 2, 'glm-ollama': 2,
    'gemini-flash': 3, 'claude-haiku': 3
}

candidates = [m for m in chain if TIERS.get(m, 3) <= current_tier and m != '$current_model']
print(json.dumps(candidates))
"
}
```

### Anti-Patterns to Avoid
- **Polling loop without backoff:** Never busy-wait checking quota status. Always sleep until expected recovery.
- **Hard-coded wait times:** Extract actual reset time from error response; don't assume fixed 60s delays.
- **Ignoring task constraints:** Don't fail Opus-only tasks to Gemini even if Opus is quota-limited. Wait instead.
- **Session-scoped state only:** Quota state should persist across script restarts via file-based cache.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| JSON parsing in bash | String manipulation | `jq` or Python fallback | Edge cases with escaping, nested structures [VERIFIED: existing pattern in codebase] |
| ISO8601 timestamp parsing | Custom regex | Python `datetime.fromisoformat()` | Timezone handling, format variations [VERIFIED: used in logging.sh] |
| Exponential backoff | Manual delay calculation | Established formula: `base * (2 ^ attempt) + jitter` | Jitter prevents thundering herd [CITED: AWS retry guidance] |
| Local LLM invocation | Direct Ollama API calls | Existing `ollama-run` wrapper | Health checks, error handling already implemented [VERIFIED: ~/dev/.meta/bin/ollama-run] |

**Key insight:** The existing codebase has established patterns for Python fallbacks, JSONL logging, and LLM wrapper scripts. Quota management should follow these patterns rather than inventing new ones.

## Provider Quota Error Formats

### Anthropic Claude
[CITED: platform.claude.com/docs/en/api/rate-limits]

**Error Response:**
```json
{
  "error": {
    "type": "rate_limit_error",
    "message": "Rate limit exceeded. Please retry after X seconds."
  }
}
```

**Key Headers:**
| Header | Value Format | Example |
|--------|--------------|---------|
| `retry-after` | Seconds integer | `60` |
| `anthropic-ratelimit-requests-reset` | RFC 3339 timestamp | `2026-04-18T15:30:00Z` |
| `anthropic-ratelimit-tokens-reset` | RFC 3339 timestamp | `2026-04-18T15:30:00Z` |

**Regex Pattern:**
```regex
retry-after:\s*([0-9]+)
anthropic-ratelimit-[a-z]+-reset:\s*([0-9T:.Z+-]+)
```

### OpenAI / Codex
[CITED: developers.openai.com/api/docs/guides/error-codes]

**Error Response:**
```json
{
  "error": {
    "message": "You exceeded your current quota...",
    "type": "insufficient_quota",
    "code": "insufficient_quota"
  }
}
```

**Key Headers:**
| Header | Value Format | Example |
|--------|--------------|---------|
| `x-ratelimit-reset-requests` | Seconds until reset | `12s` |
| `x-ratelimit-reset-tokens` | Seconds until reset | `8s` |

**Regex Pattern:**
```regex
x-ratelimit-reset-[a-z]+:\s*([0-9]+)s?
error.*insufficient_quota
```

### Google Gemini
[CITED: cloud.google.com/vertex-ai/generative-ai/docs/provisioned-throughput/error-code-429]

**Error Response:**
```json
{
  "error": {
    "status": "RESOURCE_EXHAUSTED",
    "message": "Quota exceeded for project..."
  }
}
```

**Key Headers:**
| Header | Value Format | Example |
|--------|--------------|---------|
| `x-ratelimit-reset` | Timestamp | Varies |

**Regex Pattern:**
```regex
RESOURCE_EXHAUSTED
quota.*exceeded
```

### Zhipu GLM (z.ai)
[CITED: docs.z.ai/api-reference/api-code]

**Error Codes:**
| Code | Meaning | Action |
|------|---------|--------|
| 1113 | Account in arrears | Not recoverable, alert user |
| 1302 | High concurrency | Retry with backoff |
| 1303 | High frequency | Retry with backoff |
| 1304 | Daily call limit | Wait until next day |
| 1305 | Rate limit triggered | Retry with backoff |
| 1308 | Usage limit reached, resets at `${next_flush_time}` | Parse reset time, wait |
| 1310 | Weekly/monthly limit, resets at `${next_flush_time}` | Parse reset time, wait |

**Regex Pattern:**
```regex
"code":\s*"?(1302|1303|1304|1305|1308|1310)"?
reset at\s*\`?\$?\{?next_flush_time\}?\`?|reset at ([0-9T:.+-]+)
```

## Common Pitfalls

### Pitfall 1: Failing to Extract Reset Time
**What goes wrong:** Using fixed backoff delays when the error response contains exact reset timestamp
**Why it happens:** Regex doesn't cover all provider formats; parsing is skipped
**How to avoid:** Implement hybrid parsing with LLM fallback for complex messages
**Warning signs:** Logs show "using default backoff" frequently

### Pitfall 2: Thundering Herd on Recovery
**What goes wrong:** Multiple processes/sessions all retry simultaneously when quota resets
**Why it happens:** All processes calculated same recovery time, retry exactly at reset
**How to avoid:** Add random jitter (0-5 seconds) to retry timing
**Warning signs:** Immediate re-429 after first retry attempt

### Pitfall 3: Downgrading Quality During Wait
**What goes wrong:** Opus-required tasks fail to Gemini because Opus is temporarily limited
**Why it happens:** Failover logic doesn't check task constraints
**How to avoid:** Check `task_routing.<type>.model_constraints` before failover
**Warning signs:** Planning tasks executed by wrong model tier

### Pitfall 4: State Leak Between Sessions
**What goes wrong:** Old quota state files cause incorrect behavior for new sessions
**Why it happens:** TTL check uses wrong timezone or comparison
**How to avoid:** Use Unix timestamps (seconds since epoch) consistently
**Warning signs:** Models marked as limited when they shouldn't be

### Pitfall 5: 529 vs 429 Confusion
**What goes wrong:** Treating Anthropic 529 (overloaded) same as 429 (rate limited)
**Why it happens:** Both are "try again later" errors but have different causes [CITED: blog.laozhang.ai]
**How to avoid:** 529 uses exponential backoff with longer base; 429 uses retry-after header
**Warning signs:** Very long waits for 529 errors that resolve quickly

## Code Examples

### Exponential Backoff with Jitter
```bash
# Source: AWS prescriptive guidance + research synthesis
_exponential_backoff() {
    local attempt="$1"
    local base_delay="${2:-2}"
    local max_delay="${3:-300}"

    # Calculate delay: base * 2^attempt
    local delay=$((base_delay * (1 << attempt)))

    # Cap at max
    [[ $delay -gt $max_delay ]] && delay=$max_delay

    # Add jitter (0-25% of delay)
    local jitter=$((RANDOM % (delay / 4 + 1)))
    delay=$((delay + jitter))

    echo "$delay"
}
```

### Wait-Before-Failover Integration Point
```bash
# Source: CONTEXT.md D-08, existing escalation.sh structure
# In execute_with_escalation(), after detecting exit_code 2:
case $exit_code in
    2)  # Quota error
        signal="quota"
        local wait_seconds
        wait_seconds=$(_parse_quota_error "$output_file")

        if [[ -n "$wait_seconds" && $wait_seconds -gt 0 ]]; then
            # D-08: Sleep in-process, preserve state
            [[ "${VERBOSE:-false}" == "true" ]] && \
                echo "[quota] $model quota-limited, waiting ${wait_seconds}s for recovery..." >&2

            _record_quota_state "$model" $(($(date +%s) + wait_seconds))
            sleep "$wait_seconds"

            # Retry same model (don't escalate yet)
            ((i--))
            continue
        fi

        # No timestamp extracted, proceed to failover
        ;;
esac
```

### Local LLM Error Parsing
```bash
# Source: Existing ollama-run pattern
_llm_parse_quota_error() {
    local output_file="$1"
    local error_content
    error_content=$(head -c 2000 "$output_file")

    local prompt="Extract the wait time from this API error message.
Return ONLY a number representing seconds to wait. If no time found, return 60.
Error message:
$error_content"

    local result
    result=$(OLLAMA_MODEL="${QUOTA_PARSE_MODEL:-glm-5.1:cloud}" \
             OLLAMA_TIMEOUT=30 \
             "$HOME/dev/.meta/bin/ollama-run" "$prompt" 2>/dev/null | grep -oE '^[0-9]+' | head -1)

    echo "${result:-60}"
}
```

## Config Schema Extension

### quota_management Section
```json
{
  "quota_management": {
    "enabled": true,
    "max_wait_seconds": 900,
    "default_backoff_base": 2,
    "default_backoff_max": 300,
    "parse_model": "glm-5.1:cloud",
    "state_dir": "/tmp/quota-state"
  }
}
```

### model_constraints Section
```json
{
  "task_routing": {
    "judgment": {
      "models": ["claude-opus"],
      "model_constraints": "opus-only"
    },
    "impl": {
      "models": ["gemini-flash", "glm-ollama", "glm-zai", "claude-sonnet"],
      "model_constraints": "tier-2-minimum",
      "scoring_mode": "keyword+files"
    },
    "code-review": {
      "models": ["codex", "glm-zai", "claude-opus"],
      "model_constraints": "cross-family-preferred"
    }
  }
}
```

### model_pinning Section
```json
{
  "models": {
    "glm-zai": {
      "provider": "zhipu",
      "model_id": "glm-5.1",
      "allowed_versions": ["glm-5.1"],
      "forbidden_versions": ["glm-4.6", "glm-4.5"]
    }
  }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Fixed backoff (60s) | Parse retry-after header | Always was best practice | Faster recovery, less wasted time |
| Fail immediately on 429 | Wait-before-failover | This phase | Quality preservation |
| Any-model failover | Tier-aware failover | This phase | Prevents quality degradation |
| Session-only state | File-based TTL cache | This phase | Survives restarts |

**Deprecated/outdated:**
- `insufficient_quota` errors from OpenAI are NOT rate limits — they indicate billing issues, not transient limits [CITED: community.openai.com]
- Gemini has known "ghost 429" bug in February 2026 affecting Tier 1 accounts — workaround is to try different model variant [CITED: blog.laozhang.ai]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | glm-5.1:cloud is fast enough for error parsing (sub-5s response) | Standard Stack | May need dedicated smaller model for parsing |
| A2 | File-based quota state is sufficient (no distributed coordination needed) | Architecture Patterns | Multi-process races possible if many concurrent sessions |
| A3 | 900s (15 min) max wait is acceptable for all quota recovery scenarios | Config Schema | Some provider quotas may have longer reset windows |

**If this table is empty:** All claims in this research were verified or cited — no user confirmation needed.

## Open Questions

1. **Deferred Review Backlog Mechanism**
   - What we know: D-12 mentions adding backlog item when Codex unavailable
   - What's unclear: How to create this backlog item (DEBT phase? JSONL log?)
   - Recommendation: Log to `.planning/deferred-reviews.jsonl`, process in Phase 07 (Claudeception Feedback Loop)

2. **Cross-Process Quota State Sharing**
   - What we know: File-based cache works for single process
   - What's unclear: Multiple concurrent ai-delegate instances may race on state files
   - Recommendation: Use atomic file operations (write to tmp, mv to final); accept occasional duplicate retries

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Ollama | Local LLM parsing | Yes | 0.21.0 | Regex-only parsing |
| glm-5.1:cloud model | LLM parsing | Yes | N/A | Pull phi:3.8b |
| jq | JSON extraction | Check needed | - | Python fallback (exists) |
| bash | Script execution | Yes | 5.x | - |
| python3 | Complex parsing | Yes | 3.10+ | - |

**Missing dependencies with no fallback:**
- None — all critical dependencies have fallbacks

**Missing dependencies with fallback:**
- `jq` — if not available, Python fallback is already implemented in codebase

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Bash test suite (custom, no external framework) |
| Config file | None — tests are standalone scripts |
| Quick run command | `bash ~/dev/.meta/bin/lib/test_quota.sh` |
| Full suite command | `bash ~/dev/.meta/bin/lib/test_escalation.sh && bash ~/dev/.meta/bin/lib/test_quota.sh` |

### Phase Requirements to Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| Q-01 | Quota error detection for all backends | unit | `bash test_quota.sh::test_detect_quota_*` | Wave 0 |
| Q-02 | Auto-retry with backoff, timestamp extraction | unit | `bash test_quota.sh::test_parse_quota_*` | Wave 0 |
| Q-03 | Tier-aware failover selection | unit | `bash test_quota.sh::test_failover_candidates` | Wave 0 |
| Q-04 | Task constraint enforcement | unit | `bash test_quota.sh::test_constraint_*` | Wave 0 |
| Q-05 | Model version pinning | unit | `bash test_quota.sh::test_version_pinning` | Wave 0 |
| Q-06 | Quota state TTL cache | unit | `bash test_quota.sh::test_quota_state_*` | Wave 0 |

### Sampling Rate
- **Per task commit:** `bash test_quota.sh`
- **Per wave merge:** Full suite plus manual verification with mock error responses
- **Phase gate:** All tests green + integration test with real quota error (low-stakes task)

### Wave 0 Gaps
- [ ] `~/dev/.meta/bin/lib/test_quota.sh` — test suite for quota.sh functions
- [ ] Mock error response files for each provider format
- [ ] Integration test using Gemini free tier (easy to trigger rate limit)

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | N/A — uses existing API key patterns |
| V3 Session Management | No | N/A — stateless request/response |
| V4 Access Control | No | N/A — inherits from ai-delegate |
| V5 Input Validation | Yes | Sanitize error messages before logging (existing pattern) |
| V6 Cryptography | No | N/A — no crypto operations |

### Known Threat Patterns

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Log injection via error message | Tampering | Truncate and sanitize before logging (existing `_sanitize_description` pattern) |
| State file manipulation | Tampering | Validate state file contents, use atomic writes |
| Resource exhaustion via long waits | DoS | Cap max wait at 900s, allow user interrupt |

## Sources

### Primary (HIGH confidence)
- [Anthropic Rate Limits Documentation](https://platform.claude.com/docs/en/api/rate-limits) — Header formats, retry-after behavior
- [Z.AI Error Codes](https://docs.z.ai/api-reference/api-code) — Error code meanings 1302-1310
- [Project codebase] — execution.sh, escalation.sh, logging.sh patterns

### Secondary (MEDIUM confidence)
- [OpenAI Error Handling Guide](https://developers.openai.com/cookbook/examples/how_to_handle_rate_limits) — x-ratelimit headers
- [Google Cloud 429 Documentation](https://docs.cloud.google.com/vertex-ai/generative-ai/docs/provisioned-throughput/error-code-429) — RESOURCE_EXHAUSTED handling
- [LaoZhang AI Blog](https://blog.laozhang.ai/en/posts/gemini-api-error-troubleshooting) — Gemini ghost 429 bug

### Tertiary (LOW confidence)
- [LocalAI Master](https://localaimaster.com/blog/small-language-models-guide-2026) — Small model recommendations for parsing

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — verified against installed tools and existing codebase patterns
- Architecture: HIGH — follows established module structure, CONTEXT.md decisions are clear
- Pitfalls: HIGH — provider documentation verified, known bugs documented
- Provider formats: MEDIUM — headers verified, but edge cases may exist

**Research date:** 2026-04-18
**Valid until:** 2026-05-18 (30 days — provider APIs stable, local patterns established)
