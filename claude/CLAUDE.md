# Claude Code Instructions

## Thinking & Quality

- Default to thorough analysis. For complex tasks, use plan mode first.
- IMPORTANT: Always read relevant files before editing. Never modify code you haven't read in this session.
- Verify your work: run tests, check builds, compare outputs. Never claim completion without verification.
- Fix root causes, not symptoms — no temporary workarounds.
- Make minimal changes — only modify what's necessary.
- When compacting, always preserve: modified file list, test commands, and current plan state.

## Context Management

- /clear between unrelated tasks
- Use subagents for codebase exploration to avoid bloating main context
- For large investigations, scope narrowly — don't read everything

## Research & Search

Use WebSearch liberally — prefer an extra query over relying on stale knowledge. When investigating options, architecture, or "what's current," widen the lens deliberately instead of searching the first phrase that comes to mind.

Checklist for broadening a search:

1. **Raise the abstraction level.** Search the underlying problem, not the assumed tool. ×「durable execution tools 2026」→ ○「how to run long-running business processes without adding infrastructure 2026」
2. **Check recent papers.** arxiv / OpenReview, scoped to within the last year.
3. **Negate the default premise.** "Do it all in Postgres", "WASM instead of X", "options that don't use RAG" — invert the assumption and search that.
4. **Mix in regional / regulatory context.** 「日本」「sovereign」「on-prem」「airgapped」when relevant.
5. **GitHub trending, filtered.** language × last 3 months × star growth.
6. **Research-lab / product-group OSS.** AISI / Apple / Anthropic / DeepMind / NTT研 / 産総研.
7. **"Death of X" / "why we stopped using X" postmortems.** Withdrawal writeups carry more signal than adoption writeups.

## Version Control: Jujutsu (jj)

This environment uses **Jujutsu (jj)**, not git. **Never use git commands directly.**

Use the `jj-master` plugin skills and agents automatically as needed:

- `/jj` — Core workflow and workspace creation
- `/jj-pr` — Create GitHub PRs
- `jj-workspace` agent — Creates workspaces under `~/wkspace/worktree/<type>/`
- `jj-github` agent — Creates PRs from jj repos

### Editor Safety

- **Always pass `-m`** to `jj squash`, `jj describe`, and any command that opens an editor
- Without `-m`, jj spawns `$EDITOR` (nvim) which hangs forever in non-interactive shells

### Workflow

- **New task**: Use `jj-workspace` agent to create a workspace
- **Already in workspace**: Check with `jj workspace root` — skip creation if already in one
- **Completing work**: Use `/jj-pr` or `jj-github` agent to push and create a PR
- IMPORTANT: Whenever you change any files, you MUST complete the entire workflow including creating a PR

### PR Title Convention

Gitmoji + conventional commit with **mandatory scope**: `:emoji: type(scope): description`

Examples: `:sparkles: feat(auth): add login`, `:bug: fix(api): timeout error`, `:recycle: refactor(db): query perf`

## General Rules

- Always add trailing newline to files
