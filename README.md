# Write Doc

資料の型、文章規律、図の設計、Markdownへの保存を組み合わせ、資料を1本作るClaude Code/Codex両対応marketplaceである。

## こんなときに使う

**読み手と目的に合う型を選び、読みやすい本文と必要な図を作り、Markdownへ安全に保存したいときに使う。** 題材固有の知識は持たず、要求発見、利用・負荷モデル、品質要求、クラウドアーキテクチャ、README、ADRなど同梱19型の書き方と出力を担当する。

既存の`architecture`は、観測時点の現在構成を照合可能な名前で説明する型である。新しい`cloud-architecture`は、要求・利用負荷・品質要求・制約を根拠に将来構成を比較・選定し、ADR、要求追跡、編集可能な構成図を残す型である。現在の説明と将来の選定を混ぜない。

- 資料を作りたいが、README、ハウツー、ADRなどの型を決められない
- 主張、段落、強調、文体を一貫させたい
- 文章より図が適した関係だけを選んで可視化したい
- 既存ファイルを意図せず上書きせず、Markdownへ保存したい
- 資料完成後に、中間生成物だけを安全に片付けたい

## 公開入口を選ぶ

次の入口から依頼する。内部のスキルや処理は、入口が呼び出す。

| やりたいこと | 公開入口 |
|---|---|
| 読み手と型の選択から本文の執筆・図・保存まで資料を1本完成させる | `write-doc` |

BDD、Product Planning、収集内容など、資料の題材を発見するpluginではない。題材側のpluginが作った素材を受け取り、読み手へ伝わる一つの資料へ仕上げる。

## 利用例

```text
初めてrepositoryへ来た利用者向けのREADMEを作って。
```

```text
この設計判断をADRとして整理し、主要な依存関係だけを図にして保存して。
```

```text
この設計判断を初めて読む人向けの説明資料として作成して保存して。
```

## インストール

インストールするのは`write-doc@write-doc`だけである。外部プラグインの追加は要らない。

内部のスキルは同梱されている。個別にインストールせず、公開入口から使う。

### Codex

利用するCodexと同じ設定環境で実行する。

```bash
codex plugin marketplace add nakamori-naoya/write-doc-plugins
codex plugin add write-doc@write-doc
codex plugin list
```

一覧で導入先を確認し、新しい会話で使う。

### Claude Code

次は自分の全プロジェクトで使う例である。このプロジェクトのチームで共有する場合は`project`、このプロジェクトで自分だけが使う場合は`local`に変更し、利用先のディレクトリで実行する。

```bash
CLAUDE_PLUGIN_SCOPE=user
claude plugin marketplace add nakamori-naoya/write-doc-plugins --scope "$CLAUDE_PLUGIN_SCOPE"
claude plugin install write-doc@write-doc --scope "$CLAUDE_PLUGIN_SCOPE"
claude plugin list
```

一覧で導入を確認し、Claude Codeを再起動する。すでに導入しているパッケージは、次の更新手順を使う。

## 更新する

GitHubから登録したmarketplaceを更新し、その公開パッケージを更新する。新規インストールと同じCodexの設定環境、Claude Codeの適用範囲を使う。

### Codex

```bash
codex plugin marketplace upgrade write-doc
codex plugin add write-doc@write-doc
codex plugin list
```

更新後は新しい会話で確認する。ローカルのパスからmarketplaceを登録した場合は、Git版の更新コマンドではなく、その登録先のソースを更新してから追加し直す。

### Claude Code

```bash
# インストール時に合わせてuser / project / localを選ぶ
CLAUDE_PLUGIN_SCOPE=user
claude plugin marketplace update write-doc
claude plugin update write-doc@write-doc --scope "$CLAUDE_PLUGIN_SCOPE"
claude plugin list
```

更新後はClaude Codeを再起動する。

marketplaceの取得と、インストール済みパッケージの更新は分けて確認する。同じバージョンとして公開された変更は、更新コマンドだけでは反映されない。「最新」と表示された場合は公開バージョンを確認し、キャッシュ内のファイルを直接編集しない。

