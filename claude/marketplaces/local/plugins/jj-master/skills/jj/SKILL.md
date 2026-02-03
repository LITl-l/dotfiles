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

## Quick Reference

### Navigation & Viewing

```bash
jj status              # Current state
jj log                 # Commit graph
jj log -r 'main..@'    # Commits since main
jj diff                # Current changes
jj diff -r @-          # Parent's changes
```

### History Editing (see /jj-history)

```bash
jj edit <id>           # Edit past commit
jj squash              # Combine with parent
jj split               # Break commit apart
jj rebase -d trunk()   # Update to latest
jj absorb              # Smart change distribution
```

### Safety (see /jj-safety)

```bash
jj undo                # Reverse last operation
jj op log              # View all operations
jj op restore <id>     # Restore previous state
```

### Revsets (see /jj-revsets)

```bash
@                      # Current commit
@-                     # Parent
main..@                # Commits since main
mine()                 # My commits
trunk()                # Main branch
file("path")           # Commits touching file
```

### Conflict Resolution

```bash
jj status              # Shows conflicts
jj resolve --list      # List conflicted files
jj resolve <file>      # Interactive resolve
jj resolve --tool=:ours   # Use our version
jj resolve --tool=:theirs # Use their version
```

### Advanced Operations

```bash
jj bisect run '<cmd>'  # Find bug introduction
jj fix                 # Apply formatters
jj interdiff           # Compare commit versions
jj evolog              # Change evolution history
```

## Related Skills

- `/jj-pr` - Create GitHub PRs
- `/jj-revsets` - Revision selection language
- `/jj-history` - History editing operations
- `/jj-safety` - Undo, redo, recovery

