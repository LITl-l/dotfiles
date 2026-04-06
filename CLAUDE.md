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

## Code Conventions

- Use Nix language for all configuration where possible
- Follow existing module patterns in `modules/`
- Shell scripts should target Fish syntax unless explicitly for bash
- Always add trailing newline to files

## Commands & Verification

- `home-manager switch --flake .` — Apply config (ALWAYS run after changes to verify)
- `nix flake check` — Validate flake (run before committing)
- `nix flake update` — Update all flake inputs

## Gotchas

- Nix errors can be cryptic — read the full trace, don't guess
- home-manager switch can fail silently on some options — check `systemctl --user status` if behavior seems wrong
- When adding new packages, check nixpkgs for the correct attribute path with `nix search`
