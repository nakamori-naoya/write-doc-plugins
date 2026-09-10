# RoomFlowの夜間請求集計を1日分だけ再実行する

> これは`runbook`型の記載例である。**構成の正本ではなく、粒度と具体性の見本として読む。**RoomFlowの運用環境、CLI、SQL、監視画面はすべて架空であり、**このまま実行しても動かない**。一次資料の順序を保ち、追加した確認を区別し、各操作の成功・中止・後片付けまで観測可能にする書き方の例として使う。

夜間の当番運用者が、失敗した1日分の請求集計を再実行し、完了を確認するまでの定型作業である。**この手順では、再実行してよいかどうかを判断しない。** 開始条件に一つでも合わない場合は実行せず、当番責任者へ引き渡す。集計ロジックの修正、複数日のまとめ直し、請求データの手作業修正は扱わない。

## いつ実行するか

毎日02:30の請求集計が失敗し、監視画面で対象日の`billing_daily_summary`が`failed`、かつ自動再試行回数が3回になったときに実行する。`running`または`completed`なら実行しない。

## 事前条件と影響範囲

- 本番バッチ実行権限と、請求DBおよび監視画面の閲覧権限が必要である
- `roomflow-cli` 4.2以降と`psql` 16以降を実行できること。版は`roomflow-cli --version`で確認する
- 対象日とジョブIDは実行時に決める。この記載例では対象日`2026-08-31`、ジョブID`billing-summary-20260831`を通し番号として使う
- DBの接続先（`DB_INSTANCE`、`DB_NAME`、`PGHOST`、`PGUSER`）は手順1の`deploy/env.sh`が設定する。手作業で書き換えない
- 時刻はDB・CLI・監視画面のいずれもUTCで記録される。日本時間へ読み替えない
- 再実行は請求明細を新規作成せず、対象日の未完了集計だけを更新する
- 同じジョブIDの処理が実行中なら、二重集計を防ぐため停止する
- SQLは状態確認だけに使い、手作業で請求データを更新しない

## 手順

運用の正本には、次の順で実行すると書かれている。

> 「対象環境を設定する」「対象日の状態を確認する」「集計ジョブを再実行する」「監視画面で完了を確認する」
>
> 出典: RoomFlow運用標準「夜間請求集計の再実行」（架空の資料、2026-08-20版。実在する参照先なし）

以下はこの順序を保った実行手順である。正本にない確認には「追加安全確認」と明記する。

### 1. 本番環境を設定する

正本の記載例は次のとおりである。

```sh
source deploy/env.sh production
```

今回は作業directoryを固定して実行する。

```sh
APP_DIR="/srv/roomflow"
TARGET_DATE="2026-08-31"          # 今回の対象日へ置き換える
JOB_ID="billing-summary-${TARGET_DATE//-/}"

cd "$APP_DIR"
source deploy/env.sh production
```

期待結果は`production environment loaded`と表示され、`DB_INSTANCE`・`DB_NAME`・`PGHOST`・`PGUSER`が設定されることである。それ以外なら後続を実行しない。

### 2. 接続先を確認する（追加安全確認）

この確認は正本にはない。別環境でジョブを動かす事故を防ぐために追加する。

```sh
printf '%s/%s\n' "$DB_INSTANCE" "$DB_NAME"
if env | grep -qi EMULATOR; then
  printf '%s\n' 'STOP: emulator variable is set'
else
  printf '%s\n' 'OK: emulator variable is unset'
fi
```

期待結果は`roomflow-prod/billing`と`OK: emulator variable is unset`である。`STOP`が表示された場合や接続先が異なる場合は後続を実行しない。

### 3. 対象日の状態を確認する

正本には次の確認SQLが掲載されている。

```sql
SELECT * FROM billing_daily_summary WHERE target_date = :target_date;
```

今回は二重実行を見分ける列だけを、読み取り専用の接続で表示する。

```sh
psql "$DB_NAME" --set=ON_ERROR_STOP=1 --set=target_date="$TARGET_DATE" -c "
SET default_transaction_read_only = on;
SELECT job_id, target_date, status, retry_count, updated_at
FROM billing_daily_summary
WHERE target_date = DATE :'target_date';"
```

期待結果は1行で、`job_id`が`$JOB_ID`と一致し、`status = failed`、`retry_count = 3`である。0行、2行以上、`running`、`completed`のいずれかなら実行せず、当番責任者へ結果を共有する。

### 4. 再実行開始時刻を記録する（追加安全確認）

```sh
RETRY_STARTED_AT=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
printf '%s\n' "$RETRY_STARTED_AT"
```

この時刻は、今回の再実行後に作られたログだけを確認するために使う。DBとCLIの記録もUTCなので、そのまま比較できる。

### 5. 期待する件数と合計金額を先に確定する（追加安全確認）

この確認は正本にはない。実行後の結果に期待値を合わせてしまう事故を防ぐために追加する。**再実行より前に、集計対象の明細から期待値を算出して控える。**

