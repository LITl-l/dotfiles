"""trs 自身のテスト。検査器が「壊れた仕様を壊れていると言うか」を確かめる。

実行: PYTHONPATH=src pytest -q   (TLA+ のテストは TLC が無ければ skip)
"""
from __future__ import annotations

import contextlib
import copy
import io
import json
import shutil
from pathlib import Path

import pytest
import yaml

from trs import checks, cli, tla, trace, vectors
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


@pytest.mark.parametrize("src, want", [
    (r'role == "管理者\\編集者"', "管理者\\編集者"),
    (r'role == "引用\"つき"', '引用"つき'),
    (r'role == "改行\n入り"', "改行\n入り"),
])
def test_string_escapes_keep_non_ascii(src, want):
    """\\ を1つでも含む文字列の復号で日本語が壊れないこと。"""
    assert parse(src).values()[0][1] == want


def test_unicode_escape_is_decoded():
    """\\uXXXX も復号すること (源泉に書けない文字をエスケープで書く経路)。"""
    bs = chr(92)
    src = f'role == "{bs}u7ba1{bs}u7406{bs}u8005"'
    assert parse(src).values()[0][1] == "管理者"


def test_invalid_escape_is_rejected():
    with pytest.raises(ExprError):
        parse(r'role == "\q"')


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


# --- 異常な仕様で検査器が落ちない / 誤検出しない --------------------------------
def test_scoped_assumption_may_only_use_that_uc_inputs(ws):
    """use_cases を明示した前提が、その UC の入力に無い因子を参照する場合。"""
    def f(r):
        r["assumptions"] = [{"id": "A-01", "text": "閲覧者は並べ替えない", "expr": 'role != "閲覧者"',
                             "use_cases": ["UC-02"], "basis": ["SRC-1 §2.1"]}]
    F = checks.run_all(edit(ws, f))
    assert "S041" in codes(F)
    assert any(x.code == "I001" for x in F)


def test_scoped_assumption_with_uc_inputs_is_fine(ws):
    """締めすぎの検出: UC の入力だけを使う前提は従来どおり通ること。"""
    def f(r):
        r["assumptions"] = [{"id": "A-01", "text": "閲覧者には操作手段がない", "expr": 'role != "閲覧者"',
                             "use_cases": ["UC-01"], "basis": ["SRC-2 設定画面"]}]
    F = checks.run_all(edit(ws, f))
    assert "S041" not in codes(F)
    assert "Z010" in codes(F)


def test_factor_outcome_id_clash_stops_semantic_checks(ws):
    """因子と結果で同じ id。Z3 の列挙ソート名が衝突するので意味検査に入ってはいけない。"""
    def f(r):
        r["outcomes"].append({"id": "op", "label": "ダミー", "levels": ["追加", "変更", "削除"]})
    F = checks.run_all(edit(ws, f))
    assert "S021" in codes(F)
    assert not any(x.code.startswith("Z") for x in F)


def test_duplicate_ac_id_stops_semantic_checks(ws):
    """AC id の重複。辞書の上書きで誤った Z020 / 自分自身との Z031 / 別 AC の Z040 が出ていた。"""
    def f(r):
        u = next(u for u in r["use_cases"] if u["id"] == "UC-01")
        u["acs"].append({"id": "AC-基本正常-001", "title": "重複", "pre": 'role == "閲覧者"',
                         "post": {"result": "保存"}, "then": ["x"], "basis": ["SRC-1 §2.1"]})
    F = checks.run_all(edit(ws, f))
    assert "S020" in codes(F)
    assert not any(x.code.startswith("Z") for x in F)


class _UnknownSolver:
    """資源切れを模した Z3 ソルバの代役。常に unknown を返す。"""

    def __init__(self, *a, **k):
        import z3
        self._unknown = z3.unknown

    def add(self, *a):
        pass

    def check(self):
        return self._unknown

    def reason_unknown(self):
        return "(resource limits reached)"

    def model(self):
        raise AssertionError("unknown なのに model() が呼ばれました")


def test_solver_unknown_is_reported_not_treated_as_unsat(monkeypatch):
    """unknown を unsat と同じに扱うと Z020/Z030/Z040 が黙って0件になる。"""
    import z3
    spec, _ = load(EXAMPLE / "trs.yaml")
    monkeypatch.setattr(z3, "Solver", _UnknownSolver)
    F = checks.run_all(spec)
    assert "Z000" in codes(F)
    assert "Z010" not in codes(F)


