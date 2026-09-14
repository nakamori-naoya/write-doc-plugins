# writing-rules

**読み手が本文だけから必要な理解を組み立て、目的の判断や行動ができる文章を書くための規律。** 前提と到達点から主張・経路・構成を決め、その順で書き、本文から問いに答えて確かめる。

**媒体を知らない。** Markdown なのかプレーンテキストなのかは決めない。だから資料に限らず使える——PR の説明文、チケット、レビューコメント、メール。

## 使う

```
/write-with-rules      規律に従って書く／直す
```

## 規律は10本。1つの規則は1か所にだけある

適用の順序は [apply.md](references/apply.md)、出す前の確認項目は [final-check.md](references/final-check.md) にだけある。

| 規律 | 何を決めるか | 及ぶ範囲 |
|---|---|---|
| [`path`](references/path.md) | 概念の導入順と、本文に置く節の集合。経路表が順序と長さを決める | 文書全体 |
| [`argument`](references/argument.md) | 主張は1つ、根拠は強いものを1つ、反駁・限定・前提は主張の隣、経緯は前提へ畳む | 文書・節・主張 |
| [`structure`](references/structure.md) | 見出し・冒頭・末尾・本文に残す情報・図表文の使い分け | 文書全体 |
| [`section`](references/section.md) | 節の中の書き進め方。問いへの答え、段落、例、R1〜R12 の書き方 | セクション |
| [`emphasis`](references/emphasis.md) | 強調の役は要点・キーワードの2つ。どこへ当て、どこへ当てないか | 語・節 |
| [`style`](references/style.md) | 語り口、1文の形、密度、主体と述語の対応、手順 | 文 |
| [`terminology`](references/terminology.md) | 語の実在確認、読み手に通じるかの判定、言い換え、造語の宣言。**差し替え不可** | 常に |
| [`citation`](references/citation.md) | 出典の3点セットと日本語訳。**差し替え不可** | 出典 |
| [`evidence`](references/evidence.md) | 実測・推定の条件、比較できる範囲、値と空欄の意味 | 観測値・比較表 |
| [`annotated-code`](references/annotated-code.md) | 差分注釈と実行順注釈。2層掲載、途中への差し込み、幹と枝 | コード |

## 設定

```yaml
# <repo>/.harness-plugins/writing-rules.config.yml
version: 1
rules:
  section: docs/guides/section.md      # 自分のファイルで既定を上書き
  emphasis: docs/guides/emphasis.md
extra: "docs/guides/terms.md, docs/guides/brand.md"   # 追加の規律
instructions:
  writing:
    directive: rulesの各ファイルと適用手順を読み、読み手の前提と到達点からargumentで主張と根拠と経緯の扱いを決め、pathで経路表を作り、structure、section、style、terminology、emphasisを適用し、citation、evidence、annotated-codeを該当時に適用する
```

設定は自己完結させる。repository設定があればpersonalや同梱既定は読まれない。

**指定したのにファイルが無ければ止まる。** 黙って既定へ倒れると、差し替えたつもりで効いていない状態になる。`rules.citation` と `rules.terminology` を指すと止まる。

## しないこと

- 媒体の記法を決めない（太字・バッククォート・Mermaid のどれへ写すかは doc-render）
- 文書の型を知らない
- 中身を機械で検査しない。強調率も引用数も測らない
