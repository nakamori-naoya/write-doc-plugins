# write-doc 改革の残作業・承認対象

この文書は、改革を完了するために残る破壊的変更を一つの承認単位へ集約する。記載した変更は未適用である。対象はすべて Git 追跡済みであり、削除後も履歴から復元できる。

## 承認を求める変更

### 1. repository 規約を新構成へ更新する

[AGENTS.md 改定案](agents-reform-proposal.md)の全文を、次のファイルへ適用する。

- `/Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/write-doc-plugins/AGENTS.md`

自動安全審査は、repository の統制ファイルから旧 runtime 規則を削除する変更を拒否した。提案内容は適用せず、利用者の明示承認を待っている。

### 2. 公開入口内の旧 manifest を削除する

次の二ファイルは、`version: 0.6.1` と `contractVersion: 1` を宣言する旧 manifest である。package root の新 manifest と競合するため削除する。

- `/Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/write-doc-plugins/plugins/playbooks/authoring/write-doc/.claude-plugin/plugin.json`
- `/Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/write-doc-plugins/plugins/playbooks/authoring/write-doc/.codex-plugin/plugin.json`

同じディレクトリの法的表示は削除しない。

- `/Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/write-doc-plugins/plugins/playbooks/authoring/write-doc/LICENSE`

この二 manifest は広い一括削除の対象に含まれたが、個別削除について独立した安全審査結果は得ていない。そのため、個別に拒否されたとは扱わない。

### 3. 旧 runtime と旧検証補助を削除する

[旧 runtime クリーンアップ案](runtime-cleanup-proposal.md)に記載された次の十ファイルを削除する。

- `/Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/write-doc-plugins/scripts/sync-runtime.py`
- `/Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/write-doc-plugins/shared/prepare.sh`
- `/Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/write-doc-plugins/shared/run-config.py`
- `/Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/write-doc-plugins/shared/runtime-manifest.json`
- `/Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/write-doc-plugins/shared/playbook/resolve-dependency.py`
- `/Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/write-doc-plugins/shared/playbook/resolve.sh`
- `/Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/write-doc-plugins/shared/playbook/state.py`
- `/Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/write-doc-plugins/shared/skill/resolve.sh`
- `/Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/write-doc-plugins/scripts/test-hardening.py`
- `/Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/write-doc-plugins/scripts/validate-distribution.py`

さらに、現行の最小 validator から参照されない次の三ファイルを削除する。

- `/Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/write-doc-plugins/scripts/validate-marketplace.sh`
- `/Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/write-doc-plugins/scripts/test-marketplace-validation.sh`
- `/Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/write-doc-plugins/scripts/test-content-type-fidelity.py`

`scripts/sync-runtime.py` の削除は、runtime-source 同期機構を失い恒久的な divergence を生む恐れがあるとして明示的に拒否された。残りの runtime 一式は広い一括削除で拒否された。個別の削除判定は得ていない。

### 4. CI と旧評価 fixture を整理する

[CI・旧評価資産クリーンアップ提案](ci-cleanup-proposal.md)に記載された全文へ、次の workflow を置き換える。

- `/Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/write-doc-plugins/.github/workflows/validate.yml`

同提案に記載された次の七ファイルを削除する。

- `/Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/write-doc-plugins/evals/common-templates-review.md`
- `/Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/write-doc-plugins/evals/document-review-check.md`
- `/Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/write-doc-plugins/evals/progressive-disclosure-reform.md`
- `/Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/write-doc-plugins/evals/reader-quality-review.md`
- `/Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/write-doc-plugins/evals/reader-quality.json`
- `/Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/write-doc-plugins/evals/scenarios.json`
- `/Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/write-doc-plugins/tests/fixtures/system-design-content-types/regression-cases.json`

自動安全審査は、評価資料・回帰 fixture・CI workflow の一括削除が検証能力と継続的品質保証を不可逆に弱めるとして拒否した。拒否された patch は適用されていない。

## 保持するもの

承認後の変更でも、次は保持する。

- package root の Claude/Codex manifest
- `author-document/assets/` の全資産
- `.github/workflows/secret-scanning.yml` などの security workflow
- `/Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/write-doc-plugins/docs/write-doc-reform-specification.md`
- 公開入口内の `LICENSE`
- Git 履歴

## 現在の完了状態

| Phase | 状態 | 残ること |
|---|---|---|
| Phase 1 | 完了 | なし |
| Phase 2 | 完了 | なし |
| Phase 3 | 一部完了 | 公開入口内の contract v1 旧 manifest 二本を削除する |
| Phase 4 | 一部完了 | repository 規約、旧 runtime、旧検証補助、CI、eval/test fixture を整理する |
| Phase 5 | ローカル確認済み | install 後の配布物検証と Mermaid のレンダリング確認を行う |

現在の `scripts/validate.sh` は、公開入口内の旧 manifest を検出し、32 件成功・1 件失敗で終了する。失敗項目は `package manifestはrootの2本だけ` である。上位 repository validator は通過するが、この成功だけでは Phase 3 の完了を示さない。

[作成テスト](write-doc-reform-architecture.md)はローカルで保存・読み直しを行い、中間 YAML が作られなかったことを確認した。インストール済み package からの実行と Mermaid レンダリングは未確認である。

## 承認後の確認

承認された対象だけを変更する。変更後は repository の `scripts/validate.sh` と上位 validator を再実行する。さらに、インストール済み package から Markdown と最終 SVG を生成し、Mermaid と相対リンクを表示環境で確認する。
