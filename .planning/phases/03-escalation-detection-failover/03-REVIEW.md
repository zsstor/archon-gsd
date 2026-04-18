---
phase: 03-escalation-detection-failover
reviewed: 2026-04-18T00:00:00Z
depth: standard
files_reviewed: 3
files_reviewed_list:
  - /home/zzs/dev/.meta/bin/lib/escalation.sh
  - /home/zzs/dev/.meta/bin/lib/logging.sh
  - /home/zzs/dev/.meta/bin/ai-delegate
findings:
  critical: 4
  warning: 11
  info: 5
  total: 20
status: issues_found
---

# Phase 03: Code Review Report

**Reviewed:** 2026-04-18T00:00:00Z
**Depth:** standard
**Files Reviewed:** 3
**Status:** issues_found

## Summary

Reviewed three bash scripts implementing escalation detection and failover logic for AI task delegation. The files are part of Phase 03 implementation that adds automatic escalation when AI models fail. Overall architecture is sound with modular design, but found several critical security vulnerabilities related to command injection, along with multiple logic errors, missing error handling, and shell scripting anti-patterns.

Key concerns:
1. **Command injection vulnerabilities** in Python heredoc blocks (Critical)
2. **Unquoted variable expansions** that can cause word splitting (Warning)
3. **Missing error handling** in critical paths (Warning)
4. **Race conditions** in file operations (Warning)
5. **Shell scripting anti-patterns** (Info)

## Critical Issues

### CR-01: Command Injection via Unescaped Variables in Python Heredoc

**File:** `/home/zzs/dev/.meta/bin/lib/escalation.sh:37-56`
**Issue:** Python heredoc blocks use unescaped bash variables within single quotes, creating command injection vulnerability. If `$output_file` or `$history_file` contain special characters or are attacker-controlled, malicious Python code could be executed.
**Fix:**
```bash
# Option 1: Pass as arguments to Python
python3 <<'EOF'
import sys
import difflib
import json

output_file = sys.argv[1]
history_file = sys.argv[2]
threshold = float(sys.argv[3])

try:
    new_output = open(output_file).read()
    with open(history_file) as f:
        history = [json.loads(line)['output'] for line in f.readlines()[-3:]]
except:
    sys.exit(1)

for prev_output in history:
    ratio = difflib.SequenceMatcher(None, new_output, prev_output).ratio()
    if ratio >= threshold:
        sys.exit(0)
sys.exit(1)
EOF
"$output_file" "$history_file" "$threshold"

# Option 2: Use environment variables with proper escaping
export OUTPUT_FILE="$output_file"
export HISTORY_FILE="$history_file"
export THRESHOLD="$threshold"
python3 <<'EOF'
import os
import difflib
import json

output_file = os.environ['OUTPUT_FILE']
history_file = os.environ['HISTORY_FILE']
threshold = float(os.environ['THRESHOLD'])
# ... rest of code
EOF
```

### CR-02: Command Injection in JSON String Construction

**File:** `/home/zzs/dev/.meta/bin/lib/logging.sh:34-51`
**Issue:** Multiple heredoc blocks construct JSON by direct variable interpolation with only basic quote escaping (`${description//\"/\\\"}`). This is insufficient - variables can contain newlines, backslashes, and other characters that break JSON syntax or allow injection.
**Fix:**
```bash
# Use environment variables and Python's json.dumps for ALL fields
export TASK_TYPE="$task_type"
export DESCRIPTION="$truncated_desc"
export SCORING_MODE="$scoring_mode"
export SELECTED_MODEL="$selected_model"
export RATIONALE="$rationale"

python3 <<'EOF' >> "$DELEGATION_LOG" 2>/dev/null || true
import json
import os
from datetime import datetime

entry = {
    "timestamp": datetime.now().isoformat(),
    "event_type": "routing_decision",
    "task_type": os.environ['TASK_TYPE'],
    "description": os.environ['DESCRIPTION'],
    "complexity_score": float(os.environ.get('COMPLEXITY_SCORE', '0')),
    "scoring_mode": os.environ['SCORING_MODE'],
    "history_failure_rate": float(os.environ.get('HISTORY_FAILURE_RATE', '0')),
    "selected_model": os.environ['SELECTED_MODEL'],
    "model_chain": json.loads(os.environ.get('MODEL_CHAIN', '[]')),
    "rationale": os.environ['RATIONALE']
}
print(json.dumps(entry))
EOF
```

### CR-03: Python Heredoc Injection via Description Field

