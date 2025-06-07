# Claude Code Instructions

## General Rules

- Always add new line after the final line for no diffs caused by EOF
- Before doing anything, analyze the request and generate productivity prompts to ensure efficient task completion
- After generating productivity prompts, you MUST ask whether to continue with the initial request or pick from your suggestions

## Git Workflow Rules

### Creating a New Worktree

**IMPORTANT: When starting any new task, you MUST create a new worktree from origin/develop:**

```bash
git worktree add -b <branch-name> ../<worktree-name> origin/develop
```

### Branch Naming Convention

Branch names MUST start with one of these prefixes:
- `feature/` - For new features
- `fix/` - For bug fixes
- `refactor/` - For code refactoring
- `docs/` - For documentation updates
- `test/` - For test additions or updates
- `chore/` - For maintenance tasks

### Completing the Workflow

**IMPORTANT: Whenever you change any files in this repository, you MUST complete the entire workflow including creating a pull request. This applies to ALL file changes, no matter how small.**

When your task is done, you MUST commit, push, and open a pull request from the new worktree branch:

```bash
# Make sure you're in the worktree directory
cd ../<worktree-name>

# Commit your changes
git add .
git commit -m "<commit message>"

# Push to remote
git push -u origin <branch-name>

# Create PR with all changes from the worktree branch
gh pr create --base develop --title "<PR title>" --body "<PR description>"
```

### PR Title Convention

Pull request titles MUST follow the gitmoji + conventional commit format:
- Start with a relevant gitmoji code (e.g.,:sparkles: for new features,:bug: for bug fixes,:recycle: for refactoring)
- Followed by conventional commit type with MANDATORY scope: `type(scope): description`
- **IMPORTANT: The scope is REQUIRED and must be included in parentheses**

Examples:
- `:sparkles: feat(auth): add user authentication feature`
- `:bug: fix(api): resolve timeout bug in endpoint`
- `:recycle: refactor(database): improve query performance`
- `:memo: docs(readme): update installation instructions`
- `:white_check_mark: test(user-service): add unit tests for validation`

### Cleaning Up After PR Merge

After your PR is merged, you MUST remove the worktree and update your main repository:

```bash
# Return to the main repository (use the appropriate path)
cd <main-repository-path>

# Remove the worktree
git worktree remove ../<worktree-name>

# Checkout to develop branch
git checkout develop

# Update to latest from origin
git pull origin develop
```
