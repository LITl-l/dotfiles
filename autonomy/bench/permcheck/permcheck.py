"""z3 model of Claude Code permission matching for the autonomy bench (design §3, check A).

(a) reads_protected: is there a command the merged settings let run unprompted that
    reads a protected path? Searched with z3 string constraints over three shapes:
    a read-class tool naming the path, `cd <dir> && <tool> <relative path>`, and a
    recursive reader pointed at an ancestor of the path. Plus the built-in Read tool,
    which needs no allow rule inside the session's directories, against Read() denies.
(b) done_prompts: does a done-cmd hit deny or ask, or miss every allow? Or name a
    literal path outside the session's directories (path scope, which prompts even
    under an allow rule)? Under acceptEdits, a file command inside the cwd needs no
    allow rule. Both come from real-session sampling (results/O3.md), not from docs.

Where Claude Code's matcher is not pinned down, the model brackets it: a strict and a
loose reading of every wildcard rule. (a) widens allow and narrows deny/ask, so it can
only over-report. (b) evaluates every combination and says `unverified` when they
disagree; it never picks one.
"""

import argparse
import itertools
import json
import os
import posixpath
import re
import shlex
import sys

import z3

COVERAGE = ["simple", "exact", "prefix:*", "glob*", "pipe", "&&", "||", ";",
            "Read-deny", "cd-relative", "recursive"]

# Tools that print, summarise or execute the files named in their arguments.
READ_TOOLS = ["cat", "tac", "head", "tail", "less", "more", "nl", "od", "xxd", "hexdump",
              "strings", "file", "grep", "egrep", "fgrep", "rg", "ag", "ack", "sed",
              "awk", "gawk", "cut", "sort", "uniq", "wc", "diff", "cmp", "comm", "paste",
              "base64", "jq", "yq", "bat", "vi", "vim", "nvim", "find", "python3",
              "python", "node", "perl", "ruby", "bash", "sh", "source"]

Z3_TIMEOUT_MS = 10000
NO_ALLOW = "<no allow rule>"
READ_DEFAULT = "<Read needs no allow rule inside the session's directories>"


class Unverified(Exception):
    pass


# --- Pattern AST, rendered both to z3 (searching) and to Python re (concrete checks),
# --- so the two questions share one matching semantics.

def lit(s):
    return ("lit", s)


ANY = ("any",)
NOSLASH = ("noslash",)


def seq(*xs):
    return ("seq", xs)


def opt(x):
    return ("opt", x)


def to_py(a):
    k = a[0]
    if k == "lit":
        return re.escape(a[1])
    if k == "any":
        return "(?s:.*)"
    if k == "noslash":
        return "[^/]"
    if k == "seq":
        return "".join(to_py(x) for x in a[1])
    if k == "opt":
        return "(?:" + to_py(a[1]) + ")?"
    if k == "star":
        return "(?:" + to_py(a[1]) + ")*"
    raise ValueError(a)


RE = z3.ReSort(z3.StringSort())


def zcat(rs):
    rs = list(rs)
    if not rs:
        return z3.Re(z3.StringVal(""))
    return rs[0] if len(rs) == 1 else z3.Concat(*rs)


def zalt(rs):
    rs = list(rs)
    if not rs:
        return z3.Empty(RE)
    return rs[0] if len(rs) == 1 else z3.Union(*rs)


def to_z3(a):
    k = a[0]
    if k == "lit":
        return z3.Re(z3.StringVal(a[1]))
    if k == "any":
        return z3.Full(RE)
    if k == "noslash":
        return z3.Diff(z3.AllChar(RE), z3.Re("/"))
    if k == "seq":
        return zcat(to_z3(x) for x in a[1])
    if k == "opt":
        return z3.Option(to_z3(a[1]))
    if k == "star":
        return z3.Star(to_z3(a[1]))
    raise ValueError(a)


def bash_glob(s):
    """`*` in a Bash rule matches any string, `/` and spaces included."""
    parts = s.split("*")
    out = [lit(parts[0])]
    for p in parts[1:]:
        out += [ANY, lit(p)]
    return seq(*out)


