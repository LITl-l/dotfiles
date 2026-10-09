# 導入と長期運用

## リポジトリ構成

```
specs/
  PBI-123/
    trs.yaml              人が所有する仕様 (唯一の情報源)
    Settings.tla / .cfg   状態を持つ UC のモデル (必要なときだけ)
    generated/            trs gen / trs tla の出力 (コミットする)
      TRS.md
      vectors.json
      traces/*.json
tools/trs/                このスキルの tool/ をコピー (ベンダリング)
flake.nix / flake.lock    ツールチェーンの固定
.github/workflows/trs.yml
.github/CODEOWNERS
```

導入手順:

1. スキルの `tool/` を `tools/trs/` にコピーする
2. `templates/flake.nix` をルートに置き、`nix flake lock` で固定する
3. `templates/CODEOWNERS`、`templates/github-actions.yml` を配置し、ブランチ保護で Code Owners のレビューを必須にする
4. エージェントのハーネス設定に `templates/claude-settings.json` 相当を入れる
5. `tools/trs` の自己テストを通す: `nix develop --command pytest tools/trs/tests`

ツールをスキルから参照せずリポジトリにコピーするのは、CI の検査器をエージェントが触れる場所から切り離し、検査器の変更自体を PR でレビューさせるため。

## 守りの構造 (強い順)

1. **ブランチ保護 + CODEOWNERS**: `specs/`・`tools/trs/`・flake・workflow の変更に人の承認を必須にする。仕様をエージェントが書き換えても、人の承認なしにはマージされない
2. **CI**: `trs ci --strict` と `trs trace`。生成物の乖離、未定義、矛盾、規則違反、未実行ベクタを機械的に止める
3. **ハーネスの権限設定**: 編集ツールから `specs/` を外す。Bash 経由で迂回できる deny-list なので、境界ではなく「うっかり」を防ぐ摩擦。より強くするなら `specs/` を読み取り専用でマウントしたサンドボックスで動かす (書き込み capability を最初から渡さない)

v1 にあった lock ファイルは廃止した。CODEOWNERS があれば lock は冗長で、lock 自体がエージェントに書き換えられる弱点を持つため。

## 仕様変更の流れ

1. 人が trs.yaml を編集する (元資料が更新されたら `sources[].rev` も更新する)
2. `trs check` → 指摘を解消
3. `trs gen` (+ 状態ありなら `trs tla`) → 生成物を同じ PR でコミット
4. レビュー: `generated/TRS.md` の差分で振る舞いの変化を、`vectors.json` の差分で影響するテストを確認する
5. マージ後、実装側のテストは新しいベクタで走り、`trs trace` で古い ID (T004) や未実行 (T001) が検出される

`sources[].rev` を更新したら、その SRC を根拠にしている AC・因子・規則を見直す (`grep 'SRC-1' specs/*/trs.yaml`)。

## ツールチェーンの固定

- Nix: `flake.lock` で nixpkgs を固定し、z3・TLC (tlaplus)・Python を同じ版にそろえる。更新は `nix flake update` を PR で行い、CI (`trs` の自己テストを含む) が通ることを確認してからマージする
- Nix を使わない場合: `pip install ./tools/trs` (依存は pyproject で上限つき固定) と、`tla2tools.jar` をリリース版で取得し sha256 を検証して `TRS_TLC="java -XX:+UseParallelGC -cp tla2tools.jar tlc2.TLC"` を設定する
- Z3 の版が変わると、未定義領域の表示 (どの cube に分かれるか) は変わりうるが、領域そのものと合否は変わらない。生成物 (`vectors.json`) は Z3 を使わず決定的に作るので、Z3 の版に依存しない

## スキーマの版管理

- `schema: trs/v2` を全ファイルに書く。互換性のない変更をするときは `trs/v3` を作り、移行スクリプトを `tools/trs` に同梱して全 spec を一括で移行する PR を出す
- 列挙値 (kind、ears など) を足すのは後方互換。消す・意味を変えるのは非互換
- ベクタの形式は `format: trs-vectors/v1`。テスト側のドライバは format を確認し、未知の版なら失敗させる

## ID の運用

- AC・因子・規則・OI の ID は付け直さない。廃止した番号は再利用しない
- 因子 id の改名は、それを参照する全ベクタ ID が変わる (入力のキーが変わるため)。改名は仕様変更として扱う
- 水準の並び順の変更や追加は、既存の同じ入力のベクタ ID を変えない

## 規模が大きくなったら

- 入力空間が 20 万を超える UC は分割する (G001)。分割の境界は振る舞いの境界 (権限ごと、画面ごと) にする
- 因子を UC 間で共有するのはよいが、UC ごとに `inputs` を最小にする。使わない因子は入れない
- spec は PBI 単位。同じ因子 (権限など) を多くの spec で定義するようになったら、共通定義の仕組み (include) を schema v3 で検討する。それまでは重複を許容し、`grep` で一貫性を見る

## 見ておく指標

- open な OI の数と滞留期間 (未定義が放置されていないか)
- ブロック中の AC の数
- Z020 (未定義) が PR で何件見つかって、どう解消されたか (AC 追加 / 前提 / OI)。前提への逃がしが多い場合は注意
- `trs trace` の T001 (未実行) の発生頻度
- ミューテーションテストの生存率 (AC 別)
