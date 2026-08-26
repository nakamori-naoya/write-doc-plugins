# RoomFlow

> これは [`readme.md`](../templates/readme.md) の記載例である。架空のリポジトリを初めて開いた人へ入口を渡す。

RoomFlowは、複数拠点の貸会議室を顧客へ時間単位で販売するサンプルサービスである。空き利用枠の検索、仮押さえ予約、確定予約、取消、順番待ちを提供する。題材、識別子、計測値は架空である。

## インストール

1. Docker 26以降をインストールする。
2. `docker compose up -d`を実行する。

## 使い方（最小の例）

```bash
curl 'http://localhost:8080/v1/locations/marunouchi/rooms/M-301/availability?from=2026-09-18T10:00:00%2B09:00&to=2026-09-18T11:30:00%2B09:00'
```

HTTP 200と`{"available":true}`が返れば利用できる。仮押さえ予約の作成は[スタートガイド](getting-started.example.md)で確認する。

## トラブルシューティング

8080番ポートを使えない場合は、[トラブルシューティング](troubleshooting.example.md)を確認する。

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
