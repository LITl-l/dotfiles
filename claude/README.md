# Claude Code Plugins Guide

This guide explains how to add plugins (local and remote), install skills, and configure marketplaces for Claude Code.

## Table of Contents

- [Plugin Types](#plugin-types)
- [Adding Official Plugins](#adding-official-plugins)
- [Adding Third-Party Plugins](#adding-third-party-plugins)
- [Adding Local Plugins](#adding-local-plugins)
- [Local Marketplace Setup](#local-marketplace-setup)
- [Installing Skills](#installing-skills)
- [Marketplace Configuration](#marketplace-configuration)
- [Known Limitations](#known-limitations)

## Plugin Types

Claude Code supports three plugin sources:

| Source | Description | Example |
|--------|-------------|---------|
| **Official** | Anthropic's official marketplace (`claude-plugins-official`) | `frontend-design`, `playwright` |
| **Third-party** | Community marketplaces (GitHub repos) | `mgrep@Mixedbread-Grep` |
| **Local** | Custom plugins from local directories | `jj-master@local` |

## Adding Official Plugins

Official plugins from `claude-plugins-official` are **installed automatically** - you just need to enable them in Claude Code.

### Enabling Official Plugins

1. Open Claude Code
2. Use the `/plugin` command or settings menu
3. Browse and enable plugins from the official marketplace

### Available Official Plugins

Some popular official plugins from `claude-plugins-official`:

- `frontend-design` - UI/UX design assistance
- `context7` - Context management
- `feature-dev` - Feature development workflows
- `playwright` - Browser automation testing
- `security-guidance` - Security best practices
- `hookify` - Hook management

## Adding Third-Party Plugins

For third-party marketplace plugins (community GitHub repos):

### Method 1: Using Claude Code CLI

```bash
# Add a marketplace from GitHub
claude plugin marketplace add owner/repo

# Install a plugin from it
claude plugin install plugin-name@marketplace-name
```

### Method 2: From Inside Claude Code

```
/plugin marketplace add owner/repo
/plugin install plugin-name@marketplace-name
```

## Adding Local Plugins

### Step 1: Create Marketplace Structure

```
marketplaces/
└── local/                           # Your marketplace name
    ├── .claude-plugin/
    │   └── marketplace.json         # Marketplace metadata
    └── plugins/
        └── your-plugin/             # Your plugin
            ├── .claude-plugin/
            │   └── plugin.json      # Plugin metadata
            ├── skills/              # Interactive commands
            │   └── your-skill/
            │       └── SKILL.md
            └── agents/              # Autonomous tasks
                └── your-agent.md
```

### Step 2: Create marketplace.json

```json
{
  "$schema": "https://anthropic.com/claude-code/marketplace.schema.json",
  "name": "local",
  "owner": {
    "name": "your-name"
  },
  "plugins": [
    {
      "name": "your-plugin",
      "description": "Description of your plugin",
      "source": "./plugins/your-plugin"
    }
  ]
}
```

### Step 3: Create plugin.json

```json
{
  "$schema": "https://json.schemastore.org/claude-plugin",
  "name": "your-plugin",
  "version": "1.0.0",
  "description": "Description of your plugin",
  "author": {
    "name": "your-name"
  }
}
```

### Step 4: Create a Skill (SKILL.md)

```markdown
---
name: your-skill
description: What your skill does
argument-hint: <description of expected input>
---

# Your Skill

Instructions for Claude when this skill is invoked.
```

### Step 5: Create an Agent (optional)

```markdown
---
tools:
  - Bash
  - Read
  - Glob
model: haiku
---

# Your Agent

Description of what this agent does autonomously.
```

### Step 6: Register via CLI

```bash
# Add the marketplace (from a separate terminal, not inside Claude Code)
claude plugin marketplace add ./path/to/marketplaces/local

# Install the plugin
claude plugin install your-plugin@local --scope user
```

## Local Marketplace Setup

This dotfiles repo includes a local marketplace with the `jj-master` plugin for Jujutsu workflow automation.

### Quick Setup

Run the setup script from a **separate terminal** (not inside Claude Code):

```bash
# Install marketplace and plugins
./claude/setup-marketplace.sh

# After modifying plugin files, update
./claude/setup-marketplace.sh --update

# Remove everything
./claude/setup-marketplace.sh --uninstall
```

### What It Does

The script uses the Claude Code CLI to:

1. `claude plugin marketplace add` — registers the local marketplace directory
2. `claude plugin install` — installs each plugin from the marketplace

No JSON merging, no symlinks, no jq — the CLI handles all state management.

### Adding a New Plugin

1. Create your plugin under `marketplaces/local/plugins/your-plugin/`
2. Add it to `marketplaces/local/.claude-plugin/marketplace.json`
3. Add `"your-plugin@local"` to the `PLUGINS` array in `setup-marketplace.sh`
4. Run `./claude/setup-marketplace.sh --update`

## Installing Skills

### Via CLI (Recommended)

Skills are automatically installed when you install a plugin:

```bash
claude plugin install <plugin-name>@<marketplace>
```

### Verifying Skill Installation

After installation, skills appear as `/` commands in Claude Code:

```
/your-skill <argument>
```

### Skill Discovery

Skills are auto-discovered from the plugin's `skills/` directory:

```
plugins/your-plugin/
└── skills/
    └── skill-name/
        └── SKILL.md    # Skill definition
```

Each `SKILL.md` must have front matter with:

- `name` - Command name (invoked as `/name`)
- `description` - What the skill does
- `argument-hint` - (optional) Input hint for users

## Marketplace Configuration

### Managing Marketplaces

```bash
# Add from local directory
claude plugin marketplace add ./my-marketplace

# Add from GitHub
claude plugin marketplace add owner/repo

# List registered marketplaces
claude plugin marketplace list

# Update a marketplace
claude plugin marketplace update marketplace-name

# Remove a marketplace
claude plugin marketplace remove marketplace-name
```

### Managing Plugins

```bash
# Install
claude plugin install plugin-name@marketplace --scope user

# Uninstall
claude plugin uninstall plugin-name@marketplace --scope user

# Disable without uninstalling (inside Claude Code)
/plugin disable plugin-name@marketplace

# Re-enable (inside Claude Code)
/plugin enable plugin-name@marketplace
```

### Validate a Marketplace

```bash
claude plugin validate ./path/to/marketplace
```

## Known Limitations

### Cannot Install Plugins from Within Claude Code

**Issue**: You cannot install plugins from inside a running Claude Code session.

**Workaround**: Run install commands from a separate terminal:

```bash
# In a separate terminal (not inside Claude Code)
claude plugin install your-plugin@local --scope user
```

Then restart Claude Code to see the new skills.

### Plugin Changes Require Reinstallation

After modifying plugin files (SKILL.md, agents, etc.), update via the setup script:

```bash
./claude/setup-marketplace.sh --update
```

## Quick Reference

| Task | Command |
|------|---------|
| Setup local marketplace | `./claude/setup-marketplace.sh` |
| Update after plugin changes | `./claude/setup-marketplace.sh --update` |
| Remove local marketplace | `./claude/setup-marketplace.sh --uninstall` |
| Add third-party marketplace | `claude plugin marketplace add owner/repo` |
| Install a plugin | `claude plugin install name@marketplace` |
| Uninstall a plugin | `claude plugin uninstall name@marketplace` |
| List marketplaces | `claude plugin marketplace list` |
| Use a skill | `/skill-name <argument>` in Claude Code |

## File Structure Reference

```
claude/
├── settings.json                    # Main Claude Code configuration
├── stop-hook-git-check.sh           # Git check hook
├── setup-marketplace.sh             # Marketplace setup script
├── README.md                        # This guide
└── marketplaces/
    └── local/                       # Local marketplace
        ├── .claude-plugin/
        │   └── marketplace.json
        └── plugins/
            └── jj-master/
                ├── .claude-plugin/
                │   └── plugin.json
                ├── skills/
                │   ├── jj/SKILL.md
                │   ├── jj-history/SKILL.md
                │   ├── jj-pr/SKILL.md
                │   ├── jj-revsets/SKILL.md
                │   ├── jj-safety/SKILL.md
                │   └── jj-submodules/SKILL.md
                └── agents/
                    ├── jj-github.md
                    └── jj-workspace.md
```
