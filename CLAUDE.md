# Claude Code Instructions — Dotfiles Project

## Project Overview

NixOS dotfiles managed with Home Manager and Nix flakes. Includes configs for Hyprland, WezTerm, Neovim, Fish, Starship, Waybar, and more.

## Tech Stack

- **OS**: NixOS (WSL2)
- **Package Manager**: Nix flakes + Home Manager
- **Shell**: Fish
- **VCS**: Jujutsu (jj) — never use git commands directly
- **Editor**: Neovim

## Key Paths

- `flake.nix` / `flake.lock` — Nix flake definition
- `home.nix` — Home Manager entry point
- `modules/` — Nix module definitions
- `claude/` — Claude Code config (symlinked to `~/.claude/`)
- `scripts/` — Shell utility scripts
- `claude/agents/meta.md` — orchestrator agent definition (`claude --agent meta`)
- `claude/worker-spec.template.md` — mandatory worker spec fields
- `scripts/fleet` — background-agent fleet control (installed into the store, on PATH)

## Code Conventions

- Use Nix language for all configuration where possible
- Follow existing module patterns in `modules/`
- Shell scripts should target Fish syntax unless explicitly for bash
- Always add trailing newline to files

## Commands & Verification

- `home-manager switch --flake .` — Apply config (ALWAYS run after changes to verify)
- `nix flake check` — Validate flake (run before committing)
- `nix flake update` — Update all flake inputs

## Meta-Agent Orchestration

One project = one always-interactive orchestrator session; implementation happens in
disposable worker sessions, each in its own jj workspace.

```
claude --agent meta          # orchestrator: no Edit/Write, cannot drift into coding
fleet ls [CWD]               # inventory (scope to one project dir)
fleet out <id> [lines]       # worker output, read from the transcript
fleet gc [--dry-run]         # reap orphaned job state
fleet watch [interval]       # transition stream — feed to a Monitor, do not poll
fleet spawn --name N --dir PATH --spec FILE
```

Rules that exist because they were measured, not assumed:

- **Never run `claude logs <id>`.** It returns raw ANSI terminal frames — roughly 15k
  tokens for a one-line answer. Use `fleet out`, which reads the session transcript.
- **`claude rm` cannot remove an unreachable session.** It refuses with "the background
  service may be restarting" and the state leaks; one session sat `blocked` for six
  weeks. `fleet gc` removes the orphaned `~/.claude/jobs/<id>/` that `claude rm` will not.
- **Depth 2 only.** Orchestrator dispatches workers; workers may use their own `Agent`
  tool. Deeper chains over interdependent code are the documented worst case.
- **A spec without Boundary, Termination and Output is not dispatchable** — `fleet spawn`
  refuses it. Specification defects, not model mistakes, dominate multi-agent failures.

## Gotchas

- Nix errors can be cryptic — read the full trace, don't guess
- home-manager switch can fail silently on some options — check `systemctl --user status` if behavior seems wrong
- When adding new packages, check nixpkgs for the correct attribute path with `nix search`
