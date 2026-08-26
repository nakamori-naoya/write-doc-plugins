# 仮押さえ予約の重複を排他制約で防ぐ

> これは [`pr-walkthrough.md`](../templates/pr-walkthrough.md) の記載例である。架空の短い変更ファイルを全文掲載し、差分注釈を示す。

> 型: 実装解説 ／ 読み手: レビュアーと後任 ／ PR: 架空のPR #128

- **リポジトリ**: `roomflow`
- **base**: `main` ／ **head**: `fix/exclude-overlapping-holds`
- **状態**: レビュー中

同じ会議室の重なる利用枠へ、仮押さえ予約が複数成立しない排他制約を追加した。競合時は内部エラーではなく`SLOT_UNAVAILABLE`を返す。

## 目次

① 処理の流れ ／ ② 何が変わったか ／ ③ 実装の全文 ／ ④ テスト設計 ／ ⑤ 気になった点

## ① 処理の流れ

1. **仮押さえを要求する** — 顧客と利用枠を受け取る。
2. **DBへ占有を書き込む** — GiST排他制約が重なる利用枠を拒否する。
3. **競合を業務結果へ変換する** — 制約違反を`SLOT_UNAVAILABLE`にする。

## ② 何が変わったか

### `create_tentative_hold.ts` — 排他制約違反を業務エラーへ変換した

- **区分**: 置き換え
- **パス**: `src/reservations/create_tentative_hold.ts`

**旧実装**:

```typescript
return repository.createTentativeHold(input);
```

**なぜ変えたか**: 同時仮押さえで発生する排他制約違反を、予約担当者が対処できる競合結果へ変えるため。

## ③ 実装の全文

**省略しない。** この例の対象ファイルは以下の13行が全文である。

### 注釈の凡例

| 表記 | 意味 |
|---|---|
| ［新規］ | 旧実装に無かった行 |
| ［ロジック変更なし］ | 呼ぶメソッド・条件・引数とも旧実装と同一 |
| ［コメントのみ変更］ | コードは同一で、コメントの文言・配置だけが変わった |

### `src/reservations/create_tentative_hold.ts`

**このファイルの責務**: 仮押さえ予約を作成し、重なる利用枠の競合を予約業務の結果へ変換する。

```typescript
01 import { ExclusionViolation } from "../persistence/errors";
02 import { slotUnavailable } from "./errors";
03
04 export async function createTentativeHold(input: HoldInput, repository: Repository) {
05   try {
06     // ［ロジック変更なし］仮押さえ予約と占有を同じtransactionへ書く。
07     return await repository.createTentativeHold(input);
08   } catch (error) {
09     // ［新規］DB制約が検出した競合だけを業務エラーへ変換する。
10     if (error instanceof ExclusionViolation && error.constraint === "room_booking_claims_room_time_excl") return slotUnavailable();
11     throw error;
12   }
13 }
```

## ④ テスト設計

| テスト名 | 何を確かめるか | 前提 |
|---|---|---|
| `returns_slot_unavailable_on_room_time_exclusion_violation` | 対象の排他制約違反だけを競合結果へ変える | repositoryが制約名付き`ExclusionViolation`を返す |
| `rethrows_unknown_error` | 未知の障害を隠さない | repositoryが一般エラーを返す |

## ⑤ 気になった点

### driverから制約名を失わず渡せるか

- **重大度**: 要確認

SQLSTATE `23P01`だけでは、将来追加される別の排他制約まで`SLOT_UNAVAILABLE`へ変換する可能性がある。PostgreSQL driverから制約名`room_booking_claims_room_time_excl`を失わず取得できるかは未確認である。
