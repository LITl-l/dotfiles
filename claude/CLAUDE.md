# Claude Code Instructions

## General Rules

- Always add new line after the final line for no diffs caused by EOF
- Before doing anything, analyze the request and generate productivity prompts to ensure efficient task completion
- After generating productivity prompts, you MUST ask whether to continue with the initial request or pick from your suggestions

## Version Control: Jujutsu (jj)

This environment uses **Jujutsu (jj)**, not git. **Never use git commands directly.**

Use the `jj-master` plugin skills and agents automatically as needed:
- `/jj` — Core workflow and workspace creation
- `/jj-pr` — Create GitHub PRs
- `/jj-history` — Squash, split, rebase, absorb
- `/jj-revsets` — Revision selection queries
- `/jj-safety` — Undo, redo, recovery
- `jj-workspace` agent — Creates workspaces under `~/wkspace/worktree/<type>/`
- `jj-github` agent — Creates PRs from jj repos

### Workflow

- **New task**: Use `jj-workspace` agent to create a workspace
- **Already in workspace**: Check with `jj workspace root` — skip creation if already in one
- **Completing work**: Use `/jj-pr` or `jj-github` agent to push and create a PR
- **IMPORTANT**: Whenever you change any files, you MUST complete the entire workflow including creating a pull request

### Gotchas

- jj auto-snapshots the working copy on every command — no need to manually stage or save
- Conflicts are stored in commits, not blocking — resolve them, don't panic
- Use `/jj-safety` for undo/recovery instead of trying manual fixes
- Bookmarks are jj's equivalent of git branches — use `/jj` skill for naming conventions

### PR Title Convention

Gitmoji + conventional commit with **mandatory scope**: `:emoji: type(scope): description`

Examples: `:sparkles: feat(auth): add login`, `:bug: fix(api): timeout error`, `:recycle: refactor(db): query perf`
