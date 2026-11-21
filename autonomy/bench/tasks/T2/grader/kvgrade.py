#!/usr/bin/env python3
"""T2 hidden checks. Usage: kvgrade.py <solution_dir> <err_file>

Prints "<passed> <total>" on stdout, where each check group counts once, and appends one
line per failed group to <err_file>. Exits 0 whenever it could grade, and 2 when the
grader itself cannot run (for example, strace is missing).

If T2_STATS names a file, it also writes {"groups": {name: bool}, "kills": n} there.
"kills" counts the kill -9 / restart points actually exercised.

Generation is derandomized and never shrinks, so a run is deterministic and its cost is
bounded: a failing group stops at its first counterexample.
"""

import contextlib
import json
import os
import re
import select
import shutil
import signal
import subprocess
import sys
import tempfile
import time

from hypothesis import HealthCheck, Phase, Verbosity, given, settings
from hypothesis import strategies as st
from hypothesis.configuration import set_hypothesis_home_dir

REPLY_TIMEOUT = 5.0
EXIT_TIMEOUT = 10.0
STATS = {"groups": {}, "kills": 0}


class GraderBroken(Exception):
    """The grader cannot grade at all. This is a bench bug, not a solution failure."""


class Fail(AssertionError):
    pass


# --- talking to ./run --------------------------------------------------------------


class Store:
    """One ./run process on a data dir, driven line by line."""

    def __init__(self, run, data, wrap=()):
        self.proc = subprocess.Popen(
            [*wrap, run, "--data", data],
            cwd=os.path.dirname(run),
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
        )
        self.buf = b""

    def __enter__(self):
        return self

    def __exit__(self, *exc):
        if self.proc.poll() is None:
            self.proc.kill()
        self.proc.wait()
        for f in (self.proc.stdin, self.proc.stdout):
            with contextlib.suppress(OSError):
                f.close()

    def send(self, lines):
        try:
            self.proc.stdin.write("".join(line + "\n" for line in lines).encode())
            self.proc.stdin.flush()
        except (BrokenPipeError, OSError):
            raise Fail(f"./run exited before reading {lines[0]!r}")

    def recv(self, cmd):
        deadline = time.monotonic() + REPLY_TIMEOUT
        fd = self.proc.stdout.fileno()
        while b"\n" not in self.buf:
            left = deadline - time.monotonic()
            if left <= 0 or not select.select([fd], [], [], left)[0]:
                raise Fail(f"no reply to {cmd!r} within {REPLY_TIMEOUT:.0f}s")
            chunk = os.read(fd, 65536)
            if not chunk:
                raise Fail(f"./run exited without replying to {cmd!r}")
            self.buf += chunk
        line, self.buf = self.buf.split(b"\n", 1)
        return line.decode(errors="replace")

    def call(self, cmd):
        self.send([cmd])
        return self.recv(cmd)

    def close(self):
        """End of input: ./run must exit 0 on its own."""
        with contextlib.suppress(OSError):
            self.proc.stdin.close()
        try:
            rc = self.proc.wait(EXIT_TIMEOUT)
        except subprocess.TimeoutExpired:
            raise Fail(f"./run did not exit within {EXIT_TIMEOUT:.0f}s of end of input")
        if rc != 0:
            raise Fail(f"./run exited {rc} at end of input")

    def kill9(self):
        os.kill(self.proc.pid, signal.SIGKILL)
        self.proc.wait()
        STATS["kills"] += 1


# --- the model -----------------------------------------------------------------------


def apply(model, op):
    """Apply op to model (a dict) and return the reply the spec requires."""
    verb, *args = op
    if verb == "SET":
        model[args[0]] = args[1]
        return "OK"
    if verb == "DEL":
        model.pop(args[0], None)
        return "OK"
    if verb == "GET":
        return f"VAL {model[args[0]]}" if args[0] in model else "NIL"
    keys = sorted(k for k in model if k.startswith(args[0]))
    return " ".join(["KEYS", *keys])


def line(op):
    return " ".join(op)


def run_ops(store, model, ops):
    for op in ops:
        want = apply(model, op)
        got = store.call(line(op))
        if got != want:
            raise Fail(f"{line(op)!r}: want {want!r}, got {got!r}")