def test_enc_sat_unknown_is_reported(monkeypatch):
    """Enc.sat が unknown を (model=None, False) として返すと unsat と区別がつかなくなる。"""
    import z3
    enc = checks.Enc(load(EXAMPLE / "trs.yaml")[0])
    monkeypatch.setattr(z3, "Solver", _UnknownSolver)
    with pytest.raises(checks.SolverUnknown):
        enc.sat(z3.BoolVal(True))


def test_gap_cubes_unknown_is_reported(monkeypatch):
    """gap_cubes は solver を直に回すので、こちらにも unknown の経路がある。"""
    import z3
    spec, _ = load(EXAMPLE / "trs.yaml")
    enc = checks.Enc(spec)
    monkeypatch.setattr(z3, "Solver", _UnknownSolver)
    with pytest.raises(checks.SolverUnknown):
        checks.gap_cubes(enc, ["role"], z3.BoolVal(True), z3.BoolVal(False))


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
def junit(tmp_path, cases, name="junit.xml"):
    xml = ["<testsuite>"]
    for case, status in cases:
        inner = {"fail": "<failure/>", "error": "<error/>", "skip": "<skipped/>"}.get(status, "")
        xml.append(f'<testcase name="{case}">{inner}</testcase>')
    xml.append("</testsuite>")
    p = tmp_path / name
    p.write_text("\n".join(xml), encoding="utf-8")
    return p


def generated_doc(ws):
    return vectors.generate(load(ws / "trs.yaml")[0])


def test_trace(ws, tmp_path):
    spec, _ = load(ws / "trs.yaml")
    doc = vectors.generate(spec)
    ids = [v["id"] for v in doc["vectors"]]
    ok = junit(tmp_path, [(f"test[{i}]", "pass") for i in ids])
    assert codes(trace.check(doc, [ok])) == []
    bad = junit(tmp_path, [(f"test[{ids[0]}]", "fail"), (f"test[{ids[1]}]", "skip"),
                           ("test[US-01_UC-01_AC-基本正常-001#deadbeef]", "pass")])
    assert {"T001", "T002", "T003", "T004"} <= set(codes(trace.check(doc, [bad])))


def test_trace_error_element_is_a_failure(ws, tmp_path):
    """JUnit の <error> は <failure> と同じく失敗として扱うこと。"""
    doc = generated_doc(ws)
    ids = [v["id"] for v in doc["vectors"]]
    cases = [(f"test[{i}]", "pass") for i in ids]
    cases[0] = (f"test[{ids[0]}]", "error")
    F = trace.check(doc, [junit(tmp_path, cases)])
    assert [f.code for f in F if f.where == ids[0]] == ["T002"]


def test_trace_mixed_pass_and_fail_for_one_vector(ws, tmp_path):
    """同じベクタを2本のテストが実行し、片方が落ちたら通過扱いにしない。"""
    doc = generated_doc(ws)
    ids = [v["id"] for v in doc["vectors"]]
    cases = [(f"test[{i}]", "pass") for i in ids] + [(f"retry[{ids[1]}]", "fail")]
    F = trace.check(doc, [junit(tmp_path, cases)])
    assert [f.code for f in F if f.where == ids[1]] == ["T002"]
    assert [f.message for f in F if f.code == "T100" and ids[1].startswith(f.where)] == ["5/6 ベクタ通過"]


def test_trace_multiple_junit_files(ws, tmp_path):
    """--junit は複数ファイルを取る。分割実行した結果を合わせて判定すること。"""
    doc = generated_doc(ws)
    ids = [v["id"] for v in doc["vectors"]]
    a = junit(tmp_path, [(f"test[{i}]", "pass") for i in ids[:3]], "a.xml")
    b = junit(tmp_path, [(f"test[{i}]", "pass") for i in ids[3:]], "b.xml")
    assert codes(trace.check(doc, [a, b])) == []


def test_trace_reports_stale_spec_hash(ws, tmp_path):
    """テスト側が報告した spec ハッシュが現在の仕様と違えば T010。"""
    doc = generated_doc(ws)
    p = tmp_path / "junit.xml"
    p.write_text('<testsuite><testcase name="t"><properties>'
                 '<property name="trs.spec_sha256" value="0123456789abcdef"/>'
                 '</properties></testcase></testsuite>', encoding="utf-8")
    assert "T010" in codes(trace.check(doc, [p]))


