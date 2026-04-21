---
name: jj
description: Jujutsu (jj) workflow — workspace setup, bookmark management, squash/edit patterns, trunk updates, and a quick reference for navigation, history editing, conflict resolution, and safety. Use for any jj task; /jj-history, /jj-safety, /jj-revsets, /jj-pr, /jj-submodules cover those areas in depth.
argument-hint: task description
---

# Jujutsu Workflow

Before starting any task, ensure a jj workspace exists.

## Workspace Rules

**Location**: `~/wkspace/worktree/<type>/<name>`

**Types**: `feature/`, `fix/`, `refactor/`, `docs/`, `test/`, `chore/`

## Auto-Create Workspace

This project defaults to the **squash workflow** (see "Squash vs Edit Workflow" below). The setup below leaves `@` as an empty scratch commit above a described parent, ready for squashing hunks down.

```bash
jj workspace add --name <name> ~/wkspace/worktree/<type>/<name>
cd ~/wkspace/worktree/<type>/<name>

# Describe the current empty @ with the initial message, then add scratch @ above it.
jj describe -m ":emoji: <type>(<scope>): <description>"
jj new   # empty scratch; edits happen here and get squashed down
```

For the edit workflow (commits accumulate directly on `@`), replace the two lines above with `jj new -m ":emoji: <type>(<scope>): <description>"` and edit in-place.

## Task: $ARGUMENTS

1. Check workspace: `jj status`
2. Create if needed via jj-workspace agent
3. Execute task
4. Describe changes: `jj describe -m "<message>"`

## Bookmark Naming Convention

**IMPORTANT**: Create conventional bookmarks BEFORE pushing.

Format: `<type>/<short-name>` (e.g., `feature/jj-rules`, `fix/auth-bug`)

**Anchor revision** depends on workflow:
- Squash workflow (project default): the described work is `@-`; `@` is empty scratch. Anchor `-r @-`.
- Edit workflow: the described work is `@` itself. Anchor `-r @`.

```bash
# Squash-workflow default (anchor the bookmark on the described parent, NOT the empty scratch):
jj bookmark create <type>/<name> -r @-

# Edit-workflow variant:
# jj bookmark create <type>/<name> -r @

# Push with the named bookmark
jj git push --bookmark <type>/<name>
```

**Never use** `jj git push --change @` alone - it creates ugly auto-generated names.

## Completing Work

Squash workflow (default):

```bash
# Fold the scratch @ hunks into the described parent
jj squash -m ":emoji: type(scope): description"

# Create the conventional bookmark on the described commit (@- is the parent
# since the described commit was @ before the squash moved hunks into it; after
# squash @ is the new empty scratch, and the described commit is @-)
jj bookmark create <type>/<name> -r @-

# Push
jj git push --bookmark <type>/<name>

# Create PR via gh api (see /jj-pr)
```

Edit workflow: replace `jj squash -m` with `jj describe -m` (to finalize the message on `@`) and anchor the bookmark on `-r @`.

## Updating Trunk from Upstream

Bookmarks do **not** auto-follow `@` as git branches do. Update trunk explicitly.

```bash
# Fetch latest
jj git fetch

# Start new work on top of updated trunk
jj new trunk()

# Or rebase current stack onto new trunk
jj rebase -d trunk()

# Rebase all local branches at once (all:roots() handles multiple heads)
jj rebase -s 'all:roots(trunk()..@)' -d 'trunk()'
```

## Bookmark: `create` vs `set`

- `jj bookmark create <name> -r @` — create a new bookmark (fails if it exists)
- `jj bookmark set <name> -r @` — move an existing bookmark (used when updating a PR)
- `jj bookmark set <name> -r @ --allow-backwards` — required to move a bookmark to an ancestor

## Squash vs Edit Workflow

Two idiomatic patterns for building up a commit. Pick intentionally.

**Squash workflow** (this project's default — mimics git's index):
1. `jj describe -m "..."` on an empty `@` to name the work
2. `jj new` to create a scratch commit above it
3. Edit files, then `jj squash` (or `jj squash -i`) to move hunks into the described parent
4. `@` stays empty; the parent accumulates the work

**Edit workflow** (commits emerge as you go):
1. `jj new -m "..."` — start work directly in `@`
2. Mid-task, insert a prerequisite: `jj new -B @ -m "prep"` creates a commit *before* `@`; descendants auto-rebase
3. `jj next --edit` to move back up the stack into the original commit

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
jj squash -m "msg"     # Combine with parent (always use -m!)
jj split               # Break commit apart
jj rebase -d trunk()   # Move ONLY @ to trunk (see "Updating Trunk" for whole-stack form)
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

### Editor Safety

**IMPORTANT**: Always pass `-m` to commands that open an editor (`squash`, `describe`, `split`, `commit`).
Without `-m`, jj spawns `$EDITOR` which hangs in non-interactive shells.

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
- `/jj-submodules` - Git submodules workarounds

