"""trs — テスト要求仕様の検査・生成・照合。

  trs check SPEC...            構造 + Z3 による意味検査
  trs gen   SPEC... [--check]  generated/TRS.md と generated/vectors.json を生成 (--check: 乖離検査)
  trs tla   SPEC...            TLC による不変条件と witness の検査、反例トレースの保存
  trs trace SPEC --junit F...  実装のテスト結果とベクタの照合
  trs ci    SPEC... [--junit F...] [--no-tla]   上記をまとめて実行 (CI 用)

終了コード: 0 = 問題なし / 1 = エラーあり (--strict では警告も) / 2 = 使い方・読み込みの誤り
"""
from __future__ import annotations

import argparse
import difflib
import json
import sys
from pathlib import Path

from . import __version__
from . import checks, render, tla, trace, vectors
from .model import load

SEV_ORDER = {"E": 0, "W": 1, "I": 2}


def _print(spec_path, findings, as_json, quiet_info=False):
    if as_json:
        return
    for f in sorted(findings, key=lambda f: (SEV_ORDER[f.severity], f.code, f.where)):
        if quiet_info and f.severity == "I" and f.code not in ("I000", "I090"):
            continue
        print(f"{spec_path}: {f.severity} {f.code} [{f.where}] {f.message}")


def _failed(findings, strict):
    return any(f.severity == "E" or (strict and f.severity == "W") for f in findings)


def _load_or_exit(path, results):
    spec, errs = load(path)
    if errs:
        results.append((path, errs))
        return None
    return spec


def cmd_check(spec):
    return checks.run_all(spec)


def cmd_gen(spec, check_only):
    F = []
    gen_errors = [f for f in checks.run_all(spec) if f.severity == "E"]
    if gen_errors:
        F.append(checks.Finding("E", "G000", spec.id, f"検査エラー {len(gen_errors)} 件があるため生成しません (trs check を先に通す)"))
        return F + gen_errors
    try:
        doc = vectors.generate(spec)
    except vectors.GenError as e:
        return [checks.Finding("E", "G001", spec.id, str(e))]
    outputs = {
        spec.out_dir / "vectors.json": vectors.dumps(doc),
        spec.out_dir / "TRS.md": render.render(spec),
    }
    for path, text in outputs.items():
        rel = path.relative_to(spec.dir)
        if check_only:
            cur = path.read_text(encoding="utf-8") if path.exists() else ""
            if cur != text:
                diff = "".join(list(difflib.unified_diff(cur.splitlines(True), text.splitlines(True), str(rel), "expected"))[:80])
                F.append(checks.Finding("E", "G010", str(rel), "生成物が trs.yaml と一致しません (手で編集されたか、再生成していない)\n" + diff))
            else:
                F.append(checks.Finding("I", "G100", str(rel), "trs.yaml と一致"))
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text, encoding="utf-8")
            F.append(checks.Finding("I", "G101", str(rel), "生成しました"))
    total = len(doc["vectors"])
    F.append(checks.Finding("I", "G102", spec.id, f"ベクタ {total} 件 / 生成 {len(doc['stats'])} AC / ブロック {len(doc['blocked'])} AC"))
    return F


def cmd_trace(spec, junit):
    vpath = spec.out_dir / "vectors.json"
    if not vpath.exists():
        return [checks.Finding("E", "T000", str(vpath), "vectors.json がありません (trs gen を先に実行)")]
    doc = json.loads(vpath.read_text(encoding="utf-8"))
    F = []
    if doc.get("spec_sha256") != spec.sha256:
        F.append(checks.Finding("E", "T011", str(vpath), "vectors.json が現在の trs.yaml と一致しません (trs gen で再生成)"))
    return F + trace.check(doc, junit)


def main(argv=None):
    ap = argparse.ArgumentParser(prog="trs", description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--version", action="version", version=f"trs {__version__}")
    sub = ap.add_subparsers(dest="cmd", required=True)
    for name in ("check", "gen", "tla", "trace", "ci"):
        p = sub.add_parser(name)
        p.add_argument("specs", nargs="+")
        p.add_argument("--json", action="store_true")
        p.add_argument("--strict", action="store_true", help="警告も失敗扱い")
        if name == "gen":
            p.add_argument("--check", action="store_true")
        if name in ("trace", "ci"):
            p.add_argument("--junit", nargs="+", default=[])
        if name == "ci":
            p.add_argument("--no-tla", action="store_true")
    args = ap.parse_args(argv)

    results = []
    for sp in args.specs:
        spec = _load_or_exit(sp, results)
        if spec is None:
            continue
        if args.cmd == "check":
            F = cmd_check(spec)
        elif args.cmd == "gen":
            F = cmd_gen(spec, args.check)
        elif args.cmd == "tla":
            F = tla.check(spec)
        elif args.cmd == "trace":
            F = cmd_trace(spec, args.junit)
        else:  # ci
            F = cmd_check(spec)
            if not _failed(F, False):
                F += cmd_gen(spec, check_only=True)
            if not args.no_tla:
                F += tla.check(spec, strict_tool=True)
            if args.junit:
                F += cmd_trace(spec, args.junit)
        results.append((sp, F))

    fail = False
    for sp, F in results:
        _print(sp, F, args.json)
        fail |= _failed(F, args.strict)
    if args.json:
        print(json.dumps([{"spec": sp, "findings": [f.as_dict() for f in F]} for sp, F in results],
                         ensure_ascii=False, indent=2))
    load_err = any(any(f.code == "S000" for f in F) for _, F in results)
    sys.exit(2 if load_err and not fail else (1 if fail else 0))


if __name__ == "__main__":
    main()
