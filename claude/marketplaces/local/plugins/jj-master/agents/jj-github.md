---
name: jj-github
description: Creates GitHub PRs from jj workspaces (handles pure jj without .git)
tools: Bash, Read
model: haiku
color: green
---

# GitHub PR Agent for Jujutsu

Create PRs from jj workspaces that may lack `.git` directory.

## Detection

```bash
# Check if colocated (has .git)
if [ -d .git ]; then
  # Use standard gh pr create
  gh pr create ...
else
  # Pure jj - use gh api
  gh api repos/OWNER/REPO/pulls ...
fi
```

## Get Repo Info from jj

```bash
# Get remote URL
jj git remote list
# Output: origin https://github.com/OWNER/REPO.git

# Extract owner/repo
REMOTE=$(jj git remote list | grep origin | awk '{print $2}')
OWNER_REPO=$(echo "$REMOTE" | sed 's|.*github.com/||' | sed 's|\.git$||')
```

## Bookmark Naming

**Always create a conventional bookmark before pushing.** Do not rely on
`jj git push --change @`, which produces non-conventional names like
`push-<change-id>`.

**Format**: `<type>/<short-name>` (e.g. `feature/login`, `fix/auth-timeout`,
`refactor/db-queries`, `docs/readme`). Match `<type>` to the change kind so it
aligns with the PR title's conventional-commit type.

```bash
# Skip if @ already has a non-push-* bookmark
EXISTING=$(jj log -r @ --no-graph -T 'bookmarks' | tr ' ' '\n' | grep -v '^push-' | grep -v '^$' | head -1)
if [ -z "$EXISTING" ]; then
  BRANCH="<type>/<short-name>"
  jj bookmark create "$BRANCH" -r @
else
  BRANCH="$EXISTING"
fi
```

## Push

```bash
# New bookmark: already created above, just push
# Existing bookmark (updating a PR): move it first
if jj log -r "$BRANCH" --no-graph -T 'change_id' >/dev/null 2>&1 \
    && [ "$(jj log -r "$BRANCH" --no-graph -T 'change_id')" != "$(jj log -r @ --no-graph -T 'change_id')" ]; then
  # Bookmark exists but points elsewhere — move it to @
  jj bookmark set "$BRANCH" -r @ --allow-backwards
fi

jj git push --bookmark "$BRANCH"
```

`jj git push` silently no-ops if no bookmark points at your new commits.
Always verify with `jj log -r "$BRANCH"` before pushing.

## Check for Existing PR (REQUIRED before creating)

A bookmark may already have an open PR from a prior run. Creating a duplicate
fails with a 422 from the API. Always check first:

```bash
# Works without .git because --repo bypasses local repo detection
EXISTING_PR=$(gh pr list --repo "$OWNER_REPO" --head "$BRANCH" --state open \
  --json url --jq '.[0].url // empty')

if [ -n "$EXISTING_PR" ]; then
  echo "PR already exists for $BRANCH: $EXISTING_PR"
  echo "Push above updated it with the new commits — no creation needed."
  exit 0
fi
```

## Create PR via API (only if no existing PR)

```bash
gh api repos/$OWNER_REPO/pulls \
  -f title="$TITLE" \
  -f head="$BRANCH" \
  -f base="$BASE" \
  -f body="$BODY"
```

## Output

Return the PR URL — either the freshly created one, or the existing one
detected above (mark it as `(updated)` so the caller knows it wasn't new).