def path_glob(s):
    """gitignore-style path glob: `**/` any directories, `*` and `?` within one segment."""
    out, i, buf = [], 0, ""

    def flush():
        nonlocal buf
        if buf:
            out.append(lit(buf))
            buf = ""

    while i < len(s):
        if s.startswith("**/", i):
            flush()
            out.append(opt(seq(ANY, lit("/"))))
            i += 3
        elif s.startswith("/**", i) and i + 3 == len(s):
            flush()
            out += [lit("/"), ANY]
            i += 3
        elif s.startswith("**", i):
            flush()
            out.append(ANY)
            i += 2
        elif s[i] == "*":
            flush()
            out.append(("star", NOSLASH))
            i += 1
        elif s[i] == "?":
            flush()
            out.append(NOSLASH)
            i += 1
        else:
            buf += s[i]
            i += 1
    flush()
    return seq(*out)


# --- Rules

class BashRule:
    """`Bash`, `Bash(<exact>)`, `Bash(<prefix>:*)` or `Bash(<glob with *>)`.

    Two points of Claude Code's matcher are not pinned down, so each is a world flag:
      colon_loose: does `P:*` match `P<anything>` (no word boundary) or only `P` / `P ...`?
      space_loose: does a trailing ` *` (`P *`) also match a bare `P`?
    """

    def __init__(self, text):
        self.text = text
        spec = "*" if text == "Bash" else text[len("Bash("):-1]
        self.spec = spec
        if spec.endswith(":*"):
            self.form, self.head = "prefix", spec[:-2]
        elif spec.endswith(" *") and spec != " *":
            self.form, self.head = "space", spec[:-2]
        elif "*" in spec:
            self.form, self.head = "glob", spec
        else:
            self.form, self.head = "exact", spec
        self._z3 = {}
        self._py = {}

    def ast(self, colon_loose, space_loose):
        if self.form == "prefix":
            tail = ANY if colon_loose else opt(seq(lit(" "), ANY))
            return seq(bash_glob(self.head), tail)
        if self.form == "space":
            tail = seq(lit(" "), ANY)
            return seq(bash_glob(self.head), opt(tail) if space_loose else tail)
        if self.form == "glob":
            return bash_glob(self.spec)
        return lit(self.spec)

    def z3(self, loose):
        if loose not in self._z3:
            self._z3[loose] = to_z3(self.ast(loose, loose))
        return self._z3[loose]

    def matches(self, cmd, world):
        if world not in self._py:
            self._py[world] = re.compile(to_py(self.ast(*world)))
        return self._py[world].fullmatch(cmd) is not None

    def could_start(self, head):
        """Cheap prefilter: can a command beginning with `head` match at all?"""
        lp = self.head.split("*")[0] if self.form != "exact" else self.spec
        return lp.startswith(head) or head.startswith(lp)


def is_bash(rule):
    return rule == "Bash" or (rule.startswith("Bash(") and rule.endswith(")"))


def read_ast(rule):
    """Read() rule -> absolute path pattern, or None when outside the model.

    Only `Read` and `Read(//abs)` are modelled. `/x` (relative to the settings file),
    `~/x` and `./x` depend on where the session runs. Ignoring such a rule is safe for a
    deny (the check can only over-report), and an allow is never consulted, because Read
    needs no allow rule inside the session's directories.
    """
    if rule == "Read":
        return ANY
    if rule.startswith("Read(//") and rule.endswith(")"):
        return path_glob(rule[len("Read(/"):-1])
    return None


LISTS = ("allow", "deny", "ask", "additionalDirectories")


def load(path):
    """(permission lists, sandbox block) of one settings file."""
    try:
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
        perms = data.get("permissions", {})
        sandbox = data.get("sandbox", {})
    except (OSError, ValueError, AttributeError) as e:
        print(f"permcheck: cannot read {path}: {e}", file=sys.stderr)
        sys.exit(2)
    if not isinstance(sandbox, dict):
        sandbox = {}
    return {k: list(perms.get(k, [])) for k in LISTS}, sandbox


def sandbox_auto_allow(sandboxes):
    """True when the merged sandbox block auto-allows Bash. Later files override earlier
    ones key by key, as the project file overrides the user file."""
    merged = {}
    for s in sandboxes:
        merged.update(s)
    return merged.get("enabled") is True and merged.get("autoAllowBashIfSandboxed") is True


def merge(files, roots):
    """Union of every list; @ROOT@ expanded once per root, as `run` does for the bench."""
    merged = {k: [] for k in LISTS}
    for perms in files:
        for k, rules in perms.items():
            for r in rules:
                for x in ([r.replace("@ROOT@", root) for root in roots] if "@ROOT@" in r else [r]):
                    if x not in merged[k]:
                        merged[k].append(x)
    return merged


# --- (a) reads_protected

def char_class(chars):
    return zalt([z3.Range("a", "z"), z3.Range("A", "Z"), z3.Range("0", "9")]
                + [z3.Re(c) for c in chars])


