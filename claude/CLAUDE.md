# Claude Code Instructions

## Working

- **Match effort to the task.** Act directly on clear or small tasks; reserve plan
  mode for work that is genuinely complex, ambiguous, or risky.
- **Commit to a sound approach.** Once you have enough to act, act — don't
  re-litigate a decision already made or re-derive facts already established.
  Reconsider on new evidence, not on doubt.
- **Minimal changes, root causes.** Only modify what's necessary; no temporary
  workarounds. Never modify code you haven't read in this session.
- **Evidence before assertions.** Never claim complete, fixed, or passing without
  running the check and reading its output. Scope the check to what changed — the
  full suite is for the PR, not for every edit.
- When compacting, preserve: modified file list, test commands, current plan state.

## Context

Long, bloated context measurably degrades accuracy ("context rot") — keep it lean to
avoid mistakes like editing a stale or unread file.

- `/clear` between unrelated tasks.
- **Pipe large output through crumb**: `big-cmd | crumb compress` prints a small stub;
  pull back what you need with `crumb retrieve <hash> --query "..."`. Use the CLI, not
  the MCP compress tool. crumb passes through the command's exit code and stderr —
  check those separately.
- Send subagents to explore; have them return conclusions, not file dumps.
- Scope investigations narrowly — don't read everything.

## Research

Use WebSearch liberally — prefer an extra query over stale knowledge. When
investigating options, architecture, or "what's current," widen the lens deliberately
instead of searching the first phrase that comes to mind:

1. **Raise the abstraction level** — search the underlying problem, not the assumed tool.
2. **Recent papers** — arxiv / OpenReview, within the last year.
3. **Negate the premise** — "without RAG", "all in Postgres", "WASM instead of X".
4. **Regional / regulatory angle** — 「日本」「sovereign」「on-prem」「airgapped」.
5. **GitHub trending**, filtered: language × last 3 months × star growth.
6. **Research-lab OSS** — AISI / Apple / Anthropic / DeepMind / NTT研 / 産総研.
7. **"Why we stopped using X" postmortems** — withdrawal writeups carry more signal
   than adoption writeups.

## Version Control: Jujutsu (jj)

This environment uses **Jujutsu (jj)**, not git. **Never use git commands directly.**

- **Always pass `-m`** to `jj describe`, `jj squash`, `jj split`, `jj commit`. Without
  it jj opens `$EDITOR` and hangs forever in a non-interactive shell.
- **New task** — use the `jj-workspace` agent (workspaces go under
  `~/wkspace/worktree/<type>/`). Already in one? `jj workspace root` tells you.
- **Finishing** — changed files MUST reach a PR; use the `jj-github` agent (`/jj-pr` is
  the human path — see the bullet below). A session that cannot answer a permission
  prompt — any background worker — stops at `jj describe -m` and reports instead:
  `jj git push` and `gh pr create` are gated, and a worker waiting on that gate blocks
  forever.
- The `/jj` skill can be invoked automatically; `/jj-pr`, `/jj-history`, `/jj-safety`,
  `/jj-revsets`, `/jj-submodules` are slash-command only — they are never loaded unless
  asked for by name.
- **Superpowers artifacts**: `brainstorming` and `writing-plans` save specs/plans under
  `docs/superpowers/` — ephemeral notes, gitignored. Don't commit them (skip the skill's
  "commit the spec" step); delete any that exist before merging.

### Stacked PRs

`gh stack` (`github/gh-stack`) is installed and is the canonical way to build a
series of PRs. Stack — rather than base on trunk — when any of these holds:

- the change depends on an open, unmerged PR
- one job is being split into several PRs (wave 1 → wave 2 → …)
- a stack on the same topic is already open → add to its top

State the base explicitly every time; never let it fall back to trunk silently.
`gh stack` needs a real git checkout: inside a `~/wkspace/worktree/...` jj workspace
it exits `✗ not a git repository`. From a workspace, open the PR with
`gh api repos/<owner>/<repo>/pulls -f base=<previous branch>`; run `gh stack`
(`view`/`add`/`push`/`submit`/`sync`/`merge`) from the colocated main checkout.

## What you write

Each artifact answers only the question its neighbours cannot. Restating a neighbour is
not just redundant — it becomes a lie the moment the neighbour changes. Apply this
unprompted to the ones you write unasked: commit, PR, comment, test, design doc, memo.

code=how · test=what (not how — tracing the implementation breaks on every refactor) ·
ci/cd=when+how · commit=why (not what — the diff shows it) · PR=what+why ·
comment=why-not (+why; not how — the line shows it) · api docs=what+when ·
readme=what+how-to-start · user guide=how+what-for · design doc=why+what-if ·
runbook=when+how · memo=what-next

- **PR / commit title**: gitmoji + conventional commit with **mandatory scope** —
  `:emoji: type(scope): description`. e.g. `:sparkles: feat(auth): add login`,
  `:bug: fix(api): timeout error`.
- Always end files with a trailing newline.
