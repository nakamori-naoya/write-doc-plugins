# RoomFlow ドキュメント

> これは [`landing-page.md`](../templates/landing-page.md) の記載例である。説明を詰め込まず、読み手を目的別の資料へ送る。

RoomFlowで貸会議室の空き確認、仮押さえ、確定、取消、順番待ちができる。

初めて触る人は「はじめる」へ、日々予約する人は「やりたいことから探す」へ、値を確認する人は「引く」へ、業務の決まりを知りたい人は「仕組みを知る」へ、実装の判断をたどる人は「設計を追う」へ進む。

## はじめる

- [スタートガイド](getting-started.example.md) — 最短で動かす
- [チュートリアル](tutorial.example.md) — 予約のライフサイクルを体験する

## やりたいことから探す

- [連続した90分を確保する](how-to.example.md) — 90分を1件の確定予約として作る
- [夜間請求集計を再実行する](runbook.example.md) — 運用者が決まった手順で集計を復旧する
- [予約できない原因を調べる](troubleshooting.example.md) — 表示された症状から原因を切り分ける

## 仕組みを知る

- [仮押さえ予約と確定予約](concept.example.md)
- [貸会議室予約の業務知識・コアドメイン](domain-rule.example.md)

## 設計を追う

- [ADR-0007: 重なる利用枠をPostgreSQLの排他制約で防ぐ](adr.example.md)
- [RDB論理設計](rdb-logical-data-modeling.example.md)
- [予約作成経路のコード地図](code-map.example.md)

## 引く

- [APIリファレンス](api-reference.example.md)
- [用語集](glossary.example.md)
- [トラブルシューティング](troubleshooting.example.md)

このページは入口だけを置く。設計判断の比較、全画面の説明、障害の詳細な時系列は、それぞれ該当する文書で確認する。
