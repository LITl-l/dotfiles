"""trs 自身のテスト。検査器が「壊れた仕様を壊れていると言うか」を確かめる。

実行: PYTHONPATH=src pytest -q   (TLA+ のテストは TLC が無ければ skip)
"""
from __future__ import annotations

import copy
import json
import shutil
from pathlib import Path

import pytest
import yaml

from trs import checks, tla, trace, vectors
from trs.expr import ExprError, parse
from trs.model import load

EXAMPLE = Path(__file__).resolve().parents[1] / "examples" / "PBI-123"


def codes(findings, sev="E"):
    return sorted({f.code for f in findings if f.severity == sev})


@pytest.fixture
def ws(tmp_path):
    dst = tmp_path / "PBI-123"
    shutil.copytree(EXAMPLE, dst, ignore=shutil.ignore_patterns("generated"))
    return dst


def edit(ws, fn):
    p = ws / "trs.yaml"
    raw = yaml.safe_load(p.read_text(encoding="utf-8"))
    fn(raw)
    p.write_text(yaml.safe_dump(raw, allow_unicode=True, sort_keys=False), encoding="utf-8")
    spec, errs = load(p)
    assert not errs, errs
    return spec


def ac(raw, uc, aid):
    u = next(u for u in raw["use_cases"] if u["id"] == uc)
    return next(a for a in u["acs"] if a["id"] == aid)


# --- 式 --------------------------------------------------------------------
def test_expr_roundtrip():
    e = parse('role in ["管理者", "編集者"] && !(net == "失敗") => result != "保存"')
    assert e.vars == ["role", "net", "result"]
    assert e.eval({"role": "閲覧者", "net": "失敗", "result": "保存"}) is True
    assert e.eval({"role": "管理者", "net": "正常", "result": "保存"}) is False


@pytest.mark.parametrize("bad", ['role = "x"', 'role == x', 'role in []', '(role == "a"', ''])
def test_expr_rejects(bad):
    with pytest.raises(ExprError):
        parse(bad)


# --- 正常系: 例はきれいに通る ----------------------------------------------------
def test_example_is_clean():
    spec, errs = load(EXAMPLE / "trs.yaml")
    assert not errs
    F = checks.run_all(spec)
    assert codes(F) == [] and codes(F, "W") == []


# --- 意味検査 ----------------------------------------------------------------
def test_gap_is_found(ws):
    spec = edit(ws, lambda r: ac(r, "UC-01", "AC-代替準正常-001").update(pre='role == "管理者" && net == "失敗"'))
    F = checks.run_all(spec)
    gaps = [f for f in F if f.code == "Z020"]
    assert len(gaps) == 1
    assert 'role == "編集者"' in gaps[0].message and 'net == "失敗"' in gaps[0].message
    assert "op" not in gaps[0].message  # 操作は任意 (一般化されている)


def test_known_gap_via_open_issue(ws):
    def f(r):
        ac(r, "UC-01", "AC-代替準正常-001")["pre"] = 'role == "管理者" && net == "失敗"'
        r["open_issues"].append({"id": "OI-03", "text": "編集者の通信失敗時の挙動", "status": "open",
                                 "use_case": "UC-01", "region": 'role == "編集者" && net == "失敗"'})
    F = checks.run_all(edit(ws, f))
    assert "Z020" not in codes(F) and any(x.code == "Z021" for x in F)


def test_conflict(ws):
    def f(r):
        u = next(u for u in r["use_cases"] if u["id"] == "UC-01")
        u["acs"].append({"id": "AC-基本正常-002", "title": "x", "pre": 'role == "編集者" && op == "削除"',
                         "post": {"result": "拒否"}, "then": ["x"], "basis": ["SRC-1"]})
    F = checks.run_all(edit(ws, f))
    assert "Z030" in codes(F)


def test_rule_violation(ws):
    spec = edit(ws, lambda r: ac(r, "UC-01", "AC-例外例外-001").update(post={"result": "保存"}))
    assert "Z040" in codes(checks.run_all(spec))


def test_rule_needs_outcome(ws):
    def f(r):
        r["outcomes"].append({"id": "toast", "label": "通知", "levels": ["成功", "なし"]})
        r["rules"].append({"id": "R-03", "ears": "event", "text": "保存したら成功通知",
                           "expr": 'result == "保存" => toast == "成功"', "basis": ["SRC-1"]})
    F = checks.run_all(edit(ws, f))
    v = [x for x in F if x.code == "Z040"]
    assert v and "toast" in v[0].message


