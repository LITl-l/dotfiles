#!/usr/bin/env python3
"""Deterministic T3 input generator.

  gen.py cases <dir>               named edge cases + RANDOM_CASES random inputs, <name>.in
  gen.py large <file> [lines keys]  the timed input (defaults LARGE_LINES, LARGE_KEYS)

Every input comes from a fixed seed, so a grade is reproducible byte for byte.
"""
import random
import string
import sys

RANDOM_CASES = 200
SEED = 20261120
# Sized so the naive reference takes 8-15 s on the bench host (measured; see WP4.md).
LARGE_LINES = 200000
LARGE_KEYS = 2500

KEY_CHARS = string.ascii_lowercase + string.digits + "_"


def key_pool(rng, k):
    """k distinct random keys; their first-appearance order is unrelated to byte order."""
    pool = set()
    while len(pool) < k:
        pool.add("".join(rng.choice(KEY_CHARS) for _ in range(rng.randint(1, 16))))
    keys = sorted(pool)
    rng.shuffle(keys)
    return keys


def lines(pairs):
    return "".join("%s %d\n" % kv for kv in pairs)


def named_cases():
    rng = random.Random(SEED)
    cases = {}
    cases["empty"] = ""
    cases["one-line"] = "solo 42\n"
    cases["one-key-many"] = lines(("k", rng.randrange(1000)) for _ in range(250))
    cases["one-key-101"] = lines(("k", v) for v in rng.sample(range(10**6), 101))
    # 12 keys, all with count 3, first appearing in reverse byte order: every top slot
    # is a tie, and the 10-key cut falls inside the tie.
    tied = ["k%02d" % i for i in range(12)][::-1]
    cases["all-ties"] = lines((k, rng.randrange(100)) for _ in range(3) for k in tied)
    # 11 keys: one leader, then ten tied keys competing for nine slots.
    t10 = [("lead", i) for i in range(5)]
    t10 += [(k, 7) for k in ["z", "y", "x", "w", "v", "u", "t", "s", "r", "q"] for _ in range(2)]
    cases["tie-at-10th"] = lines(t10)
    cases["exactly-10-keys"] = lines(("key%d" % (i % 10), i) for i in range(37))
    cases["equal-values"] = lines((k, 5) for k in ["b", "a", "c", "a", "b", "a"])
    cases["max-values"] = lines((k, 999999999 - i) for i, k in enumerate("abcabcab"))
    cases["zero-values"] = lines(("z_0", 0) for _ in range(4))
    cases["long-keys"] = lines(("_" * 16 if i % 2 else "9" * 16, i) for i in range(9))
    cases["even-count"] = lines(("e", v) for v in [4, 1, 3, 2])
    return cases


def random_case(rng, big):
    if big:
        n = rng.randint(150, 400)
        k = rng.randint(1, 3)
    else:
        n = rng.randint(1, 40)
        k = rng.randint(1, 15)
    keys = key_pool(rng, k)
    hi = rng.choice([3, 50, 10**9])
    return lines((rng.choice(keys), rng.randrange(hi)) for _ in range(n))


def write(path, text):
    with open(path, "w", newline="") as f:
        f.write(text)


def main(argv):
    if len(argv) >= 3 and argv[1] == "cases":
        for name, text in named_cases().items():
            write("%s/%s.in" % (argv[2], name), text)
        rng = random.Random(SEED + 1)
        for i in range(RANDOM_CASES):
            write("%s/r%03d.in" % (argv[2], i), random_case(rng, i % 10 == 0))
        return 0
    if len(argv) in (3, 5) and argv[1] == "large":
        n, k = (int(argv[3]), int(argv[4])) if len(argv) == 5 else (LARGE_LINES, LARGE_KEYS)
        rng = random.Random(SEED + 2)
        keys = key_pool(rng, k)
        write(argv[2], lines((rng.choice(keys), rng.randrange(10**9)) for _ in range(n)))
        return 0
    sys.stderr.write(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