```sh
psql "$DB_NAME" --set=ON_ERROR_STOP=1 --set=target_date="$TARGET_DATE" -t -A -F' ' -c "
SET default_transaction_read_only = on;
SELECT count(*), coalesce(sum(amount), 0)
FROM billing_invoice
WHERE target_date = DATE :'target_date' AND voided_at IS NULL;"
```

出力の1つ目を`EXPECTED_INVOICE_COUNT`、2つ目を`EXPECTED_TOTAL_AMOUNT`として控える。この記載例では`128`と`1842000`が返ったものとして以降を書く。

```sh
EXPECTED_INVOICE_COUNT="128"
EXPECTED_TOTAL_AMOUNT="1842000"
```

0件が返った場合は、対象日に請求対象が無いということなので再実行せず、当番責任者へ共有する。

### 6. 集計ジョブを再実行する

正本のコマンドは次のとおりである。

```sh
roomflow-cli billing retry --date <対象日>
```

今回の値を指定し、まず`--dry-run`で対象を表示する。`--dry-run`は集計を実行せず、対象日・対象ジョブ・対象件数だけを出力する。

```sh
roomflow-cli billing retry \
  --date "$TARGET_DATE" \
  --job-id "$JOB_ID" \
  --dry-run
```

出力の対象日が`$TARGET_DATE`、対象ジョブが1件、対象件数が`$EXPECTED_INVOICE_COUNT`と一致する場合だけ次へ進む。一致しないなら実行せず、当番責任者へ共有する。

```sh
roomflow-cli billing retry \
  --date "$TARGET_DATE" \
  --job-id "$JOB_ID"
```

`--confirm`は付けない。**`--confirm`は対話の確認画面を省略して即実行するflagであり、この手順では使わない。** flagを付けずに実行すると、対象日・対象ジョブ・対象件数を表示した確認画面が出るので、`--dry-run`の出力と同じであることを見てから承認する。

終了状態が不明な場合は同じコマンドを再実行しない。次のコマンドでジョブの状態と、手順4で控えた時刻以降のログだけを確認する。

```sh
roomflow-cli billing status --job-id "$JOB_ID"
roomflow-cli billing logs --job-id "$JOB_ID" --since "$RETRY_STARTED_AT"
```

状態が`running`なら完了まで待つ。`failed`または状態を取得できないなら「失敗したときの戻し方」へ進む。

### 7. DBと監視画面で完了を確認する

```sh
psql "$DB_NAME" --set=ON_ERROR_STOP=1 --set=job_id="$JOB_ID" -c "
SET default_transaction_read_only = on;
SELECT job_id, status, invoice_count, total_amount, completed_at
FROM billing_daily_summary
WHERE job_id = :'job_id';"
```

期待結果は1行で、`status = completed`、`completed_at`が手順4で控えた`$RETRY_STARTED_AT`以降、`invoice_count`が`$EXPECTED_INVOICE_COUNT`、`total_amount`が`$EXPECTED_TOTAL_AMOUNT`と一致することである。この2つの期待値は手順5で再実行前に算出した値であり、コマンド実行後に結果へ合わせて変更しない。

続けて監視画面で同じジョブIDを開き、次を確認する。

- 実行結果が`success`
- 開始時刻が手順4の時刻以降
- エラー件数が0

DBと監視画面のどちらか一方でも一致しない場合は、再実行せず「失敗したときの戻し方」へ進む。

### 8. 完了を報告し、環境を片付ける

運用スレッドへ、対象日、ジョブID、DB確認結果、監視画面確認結果を報告する。

> 2026-08-31分の夜間請求集計を再実行しました（ジョブID: billing-summary-20260831）。DB上の`completed`、件数128件・合計1,842,000、監視画面の`success`とエラー0件を確認しました。

この手順では一時ファイルを作成しない。最後に本番環境を読み込んだshellを閉じる。

```sh
exit
```

## 失敗したときの戻し方

このジョブは再実行前の状態へ手作業で戻さない。次のいずれかなら追加実行を止め、当番責任者へジョブID、開始時刻、DBの結果、コマンドの終了ログを渡す。

- 実行前の状態が`failed`かつ再試行3回ではない
- 手順5で対象件数が0件だった、または`--dry-run`の対象件数と一致しない
- コマンドの終了状態が不明で、`billing status`でも状態を取得できない
- DBが`completed`でも件数または合計金額が手順5の期待値と一致しない
- DBと監視画面の状態が一致しない

渡す証跡は、ジョブID、`$RETRY_STARTED_AT`、手順3・5・7で実行したSQLの出力、`roomflow-cli billing logs --job-id "$JOB_ID" --since "$RETRY_STARTED_AT"`の出力である。共有し、ローカルで実行中のコマンドがないことを確認したら、本番環境を読み込んだshellを閉じる。

```sh
exit
```

## 完了の判定

次をすべて満たした時点で完了とする。

- 対象ジョブがDB上で`completed`
- 件数と合計金額が、手順5で再実行前に確定した期待値と一致
- 監視画面の実行結果が`success`、エラー件数が0
- 運用スレッドへ確認結果を報告済み
- この手順では一時ファイルを作成していない
- 本番環境を設定したshellを終了済み
