# 検証と保守

## 検証

```bash
bash /Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/write-doc-plugins/scripts/validate.sh
bash /Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/scripts/validate.sh /Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/write-doc-plugins
```

repository の検査は、manifest と directory の一致、公開入口と内部 skill の数、必須ファイル、資産数、参照ファイル集合、禁止された runtime 依存、両 runtime の同一性を判定する。これらは repository 内の閉じた入力から真偽が一意に決まる。

型対応表の検査対象は、`version: 1` と `pairs` の下に置く2空白字下げの slug、および各 slug の下に置く4空白字下げの `template` と `example` である。`template` は `assets/templates/<slug>.md`、`example` は `assets/examples/<slug>.example.md` と完全一致させる。この repository 固有の固定表現を閉じた入力として扱い、任意の YAML を解釈する parser ではない。

文章の明確さ、テンプレートの妥当性、記載例の品質は機械検査の対象にしない。変更時は `author-document` の指示と生成資料を読み、目的、根拠、図表の役割、重要条件の保持を評価する。

## 契約変更

公開入力・出力を変更したら、`CONTRACT.md`、両 manifest の `contractVersion` と `implements[].version`、両 marketplace の package version を同時に更新する。消費側の移行対象と対応は [contract-v2-migration.md](contract-v2-migration.md) に記録する。
