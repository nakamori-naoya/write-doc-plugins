# RoomFlowの夜間請求集計を1日分だけ再実行する

> これは [`runbook.md`](../templates/runbook.md) の記載例である。一次資料の順序を保ち、追加した確認を区別し、各操作の成功・中止・後片付けまで観測可能にする。

## いつ実行するか

毎日02:30の請求集計が失敗し、監視画面で対象日の`billing_daily_summary`が`failed`、かつ自動再試行回数が3回になったときに実行する。`running`または`completed`なら実行しない。

## 事前条件と影響範囲

- 本番バッチ実行権限と、請求DBおよび監視画面の閲覧権限が必要である
- 対象日は`2026-08-31`、ジョブIDは`billing-summary-20260831`とする
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
TARGET_DATE="2026-08-31"
JOB_ID="billing-summary-20260831"
EXPECTED_INVOICE_COUNT="128"
EXPECTED_TOTAL_AMOUNT="1842000"

cd "$APP_DIR"
source deploy/env.sh production
```

期待結果は`production environment loaded`と表示されることである。それ以外なら後続を実行しない。

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

今回は二重実行を見分ける列だけを表示する。

```sql
SELECT job_id, target_date, status, retry_count, updated_at
FROM billing_daily_summary
WHERE target_date = DATE '2026-08-31';
```

期待結果は1行で、`job_id = billing-summary-20260831`、`status = failed`、`retry_count = 3`である。0行、2行以上、`running`、`completed`のいずれかなら実行せず、当番責任者へ結果を共有する。

### 4. 再実行開始時刻を記録する（追加安全確認）

```sh
RETRY_STARTED_AT=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
printf '%s\n' "$RETRY_STARTED_AT"
```

この時刻は、今回の再実行後に作られたログだけを確認するために使う。

### 5. 集計ジョブを再実行する

正本のコマンドは次のとおりである。

```sh
roomflow-cli billing retry --date <対象日>
```

今回の値を指定し、対象件数を表示してから実行する。

```sh
roomflow-cli billing retry \
  --date "$TARGET_DATE" \
  --job-id "$JOB_ID" \
  --confirm
```

確認画面の対象日が`2026-08-31`、対象ジョブが1件の場合だけ承認する。終了状態が不明な場合は同じコマンドを再実行せず、手順6へ進んで状態とログを確認する。

### 6. DBと監視画面で完了を確認する

```sql
SELECT job_id, status, invoice_count, total_amount, completed_at
FROM billing_daily_summary
WHERE job_id = 'billing-summary-20260831';
```

期待結果は1行で、`status = completed`、`completed_at`が手順4の時刻以降、`invoice_count = 128`、`total_amount = 1842000`であることとする。この2つの期待値は再実行前に確定した集計対象一覧から算出した値であり、コマンド実行後に結果へ合わせて変更しない。

続けて監視画面で同じジョブIDを開き、次を確認する。

- 実行結果が`success`
- 開始時刻が手順4の時刻以降
- エラー件数が0

DBと監視画面のどちらか一方でも一致しない場合は、再実行せず「失敗したときの戻し方」へ進む。

### 7. 完了を報告し、環境を片付ける

運用スレッドへ、対象日、ジョブID、DB確認結果、監視画面確認結果を報告する。

> 2026-08-31分の夜間請求集計を再実行しました。DB上の完了、件数・合計金額、監視画面の成功を確認DONEです。

この手順では一時ファイルを作成しない。最後に本番環境を読み込んだshellを閉じる。

```sh
exit
```

## 失敗したときの戻し方

このジョブは再実行前の状態へ手作業で戻さない。次のいずれかなら追加実行を止め、当番責任者へジョブID、開始時刻、DBの結果、コマンドの終了ログを渡す。

- 実行前の状態が`failed`かつ再試行3回ではない
- コマンドの終了状態が不明
- DBが`completed`でも件数または合計金額が一致しない
- DBと監視画面の状態が一致しない

証跡を共有し、ローカルで実行中のコマンドがないことを確認したら、本番環境を読み込んだshellを閉じる。

```sh
exit
```

## 完了の判定

次をすべて満たした時点で完了とする。

- 対象ジョブがDB上で`completed`
- 件数と合計金額が期待値と一致
- 監視画面の実行結果が`success`、エラー件数が0
- 運用スレッドへ確認結果を報告済み
- この手順では一時ファイルを作成していない
- 本番環境を設定したshellを終了済み
