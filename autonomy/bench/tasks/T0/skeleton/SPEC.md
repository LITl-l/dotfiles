# T0 — uppercase echo

Implement `./run`.

- `./run` reads all of standard input and writes it to standard output with every ASCII
  lowercase letter `a`–`z` replaced by its uppercase form `A`–`Z`.
- Every other byte is written unchanged, in order: digits, punctuation, whitespace,
  newlines (including whether the input ends with one), and non-ASCII bytes.
- Empty input produces empty output.
- `./run` exits with status 0.

Example: the input `Hello, world 42!` followed by a newline produces `HELLO, WORLD 42!`
followed by a newline.