def observe(store, keys):
    """The store's state over `keys`, read with GET only so SCAN bugs stay in their group."""
    state = {}
    for k in sorted(keys):
        got = store.call(f"GET {k}")
        if got.startswith("VAL "):
            state[k] = got[4:]
        elif got != "NIL":
            raise Fail(f"'GET {k}': want 'VAL <v>' or 'NIL', got {got!r}")
    return state


def touched(ops):
    return {op[1] for op in ops if op[0] != "SCAN"}


def verify(store, model, keys, when):
    got = observe(store, keys)
    want = {k: v for k, v in model.items() if k in keys}
    if got != want:
        lost = sorted(k for k in want if got.get(k) != want[k])
        back = sorted(k for k in got if k not in want)
        raise Fail(f"{when}: state differs from acknowledged writes (wrong or lost: {lost}, deleted but back: {back})")


# --- generators ----------------------------------------------------------------------

ALPHABET = "ABZabxyz019_.:/-"
# A small pool of keys makes overwrites, deletes of live keys and shared prefixes common;
# the free-text branch keeps lengths (up to the 64-char limit) and characters honest.
POOL = ["a", "b", "ab", "a1", "aB", "B", "a:b", "a-b", "a.b", "a/b", "_x", "z"]
pool = st.sampled_from(POOL)
keys = st.one_of(pool, pool, pool, st.text(ALPHABET, min_size=1, max_size=64))
vals = st.text(ALPHABET, min_size=1, max_size=64)
short = st.sampled_from(["a", "a", "a", "b", "B", "A", "_", "z", "a1", "ab"])
prefixes = st.one_of(short, short, short, keys)
writes = st.one_of(
    st.tuples(st.just("SET"), keys, vals),
    st.tuples(st.just("SET"), keys, vals),
    st.tuples(st.just("DEL"), keys),
)
ops = st.one_of(
    writes,
    st.tuples(st.just("GET"), keys),
    st.tuples(st.just("SCAN"), prefixes),
)


def prop(max_examples):
    return settings(
        max_examples=max_examples,
        derandomize=True,
        database=None,
        deadline=None,
        phases=[Phase.explicit, Phase.generate],
        suppress_health_check=list(HealthCheck),
        verbosity=Verbosity.quiet,
    )


# --- check groups --------------------------------------------------------------------


