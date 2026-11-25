# Claude Code Instructions — Dotfiles Project

## Project Overview

NixOS dotfiles managed with Home Manager and Nix flakes. Includes configs for Hyprland, WezTerm, Neovim, Fish, Starship, Waybar, and more.

## Tech Stack

- **OS**: NixOS (WSL2)
- **Package Manager**: Nix flakes + Home Manager
- **Shell**: Fish
- **VCS**: Jujutsu (jj) — no direct mutating git; read-only git is fine
- **Editor**: Neovim

## Key Paths

This repo is `LITl-l/dotfiles` on GitHub — use that for every `gh` command.

- `flake.nix` / `flake.lock` — Nix flake definition
- `home.nix` — Home Manager entry point
- `modules/` — Nix module definitions
- `claude/` — Claude Code config (symlinked to `~/.claude/`)
- `scripts/` — Shell utility scripts
- `claude/agents/meta.md` — orchestrator agent definition (`claude --agent meta`)
- `claude/worker-spec.template.md` — mandatory worker spec fields (fill it via
  `~/.claude/worker-spec.template.md`, which resolves from any project)
- `scripts/fleet` — background-agent fleet control (installed into the store, on PATH)
- `scripts/rework-rate` — how much of what this repo ships gets rewritten days later.
  This repo fixes forward and never reverts, so revert rate reads 0% regardless; rework
  is the signal that has resolution here. Derived from git on demand, never stored. Run
  it bare for the defaults, or `--rev A..B` for one range; `Rework Report` CI prints it
  on every push to main and gates nothing.

## Code Conventions

- Use Nix language for all configuration where possible
- Follow existing module patterns in `modules/`
- Shell scripts should target Fish syntax unless explicitly for bash
- Always add trailing newline to files

## Commands & Verification

- `home-manager switch --flake .#nixos@wsl` — Apply the config; this is the verification
  step for a config change. Bare `--flake .` fails — the target must be named
- `nix flake check` — Validate flake (run before committing)
- `nix flake update` — Update all flake inputs

## Meta-Agent Orchestration

For parallel or long work, one project has one always-interactive orchestrator session,
and the implementation happens in disposable worker sessions, each in its own jj
workspace. A task one worker would finish in minutes goes to a plain `claude` session
instead. The criterion and the 93-minute measurement behind it are in
`claude/agents/meta.md` under "When not to be used".

