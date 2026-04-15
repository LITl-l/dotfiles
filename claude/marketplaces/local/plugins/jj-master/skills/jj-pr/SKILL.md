---
name: jj-pr
description: Create GitHub PR from jj workspace (works without .git)
argument-hint: PR title or empty for auto-generate
disable-model-invocation: true
---

# Create PR from jj Workspace

## Steps

1. **Verify changes exist**
   ```bash
   jj status
   jj log -r @
   ```

2. **Create conventional bookmark** (if not exists)
   ```bash
   # Format: <type>/<short-name>
   jj bookmark create feature/my-feature -r @
   ```

3. **Push with named bookmark**
   ```bash
   jj git push --bookmark <type>/<name>
   ```

4. **Get repo info**
   ```bash
   REMOTE=$(jj git remote list | grep origin | awk '{print $2}')
   OWNER_REPO=$(echo "$REMOTE" | sed 's|.*github.com[:/]||' | sed 's|\.git$||')
   ```

5. **Create PR via API**
   ```bash
   gh api repos/$OWNER_REPO/pulls \
     -f title="$TITLE" \
     -f head="<type>/<name>" \
     -f base="main" \
     -f body="$BODY"
   ```

## Bookmark Naming

**Format**: `<type>/<short-name>`

Examples:
- `feature/jj-rules`
- `fix/auth-timeout`
- `refactor/db-queries`
- `docs/readme-update`

## Updating an Existing PR

When pushing more commits to an already-open PR, **move** the bookmark rather
than creating a new one:

```bash
# After new changes, move the bookmark to the new tip
jj bookmark set <type>/<name> -r @

# If moving to an ancestor (e.g. dropped a commit):
jj bookmark set <type>/<name> -r @ --allow-backwards

# Re-push (no --bookmark flag needed if only one tracked bookmark moved)
jj git push --bookmark <type>/<name>
```

`jj git push` silently pushes nothing if the bookmark is not pointing at `@`.
Always verify with `jj log` before pushing.

## PR Title Format

Follow gitmoji + conventional commit with **mandatory scope**:
- `:sparkles: feat(scope): description`
- `:bug: fix(scope): description`
- `:recycle: refactor(scope): description`

## Arguments

$ARGUMENTS

If empty, generate title from `jj log -r @ -T description`.
