# 仮押さえ予約の作成を実行順に読む

> これは [`code-reading.md`](../templates/code-reading.md) の記載例である。コードは架空であり、実行順注釈の粒度を見るために使う。

> 型: コードリーディング ／ 読み手: 予約作成処理を自分で追う人 ／ 対象: 架空の`roomflow`リポジトリ

- **入口**: `createReservationHandler`（`src/http/create_reservation.ts`）
- **出口**: 仮押さえ予約または業務エラーを返す
- **固定した参照点**: `example-v2.3.0`
- **追わない範囲**: 認証tokenの検証、メール通知、DB driver内部

この処理はHTTP入力を業務入力へ変換し、予約可否を判断して仮押さえ予約を記録する。

## ① 何を追うか

HTTP handlerから予約記録までの幹を追う。これは差分の説明ではない。変更の可否は[実装解説](pr-walkthrough.example.md)で扱う。

## ② 幹の一覧

| # | 段階 | この段階で確定するもの | 場所 |
|---|---|---|---|
| 1 | [入力を検査する](#stage-1) | 業務入力 | `create_reservation.ts:12` |
| 2 | [予約を作る](#stage-2) | 仮押さえ予約または拒否 | `reservation_service.ts:20` |

## ③ 幹を実行順に読む

### <a id="stage-1"></a>段階1 — 入力を検査する

- **入力**: HTTP bodyの`room_id`、`starts_at`、`ends_at`
- **確定する値**: 30分枠として妥当な`CreateReservation`入力
- **分岐条件**: 時刻が30分単位でなければ400を返す
- **副作用**: なし
- **次の呼び出し**: `ReservationService.create`

```typescript
// ［入力］HTTPの表現を、業務処理が受け取る3項目へ限定する。
const input = parseCreateReservation(request.body);
// ［分岐］不正なら400で終了し、正しければ業務判断へ進む。
if (!input.ok) return badRequest(input.error);
// ［次へ］認証処理はここでは追わず、確定した入力だけを渡す。
return service.create(actor.id, input.value);
```

→ 次: 予約を作る

### <a id="stage-2"></a>段階2 — 予約を作る

- **入力**: 予約者IDと検査済みの枠
- **確定する値**: 15分後に期限切れになる仮押さえ予約
- **分岐条件**: 枠が埋まっていれば`SLOT_UNAVAILABLE`
- **副作用**: 予約を1件記録する
- **次の呼び出し**: なし

```typescript
// ［分岐］空きでなければ記録せず終了する。空きなら次へ進む。
if (!(await availability.isOpen(input.slot))) return slotUnavailable();
// ［次へ］記録方法の詳細は枝で読む。
return repository.insertTentative(actorId, input.slot);
```

## ④ 枝を読む

### <a id="branch-insert-tentative"></a>枝 — `insertTentative`

← [幹の段階2 — 予約を作るへ戻る](#stage-2)

- **幹との契約**: 顧客と利用枠を受け取り、保存済みの仮押さえ予約を返す
- **幹に効く点**: 期限をサーバ時刻から15分後に確定する
- **ここで打ち切る先**: DB driver内部

```typescript
// ［確定］期限は利用者入力ではなく、記録時刻から決まる。
const expiresAt = clock.now().plus({ minutes: 15 });
// ［副作用］仮押さえ予約と期限を1トランザクションで記録する。
return db.reservations.insert({ actorId, slot, status: "tentative", expiresAt });
```

## ⑤ 分岐と終端

| 条件 | どこで | 返るもの |
|---|---|---|
| 入力が30分単位でない | `create_reservation.ts:14` | HTTP 400 |
| 枠が空いていない | `reservation_service.ts:22` | `SLOT_UNAVAILABLE` |
| 利用枠が空いている | `reservation_repository.ts:18` | 仮押さえ予約 |

## ⑥ 未確認・追っていないもの

- 認証tokenから予約者IDを得る処理 — **未確認**（今回の入口より前で完了するため）
- DB driverの再試行条件 — **未確認**（driver内部は追わない範囲のため）

## ⑦ 付録

`CreateReservation`は`roomId`、`startsAt`、`endsAt`の3項目を持つ。実行順を持たない型定義なので、ここでは詳細を省く。