```
claude --agent meta          # orchestrator: no Edit/Write, cannot drift into coding
fleet ls                     # inventory — bare; do NOT pass a project dir
fleet out <id> [lines]       # worker output, read from the transcript
fleet why <id>               # why a session is parked: state, detail, needs, respawn
fleet gc [--dry-run]         # reap orphaned job state; report leaked `stopped` state
fleet gc --stopped           # also remove that leaked state (never a `done` session)
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
  restarting"), and that state leaks — one session sat `blocked` for six weeks. A
  `stopped` session leaks the same way while looking accounted for: nine job dirs dated
  Oct 16 – Nov 2 sat in `~/.claude/jobs/` while `fleet gc` reported `no orphaned job
  state`, because `claude agents --json --all` still lists them, so nothing looked
  orphaned. `fleet gc` now reports those separately and removes them only under
  `--stopped`, since each still carries a `resumeSessionId`.
- **Ask the state file why a session is parked.** `fleet why <id>` prints `state`,
  `detail`, `needs`, `respawnFlags` and `resumeSessionId` from
  `~/.claude/jobs/<id>/state.json`; the six-week `blocked` session went unnoticed because
  nothing surfaced that. Do not `cat` the file — `intent` holds the worker's entire spec.
- **`claude agents --all` needs `--json` added, not `--all` dropped — confirm a reap with
  `claude agents --json --all`.** It is the *absence of `--json`* that requires a TTY, not
  `--all`. Measured both ways from a non-interactive session: `claude agents --all` exits
  1 with an empty stdout, the message `'claude agents' requires an interactive terminal
  (stdout is not a TTY)` going to stderr — so a stdout-reading check sees nothing while an
  exit-code check fails loudly; `claude agents --json --all` exits 0 and returns the full
  inventory (10 rows here, 9 of them `stopped`). Keep `--all`: it is what surfaces
  `stopped` and zombie rows, and dropping it makes the check pass the moment the session
  stops being live — the same vacuous pass in a new costume. `fleet ls` is no substitute
  for the same reason: it lists only live sessions, so a finished worker drops out of it
  before any reap.
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
  was unsatisfiable by construction. Three cases prompt, and only the first is named in
  the config: a `permissions.ask` match (`jj git push`, `gh pr create`, `gh pr merge`,
  `git push`, `nix flake update`); a command matching no `allow` pattern at all
  (`gh pr edit`; under `acceptEdits` a `cp` inside the cwd ran unprompted, observed
  once); and — the case that keeps surprising people — an allowlisted command whose path
  argument lies outside the session's directories (cwd + `additionalDirectories`), e.g.
  `find /home/nixos/.cache` (measured 2026-11-20, see the staging bullet below). Workers
  terminate at "change described, result file written"; the orchestrator runs every gated
  step where a human can approve. Widening the allowlist is not the fix — the gate exists
  so a human approves pushes. (`home-manager switch` is allowlisted and does not prompt.)
- **Stage worker input under `/home/nixos/wkspace/`, never another session's `/tmp`
  scratchpad.** A worker handed input under `/tmp/claude-1000/` blocked on its FIRST tool
  call with a directory-access prompt; given the same files under
  `/home/nixos/wkspace/adhd-upstream/` it read them without issue. The mechanism is not
  fully pinned down — `wkspace` is what has been shown to work. Stage input there and
  name the path in the spec.
- **A worker "blocked (permission prompt)" may just be holding your message.** `fleet
  spawn` defaults to `--permission-mode acceptEdits`, so a cross-session `SendMessage`
  from another mode is held for approval and is indistinguishable in `fleet watch` from a
  tool prompt. It clears on its own — do not panic-reap.
- **A real tool prompt never clears: if you sent no `SendMessage`, stop waiting and
  reap.** The complement of the held-message case above — and the two workers that
  taught it both died this way, on the `advisor` tool that no permissions list names.
  That particular trap is now closed, not merely narrow: #235 dropped `advisorModel`
  from `claude/settings.json`, and in the 2.1.325 bundle the advisor tool schema is
  appended to the request only `if(Ma)`, where `Ma` resolves from `advisorModel` and is
  `undefined` when the setting is absent — the model is never offered the tool, and the
  docs agree that unset means the advisor is off. Specs no longer need a "do not call
  `advisor`" line; `--advisor`, `/advisor` or restoring the setting would reopen it.
- **Staging under `wkspace` is necessary but not sufficient — and a few tool calls do
  not need a fleet worker at all.** The second worker, dispatched with `advisor`
  explicitly forbidden in its spec, blocked anyway during an orientation read, before
  writing anything, although its task paths were all under `additionalDirectories`
  (`/home/nixos/wkspace`, `/home/nixos/.config/dotfiles`). Cause, measured
  2026-11-20 (`fleet spawn`, `acceptEdits`, one sample each): Bash on a path outside cwd
  and `additionalDirectories` prompts even when the command is allowlisted — `find
  /home/nixos/.cache -maxdepth 1 -type d` blocked while the same `find` on
  `/home/nixos/wkspace/autonomy` ran, and two workers that day died on `find
  ~/.claude/plugins/cache/...` and `find ~/.cache/llama.cpp ...` right after a `Read` of
  the same tree had succeeded. The `Read` tool did not prompt; Bash did. Top-level shell
  expansion (`echo "home=${HOME}"`) also blocked. The rule that follows is about sizing,
  not paths: for a task of a few tool calls, dispatch an in-process `Agent` instead. It
  runs under this session's permissions, so a prompt reaches the human instead of
  deadlocking. The same spec that killed two background workers was executed by an
  in-process subagent in 19 tool calls. Reserve `fleet` for work long enough that
  staying available matters.
- **`jj git fetch` does not move `@`, and `home-manager switch` will build the stale
  working copy and still exit 0.** After fetching two merged PRs the bookmarks had
  advanced but `@`'s parent was still the pre-merge commit; `home-manager switch --flake
  .#nixos@wsl` built from that source, **reported exit code 0**, and activated a
  generation containing neither merge. The symptom was a file the merge had deleted still
  present in the activated generation — nothing in the switch output said anything was
  wrong. `jj new main` is the catch-up step. Without it a destructive follow-up runs
  against old source: here the deleted bootstrap would have recreated the very clone it
  was meant to remove.
- **A `Bash(...)` pattern's `*` crosses `/`, so a deny rule is far broader than it
  looks.** `permissions.deny`'s `Bash(rm -rf /*)` matched *every* absolute path:
  `rm -rf /home/nixos/wkspace/rmtest-probe` → denied, `rm -rf /tmp/.../rmprobe` →
  denied, while `rm -rf rmtest-probe` — relative, same target — executed with no prompt,
  because `permissions.deny` outranks the mode but `"defaultMode": "auto"` auto-approves
  a relative deletion confined to an allowed directory. The net effect was that the
  auditable spelling, absolute path with a visible target, was the only one forbidden.
  `*` is not path-segment-scoped, so depth globs like `/*/*` cannot mean "root's direct
  children"; check every deny rule by probing a path it was never meant to cover.

## Gotchas

- Nix errors can be cryptic — read the full trace, don't guess
- home-manager switch can fail silently on some options — check `systemctl --user status` if behavior seems wrong
- When adding new packages, check nixpkgs for the correct attribute path with `nix search`
