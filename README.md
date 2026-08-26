# Write Doc

資料の型、文章規律、図の設計、HTML/Markdownへの保存を組み合わせ、資料を1本作るClaude Code/Codex両対応marketplaceである。

```bash
codex plugin marketplace add nakamori-naoya/write-doc
codex plugin add write-doc@write-doc
```

`write-doc` playbookは同じmarketplaceの`content-types`、`writing-rules`、`visual-guidance`、`doc-render`をexact versionで解決する。BDDやproductなど呼び出し側の題材には依存しない。

```bash
bash scripts/validate.sh
```
