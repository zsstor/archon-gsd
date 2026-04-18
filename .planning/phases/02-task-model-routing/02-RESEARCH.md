# Phase 02: Task→Model Routing - Research

**Researched:** 2026-04-18
**Domain:** Multi-model task routing with complexity scoring, history-based learning, and adaptive escalation
**Confidence:** HIGH

## Summary

Phase 02 implements an intelligent routing system that directs tasks to optimal models based on complexity scoring, historical outcomes, and adaptive learning. The existing `ai-delegate` (856 lines) provides a solid MVP foundation with task commands, fallback chains, and basic logging. This research focuses on intentional redesign with three distinct internal modules: routing (complexity + history), execution (backend dispatch), and logging (structured outcomes).

The core technical challenge is balancing accuracy (complex scoring modes) with speed (keyword-only scoring), using time-decayed history to auto-upgrade scoring modes per task type when failure patterns emerge. JSONL structured logging with consistent schema enables downstream analysis and learning feedback loops.

**Primary recommendation:** Rewrite ai-delegate with clean module separation, implement three-mode complexity scoring (keyword → keyword+files → full) with exponential time decay for history weighting, and structured JSONL logging for Claudeception feedback.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Complexity Scoring:**
- **D-01:** Implement three scoring modes: `keyword`, `keyword+files`, `full` — all available, configurable per task type
- **D-02:** Each task type starts on `keyword` mode and auto-upgrades independently based on observed outcomes
- **D-03:** Dual-signal auto-upgrade trigger: failure rate threshold OR escalation count threshold (either can trigger upgrade)
- **D-04:** Score format is numeric 0-100 internally (thresholds configurable, easy to log and analyze)

**History Lookup:**
- **D-05:** Time-decayed weights per task type — recent failures weigh more than old ones
- **D-06:** All outcome fields feed into routing: success, escalation_count, tokens_used, duration_ms
- **D-07:** Each task type maintains its own history/decay curve independently

**Routing Architecture:**
- **D-08:** Single smart CLI — rewrite `ai-delegate` with intentional design (current version is organic MVP)
- **D-09:** Clean internal module separation: routing module, execution module, logging module
- **D-10:** Routing module owns: scoring, history lookup, model selection
- **D-11:** Execution module owns: backend dispatch, timeout handling, output capture
- **D-12:** Logging module owns: outcome recording, introspection queries

**Log Format & Introspection:**
- **D-13:** `-v` flag for inline routing rationale during execution
- **D-14:** Structured JSONL log with full context: complexity score, scoring mode used, history lookup results, model chain, final selection rationale
- **D-15:** All routing decisions logged regardless of `-v` flag (verbose just controls stdout)

### Claude's Discretion

- Specific decay function (exponential, linear, etc.) — pick what works well for the data patterns
- Threshold values for auto-upgrade triggers — start with sensible defaults, tune based on observed data
- Internal data structures for history caching — optimize for lookup speed

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope

</user_constraints>

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Bash 5.x | 5.x+ | Script runtime | Native to Linux/macOS, no external dependencies |
| Python 3.10+ | 3.10+ | JSON parsing fallback | Universal availability, jq-free config parsing |
| model-registry | Phase 01 | Model metadata queries | Existing helper from Phase 01 — reuse for availability checks |

**Installation:**
```bash
# Core dependencies already present
which bash python3

# Verify Phase 01 artifacts
ls ~/dev/.meta/bin/model-registry
cat .planning/config.json | python3 -m json.tool
```

**Version verification:** All core tools are system-provided, no package installation needed.

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| ShellCheck | 0.10+ | Static analysis | Optional — lint Bash scripts for common pitfalls |
| Bats | 1.11+ | Testing framework | Optional — if adding unit tests for routing logic |
| jq | 1.7+ | JSON parsing | Optional — if present, use instead of Python fallback |

**Installation (optional tools):**
```bash
# ShellCheck (recommended but not required)
sudo apt install shellcheck  # Debian/Ubuntu
brew install shellcheck      # macOS

# Bats (for testing)
npm install -g bats

# jq (faster than Python, but not required)
sudo apt install jq
```

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Bash | Python script | More structured, but adds Python dependency and loses existing Bash ecosystem integration |
| JSONL logging | SQLite database | Queryable storage, but adds dependency and complexity for simple append-only logs |
| Exponential decay | Linear decay | Simpler math, but less effective at emphasizing recent failures [VERIFIED: time decay research] |

