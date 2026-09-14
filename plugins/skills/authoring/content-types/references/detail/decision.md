# 決定の型

## ADR（Architecture Decision Record）

**読み手**: 将来の自分と後任
**目的**: 決定と、その時点の文脈を残す
**成功条件**: 数年後に読んで「なぜこうなっているか」と「今も同じ判断をするか」が分かる

決定ごとに1ファイル。連番を振り、過去のものを書き換えない。変えるなら新しい ADR を書いて旧を Superseded にする。決定の記録であって、設計の説明でも実装手順でもない。

判断を分けた基準、候補比較、引き受けた不利益と見直し条件を残す。短さを理由に決定的根拠を削らない。提案状態で依頼された場合は決定待ちと明示し、合意を作らない。

**テンプレート**: [`assets/templates/adr.md`](../../assets/templates/adr.md)

**記載例**: [`assets/examples/adr.example.md`](../../assets/examples/adr.example.md)
