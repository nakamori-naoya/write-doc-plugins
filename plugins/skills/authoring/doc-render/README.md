# doc-render

**書けたものを媒体へ出す。** 意味上の役を HTML / Markdown の表現へ写し、上書きを防いで保存する。

**規律を知らない。** どこに何を書くかは、書く側の関心である。

## 役 → 媒体

| 役 | HTML | Markdown |
|---|---|---|
| 要点 | `<mark>` | `**太字**` |
| キーワード | `<mark class="kw">` | `` `バッククォート` `` |


図は `図の主張` / `図の型` / `図の内容` を、HTML の `<figure>`＋インライン SVG、または Markdown の ```` ```mermaid ```` ブロック（表現しきれないものだけ外部画像）へ写す。図・出典・コード注釈の媒体表現も持つ。**CSS があるクラスには必ず書き方があり、書き方があるクラスには必ず CSS がある**（片方だけ在る状態を作らない）。

コードを載せる文書向けに、**読ませるコード（畳まない `div.code-listing`）と参照させるコード（畳んでよい `details.code-listing.appendix`）**、**段階ブロック**（`section.stage` ＋ `ul.stage-io` ＋ `p.next`）、**省略の印**（`tr.elision`）を持つ。**どこを省くか・何を読ませるかは判断しない。** 印とタグの書き方だけを決める。

## 保存

```bash
scripts/write-doc.sh --config <解決済みYAMLファイルのpath> --name <YYYY-MM-DD>-<ケバブ>.<html|md> --body-file <path> [--template <文書型slug>] [--output-dir <明示された絶対path>] [--format markdown|html]
```

通常は解決済み設定の`output.format`を使う。呼び出し元playbookが資料媒体を契約として固定している場合だけ`--format`を渡し、その1回の保存形式を優先する。新規作成先は、依頼で明示された`--output-dir`、`--template`に一致するroute、`output.default`の順で選ぶ。HTMLのthemeも解決済み設定に従う。

guard済みの既存資料を同じ絶対pathで差し替える場合だけ、`--name`の代わりに`--target <既存絶対path> --replace`を使う。`--target`は既存regular fileだけを受け付け、symlink、相対path、新規pathを拒否する。この場合、routeや`--output-dir`から保存先を作り直さない。

| 返り | 意味 |
|---|---|
| `{"decision":"written"}` exit 0 | 新規に置いた |
| `{"decision":"replaced"}` exit 0 | 指定された既存絶対pathを同じ場所で差し替えた |
| `{"decision":"exists"}` **exit 3** | **同名が既にある。書いていない** |
| `{"error":...}` exit 2 | 引数か出力先の問題 |

**作成そのものを排他にしている**（`ln(2)`）。並行して走っても、必ず片方が `exists` になる。検査してから書くまでの隙間で両方が書き、片方が消える経路を塞いである。

**出力先がsymlinkで別の場所を指す、または相対routeが作業repository外へ出たら止まる。** `type`と`path`が矛盾する設定も保存前に拒否する。

**空の本文は書かない。**「書けた」と報告されたのに中身が無い資料は、生成が途中で落ちた事故を隠す。

## リポジトリ内へ出す設定例

```yaml
# <repo>/.harness-plugins/doc-render.config.yml
# config/defaults.ymlを丸ごと複製したうえで、この値を編集する
version: 2
output:
  format: html
  theme: auto
  default: {dir: {type: relative, path: docs}}
  routes:
    - templates: [domain-rule, user-journey-bdd, rdb-logical-data-modeling]
      dir: {type: relative, path: docs/bdd}
instructions: ...  # defaults.ymlのinstructions全体を省略せず持つ
```

上の`...`は説明上の省略で、そのまま使える設定ではない。実ファイルは`config/defaults.yml`を複製し、完全な1ファイルとして編集する。

`type: relative`は作業repositoryのrootを基準にする。したがって上のBDD系資料は`<作業repo>/docs/bdd`へ出る。同じ文書型を複数routeへ書かず、`templates`にはcontent-typesが返すslugを指定する。

## リポジトリ外へ出す設定例

```yaml
# <作業repo>/.harness-plugins/doc-render.config.yml
version: 2
output:
  format: markdown
  theme: auto
  default: {dir: {type: relative, path: docs}}
  routes:
    - templates: [onboarding]
      dir: {type: absolute, path: ~/Documents/GitHub/onboarding-docs/guides/onboarding}
instructions: ...
```

`type: absolute`は作業repositoryを基準にしない。`path`には`~/...`か`/...`を指定できる。したがって上のオンボーディング資料は、作業repositoryとは別の`~/Documents/GitHub/onboarding-docs/guides/onboarding`へ出る。保存先と文書型の対応は作業repositoryの設定1ファイルで読める。

`relative`に`/Users/...`や`~/...`を書いたり、`absolute`に`docs/bdd`を書いたりすると拒否する。環境変数、`..`、末尾の`/`も拒否する。home配下なら`~/`を使うと、ユーザー名を埋め込む`/Users/...`より共有しやすい。

Desktopなどへ今回だけ出す依頼はrouteへ絶対pathを書かず、呼び出し元が依頼から取得した絶対pathを`--output-dir`へ渡す。依頼で明示されていない絶対pathは推測しない。

version 1の設定はversion 2へ更新し、`output.dir: docs`を`output.default: {dir: {type: relative, path: docs}}`へ移す。

HTMLは既定でOSのライト／ダーク設定へ追従する。常に暗くするなら `dark`、常に明るくするなら `light` を明示する。

## しないこと

- **本文の中身を一切見ない。** 型が合っているか、構成が規約どおりか、強調が適切かは機械が測るものではない
- 型を知らない
- 規律を持たない
