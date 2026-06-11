# crumb

Zero-dependency context **store-and-stub**: an MCP server *and* CLI that moves
large content out of an agent's context window. It stores content locally
(content-addressed) and hands back a short stub the agent can follow later with
`retrieve`. Pure Go standard library — no ML, no network, no telemetry.

```
⟦crumb b5522725f656 ~4.7k tok type=jsonl 4000 records⟧
preview: 1 2 3 4 5 6 7 8 9 10 11 12 …
↳ retrieve("b5522725f656") for full content
```

## Two ways to invoke it — only one saves context

| Path | Saves context? | Use it for |
|------|----------------|------------|
| **CLI pipe** — `big-cmd \| crumb compress` | ✅ Yes (~90 %+) | The raw output never enters context; only the stub does. **This is the high-value path.** |
| **MCP `compress` tool** | ❌ Not for output you already hold | The content must be passed in as the tool argument, so it is *already* in context. Use only for subagent handoff or to re-reference something later. |

> **There is no automatic mode.** Claude Code hooks cannot rewrite or replace a
> tool's output (`PostToolUse` can only *append* context or *block*; `PreToolUse`
> only edits the tool *input*). So crumb saves context only when you deliberately
> pipe output through the CLI — it cannot transparently intercept tool results.

The CLI and the MCP server share one store (`$CRUMB_DIR`, default
`~/.local/state/crumb`), so you can stash with the pipe and retrieve a slice
later through either interface.

## Recommended workflow: stash cheap, retrieve precise

```sh
# 1. Stash a large output — only an ~80-token stub enters context
verbose-build | crumb compress
#   ⟦crumb a1b2c3d4e5f6 ~12.0k tok type=text 3400 lines, …⟧

# 2. Later, pull back only the lines you need
crumb retrieve a1b2c3d4e5f6 --query error
```

`--query` filters JSON arrays element-wise and text/jsonl line-wise, so you can
retrieve one record out of thousands without re-reading the whole blob.

## Gotchas

### 1. Piping masks the upstream exit code
`cmd | crumb compress` reports **crumb's** exit status, not `cmd`'s — a failing
command looks successful:

```sh
false | crumb compress     # exit status: 0  (the failure is hidden!)
```

Guard it when the command's success matters:

```fish
big-cmd | crumb compress
test $pipestatus[1] -eq 0; or echo "big-cmd failed"   # fish
```

```bash
set -o pipefail; big-cmd | crumb compress             # bash
```

### 2. Only stdout is stubbed; stderr bypasses the pipe
`cmd | crumb compress` stashes stdout and lets stderr through inline — so error
messages stay visible, which is usually what you want. To stash the whole stream
(both channels) instead:

```sh
cmd 2>&1 | crumb compress
```

### 3. Small content passes through unchanged
Content below `CRUMB_MIN_TOKENS` (default 50, ≈200 chars) is returned as-is with
no stub and no store write. The stub itself is near-constant size (~70–80 tokens
regardless of input), so crumb only pays off on genuinely large outputs — below
~150 tokens the stub can be as big as the input.

## CLI reference

```
crumb mcp                          run the stdio MCP server
crumb compress [FILE|-]            store content, print the crumb stub
crumb retrieve <hash> [--query Q]  print stored content (optionally filtered)
crumb stats                        print savings + recent events
crumb gc [--days N] [--max-mb M] [--all]   prune old/oversized blobs
crumb --version | --help
```

### Environment

| Var | Default | Effect |
|-----|---------|--------|
| `CRUMB_DIR` | `~/.local/state/crumb` | store directory (else `$XDG_STATE_HOME/crumb`) |
| `CRUMB_MIN_TOKENS` | `50` | don't stub content below this many tokens |
| `CRUMB_HASH_LEN` | `12` | short-hash length (6–64) |
| `CRUMB_GC_DAYS` | `14` | `gc` age threshold in days |
| `CRUMB_GC_MAX_MB` | `512` | `gc` total-size cap in MB |
| `CRUMB_PRICE_PER_MTOK` | *(unset)* | if set, `stats` shows estimated cost saved |

Token counts are a rough heuristic (`ceil(chars / 4)`), not a real tokenizer.

## Build & test

Built declaratively by `pkgs/crumb/default.nix` (`buildGoModule`, `vendorHash =
null` — stdlib only). `nix build` / `nix flake check` run `go test ./...` via the
package check phase.
