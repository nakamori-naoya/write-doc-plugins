# RoomFlowをはじめる

> これは [`getting-started.md`](../templates/getting-started.md) の記載例である。題材は架空の会議室予約サービスである。

これでローカルのRoomFlowを起動し、丸の内店M-301を顧客C-4102のために90分仮押さえできる。所要5分。

## 前提

- Docker 26以降を利用できること
- TCP 8080番ポートが空いていること
- ローカル開発用tokenを環境変数`ROOMFLOW_ACCESS_TOKEN`へ設定していること

## 手順

1. `git clone https://example.invalid/roomflow.git`を実行する。
2. `cd roomflow`を実行する。
3. `docker compose up -d`を実行する。
4. 次のcommandを実行する。

   ```bash
   curl -i -X POST http://localhost:8080/v1/reservations \
     -H "Authorization: Bearer ${ROOMFLOW_ACCESS_TOKEN}" \
     -H 'Idempotency-Key: getting-started-C-4102' \
     -H 'Content-Type: application/json' \
     -d '{"location_code":"marunouchi","room_code":"M-301","customer_code":"C-4102","starts_at":"2026-09-18T10:00:00+09:00","ends_at":"2026-09-18T11:30:00+09:00"}'
   ```

## 動いたことの確認

HTTP 201と予約番号`R-20260901-0101`、状態`tentative`、受付から15分後の`expires_at`が返れば成功である。同じcommandを再実行しても同じ予約番号が返り、予約が増えないことも確認する。

## 次に読むもの

- [会議室を予約するチュートリアル](tutorial.example.md)
- [会議室を90分の一つの利用枠として予約する方法](how-to.example.md)
