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
- `claude/worker-spec.template.md` — mandatory worker spec fields (fill it via
  `~/.claude/worker-spec.template.md`, which resolves from any project)
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
fleet ls                     # inventory — bare; do NOT pass a project dir
fleet out <id> [lines]       # worker output, read from the transcript
fleet gc [--dry-run]         # reap orphaned job state
fleet watch [interval]       # transition stream — feed to a Monitor, do not poll
fleet spawn --name N --dir PATH --spec FILE
```

Rules that exist because they were measured, not assumed:

- **Never run `claude logs <id>`.** It returns raw ANSI terminal frames — roughly 15k
  tokens for a one-line answer. Use `fleet out`, which reads the session transcript.
- **`claude rm <id>` is the normal reap; `fleet gc` is not.** `gc` only collects job
  state orphaned from the daemon's view — it deliberately skips finished sessions
  (`zombie_ids` snapshots with `--all`, so a `done` worker is not a zombie) and will
  report `no orphaned job state`. Use `fleet gc` for the case `claude rm` refuses: it
  cannot remove a session whose daemon socket is gone ("the background service may be
  restarting"), and that state leaks — one session sat `blocked` for six weeks.
- **Never scope `fleet ls` to the project dir.** Workers live in
  `~/wkspace/worktree/<type>/`, a sibling of the checkout, so `fleet ls <project-dir>`
  reports an empty fleet while workers are running. Run it bare.
- **Depth 2 only.** Orchestrator dispatches workers; workers may use their own `Agent`
  tool. Deeper chains over interdependent code are the documented worst case.
- **A spec without Boundary, Termination and Output is not dispatchable** — `fleet spawn`
  refuses it. Specification defects, not model mistakes, dominate multi-agent failures.
- **A worker cannot answer a permission prompt, so no gated action can be part of its
  termination condition.** One worker ran 37 tool calls clean — `nix flake check` exit 0,
  every file written — then blocked forever launching the PR, on a done-condition that
  was unsatisfiable by construction. Two cases prompt, and only the first is named in the
  config: a `permissions.ask` match (`jj git push`, `gh pr create`, `gh pr merge`,
  `git push`, `nix flake update`), and — the case that keeps surprising people — a
  command matching no `allow` pattern at all (`gh pr edit`, `cp`, `mv`). Workers
  terminate at "change described, result file written"; the orchestrator runs every gated
  step where a human can approve. Widening the allowlist is not the fix — the gate exists
  so a human approves pushes. (`home-manager switch` is allowlisted and does not prompt.)
- **Stage worker input under `/home/nixos/wkspace/`, never another session's `/tmp`
  scratchpad.** A worker handed input under `/tmp/claude-1000/` blocked on its FIRST tool
  call with a directory-access prompt; given the same files under
  `/home/nixos/wkspace/adhd-upstream/` it read them without issue. The mechanism is not
  fully pinned down — `wkspace` is what has been shown to work. Stage input there and
  name the path in the spec.
- **Reading is allowlisted; copying is not.** `cat`, `jq`, `grep`, `sed`, `find`, `head`,
  `tail`, `wc` and `mkdir` are allowed, but `cp`, `mv` and `rm` match no `allow` pattern
  (only the `rm -rf` forms are explicitly denied), so the reflex to snapshot a file
  before editing stalls the worker. Specs say: create with Write, read with `cat`.
- **A worker "blocked (permission prompt)" may just be holding your message.** `fleet
  spawn` defaults to `--permission-mode acceptEdits`, so a cross-session `SendMessage`
  from another mode is held for approval and is indistinguishable in `fleet watch` from a
  tool prompt. It clears on its own — do not panic-reap.

## Gotchas

- Nix errors can be cryptic — read the full trace, don't guess
- home-manager switch can fail silently on some options — check `systemctl --user status` if behavior seems wrong
- When adding new packages, check nixpkgs for the correct attribute path with `nix search`
