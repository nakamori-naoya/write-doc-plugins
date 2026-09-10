# 仮押さえ予約の作成を実行順に読む

> これは [`code-reading.md`](../templates/code-reading.md) の記載例である。コード・パス・行番号・参照点は架空であり、原典の恒久リンクは張れない。掲載部分で分かる動作と、追っていない先を分ける例として使う。

> 型: コードリーディング ／ 読み手: 予約作成処理を自分で追う人 ／ 対象: 架空の`roomflow`リポジトリ

- **入口**: `createReservationHandler`（`src/http/create_reservation.ts`）
- **出口**: 仮押さえ予約または業務エラーを返す
- **固定した参照点**: `example-v2.3.0`
- **追わない範囲**: 認証tokenの検証、メール通知、DB driver内部

この処理はHTTP入力を業務入力へ変換し、予約可否を判断して仮押さえ予約を記録する。

## 注釈の凡例

注釈は実行時の役割を表す。差分の凡例とは別物なので、この文書に差分の区分は置かない。

| 表記 | 何に付けるか |
|---|---|
| ［入力］ | この段階が受け取った値と、その出どころ |
| ［確定］ | この行を抜けた時点で決まった値 |
| ［分岐］ | 条件と、どちらへ行くか。両方の行き先を書く |
| ［副作用］ | DB・キャッシュ・ログなど、外へ出るもの |
| ［次へ］ | 次にどこを呼ぶか |

掲載を省いた範囲には`// …（省略: <原典の行範囲>）`を置く。実在するリポジトリを扱うときは、この行範囲を原典の恒久リンクにする。

## ① 何を追うか

HTTP handlerから予約記録までの幹を追う。これは差分の説明ではない。変更の可否は[実装解説](pr-walkthrough.example.md)で扱う。

認証済みの予約者`C-4102`が、会議室`M-301`の2026年9月18日 10:00から11:30までを申し込む例を通して読む。以下の簡略コードで確認できるのは入力拒否・事前の空き確認・保存であり、同時要求への最終的な競合処理は掲載していない。

## ② 幹の一覧

| # | 段階 | この段階で確定するもの | 場所 |
|---|---|---|---|
| 1 | [入力を検査する](#stage-1) | 業務入力 | `create_reservation.ts:12` |
| 2 | [予約を作る](#stage-2) | 仮押さえ予約または拒否 | `reservation_service.ts:20` |

## ③ 幹を実行順に読む

### <a id="stage-1"></a>段階1 — 入力を検査する

- **入力**: HTTP bodyの`room_code`、`starts_at`、`ends_at`
- **確定する値**: 会議室と開始・終了を`slot`にまとめた業務入力
- **分岐条件**: 必須項目が無い、または終了が開始以前の場合は400を返す。それ以外は段階2へ進む
- **副作用**: なし
- **次の呼び出し**: `ReservationService.create`

```typescript
// …（省略: create_reservation.ts:1-11 — importと認証tokenの検証）
// ［入力］3項目を検査し、成功なら { slot: { roomCode, startsAt, endsAt } } にする。
const input = parseCreateReservation(request.body);
// ［分岐］不正なら400で終了し、正しければ業務判断へ進む。
if (!input.ok) return badRequest(input.error);
// ［次へ］認証処理はここでは追わず、確定した入力だけを渡す。
return service.create(actor.id, input.value);
```

`parseCreateReservation`の内部と認証処理は省略している。上の例では`slot`がM-301、10:00、11:30を持ち、`actor.id`の`C-4102`と一緒に渡る。

→ 次: [予約を作る](#stage-2)

### <a id="stage-2"></a>段階2 — 予約を作る

- **入力**: 予約者IDと検査済みの枠
- **確定する値**: 15分後に期限切れになる仮押さえ予約
- **分岐条件**: 枠が埋まっていれば`SLOT_UNAVAILABLE`。空いていれば保存する
- **副作用**: 保存成功時に予約を1件記録する。事前確認で拒否した場合は書き込まない
- **次の呼び出し**: `reservationRepository.createTentativeHold`。戻り値をそのまま呼び出し元へ返す

```typescript
// ［分岐］空きでなければ記録せず終了する。空きなら次へ進む。
if (!(await availability.isOpen(input.slot))) return slotUnavailable();
// ［副作用・次へ］保存済みの仮押さえ予約を返す。詳細は直下の枝リンクへ。
return reservationRepository.createTentativeHold(actorId, input.slot);
```

→ [枝: `createTentativeHold`](#branch-create-tentative-hold)

`availability.isOpen`の照会内部は省略している。保存が成功すれば、呼び出し元へ予約ID・状態`tentative`・確定期限が返る。保存の例外はこのコードでは捕捉せず、呼び出し元へ伝わる。

## ④ 枝を読む

### <a id="branch-create-tentative-hold"></a>枝 — `createTentativeHold`（`src/persistence/reservation_repository.ts`）

← [幹の段階2 — 予約を作るへ戻る](#stage-2)

- **幹との契約**: 予約者IDと利用枠を受け取り、保存済みの仮押さえ予約を返す
- **幹に効く点**: 期限をサーバ時刻から15分後に確定する
- **ここで打ち切る先**: DB driver内部

```typescript
// ［確定］期限は利用者入力ではなく、記録時刻から決まる。
const expiresAt = clock.now().plus({ minutes: 15 });
// ［副作用］同じ予約レコードに状態と期限を保存する。DB driver内部は追わない。
return db.reservations.insert({ actorId, slot, status: "tentative", expiresAt });
```

記録時刻が9月1日09:00なら`expiresAt`は同日09:15になる。9月18日10:00という利用開始時刻は期限計算へ渡していない。この違いは`clock.now()`を使う行から確認できる。

## ⑤ 分岐と終端

| 条件 | どこで | 返るもの |
|---|---|---|
| 必須項目・時刻の検査に失敗 | `create_reservation.ts:14` | HTTP 400。保存なし |
| 枠が空いていない | `reservation_service.ts:22` | `SLOT_UNAVAILABLE` |
| 利用枠が空いており保存成功 | `reservation_repository.ts:18` | ID・状態・期限を持つ仮押さえ予約 |
| 空き照会または保存が例外を投げる | 各呼び出し行 | 例外が呼び出し元へ伝わる。HTTPへの変換は未掲載 |

## ⑥ 未確認・追っていないもの

- 認証tokenから予約者IDを得る処理 — **未確認**（今回の入口より前で完了するため）
- DB driverの再試行条件 — **未確認**（driver内部は追わない範囲のため）
- 保存時の競合拒否とHTTP応答への変換 — **未確認**。この抜粋から同時要求を安全に処理できるとは判断できない。確認には保存実装と上位のエラーハンドラーが必要である

## ⑦ 付録

`CreateReservation`は`slot`を持ち、その中に`roomCode`、`startsAt`、`endsAt`が入る。HTTPの`room_code`などからこの形へ変換するのが段階1である。日付を扱う型の内部定義は省略している。
