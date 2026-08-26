# RoomFlow APIを直前の版へ切り戻す

> これは [`runbook.md`](../templates/runbook.md) の記載例である。判断を作業者へ残さず、開始条件と分岐を固定する。

## いつ実行するか

リリース後15分以内に予約作成のHTTP 5xx率が5分平均で2%を超え、`RoomFlowReservationErrorRateHigh`アラートが発火したときに実行する。

## 事前条件と影響範囲

- 本番デプロイ権限と監視閲覧権限が必要である
- 対象は`roomflow-api`だけで、DB migrationを含むリリースでは実行しない
- 切戻し中の新規予約は最大2分失敗する可能性がある

## 手順

1. `deployctl roomflow-api current`を実行する。
   - 期待結果: 現在版と直前版が1件ずつ表示される。
2. `deployctl roomflow-api rollback --to 2.2.4`を実行する。
   - 期待結果: `rollout started`と表示される。
3. `deployctl roomflow-api status --wait`を実行する。
   - 期待結果: 5分以内に全instanceが`healthy`になる。5分を超えたら戻し方へ進む。
4. 予約作成のHTTP 5xx率を5分間確認する。
   - 期待結果: 5分平均が0.5%未満になる。

## 失敗したときの戻し方

rollback後のinstanceが5分以内に`healthy`にならなければ、`deployctl roomflow-api rollout cancel`を実行する。`RoomFlow API停止`手順へ切り替え、インシデント責任者へ現在版、直前版、失敗したcommand全文を渡す。

## 完了の判定

直前版の全instanceが`healthy`で、予約作成のHTTP 5xx率が5分平均0.5%未満になり、アラートが解消した時点で完了とする。
