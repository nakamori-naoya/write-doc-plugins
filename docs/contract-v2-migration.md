# write-doc 公開契約 v2 移行表

## 変更の要点

契約 v2 は、入力をエージェントへ直接渡し、Markdown を直接保存する。旧契約の入力 YAML、`output_to`、解決済み YAML、`prepare.sh`、resolver、終了コード、中間成果物は使わない。

| 旧契約 v1 | 新契約 v2 |
|---|---|
| 入力 YAML の `material` path 配列 | 各 path を `{kind: file, path: /absolute/path}` に変換して直接渡す。インライン本文は `{kind: text, content: "..."}` とする |
| `document_type` | 同名で直接渡す。任意 |
| `name` のみで既定保存先へ保存 | `output_directory` と `name` を渡す。保存先が未確定なら利用者へ確認する |
| `update_target` | 同名で直接渡す |
| 入力 YAML の `references` | 同名で直接渡す。任意 |
| `output_to` の YAML を読む | 戻り値の `status` と `path` または `reason` を読む |
| `prepare.sh` で設定を解決 | 廃止。呼び出さない |
| `reader_context.yml` 等を引き継ぐ | 廃止。作らない |
| 契約版 `1` | 契約版 `2` |

`requires: [{plugin: write-doc, marketplace: write-doc}]` と `playbook: write-doc` は変わらない。契約入力の作成・受け取り方だけを一括で切り替える。

## 消費側の更新形

```yaml
requires:
  - {plugin: write-doc, marketplace: write-doc}

steps:
  - id: document
    playbook: write-doc
    purpose: 素材から資料を1本書いて保存する
    needs: [material, output_directory, name]
    provides: [status, path, reason]
```

実行時に object 配列の `material`、および新規作成なら `output_directory` + `name`、更新なら `update_target` を直接渡す。旧 path 文字列をそのまま渡さず、file と text を `kind` で明示する。保存先が無い場合に既定ディレクトリを補わない。

## 消費側 inventory

2026-09-15 に `/Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/*-plugins` の `playbook.yml` を静的検索した結果、次の17入口が `write-doc` を宣言または呼び出している。

| repository | playbook |
|---|---|
| `bdd-discovery-and-formulation-plugins` | `data-model-bdd-discovery`, `data-model-bdd-formulation`, `domain-bdd-discovery`, `domain-bdd-formulation`, `user-journey-bdd-discovery`, `user-journey-bdd-formulation` |
| `collect-and-digest-plugins` | `digest`, `session-digest` |
| `domain-modeling-plugins` | `model-domain` |
| `product-planning-plugins` | `product-north-star-planning`, `product-strategy-planning` |
| `pull-request-plugins` | `pr-review-response`, `pull-request` |
| `system-design-plugins` | `design-cloud-architecture`, `discover-quality-requirements`, `discover-requirements`, `discover-workload-model` |

この repository の変更では兄弟 repository を更新していない。上記の消費側は旧呼び出し手順のままであり、各 repository で契約 v2 への一括更新と検証が必要である。移行完了まで end-to-end 互換性は保証しない。

### 更新対象の絶対パス

各行の `playbook.yml` で入力・出力の受け渡しを更新し、同じ directory の `SKILL.md` から入力 YAML、resolver、`prepare.sh`、`output_to`、終了コードの手順を除く。

- `/Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/bdd-discovery-and-formulation-plugins/plugins/playbooks/bdd/data-model-bdd-discovery/{playbook.yml,SKILL.md}`
- `/Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/bdd-discovery-and-formulation-plugins/plugins/playbooks/bdd/data-model-bdd-formulation/{playbook.yml,SKILL.md}`
- `/Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/bdd-discovery-and-formulation-plugins/plugins/playbooks/bdd/domain-bdd-discovery/{playbook.yml,SKILL.md}`
- `/Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/bdd-discovery-and-formulation-plugins/plugins/playbooks/bdd/domain-bdd-formulation/{playbook.yml,SKILL.md}`
- `/Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/bdd-discovery-and-formulation-plugins/plugins/playbooks/bdd/user-journey-bdd-discovery/{playbook.yml,SKILL.md}`
- `/Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/bdd-discovery-and-formulation-plugins/plugins/playbooks/bdd/user-journey-bdd-formulation/{playbook.yml,SKILL.md}`
- `/Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/collect-and-digest-plugins/plugins/playbooks/collection/digest/{playbook.yml,SKILL.md}`
- `/Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/collect-and-digest-plugins/plugins/playbooks/collection/session-digest/{playbook.yml,SKILL.md}`
- `/Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/domain-modeling-plugins/plugins/playbooks/domain/model-domain/{playbook.yml,SKILL.md}`
- `/Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/product-planning-plugins/plugins/playbooks/product/product-north-star-planning/{playbook.yml,SKILL.md}`
- `/Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/product-planning-plugins/plugins/playbooks/product/product-strategy-planning/{playbook.yml,SKILL.md}`
- `/Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/pull-request-plugins/plugins/playbooks/pull-request/pr-review-response/{playbook.yml,SKILL.md}`
- `/Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/pull-request-plugins/plugins/playbooks/pull-request/pull-request/{playbook.yml,SKILL.md}`
- `/Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/system-design-plugins/plugins/system-design/playbooks/system-design/design-cloud-architecture/{playbook.yml,SKILL.md}`
- `/Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/system-design-plugins/plugins/system-design/playbooks/system-design/discover-quality-requirements/{playbook.yml,SKILL.md}`
- `/Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/system-design-plugins/plugins/system-design/playbooks/system-design/discover-requirements/{playbook.yml,SKILL.md}`
- `/Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/system-design-plugins/plugins/system-design/playbooks/system-design/discover-workload-model/{playbook.yml,SKILL.md}`

各 repository では、旧 runtime を前提とする playbook 配下の `scripts/`、共有 resolver、contract-version 検査、関連 fixture・README も検索し、新契約へ切り替える。provider の `implements[].version: 2` と不一致の v1 前提 resolver は互換性がない。消費側が v2 を直接呼べるようになるまで、旧 resolver を残して v2 provider を呼ぶ構成はサポートしない。