**File:** `/home/zzs/dev/.meta/bin/lib/escalation.sh:166-177`
**Issue:** Embeds `$output_file` path directly in Python heredoc. If the path contains quotes or special characters, can break Python syntax or inject code.
**Fix:**
```bash
python3 <<'EOF' >> "$history_file" 2>/dev/null || true
import json
import sys
import os
from datetime import datetime

output_file = os.environ['OUTPUT_FILE']
session_id = os.environ['SESSION_ID']

output = open(output_file).read()
entry = {
    "timestamp": datetime.now().isoformat(),
    "session_id": session_id,
    "output": output[:5000]
}
print(json.dumps(entry))
EOF
```
Set environment variables before the heredoc:
```bash
export OUTPUT_FILE="$output_file"
export SESSION_ID="$session_id"
```

### CR-04: Unsafe String Interpolation in JSON Construction

**File:** `/home/zzs/dev/.meta/bin/lib/logging.sh:321-338`
**Issue:** Triple-quote Python strings with bash variable substitution (`'''${output_preview//\'/\\\'}'''`). If `output_preview` contains triple quotes or special sequences, can break out of string context.
**Fix:**
```bash
# Use environment variables exclusively
export TASK_TYPE="$task_type"
export ATTEMPT_NUMBER="$attempt_number"
export MODEL="$model"
export FAILURE_SIGNAL="${failure_signal:-unknown}"
export OUTPUT_PREVIEW=""
if [[ -f "$output_file" ]]; then
    OUTPUT_PREVIEW=$(head -c 500 "$output_file" 2>/dev/null || true)
fi

python3 <<'EOF' >> "$escalation_log" 2>/dev/null || true
import json
import os
from datetime import datetime

entry = {
    "timestamp": datetime.now().isoformat(),
    "event_type": "escalation",
    "task_type": os.environ['TASK_TYPE'],
    "attempt": int(os.environ['ATTEMPT_NUMBER']),
    "model": os.environ['MODEL'],
    "signal": os.environ['FAILURE_SIGNAL'],
    "output_preview": os.environ.get('OUTPUT_PREVIEW', '')[:500]
}
print(json.dumps(entry))
EOF
```

## Warnings

### WR-01: Unquoted Variable Expansion Allows Word Splitting

**File:** `/home/zzs/dev/.meta/bin/lib/escalation.sh:240`
**Issue:** `execute_model "$model" "$prompt" "$output_file" "$timeout"` calls function that may not exist in this file (imported from execution.sh). If any parameter contains spaces and function doesn't quote internally, word splitting occurs.
**Fix:** Verify `execute_model` in `execution.sh` quotes all parameters. Add defensive quoting:
```bash
execute_model "$model" "$prompt" "$output_file" "$timeout"
```
Actually already quoted here - but verify the function definition handles quoted args.

### WR-02: Race Condition in Directory Creation

**File:** `/home/zzs/dev/.meta/bin/lib/escalation.sh:163`
**Issue:** `mkdir -p "$(dirname "$history_file")" 2>/dev/null || true` followed by write operation. In parallel execution (ai-delegate parallel command), two processes could race to create directory and write.
**Fix:**
```bash
# Use atomic write pattern
local temp_file="${history_file}.tmp.$$"
mkdir -p "$(dirname "$history_file")" 2>/dev/null || true

# Write to temp, then append atomically
python3 <<'EOF' > "$temp_file" 2>/dev/null || true
# ... Python code ...
EOF

# Atomic append (>>) on most filesystems
[[ -f "$temp_file" ]] && cat "$temp_file" >> "$history_file" && rm -f "$temp_file"
```

### WR-03: Silent Failure in Loop Detection

**File:** `/home/zzs/dev/.meta/bin/lib/escalation.sh:255-256`
**Issue:** `if _detect_loop "$output_file" "$history_file" 0.85; then` - if the Python script fails (bad JSON in history, Python error), function returns 1 (no loop detected) silently. Could mask real failures.
**Fix:**
```bash
# Distinguish between "no loop" and "detection failed"
_detect_loop() {
    local output_file="$1"
    local history_file="$2"
    local threshold="${3:-0.85}"

    [[ ! -f "$output_file" ]] && return 2  # File not found
    [[ ! -f "$history_file" ]] && return 2  # File not found

    python3 <<EOF
# ... existing code ...
EOF
    local exit_code=$?
    # exit_code 0 = loop detected, 1 = no loop, 2+ = error
    return $exit_code
}

# Then in caller:
local detect_result
if _detect_loop "$output_file" "$history_file" 0.85; then
    signal="loop"
elif [[ $? -eq 2 ]]; then
    # Detection failed - log warning but don't treat as loop
    [[ "${VERBOSE:-false}" == "true" ]] && echo "[warning] Loop detection failed" >&2
fi
```

