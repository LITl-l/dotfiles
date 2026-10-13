# i-have-adhd (vendored)

- Upstream: <https://github.com/ayghri/i-have-adhd>
- Upstream version: 0.4.1, author "Ayoub G." (Ayoub Ghriss)
- Licence: MIT — the notice is vendored verbatim as `LICENSE`
- Vendored: 2026-10-13

Vendored rather than added as a remote marketplace. `setup-marketplace.sh` reinstalls
only plugins whose id ends in `@local` or `@claude-plugins-official`; an entry from a
third-party marketplace is classified foreign and skipped, so a remote add would
silently fail to reinstall on a fresh machine.

## Deviations from upstream

The ten numbered rules, the "What ADHD changes about reading" facts, the "When to break
the rules" exceptions and the pre-send check are byte-identical to upstream. Three
deliberate deviations:

### 1. `disable-model-invocation` removed, so the skill can auto-trigger

Upstream frontmatter carried `disable-model-invocation: true`, which makes a skill
slash-command only. This copy is enabled at user scope and is expected to fire on its
own when a request calls for this shape, so the line is dropped. The `description:` was
retuned at the same time into a trigger list with a negative clause, so it fires on
genuine ADHD or answer-first requests and not on ordinary coding prompts.

### 2. The session latch removed, so the skill applies per response

Upstream:

```
## Persistence

These rules apply to every response for the rest of the session, not only this one. [...]

Turn them off only when the reader says "stop adhd mode" or "normal mode". [...]
```

Here:

```
## Scope

These rules shape the response they fire on. They do not switch the session into a mode
and they do not carry over to later turns on their own [...]
```

Upstream latches because a human invokes it deliberately. Under model invocation a
passing mention of ADHD would otherwise reshape an entire session silently. The
`Invoke with /i-have-adhd; stays on until "stop adhd mode"` tail was dropped from the
`description:` for the same reason: with no mode to exit, those commands mean nothing.

### 3. Only `SKILL.md` and `LICENSE` vendored

Upstream also ships `hooks/`, `scripts/`, `evals/`, `tests/`, `extensions/` and
manifests for Codex, Cursor, Gemini, Qwen, Kimi and opencode. None are vendored.

`hooks/hooks.json` registers a SessionStart hook running `always-on.mjs`. It was read in
full and is local-only: no network, no telemetry. It fires only if the user opts in by
creating `~/.claude/.i-have-adhd-always`, strips the frontmatter and prints the body as
session context, and exits 0 on any failure. Dropping it loses exactly one feature — that
opt-in always-on injection — which is the latching behaviour deliberately removed above.
Excluding it also keeps executables out of the tree: an out-of-store executable breaks CI
in this repo.
