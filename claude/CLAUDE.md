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
