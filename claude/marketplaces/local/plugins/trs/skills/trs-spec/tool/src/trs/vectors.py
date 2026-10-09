"""テストベクタの決定的な生成。

ベクタ = (AC, 入力の割り当て, 期待結果)。どの言語のテストからも読める JSON にする。
ベクタ ID は「AC の完全 ID + 入力の内容ハッシュ」なので、水準の並び順を変えても
同じ入力のベクタの ID は変わらない (テスト側の参照が壊れない)。
"""
from __future__ import annotations

import hashlib
import itertools
import json

from .model import Spec, assumptions_for, blocked_reasons

ENUM_CAP = 200_000
FORMAT = "trs-vectors/v1"


class GenError(ValueError):
    pass


def vector_id(ac_full_id: str, inputs: dict) -> str:
    h = hashlib.sha256(json.dumps(inputs, ensure_ascii=False, sort_keys=True).encode("utf-8")).hexdigest()[:8]
    return f"{ac_full_id}#{h}"


def region(spec: Spec, ac):
    uc = ac.uc
    domains = [spec.domain(v) for v in uc.inputs]
    size = 1
    for d in domains:
        size *= len(d)
    if size > ENUM_CAP:
        raise GenError(f"{uc.id} の入力空間 {size} が上限 {ENUM_CAP} を超えます。UC を分割してください")
    assume = [e for _, e in assumptions_for(spec, uc)]
    out = []
    for combo in itertools.product(*domains):
        env = dict(zip(uc.inputs, combo))
        if all(e.eval(env) for e in assume) and ac.pre.eval(env):
            out.append(combo)
    return out


def pairwise(valid, k):
    """決定的な貪欲法による 2 因子網羅。同点は列挙順 (水準の記載順) で先勝ち。"""
    if k <= 1:
        return list(valid)
    idx = list(itertools.combinations(range(k), 2))
    pairs = lambda c: {(i, c[i], j, c[j]) for i, j in idx}
    uncovered = set().union(*(pairs(c) for c in valid)) if valid else set()
    chosen, remaining = [], list(valid)
    while uncovered:
        best, gain = None, 0
        for c in remaining:
            g = len(pairs(c) & uncovered)
            if g > gain:
                best, gain = c, g
        if best is None:
            break
        chosen.append(best)
        remaining.remove(best)
        uncovered -= pairs(best)
    return chosen


def generate(spec: Spec) -> dict:
    vectors, blocked, stats = [], [], []
    for ac in spec.all_acs():
        reasons = blocked_reasons(spec, ac)
        if reasons:
            blocked.append({"ac": ac.full_id, "reasons": reasons})
            continue
        valid = region(spec, ac)
        rows = valid if ac.coverage == "all" else pairwise(valid, len(ac.uc.inputs))
        for combo in rows:
            inputs = dict(zip(ac.uc.inputs, combo))
            vectors.append({
                "id": vector_id(ac.full_id, inputs),
                "ac": ac.full_id,
                "class": ac.cls,
                "inputs": inputs,
                "expect": dict(ac.post),
            })
        stats.append({"ac": ac.full_id, "coverage": ac.coverage, "region": len(valid), "vectors": len(rows)})
    return {
        "format": FORMAT,
        "spec": spec.id,
        "spec_sha256": spec.sha256,
        "vectors": vectors,
        "blocked": blocked,
        "stats": stats,
    }


def dumps(doc: dict) -> str:
    return json.dumps(doc, ensure_ascii=False, indent=2, sort_keys=False) + "\n"
