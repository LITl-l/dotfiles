# Worker spec: <one-line task name>

Fill every section. `fleet spawn` refuses a spec missing Boundary, Termination or Output.
These three exist because specification and coordination defects — not model mistakes —
account for the large majority of multi-agent failures; "agent does not know when it is
done" is among the most common single modes.

## Goal

What outcome is wanted, in one or two sentences. State the intent, not the steps.

## Boundary

- Writable paths: <the worker's own jj workspace, e.g. ~/wkspace/worktree/feature/xyz>
- Do NOT touch: <paths owned by other workers, the main checkout, unrelated modules>
- Out of scope: <adjacent work this worker must leave alone>
- Scratch space: under `/home/nixos/wkspace/` only. A worker handed files under another
  session's `/tmp` scratchpad blocked on its first tool call; `wkspace` is what has been
  shown to work.
- If a baseline snapshot is wanted, stage it under `/home/nixos/wkspace/` yourself and
  name the path here; the worker cannot copy it into place.

### What is known to work

Read this list rather than a list of bans. A ban can only be written after something has
already died, so the forbidden set is always one worker behind; the allowed set is not.

- Files: create and edit with `Write` and `Edit`, read with `Read`. These are non-Bash
  `allow` entries and cannot gate. A Bash read can: three workers in one session blocked
  on one — `readlink`, a `for` loop, and an on-PATH binary invoked by name.
- Bash, for the cases that genuinely need a shell: `jq`, `cat`, `grep`, `sed`, `find`,
  `head`, `tail`, `wc`, `mkdir`, `diff`, `echo`, `ls`, `sleep`, `unzip -p`, `nix`
  (`build`, `develop`, `eval`, `flake check`, `search`), `nvim --headless`, `jj` except
  `jj git push`, read-only `git` (`show`, `log`, `diff`, `status`, also through
  `git -C <path>`), and `curl` to `localhost` or `127.0.0.1` only.
- Bash only on paths inside your workspace or `/home/nixos/wkspace`; never on
  `~/.claude`, `~/.cache`, `/nix/store`. An allowlisted command on a path outside the
  session's directories stalls (measured 2026-11-20: `find /home/nixos/.cache`); the
  `Read` tool on the same path did not. Top-level shell expansion (`${HOME}`) stalled too.
- Outside that set it stalls, including `rm`, `od`, `yq`, `python3` outside `tools/`,
  `curl` to any other host, and `gh pr edit`. Copy and move with `Write` (or `cat`):
  `cp` inside the cwd ran unprompted under `acceptEdits` once, mechanism unverified, so
  do not depend on it either way. For a trailing-newline check use
  `tail -c 1 <file> | wc -l`, not `od`.

### Shapes that gate although the command name is allowlisted

- **A braced array read of bash's capitalised pipeline-status variable.** Measured
  2026-11-17: a bare `echo` containing one — no pipe, no parentheses — raised a
  permission prompt under `--permission-mode acceptEdits`, although `Bash(echo *)` and
  `Bash(echo)` are both allowlisted. The same line ran silently in an interactive `auto`
  session, so an interactive check cannot reproduce this and must not be used to clear
  the shape. Take exit statuses the redirect way instead: `<cmd> > <logfile> 2>&1` on
  one line, `echo $?` on the next, then `grep`/`tail` the log in a separate call.
- **Parentheses inside a quoted string: UNMEASURED.** The probe that would settle it was
  never run — the worker assigned to it died on the shape above. Assume nothing either
  way; avoid them until someone measures it under `acceptEdits`.

### The three stalls of 2026-11-17

Reasons are given because reasons are what gets a rule obeyed: of 32 rules audited in
this repo, the 24 that were DEAD or LEAKY were the ones written as general advice, while
the ones traceable to a specific incident held.

1. `python3 -c "import json; ..."` — the only `python3` entry is `Bash(python3 tools/*)`,
   and a path-scoped pattern cannot match an inline `-c`. Inline `python3` stays out of
   the allowlist on purpose: it would make arbitrary code unreviewable. Use `jq`.
2. `grep -c ... <log>; echo "GREP_EXIT=<braced array read> (1 = zero matches)"` — both
   `grep` and `echo` are allowlisted, so the command names were never the problem; the
   braced array read was. `claude/pipeline-status-guard.sh` was handing that exact string
   out as a ready-made `Corrected command:`, and now recommends the redirect form instead.
3. A worker hit a prompt and recovered on its own — the only one of the three that did.

## Termination condition

The worker is done when this is objectively true — a command that exits 0, a file that
exists with given content, a test that passes. Not "when the feature feels complete".

    e.g. `nix flake check` exits 0 AND `home-manager switch --flake .#nixos@wsl` succeeds

Never make a gated action the done-condition: a background worker has no human to answer
a permission prompt and will block forever. A command gates by matching `permissions.ask`
(`jj git push`, `gh pr create`, `gh pr merge`), by matching no `allow` pattern at all
(`gh pr edit`), by touching a path outside the session's directories, or by being written
in a shape the matcher does not accept even though its name is allowlisted — see
Boundary. Stop the worker at "change described
with `jj describe -m`, result file written"; the orchestrator runs the gated steps.

## Output

- Write the result to: <absolute path, e.g. ~/.claude/fleet/<task>/result.md>
- Format: what the meta agent should find there — decisions made, files changed,
  commands run with their actual output, and anything left undone.

Report outcomes faithfully. If something failed, say so and paste the output.

## Verification

The exact command(s) the meta agent will re-run to confirm the termination condition.

## Context

Only what the worker cannot discover on its own: constraints, prior decisions, gotchas.
Do not paste files here — the worker can read them.