コマンドは[Codexのmarketplace管理](https://developers.openai.com/plugins/build/plugins)と[Claude Codeの更新仕様](https://code.claude.com/docs/en/plugins-reference#plugin-update)に基づく。

## インストール済みである必要があるplugin

`write-doc@write-doc`が外部へ持つ依存は`grill@grill`の1つだけである。読み手・目的・求める判断が依頼から決まらないときだけ、その公開playbookを呼ぶ。BDDやproductなど呼び出し側の題材には依存しない。

内部の機能は同じpackage内で内部契約として解決する。別repositoryから利用するときの公開契約は`write-doc@write-doc`だけであり、内部機能名をインストール対象または依存先として公開しない。

## 公開契約

公開契約の正本は[CONTRACT.md](plugins/playbooks/authoring/write-doc/CONTRACT.md)である。契約 ID は`write-doc/write-doc`、版は1。

**そこに書かれていることだけが契約である。** 入口（4点）、`--input`の入力schema、`output_to`へ書く出力schema、提供側が守る保証。それ以外——工程の並びと名前、内部skill名、内部plugin名、テンプレートと骨格、保存scriptの引数とexit code、`references/`の手引き、内部pluginの設定キー——は非契約であり、いつ変わってもよい。

呼び出し元のplaybookは次の2か所だけでこれを要求する。

```yaml
requires:
  - {plugin: write-doc, marketplace: write-doc}

steps:
  - id: document
    playbook: write-doc
    input:
      document_type: domain-rule   # 静的に決まる型だけ書く
    provides: [document_path]
```

**外部から`skill:`や`script:`で内部を掴むことはできない。** resolverが`external-dependency-skill` / `external-dependency-script`で停止する。

**実行は2段で、解決は1回だけである。** 呼び出し元が`scripts/prepare.sh <repo> --input=<abs> --scope=<dir> --bindings=<lock>`で解決済みYAMLのpathを得て、そのpathを添えて入口SKILL.mdへ実行を渡す。write-docは受け取ったpathをそのまま使い、解決をやり直さない。やり直すと呼び出し元が載せた入力・scope・束縛が消える。詳細は[CONTRACT.md §1](plugins/playbooks/authoring/write-doc/CONTRACT.md)。

## 依存先の差し替え

論理名（`write-doc`、`grill`）と実体pluginは分かれている。利用者は契約ID（`marketplace/plugin`）に対する実体を `dependencies.yml` で束縛する。**playbook側の`requires`は書き換えない。**

```yaml
version: 1
bindings:
  # このrepositoryの資料作成だけ、別の実装へ差し替える
  "write-doc/write-doc": {plugin: acme-write-doc, marketplace: acme-docs}
  # write-docが内部で使う対話も差し替えられる
  "grill/grill": {plugin: acme-grill, marketplace: acme-dialogue}
```

- top-levelは `version: 1` と `bindings` の2つだけである。それ以外のキーがあると `[error:binding-file-invalid] reason=top-level-keys` で停止する。
- 値に書けるのは `plugin` と `marketplace` だけで、pathやversionは書けない。
- 置き場所は3層で、下ほど優先する。層はマージせず、見つかった最優先の1ファイルだけを使う。
  1. personal: `$XDG_CONFIG_HOME/harness-plugins/dependencies.yml`（未設定時は `~/.config/harness-plugins/dependencies.yml`）
  2. repository: `<repo>/.harness-plugins/dependencies.yml`
  3. scope: `<repo>/.harness-plugins/scopes/<入口playbook>/dependencies.yml`
- 差し替え先は、manifestの `metadata.harness.implements` にその契約IDと、`write-doc/write-doc` なら扱える文書型slugを自己宣言していなければならない。宣言が無ければ `[error:binding-not-implemented]` で停止する。呼び出し元が要求した文書型を実装していなければ、解決の時点で止まる。
- 入口が選んだ束縛はrun専用のlockへ固定して子へ渡す。入れ子の実行（呼び出し元 → write-doc → grill）で実体が食い違うことはなく、実行中に `dependencies.yml` を書き換えても、そのrunの解決は変わらない。

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

資料の保存先は、作業repositoryの`<repo>/.harness-plugins/doc-render.config.yml`で文書型ごとに分けられる。各`dir`は`type: relative|absolute`と`path`を持つため基準が暗黙にならず、同じ1ファイルからrepository内にも外にも出せる。一致しない型は`output.default`へ保存する。

## 検証と保守

検証コマンド、実行契約の保守、開発CLIの扱いは [docs/maintenance.md](docs/maintenance.md) にある。
