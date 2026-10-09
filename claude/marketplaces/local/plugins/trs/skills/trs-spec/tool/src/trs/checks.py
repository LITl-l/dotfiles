"""TRS の検査。

S***: 構造・参照整合性・根拠 (Python で決定的に検査)
Z***: 意味的な検査 (Z3)。空虚な AC / 未定義の入力領域 / AC 間の矛盾 / 規則違反 / 死んだ水準
X***: 検査器自身の検査 (評価器と Z3 変換の食い違い)
"""
from __future__ import annotations

import itertools
import re
from collections import Counter

from .model import CLASSES, Finding, Spec, assumptions_for, blocked_reasons

BASIS_ID_RE = re.compile(r"\b(SRC-\d+|OI-\d+)\b")
CODE_REF_RE = re.compile(
    r"(\b(src|lib|app|pkg|internal|cmd|frontend|backend|server|client)/"
    r"|\.(tsx?|jsx?|mjs|py|go|rs|java|kt|rb|php|cs|swift|vue|svelte|sql)\b"
    r"|#L\d+|/blob/|/tree/|実装|コード)"
)
GAP_LIMIT = 50
SELF_CHECK_LIMIT = 3000


# ---------------------------------------------------------------------------
# Z3 エンコーダ
# ---------------------------------------------------------------------------
_SEQ = itertools.count()


class Enc:
    def __init__(self, spec: Spec):
        import z3

        self.z3 = z3
        n = next(_SEQ)
        self.zv, self.rev = {}, {}
        for var in list(spec.factors) + list(spec.outcomes):
            levels = spec.domain(var)
            sort, consts = z3.EnumSort(f"S{n}_{var}", [f"{var}={lv}#{n}" for lv in levels])
            c = z3.Const(f"{var}#{n}", sort)
            self.zv[var] = (c, dict(zip(levels, consts)))
            self.rev[var] = {consts[i].decl().name(): lv for i, lv in enumerate(levels)}

    def eqs(self, assign: dict):
        z3 = self.z3
        parts = []
        for v, val in assign.items():
            c, consts = self.zv[v]
            vals = val if isinstance(val, tuple) else (val,)
            parts.append(z3.Or([c == consts[x] for x in vals]))
        return z3.And(parts)

    def value(self, model, var):
        c = model.eval(self.zv[var][0], model_completion=True)
        return self.rev[var][c.decl().name()]

    def sat(self, *fs):
        s = self.z3.Solver()
        s.add(*fs)
        r = s.check()
        return (s.model() if r == self.z3.sat else None), r == self.z3.sat


def fmt(assign: dict, keep_order=None) -> str:
    keys = keep_order or list(assign)
    parts = []
    for k in keys:
        if k not in assign:
            continue
        v = assign[k]
        if isinstance(v, tuple) and len(v) > 1:
            parts.append(f"{k} in [" + ", ".join(f'"{x}"' for x in v) + "]")
        else:
            parts.append(f'{k} == "{v[0] if isinstance(v, tuple) else v}"')
    return " && ".join(parts) if parts else "true"


