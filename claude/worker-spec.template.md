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

## Termination condition

The worker is done when this is objectively true — a command that exits 0, a file that
exists with given content, a test that passes. Not "when the feature feels complete".

    e.g. `nix flake check` exits 0 AND `home-manager switch --flake .` succeeds

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