def test_vector_ids_are_read_from_test_identity_only(ws, tmp_path):
    """ベクタ ID を system-out / classname から拾うと、仕様を print する1本で全部が通過扱いになる。"""
    doc = generated_doc(ws)
    ids = [v["id"] for v in doc["vectors"]]
    p = tmp_path / "junit.xml"
    p.write_text('<testsuite><testcase name="test_dump" classname="{}"><system-out>{}</system-out>'
                 "</testcase></testsuite>".format(ids[0], " ".join(ids)), encoding="utf-8")
    F = trace.check(doc, [p])
    assert codes(F) == ["T001"]
    assert len([f for f in F if f.code == "T001"]) == len(ids)


def test_vector_id_in_property_is_accepted(ws, tmp_path):
    """締めすぎの検出: property で ID を報告する経路は残すこと。"""
    doc = generated_doc(ws)
    p = tmp_path / "junit.xml"
    p.write_text("<testsuite>" + "".join(
        f'<testcase name="t{n}"><properties><property name="trs.vector" value="{v["id"]}"/>'
        "</properties></testcase>" for n, v in enumerate(doc["vectors"])) + "</testsuite>",
        encoding="utf-8")
    assert codes(trace.check(doc, [p])) == []


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


def cfg_edit(ws, old, new):
    c = ws / "Settings.cfg"
    c.write_text(c.read_text(encoding="utf-8").replace(old, new), encoding="utf-8")
    return tla.check(load(ws / "trs.yaml")[0], strict_tool=False)


def test_cfg_line_comment_does_not_count_as_checked(ws):
    """cfg のどこかに名前があれば通っていたので、コメントアウトでも L011 を通った。"""
    assert "L011" in codes(cfg_edit(ws, "INVARIANT Inv_KeepDraftOnError",
                                    "\\* INVARIANT Inv_KeepDraftOnError"))


def test_cfg_block_comment_does_not_count_as_checked(ws):
    assert "L011" in codes(cfg_edit(ws, "INVARIANT Inv_KeepDraftOnError",
                                    "(* INVARIANT Inv_KeepDraftOnError *)"))


def test_cfg_name_outside_invariant_section_does_not_count(ws):
    """PROPERTY など別の節に名前があるだけでは不変条件を検査したことにならない。"""
    assert "L011" in codes(cfg_edit(ws, "INVARIANT Inv_KeepDraftOnError",
                                    "PROPERTY Inv_KeepDraftOnError"))


def test_cfg_invariants_block_form_is_accepted(ws):
    """締めすぎの検出: INVARIANTS にまとめ書きする形も読めること。"""
    assert "L011" not in codes(cfg_edit(ws, "INVARIANT TypeOK\nINVARIANT Inv_KeepDraftOnError",
                                        "INVARIANTS TypeOK Inv_KeepDraftOnError"))


def test_tla_rejects_non_ascii(ws):
    t = ws / "Settings.tla"
    t.write_text(t.read_text() + "\n\\* 日本語\n")
    assert "L002" in codes(tla.check(load(ws / "trs.yaml")[0]))


# --- CLI ---------------------------------------------------------------------
def run_cli(*argv):
    """trs.cli.main を呼び、(終了コード, 標準出力) を返す。"""
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf), pytest.raises(SystemExit) as e:
        cli.main(list(argv))
    return e.value.code, buf.getvalue()


def test_cli_exit_0_when_clean():
    code, out = run_cli("check", str(EXAMPLE / "trs.yaml"))
    assert code == 0
    assert "E " not in out


def test_cli_exit_1_on_error(ws):
    edit(ws, lambda r: ac(r, "UC-01", "AC-例外例外-001").update(post={"result": "保存"}))
    code, out = run_cli("check", str(ws / "trs.yaml"))
    assert code == 1 and "Z040" in out


def test_cli_strict_fails_on_warning_only(ws):
    """--strict でなければ警告だけでは落ちない。--strict なら落ちる。"""
    def f(r):
        r["factors"].append({"id": "theme", "label": "配色", "levels": ["明", "暗"],
                             "status": "fixed", "basis": ["SRC-2 設定画面"]})
    edit(ws, f)
    code, out = run_cli("check", str(ws / "trs.yaml"))
    assert code == 0 and "W S060" in out
    assert run_cli("check", "--strict", str(ws / "trs.yaml"))[0] == 1


