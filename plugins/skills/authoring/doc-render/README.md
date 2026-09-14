# doc-render

**書けたものを Markdown へ出す。** 意味上の役を Markdown の表現へ写し、上書きを防いで保存する。

**規律を知らない。** どこに何を書くかは、書く側の関心である。

## 役 → Markdown

強調・図・出典・コード注釈の役から Markdown の記法への対応表は [references/markdown.md](references/markdown.md)（強調と図）、[references/citation.md](references/citation.md)、[references/annotated-code.md](references/annotated-code.md) にある。どこを省くか・何を読ませるかは判断しない。

## 保存

```bash
scripts/write-doc.sh --config <解決済みYAMLファイルのpath> --name <ファイル名>.md --body-file <path> [--template <文書型slug>] [--output-dir <明示された絶対path>] [--format markdown]
```

新規作成先は、依頼で明示された `--output-dir`、`--template` に一致するroute、`output.default` の順で選ぶ。

`update_target` で渡された既存資料を同じ絶対pathで差し替える場合だけ、`--name` の代わりに `--target <既存絶対path> --replace` を使う。`--target` は既存regular fileだけを受け付け、symlink、相対path、新規pathを拒否する。この場合、routeや `--output-dir` から保存先を作り直さない。差し替え時は、旧 `<資料名>.assets/` を消してから新しい画像を置く。

| 返り | 意味 |
|---|---|
| `{"decision":"written"}` exit 0 | 新規に置いた |
| `{"decision":"replaced"}` exit 0 | 指定された既存絶対pathを同じ場所で差し替えた |
| `{"decision":"exists"}` **exit 3** | 同名が既にある。書いていない |
| `{"error":...}` exit 2 | 引数か出力先の問題 |

作成そのものを排他にしている（`ln(2)`）。並行して走っても、必ず片方が `exists` になる。検査してから書くまでの隙間で両方が書き、片方が消える経路を塞いである。

出力先がsymlinkで別の場所を指す、または相対routeが作業repository外へ出たら止まる。`type` と `path` が矛盾する設定も保存前に拒否する。空の本文は書かない。「書けた」と報告されたのに中身が無い資料は、生成が途中で落ちた事故を隠す。

## 設定

```yaml
# <repo>/.harness-plugins/doc-render.config.yml
# config/defaults.ymlを丸ごと複製したうえで、この値を編集する
version: 2
output:
  format: markdown
  default: {dir: {type: relative, path: docs}}
  routes:
    - templates: [domain-rule, user-journey-bdd, rdb-logical-data-modeling]
      dir: {type: relative, path: docs/bdd}
    - templates: [how-to]
      dir: {type: absolute, path: ~/Documents/GitHub/ops-docs/guides/how-to}
instructions: ...  # defaults.ymlのinstructions全体を省略せず持つ
```

上の `...` は説明上の省略で、そのまま使える設定ではない。実ファイルは `config/defaults.yml` を複製し、完全な1ファイルとして編集する。

- `type: relative` は作業repositoryのrootを基準にする。上のBDD系資料は `<作業repo>/docs/bdd` へ出る。
- `type: absolute` は作業repositoryを基準にしない。`path` には `~/...` か `/...` を指定する。上のハウツーガイドは `~/Documents/GitHub/ops-docs/guides/how-to` へ出る。home配下は `~/` で書くと、ユーザー名を埋め込む `/Users/...` より共有しやすい。
- `relative` に `/Users/...` や `~/...` を書く、`absolute` に `docs/bdd` を書く、環境変数、`..`、末尾の `/` は拒否する。
- 同じ文書型を複数routeへ書かない。`templates` には content-types が返すslugを指定する。
- 今回だけ別の場所へ出す依頼はrouteへ書かず、呼び出し元が依頼から取得した絶対pathを `--output-dir` へ渡す。依頼で明示されていない絶対pathは推測しない。

## しないこと

- 本文の中身を一切見ない。型が合っているか、構成が規約どおりか、強調が適切かは機械が測るものではない
- 型を知らない
- 規律を持たない
