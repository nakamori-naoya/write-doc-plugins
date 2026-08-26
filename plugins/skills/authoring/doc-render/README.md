# doc-render

**書けたものを媒体へ出す。** 意味上の役を HTML / Markdown の表現へ写し、上書きを防いで保存する。

**規律を知らない。** どこに何を書くかは、書く側の関心である。

## 役 → 媒体

| 役 | HTML | Markdown |
|---|---|---|
| 要点 | `<mark>` | `**太字**` |
| キーワード（初出のみ） | `<mark class="kw">` | `` `バッククォート` `` |
| 一言でいうと | `<p class="hitokoto">` | `> 引用` |
| 要約項目 | `<span class="badge imp/pt">` | `**[最重要]**` |

図は `図の主張` / `図の型` / `図の内容` を、HTML の `<figure>`＋インライン SVG、または Markdown の外部 SVG 参照へ写す。図・出典・コード注釈の媒体表現も持つ。**CSS があるクラスには必ず書き方があり、書き方があるクラスには必ず CSS がある**（片方だけ在る状態を作らない）。

コードを載せる文書向けに、**読ませるコード（畳まない `div.code-listing`）と参照させるコード（畳んでよい `details.code-listing.appendix`）**、**段階ブロック**（`section.stage` ＋ `ul.stage-io` ＋ `p.next`）、**省略の印**（`tr.elision`）を持つ。**どこを省くか・何を読ませるかは判断しない。** 印とタグの書き方だけを決める。

## 保存

```bash
scripts/write-doc.sh --config <解決済みYAMLファイルのpath> --name <YYYY-MM-DD>-<ケバブ>.<html|md> --body-file <path> [--format markdown|html]
```

通常は解決済み設定の`output.format`を使う。呼び出し元playbookが資料媒体を契約として固定している場合だけ`--format`を渡し、その1回の保存形式を優先する。出力先とHTMLのthemeは引き続き解決済み設定に従う。

guard済みの既存資料を同じ絶対pathで差し替える場合だけ、`--name`の代わりに`--target <既存絶対path> --replace`を使う。`--target`は既存regular fileだけを受け付け、symlink、相対path、新規pathを拒否する。この場合、設定の`output.dir`から保存先を作り直さない。

| 返り | 意味 |
|---|---|
| `{"decision":"written"}` exit 0 | 新規に置いた |
| `{"decision":"replaced"}` exit 0 | 指定された既存絶対pathを同じ場所で差し替えた |
| `{"decision":"exists"}` **exit 3** | **同名が既にある。書いていない** |
| `{"error":...}` exit 2 | 引数か出力先の問題 |

**作成そのものを排他にしている**（`ln(2)`）。並行して走っても、必ず片方が `exists` になる。検査してから書くまでの隙間で両方が書き、片方が消える経路を塞いである。

**出力先が symlink で別の場所を指していたら止まる。** 設定に書いた場所の外へは書かない。

**空の本文は書かない。**「書けた」と報告されたのに中身が無い資料は、生成が途中で落ちた事故を隠す。

## 設定

```yaml
# <repo>/.harness-plugins/doc-render.config.yml
# config/defaults.ymlを丸ごと複製したうえで、この値を編集する
version: 1
output: {dir: docs, format: html, theme: auto}
instructions: ...  # defaults.ymlのinstructions全体を省略せず持つ
```

上の`...`は説明上の省略で、そのまま使える設定ではない。実ファイルは`config/defaults.yml`を複製し、完全な1ファイルとして編集する。

HTMLは既定でOSのライト／ダーク設定へ追従する。常に暗くするなら `dark`、常に明るくするなら `light` を明示する。

## しないこと

- **本文の中身を一切見ない。** 型が合っているか、構成が規約どおりか、強調が適切かは機械が測るものではない
- 型を知らない
- 規律を持たない