def test_cli_exit_nonzero_on_schema_error(tmp_path):
    p = tmp_path / "trs.yaml"
    p.write_text("schema: trs/v2\nid: PBI-1\n", encoding="utf-8")
    code, out = run_cli("check", str(p))
    assert code != 0 and "S000" in out


def test_cli_ci_detects_generated_drift(ws):
    run_cli("gen", str(ws / "trs.yaml"))
    md = ws / "generated" / "TRS.md"
    md.write_text(md.read_text(encoding="utf-8") + "手で足した行\n", encoding="utf-8")
    code, out = run_cli("ci", "--no-tla", str(ws / "trs.yaml"))
    assert code == 1 and "G010" in out


def test_cli_ci_is_green_after_gen(ws):
    run_cli("gen", str(ws / "trs.yaml"))
    code, out = run_cli("ci", "--strict", "--no-tla", str(ws / "trs.yaml"))
    assert code == 0 and "G100" in out


def test_cli_no_tla_says_it_skipped_tlc(ws):
    """--no-tla で TLC を飛ばしたことが出力に残ること (黙って抜けない)。"""
    run_cli("gen", str(ws / "trs.yaml"))
    assert "L003" in run_cli("ci", "--no-tla", str(ws / "trs.yaml"))[1]
    assert "L003" not in run_cli("check", str(ws / "trs.yaml"))[1]


def test_cli_no_tla_still_checks_invariant_names(ws):
    """TLC の要らない名前照合 (L010〜L012) は --no-tla でも走ること。"""
    run_cli("gen", str(ws / "trs.yaml"))
    t = ws / "Settings.tla"
    t.write_text(t.read_text(encoding="utf-8").replace("Inv_KeepDraftOnError ==", "Inv_Renamed =="),
                 encoding="utf-8")
    code, out = run_cli("ci", "--no-tla", str(ws / "trs.yaml"))
    assert code == 1 and "L010" in out


def test_cli_trace_detects_stale_vectors(ws, tmp_path):
    """vectors.json が現在の trs.yaml と一致しなければ T011。"""
    run_cli("gen", str(ws / "trs.yaml"))
    vp = ws / "generated" / "vectors.json"
    doc = json.loads(vp.read_text(encoding="utf-8"))
    doc["spec_sha256"] = "0" * 64
    vp.write_text(json.dumps(doc, ensure_ascii=False), encoding="utf-8")
    ok = junit(tmp_path, [(f"test[{v['id']}]", "pass") for v in doc["vectors"]])
    code, out = run_cli("trace", str(ws / "trs.yaml"), "--junit", str(ok))
    assert code == 1 and "T011" in out


def test_cli_ci_with_junit_reports_failures(ws, tmp_path):
    run_cli("gen", str(ws / "trs.yaml"))
    doc = json.loads((ws / "generated" / "vectors.json").read_text(encoding="utf-8"))
    ids = [v["id"] for v in doc["vectors"]]
    mixed = junit(tmp_path, [(f"test[{ids[0]}]", "fail")] + [(f"test[{i}]", "pass") for i in ids[1:]])
    code, out = run_cli("ci", str(ws / "trs.yaml"), "--no-tla", "--junit", str(mixed))
    assert code == 1 and "T002" in out and "T100" in out


def test_cli_json_output(ws):
    code, out = run_cli("check", "--json", str(ws / "trs.yaml"))
    doc = json.loads(out)
    assert code == 0 and doc[0]["spec"].endswith("trs.yaml")
    assert {"severity", "code", "where", "message"} == set(doc[0]["findings"][0])


def test_ensure_trailing_newline(tmp_path):
    p = tmp_path / "trace.json"
    p.write_bytes(b'{"state": 1}')
    tla._ensure_trailing_newline(p)
    assert p.read_bytes() == b'{"state": 1}\n'
    tla._ensure_trailing_newline(p)
    assert p.read_bytes() == b'{"state": 1}\n'
    e = tmp_path / "empty.json"
    e.write_bytes(b"")
    tla._ensure_trailing_newline(e)
    assert e.read_bytes() == b""
