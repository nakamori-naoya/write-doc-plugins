# write-doc — 2026-09-16 実行記録の所見

記録: [write-doc.json](write-doc.json)（case `representative-boundary`、生成 `claude-opus-5` effort high、独立judge `claude-sonnet-5`、SKILL sha256 `c0c7b7bc431e…` ＝ 確定版）。試行の履歴: [attempt-1](write-doc.attempt-1.json) 確定前SKILL・judge出力がJSONでなく `error`、[attempt-2](write-doc.attempt-2.json) 確定前SKILL（`3e89fce8…`）に対する有効な記録。本記録は3回目。

## 実行

```bash
cd write-doc-plugins && python3 scripts/evaluate-skills.py --fixtures evals/scenarios.json \
  --model-command '["python3","scripts/claude-eval-adapter.py"]' --judge-command '["python3","scripts/claude-eval-adapter.py"]' \
  --model claude-opus-5 --judge-model claude-sonnet-5 --settings '{"effort":"high"}' --output evals/runs/2026-09-16/write-doc.json
```

fixtureの依頼文は旧runtimeの `prepare` を含んでいたので、現行の入力契約（`material` `{kind: text}`、`document_type: adr`、`output_directory` + `name`）で書き直した。

## agentの所見（「」は応答の逐語）

**この記録の応答は本文2文の後、tool呼び出しをXML風のテキスト（`<invoke name="Bash">` …）として書き出して終わっている。** `--tools ''` でtoolが無い場面で、モデルが呼び出しを「明示」する代わりに呼び出し記法をそのまま出力した形で、attempt-2（散文で呼び出しを列挙）とは応答の形が違う。criteriaに照らせる本文は少なく、所見の根拠は弱い。

| criterion | 所見 | 根拠 |
|---|---|---|
| caller-type | 反しない。`adr` をそのまま契約検査に通し、型を選び直す文も図の要否を聞き返す文も無い。ただし図不要をどう扱うかは応答に現れておらず、肯定的な根拠は薄い | 「入力は契約の形式を満たしています（`material` 1件・`content` 非空、`document_type=adr`、`output_directory` は絶対path、`name` はpath要素なしの `.md`）。」 |
| truthful | 満たす。検査と読み込みを「ここから実行します」と述べ、完了とは言わない。呼び出し記法の中身も保存先の存在・同名file・同名資産の検査（手順1）と playbook / 型カタログ / core-principles の読み込み（手順2〜3）で、SKILLの手順順どおり | 「手順1〜3に必要な検査と読み込みをここから実行します。」 |

judgeは2件passだが、`caller-type` のquote「`document_type=adr`」は根拠として薄い。私の読みは上のとおり、反しないが肯定的根拠が薄い。attempt-2の応答（確定前SKILL）の方が判断基準の適用（図不要なら資産directoryを割り当てない、読み手と読後ゴールの仮説）を本文で示していた。

## 気づき

- tool無しの `claude -p` でモデルが呼び出し記法をテキストとして出力する事象は、runnerの生成側instruction（『ツールが必要なら必要な呼び出しを明示し、実行済みとは偽らない』）の「明示」の解釈に幅があることを示す。runner基準資料の未決として残す（今回は変えていない）。
- 呼び出し記法の中で `取消期限の基準.assets` の有無も検査している。図不要でも同名資産の衝突を見る判断は、SKILL手順3の『新規で同名資産があれば止まり』と整合する。

## 未確認

- 実fileの読み書き・templateの解決は行っていない。
