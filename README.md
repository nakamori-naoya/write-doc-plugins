# Write Doc

資料の型、文章規律、図の設計、HTML/Markdownへの保存を組み合わせ、資料を1本作るClaude Code/Codex両対応marketplaceである。

## こんなときに使う

**読み手と目的に合う型を選び、読みやすい本文と必要な図を作り、MarkdownまたはHTMLへ安全に保存したいときに使う。** 題材固有の知識は持たず、README、設計資料、ADR、Runbookなどの書き方と出力を担当する。

- 資料を作りたいが、README、ハウツー、ADRなどの型を決められない
- 主張、段落、強調、文体を一貫させたい
- 文章より図が適した関係だけを選んで可視化したい
- 既存ファイルを意図せず上書きせず、HTMLまたはMarkdownへ保存したい
- 資料完成後に、中間生成物だけを安全に片付けたい

## 公開入口を選ぶ

次の入口から依頼します。内部のスキルや処理は、入口が必要に応じて呼び出します。

| やりたいこと | 公開入口 |
|---|---|
| 型の選択から保存後の品質確認まで資料を完成させる | `write-doc` |

BDD、Product Planning、収集内容など、資料の題材を発見するpluginではない。題材側のpluginが作った素材を受け取り、読み手へ伝わる一つの資料へ仕上げる。

## 利用例

```text
初めてrepositoryへ来た利用者向けのREADMEをMarkdownで作って。
```

```text
この設計判断をADRとして整理し、主要な依存関係だけを図にしてHTMLで保存して。
```

```text
この設計判断を初めて読む人向けの説明資料として作成し、内容を確認して保存して。
```

## インストール

インストールするのは`write-doc@write-doc`です。外部プラグインの追加は不要です。

内部のスキルは同梱されています。個別にインストールせず、公開入口から利用してください。

### Codex

利用するCodexと同じ設定環境で実行してください。

```bash
codex plugin marketplace add nakamori-naoya/write-doc-plugins
codex plugin add write-doc@write-doc
codex plugin list
```

一覧で導入先を確認し、新しい会話で利用してください。

### Claude Code

次は自分の全プロジェクトで使う例です。このプロジェクトのチームで共有する場合は`project`、このプロジェクトで自分だけが使う場合は`local`に変更し、利用先のディレクトリで実行してください。

```bash
CLAUDE_PLUGIN_SCOPE=user
claude plugin marketplace add nakamori-naoya/write-doc-plugins --scope "$CLAUDE_PLUGIN_SCOPE"
claude plugin install write-doc@write-doc --scope "$CLAUDE_PLUGIN_SCOPE"
claude plugin list
```

一覧で導入を確認し、Claude Codeを再起動してください。すでに導入しているパッケージは、次の更新手順を使ってください。

## 更新する

GitHubから登録したmarketplaceを更新し、その公開パッケージを更新します。新規インストールと同じCodexの設定環境、Claude Codeの適用範囲を使ってください。

### Codex

```bash
codex plugin marketplace upgrade write-doc
codex plugin add write-doc@write-doc
codex plugin list
```

更新後は新しい会話で確認してください。ローカルのパスからmarketplaceを登録した場合は、Git版の更新コマンドではなく、その登録先のソースを更新してから追加し直します。

### Claude Code

```bash
# インストール時に合わせてuser / project / localを選ぶ
CLAUDE_PLUGIN_SCOPE=user
claude plugin marketplace update write-doc
claude plugin update write-doc@write-doc --scope "$CLAUDE_PLUGIN_SCOPE"
claude plugin list
```

更新後はClaude Codeを再起動してください。

marketplaceの取得と、インストール済みパッケージの更新は分けて確認します。同じバージョンとして公開された変更は、更新コマンドだけでは反映されない場合があります。「最新」と表示された場合は公開バージョンを確認し、キャッシュ内のファイルを直接編集しないでください。