# Witness characters: no quoting, expansion, redirection or command separators, so a
# witness is one plain command whose text is exactly what the matcher sees.
SAFE = char_class(" ._/-+=,:@%^{}")
PATHC = char_class("._/-+=,:@%^")


def zstr(name):
    return z3.String(name)


class Searcher:
    def __init__(self, merged, protected):
        self.allow = [BashRule(r) for r in merged["allow"] if is_bash(r)]
        self.deny = [BashRule(r) for r in merged["deny"] if is_bash(r)]
        self.ask = [BashRule(r) for r in merged["ask"] if is_bash(r)]
        # Protected paths as they can appear in a command: absolute, or relative from
        # anywhere, so any string whose tail matches the glob.
        self.paths = to_z3(seq(opt(seq(ANY, lit("/"))), path_glob(protected)))
        self.unknown = []

    def runs_unprompted(self, seg, rules):
        """Allowed by one of `rules` (loose reading), hit by no deny or ask (strict)."""
        blocked = zalt([r.z3(False) for r in self.deny + self.ask])
        return z3.And(z3.Or([z3.InRe(seg, r.z3(True)) for r in rules]),
                      z3.Not(z3.InRe(seg, blocked)))

    def solve(self, constraints, term):
        s = z3.Solver()
        s.set("timeout", Z3_TIMEOUT_MS)
        s.add(*constraints)
        res = s.check()
        if res == z3.sat:
            return s.model().eval(term, model_completion=True).as_string()
        if res == z3.unknown:
            raise Unverified(s.reason_unknown())
        return None

    def shapes(self, tool, rule):
        a, p, b, d, r = (zstr(x) for x in "apbdr")
        words = z3.Star(SAFE)
        args_before = z3.Option(z3.Concat(words, z3.Re(" ")))
        args_after = z3.Option(z3.Concat(z3.Re(" "), words))
        nonempty_path = z3.Concat(PATHC, z3.Star(PATHC))
        # A file, not a directory: keeps `cat dir/` (which reads nothing) out of witnesses.
        file_path = z3.Concat(z3.Star(PATHC), z3.Diff(PATHC, z3.Re("/")))
        head = z3.StringVal(tool + " ")

        # 1. The tool names the protected path; tried bare first for a readable witness.
        seg = z3.Concat(head, a, p, b)
        direct = [z3.InRe(p, z3.Intersect(self.paths, file_path)),
                  self.runs_unprompted(seg, [rule])]
        yield [a == "", b == ""] + direct, seg
        yield [z3.InRe(a, args_before), z3.InRe(b, args_after)] + direct, seg

        # 2. `cd` into the tree, then a relative path that no longer names all of it.
        cds = [x for x in self.allow if x.could_start("cd ")]
        if cds:
            cd = z3.Concat(z3.StringVal("cd "), d)
            seg = z3.Concat(head, a, r, b)
            yield [z3.InRe(d, file_path),
                   z3.InRe(r, z3.Intersect(file_path, z3.Concat(z3.Diff(PATHC, z3.Re("/")),
                                                                z3.Star(PATHC)))),
                   z3.InRe(z3.Concat(d, z3.StringVal("/"), r), self.paths),
                   z3.InRe(a, args_before), z3.InRe(b, args_after),
                   self.runs_unprompted(cd, cds), self.runs_unprompted(seg, [rule])], \
                z3.Concat(cd, z3.StringVal(" && "), seg)

        # 3. A recursive reader handed an ancestor directory of the protected path.
        letters = z3.Star(z3.Union(z3.Range("a", "z"), z3.Range("A", "Z")))
        recursive_flag = z3.Union(
            z3.Concat(z3.Re("-"), letters, z3.Union(z3.Re("r"), z3.Re("R")), letters),
            z3.Re("--recursive"))
        around = {
            "rg": (args_before, args_after), "ag": (args_before, args_after),
            "ack": (args_before, args_after),
            "find": (z3.Re(""), z3.Concat(args_after, z3.Re(" -exec cat {} +"))),
        }
        for g in ("grep", "egrep", "fgrep"):
            around[g] = (z3.Concat(args_before, recursive_flag, z3.Re(" "), args_before),
                         args_after)
        if tool in around:
            pre, post = around[tool]
            seg = z3.Concat(head, a, d, b)
            yield [z3.InRe(a, pre), z3.InRe(b, post), z3.InRe(d, nonempty_path),
                   z3.InRe(z3.Concat(d, z3.StringVal("/"), p), self.paths),
                   z3.InRe(p, z3.Star(PATHC)),
                   self.runs_unprompted(seg, [rule])], seg

    def bash_violations(self):
        out = []
        for tool in READ_TOOLS:
            for rule in self.allow:
                if not rule.could_start(tool + " "):
                    continue
                unknown = None
                for constraints, term in self.shapes(tool, rule):
                    try:
                        w = self.solve(constraints, term)
                    except Unverified as e:
                        unknown = str(e)
                        continue
                    if w is not None:
                        out.append({"kind": "reads_protected", "witness": w,
                                    "rule": rule.text})
                        break
                else:
                    # No shape gave a witness, but one could not be decided: not ok.
                    if unknown is not None:
                        out.append({"kind": "unverified", "witness": f"{tool} <path>",
                                    "rule": f"{rule.text} (z3: {unknown})"})
        return out