### WR-04: Missing Error Handling for read_config Failures

**File:** `/home/zzs/dev/.meta/bin/lib/escalation.sh:198`
**Issue:** `chain_json=$(read_config "$chain_key" "$(read_config "escalation.chain.default" '[]')")` - nested command substitution. If inner `read_config` fails, outer one uses empty string, not default array.
**Fix:**
```bash
local default_chain
default_chain=$(read_config "escalation.chain.default" '[]') || default_chain='[]'
chain_json=$(read_config "$chain_key" "$default_chain") || chain_json="$default_chain"
```

### WR-05: Incomplete Exit Code Handling

**File:** `/home/zzs/dev/.meta/bin/lib/escalation.sh:244-251`
**Issue:** Exit code 127 (not_available) causes `((i--))` to retry same index, but if multiple consecutive models are unavailable, could loop indefinitely checking same unavailable model.
**Fix:**
```bash
case $exit_code in
    0) ;;  # Success - check for other signals
    2) signal="quota" ;;
    124) signal="timeout" ;;
    127)
        # Model not available - skip without decrementing (continue already advances i)
        [[ "${VERBOSE:-false}" == "true" ]] && echo "[escalation] $model not available, trying next" >&2
        continue
        ;;
    *) signal="explicit_failure" ;;
esac
```
Remove the `((i--))` which is problematic.

### WR-06: Potential Division by Zero

**File:** `/home/zzs/dev/.meta/bin/lib/logging.sh:225-227`
**Issue:** Python code checks `if total_weight > 0:` but this could be false if all entries have age > 7*log2(1000) days (effectively zero after decay). Division by zero is prevented, but the 0.5 fallback may not be semantically correct.
**Fix:**
```python
# Cold start: if <5 entries OR total_weight near-zero, return Bayesian prior
if entry_count < 5 or total_weight < 0.001:
    print(0.5)
elif total_weight > 0:
    print(failure_weight / total_weight)
else:
    print(0.5)
```

### WR-07: Unsafe sed Pattern in Description Sanitization

**File:** `/home/zzs/dev/.meta/bin/lib/logging.sh:246`
**Issue:** `sanitized=$(echo "$sanitized" | sed -E 's/(password|key|token|secret|api_key)=[^ ]*/\1=REDACTED/gi')` - the `[^ ]*` pattern stops at space, so `password=foo bar` only redacts `foo`, leaving `bar` in logs.
**Fix:**
```bash
# Match until whitespace, quote, or end of line
sanitized=$(echo "$sanitized" | sed -E 's/(password|key|token|secret|api_key)=[^[:space:]&]*/\1=REDACTED/gi')

# Or better: use Python for robust parsing
_sanitize_description() {
    python3 <<'EOF'
import re
import sys
desc = sys.stdin.read()
# Redact key=value patterns
desc = re.sub(r'(password|key|token|secret|api_key)\s*=\s*\S+', r'\1=REDACTED', desc, flags=re.IGNORECASE)
print(desc)
EOF
}
```

### WR-08: Missing Validation for Escalation Count File

**File:** `/home/zzs/dev/.meta/bin/ai-delegate:171`
**Issue:** `escalation_count=$(cat "${output_file}.escalation_count" 2>/dev/null || echo "0")` - if file contains non-numeric data (malformed by race condition or disk error), will pass non-numeric value to `log_task_outcome`.
**Fix:**
```bash
escalation_count=$(cat "${output_file}.escalation_count" 2>/dev/null || echo "0")
# Validate it's a number
[[ "$escalation_count" =~ ^[0-9]+$ ]] || escalation_count=0
```

### WR-09: Dangerous eval in Test Command Execution

**File:** `/home/zzs/dev/.meta/bin/ai-delegate:453`
**Issue:** `if (cd "$PROJECT_ROOT" && eval "$test_cmd") 2>/dev/null; then` - using `eval` with dynamically constructed command. If `spec_file` contains shell metacharacters, could execute arbitrary commands.
**Fix:**
```bash
# Don't use eval - test commands are known patterns
if [[ "$spec_file" == *.spec.ts ]] || [[ "$spec_file" == *.spec.tsx ]]; then
    (cd "$PROJECT_ROOT" && npx playwright test "$full_path" --reporter=list) 2>/dev/null
elif [[ "$spec_file" == *.test.ts ]] || [[ "$spec_file" == *.test.tsx ]]; then
    (cd "$PROJECT_ROOT" && npm test -- "$full_path") 2>/dev/null
elif [[ "$spec_file" == *.py ]]; then
    (cd "$PROJECT_ROOT" && pytest "$full_path" -v) 2>/dev/null
fi
```

