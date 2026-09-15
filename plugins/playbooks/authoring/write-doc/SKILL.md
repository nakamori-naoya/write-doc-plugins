---
name: write-doc
description: 素材からMarkdown資料を1本書いて保存する公開playbook。資料の新規作成または既存資料の更新に使う。
---

# write-doc

[公開契約](CONTRACT.md)の入力を受け取り、内部の [author-document](../../../skills/authoring/author-document/SKILL.md) を1回実行する。

1. `material` と、新規作成の `output_directory` + `name` または更新の `update_target` を確認する。
2. `document_type` と `references` があれば変更せず渡す。
3. `author-document` が返した `status` と、`path` または `reason` を公開契約の出力として直接返す。

入力が契約を満たさない場合は執筆せず、`status: failed` と理由を返す。保存先を推測しない。中間 YAML や実行設定ファイルは作らない。
