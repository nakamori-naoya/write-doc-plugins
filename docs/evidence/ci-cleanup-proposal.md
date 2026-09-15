# CI・旧評価資産クリーンアップ提案

この提案は未適用である。安全審査が、評価資料・回帰 fixture・CI workflow の一括削除を不可逆な検証能力低下と判定したためである。利用者の明示承認を得るまで、対象ファイルを変更または削除しない。

## 安全審査の結果

拒否理由は次のとおりである。

> 評価資料・回帰fixture・CIワークフローをまとめて削除する変更は、明示された改革範囲を超え、検証能力と継続的品質保証を不可逆に弱めます。

安全審査は、別の手段による同じ変更の再試行も禁止した。拒否された patch は原子的に適用されなかったため、対象ファイルに部分変更はない。

## 承認後に削除する対象

以下は Git 管理下の既存ファイルである。

- `/Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/write-doc-plugins/evals/common-templates-review.md`
- `/Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/write-doc-plugins/evals/document-review-check.md`
- `/Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/write-doc-plugins/evals/progressive-disclosure-reform.md`
- `/Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/write-doc-plugins/evals/reader-quality-review.md`
- `/Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/write-doc-plugins/evals/reader-quality.json`
- `/Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/write-doc-plugins/evals/scenarios.json`
- `/Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/write-doc-plugins/tests/fixtures/system-design-content-types/regression-cases.json`

これらは旧ランタイム構成または文章品質の代理評価に結び付いた資産である。削除後も、構造契約はリポジトリの `scripts/validate.sh` で検査する。文章の意味と品質は、対象文書を読む根拠付きレビューで評価する。

## 承認後に置き換える CI

対象は `/Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/write-doc-plugins/.github/workflows/validate.yml` である。兄弟リポジトリの checkout、同名 branch 解決、Python・Go の setup、`yq` の導入を廃止する。

提案する全文は次のとおりである。

```yaml
name: Functional validation

on:
  push:
  pull_request:

permissions:
  contents: read

jobs:
  validate:
    name: validate (${{ matrix.os }})
    strategy:
      fail-fast: false
      matrix:
        os: [ubuntu-latest, macos-latest]
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@11d5960a326750d5838078e36cf38b85af677262 # v4

      - name: Install validation commands
        shell: bash
        run: |
          if [ "$RUNNER_OS" = Linux ]; then
            sudo apt-get update
            sudo apt-get install -y jq ripgrep
          else
            brew list jq >/dev/null 2>&1 || brew install jq
            brew list ripgrep >/dev/null 2>&1 || brew install ripgrep
          fi

      - name: Validate repository contract
        shell: bash
        run: bash scripts/validate.sh
```

## 承認後の検証

変更後は、ローカルの `bash scripts/validate.sh` と上位の repository 検証を実行する。CI では Ubuntu と macOS の両方で同じリポジトリ内検証を実行する。文章量、キーワード数、見出し数、類似度は合否判定に使わない。
