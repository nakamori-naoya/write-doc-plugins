# 仮押さえ予約を作成する

> これは [`api-reference.md`](../templates/api-reference.md) の記載例である。RoomFlowのエンドポイント・仕様・応答はすべて説明用の架空例であり、実装や実行結果を確認したものではない。

予約連携を実装する開発者向けに、仮押さえ作成の入力、成功の見分け方、再送条件を定義する。空いている一つの利用枠を、作成時点から15分間確保する。確定・取消APIはこのページの対象外である。

`POST /v1/reservations`

## 認証

`Authorization: Bearer <access-token>`が必要である。tokenは予約担当者を表し、`reservations:write` scopeと対象拠点への権限を持つ必要がある。tokenが無効ならHTTP 401、scopeまたは拠点権限が足りなければHTTP 403を返す。

## リクエスト

JSONを送る。path/queryパラメータはなく、以下のbody項目に既定値はない。

| ヘッダー | 必須 | 値・条件 |
|---|:---:|---|
| `Content-Type` | ○ | `application/json` |
| `Authorization` | ○ | 上記のBearer token |
| `Idempotency-Key` | ○ | 1〜128文字のASCII文字列。一つの作成意図につき一つ発行する |

同じ予約担当者の同じkey・同じbodyへの再送は、成功結果を24時間再利用する。通信が途切れて結果が分からない場合は、keyとbodyを変えずに再送する。同じ予約ID・作成時の期限が返り、期限は延びない。24時間後の再送は新規作成になり得るため、予約一覧で結果を確認してから判断する。この例は成功結果の再利用だけを定義し、処理中の同時再送は扱わない。

| パラメータ | 型 | 必須 | 説明 |
|---|---|:---:|---|
| `location_code` | string | ○ | 予約担当者の担当拠点。例: `marunouchi` |
| `room_code` | string | ○ | 拠点内の会議室。例: `M-301` |
| `customer_code` | string | ○ | 予約可能顧客を識別する業務コード |
| `starts_at` | RFC 3339 string | ○ | 30分単位の利用開始。秒は`00` |
| `ends_at` | RFC 3339 string | ○ | 30分単位の利用終了。開始より後、差は30分以上4時間以下。秒は`00` |

時刻にはUTC offsetを含める。利用時間帯は開始を含み、終了を含まない。10:00〜11:30の予約は11:00〜12:00と競合するが、11:30〜12:00とは競合しない。

## レスポンス

成功時はHTTP 201と`Location: /v1/reservations/<reservation_id>`を返す。以下は2026-09-01 09:00（日本時間）に作成した場合の応答例である。

```json
{
  "reservation_id": "R-20260901-0101",
  "location_code": "marunouchi",
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
| `location_code` / `room_code` / `customer_code` | string | 受理した拠点・会議室・顧客 |
| `starts_at` / `ends_at` | RFC 3339 string | 受理した利用時間帯 |
| `status` | string | このAPIの成功時は`tentative`。確定予約ではない |
| `expires_at` | RFC 3339 string | 仮押さえの確定期限。期限ちょうどから確定できない |

`expires_at`は9月18日の利用終了時刻ではなく、9月1日の確定期限である。HTTP 201を受け取っても、期限内に確定しなければ仮押さえは失効する。

## エラー

| ステータス | コード | 意味 | 対処 |
|---|---|---|---|
| 400 | `INVALID_REQUEST` | 必須項目・ヘッダーの不足、JSONや型の不正 | エラーの`message`が指す項目を修正する |
| 400 | `INVALID_SLOT` | 利用時間が30分単位、30分以上4時間以下を満たさない | 開始・終了時刻を修正する |
| 401 | `UNAUTHENTICATED` | tokenが無い、無効、または期限切れ | 有効なtokenを取得する |
| 403 | `PERMISSION_DENIED` | scopeまたは対象拠点への権限がない | 権限を持つ担当者へ依頼する |
| 409 | `SLOT_UNAVAILABLE` | 同じ枠が押さえられている | 空き状況を再取得する |
| 409 | `IDEMPOTENCY_KEY_REUSED` | 同じkeyが異なるbodyで使われた | 新しいkeyで意図した要求を送る |
| 422 | `TENTATIVE_HOLD_LIMIT` | 顧客が仮押さえ予約を3件持っている | 不要な仮押さえを取り消すか期限切れを待つ |
| 422 | `TENTATIVE_HOLD_SUSPENDED` | 顧客が仮押さえ停止中顧客である | 停止終了日時を確認する |

エラーbodyは`error.code`、表示用の`error.message`、問い合わせ用の`request_id`を持つ。分岐には文言ではなく`code`を使う。たとえばHTTP 409の応答は次の形になる。

```json
{"error":{"code":"SLOT_UNAVAILABLE","message":"この利用枠は予約できません"},"request_id":"req-example-002"}
```

## 例

ローカルの例示サーバーが起動し、拠点・会議室・顧客が登録済みという前提である。`ROOMFLOW_ACCESS_TOKEN`には上記権限のtokenを設定する。

```bash
curl -i -X POST http://localhost:8080/v1/reservations \
  -H "Authorization: Bearer ${ROOMFLOW_ACCESS_TOKEN}" \
  -H 'Idempotency-Key: hold-C-4102-20260918-1000' \
  -H 'Content-Type: application/json' \
  -d '{"location_code":"marunouchi","room_code":"M-301","customer_code":"C-4102","starts_at":"2026-09-18T10:00:00+09:00","ends_at":"2026-09-18T11:30:00+09:00"}'
```

`HTTP/1.1 201 Created`、`Location: /v1/reservations/R-20260901-0101`、上記JSONが返れば仮押さえ予約は成立している。
