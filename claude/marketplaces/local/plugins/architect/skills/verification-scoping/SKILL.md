---
name: verification-scoping
description: Use when deciding how to verify a change — about to re-run a test suite, linter or typechecker you already ran this session; waiting on CI or a background job; or pushing a second time for the same task. Covers scoping verification to what changed, letting CI be the real gate, and keeping large command output out of context.
---

# Verification Scoping

## Core Principle

**Verification is not optional; its *breadth* is the variable you control.**

The waste is almost never "ran the tests." It is running the *same whole* suite
again when one file moved, and then waiting in the foreground for a machine to
agree with you. Scope the run to what changed, and let the slow, broad checks
happen where you are not sitting and watching.

Grounded in an 8-week measurement of this user's own sessions (September 2026);
the underlying data is in PR #213.

## The judgment

**Iterate scoped; verify broad once.**

While you are still changing code, run only what covers the area you touched —
`pytest -k`, a test path, `ruff check <dir>`, a single project. A scoped run that
comes back in 3 seconds gets run more often, not less, so it catches more.

Then run the full suite **once**, before the PR. That run is mandatory: full runs
surface a genuine failure **22.3%** of the time, which is why this is a
**scoping** rule and never a **skipping** rule.

**"Once" is a cadence, not a lifetime cap.** If a full run fails and you make a
real fix, running it again is compliant — that is the loop working as intended.
What "once" rules out is re-running when nothing has changed, which is the
name-the-edit test below.

**If nothing changed, a re-run tells you nothing.** Before re-running the whole
suite, ask what edit would make the result differ from the last one. If you cannot
name it, the run is theatre. Re-read the failure you already have instead.

**Let CI be the real gate — after your one local full run, not instead of it.**
CI runs the matrix, the clean checkout and the other platform, so once you have
pushed there is nothing further to learn by sitting and watching it finish. What
CI replaces is the *watching*, never the single mandatory pre-PR full run: run
that locally, push, then go do the next thing.

**Never wait in the foreground.** If you must wait, start the command with
`run_in_background: true` and wait on the condition with the `Monitor` tool. A
`until ...; do sleep 10; done` loop blocks the session for the full duration and
returns nothing you could not have had asynchronously. "Don't watch" and "wait in
the background" are one rule seen from two sides: never *block* on a result. If
something downstream depends on it, background the command and wait with
`Monitor`; if nothing does, just check later.

**Batch pushes: one per task, not one per change.** Each push costs a CI cycle
and, here, an approval prompt. Group the work, then push.

**Explore before editing.** Reading the surrounding code first is the single
behaviour that correlates with *less* total work, not more. Front-load it.

**Keep big output out of context.** When you know output will be large (full test
logs, `nix build` traces, bulk greps), run it as `cmd 2>&1 | crumb compress` and
pull back only what you need with `crumb retrieve <hash> --query "..."`. Large raw
output left in context crowds out what actually matters and raises the odds of a
mistake later in the session. The `2>&1` is required — crumb compresses stdout
only, so without it stderr (where `nix build` puts the trace) bypasses crumb and
lands raw in context. And `$?` after the pipe is crumb's own status, not the
command's — read `${PIPESTATUS[0]}`, or `set -o pipefail`.

## Applying it

| Situation | Do |
|---|---|
| Mid-iteration, one area changed | Scoped run over that area |
| About to re-run the same full suite | Name the edit that would change the result; if none, don't |
| Change is complete | One full suite, then push |
| Want to know if CI is green | Don't block on it: nothing downstream depends on it → push and check later; something does → `run_in_background` + `Monitor` |
| Must wait on something external | `run_in_background: true` + `Monitor` |
| Command will print a lot | `... 2>&1 \| crumb compress` |

## Anti-patterns

- Re-running the full suite as a nervous tic between small edits.
- Running the full suite locally *and* watching the same checks on CI.
- `until <condition>; do sleep N; done` in the foreground.
- Pushing after each edit so CI "keeps up".
- Skipping the pre-PR full run because a scoped run was green — the scoped run
  did not cover the 22.3%.
