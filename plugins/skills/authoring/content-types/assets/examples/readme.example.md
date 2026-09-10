# RoomFlow

> これは`readme`型の記載例である。**構成の正本ではなく、粒度と具体性の見本として読む。**リポジトリ、clone先、識別子、計測値はすべて架空であり、**このまま実行しても動かない**。初めて開いた人へ入口を渡す書き方の例として使う。

RoomFlowは、貸会議室を顧客へ時間単位で販売するサンプルサービスである。空き利用枠の検索、仮押さえ予約、確定予約、取消、順番待ちを提供する。このREADMEでは起動と空き確認までを案内し、予約作成は[スタートガイド](getting-started.example.md)、項目ごとの値は[APIリファレンス](api-reference.example.md)へ委ねる。

## インストール

対応環境はmacOSまたはLinux、Docker 26以降、空いているTCP 8080番ポートである。認証を使うAPIを試す場合は、ローカル開発用tokenを`ROOMFLOW_ACCESS_TOKEN`へ設定する。

1. `git clone <RoomFlowのリポジトリURL>`を実行する。
2. `cd roomflow`を実行する。
3. `docker compose up -d`を実行する。
4. `docker compose ps`を実行し、`api`と`db`が`running`になっていることを確かめる。

## 使い方（最小の例）

```bash
curl 'http://localhost:8080/v1/rooms/M-301/availability?from=2026-09-18T10:00:00%2B09:00&to=2026-09-18T11:30:00%2B09:00'
```

HTTP 200と`{"available":true}`が返れば利用できる。仮押さえ予約の作成は[スタートガイド](getting-started.example.md)で確認する。

## トラブルシューティング

8080番ポートを使えない場合は、[トラブルシューティング](troubleshooting.example.md)を確認する。

`ROOMFLOW_ACCESS_TOKEN`が未設定のまま予約作成APIを呼ぶとHTTP 401が返る。空き確認APIだけならtokenなしで試せる。

## 開発で最初に見る場所

| 知りたいこと | 入口 |
|---|---|
| 予約状態の意味 | [コンセプト](concept.example.md) |
| 予約APIの値 | [APIリファレンス](api-reference.example.md) |
| 予約通知の変更作業 | [オンボーディング](onboarding.example.md) |

## 更新履歴

[リリースノート](release-notes.example.md)に利用者へ影響する変更を記録する。

## メンテナー

RoomFlowチーム。連絡先は`#roomflow-dev`である。

## ライセンス

MIT License。原文はリポジトリの`LICENSE`に置く。

## もっと詳しく

- [スタートガイド](getting-started.example.md)
- [コンセプト](concept.example.md)
- [APIリファレンス](api-reference.example.md)
