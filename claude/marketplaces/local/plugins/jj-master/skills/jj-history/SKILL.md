---
name: jj-history
description: Jujutsu history editing - squash, split, rebase, absorb
argument-hint: operation type or empty for reference
disable-model-invocation: true
---

# Jujutsu History Editing

Safe, powerful history manipulation with automatic rebasing.

## Key Concept

When you modify any commit, all descendants are **automatically rebased**.
No need for `git rebase --continue` - jj handles it.

## Squash (Combine Commits)

```bash
# Squash current into parent
jj squash

# Squash specific commit into its parent
jj squash -r <change-id>

# Squash into specific destination
jj squash --into <dest>

# Squash only specific files
jj squash <file1> <file2>

# Interactive squash (select hunks)
jj squash -i
```

## Split (Break Apart Commits)

```bash
# Split current commit interactively
jj split

# Split specific commit
jj split -r <change-id>

# Split by files (non-interactive)
jj split <file1> -- <file2>
```

## Rebase (Move Commits)

```bash
# Rebase current onto destination
jj rebase -d <dest>

# Rebase specific revision
jj rebase -r <rev> -d <dest>

# Rebase revision and descendants
jj rebase -s <source> -d <dest>

# Rebase onto multiple parents (merge)
jj rebase -d <parent1> -d <parent2>

# Rebase onto trunk (update to latest)
jj rebase -d trunk()
```

## Edit (Modify Past Commits)

```bash
# Edit a specific commit
jj edit <change-id>

# Make changes to files...
# Changes auto-amend into that commit
# Descendants auto-rebase

# Return to latest
jj edit @
# or
jj new
```

## Absorb (Smart Distribution)

Automatically distribute working changes into appropriate commits.

```bash
# Absorb current changes into stack
jj absorb

# Preview what would be absorbed
jj absorb --dry-run

# Absorb from specific revision
jj absorb -r <rev>
```

## Diffedit (Interactive Editing)

```bash
# Edit diff of current commit
jj diffedit

# Edit diff of specific commit
jj diffedit -r <change-id>
```

## Abandon (Discard Commits)

```bash
# Abandon current commit
jj abandon

# Abandon specific commit
jj abandon <change-id>

# Abandon range
jj abandon -r 'main..@'
```

## Duplicate (Copy Commits)

```bash
# Duplicate a commit
jj duplicate <change-id>

# Duplicate to specific destination
jj duplicate <change-id> -d <dest>
```

## Describe (Change Message)

```bash
# Change current commit message
jj describe -m "new message"

# Change specific commit message
jj describe -r <change-id> -m "new message"

# Open editor for message
jj describe
```

## Common Workflows

### Clean Up WIP Commits

```bash
# Squash all WIP into one
jj squash -r 'description(glob:"wip*")' --into @-
```

### Reorder Commits

```bash
# Move commit to different position
jj rebase -r <commit> -d <new-parent>
```

### Insert Commit in Middle

```bash
# Create new commit after specific one
jj new <parent>
# Make changes
jj rebase -s <following> -d @
```

### Fix Typo in Old Commit

```bash
jj edit <change-id>
# Fix the typo
jj new  # Return to tip
```

## Arguments

$ARGUMENTS

If provided, guide through the specific history operation.
