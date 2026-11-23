# SPEC: Plover formatting operators in `steno-core`

## Why

`Translator` (in `crates/steno-core/src/dictionary.rs`) turns strokes into
`Translation::Text { strokes, text }`, where `text` is the raw dictionary string. The app
types that string unchanged, so a dictionary entry such as `{^ing}` or `{.}` is typed
literally today. Steno dictionaries use Plover's *translation language* for spacing,
attaching, capitalization and punctuation. This task adds the missing stage: a pure
formatter that turns a sequence of dictionary translations into the text a user should
see, and into the keystroke delta needed to get there.

The formatter is a new module, `crates/steno-core/src/format.rs`. `Engine`, `Translator`
and the `steno-app` crate are not touched; wiring the formatter into the app is a later
change.

## Public API (fixed — implement exactly this)

```rust
pub use format::{format, Formatter, Output};               // in lib.rs
#[derive(Debug, Clone, PartialEq, Eq, Default)]
pub struct Output { pub backspaces: usize, pub text: String } // chars to delete, then text to type
impl Formatter {
    pub fn new() -> Self;                             // also Default
    pub fn apply(&mut self, translation: &str) -> Output; // one dictionary translation
    pub fn undo(&mut self) -> Output;                 // revert the last apply (state too); empty if none
    pub fn text(&self) -> &str;                       // everything rendered so far
}
pub fn format(translations: &[&str]) -> String;      // fold apply over a fresh Formatter, return text()
```

- `lib.rs` gains `pub mod format;` and the `pub use` line above.
- `Formatter` implements `Default` (same as `new()`).
- `format(ts)` is exactly: a fresh `Formatter`, `apply` each element in order, return a
  copy of `text()`.

### `Output`: the minimal delta

`apply` and `undo` change the rendered text from a *before* string `B` to an *after*
string `A`. The returned `Output` is the minimal edit that turns `B` into `A` when typed
at the end of the text:

- Let `p` be the length, in **Unicode scalar values** (Rust `char`s, not bytes), of the
  longest common prefix of `B` and `A`, compared `char` by `char`.
- `backspaces` = (number of `char`s in `B`) − `p`.
- `text` = `A` with its first `p` `char`s removed.

Example: `B = "cat"`, `A = "Cat."` gives `Output { backspaces: 3, text: "Cat." }`;
`B = "日本"`, `A = "日"` gives `Output { backspaces: 1, text: "" }`.

**Replay invariant:** starting from an empty buffer, applying every `Output` returned so
far, in order (delete `backspaces` chars from the end, then append `text`), yields exactly
`text()`. This holds across any mix of `apply` and `undo`.

### `undo`

`undo` reverts the most recent `apply` that has not already been undone: the rendered
text **and** every piece of formatting state (pending attach, pending case, glue, the
"last fragment" used by retro operators) return to exactly what they were before that
`apply`. Repeated `undo` walks further back. With nothing left to undo it changes nothing
and returns `Output::default()`. An `apply` that changed no text can still be undone (its
`Output` is empty, but its state change is reverted).

## Formatting rules

### Atoms

A translation string is split into **atoms**: each `{...}` group is a *meta* atom; each
run of characters between metas is a *text* atom.

- Inside text, `\{` and `\}` are a literal `{` and `}` and never start or end a meta.
- Leading and trailing ASCII spaces of every text atom are dropped; a text atom that is
  empty after that is ignored. Spaces *inside* a text atom (a multi-word translation such
  as `hello world`) are kept.
- A translation consisting only of ASCII digits `0`–`9` (for example `42`) is treated as
  the glue atom `{&42}` (see Glue).

Atoms are processed left to right; each one updates the state below and may write a
**fragment**: an optional single space followed by some text.

### State

- **attach** — whether the next fragment is written without a space in front of it.
  Initially *true*: the very first word is attached (it starts the text, with no space).
- **case** — a pending case change for the next fragment: none (initially), *capitalize*,
  *lower*, or *upper*.
- **glue** — whether the most recent fragment was written by a glue atom. Initially false.
- **last fragment** — where the most recent fragment starts and whether it has its space.

### Writing a fragment

A fragment with text `t` is written as:

1. A space, unless the fragment is attached. A fragment is attached when *attach* is true,
   or the atom itself attaches to the previous text (`{^x}` forms, punctuation, glue next
   to glue — below).
2. `t` with the pending *case* applied, which also clears it:
   - *capitalize*: the first `char` of `t` is upper-cased;
   - *lower*: the first `char` of `t` is lower-cased;
   - *upper*: the first word of `t` (up to its first space) is upper-cased.

   Upper-/lower-casing follows Rust's `char::to_uppercase` / `char::to_lowercase`.
3. Then *attach* becomes false and *glue* becomes false, unless the atom says otherwise.

Apart from `{^}`, `{^^}` and `{}` (below), an atom that writes no text never touches the
pending *case*.

### Plain text

A text atom writes itself as a fragment: words go **space-before** — a space is written in
front of each word unless it is attached. Example: `["hello", "world"]` → `hello world`.

### Attach