## Architecture Patterns

### Recommended Project Structure

```
~/dev/.meta/bin/
├── ai-delegate              # Main CLI (rewrites existing)
├── model-registry           # Phase 01 helper (reuse as-is)
├── ollama-run              # Phase 04 wrapper (reuse)
├── zai-run                 # Phase 04 wrapper (reuse)
└── lib/
    ├── routing.sh          # NEW: Complexity scoring + history + model selection
    ├── execution.sh        # NEW: Backend dispatch + timeout + output capture
    └── logging.sh          # NEW: JSONL append + introspection queries

.planning/
├── config.json             # Extended with scoring thresholds, decay params
└── delegation-log.jsonl    # Structured outcome log (one JSON object per line)
```

### Pattern 1: Module Separation via Sourcing

**What:** Bash scripts use `source` to load internal function libraries, keeping main CLI thin and focused.

**When to use:** When a single script exceeds ~300 lines or has distinct responsibilities (routing vs execution vs logging).

**Example:**
```bash
# ai-delegate main script
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/routing.sh"
source "${SCRIPT_DIR}/lib/execution.sh"
source "${SCRIPT_DIR}/lib/logging.sh"

# Main CLI dispatch
cmd_impl() {
    local description="$1"
    local context_file="${2:-}"

    # Routing module determines best model
    local model
    model=$(route_task "impl" "$description" "$context_file")

    # Execution module runs the task
    local output
    output=$(execute_model "$model" "$description" "$context_file")

    # Logging module records outcome
    log_outcome "impl" "$model" "$output"
}
```