コマンドは2026-09-06時点のCLIヘルプと、[Codexのmarketplace管理](https://developers.openai.com/plugins/build/plugins)、[Claude Codeの更新仕様](https://code.claude.com/docs/en/plugins-reference#plugin-update)を確認しています。

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

論理名（`write-doc`、`grill`）と実体pluginは分かれている。利用者は契約IDに対する実体を、次の3層のいずれかで束縛できる。**playbook側の`requires`は書き換えない。**

1. scope: `<repo>/.harness-plugins/scopes/<入口playbook>/dependencies.yml`
2. repository: `<repo>/.harness-plugins/dependencies.yml`
3. personal: `~/.config/harness-plugins/dependencies.yml`

```yaml
version: 1
dependencies:
  # このrepositoryの資料作成だけ、別の実装へ差し替える
  "write-doc/write-doc": {plugin: acme-write-doc, marketplace: acme-docs}
  # write-docが内部で使う対話も差し替えられる
  "grill/grill": {plugin: acme-grill, marketplace: acme-dialogue}
```

差し替え先は`metadata.harness.implements`で、実装する契約IDと、`write-doc/write-doc`なら扱える文書型slugを自己宣言していなければならない。**宣言の無いpluginへは束縛できない。** 呼び出し元が要求した文書型を実装していなければ、解決の時点で止まる。

入れ子の実行（呼び出し元 → write-doc → grill）では、入口が選んだ束縛をそのまま子へ渡すので、同じ実行の中で実体が食い違うことはない。

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

## 検証

```bash
bash scripts/validate.sh
```

## 実行契約と保守

設定はprepareが返すrun専用の絶対pathで引き継ぐ。別shellで同じpathを明示し、完了・失敗停止の最後に同梱run-configのcleanupを呼ぶ。中断後は保存したpathを使い、既にcleanup済みなら設定を再解決する。

依存宣言のversionは固定しない。対応する実行契約は`contractVersion: 1`で、未宣言の旧fixtureは契約1として扱う。未知の契約版は拒否する。installed cacheでは安定版の最大SemVerを選び、prereleaseは`HARNESS_PLUGIN_ALLOW_PRERELEASE=1`を明示した場合だけ候補にする。解決したversion、内容hash、契約版を記録し、工程直前とwrite-doc再開時に内容変更を拒否する。

[doctor](scripts/doctor.py)は`python3 scripts/doctor.py --repo <対象project>`でCLI構文、両runtime公開入口、依存、設定の解決元を読み取り専用で診断する。`--distribution-only`は依存・project設定を検査しない限定診断であり、full診断の代用にはしない。

共通実装の開発時正本はProduct Planning repositoryの`shared/runtime-source`にある。更新時はそのsource checkoutを取得し、[生成CLI](scripts/sync-runtime.py)へ`--source <取得した正本directory>`を渡す。`--check`は生成差分と[生成履歴](shared/runtime-manifest.json)のversion・内容hash・対象集合を検査する。正本checkoutなしのCIでも同梱物のhashと対象集合を検査できる。実行時に別repositoryや生成CLIは不要である。変更は正本へ加え、同じ生成コマンドを各source repositoryへ適用する。

[release CLI](scripts/release.py)は`--plugin --version --notes --breaking --migration --checks`で更新計画を返す。`--checks`にはcodex/claudeの実検証結果、または未検証と理由を明示する。`--apply`で両manifestとcatalogの整合を確認して一括更新し、releases配下へ変更内容・移行・検証結果のJSON記録を残す。依存宣言は変更しない。

[意味評価fixture](evals/scenarios.json)を[評価runner](scripts/evaluate-skills.py)へ渡し、異なる生成modelとjudge modelを指定する。モデル名、実model利用、適用設定、入力、出力、SKILL hash、判定の引用と理由を保存する。これはツール無効の次応答を対象とした代表caseの意味評価であり、実ツールを使った全工程E2Eや全行動の保証ではない。保存・CLI・再開の検証は[振る舞い回帰試験](scripts/test-hardening.py)と既存validateが担う。実モデル未実行のfixtureを合格扱いにしない。

### 破壊的変更の移行

重複した薄いSKILL入口を廃止した。利用者は公開manifestに列挙された入口を使い、旧入口pathを保存した独自ランチャーは新しい宣言へ切り替える。設定のEXIT trapは廃止し、返されたrun pathを明示して完了・停止時にcleanupする。旧式の一時pathやshell変数だけを再利用しない。write-doc状態schemaは2で、旧状態の自動移行は行わず、新run-idで開始する。失敗状態は`needs_retry`として返し、修復後の明示`retry`で失敗工程だけを再実行する。

### 開発CLIの入力境界

`doctor`、`release`、`sync-runtime`、意味評価runnerは、操作者が明示したローカルsource、出力先、adapter argvを扱う開発CLIである。外部から受け取った文書やモデル出力をCLI引数へ自動変換しない。doctorのfull modeは選んだrepositoryのresolverを実行するため、信頼するsource checkoutを対象にする。doctorは配布treeのsymlinkを読取・実行前に拒否し、sync-runtimeは生成先と正本treeのsymlinkをcopy前に拒否する。評価の会話・fixture・モデル出力はadapterへstdinデータとして渡し、実行argvに混ぜない。