def read_violations(merged, protected, roots):
    denies = [x for x in (read_ast(r) for r in merged["deny"]) if x is not None]
    blocked = zalt([to_z3(x) for x in denies])
    rule = "Read" if "Read" in merged["allow"] else READ_DEFAULT
    out = []
    for root in roots:
        target = protected if protected.startswith("/") else root.rstrip("/") + "/" + protected
        p = zstr("p")
        s = z3.Solver()
        s.set("timeout", Z3_TIMEOUT_MS)
        s.add(z3.InRe(p, z3.Intersect(to_z3(path_glob(target)), z3.Star(PATHC))),
              z3.Not(z3.InRe(p, blocked)))
        res = s.check()
        if res == z3.sat:
            w = s.model().eval(p, model_completion=True).as_string()
            out.append({"kind": "reads_protected", "witness": f"Read({w})", "rule": rule})
        elif res == z3.unknown:
            out.append({"kind": "unverified", "witness": f"Read({target})",
                        "rule": f"z3: {s.reason_unknown()}"})
    return out


# --- (b) done_prompts

# `~` is not here: path scope resolves it (see path_args).
UNMODELLED = set("$`\\<>()&\n#*?[]{}!")


def split_compound(cmd):
    """Split on |, &&, ;, || outside quotes; anything the model cannot see through is
    Unverified (expansions, redirections, subshells, globs, background jobs)."""
    segs, cur, quote, i = [], "", None, 0
    while i < len(cmd):
        c = cmd[i]
        if quote == "'":
            quote = None if c == "'" else quote
        elif quote == '"':
            if c in "$`\\":
                raise Unverified(f"expansion inside double quotes: {c!r}")
            quote = None if c == '"' else quote
        elif c in "'\"":
            quote = c
        elif cmd.startswith(("&&", "||"), i):
            segs.append(cur)
            cur, i = "", i + 2
            continue
        elif c in "|;":
            segs.append(cur)
            cur, i = "", i + 1
            continue
        elif c in UNMODELLED:
            raise Unverified(f"shell syntax outside the model: {c!r}")
        cur += c
        i += 1
    if quote:
        raise Unverified("unterminated quote")
    segs.append(cur)
    segs = [s.strip() for s in segs]
    if any(not s for s in segs):
        raise Unverified("empty command segment")
    return segs


# --- Session context: path scope and permission mode (O3 findings 1 and 2).

# Observed under acceptEdits for `cp` only (O3 P4); the rest of the set is the spec's
# minimum. Kept narrow on purpose: an auto-approve the real session lacks is a false ok.
ACCEPT_EDITS_CMDS = {"cp", "mv", "mkdir", "touch"}
ASSIGNMENT = re.compile(r"[A-Za-z_][A-Za-z0-9_]*=")
IN_CWD = object()  # a relative path inside a cwd that was not stated


def norm(p):
    p = posixpath.normpath(p)
    return "/" + p.lstrip("/") if p.startswith("/") else p


def inside(p, d):
    """Containment on path-component boundaries: /a/bc is not inside /a/b."""
    return p == d or p.startswith(d.rstrip("/") + "/")


