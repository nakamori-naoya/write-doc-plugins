# Write Doc

資料の型、文章規律、図の設計、HTML/Markdownへの保存を組み合わせ、資料を1本作るClaude Code/Codex両対応marketplaceである。

## こんなときに使う

**読み手と目的に合う型を選び、読みやすい本文と必要な図を作り、MarkdownまたはHTMLへ安全に保存したいときに使う。** 題材固有の知識は持たず、README、設計資料、ADR、Runbookなどの書き方と出力を担当する。

- 資料を作りたいが、README、ハウツー、ADRなどの型を決められない
- 主張、段落、強調、文体を一貫させたい
- 文章より図が適した関係だけを選んで可視化したい
- 既存ファイルを意図せず上書きせず、HTMLまたはMarkdownへ保存したい
- 資料完成後に、中間生成物だけを安全に片付けたい

## どの機能を使うか

| やりたいこと | 選ぶ機能 |
|---|---|
| 型の選択から保存まで一続きで資料を完成させる | `write-doc` |
| 読み手と目的から文書の型だけを決める | `content-types` |
| 本文、PR説明、コメントの文章だけを整える | `writing-rules` |
| 図にする箇所と図の型だけを決める | `visual-guidance` |
| 完成済み本文をMarkdownまたはHTMLへ保存する | `doc-render` |
| 最終資料を残して未追跡の中間生成物だけを削除する | `write-doc-cleanup` |

BDD、Product Planning、収集内容など、資料の題材を発見するpluginではない。題材側のpluginが作った素材を受け取り、読み手へ伝わる一つの資料へ仕上げる。

## 利用例

```text
初めてrepositoryへ来た利用者向けのREADMEをMarkdownで作って。
```

```text
この設計判断をADRとして整理し、主要な依存関係だけを図にしてHTMLで保存して。
```

```text
このPR本文を文章規律に従って直して。ファイル保存はしなくてよい。
```

## インストール

### Codex

Codexのpluginコマンドには`--scope`がない。通常の手順はuser単位でmarketplaceとpluginを登録する。

```bash
codex plugin marketplace add nakamori-naoya/write-doc-plugins
codex plugin add write-doc@write-doc
```

このrepositoryだけに分離したい場合は、repository専用の`CODEX_HOME`を作り、インストール時と利用時に同じ値を指定する。

```bash
mkdir -p .codex-home
export CODEX_HOME="$PWD/.codex-home"

codex plugin marketplace add nakamori-naoya/write-doc-plugins
codex plugin add write-doc@write-doc
codex
```

`CODEX_HOME`には認証、設定、ログ、session、plugin metadataも保存されるため、このdirectoryはGit管理しない。

### Claude Code

Claude Codeは次のscopeを選べる。

| scope | 対象 |
|---|---|
| `user` | user全体。省略時の既定値 |
| `project` | このrepositoryで有効にする設定をGitでチーム共有する |
| `local` | このrepositoryで有効にするが、Git共有せず自分だけで使う |

repository設定としてインストールする場合は`project`を指定する。`CLAUDE_PLUGIN_SCOPE`を`user`または`local`へ変えれば、同じ手順でscopeを切り替えられる。

```bash
CLAUDE_PLUGIN_SCOPE=project

claude plugin marketplace add nakamori-naoya/write-doc-plugins --scope "$CLAUDE_PLUGIN_SCOPE"
claude plugin install write-doc@write-doc --scope "$CLAUDE_PLUGIN_SCOPE"
```

利用者がインストールするのは`write-doc@write-doc`だけである。型選択、文章規律、図の選択、保存、後片付けは同じplaybook packageへ内包し、個別のインストール対象にはしない。

## インストール済みである必要があるplugin

`write-doc@write-doc`に外部pluginへの依存はない。BDDやproductなど呼び出し側の題材にも依存しない。

内部playbookは同じpackage内の機能を内部契約で解決する。別repositoryから利用するときの公開契約は`write-doc@write-doc`だけであり、内部機能名をインストールまたは依存先として公開しない。

## 設定の上書きと優先順位

設定を持つpluginは、優先順位が最も高い1ファイルだけを選ぶ。複数層をマージしないため、上書きするYAMLには同梱設定と同じ必須項目をすべて含める。必須項目の不足、未知のキー、許可されていない値があれば実行を停止する。

skillの静的設定は、上から順に優先する。

1. scope: `<scope>/<plugin-name>.config.yml`。呼び出し元がscopeを渡した実行だけで使う
2. local: `<repo>/.harness-plugins/<plugin-name>.local.yml`。端末固有で、通常はcommitしない
3. repository: `<repo>/.harness-plugins/<plugin-name>.config.yml`
4. personal: `$XDG_CONFIG_HOME/harness-plugins/<plugin-name>.config.yml`（未設定時は `~/.config/harness-plugins/<plugin-name>.config.yml`）
5. bundled defaults: plugin同梱の既定設定

playbookの静的設定は、scope、repository、personal、同梱 `playbook.yml` の順で優先する。playbookにはlocal層がない。入口playbook自身は通常のrepository設定を使い、下段のpluginへscopeを渡す。単体呼び出しではscopeを読まない。

skillでは、同梱設定の `prompt_parameters` に宣言されたpathだけ、依頼で明示された値を `--override=<path>=<value>` として最終上書きできる。宣言されていないpathを任意に上書きすることはできない。

たとえば入口は `<repo>/.harness-plugins/write-doc.config.yml`、その入口から呼ぶ `writing-rules` だけの設定は `<repo>/.harness-plugins/scopes/write-doc/writing-rules.config.yml` に置く。

## 検証

```bash
bash scripts/validate.sh
```
