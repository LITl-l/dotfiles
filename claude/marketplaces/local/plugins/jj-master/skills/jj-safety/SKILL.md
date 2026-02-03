---
name: jj-safety
description: Jujutsu safety operations - undo, redo, operation log
argument-hint: operation or empty for reference
disable-model-invocation: true
---

# Jujutsu Safety Operations

Every jj operation is recorded and reversible.

## Undo / Redo

```bash
# Undo last operation
jj undo

# Undo multiple times
jj undo && jj undo

# Redo after undo
jj redo
```

## Operation Log

Every repository action is logged with a unique operation ID.

```bash
# View operation history
jj op log

# View with more detail
jj op log --limit 20

# Show what changed in operation
jj op show <op-id>

# Diff between operations
jj op diff --from <op-id> --to <op-id>
```

## Restore to Previous State

```bash
# Restore entire repo to operation state
jj op restore <op-id>

# Preview what restore would do
jj op restore <op-id> --dry-run
```

## What Gets Logged

- Commits and amendments
- Rebases and squashes
- Bookmark changes
- Fetches and pushes
- Conflict resolutions
- Any state change

## Conflict Handling

Jujutsu handles conflicts differently - operations don't fail.

```bash
# Check for conflicts
jj status

# List conflicted files
jj resolve --list

# Interactive resolution
jj resolve <file>

# Use specific side
jj resolve --tool=:ours <file>
jj resolve --tool=:theirs <file>

# Resolve all with one side
jj resolve --tool=:ours
```

### Conflict Markers

```
<<<<<<< Conflict 1 of 1
%%%%%%% Changes from base to side #1
-old line
+side 1 change
+++++++ Contents of side #2
side 2 content
>>>>>>>
```

## Workspace Safety

```bash
# List all workspaces
jj workspace list

# Forget abandoned workspace
jj workspace forget <name>
```

## Recovery Scenarios

### Accidentally Abandoned Commit

```bash
# Find in operation log
jj op log | grep -A2 "abandon"

# Restore before the abandon
jj op restore <op-id-before-abandon>
```

### Bad Rebase

```bash
# Undo the rebase
jj undo

# Or find good state
jj op log
jj op restore <good-op-id>
```

### Lost Work

```bash
# Check operation log for last known good state
jj op log

# Show what repo looked like
jj op show <op-id>

# Restore if needed
jj op restore <op-id>
```

### Fetch Overwrote Local

```bash
# Undo the fetch
jj undo

# Or restore pre-fetch state
jj op log  # Find op before fetch
jj op restore <op-id>
```

## Immutable Commits

Some commits are protected from rewriting:

```bash
# Check what's immutable
jj log -r 'immutable()'

# Typically: trunk(), tags(), remote bookmarks
```

Configure in `.jj/repo/config.toml`:

```toml
[revset-aliases]
"immutable_heads()" = "trunk() | tags()"
```

## Arguments

$ARGUMENTS

If provided, help with the specific safety operation.
