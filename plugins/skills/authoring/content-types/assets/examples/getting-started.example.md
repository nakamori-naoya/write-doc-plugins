# RoomFlowをはじめる

> これは [`getting-started.md`](../templates/getting-started.md) の記載例である。題材の会議室予約サービスRoomFlow、clone先、tokenの発行commandはすべて架空であり、**このまま実行しても動かない**。手順の粒度と成功判定の書き方を読むための例として使う。

このガイドで、ローカルのRoomFlowを起動し、会議室M-301を90分だけ仮押さえした状態を一度作る。

確認するのは「初回に1件作れるか」だけである。確定、取消、順番待ち、権限設定は扱わない。体系的に学ぶなら[チュートリアル](tutorial.example.md)、項目ごとの値は[APIリファレンス](api-reference.example.md)へ進む。

## 前提

- Docker 26以降を利用できること
- TCP 8080番ポートが空いていること
- `curl`を実行できること

## 手順

1. `git clone <RoomFlowのリポジトリURL>`を実行する。
2. `cd roomflow`を実行する。
3. `docker compose up -d`を実行する。
4. `docker compose ps`を実行し、`api`と`db`が`running`になるまで待つ。
5. `export ROOMFLOW_ACCESS_TOKEN=$(docker compose exec -T api roomflow issue-dev-token --customer C-4102)`を実行し、顧客`C-4102`を表すローカル開発用tokenを取得する。
6. 次のcommandを実行する。

   ```bash
   curl -i -X POST http://localhost:8080/v1/reservations \
     -H "Authorization: Bearer ${ROOMFLOW_ACCESS_TOKEN}" \
     -H 'Idempotency-Key: getting-started-C-4102-20260918-1000' \
     -H 'Content-Type: application/json' \
     -d '{"room_code":"M-301","starts_at":"2026-09-18T10:00:00+09:00","ends_at":"2026-09-18T11:30:00+09:00"}'
   ```

## 動いたことの確認

`HTTP/1.1 201 Created`が返り、bodyの`status`が`tentative`、`expires_at`が実行時刻の15分後になっていれば成功である。**返った`reservation_id`を控える。** 以降の手順ではその値を使う。予約IDは実行するたびに変わるので、下の値と一致しなくてよい。

次は2026-09-01 09:00に受け付けた場合の説明用レスポンスである。

```json
{
  "reservation_id": "R-20260901-0101",
  "room_code": "M-301",
  "customer_code": "C-4102",
  "starts_at": "2026-09-18T10:00:00+09:00",
  "ends_at": "2026-09-18T11:30:00+09:00",
  "status": "tentative",
  "expires_at": "2026-09-01T09:15:00+09:00"
}
```

同じ`Idempotency-Key`で再実行しても、控えた予約IDと同じ値が返り、予約が増えないことも確認する。`expires_at`は予約を確定するまでの期限であり、9月18日の利用時間を短くする値ではない。

## 次に読むもの

- [会議室を予約するチュートリアル](tutorial.example.md)
- [会議室を90分の一つの利用枠として予約する方法](how-to.example.md)