class Grader:
    def __init__(self, run, scratch):
        self.run = run
        self.scratch = scratch

    def fresh(self):
        return tempfile.mkdtemp(prefix="data-", dir=self.scratch)

    def basic(self):
        script = [
            ("GET", "a"), ("SET", "a", "1"), ("GET", "a"), ("GET", "b"),
            ("SET", "a", "2"), ("GET", "a"), ("DEL", "a"), ("GET", "a"), ("DEL", "a"),
            ("SET", "user:1", "alice"), ("SET", "user:2", "bob"), ("GET", "user:1"),
            ("SET", "k" * 64, "v" * 64), ("GET", "k" * 64), ("SET", "x", "a-b_c.d:e/f"),
            ("GET", "x"),
        ]
        with Store(self.run, self.fresh()) as s:
            run_ops(s, {}, script)
            s.close()

    def scan(self):
        names = ["a", "a1", "a2", "ab", "aa", "B", "b", "a.b", "a-b", "a/b", "a:b",
                 "a_b", "aZ", "_x", "Z", "user:10", "user:2", "user:1"]
        script = [("SCAN", "a")] + [("SET", k, "v") for k in names]
        script += [("SCAN", p) for p in ["a", "A", "a1", "user:", "user:1", "B", "q", "_", "Z"]]
        script += [("DEL", "a1"), ("DEL", "ab"), ("SCAN", "a"), ("SET", "a1", "w"), ("SCAN", "a")]
        with Store(self.run, self.fresh()) as s:
            run_ops(s, {}, script)
            s.close()

    def model(self):
        # The pool goes in first, in a generated order: left to the op generator alone,
        # 24 of 25 sequences issued no SCAN matching two keys, so key order went untested.
        @prop(25)
        @given(st.permutations(POOL), vals, st.lists(ops, min_size=8, max_size=40))
        def check(order, v, seq):
            with Store(self.run, self.fresh()) as s:
                run_ops(s, {}, [*(("SET", k, v) for k in order), *seq])
                s.close()

        check()

    def restart(self):
        @prop(10)
        @given(st.lists(st.lists(ops, min_size=1, max_size=15), min_size=2, max_size=4))
        def check(segments):
            data, model, seen = self.fresh(), {}, set()
            for i, seg in enumerate(segments):
                with Store(self.run, data) as s:
                    if i:
                        verify(s, model, seen, f"after clean restart {i}")
                    run_ops(s, model, seg)
                    seen |= touched(seg)
                    s.close()
            with Store(self.run, data) as s:
                verify(s, model, seen, f"after clean restart {len(segments)}")
                s.close()

        check()

    def crash(self):
        """Kill -9 right after an acknowledged write, then restart on the same data."""

        @prop(8)
        @given(st.lists(st.tuples(st.lists(ops, max_size=10), writes), min_size=3, max_size=5))
        def check(segments):
            data, model, seen = self.fresh(), {}, set()
            for i, (seg, last) in enumerate(segments):
                with Store(self.run, data) as s:
                    if i:
                        verify(s, model, seen, f"after kill -9 {i}")
                    run_ops(s, model, [*seg, last])
                    seen |= touched([*seg, last])
                    s.kill9()
            with Store(self.run, data) as s:
                verify(s, model, seen, f"after kill -9 {len(segments)}")
                s.close()

        check()

    def crash_burst(self):
        """Send a burst of writes without waiting, kill -9 after k acks.

        Acknowledged writes must all be there; unacknowledged ones may be there only as a
        prefix in arrival order, so the state must equal the model after ops[:m], k <= m <= n.
        """

        @prop(8)
        @given(st.lists(st.tuples(st.lists(writes, min_size=1, max_size=30),
                                  st.integers(min_value=0, max_value=10**6)),
                        min_size=2, max_size=3))
        def check(bursts):
            data, model, seen = self.fresh(), {}, set()
            for i, (burst, pick) in enumerate(bursts):
                k = 1 + pick % len(burst)
                seen |= touched(burst)
                with Store(self.run, data) as s:
                    if i:
                        verify(s, model, seen, f"after burst kill -9 {i}")
                    s.send([line(op) for op in burst])
                    for op in burst[:k]:
                        got = s.recv(line(op))
                        if got != "OK":
                            raise Fail(f"{line(op)!r}: want 'OK', got {got!r}")
                    s.kill9()
                with Store(self.run, data) as s:
                    got = observe(s, seen)
                    s.close()
                candidates = []
                m = dict(model)
                for j, op in enumerate(burst):
                    apply(m, op)
                    if j + 1 >= k:
                        candidates.append(dict(m))
                match = [c for c in candidates if {x: y for x, y in c.items() if x in seen} == got]
                if not match:
                    raise Fail(f"after burst kill -9 {i + 1}: state is not any arrival-order prefix "
                               f"that includes all {k} acknowledged of {len(burst)} sent writes")
                model = match[-1]

        check()

    def sync(self):
        """Every OK to a write must be preceded by a completed fsync-family syscall.

        kill -9 cannot test this: the page cache outlives the process. strace can: between
        the previous reply and the OK, some sync must have completed (fsync, fdatasync,
        sync, syncfs, sync_file_range, msync, or a write to an O_SYNC/O_DSYNC file).
        """
        script = [("GET", "a"), ("SET", "a", "1"), ("SET", "b", "2"), ("DEL", "a"),
                  ("GET", "b"), ("SET", "a", "3"), ("SCAN", "a"), ("SET", "c", "4")]
        nwrites = sum(op[0] in ("SET", "DEL") for op in script)
        trace = os.path.join(self.scratch, f"strace-{os.getpid()}.txt")
        wrap = ["strace", "-f", "-qq", "-s", "16", "-o", trace, "--"]
        with Store(self.run, self.fresh(), wrap) as s:
            run_ops(s, {}, script)
            s.close()
        with open(trace, errors="replace") as f:
            oks, unsynced = sync_audit(f)
        if oks != nwrites:
            raise Fail(f"strace saw {oks} 'OK' writes to stdout, expected {nwrites}")
        if unsynced:
            raise Fail(f"{unsynced} of {nwrites} writes were acknowledged before any fsync completed")


SYNCS = {"fsync", "fdatasync", "sync", "syncfs", "sync_file_range", "msync"}
WRITES = {"write", "pwrite64", "writev", "pwritev", "pwritev2"}
TRACE_LINE = re.compile(r"^(?:\d+\s+)?(.*)$")
RESUMED = re.compile(r"^<\.\.\. (\w+) resumed>(.*)$")
UNFINISHED = re.compile(r"^(\w+)\((.*) <unfinished \.\.\.>$")
CALL = re.compile(r"^(\w+)\((.*)$")
RET = re.compile(r"\)\s+=\s+(-?\d+)")


