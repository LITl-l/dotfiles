---
name: jj-submodules
description: Working with git submodules in jujutsu - workarounds and limitations
argument-hint: submodule path or empty for reference
disable-model-invocation: true
---

# Jujutsu + Git Submodules

Submodules are **not yet supported** in jj. They won't appear in working copy,
but data is preserved. Here are workarounds until native support arrives.

## Current Limitations

| Feature | Status |
|---------|--------|
| View submodule contents | Not supported |
| Modify submodules via jj | Not supported |
| Submodule data preservation | Yes (not lost) |
| Colocated repo + submodules | Problematic |

## Workaround: Manual Submodule Setup

### 1. Find Target Commit

Get the commit hash the parent repo expects:

```bash
# Using git (works in colocated repos)
git ls-tree --object-only HEAD -- "<submodule-path>"

# Using jj (shows gitlink in patch)
jj log -r @ --limit 1 --patch --git <submodule-path>
```

### 2. Clone Submodule with jj

```bash
cd <submodule-parent-dir>
jj git clone <submodule-url> <submodule-name>
cd <submodule-name>
jj new <target-commit>
```

### 3. Colocated Alternative

For repos needing both jj and git submodule commands:

```bash
cd <submodule-parent-dir>
jj git clone --colocate <submodule-url> <submodule-name>
cd <submodule-name>
jj new <target-commit>
```

## Helper Function (zsh/bash)

Add to your shell config for easier updates:

```bash
# Update a jj-managed submodule to match parent repo
update-jj-submodule() {
  local SUB=$1
  if [[ -z "$SUB" ]]; then
    echo "Usage: update-jj-submodule <submodule-path>"
    return 1
  fi

  local COMMIT=$(git ls-tree --object-only HEAD -- "$SUB")
  if [[ -z "$COMMIT" ]]; then
    echo "No target commit found for $SUB"
    return 1
  fi

  echo "Updating $SUB to $COMMIT"
  jj git fetch --repository "$SUB" && \
  jj new "$COMMIT" --repository "$SUB"
}
```

Usage:

```bash
update-jj-submodule themes/ananke
```

## Common Scenarios

### Cloning Repo with Submodules

```bash
# Clone main repo
jj git clone --colocate <repo-url> <name>
cd <name>

# Initialize submodules via git
git submodule update --init --recursive

# Now submodules work via git, main repo via jj
```

### Adding New Submodule

Use git for submodule operations:

```bash
# Add via git
git submodule add <url> <path>

# jj will see the .gitmodules change
jj status
jj describe -m "feat: add submodule"
```

### Updating Submodule Reference

```bash
# Update via git
cd <submodule-path>
git fetch && git checkout <new-commit>
cd ..
git add <submodule-path>

# Commit via jj
jj describe -m "chore: update submodule"
```

## Known Issues

### Colocated Repo Rebase Errors

Rebasing with submodules may cause:
```
Internal error: Failed to check out commit
Failed to open file... for writing: File exists
```

**Workaround**: Use `jj undo`, then try operation without submodule changes.

### Divergent State

Mixing jj and git commands can cause confusion:

```bash
# Check for issues
jj status
git status

# If divergent, prefer jj state
jj git import
```

### Missing Submodule Contents

If submodule appears empty after clone:

```bash
# Ensure git submodules are initialized
git submodule update --init

# Or manually clone as jj repo (see above)
```

## Best Practices

1. **Use colocated repos** when submodules are required
2. **Manage submodules via git**, main repo via jj
3. **Avoid rebasing** commits that touch submodule references
4. **Keep submodule changes separate** from other commits
5. **Use helper functions** for repetitive submodule updates

## Future Support

Native submodule support is planned. Track progress:
- [Issue #494](https://github.com/jj-vcs/jj/issues/494) - Main tracking issue
- [Issue #1402](https://github.com/jj-vcs/jj/issues/1402) - Phase 1 milestone

## Arguments

$ARGUMENTS

If provided, help with specific submodule operation or troubleshooting.
