# Task

Read `SPEC.md` in the current directory and implement `./run` so that it behaves exactly
as `SPEC.md` describes. You choose the implementation language. `./run` must stay an
executable file in the current directory: it is invoked directly, reading standard input
and writing standard output.

## Boundary

- Work only inside the current directory. Everything you need is here.
- You may add an executable `./test` with your own tests. It must test the program whose
  path is in the environment variable `BENCH_TARGET`, not `./run` directly, and it must
  exit 0 when that program is correct and non-zero when it is not.
- Never ask questions. Nobody will answer; decide for yourself and keep going.

## Termination condition

When you believe `./run` fully satisfies `SPEC.md`, create an empty file named `DONE` in
the current directory and stop. Do not create `DONE` before that.

## Output

- `./run`, implementing `SPEC.md`.
- Optionally `./test`, testing `$BENCH_TARGET`.
- The empty file `DONE`, once you are finished.
