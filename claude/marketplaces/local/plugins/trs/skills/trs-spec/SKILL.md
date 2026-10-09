---
name: trs-spec
description: >-
  人が要件と振る舞いを所有し、AI はそれを基に実装する開発を、TRS (テスト要求仕様) で回すスキル。
  仕様は YAML (因子・結果・AC の事前条件と事後条件・EARS 規則・Open Issues) で書き、Z3 で
  未定義の入力・AC 間の矛盾・規則違反・空虚な AC を検出し、状態を持つ流れは TLA+ (TLC) で不変条件と
  到達可能性 (witness) を検査し、スタック非依存のテストベクタと JUnit XML の照合で実装の適合を確かめる。
  Use when the user mentions TRS / テスト要求仕様, 受け入れ基準 (AC), 仕様駆動開発 (spec-driven development),
  EARS, Gherkin/BDD の代替, 決定表, 因子水準・pairwise, Z3 や TLA+ での仕様検査, or says things like
  「AI に実装させると認識とズレる」「仕様を AI に書き換えられたくない」「テストが実装に合わせて作られている」
  「未定義の振る舞いを洗い出したい」.
---

# TRS v2: 人が振る舞いを所有し、AI はそれを基に作る

## なぜこの形か

AI に実装させて「いつの間にか認識とズレる」原因と、それぞれへの機構:

| ズレの原因 | 機構 |
| --- | --- |
| 仕様が肥大して人が把握しきれない | AC は「事前条件 → 結果」の1行に圧縮。値は因子に一元化。人は `generated/TRS.md` を読む |
| 未定義の部分を AI がもっともらしく埋める | **Z3 が未定義の入力領域を具体的な式で列挙する** (Z020)。埋めるかどうかは人が決め、決まるまで OI としてブロック |
| 期待値が実装から作られる | 根拠は仕様書・デザインのみ (実装を指すとエラー)。テストのアダプタは期待値を読めない構造 |
| AI が仕様やテストを実装に合わせて書き換える | 仕様は CODEOWNERS で人の承認必須。生成物は乖離検査。照合は CI で |
| テストが通っても何も検証していない | 比較はドライバ1か所に集約。TLA+ は witness で到達可能性を要求。実装は「壊して落ちるか」で確認 |

原則: **オラクル (何が正しいか) は人が持ち、入力生成と検査は機械が持つ。** LLM は仕様の下書きと実装を手伝うが、判定には使わない。

## こういうときは使わない

- 小さな変更・バグ修正・既存の振る舞いを変えない作業。仕様化の費用が回収できない
- 新規プロジェクトの立ち上げ。所有すべき振る舞いがまだ無い
- 既存機能の一括変換。TRS は PBI 単位で、入力空間にも上限がある。価値の高い UC を1つ選ぶ
- 根拠となる一次資料 (仕様書・デザイン) が手元に無い。仕様化より先に資料の所在を確認する

## 4つの層

1. **仕様 (人が所有)**: `specs/<PBI>/trs.yaml`。因子・結果・前提・規則・UC・AC・OI
2. **状態なしの検査 (Z3)**: `trs check` — 空虚な AC、未定義の入力、AC 間の矛盾、規則違反
3. **状態ありの検査 (TLA+)**: `trs tla` — 規則が全到達状態で成り立つか、各 AC の事後条件に到達できるか。反例トレースを保存
4. **実装の適合 (テスト)**: `trs gen` が出す `vectors.json` を任意の言語のテストで実行 → JUnit XML → `trs trace` で全ベクタの実行と通過を照合

## 構成

```
tool/                       Python パッケージ `trs` (z3-solver, PyYAML, jsonschema)。プロジェクトの tools/trs/ にコピーして使う
  src/trs/schema/trs.schema.json   スキーマ (エディタ補完用)
  examples/PBI-123/          完成例 (trs.yaml + Settings.tla/.cfg)
  tests/                     自己テスト (検査器が壊れた仕様を壊れていると言うか)
templates/                  trs.yaml / Model.tla / Model.cfg / flake.nix / github-actions.yml / CODEOWNERS / claude-settings.json
references/
  format.md          trs.yaml の形式・意味論・式の言語・検査コード  ← 仕様を読み書きする前に必ず読む
  authoring.md       仕様の作成を手伝うときの進め方
  implementation.md  仕様を基に実装・テストするときの進め方
  formal.md          Z3 / TLA+ / Lean の役割分担と落とし穴
  operations.md      導入・CI・ツール固定・スキーマ版管理・長期運用
```

## モードを判断する