**Source:** [CITED: Designing Modular Bash: Functions, Namespaces, and Library Patterns](https://www.lost-in-it.com/posts/designing-modular-bash-functions-namespaces-library-patterns/)

### Pattern 2: Three-Mode Complexity Scoring with Auto-Upgrade

**What:** Start with fast keyword-only scoring, auto-upgrade to keyword+files or full analysis when failure patterns emerge.

**When to use:** When balancing speed (cheap scoring) with accuracy (expensive scoring).

**Example:**
```bash
# routing.sh internal function
_score_complexity() {
    local task_type="$1"
    local description="$2"
    local mode
    mode=$(_get_scoring_mode "$task_type")  # keyword | keyword+files | full

    case "$mode" in
        keyword)
            # Fast: scan description only (0-100 scale)
            _score_keywords "$description"
            ;;
        keyword+files)
            # Medium: keywords + file count heuristic
            local base_score
            base_score=$(_score_keywords "$description")
            local file_bonus
            file_bonus=$(_count_affected_files "$description")
            echo $((base_score + file_bonus))
            ;;
        full)
            # Slow: deep analysis (AST parsing, test coverage check, etc.)
            _score_full "$description"
            ;;
    esac
}

_score_keywords() {
    local description="$1"
    local score=50  # baseline

    # High complexity indicators (+30-40 each)
    echo "$description" | grep -qiE "refactor|migrate|architect|multi.?file" && score=$((score + 35))

    # Medium complexity indicators (+15-20 each)
    echo "$description" | grep -qiE "test|integrate|api|database" && score=$((score + 15))

    # Cap at 100
    [[ $score -gt 100 ]] && score=100
    echo "$score"
}
```

**Source:** [CITED: Best AI Model for Coding Agents in 2026: A Routing Guide](https://www.augmentcode.com/guides/ai-model-routing-guide) — discusses complexity-based routing

### Pattern 3: Exponential Time Decay for History Weighting

**What:** Recent outcomes carry more weight than old outcomes using exponential decay function.

**When to use:** When learning from historical task outcomes where recency matters more than distant history.

**Example:**
```bash
# routing.sh internal function
_apply_time_decay() {
    local timestamp="$1"      # ISO 8601 timestamp
    local weight="${2:-1.0}"  # Base weight
    local half_life="${3:-7}" # Days until weight halves

    local now
    now=$(date +%s)
    local then
    then=$(date -d "$timestamp" +%s 2>/dev/null || echo "$now")
    local age_days=$(( (now - then) / 86400 ))

    # Exponential decay: weight * (0.5 ^ (age_days / half_life))
    python3 -c "print($weight * (0.5 ** ($age_days / $half_life)))"
}

_compute_weighted_failure_rate() {
    local task_type="$1"

    # Read delegation-log.jsonl, filter by task_type, apply decay
    local total_weight=0
    local failure_weight=0

    while IFS= read -r line; do
        local ts success
        ts=$(echo "$line" | python3 -c "import json,sys; print(json.load(sys.stdin).get('timestamp',''))")
        success=$(echo "$line" | python3 -c "import json,sys; print(json.load(sys.stdin).get('success',True))")

        local decay_weight
        decay_weight=$(_apply_time_decay "$ts")

        total_weight=$(python3 -c "print($total_weight + $decay_weight)")
        [[ "$success" == "False" || "$success" == "false" ]] && \
            failure_weight=$(python3 -c "print($failure_weight + $decay_weight)")
    done < <(grep "\"task_type\":\"$task_type\"" "$DELEGATION_LOG")

    # Return weighted failure rate (0.0 - 1.0)
    python3 -c "print($failure_weight / max($total_weight, 1.0))"
}
```

**Source:** [CITED: Exponential decay - Wikipedia](https://en.wikipedia.org/wiki/Exponential_decay) and [CITED: Recency-Weighted Scoring Explained](https://customers.ai/recency-weighted-scoring)

### Pattern 4: JSONL Structured Logging with Consistent Schema

**What:** Append-only log file with one JSON object per line, consistent field names across all entries.

**When to use:** For event logging that needs to be streamable, parseable, and analyzable without loading entire file.

**Example:**
```bash
# logging.sh internal function
log_routing_decision() {
    local task_type="$1"
    local description="$2"
    local complexity_score="$3"
    local scoring_mode="$4"
    local history_failure_rate="$5"
    local selected_model="$6"
    local model_chain="$7"  # JSON array as string
    local rationale="$8"

    # Build JSON entry (Python for reliable JSON serialization)
    python3 <<EOF >> "$DELEGATION_LOG"
import json
from datetime import datetime

entry = {
    "timestamp": datetime.now().isoformat(),
    "event_type": "routing_decision",
    "task_type": "$task_type",
    "description": """$description""",
    "complexity_score": $complexity_score,
    "scoring_mode": "$scoring_mode",
    "history_failure_rate": $history_failure_rate,
    "selected_model": "$selected_model",
    "model_chain": $model_chain,
    "rationale": "$rationale"
}
print(json.dumps(entry))
EOF
}

log_task_outcome() {
    local task_type="$1"
    local model="$2"
    local success="$3"
    local duration_ms="$4"
    local escalation_count="${5:-0}"
    local tokens_used="${6:-0}"

    python3 <<EOF >> "$DELEGATION_LOG"
import json
from datetime import datetime

entry = {
    "timestamp": datetime.now().isoformat(),
    "event_type": "task_outcome",
    "task_type": "$task_type",
    "model": "$model",
    "success": $success,
    "duration_ms": $duration_ms,
    "escalation_count": $escalation_count,
    "tokens_used": $tokens_used
}
print(json.dumps(entry))
EOF
}
```

**Source:** [CITED: JSONL for Log Processing - Structured Logging & Analysis](https://ndjson.com/use-cases/log-processing/) and [CITED: How to Implement Structured Logging Best Practices](https://oneuptime.com/blog/post/2026-01-25-structured-logging-best-practices/view)

### Anti-Patterns to Avoid

- **Global state in Bash modules:** Use explicit parameter passing instead of relying on global variables between modules [CITED: Bash Functions: A Comprehensive Guide to Modular Scripting](https://linuxvox.com/blog/bash-functions/)
- **Parsing JSON with regex/sed:** Always use Python or jq for JSON manipulation to avoid escaping nightmares
- **Blocking history lookups:** Cache recent history in memory per session to avoid re-reading log file on every routing decision
- **Hardcoded model names:** Always read from config.json registry, never hardcode "gemini" or "codex" in routing logic

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| JSON parsing in Bash | Custom sed/awk/regex parser | Python 3 json module or jq | JSON escaping, nested objects, Unicode — Python handles all edge cases [VERIFIED: existing ai-delegate pattern] |
| Time arithmetic | Bash date string parsing | Python datetime or date +%s | Bash date parsing fragile across platforms, Python reliable |
| Statistical functions | Custom weighted averages in Bash | Python one-liners | Floating-point math in Bash requires bc/awk, Python built-in |
| Model availability checks | Custom ping/curl per model | model-registry helper | Phase 01 already solved this with timeout handling and caching [VERIFIED: model-registry source] |

**Key insight:** Bash excels at orchestration (calling tools, chaining commands, file I/O), but delegating math and structured data to Python keeps scripts maintainable. The existing ai-delegate already follows this pattern successfully.

## Runtime State Inventory

> Omitted — this is a greenfield implementation phase, not a refactor/migration.

## Common Pitfalls

### Pitfall 1: Scoring Mode Gets Stuck

**What goes wrong:** Task type auto-upgrades from keyword to keyword+files mode, but never downgrades even after long success streak.

**Why it happens:** Auto-upgrade logic only triggers on failure, no downgrade logic exists.

**How to avoid:** Implement hysteresis — after N consecutive successes in upgraded mode, consider downgrading. Or set expiration TTL (e.g., downgrade after 30 days if no recent failures).

**Warning signs:** All task types drift toward `full` mode over time, slowing down all routing decisions.

### Pitfall 2: Cold Start Problem

**What goes wrong:** First few tasks for a new task type have no history, so time-decay weighting divides by zero or returns NaN.

**Why it happens:** Weighted failure rate calculation assumes at least one log entry exists.

**How to avoid:** Use Bayesian prior — assume 50% failure rate with low weight for task types with <5 historical entries. Or fall back to static routing from config when history insufficient.

**Warning signs:** Python errors like `ZeroDivisionError` or routing selects wrong model for first task of each type.

### Pitfall 3: JSONL Log File Grows Unbounded

**What goes wrong:** delegation-log.jsonl grows to hundreds of MB, slowing down history lookups.

**Why it happens:** No log rotation or archival strategy.

**How to avoid:** Implement log rotation — after 10,000 entries or 30 days, move old entries to delegation-log-YYYYMM.jsonl.gz archive. Keep only recent N days in hot log for routing queries.

**Warning signs:** Routing decisions take >1s, grep commands timeout, disk space warnings.

### Pitfall 4: Race Conditions with Parallel Tasks

**What goes wrong:** Two ai-delegate processes run in parallel, both appending to delegation-log.jsonl, log entries interleave or corrupt.

**Why it happens:** JSONL append is not atomic without file locking.

**How to avoid:** Use flock for exclusive write access during log append, or accept risk (JSONL format recovers gracefully from interleaved lines). For high concurrency, switch to SQLite with proper locking.

**Warning signs:** Malformed JSON lines in log file, Python json parsing errors during history lookup.

### Pitfall 5: Verbose Mode Leaks Sensitive Data

**What goes wrong:** `-v` flag logs full task description to stdout, description contains API keys or credentials.

**Why it happens:** No sanitization of logged data.

**How to avoid:** Redact patterns like `(password|key|token|secret)=\S+` before logging. Or document that `-v` is unsafe for sensitive tasks.

**Warning signs:** Security audit finds credentials in terminal history or CI/CD logs.

## Code Examples

Verified patterns from existing codebase and official sources:

### Reading Config with Python Fallback

```bash
# Source: existing ai-delegate lines 81-112
read_config() {
    local key="$1"
    local default="$2"

    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "$default"
        return
    fi

    local value
    if command -v jq &>/dev/null; then
        value=$(jq -r ".task_routing.${key} // empty" "$CONFIG_FILE" 2>/dev/null)
    else
        value=$(python3 -c "
import json
try:
    with open('$CONFIG_FILE') as f:
        cfg = json.load(f)
    v = cfg.get('task_routing', {}).get('$key')
    if v is not None:
        if isinstance(v, bool):
            print('true' if v else 'false')
        elif isinstance(v, (list, dict)):
            print(json.dumps(v))
        else:
            print(v)
except: pass
" 2>/dev/null)
    fi

    echo "${value:-$default}"
}
```

### Model Availability Check via Registry

```bash
# Source: existing ai-delegate lines 162-165
check_model_available() {
    local model="$1"
    "${SCRIPT_DIR}/model-registry" check "$model" 2>/dev/null
}
```

### Session ID Generation

```bash
# Source: existing ai-delegate lines 76-78
session_id() {
    echo "$(date +%Y%m%d-%H%M%S)-$$"
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Single LLM per project | Multi-model routing | 2025-2026 | Cost optimization: route simple tasks to cheap models, complex to capable ones [CITED: AI model routing guide] |
| Static failure thresholds | Adaptive time-decayed learning | 2026 research | Systems learn per-task-type patterns, auto-adjust to avoid manual tuning [CITED: Adaptive threshold tuning] |
| SQL databases for logs | JSONL append-only logs | 2024-2026 | Streaming-friendly, no lock contention, standard format for log processors [CITED: JSONL structured logging] |
| Manual shell script testing | Bats + ShellCheck | 2025-2026 | Automated testing for Bash scripts with static analysis [CITED: ShellCheck 2026 guide] |

**Deprecated/outdated:**
- Hardcoded model fallback chains: Now config-driven per task type in config.json
- jq-required scripts: Python fallback pattern now standard (no external dependency)

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Exponential decay (half-life 7 days) is better than linear for emphasizing recent failures | Architecture Patterns | May need to tune half-life based on task cadence — daily tasks vs weekly tasks need different decay rates |
| A2 | 0-100 numeric scale sufficient for complexity scoring | Standard Stack | If fine-grained distinctions needed (e.g., score 73 vs 74 matters), may need float scores |
| A3 | ShellCheck and Bats are optional (testing not mandatory for MVP) | Standard Stack | If routing logic gets complex, lack of tests increases risk of regression bugs |
| A4 | Parallel task execution race condition is low-risk (accept interleaved JSONL lines) | Common Pitfalls | High concurrency projects may need flock or SQLite instead of simple append |

**Confidence reasoning:**
- A1: Exponential decay is well-established for recency weighting (MEDIUM confidence — may need tuning)
- A2: 0-100 scale used in most scoring systems, simple to reason about (HIGH confidence)
- A3: Existing ai-delegate has no tests, works fine (MEDIUM confidence — technical debt acknowledged)
- A4: JSONL format recovers from interleaved lines, each line independent (HIGH confidence for low concurrency, LOW for high concurrency)

## Open Questions (RESOLVED)

1. **What threshold values trigger auto-upgrade?**
   - What we know: Research shows adaptive thresholds avoid manual tuning, but no standard values
   - What's unclear: Specific failure rate % or escalation count N that triggers keyword → keyword+files upgrade
   - **RESOLVED:** Start with failure_rate > 0.3 (30%) OR escalation_count > 2 per task type, tune based on observed data

2. **How long to cache history in memory?**
   - What we know: Re-reading delegation-log.jsonl on every routing decision is slow
   - What's unclear: Memory footprint of caching last N entries, invalidation strategy
   - **RESOLVED:** Cache last 1000 entries in session, refresh every 100 routing decisions or if log modified timestamp changes

3. **Should scoring mode persist across sessions?**
   - What we know: Task types auto-upgrade scoring modes during session
   - What's unclear: Does scoring mode reset to keyword on next ai-delegate invocation, or persist via config?
   - **RESOLVED:** Persist in config.json under `task_routing.<type>.scoring_mode`, default to keyword for new types

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Bash | Script runtime | ✓ | 5.x (system) | — |
| Python 3 | JSON parsing | ✓ | 3.10.12 | — |
| npm | Optional (Bats install) | ✓ | 11.5.1 | Manual Bats install or skip tests |
| jq | Optional (JSON parsing) | ✗ | — | Python 3 fallback (already implemented) |
| ShellCheck | Optional (static analysis) | ✗ | — | Skip linting or install manually |
| Bats | Optional (testing) | ✗ | — | Skip unit tests or install via npm |
| model-registry | Model availability checks | ✓ | Phase 01 | — |
| ollama-run | GLM Ollama execution | ✓ | Phase 04 | — |
| zai-run | GLM z.ai execution | ✓ | Phase 04 | — |

**Missing dependencies with no fallback:**
- None — all required dependencies present

**Missing dependencies with fallback:**
- jq → Python 3 json module (existing pattern in ai-delegate)
- ShellCheck → Manual code review (optional quality tool)
- Bats → Manual testing (optional, no tests exist currently)

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Bats (Bash Automated Testing System) 1.11+ |
| Config file | None — see Wave 0 (install Bats if testing desired) |
| Quick run command | `bats tests/routing.bats` |
| Full suite command | `bats tests/*.bats` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| D-01 | Three scoring modes implemented | unit | `bats tests/routing.bats -f "scoring modes"` | ❌ Wave 0 |
| D-04 | Complexity score 0-100 numeric | unit | `bats tests/routing.bats -f "score range"` | ❌ Wave 0 |
| D-05 | Time decay applied to history | unit | `bats tests/routing.bats -f "time decay"` | ❌ Wave 0 |
| D-09 | Module separation enforced | manual-only | Visual inspection of lib/ structure | N/A |
| D-14 | JSONL log schema consistent | unit | `bats tests/logging.bats -f "schema"` | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** `shellcheck ~/dev/.meta/bin/ai-delegate` (if ShellCheck installed)
- **Per wave merge:** `bats tests/*.bats` (if Bats installed and tests written)
- **Phase gate:** Manual smoke test — run `ai-delegate status` and `ai-delegate impl "test task"` with `-v` flag

### Wave 0 Gaps

- [ ] Install Bats: `npm install -g bats` — if unit testing desired
- [ ] Create `tests/routing.bats` — covers D-01, D-04, D-05 (complexity scoring and time decay)
- [ ] Create `tests/logging.bats` — covers D-14 (JSONL schema validation)
- [ ] Install ShellCheck: `sudo apt install shellcheck` — for static analysis (optional)

**If no gaps:** Testing is optional for MVP. Manual testing via smoke tests sufficient. Decision: defer automated tests to DEBT.1 if time-constrained.

## Security Domain

> Omitted — config.json does not specify `security_enforcement` setting, and phase involves internal scripting with no network-exposed APIs, authentication, or user input validation. Security concerns limited to:
> - Log sanitization (covered in Pitfall 5)
> - Config file permissions (standard Unix file security)
> - No cryptography, session management, or access control in scope

## Sources

### Primary (HIGH confidence)

- Existing codebase: `~/dev/.meta/bin/ai-delegate` (856 lines) — verified patterns for config reading, model checking, session IDs
- Existing codebase: `~/dev/.meta/bin/model-registry` (372 lines) — verified helper for model availability checks
- Existing codebase: `.planning/config.json` — verified schema for models, task_routing, escalation sections
- Existing codebase: `~/dev/.meta/bin/ollama-run` and `~/dev/.meta/bin/zai-run` — Phase 04 wrappers confirmed available
- System environment: Bash 5.x, Python 3.10.12, npm 11.5.1 verified present

### Secondary (MEDIUM confidence)

- [Designing Modular Bash: Functions, Namespaces, and Library Patterns](https://www.lost-in-it.com/posts/designing-modular-bash-functions-namespaces-library-patterns/) — modular Bash design with internal function separation
- [Best AI Model for Coding Agents in 2026: A Routing Guide](https://www.augmentcode.com/guides/ai-model-routing-guide) — complexity-based model routing strategies
- [Recency-Weighted Scoring Explained](https://customers.ai/recency-weighted-scoring) — exponential time decay for recency weighting
- [Exponential decay - Wikipedia](https://en.wikipedia.org/wiki/Exponential_decay) — exponential decay function fundamentals
- [JSONL for Log Processing - Structured Logging & Analysis](https://ndjson.com/use-cases/log-processing/) — JSONL format for append-only logs
- [How to Implement Structured Logging Best Practices](https://oneuptime.com/blog/post/2026-01-25-structured-logging-best-practices/view) — structured logging schema consistency
- [How to Install and Use ShellCheck for Safer Bash Scripts in 2026](https://www.turbogeek.co.uk/how-to-install-and-use-shellcheck-for-safer-bash-scripts-in-2026/) — ShellCheck static analysis for Bash
- [Bash Functions: A Comprehensive Guide to Modular Scripting](https://linuxvox.com/blog/bash-functions/) — modular scripting best practices

### Tertiary (LOW confidence)

- [Why Adaptive Data Quality Thresholds Matter](https://www.acceldata.io/blog/adaptive-data-quality-thresholds-moving-beyond-static-rules) — adaptive thresholds avoid manual tuning (general principle, not Bash-specific)
- [Data-adaptive automatic threshold calibration for stability selection](https://www.tandfonline.com/doi/full/10.1080/00949655.2026.2623120) — threshold tuning research (academic, not directly applicable)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — existing codebase verified, all dependencies present or have fallbacks
- Architecture: HIGH — patterns verified in existing ai-delegate, modular Bash well-established
- Pitfalls: MEDIUM — based on general Bash scripting experience and JSONL format characteristics
- Threshold values: LOW — no authoritative source for specific failure rate or escalation count triggers, requires empirical tuning

**Research date:** 2026-04-18
**Valid until:** 2026-05-18 (30 days — Bash/Python stable, threshold tuning may evolve with usage data)
