# crumb — a zero-dependency context store-and-stub

**Status:** approved design (2026-06-03)
**Replaces:** the `headroom` MCP integration (`LITl-l/headroom-overlay`)

## Problem

The dotfiles currently depend on `headroom-ai` for context compression in Pi and
Claude Code. headroom is a large Python+Rust system shipping a HuggingFace model
(`Kompress-base`), AST compressors, an HTTP proxy, cross-agent memory, and an
on-by-default telemetry beacon that had to be disabled (`HEADROOM_TELEMETRY=off`).
It reaches the Nix world only through an external overlay (`LITl-l/headroom-overlay`)
that we fork and maintain.

In practice we use exactly three MCP tools — `compress`, `retrieve`, `stats` — and
in an MCP workflow the agent can always call `retrieve`. So the real token win is
not lossy ML compression; it is **reference indirection**: replace a big blob in the
transcript with a short stub plus a key, store the original locally, and fetch it on
demand. That subset is trivially simple and needs no ML, no network, and no
third-party libraries.

## Goals

- Minimal dependencies: a single static binary, no interpreter, no runtime libraries.
- Easy for a Nix user: built in-repo with `buildGoModule`, no external flake input,
  no Cachix.
- Auditable: a handful of small Go files you can read end-to-end — visibly no
  telemetry.
- Drop-in for our usage: same three tool semantics, plus a CLI for PATH parity.

## Non-goals (explicitly dropped — unused in our config)

- ML / AST compressors (the lossy, irreversible path).
- HTTP proxy server.
- Cross-agent memory dedup and the `learn` / session-mining command.
- Any telemetry. There is no beacon and no opt-out knob, because there is nothing
  to opt out of.

## Naming

The tool is `crumb`: leave a crumb in the transcript, follow it home to the full
content. The stub marker *is* the breadcrumb.

- CLI binary: `crumb`
- MCP server id: `crumb`; tool names `compress`, `retrieve`, `stats` (exposed to
  agents as `mcp__crumb__compress` / `mcp__crumb__retrieve` / `mcp__crumb__stats` —
  no `crumb_` prefix on the tool name, to avoid the `mcp__crumb__crumb_…` stutter)
- Nix attribute: `pkgs.crumb`
- Store directory: `~/.local/state/crumb/` (override with `$CRUMB_DIR`)

## Architecture

A static Go binary, pure standard library (`encoding/json`, `crypto/sha256`, `os`,
`bufio`, `time`). No external modules, so `go.mod` has no `require` block and
`buildGoModule` uses `vendorHash = null`.

```
pkgs/crumb/
  default.nix     buildGoModule, vendorHash = null, static binary
  go.mod          module crumb; no require block
  main.go         arg dispatch: mcp | compress | retrieve | stats | gc
  mcp.go          JSON-RPC 2.0 stdio loop: initialize, tools/list, tools/call
  summary.go      type detection + stub rendering + token estimate
  store.go        content-addressed blob store + JSONL event log + gc
  *_test.go       unit + protocol tests
```

Each unit has one purpose, a small interface, and is testable in isolation:

| Unit | Responsibility | Depends on |
|------|----------------|-----------|
| `store` | `Put(content) -> hash` (atomic temp+rename, dedup by hash); `Get(hash, query)`; `AppendEvent`; `ReadStats`; `GC` | `os`, `crypto/sha256` |
| `summary` | detect type {json, jsonl, text}; render stub; estimate tokens (`len/4`) | `encoding/json` |
| `mcp` | newline-delimited JSON-RPC over stdin/stdout; dispatch the 3 tools | `store`, `summary`, `encoding/json` |
| `main` | CLI subcommands sharing the same `store` + `summary` | all of the above |

## On-disk layout & data flow

```
~/.local/state/crumb/            (override: $CRUMB_DIR)
  blobs/<sha256hex>              one file per unique content (atomic write, dedup-by-name)
  events.jsonl                   append-only: {ts,op,hash,orig_tok,stub_tok}
```

- **compress(content):** `h = sha256(content)`. If the estimated size is below
  `$CRUMB_MIN_TOKENS` (default 50) return the content unchanged — stubbing tiny
  content is pointless. Otherwise write `blobs/h` (skip if it already exists =
  dedup), append a `compress` event, and return the stub.
- **retrieve(hash, query?):** read `blobs/<hash>`. No query → return the full
  content. With a query → JSON arrays are filtered to elements whose serialization
  contains the query; text / jsonl are grepped to matching lines plus a match count.
  A missing or GC'd hash returns a clear "not found (may have been gc'd)" error.
- **stats():** fold `events.jsonl` into totals — compressions, unique blobs,
  original vs stub tokens, **tokens saved**, store size on disk, and the most recent
  events. Cost is shown only if `$CRUMB_PRICE_PER_MTOK` is set; otherwise omitted to
  stay honest.

### Concurrency

Pi and Claude Code each spawn their own `crumb mcp` process against the same store.
Content-addressed filenames plus atomic `write-temp + rename` make blob writes
conflict-free (identical content → identical filename; different content → different
filename). The event log uses `O_APPEND`, whose small writes are atomic on POSIX. No
locks and no database are required.

## The stub

What lands in the transcript:

```
⟦crumb 9f3a1c8e ~14.2k tok type=json keys=[results(312), meta, page]⟧
preview: {"results":[{"id":1,"name":"alpha","status":"ok"}, …
↳ retrieve("9f3a1c8e") for full content
```

Type detection is pure heuristic:

- Parse as JSON. Object → list top-level keys with array lengths
  (`keys=[results(312), meta, page]`). Array → length plus the first element's keys.
- Else if every non-empty line parses as JSON → `jsonl` with a line count.
- Else `text` with line and character counts plus a head preview.

Code and logs fall under `text` (line counts + head preview) rather than pretending
to parse them. Token estimate is `len(content)/4`, labelled `~` to signal an
estimate.

## Error handling

Failures surface; they are never silently swallowed.

- Unknown hash → JSON-RPC error `-32602` (invalid params) / CLI exit 1 with a
  message.
- Malformed JSON-RPC frame → `-32700` (parse error).
- Unknown method or tool → `-32601` (method not found).
- `compress` never fails on unparseable content — it classifies it as `text`.
- A GC'd retrieval returns an explicit "expired" message so the agent can tell an
  evicted hash apart from a wrong one.

## MCP protocol

A minimal JSON-RPC 2.0 server over stdio (newline-delimited JSON). Methods handled:

- `initialize` → reply with `serverInfo`, a `tools` capability, and the negotiated
  `protocolVersion` (echo the client's requested version when supported).
- `notifications/initialized` → no-op.
- `ping` → empty result.
- `tools/list` → the three tools with JSON-Schema `inputSchema`.
- `tools/call` → dispatch to `compress` / `retrieve` / `stats`, returning a
  `content` array with a single `text` item.

The exact `protocolVersion` strings accepted are verified during implementation
against what Claude Code and Pi actually send.

## CLI surface

```
crumb mcp                         run the stdio MCP server (used by Pi + Claude Code)
crumb compress [FILE|-]           read FILE or stdin, store it, print the stub
crumb retrieve <hash> [--query Q] print the original (optionally filtered)
crumb stats [--json]              print savings + recent events
crumb gc [--days N] [--max-mb M] [--all]   prune old/oversized blobs; compact log
crumb --version | --help
```

## Nix integration (the cleanup)

- **flake.nix:** remove the `headroom` input (`github:LITl-l/headroom-overlay`) and
  its overlay/linux-gating. Add a local overlay
  `crumb = final.callPackage ./pkgs/crumb {}` so `pkgs.crumb` resolves in-repo with
  no external flake and no Cachix.
- **home.nix:** `pkgs.headroom` → `pkgs.crumb`; delete the `HEADROOM_TELEMETRY` env
  entry and the headroom-overlay / Cachix comments.
- **modules/pi.nix:** MCP server `headroom` → `crumb`, command `crumb` with args
  `["mcp"]`, drop the telemetry env.
- **modules/claude-code.nix:** rewrite the activation script to
  `claude mcp remove headroom` (if present) and register `crumb`
  (`claude mcp add crumb -s user -- crumb mcp`); the idempotency check keys on
  whether `crumb` is already registered.
- **.claude/settings.local.json:** drop the stale
  `Read(.../headroom-mcp/**)` permission.
- **memory:** update `feedback_audit_tool_telemetry.md` to note crumb has no beacon
  (the audit instinct still applies to future tools).

## Testing & verification

Go unit and protocol tests, run automatically by `buildGoModule`'s check phase:

- `retrieve` returns a byte-identical original after `compress`.
- Dedup: compressing identical content twice yields one blob and the same hash.
- Type detection for JSON object, JSON array, jsonl, and text.
- Token estimate sanity.
- Query filtering: JSON array element filter and text line grep.
- GC: age and size-cap eviction; `retrieve` after GC returns the "expired" error.
- Concurrency: parallel goroutine writes of identical and distinct content do not
  corrupt the store or the event log.
- MCP protocol: a table test feeds `initialize` / `tools/list` / `tools/call` frames
  and asserts the JSON-RPC responses.

System verification:

1. `nix flake check`
2. `home-manager switch --flake .`
3. `claude mcp get crumb` shows the registered server.
4. Shell roundtrip: `crumb compress < big.json` then `crumb retrieve <hash>` returns
   the original; `crumb stats` reports the savings.

## Net result vs. today

| | headroom (now) | crumb (proposed) |
|---|---|---|
| Runtime deps | Python + Rust + HF model, ML stack | one static binary |
| Source of truth | external `LITl-l/headroom-overlay` we fork/maintain | in this dotfiles repo |
| Telemetry | on-by-default beacon (disabled via env) | none exists |
| Auditability | large multi-language codebase | ~4 small Go files |
| Compression | lossy ML (irreversible) | reversible store-and-stub |

## Defaults summary

| Knob | Env var | Default |
|------|---------|---------|
| Store directory | `$CRUMB_DIR` | `~/.local/state/crumb` |
| Min size to stub | `$CRUMB_MIN_TOKENS` | 50 tokens |
| GC age | `$CRUMB_GC_DAYS` | 14 days |
| GC size cap | `$CRUMB_GC_MAX_MB` | 512 MB |
| Cost reporting | `$CRUMB_PRICE_PER_MTOK` | unset (omitted) |

GC is manual (`crumb gc`); there is no automatic background eviction.