# ---------------------------------------------------------------------------
# 構造検査
# ---------------------------------------------------------------------------
def static_checks(spec: Spec) -> list:
    F = []
    E = lambda code, where, msg: F.append(Finding("E", code, where, msg))
    W = lambda code, where, msg: F.append(Finding("W", code, where, msg))
    raw = spec.raw

    # 重複
    for name, items in (("sources", raw["sources"]), ("factors", raw.get("factors", [])),
                        ("outcomes", raw["outcomes"]), ("assumptions", raw.get("assumptions", [])),
                        ("rules", raw.get("rules", [])), ("stories", raw.get("stories", [])),
                        ("use_cases", raw["use_cases"]), ("open_issues", raw.get("open_issues", []))):
        for k, n in Counter(i["id"] for i in items).items():
            if n > 1:
                E("S020", name, f"id が重複しています: {k}")
    for uc in spec.use_cases:
        for k, n in Counter(a.id for a in uc.acs).items():
            if n > 1:
                E("S020", uc.id, f"AC id が重複しています: {k}")
    for k in set(spec.factors) & set(spec.outcomes):
        E("S021", k, "因子と結果で同じ id は使えません")

    src_ids = {s["id"] for s in raw["sources"]}
    ois = {i["id"]: i for i, _ in spec.issues}

    def basis(where, items):
        for b in items:
            if CODE_REF_RE.search(b):
                E("S031", where, f"根拠が実装を指しているように見えます: {b!r} (期待値の根拠は仕様書とデザイン)")
            ids = BASIS_ID_RE.findall(b)
            if not ids:
                E("S032", where, f"根拠に SRC-n / OI-n の参照がありません: {b!r}")
            for i in ids:
                if i.startswith("SRC-") and i not in src_ids:
                    E("S033", where, f"根拠資料に {i} がありません")
                if i.startswith("OI-"):
                    if i not in ois:
                        E("S033", where, f"Open Issues に {i} がありません")
                    elif ois[i]["status"] != "resolved":
                        E("S034", where, f"{i} は未解決なので根拠にできません")

    for s in raw["sources"]:
        if CODE_REF_RE.search(s["ref"]):
            E("S030", s["id"], "根拠資料が実装を指しているように見えます")
    for f in spec.factors.values():
        basis(f["id"], f["basis"])
    for a, _ in spec.assumptions:
        basis(a["id"], a["basis"])
    for r, _ in spec.rules:
        basis(r["id"], r["basis"])

    def check_expr(where, e, allowed: set, kind: str):
        if e is None:
            return
        for v in e.vars:
            if v not in allowed:
                E("S041", where, f"{kind}で使えない変数 {v!r} (使えるのは {sorted(allowed)})")
        for v, val in e.values():
            if v in allowed and val not in spec.domain(v):
                E("S042", where, f"{v} に水準 {val!r} はありません (水準: {spec.domain(v)})")

    story_ids = {s["id"] for s in raw.get("stories", [])}
    for uc in spec.use_cases:
        if story_ids and uc.story not in story_ids:
            E("S040", uc.id, f"ストーリー {uc.story} がありません")
        for v in uc.inputs:
            if v not in spec.factors:
                E("S040", uc.id, f"入力 {v!r} が因子にありません")
        for a in uc.acs:
            where = a.full_id
            basis(where, a.raw["basis"])
            check_expr(where + "/pre", a.pre, set(uc.inputs), "事前条件")
            for k, v in a.post.items():
                if k not in spec.outcomes:
                    E("S043", where, f"post のキー {k!r} が結果にありません")
                elif v not in spec.outcomes[k]["levels"]:
                    E("S043", where, f"{k} に水準 {v!r} はありません (水準: {spec.outcomes[k]['levels']})")
            if not a.raw.get("then"):
                W("S044", where, "then (期待結果の説明文) がありません")
            if "tla_witness" in a.raw and "tla" not in raw:
                E("S070", where, "tla_witness があるのに tla (module/config) がありません")
        # 3分類の枠
        have = Counter(a.cls for a in uc.acs)
        for cls in CLASSES:
            v = uc.scope[cls]
            if v == "未検討":
                E("S050", f"{uc.id}/{cls}", "未検討です。検討して あり / なし を明示する")
            elif v == "あり" and have[cls] == 0:
                E("S051", f"{uc.id}/{cls}", "あり なのに該当 AC がありません")
            elif v == "なし" and have[cls] > 0:
                E("S052", f"{uc.id}/{cls}", f"なし なのに AC が {have[cls]} 本あります")

    allv = set(spec.factors) | set(spec.outcomes)
    for r, e in spec.rules:
        check_expr(r["id"], e, allv, "規則")
        if "tla" in r and "tla" not in raw:
            E("S070", r["id"], "tla 規則があるのに tla (module/config) がありません")
    uc_ids = {u.id for u in spec.use_cases}
    for a, e in spec.assumptions:
        check_expr(a["id"], e, set(spec.factors), "前提")
        for u in a.get("use_cases", []):
            if u not in uc_ids:
                E("S045", a["id"], f"use_cases に {u} がありません")

    ac_ids = {a.full_id for a in spec.all_acs()}
    for i, e in spec.issues:
        for t in i.get("affects", []):
            if t not in ac_ids and t not in spec.factors:
                E("S046", i["id"], f"affects {t!r} が AC にも因子にもありません")
        if i["status"] == "resolved" and not i.get("resolution"):
            E("S047", i["id"], "resolved なのに resolution がありません (履歴として残す)")
        if "region" in i:
            uc = next((u for u in spec.use_cases if u.id == i.get("use_case")), None)
            if uc is None:
                E("S048", i["id"], "region には use_case の指定が必要です")
            else:
                check_expr(i["id"] + "/region", e, set(uc.inputs), "region")

    used = {v for u in spec.use_cases for v in u.inputs}
    for f in spec.factors.values():
        if f["id"] not in used:
            W("S060", f["id"], "どの UC の入力にも使われていません")
        if f["status"] == "tentative" and not any(
                i["status"] == "open" and f["id"] in i.get("affects", []) for i, _ in spec.issues):
            W("S061", f["id"], "tentative なのに open な Open Issue の affects にありません")
    return F


