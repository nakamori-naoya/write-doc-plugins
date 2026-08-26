# 仮押さえ予約を作成する

> これは [`api-reference.md`](../templates/api-reference.md) の記載例である。値と原因・結果を引ける粒度で書く。

空いている一つの利用枠を15分間、仮押さえ予約として確保する。以下の識別子と値は架空である。

`POST /v1/reservations`

## 認証

`Authorization: Bearer <access-token>`が必要である。tokenには`reservations:write` scopeが必要で、対象拠点を担当する予約担当者を表す。足りない場合はHTTP 403を返す。

`Idempotency-Key`も必須である。同じkeyと同じbodyの再送には最初の結果を返し、予約を二重に作らない。

## リクエスト

| パラメータ | 型 | 必須 | 説明 |
|---|---|:---:|---|
| `location_code` | string | ○ | 予約担当者の担当拠点。例: `marunouchi` |
| `room_code` | string | ○ | 拠点内の会議室。例: `M-301` |
| `customer_code` | string | ○ | 予約可能顧客を識別する業務コード |
| `starts_at` | RFC 3339 string | ○ | 30分単位の利用開始。秒は`00` |
| `ends_at` | RFC 3339 string | ○ | 利用終了。開始より後、30分以上4時間以下 |

## レスポンス

成功時はHTTP 201を返す。

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

## エラー

| ステータス | コード | 意味 | 対処 |
|---|---|---|---|
| 400 | `INVALID_SLOT` | 利用時間が30分単位、30分以上4時間以下を満たさない | 開始・終了時刻を修正する |
| 409 | `SLOT_UNAVAILABLE` | 同じ枠が押さえられている | 空き状況を再取得する |
| 409 | `IDEMPOTENCY_KEY_REUSED` | 同じkeyが異なるbodyで使われた | 新しいkeyで意図した要求を送る |
| 422 | `TENTATIVE_HOLD_LIMIT` | 顧客が仮押さえ予約を3件持っている | 不要な仮押さえを取り消すか期限切れを待つ |
| 422 | `TENTATIVE_HOLD_SUSPENDED` | 顧客が仮押さえ停止中顧客である | 停止終了日時を確認する |

## 例

```bash
curl -i -X POST http://localhost:8080/v1/reservations \
  -H "Authorization: Bearer ${ROOMFLOW_ACCESS_TOKEN}" \
  -H 'Idempotency-Key: hold-C-4102-20260918-1000' \
  -H 'Content-Type: application/json' \
  -d '{"location_code":"marunouchi","room_code":"M-301","customer_code":"C-4102","starts_at":"2026-09-18T10:00:00+09:00","ends_at":"2026-09-18T11:30:00+09:00"}'
```

`HTTP/1.1 201 Created`、`Location: /v1/reservations/R-20260901-0101`、上記JSONが返れば仮押さえ予約は成立している。