| atom | effect |
|---|---|
| `{^}` and `{^^}` | write nothing; *attach* becomes true; a pending *case* is dropped and *glue* becomes false |
| `{^x}` | write `x` attached to the previous text |
| `{x^}` | write `x` normally, then *attach* becomes true |
| `{^x^}` | write `x` attached, then *attach* becomes true |
| `{^ ^}` | write a single space attached, then *attach* becomes true (a forced space) |

Here `x` is any non-empty text. Attach and other atoms can be mixed with text inside one
translation: `x{^}` writes `x` then attaches the next word; `{^}x` writes `x` attached.
Examples: `["test", "{^ing}"]` → `testing`; `["{in^}", "side"]` → `inside`;
`["a", "{^-^}", "b"]` → `a-b`. Without orthography rules, `["make", "{^ing}"]` → `makeing`.

### Glue

`{&x}` writes `x`; it is attached when the most recent fragment was also glue (or when
*attach* is true), and it sets *glue* to true. A digits-only translation is implicitly
glue. Glue sticks only to adjacent glue: a normal word after glue gets its space.
Examples: `["{&a}", "{&b}", "{&c}"]` → `abc`; `["1", "2", "3"]` → `123`;
`["page", "4", "2"]` → `page 42`; `["{&a}", "word", "{&b}"]` → `a word b`.

### Case

| atom | effect |
|---|---|
| `{-\|}` | the next fragment is capitalized (first `char` upper-cased) |
| `{>}` | the next fragment's first `char` is lower-cased |
| `{<}` | the next fragment's first word is upper-cased |
| `{*-\|}` | capitalize the previous word |
| `{*>}` | lower-case the first `char` of the previous word |
| `{*<}` | upper-case the previous word |

`{-|}`, `{>}` and `{<}` only set *case*; they write nothing and leave *attach* and *glue*
as they were. The retro forms `{*-|}`, `{*>}`, `{*<}` act on the **previous word**: the
longest run of non-whitespace `char`s at the end of the rendered text. They rewrite that
word in place and change no other state (*attach*, *case* and *glue* stay as they were).
With no previous word (empty text, or text ending in whitespace) they do nothing.
Examples: `["{-|}", "hello"]` → `Hello`; `["{<}", "nasa"]` → `NASA`;
`["hello", "{*-|}"]` → `Hello`; `["{-|}", "{>}", "Word"]` → `word` (the later case wins).

### Punctuation

| atom | effect |
|---|---|
| `{.}` `{?}` `{!}` | write `.` / `?` / `!` attached, then *case* becomes *capitalize* |
| `{,}` `{:}` `{;}` | write `,` / `:` / `;` attached; no new case |

After punctuation the next word gets its space as usual. Examples:
`["hello", "{.}", "world"]` → `hello. World`; `["yes", "{,}", "sir"]` → `yes, sir`.

### Retro spacing

- `{*!}` removes the space in front of the **last fragment**, if it has one (joining the
  last two words). Otherwise it does nothing.
- `{*?}` inserts a space in front of the last fragment, if it has none.

Neither changes *attach*, *case* or *glue*. With no fragment written yet, both do nothing.
Examples: `["hello", "world", "{*!}"]` → `helloworld`; `["in", "{^side}", "{*?}"]` →
`in side`.

### Cancel, escapes and unknown metas

- `{}` writes nothing and cancels pending formatting: *attach* becomes false, *case*
  becomes none and *glue* becomes false. So `["a", "{-|}", "{}", "word"]` → `a word`
  (lower-case), and `["a{^}", "{}", "b"]` → `a b`.
- `\{` and `\}` are literal braces: `["\{x\}"]` → `{x}`.
- Any other `{...}` meta — for example `{#Return}` (a key press) or `{PLOVER:TOGGLE}` (an
  engine command) — writes no text and changes no state at all.

## Out of scope

Not implemented and not tested: sending keys for `{#...}` (they are ignored, as above),
orthography rules (`{^ing}` attaches literally), carry-capitalization `{~|...}`, the
behaviour of `{PLOVER:...}` commands, and space-after placement (spaces always go before
words).

## Constraints

- Put the formatter in `crates/steno-core/src/format.rs` and re-export it from `lib.rs`
  as shown. Change no existing public item and add no dependency (no change to any
  `Cargo.toml`).
- Work only inside `crates/steno-core/` (source and tests). Do not touch `steno-app`, the
  workspace `Cargo.toml`, `Cargo.lock` or `flake.nix`.
- Write your formatter tests in `crates/steno-core/tests/format*.rs` (for example
  `crates/steno-core/tests/format.rs`), using **only the public API above**
  (`steno_core::{format, Formatter, Output}`). Every existing test must keep passing.
- Build and test with `cargo test -p steno-core --offline` only. Never build the whole
  workspace (`cargo test` at the root): `steno-app` needs GUI system libraries that are
  not available here. There is no network access.
- Keep every file you add or change `rustfmt`-clean, and keep `cargo clippy -p steno-core
  --all-targets --offline -- -D warnings` clean. Some existing files are not
  `rustfmt`-clean; leave files you have no other reason to change as they are.
