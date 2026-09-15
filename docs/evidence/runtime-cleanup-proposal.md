# 旧 runtime クリーンアップ案（未適用）

新しい manifest、公開入口、内部 skill、`scripts/validate.sh` は次の旧 runtime を参照しない。自動安全審査が runtime 同期機構の削除を拒否したため、利用者の明示承認まで残す。

## 明示的に拒否された対象

- `/Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/write-doc-plugins/scripts/sync-runtime.py`

拒否理由は「runtime-source synchronization mechanism を削除すると、明示された SKILL/pipeline simplification の範囲外で永続的な divergence の恐れがある」である。

## 同じ runtime 機構として残す対象

- `/Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/write-doc-plugins/shared/prepare.sh`
- `/Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/write-doc-plugins/shared/run-config.py`
- `/Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/write-doc-plugins/shared/runtime-manifest.json`
- `/Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/write-doc-plugins/shared/playbook/resolve-dependency.py`
- `/Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/write-doc-plugins/shared/playbook/resolve.sh`
- `/Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/write-doc-plugins/shared/playbook/state.py`
- `/Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/write-doc-plugins/shared/skill/resolve.sh`
- `/Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/write-doc-plugins/scripts/test-hardening.py`
- `/Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/write-doc-plugins/scripts/validate-distribution.py`

これらの一括削除も、tests・evals・nested manifests 等との広い削除命令に含めた際、「不可逆な損失と検証・package governance の弱体化」として拒否された。個別の削除判定は得ていない。`sync-runtime.py` を迂回して無効化しないため、同じ runtime 一式を承認待ちとして保持する。

承認後は上記だけを削除し、`scripts/validate.sh` と上位 validator を再実行する。security workflow、root package manifest、asset、正式仕様、履歴 release は対象に含めない。
