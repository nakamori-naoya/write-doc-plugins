> 作業を始める前に、workspace規約入口 `/Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/AGENTS.md` を読み、そこから指定される共通規約とこのrepository固有の規則を適用する。

# AGENTS.md

このrepositoryは、資料を1本作って保存する`write-doc` marketplaceのsourceである。

- marketplaceへ公開するインストール対象はpackage `write-doc`（`./plugins/write-doc`）だけにする。公開入口は`skills/write-doc` 1つで、公開playbook `write-doc`でもある。内部skillは置かない。
- `write-doc`は自身の`SKILL.md`、`playbook.yml`、`references/`、`assets/`だけで資料を直接執筆して保存する。工程順は`playbook.yml`の宣言順が正式な定義であり、同じagentが辿る。
- BDD、対話、収集、PR、product、agent作業方針をこのrepositoryへ同梱しない。
- 外部pluginを追加する場合は公開playbookとしてだけ参照する。相手の内部skill、reference、script、path、工程ID、引数、終了コード、設定キーへ依存しない。
- このrepositoryの公開契約は`plugins/write-doc/skills/write-doc/CONTRACT.md`が契約定義である。契約に無い振る舞いを消費側へ約束しない。契約変更時は両manifestの`contractVersion`と`implements`を一致させる。
- 文書型を追加したら、`assets/template-examples.yml`、`metadata.harness.implements[].types`、`scripts/validate.sh`の期待資産集合を同時に更新する。
- templateの冒頭は本文段落で始め、メタ情報の一覧・引用block・型の解説を置かない。作業記録の欄を成果物のtemplateへ足さない。
- `SKILL.md`、`references/`、`playbook.yml`に実行基盤の配管（`${.`マクロ、同期block、環境変数によるroot解決、設定解決scriptの実行指示）を書かない。Markdownを直接執筆し、明示されていない保存先を補わない。
- 機械検査は、repository内の契約定義から真偽が一意に決まる構造契約だけを扱う。意味と文章品質は対象を読んで根拠付きで評価する。
- install cacheと配布済みcacheを編集しない。このsourceだけを変更対象とする。symlinkを置かない。
- 変更後は`bash scripts/validate.sh`と`bash /Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/scripts/validate.sh /Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/write-doc-plugins`を実行する。

## 検査スクリプトは、意味が一意に決まることだけを判定する

このrepositoryの検査スクリプト（validate、lint、verify、checkなど、名前を問わない）が判定してよいのは、ファイルや見出しの有無、識別子や版の一致、宣言と配置の対応、禁止された書き方の有無のように、入力と基準資料から意味が決定論的に一意に決まることだけである。読んで解釈しないと決まらないことや、件数や語の出現のような品質の代わりの指標は判定せず、エージェントが読んで評価する（意味評価）。判定が一意に決まることを宣言できない検査は作らず、詳しい条件は `/Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/.agents/rules/deterministic-validation.md` に従う。