class Session:
    def __init__(self, cwd, home, dirs, mode, disabled, sandbox_auto=False):
        self.cwd = norm(cwd) if cwd else None
        self.home = home
        self.dirs = [d for d in (self.resolve(x, strict=False) for x in dirs)
                     if isinstance(d, str)]
        self.accept_edits = mode == "acceptEdits" and "accept-edits" not in disabled
        self.path_scope = "path-scope" not in disabled
        self.sandbox_auto = sandbox_auto and "sandbox" not in disabled
        self.env_assign = "env-assign" not in disabled

    def resolve(self, tok, strict=True):
        """Lexical: expand ~, join to the cwd, normalise `..`. No filesystem access."""
        if tok.startswith("~"):
            if tok != "~" and not tok.startswith("~/"):
                if strict:
                    raise Unverified(f"path scope: cannot expand {tok!r}")
                return None
            if not self.home:
                if strict:
                    raise Unverified("path scope: ~ with no home directory")
                return None
            return norm(self.home + tok[1:])
        if tok.startswith("/"):
            return norm(tok)
        if self.cwd:
            return norm(self.cwd + "/" + tok)
        rel = posixpath.normpath(tok)
        if rel == ".." or rel.startswith("../"):
            if strict:
                raise Unverified(f"path scope: {tok!r} escapes a cwd that was not given")
            return None
        return IN_CWD


def path_args(seg):
    """(command word, literal arguments that may name paths).

    A flag is skipped unless it carries `=value`, whose value is checked. A flag that
    glues a path to its letter (`-I/usr`) cannot be split reliably, so it is unverified.
    """
    try:
        toks = shlex.split(seg)
    except ValueError as e:
        raise Unverified(f"path scope: {e}") from e
    while toks and ASSIGNMENT.match(toks[0]):
        toks = toks[1:]
    if not toks:
        return "", []
    args = []
    for t in toks[1:]:
        if re.search(r"[=:]~", t):
            raise Unverified(f"path scope: tilde after = or : in {t!r}")
        if t.startswith("-"):
            if "=" in t:
                args.append(t.split("=", 1)[1])
            elif "/" in t or "~" in t:
                raise Unverified(f"path scope: cannot split flag {t!r}")
            continue
        args.append(t)
    return toks[0], [a for a in args if a]


def scope(seg, session):
    """(auto-approvable under acceptEdits, path outside the session's directories or None)."""
    cmd, args = path_args(seg)
    edit_cmd = session.accept_edits and cmd in ACCEPT_EDITS_CMDS
    if not session.path_scope and not edit_cmd:
        return False, None
    outside, in_cwd = None, True
    for a in args:
        p = session.resolve(a)
        if p is IN_CWD:
            continue
        here = session.cwd is not None and inside(p, session.cwd)
        in_cwd = in_cwd and here
        if not session.path_scope or here or any(inside(p, d) for d in session.dirs):
            continue
        if session.cwd is None:
            raise Unverified(f"path scope: {p} may be inside the cwd, which was not given")
        outside = outside or p
    return edit_cmd and in_cwd, outside


ENV_ASSIGN = "<env assignment>"
SANDBOX_AUTO = "<sandbox autoAllowBashIfSandboxed>"
ENV_ARG_FLAGS = {"-u", "--unset", "-C", "--chdir", "-S", "--split-string"}


def assigns_env(seg):
    """Does the segment set an environment variable for its command: `VAR=… cmd`, or
    `env [flags] VAR=… cmd`? Bare `env` and `env -u VAR cmd` set nothing."""
    try:
        toks = shlex.split(seg)
    except ValueError as e:
        raise Unverified(f"env assignment: {e}") from e
    if toks and ASSIGNMENT.match(toks[0]):
        return True
    if not toks or toks[0] != "env":
        return False
    i = 1
    while i < len(toks):
        t = toks[i]
        if ASSIGNMENT.match(t):
            return True
        if t in ENV_ARG_FLAGS:
            i += 2
            continue
        if not t.startswith("-"):
            return False  # the command word: no assignment before it
        i += 1
    return False


WORLDS = list(itertools.product([False, True], repeat=2))


def verdict(seg, merged, world, auto_edit, outside, env_assign=False, sandbox_auto=False):
    """('ok'|'prompt', rule) for one segment under one reading of the matcher.

    Order: deny/ask, then an env assignment (which prompts even when an allow rule
    matches), then path scope (which overrides an allow), then allow, then the
    acceptEdits and sandbox auto-approves (which stand in only for a missing allow rule).
    """
    rules = {k: [BashRule(r) for r in merged[k] if is_bash(r)] for k in ("allow", "deny", "ask")}
    for kind in ("deny", "ask"):
        hit = next((r for r in rules[kind] if r.matches(seg, world)), None)
        if hit:
            return "prompt", hit.text
    if env_assign:
        return "prompt", ENV_ASSIGN
    if outside:
        return "prompt", f"path-scope:{outside}"
    hit = next((r for r in rules["allow"] if r.matches(seg, world)), None)
    if hit:
        return "ok", hit.text
    if auto_edit:
        return "ok", "<acceptEdits>"
    if sandbox_auto:
        return "ok", SANDBOX_AUTO
    return "prompt", NO_ALLOW