def test_vacuous_ac_and_dead_level(ws):
    def f(r):
        r["assumptions"] = [{"id": "A-01", "text": "閲覧者には操作手段がない", "expr": 'role != "閲覧者"',
                             "basis": ["SRC-2 設定画面"]}]
    F = checks.run_all(edit(ws, f))
    assert "Z010" in codes(F) and "Z050" in codes(F, "W")


def test_basis_must_not_be_code(ws):
    spec = edit(ws, lambda r: ac(r, "UC-01", "AC-例外例外-001").update(basis=["frontend/src/save.ts#L40"]))
    assert {"S031", "S032"} <= set(codes(checks.run_all(spec)))


def test_scope_frame(ws):
    def f(r):
        r["use_cases"][1]["scope"]["準正常"] = "未検討"
        r["use_cases"][1]["scope"]["例外"] = "あり"
    assert {"S050", "S051"} <= set(codes(checks.run_all(edit(ws, f))))


# --- ベクタ ------------------------------------------------------------------
def test_vectors_deterministic_and_order_stable(ws):
    spec, _ = load(ws / "trs.yaml")
    a = vectors.generate(spec)
    b = vectors.generate(load(ws / "trs.yaml")[0])
    assert a == b
    spec2 = edit(ws, lambda r: r["factors"][1]["levels"].reverse())
    ids2 = {v["id"] for v in vectors.generate(spec2)["vectors"]}
    full = {v["id"] for v in a["vectors"] if v["ac"].endswith("基本正常-001")}
    assert full <= ids2  # coverage: all の AC は並び順を変えても ID が変わらない
    assert any(x["ac"].endswith("UC-02_AC-基本正常-001") for x in a["blocked"])


def test_pairwise_covers_all_pairs():
    import itertools
    valid = list(itertools.product("abc", "xyz", "pqr", "12"))
    rows = vectors.pairwise(valid, 4)
    need = {(i, c[i], j, c[j]) for c in valid for i, j in itertools.combinations(range(4), 2)}
    got = {(i, c[i], j, c[j]) for c in rows for i, j in itertools.combinations(range(4), 2)}
    assert need == got and len(rows) < len(valid)


# --- 照合 --------------------------------------------------------------------
def junit(tmp_path, cases):
    xml = ["<testsuite>"]
    for name, status in cases:
        inner = {"fail": "<failure/>", "skip": "<skipped/>"}.get(status, "")
        xml.append(f'<testcase name="{name}">{inner}</testcase>')
    xml.append("</testsuite>")
    p = tmp_path / "junit.xml"
    p.write_text("\n".join(xml), encoding="utf-8")
    return p


def test_trace(ws, tmp_path):
    spec, _ = load(ws / "trs.yaml")
    doc = vectors.generate(spec)
    ids = [v["id"] for v in doc["vectors"]]
    ok = junit(tmp_path, [(f"test[{i}]", "pass") for i in ids])
    assert codes(trace.check(doc, [ok])) == []
    bad = junit(tmp_path, [(f"test[{ids[0]}]", "fail"), (f"test[{ids[1]}]", "skip"),
                           ("test[US-01_UC-01_AC-基本正常-001#deadbeef]", "pass")])
    assert {"T001", "T002", "T003", "T004"} <= set(codes(trace.check(doc, [bad])))


# --- TLA+ --------------------------------------------------------------------
needs_tlc = pytest.mark.skipif(tla.tlc_cmd() is None, reason="TLC が無い (TRS_TLC を設定)")


@needs_tlc
def test_tla_ok(ws):
    spec, _ = load(ws / "trs.yaml")
    F = tla.check(spec)
    assert codes(F) == [] and any(f.code == "L101" for f in F)
    assert (ws / "generated" / "traces" / "US-01_UC-01_AC-代替準正常-001.json").exists()


@needs_tlc
def test_tla_unreachable_witness(ws):
    t = ws / "Settings.tla"
    t.write_text(t.read_text().replace("~(hadError /\\ saved)", '~(hadError /\\ draft = "empty")'))
    assert "L030" in codes(tla.check(load(ws / "trs.yaml")[0]))


@needs_tlc
def test_tla_invariant_violation(ws):
    t = ws / "Settings.tla"
    t.write_text(t.read_text().replace("hadError' = TRUE /\\ UNCHANGED <<draft, saved>>",
                                       "hadError' = TRUE /\\ draft' = \"empty\" /\\ UNCHANGED <<saved>>"))
    assert "L020" in codes(tla.check(load(ws / "trs.yaml")[0]))


def test_tla_rejects_non_ascii(ws):
    t = ws / "Settings.tla"
    t.write_text(t.read_text() + "\n\\* 日本語\n")
    assert "L002" in codes(tla.check(load(ws / "trs.yaml")[0]))
