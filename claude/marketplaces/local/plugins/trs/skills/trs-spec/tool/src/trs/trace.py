"""実装のテスト結果 (JUnit XML) とテストベクタの照合。

JUnit XML はほぼすべてのテストフレームワークが出力できるので、スタックに依存しない。
テスト側の約束はひとつだけ: テストケース名 (または property の値) にベクタ ID を含めること。
例: `test_save[US-01_UC-01_AC-基本正常-001#1a2b3c4d]`

ベクタ ID は name と property からしか拾わない。この2つはテストケースを名指しするが、
classname はクラス内の全ケースで共通で、system-out はたまたま流れた標準出力なので、
そこから拾うと「vectors.json を print するだけの通過テスト1本」で全ベクタが通過扱いになる。
spec ハッシュ (T010) は逆に厳しくなる方向にしか働かないので、出力全体から拾う。
"""
from __future__ import annotations

import re
import xml.etree.ElementTree as ET
from collections import defaultdict

from .model import Finding

VEC_RE = re.compile(r"(US-\d+_UC-\d+_AC-(?:基本|代替|例外)(?:準正常|正常|例外)-\d{3}#[0-9a-f]{8})")
SHA_RE = re.compile(r"trs\.spec_sha256=([0-9a-f]{16,64})")


def collect(paths):
    """{vector_id: [status]} と、テスト側が報告した spec ハッシュの集合"""
    seen = defaultdict(list)
    shas = set()
    for p in paths:
        root = ET.parse(p).getroot()
        for tc in root.iter("testcase"):
            ident = [tc.get("name", "")]
            other = [tc.get("classname", "")]
            for prop in tc.iter("property"):
                ident.append(f"{prop.get('name', '')}={prop.get('value', '')}")
            for tag in ("system-out", "system-err"):
                for el in tc.iter(tag):
                    other.append(el.text or "")
            blob = "\n".join(ident)
            if tc.find("failure") is not None or tc.find("error") is not None:
                status = "fail"
            elif tc.find("skipped") is not None:
                status = "skip"
            else:
                status = "pass"
            for vid in set(VEC_RE.findall(blob)):
                seen[vid].append(status)
            shas.update(SHA_RE.findall("\n".join(ident + other)))
    return seen, shas


def check(vectors_doc: dict, junit_paths) -> list:
    F = []
    seen, shas = collect(junit_paths)
    expected = {v["id"]: v for v in vectors_doc["vectors"]}
    for sha in shas:
        if not vectors_doc["spec_sha256"].startswith(sha):
            F.append(Finding("E", "T010", "junit", f"テストが古い仕様 ({sha[:16]}) を基にしています。ベクタを読み直してください"))
    per_ac = defaultdict(lambda: [0, 0])
    for vid, v in expected.items():
        st = seen.get(vid)
        per_ac[v["ac"]][1] += 1
        if not st:
            F.append(Finding("E", "T001", vid, "このベクタを実行したテストがありません"))
        elif "fail" in st:
            F.append(Finding("E", "T002", vid, f"失敗しています (入力 {v['inputs']}, 期待 {v['expect']})"))
        elif "skip" in st:
            F.append(Finding("E", "T003", vid, "skip されています"))
        else:
            per_ac[v["ac"]][0] += 1
    for vid in sorted(set(seen) - set(expected)):
        F.append(Finding("E", "T004", vid, "現在のベクタにない ID です (仕様変更後に古いテストが残っている)"))
    for ac, (ok, n) in sorted(per_ac.items()):
        F.append(Finding("I", "T100", ac, f"{ok}/{n} ベクタ通過"))
    for b in vectors_doc.get("blocked", []):
        F.append(Finding("I", "T101", b["ac"], "ブロック中のため対象外 — " + ", ".join(b["reasons"])))
    return F