# ---------------------------------------------------------------------------
# 意味検査 (Z3)
# ---------------------------------------------------------------------------
def semantic_checks(spec: Spec) -> list:
    F = []
    E = lambda code, where, msg: F.append(Finding("E", code, where, msg))
    W = lambda code, where, msg: F.append(Finding("W", code, where, msg))
    I = lambda code, where, msg: F.append(Finding("I", code, where, msg))
    enc = Enc(spec)
    z3 = enc.z3
    rule_applied = Counter()
    rule_antecedent_sat = Counter()

    for uc in spec.use_cases:
        acs = [a for a in uc.acs if a.pre is not None]
        assume = z3.And([e.z3(enc.zv) for _, e in assumptions_for(spec, uc)] or [z3.BoolVal(True)])
        pres = {a.full_id: a.pre.z3(enc.zv) for a in acs}

        # X001: 評価器と Z3 変換の照合
        F.extend(self_check(spec, uc, enc))

        # Z050: 死んだ水準
        for v in uc.inputs:
            for lv in spec.domain(v):
                _, ok = enc.sat(assume, enc.eqs({v: lv}))
                if not ok:
                    W("Z050", f"{uc.id}/{v}", f"水準 {lv!r} は前提によりこの UC では起こりえません (意図通りか確認)")

        # Z010: 空虚な AC
        for a in acs:
            _, ok = enc.sat(assume, pres[a.full_id])
            if not ok:
                E("Z010", a.full_id, "事前条件を満たす入力がありません (前提と矛盾し、この AC は空虚)")

        # Z030/Z031: AC 間の重なり
        for a, b in itertools.combinations(acs, 2):
            m, ok = enc.sat(assume, pres[a.full_id], pres[b.full_id])
            if not ok:
                continue
            w = {v: enc.value(m, v) for v in uc.inputs}
            diff = {k for k in set(a.post) & set(b.post) if a.post[k] != b.post[k]}
            if diff:
                E("Z030", f"{a.full_id} × {b.full_id}",
                  f"事前条件が重なり、結果 {sorted(diff)} が食い違います。例: {fmt(w)}")
            else:
                W("Z031", f"{a.full_id} × {b.full_id}",
                  f"事前条件が重なっています (結果は同じ)。どちらの AC が担当するか曖昧です。例: {fmt(w)}")

        # Z060: open な OI の region と AC の重なり
        oi_regions = []
        for i, e in spec.issues:
            if e is not None and i.get("use_case") == uc.id and i["status"] == "open":
                oi_regions.append((i, e.z3(enc.zv)))
                for a in acs:
                    m, ok = enc.sat(assume, pres[a.full_id], oi_regions[-1][1])
                    if ok:
                        E("Z060", a.full_id, f"{i['id']} で未定義とした領域の振る舞いを規定しています。"
                                             f"例: {fmt({v: enc.value(m, v) for v in uc.inputs})}")

        # Z020: 未定義の入力領域
        covered = z3.Or(list(pres.values())) if pres else z3.BoolVal(False)
        for cube in gap_cubes(enc, uc.inputs, assume, covered):
            cz = enc.eqs(cube) if cube else z3.BoolVal(True)
            known = next((i for i, rz in oi_regions if not enc.sat(assume, cz, z3.Not(rz))[1]), None)
            if known:
                I("Z021", uc.id, f"未定義 (既知: {known['id']}): {fmt(cube, uc.inputs)}")
            else:
                E("Z020", uc.id, f"どの AC にも当たらない入力があります: {fmt(cube, uc.inputs)} — "
                                 f"AC を追加する / 前提 (起こりえない) にする / Open Issue (region) にする")

        # Z040: 規則
        for r, e in spec.rules:
            if e is None:
                continue
            fvars = [v for v in e.vars if v in spec.factors]
            if not all(v in uc.inputs for v in fvars):
                continue
            rule_applied[r["id"]] += 1
            rz = e.z3(enc.zv)
            if e.ast[0] == "imp":
                from .expr import Expr
                ant = Expr("", e.ast[1]).z3(enc.zv)
                if enc.sat(assume, ant)[1]:
                    rule_antecedent_sat[r["id"]] += 1
            for a in acs:
                m, ok = enc.sat(assume, pres[a.full_id], enc.eqs(a.post), z3.Not(rz))
                if ok:
                    w = {v: enc.value(m, v) for v in uc.inputs}
                    missing = [v for v in e.vars if v in spec.outcomes and v not in a.post]
                    hint = f" (この AC は結果 {missing} を規定していません)" if missing else ""
                    E("Z040", a.full_id, f"{r['id']} に違反します{hint}。例: {fmt(w)}")

    for r, e in spec.rules:
        if e is None:
            continue
        if rule_applied[r["id"]] == 0:
            W("Z042", r["id"], "どの UC にも適用されません (因子がそろう UC がない)")
        elif e.ast[0] == "imp" and rule_antecedent_sat[r["id"]] == 0:
            W("Z043", r["id"], "前件がどの UC でも成り立たず、規則が空虚です")
    return F


