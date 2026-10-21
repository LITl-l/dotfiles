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
- **A worker's *path* can be gated, not just its termination condition.** The `advisor`
  tool appears in no permissions list at all: `allow` carries nine non-Bash tool entries
  (`Edit`, `Glob`, `Grep`, `Read`, `Skill`, `WebFetch`, `WebSearch`, `Write`,
  `mcp__context7`) and `advisor` is not one of them, even though `advisorModel` is
  configured. A background worker that decides to consult it therefore blocks forever.
  No termination condition named it, and the done-condition rule above does not catch
  it: the gate was on a path the worker chose, not on a step the spec wrote down. The
  first worker died there before writing a line. Say "do not call `advisor`" outright in
  the spec, with the reason — a worker reaches for it exactly when the task looks
  consequential. And unlike the held-message case above, a real tool prompt never
  clears: if you sent no `SendMessage`, stop waiting and reap.
- **`od` matches no `allow` pattern.** The reading set in the bullet above is allowed and
  so is `diff` (`Bash(diff *)`), but `od` is absent, so the reflex "confirm the trailing
  byte with `od -c`" stalls the worker. `tail -c 1 <file> | wc -l` answers the same
  question and is allowed.
- **Staging under `wkspace` is necessary but not sufficient — and a few tool calls do
  not need a fleet worker at all.** The second worker, dispatched with `advisor`
  explicitly forbidden in its spec, blocked anyway: during an orientation *read* of
  paths that `permissions.additionalDirectories` already covers (`/home/nixos/wkspace`,
  `/home/nixos/.config/dotfiles`), again before writing anything. That cause is still
  unpinned, so it is a second data point that the `/tmp`-vs-`wkspace` mechanism above is
  incompletely understood. The rule that follows is about sizing, not paths: for a task
  of a few tool calls, dispatch an in-process `Agent` instead. It runs under this
  session's permissions, so a prompt reaches the human instead of deadlocking. The same
  spec that killed two background workers was executed by an in-process subagent in 19
  tool calls. Reserve `fleet` for work long enough that staying available matters.

## Gotchas

- Nix errors can be cryptic — read the full trace, don't guess
- home-manager switch can fail silently on some options — check `systemctl --user status` if behavior seems wrong
- When adding new packages, check nixpkgs for the correct attribute path with `nix search`
