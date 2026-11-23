# Task

The current directory is an existing Rust repository. Read `SPEC.md` in the current
directory and implement it in this repository, exactly as `SPEC.md` describes. Fit the
change into the code that is already here: its conventions, its tests and its toolchain.

## Boundary

- Work only inside `crates/steno-core/` (its source and its `tests/` directory). Change
  nothing else in the repository; `SPEC.md` says what may not change inside it either.
- Build and test with `cargo test -p steno-core --offline` only, never the whole
  workspace. There is no network access; everything you need is already here.
- Never ask questions. Nobody will answer; decide for yourself and keep going.

## Termination condition

When you believe the repository fully satisfies `SPEC.md` and
`cargo test -p steno-core --offline` passes, create an empty file named `DONE` in the
current directory and stop. Do not create `DONE` before that.

## Output

- The formatter and its re-export in `crates/steno-core/`, as `SPEC.md` describes.
- Your own tests of it in `crates/steno-core/tests/format*.rs`.
- The empty file `DONE`, once you are finished.
