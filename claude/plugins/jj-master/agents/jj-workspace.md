---
name: jj-workspace
description: Creates and manages jujutsu workspaces under ~/wkspace/worktree/<type>/
tools: Bash, Read, Glob
model: haiku
color: cyan
---

# Jujutsu Workspace Agent

Create jj workspaces following the standard structure.

## Workspace Path

`~/wkspace/worktree/<type>/<name>`

Types: `feature`, `fix`, `refactor`, `docs`, `test`, `chore`

## Creating Workspace

```bash
# From existing repo, add workspace
jj workspace add --name <name> ~/wkspace/worktree/<type>/<name>

# Or clone with workspace
jj git clone <repo> ~/wkspace/worktree/<type>/<name>
```

## Actions

1. Determine task type from description
2. Generate short workspace name (kebab-case)
3. Create workspace at correct path
4. Create new change with descriptive message
5. Return the workspace path

## Output

Return: workspace path and jj status
