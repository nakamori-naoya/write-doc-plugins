# 仮押さえ予約の競合を業務エラーへ変換する

> これは [`pr-walkthrough.md`](../templates/pr-walkthrough.md) の記載例である。架空の短い変更ファイルを全文掲載し、差分注釈を示す。PR・コード・テスト名は説明用であり、実在する変更や実行済みのテスト結果ではない。

> 型: 実装解説 ／ 読み手: レビュアーと後任 ／ PR: 架空のPR #128

- **リポジトリ**: `roomflow`
- **取り込み先**: `main` ／ **変更元**: `fix/exclude-overlapping-holds`
- **状態**: レビュー中

既存のDB制約が仮押さえの重複を拒否したとき、予約作成の呼び出し元へ`SLOT_UNAVAILABLE`を返すようにした。以前は同じ競合も例外として上位へ伝わっていた。DB制約と、失敗時に予約・占有の両方を取り消す処理は既存という前提で、今回の変更は一つの関数のエラー変換に限定する。

たとえばM-301の2026年9月18日 10:00から11:30までを二人が同時に申し込んだ場合、DBが拒否した側を競合結果へ変える。未知のDB障害は従来どおり例外として伝える。HTTPのステータス変換はこの関数の外で行う。

## 差分注釈の凡例

掲載したコードの各行がどの区分かを、この表で読む。実行順注釈とは別物なので、この文書に実行順の区分は置かない。

| 表記 | 意味 |
|---|---|
| ［新規］ | 旧実装に無かった行 |
| ［ロジック変更なし］ | 呼ぶメソッド・条件・引数とも旧実装と同一 |
| ［コメントのみ変更］ | コードは同一で、コメントの文言・配置だけが変わった |
| ［削除］ | 旧実装にあって、今は無い |

## 目次

[① 処理の流れ](#①-処理の流れ) ／ [② 何が変わったか](#②-何が変わったか) ／ [③ 実装の全文](#③-実装の全文) ／ [④ テスト設計](#④-テスト設計) ／ [⑤ 気になった点](#⑤-気になった点)

## ① 処理の流れ

1. **仮押さえを要求する** — 顧客と利用枠を受け取る。
2. **データベースへ占有を書き込む** — 既存の保存処理が予約と占有を一緒に記録し、重複ならDB制約が拒否する。
3. **競合を業務結果へ変換する** — 対象の制約違反だけを`SLOT_UNAVAILABLE`にし、別の障害は再送出する。

## ② 何が変わったか

### `create_tentative_hold.ts` — 排他制約違反を業務エラーへ変換した

- **区分**: 置き換え
- **パス**: `src/reservations/create_tentative_hold.ts`

**旧実装**:

```typescript
return repository.createTentativeHold(input);
```

**なぜ変えたか**: この例の変更理由は、同時仮押さえの競合を呼び出し元が通常の業務結果として扱えるようにすることである。`return`に`await`を追加したのは、保存処理の非同期の失敗をこの`catch`で受け取るためである。成功時に呼ぶメソッドと引数は変えない。この変換が守る業務上の決まりは、[業務知識・コアドメイン](domain-rule.example.md)の「常に守られること」1である。

## ③ 実装の全文

この例の対象ファイルは以下の11行が全文である。行番号はファイルの行番号であり、注釈行は含めていない。実在するリポジトリを扱うときは、この行番号を原典の恒久リンクにする。import先の型と既存の保存実装は、この変更の対象外である。

### `src/reservations/create_tentative_hold.ts`

**このファイルの責務**: 仮押さえ予約を作成し、重なる利用枠の競合を予約業務の結果へ変換する。

```typescript
01 import { ExclusionViolation, slotUnavailable } from "./errors";
02 import type { HoldInput, Repository } from "./reservation_repository";
03
04 export async function createTentativeHold(input: HoldInput, repository: Repository) {
05   try {
06     return await repository.createTentativeHold(input);
07   } catch (error) {
08     if (error instanceof ExclusionViolation && error.constraint === "room_booking_claims_room_time_excl") return slotUnavailable();
09     throw error;
10   }
11 }
```

| 行 | 区分 | なぜそうなのか |
|---|---|---|
| 01 | ［新規］ | 変換に使う`ExclusionViolation`と`slotUnavailable`をこの変更で使い始めたため |
| 02 | ［ロジック変更なし］ | 入力型と保存契約の型importは旧実装と同一 |
| 04 | ［ロジック変更なし］ | 公開する関数名・引数・戻り型を維持したため、呼び出し元は変えなくてよい |
| 05, 07, 10 | ［新規］ | 旧実装に`try`/`catch`が無かった。捕捉の枠だけを足している |
| 06 | ［新規］ | 旧実装の`return repository.createTentativeHold(input);`を置き換えた。呼ぶメソッドと引数は同じで、`await`を足して非同期の失敗を`catch`へ渡す |
| — | ［削除］ | 旧実装の`return repository.createTentativeHold(input);`（`await`なし）は無くなった |
| 08, 09 | ［新規］ | 対象の制約違反だけを競合結果へ変え、それ以外は従来どおり再送出する |

エラー型は業務側の契約に置き、永続化実装がDBの失敗をその型へ写す。08行で制約名を限定する条件が、利用枠の競合と別の障害を分ける境界になる。

## ④ テスト設計

| テスト名 | 何を確かめるか | 前提 |
|---|---|---|
| `returns_slot_unavailable_on_room_time_exclusion_violation` | 対象の排他制約違反だけを競合結果へ変える | リポジトリ層が制約名付き`ExclusionViolation`を返す |
| `returns_created_hold` | 成功時の予約ID・状態・期限を変えない | リポジトリ層が仮押さえ予約を返す |
| `rethrows_other_exclusion_violation` | 別の排他制約違反を競合として隠さない | 別の制約名付き`ExclusionViolation`を返す |
| `rethrows_unknown_error` | 未知の障害を隠さない | リポジトリ層が一般エラーを返す |

いずれもテスト設計の例で、実行結果はない。競合ケースでは、同期的なthrowだけでなく保存Promiseのrejectを使い、`await`を外したときにエラー変換の検証が失敗することを確かめる。DBで同時要求を拒否できるかは、この関数の単体テストだけでは検証できない。

## ⑤ 気になった点

### ドライバーから制約名を失わず渡せるか

- **重大度**: 要確認

SQLSTATE `23P01`だけでは、将来追加される別の排他制約まで`SLOT_UNAVAILABLE`へ変換する可能性がある。PostgreSQLドライバーから制約名`room_booking_claims_room_time_excl`を失わず取得できるかは未確認である。取り込み前に、実DBへの重複書込みで制約名がこの関数まで届くことと、拒否した側に予約・占有の片方だけが残らないことを確認する。