def gap_cubes(enc: Enc, inputs, assume, covered):
    """未定義領域を部分割り当て (cube) の集合として列挙する。

    モデルを1つ取り、各入力について「その入力を任意にしても領域全体が未定義のままか」を
    Z3 に問い、任意にできる入力を外して一般化する。"""
    z3 = enc.z3
    s = z3.Solver()
    s.add(assume, z3.Not(covered))
    out = []
    while len(out) < GAP_LIMIT and s.check() == z3.sat:
        m = s.model()
        cube = {v: enc.value(m, v) for v in inputs}
        for v in inputs:
            trial = {k: c for k, c in cube.items() if k != v}
            tz = enc.eqs(trial) if trial else z3.BoolVal(True)
            if not enc.sat(assume, tz, covered)[1]:
                cube = trial
        out.append(cube)
        s.add(z3.Not(enc.eqs(cube)) if cube else z3.BoolVal(False))
    return sorted(_merge(out, inputs), key=lambda c: fmt(c, inputs))


def _merge(cubes, inputs):
    """1つの変数だけが異なる cube をまとめる (表示を読みやすくするため。領域は変わらない)。"""
    cubes = [{k: (v if isinstance(v, tuple) else (v,)) for k, v in c.items()} for c in cubes]
    changed = True
    while changed:
        changed = False
        for v in inputs:
            groups = {}
            for c in cubes:
                if v not in c:
                    groups.setdefault(("_", id(c)), [c])
                    continue
                key = (frozenset(c), tuple(sorted((k, x) for k, x in c.items() if k != v)))
                groups.setdefault(key, []).append(c)
            nxt = []
            for g in groups.values():
                if len(g) == 1:
                    nxt.append(g[0])
                    continue
                m = dict(g[0])
                m[v] = tuple(sorted({x for c in g for x in c[v]}, key=lambda x: str(x)))
                nxt.append(m)
                changed = True
            cubes = nxt
    return cubes


def self_check(spec: Spec, uc, enc: Enc) -> list:
    """同じ AST の2つの解釈 (Python 評価器 / Z3) が一致することを有限領域で照合する。"""
    z3 = enc.z3
    exprs = [(a.full_id, a.pre) for a in uc.acs if a.pre is not None]
    exprs += [(r["id"], e) for r, e in assumptions_for(spec, uc)]
    domains = [spec.domain(v) for v in uc.inputs]
    out = []
    for n, combo in enumerate(itertools.product(*domains)):
        if n >= SELF_CHECK_LIMIT:
            break
        env = dict(zip(uc.inputs, combo))
        subs = [(enc.zv[v][0], enc.zv[v][1][val]) for v, val in env.items()]
        for name, e in exprs:
            py = e.eval(env)
            zz = z3.is_true(z3.simplify(z3.substitute(e.z3(enc.zv), *subs)))
            if py != zz:
                out.append(Finding("E", "X001", name, f"評価器と Z3 変換が食い違います: {env} (検査器のバグ)"))
                return out
    return out


def summary(spec: Spec) -> Finding:
    acs = list(spec.all_acs())
    c = Counter(a.cls for a in acs)
    blocked = [a for a in acs if blocked_reasons(spec, a)]
    open_oi = sum(1 for i, _ in spec.issues if i["status"] == "open")
    return Finding("I", "I000", spec.id, "AC {} 本 (正常 {} / 準正常 {} / 例外 {}), ブロック中 {} 本, open な Issue {} 件".format(
        len(acs), c["正常"], c["準正常"], c["例外"], len(blocked), open_oi))


def run_all(spec: Spec) -> list:
    F = list(spec.parse_findings)
    F += static_checks(spec)
    if not any(f.severity == "E" and f.code in ("S010", "S041", "S042", "S043", "S040") for f in F):
        F += semantic_checks(spec)
    else:
        F.append(Finding("I", "I001", spec.id, "式・参照のエラーがあるため Z3 による意味検査を省略しました"))
    for a in spec.all_acs():
        r = blocked_reasons(spec, a)
        if r:
            F.append(Finding("I", "I090", a.full_id, "ブロック中 — " + ", ".join(r)))
    F.append(summary(spec))
    return F
