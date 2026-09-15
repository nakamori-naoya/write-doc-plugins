# content-types

**誰に何を届けるかを決める。** 同梱ペルソナから読み手を1人選び、読後の到達点を問いへ落とし、そこから文書の型を1つ選んで、テンプレートと記載例を渡す。

**順序を入れ替えない。** 読み手 → 到達点 → 型である。型を先に決めると、型が持つ節を埋めるために内容を集めることになる。

**規律も媒体も知らない。** どう書くか・どう出すかは、それぞれ別の関心である。

## 使う

```
/pick-content-type      読み手と到達点を決めて、型と骨格を取る
```

## 何を持っているか

| もの | 正本 |
|---|---|
| 読み手ペルソナ（5人・固定。語を3段階で持つ） | [references/personas.md](references/personas.md) |
| 15種の型の選び方・一覧・型ごとの固定事項 | [references/catalog.md](references/catalog.md) |
| 型ごとの読み手・目的・境界 | `references/detail/*.md` |
| テンプレートと記載例の対応 | [assets/template-examples.yml](assets/template-examples.yml) |

テンプレートの各節には、コメント（`<!-- -->`）で「書く／書かない」の境界がある。`<!-- -->` は Markdown ビューアが表示しないコメント記法として許容する、テンプレートで唯一の Markdown 外の記法である。記載例は粒度と具体性の見本であり、構成の正本ではない。

専門領域の内容の正しさや作業方法は入力が与える。この能力はそれらを補わない。

## 設定

```yaml
# <repo>/.harness-plugins/content-types.config.yml
version: 1
default_type: concept           # カタログで型が一意に決まらないときの型
instructions:
  reader:
    directive: personasから読み手を1人選び、読後の到達点を本文だけで答えられる問い2〜4個へ落としてから型を決める
  selection:
    directive: 到達点を達成する型を、catalogの選び方を上から判定して1つだけ選ぶ
```

このファイルだけで完結させる。personal設定や同梱既定から不足キーは補われない。`default_type` に対応するテンプレートが無ければ止まる。

## しないこと

- 文章を書かない
- 媒体の書式を決めない
- 型を足さない（カタログ「この15型で扱わないもの」）
