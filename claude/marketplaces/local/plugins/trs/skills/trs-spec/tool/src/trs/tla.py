"""TLA+ (TLC) による状態を持つ振る舞いの検査。

1. 本検査: config の不変条件 (規則の tla) がすべて成り立つこと
2. witness 検査: AC ごとの tla_witness (「事後条件に到達しない」を表す不変条件) が
   **破られる** こと。破られなければ、その AC の事後条件にはどの実行でも到達できない
   (モデルが空虚か、AC が満たせない)。反例トレースは JSON で保存し、状態遷移テストの入力にする。

TLC の起動コマンドは環境変数 TRS_TLC で指定する (既定: `tlc`)。
例: TRS_TLC="java -XX:+UseParallelGC -cp /opt/tla2tools.jar tlc2.TLC"
"""
from __future__ import annotations

import os
import re
import shlex
import shutil
import subprocess
import tempfile
from pathlib import Path

from .model import Finding, Spec


def tlc_cmd():
    cmd = shlex.split(os.environ.get("TRS_TLC", "tlc"))
    if shutil.which(cmd[0]) is None:
        return None
    return cmd


def _run(cmd, module: Path, cfg: Path, extra=()):
    with tempfile.TemporaryDirectory() as meta:
        p = subprocess.run(
            [*cmd, "-workers", "1", "-cleanup", "-noGenerateSpecTE", "-metadir", meta, "-config", str(cfg), *extra, module.name],
            cwd=module.parent, capture_output=True, text=True,
        )
    return p.returncode, p.stdout + p.stderr


def check(spec: Spec, strict_tool: bool = True) -> list:
    F = []
    if "tla" not in spec.raw:
        return F
    module = (spec.dir / spec.raw["tla"]["module"]).resolve()
    cfg = (spec.dir / spec.raw["tla"]["config"]).resolve()
    for p in (module, cfg):
        if not p.exists():
            F.append(Finding("E", "L001", str(p), "ファイルがありません"))
    if F:
        return F
    src = module.read_text(encoding="utf-8")
    cfg_text = cfg.read_text(encoding="utf-8")
    for name, text in ((module.name, src), (cfg.name, cfg_text)):
        bad = next((i for i, line in enumerate(text.splitlines(), 1) if not line.isascii()), None)
        if bad:
            F.append(Finding("E", "L002", f"{name}:{bad}", "TLA+ の構文解析器 (SANY) は ASCII のみ受け付けます (コメントも不可)。"
                                                          "日本語は trs.yaml 側に書く"))
    if F:
        return F

    # 静的: 規則と witness の名前がモジュール / config にあるか
    for r, _ in spec.rules:
        if "tla" in r:
            if not re.search(rf"^\s*{re.escape(r['tla'])}\s*==", src, re.M):
                F.append(Finding("E", "L010", r["id"], f"不変条件 {r['tla']} が {module.name} に定義されていません"))
            if not re.search(rf"\b{re.escape(r['tla'])}\b", cfg_text):
                F.append(Finding("E", "L011", r["id"], f"不変条件 {r['tla']} が {cfg.name} で検査されていません"))
    witnesses = [(a, a.raw["tla_witness"]) for a in spec.all_acs() if a.raw.get("tla_witness")]
    for a, w in witnesses:
        if not re.search(rf"^\s*{re.escape(w)}\s*==", src, re.M):
            F.append(Finding("E", "L012", a.full_id, f"witness {w} が {module.name} に定義されていません"))
    if any(f.severity == "E" for f in F):
        return F

    cmd = tlc_cmd()
    if cmd is None:
        sev = "E" if strict_tool else "W"
        F.append(Finding(sev, "L000", "tlc", "TLC が見つかりません (TRS_TLC を設定するか tlaplus を入れる)"))
        return F

    code, out = _run(cmd, module, cfg)
    if code != 0 or "No error has been found" not in out:
        m = re.search(r"Error: (.+)", out)
        F.append(Finding("E", "L020", module.name, "TLC 本検査が失敗しました: " + (m.group(1) if m else f"exit {code}")))
        F.append(Finding("I", "L021", module.name, out[-2000:]))
        return F
    F.append(Finding("I", "L100", module.name, "TLC: 規則 (不変条件) はすべての到達可能状態で成り立ちます"))

    tdir = spec.out_dir / "traces"
    tdir.mkdir(parents=True, exist_ok=True)
    for a, w in witnesses:
        with tempfile.NamedTemporaryFile("w", suffix=".cfg", dir=module.parent, delete=False, encoding="utf-8") as t:
            t.write(cfg_text + f"\nINVARIANT {w}\n")
            wcfg = Path(t.name)
        trace = tdir / f"{a.full_id}.json"
        try:
            code, out = _run(cmd, module, wcfg, ("-dumpTrace", "json", str(trace)))
        finally:
            wcfg.unlink(missing_ok=True)
        if re.search(rf"Invariant {re.escape(w)} is violated", out):
            F.append(Finding("I", "L101", a.full_id, f"事後条件に到達できます (witness {w} の反例 → {trace.relative_to(spec.dir)})"))
        elif "No error has been found" in out:
            trace.unlink(missing_ok=True)
            F.append(Finding("E", "L030", a.full_id,
                             f"witness {w} が破られません。この AC の事後条件にはどの実行でも到達できません"))
        else:
            F.append(Finding("E", "L031", a.full_id, f"witness 検査が想定外の結果です: {out[-500:]}"))
    return F
