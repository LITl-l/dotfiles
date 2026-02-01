---
name: jj
description: Jujutsu workspace workflow - auto-creates workspace before tasks
argument-hint: task description
---

# Jujutsu Workflow

Before starting any task, ensure a jj workspace exists.

## Workspace Rules

**Location**: `~/wkspace/worktree/<type>/<name>`

**Types**: `feature/`, `fix/`, `refactor/`, `docs/`, `test/`, `chore/`

## Auto-Create Workspace

```bash
jj workspace add --name <name> ~/wkspace/worktree/<type>/<name>
cd ~/wkspace/worktree/<type>/<name>
jj new -m "<type>: <description>"
```

## Task: $ARGUMENTS

1. Check workspace: `jj status`
2. Create if needed via jj-workspace agent
3. Execute task
4. Describe changes: `jj describe -m "<message>"`

## Bookmark Naming Convention

**IMPORTANT**: Create conventional bookmarks BEFORE pushing.

Format: `<type>/<short-name>` (e.g., `feature/jj-rules`, `fix/auth-bug`)

```bash
# Create bookmark with conventional name
jj bookmark create <type>/<name> -r @

# Push with the named bookmark
jj git push --bookmark <type>/<name>
```

**Never use** `jj git push --change @` alone - it creates ugly auto-generated names.

## Completing Work

```bash
# Describe changes
jj describe -m ":emoji: type(scope): description"

# Create conventional bookmark
jj bookmark create <type>/<name> -r @

# Push
jj git push --bookmark <type>/<name>

# Create PR via gh api (see /jj-pr)
```
