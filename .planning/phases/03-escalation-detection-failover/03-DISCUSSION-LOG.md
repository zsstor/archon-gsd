# Phase 03: Escalation Detection + Failover - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-18
**Phase:** 03-escalation-detection-failover
**Areas discussed:** Escalation signals, Handoff protocol, Escalation behavior, Feedback integration

---

## Gray Area Selection

| Option | Description | Selected |
|--------|-------------|----------|
| Escalation signals | How to detect: explicit failures vs loops vs test failures vs token exhaustion? Detection thresholds and priority. | ✓ |
| Handoff protocol | What context gets bundled for the next model? Format of attempt history and failure signals. | ✓ |
| Escalation behavior | When to escalate vs retry same model? Max attempts before escalation? Cooldown between attempts? | ✓ |
| Feedback integration | How escalation events feed into learning? Penalizing models that trigger escalation? | ✓ |

**User's choice:** All four areas
**Notes:** User wanted comprehensive discussion of the entire escalation system.

---

## Escalation Signals

### Loop Detection

| Option | Description | Selected |
|--------|-------------|----------|
| Output similarity | Hash last N outputs, trigger if similarity > threshold. Catches semantic loops, not just exact matches. | ✓ |
| Exact match | Trigger only if output is byte-identical N times. Simpler but misses near-loops. | |
| Structural pattern | Parse output structure (e.g., same error type N times). More precise but more complex. | |

**User's choice:** Output similarity (Recommended)
**Notes:** None

### Test Failure Detection

| Option | Description | Selected |
|--------|-------------|----------|
| Parse test output | Look for test framework patterns (FAIL, FAILED, AssertionError). Works with common frameworks out of the box. | ✓ |
| Exit code only | Trust non-zero exit code from test runners. Simpler but can't distinguish test failure from other errors. | |
| Run tests after impl | Explicitly run test suite after implementation and check results. More control but requires knowing test command. | |

**User's choice:** Parse test output (Recommended)
**Notes:** None

### Token Exhaustion Detection

| Option | Description | Selected |
|--------|-------------|----------|
| Output pattern matching | Parse error messages for max_tokens, truncated, context_length patterns. Works across providers. | ✓ |
| Provider-specific parsing | Use provider SDKs or known error formats per model. More accurate but harder to maintain. | |
| Pre-emptive estimation | Estimate token count before sending, warn if likely to exhaust. Proactive but requires token counting. | |

**User's choice:** Output pattern matching (Recommended)
**Notes:** None

---

## Handoff Protocol

### Handoff Contents

| Option | Description | Selected |
|--------|-------------|----------|
| Full attempt history | Original prompt + each model's output + failure signals. The new model sees everything tried. | ✓ |
| Summary only | Original prompt + summary of what was tried and why it failed. Saves tokens but loses detail. | |
| Last attempt + signal | Original prompt + only the failing output + failure type. Minimal but may miss patterns. | |

**User's choice:** Full attempt history (Recommended)
**Notes:** None

### Handoff Format

| Option | Description | Selected |
|--------|-------------|----------|
| Structured markdown | ## Previous Attempts / ### Attempt 1 (gemini-flash) / Output: ... / Failure: loop detected. Human-readable and model-friendly. | ✓ |
| JSON blob | Machine-parseable, but less natural for the receiving model to reason about. | |
| Inline prose | Narrative description: 'We first tried X which failed because Y, then...' Natural but verbose. | |

**User's choice:** Structured markdown (Recommended)
**Notes:** None

---

## Escalation Behavior

### Retry vs Escalate

| Option | Description | Selected |
|--------|-------------|----------|
| Escalate on signal | Any detected signal (loop/failure/quota) triggers immediate escalation. No retries on same model. | ✓ |
| Retry once then escalate | One retry on the same model before escalating. Gives transient failures a second chance. | |
| Configurable per signal | Different behavior per signal type (e.g., retry on timeout, escalate on loop). Most flexible but more config. | |

**User's choice:** Escalate on signal (Recommended)
**Notes:** None

### Chain Exhaustion

| Option | Description | Selected |
|--------|-------------|----------|
| Fail with full history | Return failure with all attempt history logged. Human can review what was tried. | ✓ |
| Retry from top | Start the chain over with accumulated context. Risk of infinite loop but might work on second pass. | |
| Drop to human | Create a TODO/issue for human intervention. Explicit handoff but adds friction. | |

**User's choice:** Fail with full history (Recommended)
**Notes:** None

### Cooldown

| Option | Description | Selected |
|--------|-------------|----------|
| No cooldown | Escalate immediately to maximize throughput. Quota limits are handled by Phase 11 later. | ✓ |
| Brief cooldown (1-5s) | Small delay between attempts. Helps with transient rate limits but slows down. | |
| Exponential backoff | Increasing delays: 1s, 2s, 4s... Robust but significantly slower. | |

**User's choice:** No cooldown (Recommended)
**Notes:** None

---

## Feedback Integration

### Learning Integration

| Option | Description | Selected |
|--------|-------------|----------|
| Log with penalty weight | Each escalation counts as a weighted failure in the model's history for that task type. Affects future routing. | ✓ |
| Log without penalty | Record escalation events for analysis but don't affect routing. Learning is manual/offline. | |
| Immediate routing adjustment | After N escalations, bump the model down in preference for that task type in real-time. | |

**User's choice:** Log with penalty weight (Recommended)
**Notes:** None

### Credit Attribution

| Option | Description | Selected |
|--------|-------------|----------|
| Credit final model only | The model that succeeded gets +1 success. Failed models already got -1 each. Clean accounting. | ✓ |
| Credit all in chain | Partial credit to models that contributed context, even if they failed. Reflects collaborative effort. | |
| No credit on escalation | Escalation chain tasks don't affect learning at all. Keeps learning data 'clean' from complex scenarios. | |

**User's choice:** Credit final model only (after clarification)
**Notes:** User asked about implications of each option. Key insight: separate concerns — (1) learning affects routing with simple attribution, (2) logging preserves full data for future sophisticated analysis. User added: "Also add full/verbose logging so we can revisit the entire thing later as a separate initiative. Preserve the data vs. aggregate and discard." This led to D-12 in CONTEXT.md.

---

## Claude's Discretion

- Similarity threshold for loop detection
- Hashing algorithm for output comparison
- Penalty weight for escalation failures
- Log retention policy

## Deferred Ideas

- Sophisticated credit attribution (distinguishing "model failed fair task" from "router gave impossible task") — Phase 07
- Quota-aware scheduling and waiting for recovery — Phase 11
