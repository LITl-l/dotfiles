"""trs.yaml の読み込みと、検査・生成が使うモデル。"""
from __future__ import annotations

import hashlib
import json
import re
from dataclasses import dataclass, field
from pathlib import Path

import yaml

from .expr import Expr, ExprError, parse

SCHEMA_PATH = Path(__file__).resolve().parent / "schema" / "trs.schema.json"
AC_ID_RE = re.compile(r"^AC-(基本|代替|例外)(準正常|正常|例外)-(\d{3})$")
CLASSES = ("正常", "準正常", "例外")


@dataclass
class Finding:
    severity: str  # E / W / I
    code: str
    where: str
    message: str

    def as_dict(self):
        return {"severity": self.severity, "code": self.code, "where": self.where, "message": self.message}


@dataclass
class AC:
    uc: "UseCase"
    raw: dict
    id: str
    full_id: str
    flow: str
    cls: str
    pre: Expr | None
    post: dict
    coverage: str


@dataclass
class UseCase:
    raw: dict
    id: str
    story: str
    inputs: list
    scope: dict
    acs: list = field(default_factory=list)

    @property
    def prefix(self):
        return f"{self.story}_{self.id}"


@dataclass
class Spec:
    path: Path
    raw: dict
    sha256: str
    factors: dict
    outcomes: dict
    use_cases: list
    assumptions: list  # [(raw, Expr|None)]
    rules: list  # [(raw, Expr|None)]
    issues: list  # [(raw, Expr|None)]
    parse_findings: list

    @property
    def id(self):
        return self.raw["id"]

    @property
    def dir(self):
        return self.path.parent

    @property
    def out_dir(self):
        return self.dir / "generated"

    def all_acs(self):
        for uc in self.use_cases:
            yield from uc.acs

    def domain(self, var):
        if var in self.factors:
            return self.factors[var]["levels"]
        return self.outcomes[var]["levels"]


def canonical_sha256(raw: dict) -> str:
    """YAML の書式 (コメント・空白・キー順) に依存しない内容ハッシュ。"""
    return hashlib.sha256(json.dumps(raw, ensure_ascii=False, sort_keys=True).encode("utf-8")).hexdigest()


def schema_errors(raw) -> list:
    import jsonschema

    schema = json.loads(SCHEMA_PATH.read_text(encoding="utf-8"))
    v = jsonschema.Draft202012Validator(schema)
    out = []
    for e in sorted(v.iter_errors(raw), key=lambda e: list(e.absolute_path)):
        where = "/".join(str(p) for p in e.absolute_path) or "(root)"
        out.append(Finding("E", "S000", where, f"スキーマ違反: {e.message}"))
    return out


def load(path) -> tuple[Spec | None, list]:
    path = Path(path).resolve()
    raw = yaml.safe_load(path.read_text(encoding="utf-8"))
    errs = schema_errors(raw)
    if errs:
        return None, errs

    pf = []

    def p(src, where):
        try:
            return parse(src)
        except ExprError as e:
            pf.append(Finding("E", "S010", where, f"式を解析できません: {e} — {src!r}"))
            return None

    factors = {f["id"]: f for f in raw.get("factors", [])}
    outcomes = {o["id"]: o for o in raw.get("outcomes", [])}
    ucs = []
    for u in raw["use_cases"]:
        uc = UseCase(raw=u, id=u["id"], story=u["story"], inputs=list(u["inputs"]), scope=u["scope"])
        for a in u["acs"]:
            m = AC_ID_RE.match(a["id"])
            uc.acs.append(AC(
                uc=uc, raw=a, id=a["id"], full_id=f"{uc.prefix}_{a['id']}",
                flow=m.group(1), cls=m.group(2),
                pre=p(a["pre"], f"{uc.id}/{a['id']}/pre"),
                post=dict(a["post"]), coverage=a.get("coverage", "pairwise"),
            ))
        ucs.append(uc)
    assumptions = [(a, p(a["expr"], f"{a['id']}/expr")) for a in raw.get("assumptions", [])]
    rules = [(r, p(r["expr"], f"{r['id']}/expr") if "expr" in r else None) for r in raw.get("rules", [])]
    issues = [(i, p(i["region"], f"{i['id']}/region") if "region" in i else None) for i in raw.get("open_issues", [])]
    spec = Spec(path=path, raw=raw, sha256=canonical_sha256(raw), factors=factors, outcomes=outcomes,
                use_cases=ucs, assumptions=assumptions, rules=rules, issues=issues, parse_findings=pf)
    return spec, []


def assumptions_for(spec: Spec, uc: UseCase) -> list:
    """UC に適用される前提: 明示指定、または参照する因子がすべて UC の入力にあるもの。"""
    out = []
    for raw, e in spec.assumptions:
        if e is None:
            continue
        if "use_cases" in raw:
            if uc.id in raw["use_cases"]:
                out.append((raw, e))
        elif all(v in uc.inputs for v in e.vars):
            out.append((raw, e))
    return out


def blocked_reasons(spec: Spec, ac: AC) -> list:
    reasons = []
    for raw, _ in spec.issues:
        if raw["status"] != "open":
            continue
        aff = raw.get("affects", [])
        if ac.full_id in aff:
            reasons.append(f"{raw['id']} (AC)")
        for v in ac.uc.inputs:
            if v in aff:
                reasons.append(f"{raw['id']} ({v})")
    for v in ac.uc.inputs:
        f = spec.factors.get(v)
        if f and f["status"] == "tentative":
            reasons.append(f"{v} は水準未確定 (tentative)")
    seen = []
    for r in reasons:
        if r not in seen:
            seen.append(r)
    return seen
