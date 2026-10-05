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
- [How These Files Are Linked](#how-these-files-are-linked)
- [Known Limitations](#known-limitations)

## Plugin Types

Claude Code supports three plugin sources:

| Source | Description | Example |
|--------|-------------|---------|
| **Official** | Anthropic's official marketplace (`claude-plugins-official`) | `frontend-design`, `playwright` |
| **Third-party** | Community marketplaces (GitHub repos) | `mgrep@Mixedbread-Grep` |
| **Local** | Custom plugins from local directories | `jj-master@local` |

## Adding Official Plugins

Enabling an official plugin in `settings.json` (`enabledPlugins`) only **toggles**
it — it does not fetch it. `setup-marketplace.sh` closes that gap: it reads
`enabledPlugins` and installs every enabled entry belonging to a marketplace it
declares (`local`, `claude-plugins-official`). `enabledPlugins` is therefore the
single source of truth — there is no second list to keep in sync. Entries from
other marketplaces, such as the claude.ai org-synced `osi-deploy`, are managed
elsewhere and are skipped.

### Enabling Official Plugins

1. Add `"plugin@claude-plugins-official": true` to `enabledPlugins` in `settings.json`
2. Run `./claude/setup-marketplace.sh` (from a separate terminal, not inside Claude
   Code) — or just `home-manager switch`, whose activation runs the same script

### Available Official Plugins

Some popular official plugins from `claude-plugins-official`:

- `frontend-design` - UI/UX design assistance
- `context7` - Up-to-date docs lookup (disabled here — see [Disabled Plugins](#disabled-plugins))
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

# Refresh the marketplace sources, then install anything missing
./claude/setup-marketplace.sh --update

# Remove everything
./claude/setup-marketplace.sh --uninstall
```

### What It Does

The script uses the Claude Code CLI to:

1. read the enabled entries of `enabledPlugins` from `settings.json`, keeping only
   the marketplaces it declares (`local`, `claude-plugins-official`)
2. `claude plugin marketplace add` — register a marketplace, but only when
   something still has to be fetched from it **and**
   `claude plugin marketplace list --json` does not already know it
3. `claude plugin install` — install only what `claude plugin list` does not have

No JSON merging, no symlinks — the CLI handles all state management. It never
uninstalls or reinstalls, and every CLI call runs under `timeout` and cannot fail
the run, so `home.activation.setupClaudeCode` can call it on every
`home-manager switch` without tearing plugins down or hanging the switch.

`settings.json` is tracked, so the script must leave it byte-identical.
`claude plugin marketplace add <dir>` writes the directory it is handed into
`extraKnownMarketplaces.<name>.source.path` there — a machine-specific absolute
path. Three things keep that out of the repo: the already-registered check above
skips the `add` entirely; `home.activation.setupClaudeCode` passes
`CLAUDE_MARKETPLACE_PATH` and `CLAUDE_SETTINGS_FILE` as absolute paths into the
canonical checkout, so a run out of a jj workspace cannot bake in a path that
disappears; and if an `add` does happen anyway, the key is stripped again by an
atomic rewrite that is refused unless the result is exactly the same document
minus that one key.

A deadline hit (`timeout` exit 124/137) also stops the remaining CLI calls rather
than paying one deadline per plugin, and the activation entry puts a single outer
`timeout` around the whole script.

### Adding a New Plugin

1. Create your plugin under `marketplaces/local/plugins/your-plugin/`
2. Add it to `marketplaces/local/.claude-plugin/marketplace.json`
3. Enable it in `settings.json`'s `enabledPlugins` (`"your-plugin@local": true`)
4. Run `./claude/setup-marketplace.sh`

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

## MCP Servers

MCP servers are configured separately from plugins: they live in `~/.claude.json`
at **user scope** and are managed with the `claude mcp` CLI (not `settings.json`).
`setup-marketplace.sh` registers them idempotently, so a fresh machine reproduces
them on the next `home-manager switch`.

### context7 (remote HTTP)

Up-to-date library documentation lookup. We use Context7's **remote** MCP at
`https://mcp.context7.com/mcp` instead of the official `context7` plugin, which
bundles a stdio MCP run via `npx -y @upstash/context7-mcp`. That npx server
targets `context7.com`, which is unreachable from this network (TCP `:443` times
out), so it hangs. The remote host responds and spawns no local Node process.

- Works keyless at a lower rate limit.
- For higher limits, `export CONTEXT7_API_KEY=...` before running
  `./claude/setup-marketplace.sh --update`. The key is sent as a request header
  and is **never** written to this repo.
- Tools: `resolve-library-id`, `query-docs` — pre-approved in `settings.json`
  via `permissions.allow` → `mcp__context7`.

## Disabled Plugins

These official plugins are set to `false` in `settings.json`:

- `context7` — replaced by the remote MCP above (see [MCP Servers](#mcp-servers)).
- `security-guidance` — its hooks (SessionStart / UserPromptSubmit / PostToolUse /
  Stop) shell out to Python via `sg-python.sh`, and there is no `python3` in this
  environment (language runtimes are not installed globally). With no interpreter,
  every turn printed *"no working Python 3 interpreter found"*. On-demand security
  review remains available via the built-in `/security-review`.

## How These Files Are Linked

`modules/claude-code.nix` links this directory into `~/.claude/` in two different
ways, and which one a file gets depends on whether Claude Code writes it:

| File | Linked by | Why |
|------|-----------|-----|
| Claude **writes** it — `settings.json`, `CLAUDE.md` | `ln -sfnT` in `home.activation.linkClaudeWritableConfig` | one hop, straight into the repo |
| Claude only **reads** it — hook scripts, `agents/meta.md`, `worker-spec.template.md` | `home.file` + `mkOutOfStoreSymlink` | declarative; an edit is live without a rebuild |

`home.file`'s out-of-store symlink is always a two-hop chain: `~/.claude/x` → the
generation's `/nix/store/…-home-manager-files/.claude/x` → this repo. Claude Code
rewrites `settings.json` and `CLAUDE.md` *atomically* — temp file in the target's
directory, then `rename()` — and it resolves only the first hop, so it tries to
create the temp file inside the read-only store directory and fails with `EACCES`.
A plain open-and-write survives the chain, which is why hand edits reached the repo
while `/auto-mode-setup` could not write at all. The activation link collapses the
chain to a single hop.

The relink refuses to guess when it finds something other than its own link:

- A **regular file** at `~/.claude/settings.json` (an interrupted atomic write, or
  a `~/.claude` restored by anything that dereferences symlinks — `cp -r`,
  `rsync -L`, cloud sync) is moved aside to `settings.json.hm-orphan.<epoch>` with
  a warning, and the link is recreated. It is never copied back over the tracked
  file: a truncated or stale copy would silently replace hand-maintained config.
  Reconcile the orphan by hand and delete it.
- A **directory** there makes `ln -sfnT` fail, which is reported as a warning. The
  `-T` matters: plain `ln -sfn` would create the link *inside* the directory and
  exit 0, leaving a broken config that looks like a clean switch.
- A path that **already resolves to the repo file** is left alone, so a `~/.claude`
  that is itself a symlink into the checkout is not mangled.

None of these abort the switch, which activation's `set -eu -o pipefail` would
otherwise do.

Nothing under `~/.claude/plugins/` is linked: only the *intent* (`enabledPlugins`)
is tracked. `known_marketplaces.json` and `installed_plugins.json` are CLI-written
and hold absolute paths and git SHAs, so tracking them would reintroduce the same
write bug and break machine portability.

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

`setup-marketplace.sh` deliberately never reinstalls — doing so tore down working
plugins on every `home-manager switch`. After editing a local plugin's files,
refresh the marketplace source, and reinstall that one plugin by hand if the change
does not show up:

```bash
./claude/setup-marketplace.sh --update
claude plugin uninstall your-plugin@local --scope user
claude plugin install your-plugin@local --scope user
```

## Quick Reference

| Task | Command |
|------|---------|
| Install the enabled plugins | `./claude/setup-marketplace.sh` |
| Refresh marketplaces, then install | `./claude/setup-marketplace.sh --update` |
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
