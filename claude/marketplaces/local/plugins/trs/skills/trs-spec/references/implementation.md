# 仕様を基に実装する

前提: `specs/**` (trs.yaml・TLA+・generated/) は人が所有する読み取り専用の入力。Claude が書くのは実装と、テストのアダプタだけ。

## 着手前

```bash
trs ci specs/<PBI>/trs.yaml --no-tla   # 仕様が健全で、生成物が最新か
```

- 失敗したら実装しない。仕様側の問題として人に報告する。
- `vectors.json` の `blocked` にある AC には着手しない。

## テストの構造: 共通ドライバ + 薄いアダプタ

ベクタごとに個別のテストを手書きしない。全ベクタを1つのドライバで回し、実装との接点だけをアダプタに書く。

```
for v in vectors.json:
    observed = adapter.run(v.inputs)      # 入力状態を作り、操作し、結果を観測する
    assert observed[k] == v.expect[k]  for k in v.expect
```

こうすると、比較 (assert) はドライバに1か所だけになり、「何も検証していないテスト」は構造的に作れない。検証の弱さが入り込む場所はアダプタの `run` (観測) に集中するので、レビューと「壊して落ちるか」をそこに集中させればよい。

### 守ること

- **観測は実装の外から行う。** 画面・API レスポンス・DB の状態を読む。実装の内部関数の戻り値をそのまま観測値にしない。
- **アダプタは `expect` を読まない。** 引数は `inputs` だけにする。期待値を見て観測値を作るのは、テストを恒真にする典型的な抜け道。
- **ベクタ ID をテスト名に入れる。** JUnit XML のテストケース名にベクタ ID が出ることだけが、照合 (`trs trace`) との約束。
- **期待値をテスト側で書き換えない。** 落ちたら実装を直すか、仕様の問題として人に報告する。

### 例

pytest:

```python
import json, pathlib, pytest
VEC = json.loads(pathlib.Path("specs/PBI-123/generated/vectors.json").read_text())

@pytest.mark.parametrize("v", VEC["vectors"], ids=lambda v: v["id"])
def test_vector(v, adapter):
    observed = adapter.run(v["ac"], v["inputs"])
    for k, want in v["expect"].items():
        assert observed[k] == want, (v["id"], k)
# pytest --junitxml=reports/junit/pytest.xml
```

Vitest:

```ts
import vec from "../specs/PBI-123/generated/vectors.json";
import { describe, it, expect } from "vitest";
import { run } from "./adapter";

describe("PBI-123", () => {
  it.each(vec.vectors.map((v) => [v.id, v] as const))("%s", async (_id, v) => {
    const observed = await run(v.ac, v.inputs);
    for (const [k, want] of Object.entries(v.expect)) expect(observed[k]).toBe(want);
  });
});
// vitest run --reporter=junit --outputFile=reports/junit/vitest.xml
```

Go:

```go
func TestVectors(t *testing.T) {
    doc := loadVectors(t, "specs/PBI-123/generated/vectors.json")
    for _, v := range doc.Vectors {
        v := v
        t.Run(v.ID, func(t *testing.T) {
            got := adapter.Run(v.AC, v.Inputs)
            for k, want := range v.Expect {
                if got[k] != want { t.Fatalf("%s: %s = %q, want %q", v.ID, k, got[k], want) }
            }
        })
    }
}
// gotestsum --junitfile reports/junit/go.xml
```

他の言語も同じ。テストケース名 (または JUnit の property / system-out) にベクタ ID が入ればよい。

## 照合

```bash
trs trace specs/<PBI>/trs.yaml --junit reports/junit/*.xml
```

全ベクタが実行され、通過していることを確かめる。未実行 (T001)・失敗 (T002)・skip (T003)・現在の仕様にない ID (T004)・古い仕様のベクタ (T011) はすべてエラー。テストが `trs.spec_sha256=<hash>` を property か標準出力に出すと、テストがどの版の仕様を読んだかも照合する (T010)。

## 状態を持つ AC: トレースの再生

`trs tla` は witness の反例を `generated/traces/<AC>.json` に保存する。これは「その AC の事後条件に到達する最短の実行」で、`counterexample.action` の各要素が `[前の状態, {name, location}, 次の状態]` の3要素配列になっている (状態は `[通し番号, 変数の辞書]`)。

```
for step in trace.counterexample.action:
    adapter.do(step[1]["name"])                      # アクション名 (Edit, Save, Fail, Retry, Succeed …) で操作する
    assert abstract(adapter.state()) == step[2][1]   # 抽象化した実装の状態とモデルの次状態を比較
```

`abstract` は実装の状態をモデルの変数 (トレースの `vars` にある `ui`, `draft`, `saved` …) に写す関数で、アダプタ側に書く。これで「モデルで到達できる」と「実装で同じ道筋をたどれる」を結べる。

## 実装中に仕様にない振る舞いが必要になったら

例: エラー時の文言、境界値、空一覧の表示、仕様にない権限の組み合わせ。

1. **自分で決めない。**「たぶんこうだろう」で実装しないこと。これが「いつの間にか認識とズレる」の発生源。
2. 作業を止め、人に次を示す: 何が未定義か / なぜ必要になったか / 選択肢 / OI として追記する案 (`region` の式つき)。
3. trs.yaml への反映は人が行う (または人の明示的な指示を受けてから行う)。
4. 未定義の部分に依存しない作業は続けてよい。

## 壊して落ちるか (witness の実装版)

「テストが通った」より「実装を壊したらテストが落ちた」の方が強い証拠になる。主要な AC ごとに少なくとも1回:

1. 実装の該当箇所を一時的に壊す (権限チェックを外す、保存を no-op にする、戻り値を固定する)
2. その AC のベクタだけ実行する (`-k "AC-例外例外-001"` など)
3. 落ちることを確認する。通ってしまったら、アダプタの観測が実装を見ていない
4. 壊した変更を確実に戻す (`git stash` / `git checkout`)

継続的に回すなら、ミューテーションテスト (Python: mutmut、JS/TS: Stryker、Rust: cargo-mutants、Go: go-mutesting、JVM: PIT) をベクタのテストに対して実行し、生き残ったミュータントを AC 別に集計する。

## 完了報告に含めること

- 実装した AC と `trs trace` の結果 (AC 別の通過ベクタ数)
- ブロック中で着手しなかった AC と理由
- 提案した OI (region の式つき)
- 「壊して落ちるか」を確認した AC と結果

「全テスト通過」だけを報告しない。

## してはいけないこと

- `specs/**` (trs.yaml、TLA+、generated/) と `tools/trs/**` を編集する
- テストが落ちたときに期待値や仕様を実装に合わせる
- アダプタで `expect` を参照する
- 生成物を手で直す (直すのは trs.yaml。再生成は人のレビューを経る)
