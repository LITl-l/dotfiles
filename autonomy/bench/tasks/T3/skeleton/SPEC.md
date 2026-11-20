# T3 — make the log aggregator fast

`./run` in this directory is a **correct but slow** log aggregator. It is also its own
source (Python 3). Your job is to make `./run` much faster **without changing its output
in any way**. You may rewrite it in any language available to you. It must stay an
executable named `./run` in this directory.

Your result is checked in two steps:

1. Correctness. Your `./run` and the original are run on many inputs, including edge
   cases. The output must be byte-for-byte identical, and the exit status must be 0.
   A single difference scores zero speed.
2. Speed. Only if step 1 finds no difference, both programs are timed on a large input.
   The score is the original's time divided by yours.

The current `./run` defines the behaviour. If this text and `./run` disagree, `./run` wins.

## Input (stdin)

Zero or more lines, each `<key> <value>` followed by a newline:

- `<key>` is 1–16 characters from `a-z`, `0-9` and `_`.
- `<value>` is a decimal integer, 0 ≤ value < 1 000 000 000.
- They are separated by one space. Every line, including the last, ends in `\n`.

## Output (stdout)

```
keys <K>
<key> <count> <p50> <p99>      one line per distinct key, keys in ascending byte order
top <T>                        T = min(10, K)
<key> <count>                  the T keys with the highest count
```

- `count` is the number of lines with that key.
- `p50` and `p99` are nearest-rank percentiles of that key's values. Sort the values in
  ascending order as v[1..n]; then pX = v[ceil(X·n / 100)].
- The `top` keys are ordered by count, highest first. Keys with equal counts are ordered
  by ascending byte order of the key.
- An empty input prints `keys 0` and then `top 0`.

## Example

Input:

```
b 5
a 1
b 7
a 3
c 2
```

Output:

```
keys 3
a 2 1 3
b 2 5 7
c 1 2 2
top 3
a 2
b 2
c 1
```

## Optional

You may add `./test`, your own tests. It is run with `BENCH_TARGET` set to the path of a
`./run` to test, and it must exit non-zero when that program is wrong.
