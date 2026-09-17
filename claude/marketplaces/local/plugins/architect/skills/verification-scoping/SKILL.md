---
name: verification-scoping
description: Use when deciding how to verify a change — about to re-run a test suite, linter or typechecker you already ran this session; waiting on CI or a background job; pushing a second time for the same task; or starting work in an unfamiliar area. Covers scoping verification to what changed, letting CI be the real gate, and keeping large command output out of context.
---

# Verification Scoping

## Core Principle

**Verification is not optional; its *breadth* is the variable you control.**

The waste is almost never "ran the tests." It is running the *same whole* suite
again when one file moved, and then waiting in the foreground for a machine to
agree with you. Scope the run to what changed, and let the slow, broad checks
happen where you are not sitting and watching.

## What the measurements say

Over 8 weeks of this user's real sessions:

- Full-suite runs cost **12.22h across 1,009 calls**. **96% of that (11.78h) was
  the 2nd-and-later run in the same session.** 51 of 53 sessions re-ran the same
  suite; the median number of edits since the previous full run was **1**, and
  **19.1% of repeats had zero edits**.
- Those same full runs surface a genuine failure **22.3%** of the time. That is
  why this is a **scoping** rule and never a **skipping** rule.
- Blocking waits (poll loops, `gh run watch`) cost **12.8h** — the single largest
  actionable sink. 72% of the re-running sessions then polled CI for the same
  change, duplicating another 9.53h.
- Sessions that front-load exploration correlate **-0.33..-0.49** with active
  time, tool count and edit churn.

## The judgment

**Iterate scoped; verify broad once.**

While you are still changing code, run only what covers the area you touched —
`pytest -k`, a test path, `ruff check <dir>`, a single project. A scoped run that
comes back in 3 seconds gets run more often, not less, so it catches more.

Then run the full suite **once**, before the PR. That run is mandatory. It is the
one that earns the 22.3%.

**If nothing changed, a re-run tells you nothing.** Before re-running the whole
suite, ask what edit would make the result differ from the last one. If you cannot
name it, the run is theatre. Re-read the failure you already have instead.

**Let CI be the real gate.** CI runs the matrix, the clean checkout and the other
platform. Duplicating it locally *and* watching it finish pays twice for one
answer. Push, then go do the next thing.

**Never wait in the foreground.** If you must wait, start the command with
`run_in_background: true` and wait on the condition with the `Monitor` tool. A
`until ...; do sleep 10; done` loop blocks the session for the full duration and
returns nothing you could not have had asynchronously.

**Batch pushes: one per task, not one per change.** Each push costs a CI cycle
and, here, an approval prompt. Group the work, then push.

**Explore before editing.** Reading the surrounding code first is the single
behaviour that correlates with *less* total work, not more. Front-load it.

**Keep big output out of context.** When you know output will be large (full test
logs, `nix build` traces, bulk greps), pipe it through `crumb compress` and pull
back only what you need with `crumb retrieve <hash> --query "..."`. Context rot is
measurable: the top decile of Bash output pulled ~1.58M tokens into context, and
`crumb` was used zero times. Note that `crumb` passes through the command's exit
code and stderr, so check those separately.

## Applying it

| Situation | Do |
|---|---|
| Mid-iteration, one area changed | Scoped run over that area |
| About to re-run the same full suite | Name the edit that would change the result; if none, don't |
| Change is complete | One full suite, then push |
| Want to know if CI is green | Push and move on; check later, don't watch |
| Must wait on something external | `run_in_background: true` + `Monitor` |
| Command will print a lot | `... \| crumb compress` |

## Anti-patterns

- Re-running the full suite as a nervous tic between small edits.
- Running the full suite locally *and* watching the same checks on CI.
- `until <condition>; do sleep N; done` in the foreground.
- Pushing after each edit so CI "keeps up".
- Skipping the pre-PR full run because a scoped run was green — the scoped run
  did not cover the 22.3%.