### WR-10: Unquoted Command Substitution in Find

**File:** `/home/zzs/dev/.meta/bin/ai-delegate:295`
**Issue:** `$(find "$full_ref" -type f \( -name "*.tsx" -o -name "*.ts" -o -name "*.py" \) | head -5 | while read f; do echo "=== ${f#$PROJECT_ROOT/} ==="; head -50 "$f"; done)` - the `while read f` doesn't quote variable, and `f` could contain spaces.
**Fix:**
```bash
while IFS= read -r f; do
    echo "=== ${f#$PROJECT_ROOT/} ==="
    head -50 "$f"
done
```

### WR-11: Missing Bounds Check on Array Access

**File:** `/home/zzs/dev/.meta/bin/lib/escalation.sh:232`
**Issue:** `for ((i=start_idx; i<${#chain[@]}; i++)); do` - if `start_idx` is not found in chain (all comparisons fail), it remains 0, which is correct. But if chain is empty, loop doesn't run and function returns 1 (correct). However, `start_idx` could theoretically be set to wrong value if chain has duplicates.
**Fix:**
```bash
# Validate start_idx is in bounds
if [[ $start_idx -ge ${#chain[@]} ]]; then
    [[ "${VERBOSE:-false}" == "true" ]] && echo "[escalation] Initial model not in chain, starting from beginning" >&2
    start_idx=0
fi
```

## Info

### IN-01: Commented-out Code Section

**File:** `/home/zzs/dev/.meta/bin/lib/logging.sh:288-295`
**Issue:** Function `_cache_recent_history` is a stub with TODO comment. Either implement or remove.
**Fix:**
```bash
# Remove the stub if not implementing:
# Delete lines 288-295

# Or if keeping for future work, add FIXME marker:
# FIXME: Implement session-level caching if query performance becomes bottleneck
```

### IN-02: Magic Number in Threshold

**File:** `/home/zzs/dev/.meta/bin/lib/escalation.sh:255`
**Issue:** Hardcoded threshold `0.85` in loop detection call. Should be configurable.
**Fix:**
```bash
# At top of file or in config
LOOP_DETECTION_THRESHOLD="${LOOP_DETECTION_THRESHOLD:-0.85}"

# In usage:
if _detect_loop "$output_file" "$history_file" "$LOOP_DETECTION_THRESHOLD"; then
```

### IN-03: Inconsistent Verbose Logging Pattern

**File:** Multiple locations
**Issue:** Some verbose logs use `[[ "${VERBOSE:-false}" == "true" ]]`, others check the variable differently. Inconsistent pattern makes code harder to maintain.
**Fix:**
```bash
# Create helper function in ai-delegate or logging.sh:
verbose_log() {
    [[ "${VERBOSE:-false}" == "true" ]] && echo "$@" >&2
}

# Then use consistently:
verbose_log "[escalation] Attempt $attempt: trying $model"
```

### IN-04: Unused Variable in Chain Validation

**File:** `/home/zzs/dev/.meta/bin/lib/escalation.sh:298-326`
**Issue:** Function `_validate_escalation_chain` is defined but never called in the codebase. Dead code.
**Fix:**
```bash
# Either call it in execute_with_escalation before starting:
execute_with_escalation() {
    local task_type="$1"
    # ...

    # Validate chain configuration
    _validate_escalation_chain "$task_type" || true  # Don't fail, just warn

    # ... rest of function
}

# Or remove the function if not using validation
```

### IN-05: Ambiguous Function Return Values

**File:** `/home/zzs/dev/.meta/bin/lib/escalation.sh:29-56`
**Issue:** Detection functions return 0 for "detected" and 1 for "not detected", which is opposite of typical bash convention (0=success/false, 1=failure/true). This is confusing.
**Fix:**
```bash
# Add comment explaining convention:
# Detection functions return 0 (success) when signal IS detected
# This allows usage: if _detect_loop ...; then handle_loop; fi

# Or invert return values to match bash idioms:
# Returns: 1 if loop detected, 0 otherwise
_detect_loop() {
    # ... logic ...
    if ratio >= threshold:
        sys.exit(1)  # Loop detected (failure state)
    sys.exit(0)  # No loop (success state)
}

# Then invert caller:
if ! _detect_loop "$output_file" "$history_file" 0.85; then
    signal="loop"
fi
```
Note: Current convention is actually reasonable for the use case - keep as-is but add clarifying comments.

---

_Reviewed: 2026-04-18T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
