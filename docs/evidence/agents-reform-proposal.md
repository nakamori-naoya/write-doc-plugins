# AGENTS.md 改定案（未適用）

`AGENTS.md` は repository の統制ファイルであるため、自動安全審査が旧 runtime 規則の削除を拒否した。次の全文案は適用せず、利用者の明示承認を得るために保存する。

```markdown
# AGENTS.md

このrepositoryは、資料を1本作って保存する`write-doc` marketplaceのsourceである。

- marketplaceへ公開するインストール対象は`write-doc` playbook packageだけにする。公開入口は`write-doc` 1つ、内部skillは`author-document` 1つとする。
- `author-document`は自身の`SKILL.md`、`references/`、`assets/`だけで資料を直接執筆して保存する。
- BDD、対話、収集、PR、product、agent作業方針をこのrepositoryへ同梱しない。
- 外部pluginを追加する場合は公開playbookとしてだけ参照する。相手の内部skill、reference、script、path、工程ID、引数、終了コード、設定キーへ依存しない。
- playbookの外部依存は`{plugin, marketplace}`で完全修飾し、versionを固定しない。
- このrepositoryの公開契約は`plugins/playbooks/authoring/write-doc/CONTRACT.md`が正本である。契約に無い振る舞いを消費側へ約束しない。契約変更時は両manifestの`contractVersion`と`implements`を一致させる。
- 文書型を追加したら、`assets/template-examples.yml`、`metadata.harness.implements[].types`、`scripts/validate.sh`の期待資産集合を同時に更新する。
- 執筆用の設定解決scriptと中間YAMLを置かない。Markdownを直接執筆し、明示されていない保存先を補わない。
- 機械検査は、repository内の正本から真偽が一意に決まる構造契約だけを扱う。意味と文章品質は対象を読んで根拠付きで評価する。
- install cacheと配布済みcacheを編集しない。このsourceを正本として変更する。
- symlinkを置かない。公開入口と内部skillの名前を衝突させない。
- 変更後は`bash scripts/validate.sh`と`bash /Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/scripts/validate.sh /Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/write-doc-plugins`を実行する。
```

この案は `/Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/.agents/rules/harness-principles.md`、`/Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/.agents/rules/plugin-package-contract.md`、`/Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/.agents/rules/deterministic-validation.md` を上位正本として適用する。