def done_violations(merged, done_cmds, session):
    out = []
    for cmd in done_cmds:
        try:
            segs = split_compound(cmd)
        except Unverified as e:
            out.append({"kind": "unverified", "witness": cmd, "rule": str(e)})
            continue
        for seg in segs:
            try:
                auto_edit, outside = scope(seg, session)
                env_assign = session.env_assign and assigns_env(seg)
            except Unverified as e:
                out.append({"kind": "unverified", "witness": seg, "rule": str(e)})
                continue
            results = {w: verdict(seg, merged, w, auto_edit, outside, env_assign,
                                  session.sandbox_auto) for w in WORLDS}
            outcomes = {o for o, _ in results.values()}
            if outcomes == {"ok"}:
                continue
            if outcomes == {"prompt"}:
                out.append({"kind": "done_prompts", "witness": seg,
                            "rule": results[(False, False)][1]})
                continue
            # The worlds disagree: name the rule whose reading decides it.
            rules = [BashRule(r) for k in ("deny", "ask", "allow") for r in merged[k] if is_bash(r)]
            pivot = next(r for r in rules if len({r.matches(seg, w) for w in WORLDS}) > 1)
            out.append({"kind": "unverified", "witness": seg, "rule": pivot.text})
    return out


def main(argv):
    ap = argparse.ArgumentParser(prog="permcheck")
    ap.add_argument("--settings", required=True)
    ap.add_argument("--project", required=True)
    ap.add_argument("--protected", required=True, nargs="+", action="extend")
    ap.add_argument("--done-cmd", nargs="+", action="extend", default=[])
    ap.add_argument("--root", action="append", default=[],
                    help="value(s) @ROOT@ expands to; default: the symbolic root /@ROOT@")
    ap.add_argument("--mode", default="acceptEdits",
                    help="session permission mode (default acceptEdits, as fleet spawn); "
                         "any mode other than acceptEdits is judged as default")
    ap.add_argument("--cwd", help="the session's working directory; never inferred")
    ap.add_argument("--home", default=os.environ.get("HOME"),
                    help="what ~ expands to (default: $HOME)")
    args = ap.parse_args(argv)
    roots = args.root or ["/@ROOT@"]

    loaded = [load(args.settings), load(args.project)]
    merged = merge([perms for perms, _ in loaded], roots)
    # Selftest-only switch: proves each rule does work by turning it off.
    disabled = set(filter(None, os.environ.get("PERMCHECK_DISABLE", "").split(",")))
    session = Session(args.cwd, args.home, merged["additionalDirectories"], args.mode, disabled,
                      sandbox_auto_allow([sb for _, sb in loaded]))
    violations = []
    for glob in dict.fromkeys(args.protected):
        violations += Searcher(merged, glob).bash_violations()
        violations += read_violations(merged, glob, roots)
    violations += done_violations(merged, args.done_cmd, session)

    coverage = list(COVERAGE)
    if session.path_scope:
        coverage.append("path-scope: a literal path argument outside the cwd and "
                        "additionalDirectories prompts, even when allowed; unverified "
                        "when --cwd is not given and the path could be inside it")
    if session.accept_edits:
        coverage.append("acceptEdits: cp/mv/mkdir/touch with every path inside the cwd "
                        "need no allow rule (observed once, mechanism unverified)")
    if session.env_assign:
        coverage.append("env-assign: a command that assigns an environment variable "
                        "(VAR=... cmd, or env VAR=... cmd) prompts even when an allow rule "
                        "matches (observed in O6 Q4/Q5/Q7/Q8 under sandbox settings, one "
                        "sample each; mechanism unverified)")
    if session.sandbox_auto:
        coverage.append("sandbox: with sandbox.enabled and autoAllowBashIfSandboxed, a "
                        "command no allow rule matches runs unprompted; deny, ask, path "
                        "scope and env-assign still prompt (observed in O6 Q1/Q6, one "
                        "sample each; mechanism unverified). Done-cmds only: the "
                        "reads_protected search does not model it or sandbox.filesystem")
    coverage.append("mode: only acceptEdits is modelled; every other mode is judged as default")
    ok = not violations
    print(json.dumps({"ok": ok, "violations": violations, "model_coverage": coverage}))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
