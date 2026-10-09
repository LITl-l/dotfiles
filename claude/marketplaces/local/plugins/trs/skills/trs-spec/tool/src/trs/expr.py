"""条件式の言語 (CEL のサブセット + 含意 `=>`)。

    expr    := implies
    implies := or ( "=>" implies )?          # 右結合
    or      := and ( "||" and )*
    and     := unary ( "&&" unary )*
    unary   := "!" unary | "(" expr ")" | "true" | "false" | cmp
    cmp     := IDENT ( "==" | "!=" ) STRING
             | IDENT "in" "[" STRING ( "," STRING )* "]"

IDENT は因子・結果の id ([A-Za-z_][A-Za-z0-9_]*)、STRING は "..." (日本語可)。
同じ AST から (1) Python の評価器 と (2) Z3 の式 の両方を作る。
2つの解釈が食い違わないことは checks.self_check で機械的に照合する。
"""
from __future__ import annotations

import re
from dataclasses import dataclass

_TOKEN = re.compile(
    r'\s*(=>|&&|\|\||==|!=|!|\(|\)|\[|\]|,|"(?:[^"\\]|\\.)*"|[A-Za-z_][A-Za-z0-9_]*)'
)


class ExprError(ValueError):
    pass


@dataclass(frozen=True)
class Expr:
    src: str
    ast: tuple

    @property
    def vars(self) -> list:
        out = []
        for a in atoms(self.ast):
            if a[1] not in out:
                out.append(a[1])
        return out

    def values(self) -> list:
        """[(var, value)] — 参照している水準の一覧 (検証用)"""
        out = []
        for a in atoms(self.ast):
            vals = a[2] if a[0] == "in" else (a[2],)
            out.extend((a[1], v) for v in vals)
        return out

    def eval(self, env: dict) -> bool:
        return _eval(self.ast, env)

    def z3(self, zv: dict):
        return _z3(self.ast, zv)


TRUE = Expr("true", ("true",))


def parse(src: str) -> Expr:
    src = (src or "").strip()
    if not src:
        raise ExprError("空の式です")
    toks, pos = [], 0
    while pos < len(src):
        m = _TOKEN.match(src, pos)
        if not m or m.end() == pos:
            raise ExprError(f"字句解析できません: {src[pos:]!r}")
        toks.append(m.group(1))
        pos = m.end()
        while pos < len(src) and src[pos].isspace():
            pos += 1
    p = _Parser(toks)
    ast = p.implies()
    if p.i != len(toks):
        raise ExprError(f"余分なトークン: {' '.join(toks[p.i:])}")
    return Expr(src, ast)


class _Parser:
    def __init__(self, toks):
        self.t, self.i = toks, 0

    def peek(self):
        return self.t[self.i] if self.i < len(self.t) else None

    def eat(self, want=None):
        tok = self.peek()
        if tok is None:
            raise ExprError("式が途中で終わっています")
        if want is not None and tok != want:
            raise ExprError(f"'{want}' が必要です (got {tok!r})")
        self.i += 1
        return tok

    def implies(self):
        left = self.or_()
        if self.peek() == "=>":
            self.eat()
            return ("imp", left, self.implies())
        return left

    def or_(self):
        n = self.and_()
        while self.peek() == "||":
            self.eat()
            n = ("or", n, self.and_())
        return n

    def and_(self):
        n = self.unary()
        while self.peek() == "&&":
            self.eat()
            n = ("and", n, self.unary())
        return n

    def unary(self):
        tok = self.peek()
        if tok == "!":
            self.eat()
            return ("not", self.unary())
        if tok == "(":
            self.eat()
            n = self.implies()
            self.eat(")")
            return n
        if tok in ("true", "false"):
            self.eat()
            return (tok,)
        return self.cmp()

    def string(self):
        tok = self.eat()
        if not (tok.startswith('"') and tok.endswith('"')):
            raise ExprError(f'文字列 "..." が必要です (got {tok!r})')
        return bytes(tok[1:-1], "utf-8").decode("unicode_escape") if "\\" in tok else tok[1:-1]

    def cmp(self):
        var = self.eat()
        if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", var) or var in ("in", "true", "false"):
            raise ExprError(f"識別子が必要です (got {var!r})")
        op = self.eat()
        if op in ("==", "!="):
            return ("eq" if op == "==" else "ne", var, self.string())
        if op == "in":
            self.eat("[")
            vals = [self.string()]
            while self.peek() == ",":
                self.eat()
                vals.append(self.string())
            self.eat("]")
            return ("in", var, tuple(vals))
        raise ExprError(f"==, !=, in のいずれかが必要です (got {op!r})")


def atoms(n):
    k = n[0]
    if k in ("eq", "ne", "in"):
        yield n
    elif k == "not":
        yield from atoms(n[1])
    elif k in ("and", "or", "imp"):
        yield from atoms(n[1])
        yield from atoms(n[2])


def _eval(n, env):
    k = n[0]
    if k == "true":
        return True
    if k == "false":
        return False
    if k == "eq":
        return env[n[1]] == n[2]
    if k == "ne":
        return env[n[1]] != n[2]
    if k == "in":
        return env[n[1]] in n[2]
    if k == "not":
        return not _eval(n[1], env)
    if k == "and":
        return _eval(n[1], env) and _eval(n[2], env)
    if k == "or":
        return _eval(n[1], env) or _eval(n[2], env)
    if k == "imp":
        return (not _eval(n[1], env)) or _eval(n[2], env)
    raise AssertionError(k)


def _z3(n, zv):
    import z3

    k = n[0]
    if k == "true":
        return z3.BoolVal(True)
    if k == "false":
        return z3.BoolVal(False)
    if k in ("eq", "ne", "in"):
        var, consts = zv[n[1]]
        if k == "eq":
            return var == consts[n[2]]
        if k == "ne":
            return var != consts[n[2]]
        return z3.Or([var == consts[v] for v in n[2]])
    if k == "not":
        return z3.Not(_z3(n[1], zv))
    if k == "and":
        return z3.And(_z3(n[1], zv), _z3(n[2], zv))
    if k == "or":
        return z3.Or(_z3(n[1], zv), _z3(n[2], zv))
    if k == "imp":
        return z3.Implies(_z3(n[1], zv), _z3(n[2], zv))
    raise AssertionError(k)
