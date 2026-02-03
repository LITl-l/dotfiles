---
name: jj-revsets
description: Jujutsu revset language reference for selecting revisions
argument-hint: revset query or empty for reference
disable-model-invocation: true
---

# Jujutsu Revsets Reference

A functional language for selecting sets of revisions.

## Symbols

| Symbol | Description |
|--------|-------------|
| `@` | Current working copy commit |
| `@-` | Parent of working copy |
| `@--` | Grandparent (chain `-` for ancestors) |
| `@+` | Child of working copy |
| `root()` | The root commit |
| `trunk()` | Main branch (main/master/trunk) |
| `<change-id>` | Specific change by ID |
| `<bookmark>` | Named bookmark |
| `<bookmark>@<remote>` | Remote-tracking bookmark |

## Operators

| Operator | Description | Example |
|----------|-------------|---------|
| `x-` | Parent(s) of x | `@-` |
| `x+` | Children of x | `main+` |
| `::x` | Ancestors of x (inclusive) | `::@` |
| `x::` | Descendants of x (inclusive) | `main::` |
| `x::y` | x to y (ancestors of y that descend from x) | `main::@` |
| `x..y` | Ancestors of y excluding ancestors of x | `main..@` |
| `x \| y` | Union (x or y) | `main \| feature` |
| `x & y` | Intersection (x and y) | `mine() & main::` |
| `~x` | Negation (not x) | `~merges()` |

## Functions

### Filtering

```bash
# By author/committer
author("pattern")
committer("pattern")

# By description
description("pattern")
description(glob:"feat:*")

# By file changes
file("path")
file(glob:"src/**/*.rs")

# By diff content
diff_contains("TODO")
diff_contains("pattern", "src/")

# Empty commits
empty()
```

### Commit Types

```bash
# Merge commits
merges()

# Commits with conflicts
conflicts()

# Tagged commits
tags()

# All bookmarks
bookmarks()
bookmarks("pattern")

# Remote bookmarks
remote_bookmarks()
```

### Ownership

```bash
# My commits (matches user.email)
mine()

# Mutable (can be rewritten)
mutable()

# Immutable (trunk, tags, pushed)
immutable()
```

### Navigation

```bash
# Parents/children at depth
parents(x, 3)      # Same as x---
children(x, 2)     # Same as x++

# Ancestors/descendants
ancestors(x)       # Same as ::x
descendants(x)     # Same as x::

# Heads (no children in set)
heads(x)

# Roots (no parents in set)
roots(x)
```

## String Patterns

| Pattern | Description |
|---------|-------------|
| `"text"` | Contains substring |
| `exact:"text"` | Exact match |
| `glob:"*.rs"` | Shell glob pattern |
| `regex:"^feat"` | Regular expression |

## Common Examples

```bash
# Show my recent work
jj log -r 'mine() & @::'

# Commits since main
jj log -r 'main..@'

# Find commits touching file
jj log -r 'file("src/main.rs")'

# Non-merge commits
jj log -r '~merges()'

# Commits with TODO added
jj log -r 'diff_contains("TODO")'

# WIP commits to clean up
jj log -r 'description(glob:"wip*")'

# Mutable commits I can edit
jj log -r 'mutable() & mine()'

# Commits ready to push
jj log -r 'remote_bookmarks()..@'
```

## Arguments

$ARGUMENTS

If provided, help construct a revset query for the described selection.
