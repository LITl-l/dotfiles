# Claude Code Plugins Guide

This guide explains how to add plugins (local and remote), install skills, and configure marketplaces for Claude Code.

## Table of Contents

- [Plugin Types](#plugin-types)
- [Adding Official Plugins](#adding-official-plugins)
- [Adding Third-Party Plugins](#adding-third-party-plugins)
- [Adding Local Plugins](#adding-local-plugins)
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
2. Use the `/plugins` command or settings menu
3. Browse and enable plugins from the official marketplace

Official plugins include built-in skills that work immediately after enabling.

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
# Install from third-party marketplace
claude plugin install <plugin-name>@<marketplace-name>

# Example
claude plugin install mgrep@Mixedbread-Grep
```

### Method 2: Manual Configuration in settings.json

Add the plugin to `enabledPlugins` in `~/.claude/settings.json`:

```json
{
  "enabledPlugins": [
    "mgrep@Mixedbread-Grep"
  ]
}
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
  "$schema": "https://json.schemastore.org/claude-plugin-marketplace",
  "name": "local",
  "owner": "your-name",
  "plugins": [
    "./plugins/your-plugin"
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

## Steps

1. Do something
2. Do something else

## Example Commands

\`\`\`bash
echo "example command"
\`\`\`
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

## Instructions

1. Step one
2. Step two
```

### Step 6: Register the Marketplace

Add to `settings.json`:

```json
{
  "marketplaces": {
    "local": {
      "source": "~/.claude/plugins/marketplaces/local",
      "type": "directory"
    }
  }
}
```

### Step 7: Install the Plugin

```bash
# Uninstall first if exists (ignore errors)
claude plugin uninstall your-plugin@local --scope user 2>/dev/null || true

# Install the plugin
claude plugin install your-plugin@local --scope user
```

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

### Local Directory Marketplace

```json
{
  "marketplaces": {
    "local": {
      "source": "~/.claude/plugins/marketplaces/local",
      "type": "directory"
    }
  }
}
```

### GitHub Repository Marketplace

```json
{
  "marketplaces": {
    "my-marketplace": {
      "source": "github:username/repo",
      "type": "git"
    }
  }
}
```

## Known Limitations

### Cannot Install Skills from Within Claude Code

**Issue**: While you can add a marketplace configuration within Claude Code, you cannot install skills/plugins from inside a Claude Code session.

**Reason**: Plugin installation requires the `claude plugin install` CLI command, which modifies Claude Code's internal state. Running this command from within Claude Code creates a conflict.

**Workaround**: Install plugins from a separate terminal session:

```bash
# In a separate terminal (not inside Claude Code)
claude plugin install your-plugin@local --scope user
```

Then restart Claude Code to see the new skills.

### Plugin Changes Require Reinstallation

After modifying plugin files (SKILL.md, agents, etc.), you must reinstall:

```bash
claude plugin uninstall your-plugin@local --scope user 2>/dev/null || true
claude plugin install your-plugin@local --scope user
```

### Nix/Home Manager Integration

If using Nix with Home Manager, plugins can be automatically registered during activation:

```nix
# In your Nix module
home.activation.installClaudePlugins = lib.hm.dag.entryAfter ["writeBoundary"] ''
  run ${pkgs.claude-code}/bin/claude plugin uninstall your-plugin@local --scope user 2>/dev/null || true
  run ${pkgs.claude-code}/bin/claude plugin install your-plugin@local --scope user 2>/dev/null || true
'';
```

## Quick Reference

| Task | Command |
|------|---------|
| Enable official plugin | Use `/plugins` command in Claude Code |
| Install third-party plugin | `claude plugin install <name>@<marketplace>` |
| Install local plugin | `claude plugin install <name>@local --scope user` |
| Uninstall plugin | `claude plugin uninstall <name>@<marketplace>` |
| List installed plugins | Check `enabledPlugins` in settings.json |
| Use a skill | `/skill-name <argument>` in Claude Code |

## File Structure Reference

```
~/.claude/
├── settings.json                    # Main configuration
└── plugins/
    └── marketplaces/
        └── local/                   # Local marketplace
            ├── .claude-plugin/
            │   └── marketplace.json
            └── plugins/
                └── plugin-name/
                    ├── .claude-plugin/
                    │   └── plugin.json
                    ├── skills/
                    │   └── skill-name/
                    │       └── SKILL.md
                    └── agents/
                        └── agent-name.md
```
