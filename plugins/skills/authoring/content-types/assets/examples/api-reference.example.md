# 仮押さえ予約を作成する

> これは [`api-reference.md`](../templates/api-reference.md) の記載例である。RoomFlowのエンドポイント・仕様・応答はすべて説明用の架空例であり、実装や実行結果を確認したものではない。

予約連携を実装する開発者向けに、仮押さえ作成の入力、成功の見分け方、再送条件を定義する。空いている一つの利用枠を、作成時点から15分間確保する。この操作が守る業務上の決まりは[業務知識・コアドメインの記載例](domain-rule.example.md)にあり、ここでは繰り返さず、その決まりがHTTPでどう現れるかだけを書く。確定・取消APIはこのページの対象外である。

`POST /v1/reservations`

## 認証

`Authorization: Bearer <access-token>`が必要である。tokenは予約者本人を表し、`reservations:write` scopeを持つ必要がある。作成される仮押さえ予約は、このtokenが表す予約者の予約になる。tokenが無効ならHTTP 401、scopeが足りなければHTTP 403を返す。

## リクエスト

JSONを送る。path/queryパラメータはなく、以下のbody項目に既定値はない。

| ヘッダー | 必須 | 値・条件 |
|---|:---:|---|
| `Content-Type` | ○ | `application/json` |
| `Authorization` | ○ | 上記のBearer token |
| `Idempotency-Key` | ○ | 1〜128文字のASCII文字列。一つの作成意図につき一つ発行する |

| パラメータ | 型 | 必須 | 説明 |
|---|---|:---:|---|
| `room_code` | string | ○ | 会議室を一意に識別する業務コード。例: `M-301` |
| `starts_at` | RFC 3339 string | ○ | 利用開始。秒は`00` |
| `ends_at` | RFC 3339 string | ○ | 利用終了。開始より後 |

時刻にはUTC offsetを含める。利用枠は開始を含み、終了を含まない。10:00から11:30までの予約は11:00から12:00までと競合するが、11:30から12:00までとは競合しない。

## 再送と冪等性

同じ予約者が、同じ`Idempotency-Key`と同じbodyで再送したときの扱いを、元の要求の状態ごとに定める。通信が途切れて結果が分からない場合は、keyとbodyを変えずに再送してよい。

| 元の要求の状態 | 再送への応答 | 呼び出し側がすること |
|---|---|---|
| 成功して終わっている | HTTP 201と同じ`reservation_id`・同じ`expires_at`。期限は延びない | そのまま成功として扱う |
| まだ処理中 | HTTP 409 `REQUEST_IN_PROGRESS`。`Retry-After: 1`を付ける | 1秒待って同じkeyで再送する。最大10回まで |
| 失敗して終わっている | 失敗時と同じステータスとコード | エラーに応じて対処する |
| 同じkeyで異なるbody | HTTP 409 `IDEMPOTENCY_KEY_REUSED` | 新しいkeyで意図した要求を送る |
| 保持期限を過ぎている | 新しい要求として処理される。二重に成立し得る | 予約一覧で結果を確認してから送る |

保持期限は、元の要求を受け付けた時刻から24時間である。`expires_at`（仮押さえの確定期限）とは別の時計であり、混同しない。

## レスポンス

成功時はHTTP 201と`Location: /v1/reservations/<reservation_id>`を返す。以下は2026-09-01 09:00（日本時間）に作成した場合の応答例である。

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

| フィールド | 型 | 意味 |
|---|---|---|
| `reservation_id` | string | 作成された予約の識別子。再送でも同じ値 |
| `room_code` | string | 受理した会議室 |
| `customer_code` | string | tokenから決まった予約者。要求では送らない |
| `starts_at` / `ends_at` | RFC 3339 string | 受理した利用枠 |
| `status` | string | このAPIの成功時は`tentative`。確定予約ではない |
| `expires_at` | RFC 3339 string | 仮押さえの確定期限。期限ちょうどから確定できない |

`expires_at`は9月18日の利用終了時刻ではなく、9月1日の確定期限である。HTTP 201を受け取っても、期限内に確定しなければ仮押さえは失効する。

## エラー

| ステータス | コード | 意味 | 対処 |
|---|---|---|---|
| 400 | `INVALID_REQUEST` | 必須項目・ヘッダーの不足、JSONや型の不正、`ends_at`が`starts_at`以前 | エラーの`message`が指す項目を修正する |
| 401 | `UNAUTHENTICATED` | tokenが無い、無効、または期限切れ | 有効なtokenを取得する |
| 403 | `PERMISSION_DENIED` | `reservations:write` scopeがない | 必要なscopeを持つtokenを取得する |
| 404 | `ROOM_NOT_FOUND` | `room_code`に対応する会議室がない | 会議室コードを確認する |
| 409 | `SLOT_UNAVAILABLE` | 同じ会議室の重なる利用枠を、別の仮押さえ予約か確定予約が占有している | 空き状況を再取得する |
| 409 | `REQUEST_IN_PROGRESS` | 同じkeyの要求をまだ処理している | `Retry-After`の秒数だけ待って同じkeyで再送する |
| 409 | `IDEMPOTENCY_KEY_REUSED` | 同じkeyが異なるbodyで使われた | 新しいkeyで意図した要求を送る |
| 422 | `TENTATIVE_HOLD_SUSPENDED` | 予約者が仮押さえ停止中顧客である | `error.details.suspended_until`の停止終了日時まで待つ |

エラーbodyは`error.code`、表示用の`error.message`、問い合わせ用の`request_id`を持つ。分岐には文言ではなく`code`を使う。たとえばHTTP 409の応答は次の形になる。

```json
{"error":{"code":"SLOT_UNAVAILABLE","message":"この利用枠は予約できません"},"request_id":"req-example-002"}
```

## 例

ローカルの例示サーバーが起動し、会議室と顧客が登録済みという前提である。`ROOMFLOW_ACCESS_TOKEN`には顧客`C-4102`を表すtokenを設定する。

```bash
curl -i -X POST http://localhost:8080/v1/reservations \
  -H "Authorization: Bearer ${ROOMFLOW_ACCESS_TOKEN}" \
  -H 'Idempotency-Key: hold-C-4102-20260918-1000' \
  -H 'Content-Type: application/json' \
  -d '{"room_code":"M-301","starts_at":"2026-09-18T10:00:00+09:00","ends_at":"2026-09-18T11:30:00+09:00"}'
```

`HTTP/1.1 201 Created`、`Location: /v1/reservations/R-20260901-0101`、上記JSONが返れば仮押さえ予約は成立している。
