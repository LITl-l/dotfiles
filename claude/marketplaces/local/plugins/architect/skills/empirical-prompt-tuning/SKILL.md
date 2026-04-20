---
name: empirical-prompt-tuning
description: Use when a skill, slash command, task prompt, CLAUDE.md section, or code-generation prompt has just been authored or substantially revised — OR when an agent keeps missing the mark and you suspect the instruction itself is the fault. Dispatches fresh subagents against fixed scenarios, dual-axis evaluates (self-report + Task-usage metrics), and iterates until improvement plateaus.
---

# Empirical Prompt Tuning

**Prompt quality is invisible to its author.** Re-reading your own prose moments after writing it is structurally impossible — the text that felt clear in your head stays clear when you read it back. The only honest evaluation comes from **dispatching a fresh agent with zero prior context** and measuring both what they report and how the system logs their execution.

Iterate until the improvement curve flattens. Do not stop early.

## When to use

- Immediately after authoring or substantially revising a skill, slash command, or task prompt
- When an agent misbehaves and you suspect instruction ambiguity, not capability
- When a high-traffic prompt (core automation, reusable skill) should be made robust

Do not use for:
- Throwaway one-off prompts (evaluation cost exceeds benefit)
- Purely stylistic preference tuning (no objective success criterion)

## Workflow

### 0. Iteration 0 — static description↔body audit (no dispatch)

Before any subagent work, statically compare the skill's `description` field to what the body actually covers.

- Read `description` — note every trigger phrase and capability it promises
- Read the body — note what it actually instructs / references
- Any mismatch must be resolved (either expand the body or narrow the description) **before** iter 1

Skip this at your peril. If the description promises X but the body only covers Y, a subagent will silently re-interpret the body toward X (the description anchors their mental model). You get a false-positive pass where the skill actually doesn't do what it claims.

**Example:** description says "navigation / form filling / data extraction"; body is a `npx playwright test` CLI reference. Subagent will hallucinate the missing capabilities from the description. Fix the gap before testing.

### 1. Baseline setup

Fix two things **before** dispatching anything:

- **Scenarios (2-3)**: one median realistic case + 1-2 edge cases. Concrete, not toy. Reflect the actual context where this prompt runs.
- **Requirements checklist (3-7 items per scenario)**: what the output must satisfy. At least **one `[critical]`** tag per scenario (pass/fail threshold). Accuracy % = items met / total.

**Do not modify the checklist after dispatch.** Moving goalposts contaminates the signal.

### 2. Dispatch to fresh subagents

Use the Task tool to send the prompt-under-test to a **new subagent**. Never re-read it yourself — that's not evaluation, that's self-narration.

Run multiple scenarios in parallel by placing several Agent calls in a single message.

If the environment cannot dispatch subagents (you are already a subagent, Task tool disabled), see **Environment constraints** below. Self-review is not a fallback.

### 3. Execute

Hand the subagent a prompt following the **Subagent dispatch contract** (below). The subagent runs the scenario, produces artifacts, and returns a structured self-report.

### 4. Dual-axis evaluation

Extract from each result:

**Self-report** (from the subagent's returned text):
- Ambiguities: where they got stuck on wording
- Discretionary fills: choices the prompt left unspecified
- Retries: how many times they redid a decision (subagent-reported; can't measure externally)

**Instruction-side metrics** (from Task tool usage metadata):
- **Success/failure**: ○ only if **all `[critical]` items** are met. One `[critical]` × or partial ⇒ ×. Binary label only.
- **Accuracy %**: ○ = full points, × = 0, partial = 0.5; summed / total items
- **Steps**: `tool_uses` from the Task return meta, verbatim. Count Read/Grep, don't exclude "cheap" calls
- **Duration**: `duration_ms` from meta
- **Retries**: from the self-report (see above)

**On failure**, always annotate *which `[critical]` dropped* in the ambiguities section — keeps the root-cause trail attached.

Requirements without any `[critical]` produce a vacuous pass. At least one is mandatory. Never add/remove `[critical]` tags after the fact.

### 5. Apply minimal diff

One iteration, one theme. Related micro-edits can bundle (2-3 small fixes with a common cause = one iter); unrelated fixes wait.

**Before applying**, write out which checklist item / judgment-phrase the edit targets. Edits inferred from axis *names* instead of item *wording* routinely miss (see "ripple patterns" below).

### 6. Re-dispatch

Fresh subagent every iteration. **Never reuse** — a prior subagent has absorbed your previous changes and will rate the new version relative to the old one rather than blind.

Raise parallelism only if iterations aren't converging.

### 7. Convergence check

Stop when two consecutive iterations all satisfy:

- New ambiguities: 0
- Accuracy delta: ≤ +3 pp (saturated)
- Steps delta: ±10%
- Duration delta: ±15%
- **Hold-out validation**: at convergence, dispatch one previously-unused scenario. If accuracy drops ≥15 pp from recent average, you've overfit — go back to baseline and add more edge diversity.

High-importance prompts: require 3 consecutive iterations.

## Evaluation axes

| Axis | Source | Meaning |
|---|---|---|
| Success/failure | `[critical]` items all ○ ⇒ ○ (binary) | Minimum bar |
| Accuracy % | Checklist completion rate | Partial-success degree |
| Steps | Task usage `tool_uses` | Instruction waste signal |
| Duration | Task usage `duration_ms` | Cognitive-load proxy |
| Retries | Subagent self-report | Ambiguity signal |
| Ambiguities | Subagent self-report bullets | Qualitative improvement fuel |
| Discretionary fills | Subagent self-report bullets | Surfaces implicit spec |

**Weighting**: qualitative (ambiguities / fills) primary, quantitative (time / steps) secondary. Chasing duration alone thins the prompt to brittleness.

### `tool_uses` as structural-flaw detector

Accuracy % alone hides design problems. `tool_uses` **relative across scenarios** exposes structural thinness:

- If one scenario's `tool_uses` is **3-5× the others**, that skill is a **decision-tree index** rather than self-contained instruction. The agent is chasing references.
- Typical: every scenario runs in 1-3 tool calls except one at 15+ → no inline recipe for that case, agent sweeps `references/`.
- Fix: iter 2 adds a minimal working example inline, or a "when to descend into references" guide at the top of the SKILL body. `tool_uses` drops sharply.

100% accuracy + imbalanced `tool_uses` is **not convergence** — it's evidence to dispatch iter 2.

### Ripple patterns (edit → effect is non-linear)

Three patterns recur when estimating what a diff will move:

- **Conservative** (estimated > actual): you aimed one edit at multiple axes; only one moved. Multi-axis shots miss.
- **Overshoot** (estimated < actual): one structural information unit (command + config + expected-output trio) satisfied several judgment phrases simultaneously. Combined information hits multiply.
- **Zero** (estimated > 0, actual = 0): edit inferred from axis *name*, not from the judgment phrase's *wording*. Axes and judgments are different.

Stabilize estimation by asking the subagent to **verbalize which judgment phrase each edit will satisfy** before applying. Phrase-level mapping is the only reliable estimator. When adding new axes, specify each score tier in wording concrete enough for a subagent to judge (e.g., "all CLI flags explicit", "minimal running example included in full") — not just axis labels.

## Subagent dispatch contract

Hand the subagent this exact structure:

```
You are a fresh reader of <target prompt name>. No prior context.

## Target prompt
<full text pasted, OR a Read path to the file>

## Scenario
<one-paragraph situational setup>

## Requirements checklist
1. [critical] <minimum-bar item>
2. <normal item>
3. <normal item>
...
(Evaluation rules: see the caller's workflow §4. At least one [critical] required.)

## Task
1. Execute the scenario following the target prompt. Produce artifacts.
2. Return the report below.

## Report structure
- Artifact: <output or execution summary>
- Requirements: each item ○ / × / partial (with reason)
- Ambiguities: where the prompt was unclear; phrases you had to re-read (bullets)
- Discretionary fills: decisions the prompt did not specify that you made (bullets)
- Retries: how many times you redid the same decision, and why
```

Caller extracts self-report sections; pulls `tool_uses` / `duration_ms` from the Agent tool's usage metadata; fills the evaluation table.

## Environment constraints

If fresh-subagent dispatch is not available (you are already a subagent; Task tool disabled):

- **Option A**: ask the parent session's user to launch a separate Claude Code session and run the evaluation there
- **Option B**: skip empirical evaluation and report explicitly: "empirical evaluation skipped: dispatch unavailable"
- **Never**: substitute self-review. The bias invalidates the result.

**Structural-review mode**: a weaker but valid alternative when all you need is a consistency/clarity review (not execution). Make it explicit in the subagent prompt: *"Structural review mode: text-consistency check, not execution."* This bypasses the environment-constraint skip. Structural review supplements empirical evaluation — it does **not** substitute for it and cannot count toward consecutive-convergence tally.

## Stopping conditions

- **Converged** — stop. Two (or three, for high-importance prompts) consecutive iterations meet all convergence criteria including hold-out validation.
- **Diverging** — 3+ iterations with no reduction in new ambiguities ⇒ the design itself is wrong. Stop patching, rewrite structure from scratch.
- **Resource cutoff** — cost of more iterations outweighs the prompt's importance. Ship at 80 and move on.

## Presentation format

```
## Iteration N

### Diff from previous
- <one-line edit description>

### Results (per scenario)
| Scenario | Pass/Fail | Accuracy | Steps | Duration | Retries |
|---|---|---|---|---|---|
| A | ○ | 90% | 4 | 20s | 0 |
| B | × | 60% | 9 | 41s | 2 |

### New ambiguities (this iter)
- <scenario B>: [critical] item N failed — <one-line reason>    # always annotate on failure
- <scenario B>: <other finding>
- <scenario A>: (none new)

### New discretionary fills
- <scenario B>: <what they had to invent>

### Next edit
- <one-line minimal diff>

(Convergence: X consecutive clears; Y remaining until stop.)
```

## Red flags — common rationalizations

| Rationalization | Reality |
|---|---|
| "I can re-read it and see the same things." | You cannot "objectively" review text you just wrote. Dispatch. |
| "One scenario is enough." | One scenario overfits. Minimum 2, ideally 3. |
| "Zero new ambiguities once ⇒ done." | Could be chance. **Consecutive** clears confirm. |
| "Let me fix all the findings at once." | You'll lose which edit caused which effect. One theme per iter. |
| "Let me split every micro-edit into its own iter." | Opposite trap. Related 2-3 fixes bundle. Splitting explodes iteration count. |
| "Metrics are good, I'll ignore the qualitative notes." | Short duration can signal a thinned, brittle prompt. Qualitative is primary. |
| "Rewriting from scratch would be faster." | After 3+ stuck iterations, yes. Before that, it's avoidance. |
| "Let me reuse the same subagent." | It has learned your previous revisions. Always fresh. |

## Common failure modes

- **Scenarios too easy or too hard**: both produce no signal. Median realistic + one edge.
- **Metric-chasing only**: cut duration by cutting context → brittle. Qualitative first.
- **Too much per iteration**: can't attribute which change mattered.
- **Tuning scenarios to match edits**: trimming a scenario to make an ambiguity "disappear" inverts the whole exercise.

## Related

- `adr-discipline` (sibling skill): same plugin, same philosophy — verified discipline for authoring artifacts. ADRs decide tech; this skill disciplines prompt authoring.
- `retrospective-codify` (if present): post-task learning capture. This skill runs **during** prompt authoring; retrospective runs **after** the work. Don't confuse them.
- Parallel dispatch: use a single message with multiple Agent calls when running scenarios concurrently.

## Attribution

Adapted from [mizchi/chezmoi-dotfiles `empirical-prompt-tuning` SKILL.md](https://github.com/mizchi/chezmoi-dotfiles/blob/main/dot_claude/skills/empirical-prompt-tuning/SKILL.md). Translated to English and lightly adapted for this repo (jj workflow context; `architect` plugin sibling references). Methodology is unchanged.
