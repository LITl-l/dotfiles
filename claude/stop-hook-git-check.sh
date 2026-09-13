#!/bin/bash

# Read the JSON input from stdin
input=$(cat)

# Check if stop hook is already active (recursion prevention)
stop_hook_active=$(echo "$input" | jq -r '.stop_hook_active')
if [[ "$stop_hook_active" = "true" ]]; then
  exit 0
fi

# Detect jj repos — jj auto-snapshots, so use jj-native checks
# The jj checks below are ADVISORY: they print a reminder and exit 0.
#
# They used to exit 2, which blocks the assistant from stopping. That is wrong
# here because the check is workspace-scoped, not session-scoped: `jj diff` on @
# reports whatever is in the working copy with no notion of which session put it
# there, and jj auto-snapshots every write into @, so there is no staging area to
# signal deliberate authorship. Every session sharing a workspace — including
# dispatched background agents, which inherit user-scope hooks — inherited every
# other session's dirt as a stop condition and burned a turn investigating files
# it never wrote. The git fallback path below still blocks; it is single-session.
if jj workspace root >/dev/null 2>&1; then
  # Check if there are any changes not yet described (working copy has modifications)
  # In jj, the working copy is always a commit, so we check if the current change
  # has been described and if bookmarks are pushed
  # Check if working copy has actual file changes that haven't been described/pushed
  has_diff=$(jj diff --stat 2>/dev/null | grep -v '^0 files changed')
  if [[ -n "$has_diff" ]]; then
    current_desc=$(jj log -r @ --no-graph -T 'description' 2>/dev/null)
    if [[ -z "$current_desc" || "$current_desc" == "(no description set)" ]]; then
      echo "There are undescribed changes in the jj working copy. Please describe and push your changes."
      exit 0
    fi
  fi

  # Check for unpushed bookmarks on the current workspace's active stack only
  # (commits between trunk and @). Stale bookmarks from merged PRs live either
  # in ::trunk() (merged without squash) or on orphan parallel history
  # (squash-merged) — neither belongs to `trunk()..@`, so both are correctly
  # ignored here. They're cleanup candidates, not push candidates.
  unpushed=$(jj log -r 'trunk()..@ & bookmarks() ~ remote_bookmarks()' --no-graph -T 'change_id ++ "\n"' 2>/dev/null | head -5)
  if [[ -n "$unpushed" ]]; then
    echo "There are unpushed bookmarks. Please push your changes to the remote."
    exit 0
  fi

  exit 0
fi

# Fall back to git checks for non-jj repos
if ! git rev-parse --git-dir >/dev/null 2>&1; then
  exit 0
fi

# Check for uncommitted changes (both staged and unstaged)
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "There are uncommitted changes in the repository. Please commit and push these changes to the remote branch." >&2
  exit 2
fi

# Check for untracked files that might be important
untracked_files=$(git ls-files --others --exclude-standard)
if [[ -n "$untracked_files" ]]; then
  echo "There are untracked files in the repository. Please commit and push these changes to the remote branch." >&2
  exit 2
fi

current_branch=$(git branch --show-current)
if [[ -n "$current_branch" ]]; then
  if git rev-parse "origin/$current_branch" >/dev/null 2>&1; then
    # Branch exists on remote - compare against it
    unpushed=$(git rev-list "origin/$current_branch..HEAD" --count 2>/dev/null) || unpushed=0
    if [[ "$unpushed" -gt 0 ]]; then
      echo "There are $unpushed unpushed commit(s) on branch '$current_branch'. Please push these changes to the remote repository." >&2
      exit 2
    fi
  else
    # Branch doesn't exist on remote - compare against default branch
    unpushed=$(git rev-list "origin/HEAD..HEAD" --count 2>/dev/null) || unpushed=0
    if [[ "$unpushed" -gt 0 ]]; then
      echo "Branch '$current_branch' has $unpushed unpushed commit(s) and no remote branch. Please push these changes to the remote repository." >&2
      exit 2
    fi
  fi
fi

exit 0
