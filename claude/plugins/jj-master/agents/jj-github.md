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

## Get Branch Name

After `jj git push --change @`, jj creates a bookmark like `push-<change-id>`.

```bash
# Get current change's bookmark
jj log -r @ --no-graph -T 'bookmarks'
```

## Create PR via API

```bash
gh api repos/$OWNER_REPO/pulls \
  -f title="$TITLE" \
  -f head="$BRANCH" \
  -f base="$BASE" \
  -f body="$BODY"
```

## Output

Return the PR URL from the API response.