def sync_audit(lines):
    """Return (number of 'OK' replies, how many of them had no sync since the last reply)."""
    pending, osync = {}, set()
    synced, oks, unsynced = False, 0, 0

    def first_int(args):
        m = re.match(r"\s*(\d+)", args)
        return int(m.group(1)) if m else None

    for raw in lines:
        pid_body = TRACE_LINE.match(raw.rstrip("\n"))
        body = pid_body.group(1)
        pid = raw.split(None, 1)[0]
        start = end = None
        if m := RESUMED.match(body):
            name, args = m.group(1), pending.pop((pid, m.group(1)), "") + m.group(2)
            end = (name, args)
        elif m := UNFINISHED.match(body):
            pending[(pid, m.group(1))] = m.group(2)
            start = (m.group(1), m.group(2))
        elif m := CALL.match(body):
            start = end = (m.group(1), m.group(2))
        else:
            continue
        if start and start[0] in WRITES and first_int(start[1]) == 1:
            if '"OK\\n' in start[1]:
                oks += 1
                unsynced += not synced
            synced = False
        if end:
            name, args = end
            r = RET.search(args)
            ret = int(r.group(1)) if r else None
            if name in SYNCS and ret == 0:
                synced = True
            elif name in WRITES and first_int(args) in osync and ret is not None and ret > 0:
                synced = True
            elif name in ("open", "openat", "creat") and ret is not None and ret >= 0:
                if re.search(r"\bO_D?SYNC\b", args):
                    osync.add(ret)
                else:
                    osync.discard(ret)
            elif name == "close":
                osync.discard(first_int(args))
    return oks, unsynced


GROUPS = [
    ("basic", Grader.basic),
    ("scan", Grader.scan),
    ("model", Grader.model),
    ("restart", Grader.restart),
    ("crash", Grader.crash),
    ("crash-burst", Grader.crash_burst),
    ("sync", Grader.sync),
]


def describe(e):
    msg = str(e).strip().splitlines()
    text = msg[0] if msg else type(e).__name__
    return text if len(text) <= 300 else text[:297] + "..."


def preflight():
    if not shutil.which("strace"):
        raise GraderBroken("strace not on PATH; the sync group needs it")
    probe = subprocess.run(["strace", "-qq", "-o", os.devnull, "true"], capture_output=True)
    if probe.returncode != 0:
        raise GraderBroken(f"strace cannot trace here: {probe.stderr.decode().strip()}")


def main():
    if len(sys.argv) != 3:
        print("usage: kvgrade.py <solution_dir> <err_file>", file=sys.stderr)
        return 2
    sol, errf = os.path.abspath(sys.argv[1]), sys.argv[2]
    run = os.path.join(sol, "run")
    try:
        preflight()
    except GraderBroken as e:
        print(f"kvgrade: {e}", file=sys.stderr)
        return 2
    scratch = tempfile.mkdtemp(prefix="t2-grade-")
    errors, passed = [], 0
    try:
        # hypothesis fixes its storage dir to cwd at import time, so a chdir is too late:
        # without this it leaves .hypothesis/ in whatever directory ran the grader.
        set_hypothesis_home_dir(os.path.join(scratch, ".hypothesis"))
        os.chdir(scratch)
        grader = Grader(run, scratch)
        with contextlib.redirect_stdout(sys.stderr):
            for name, fn in GROUPS:
                ok = False
                if not os.access(run, os.X_OK):
                    errors.append(f"{name}: no executable ./run")
                else:
                    try:
                        fn(grader)
                        ok = True
                    except Exception as e:  # any failure inside a group fails that group
                        errors.append(f"{name}: {describe(e)}")
                STATS["groups"][name] = ok
                passed += ok
    finally:
        shutil.rmtree(scratch, ignore_errors=True)
    with open(errf, "a") as f:
        f.writelines(e.replace("\n", " ") + "\n" for e in errors)
    if os.environ.get("T2_STATS"):
        with open(os.environ["T2_STATS"], "w") as f:
            json.dump(STATS, f)
            f.write("\n")
    print(passed, len(GROUPS))
    return 0


if __name__ == "__main__":
    sys.exit(main())