| 依頼 | 読むもの |
| --- | --- |
| 仕様書・デザイン・PBI から仕様を作る / AC を整理する / 未定義を洗い出す | `format.md` → `authoring.md` |
| 仕様を基に機能やテストを作る | `format.md` → `implementation.md` |
| 状態遷移・リトライ・並行性のある UC を検査したい | `formal.md` |
| リポジトリに導入する / CI に組み込む / 運用設計 | `operations.md` |
| 既存の仕様をレビューしてほしい | `format.md` → `trs check` を実行し、機械の指摘と「人が確認すべきこと」を分けて報告。対象の trs.yaml に `tla:` があれば `formal.md` も読む。**レビューでは** (= 他人の `specs/` に対しては) `trs gen` (引数なし) と `trs tla` が相手のディレクトリに書き込むので、読み取り専用の `trs check` と `trs gen --check` にとどめる (共通の規則 4)。自分の出力先に生成する作成モードはこの制限の対象外。TLA+ を検査したいときは仕様ディレクトリごと (trs.yaml と `tla.module` / `tla.config` が指す `.tla` / `.cfg`) 別の場所に複製し、複製側で `trs tla` を回す |
| 既存の Gherkin / 受け入れ基準を移行したい | `format.md` → `authoring.md` (Examples の値は因子に、Scenario は pre/post に) |

## 実行

プロジェクトに導入済みなら `trs …`。未導入でスキルから直接使うなら、`<skill>` = この SKILL.md があるディレクトリ とし、まず依存の用意をどちらにするか決める。

- **(A) 依存 (z3-solver / PyYAML / jsonschema) が入った python が既にあるなら** — インストールは不要。`PYTHONPATH=<skill>/tool/src <その python> -m trs …` で呼ぶ。`python` が PATH に無い環境では、その python の実体を絶対パスで書く (`PYTHONPATH=<skill>/tool/src /path/to/python -m trs check …`)
- **(B) 無いなら** — `pip install z3-solver PyYAML jsonschema` (必要なら `--break-system-packages`)

以降の `python` は (A) か (B) で決めたもの。

```bash
export PYTHONPATH=<skill>/tool/src
SPEC=<skill>/tool/examples/PBI-123/trs.yaml      # 導入済みなら specs/<PBI>/trs.yaml
python -m trs check $SPEC                        # 構造 + Z3
python -m trs gen   $SPEC                        # generated/TRS.md, vectors.json を書く
python -m trs gen   $SPEC --check                # 書かずに乖離だけ見る
TRS_TLC="java -XX:+UseParallelGC -cp tla2tools.jar tlc2.TLC" python -m trs tla $SPEC
python -m trs trace $SPEC --junit reports/junit/*.xml
python -m trs ci    specs/*/trs.yaml --strict [--junit …] [--no-tla]
```

パスの解決: 仕様のパスと `--junit` は **cwd 基準**。生成物 `generated/` (TRS.md, vectors.json, traces/) と `tla.module` / `tla.config` は **仕様ファイルのあるディレクトリ基準**で、cwd には依らない。よってスキルの例を指した `trs gen` / `trs tla` は `<skill>/tool/examples/PBI-123/generated/` を書き換える。

`--json` で機械可読の結果を出せる。終了コードはエラーがあれば 1。

## 共通の規則

1. **期待値の根拠は仕様書とデザイン。実装ではない。** 実装を見てよいのは「その入力状態を作れるか」を確かめるときだけ。
2. **未定義は未定義のまま扱う。** Z020 は人への質問のリスト。Claude が AC や前提を足して消さない。
3. **3分類 (正常 / 準正常 / 例外) を全 UC で明示する。** 該当がなければ「なし」。
4. **`specs/**` と `tools/trs/**` は人の明示的な指示なしに編集しない。** 作成モードで人と一緒に trs.yaml を書くのは可。TLA+ の `Inv_*` と `TypeOK` は人が所有する。
5. **生成物は手で直さない。** 直すのは trs.yaml。
6. **検査の合格を意図との一致と取り違えない。** check はモデルの一貫性、tla はモデルの性質、trace は観測の一致を示すだけ。

## 報告のしかた

機械で確かめたことと、人が確かめるべきことを分けて書く。**報告には実際に実行したものだけを書く。実行していない検査は「未実行」と明示する (結果を作文しない)。**

- 機械 — 実行したものだけ: `trs check` の指摘 (特に Z020 未定義は式と具体例つきで)、`trs gen` を回したなら生成ベクタ数 (AC 別) とブロック中の AC、`trs tla` を回したなら TLC の結果と witness、`trs trace` を回したならその結果
- 人: AC の内容が意図通りか、「なし」の判断、未定義領域をどう扱うか、不変条件と witness の文が意図通りか
