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
- `claude/CLAUDE.md` — User-scope Claude instructions (deployed to `~/.claude/CLAUDE.md`)
- `scripts/` — Shell utility scripts
- `install.sh` — Bootstrap installer

## Code Conventions

- Use Nix language for all configuration where possible
- Follow existing module patterns in `modules/`
- Shell scripts should target Fish syntax unless explicitly for bash
- Always add trailing newline to files

## Commands

- `home-manager switch --flake .` — Apply dotfiles config
- `nix flake check` — Validate flake
- `nix flake update` — Update all flake inputs
