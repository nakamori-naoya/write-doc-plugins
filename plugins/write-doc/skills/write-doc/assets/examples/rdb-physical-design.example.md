# RDB物理設計 — 図書館の貸出

<!-- これは`rdb-physical-design`型の記載例である。**構成の基準資料ではなく、粒度と具体性の見本として読む。**
     架空の題材「図書館の貸出」の論理データモデルを写した。件数と計測値は説明用の仮想値である。 -->

**対象DBMSをPostgreSQL 16.4に固定し、論理設計の9テーブルを変えずに、制約、index、分離レベルと再試行、代表的なReadを決める。** 貸出上限は複数の行にまたがる件数なので、集計列を足さずに`SERIALIZABLE`と再試行で守る。延滞の通知の回収は、利用者から見えないが件数とともに遅くなるReadとして台帳に載せる。

## 対象と論理設計

- 対象DBMS: PostgreSQL
- 対象バージョン: 16.4
- 論理モデル: `rdb-logical-data-modeling.example.md`（2026-10-01）
- 入力にした論理設計: [RDB論理設計の記載例](rdb-logical-data-modeling.example.md)（版: 2026-10-01 確定）
- 論理構造の指紋: sha256:e1ca7c353838906aecd5ba2897ad6a1d08361fdb144a9586bb4f9e445ac49654
- 要求資料: `requirements-discovery.example.md`（説明用の仮想入力）
- 利用・負荷モデル: `workload-model.example.md`（説明用の仮想入力）
- 品質要求資料: `quality-requirements.example.md`（説明用の仮想入力）
- 基盤構成資料: `cloud-architecture.example.md`（説明用の仮想入力）
- 検証証拠: 未実施。この記載例の数値は仮想であり、実案件では実行計画・競合試験の絶対pathへ置き換える
- 確認環境: PostgreSQL 16.4、1 primary（4 vCPU / 16 GiB）、2026-10-02
- 想定規模: 貸出の累計300万件、貸出中と延滞は同時に15万件、基底イベント700万件、通知の要求は月2万件、ピークは開館直後の20貸出/秒

論理設計のER図、列定義、BDD、Before / Afterは再掲しない。

## 物理制約

| 制約名 | 対象 | PostgreSQL 16.4での実現 | 適用時点 | 違反時の扱い |
|---|---|---|---|---|
| 一冊の本の貸出中か延滞の貸出は一つ | `loans` | `book_number`の部分一意index（`status IN ('lent', 'overdue')`） | 行の書込み時 | SQLSTATE `23505`を「貸出中の本を借りる」へ変換する。再試行しない |
| 一人の貸出中と延滞の貸出は5冊まで | `loans` | `SERIALIZABLE`のtransactionで件数を読んでから書く | commit時 | SQLSTATE `40001`なら transaction 全体を最大3回再試行する |
| 現在の版は最後のイベントの版 | `loans`、`loan_base_events` | 条件付きUPDATE（`current_version = 読んだ版`）と、`loan_id, version`の一意制約を同じtransactionで組み合わせる | 状態変更時 | 更新件数0なら読み直さずに競合として返す |
| 成功と失敗はどちらか一つ | `overdue_notice_succeeded_events`、`overdue_notice_failed_events` | 両表の`request_id`主キーと、書く前に他方を確かめる同じtransaction内の存在確認 | 書込み時 | 他方が先にあれば書かずに終える |

## 物理化の方針

### 物理写像: 貸出の現在の姿

- 論理上の意味: 貸出の現在の状態と返却期限を、毎回の貸出と返却で読む
- 物理実装: `loans`を一次データの投影として持ち、業務イベントと同じtransactionで更新する
- 一次データと同期: 基底イベントと詳細イベントが一次データである。`loans`の更新とイベントの追加は同じtransactionで確定し、片方だけをcommitしない
- 再構築・撤去: 基底イベントを`version`順に畳み込んで`loans`を作り直せる。作り直した表と現在の表を比べてから切り替える
- 不変条件の保存: `current_version`は最後の基底イベントの`version`と一致する

| 論理上の判断 | 物理化 | 理由 |
|---|---|---|
| 状態 | `text`。CHECK は置かない | `loans`はドメインモデルだけが書く。状態の値の正しさはドメインモデルが持ち、持ち主を二つにしない |
| 技術処理の表の値 | `overdue_notice_claimed_events.version`は1以上、`overdue_notice_failed_events.reason`は空でない、を CHECK で拒む | 技術処理の表はドメインモデルの外の送り手が書くので、値を検証する別の書き手がいない |
| イベントの時刻 | 基底イベントの`occurred_at`だけ | 一つの出来事に時刻を一本だけ持つ論理設計を保つ |
| 詳細イベントの主キー | 基底イベントの`event_id`を主キー兼外部キーにする | 基底と詳細の一対一を構造で保証する |

## index

### index: `loans_book_active_key`

- 対象: `loans (book_number)` の部分一意index。`status IN ('lent', 'overdue')`の行だけ
- 種類: B-tree部分一意index
- 目的: 一冊の本の貸出中か延滞の貸出を一つに限り、Read-001の本の確認を支える
- 列の順番: 単一列
- 対象Read・更新: 本を借りる、Read-001
- 根拠: 同時15万行のうち一冊の確認は1行を読む
- 更新費用: 貸出で追加、返却で対象外になる
- 検証状態: planned

### index: `loans_user_active_idx`

- 対象: `loans (user_number)` の部分index。`status IN ('lent', 'overdue')`の行だけ。`status`をINCLUDEする
- 種類: B-tree部分index
- 目的: 一人の貸出中と延滞の貸出を数え、延滞の有無を同時に見る
- 列の順番: 単一列
- 対象Read・更新: Read-001
- 根拠: 利用者あたり最大5行を読むIndex Only Scanという仮想結果を置く
- 更新費用: 貸出で追加、延滞でINCLUDE列を更新、返却で対象外になる
- 検証状態: planned

### index: `loans_due_lent_idx`

- 対象: `loans (due_on, loan_id)` の部分index。`status = 'lent'`の行だけ
- 種類: B-tree複合・部分index
- 目的: 延滞にする候補（返却期限を過ぎた貸出中の貸出）を返却期限の順に走査する
- 列の順番: `due_on`の範囲を先に絞り、同じ日の行を`loan_id`で安定して並べる
- 対象Read・更新: Read-002
- 根拠: 貸出中15万行のうち、一日分の候補は平均400行という仮想結果を置く
- 更新費用: 貸出で追加、延滞と返却で対象外になる
- 検証状態: planned

### index: `overdue_notice_open_requests_idx`

- 対象: `overdue_notice_requested_events (requested_at, request_id)`。成功も失敗も無い要求を探す走査に使う
- 種類: B-tree複合index
- 目的: 回収できる要求を古い順に探す
- 列の順番: `requested_at`の順に読み、同じ時刻を`request_id`で安定して並べる
- 対象Read・更新: Read-003、Read-004
- 根拠: 要求は削除しないので累計は増え続ける。成功と失敗の主キーに対するアンチ結合で、未完了の要求だけを読む。未完了が100件以下なら p95 10ms という仮想結果を置く。累計が100万件を超えたら部分indexか派生の予定表へ切り替えを再検討する
- 更新費用: 要求の追加ごとに一エントリ増える
- 検証状態: planned

### index: `overdue_notice_claimed_events_request_version_key`

- 対象: `overdue_notice_claimed_events (request_id, version)`
- 種類: 一意制約が作るB-tree複合index
- 目的: 同じ要求の同じ版の回収を一つに限り、最新の回収を引く
- 列の順番: `request_id`で一つの要求に絞り、`version`の降順で最新を取る
- 対象Read・更新: 回収、Read-003
- 根拠: 一意制約が同じindexを作るので、別のindexを足さない
- 更新費用: 回収ごとに一エントリ増える
- 検証状態: planned

## トランザクションと分離レベル

分離レベルと再試行は、この節が操作ごとに決める。実装はここで決めた指定をtransactionへ渡すだけにする。

### 分離性判断: 貸出上限

- 同時に進む操作: 同じ利用者が二冊を同時に借りる
- 許してはいけない結果: 借りている冊数が4冊のときに、二冊とも成立して6冊になる
- 発生し得る現象: 書き込みスキュー。どちらも4冊を数えてから書く
- 選択する分離レベル: SERIALIZABLE
- 併用する仕組み: `loans_user_active_idx`で件数を読み、同じtransactionで貸出を追加する
- 対象バージョンでの確認: 二つのsessionで同じ利用者の4冊の状態から同時に借り、一方がSQLSTATE `40001`で中断することを確かめる
- 競合時の扱い: SQLSTATE `40001`だけを、transaction全体で最大3回、10〜50msのjitterを置いて再試行する。再試行で5冊を数えたら「貸出上限に達している利用者が本を借りる」を返す
- 検証状態: planned

集計列（利用者ごとの借りている冊数）を足せば一行の問題にできるが、一次データが二つになり、返却のたびに二か所を直すことになる。件数は最大5行なので、数えるほうを選んだ。

### 分離性判断: 同じ本を二人が借りる

- 同時に進む操作: 同じ本を二人の利用者が同時に借りる
- 許してはいけない結果: 一冊の本に貸出中の貸出が二つできる
- 発生し得る現象: 事前の確認だけでは二つとも「まだ無い」と読む
- 選択する分離レベル: SERIALIZABLE（貸出上限と同じtransactionのため）
- 併用する仕組み: `loans_book_active_key`の部分一意index
- 対象バージョンでの確認: 二つのsessionで同じ本を借り、後発がSQLSTATE `23505`で中断することを確かめる
- 競合時の扱い: `23505`は再試行せず「貸出中の本を借りる」を返す
- 検証状態: planned

### 分離性判断: 延滞にするのと返却が重なる

- 同時に進む操作: 同じ貸出を延滞にする処理と、本を返す処理
- 許してはいけない結果: 返却済みの貸出が延滞になる。同じ版から二つの出来事が成立する
- 発生し得る現象: ロストアップデート
- 選択する分離レベル: READ COMMITTED
- 併用する仕組み: 読んだ`current_version`を条件にしたUPDATEと、`loan_id, version`の一意制約
- 対象バージョンでの確認: 二つのsessionで版1の貸出を同時に進め、後発の更新件数が0になることを確かめる
- 競合時の扱い: 再試行しない。延滞にする側は、その貸出を次の走査に任せる
- 検証状態: planned

### 分離性判断: 通知の要求の回収

- 同時に進む操作: 二つの送り手が同じ要求を回収する
- 許してはいけない結果: 同じ要求の同じ版の回収が二つ成立する
- 発生し得る現象: 二つとも未回収と読んで回収を書く
- 選択する分離レベル: READ COMMITTED
- 併用する仕組み: `request_id, version`の一意制約。候補の走査は`FOR UPDATE SKIP LOCKED`で他の送り手が掴んだ要求を飛ばす
- 対象バージョンでの確認: 二つのsessionで同時に回収し、一方だけが回収を書き、他方は別の要求を取ることを確かめる
- 競合時の扱い: `23505`は再試行せず、次の候補へ進む。外部への送信は回収のtransactionをcommitしてから行う
- 検証状態: planned

## パーティションと配置

初期は9テーブルとも非partitionとする。基底イベントが3,000万件を超えたら、`occurred_at`による年次partitionを再検討する。通知の要求は削除しないので、累計100万件で走査の方法を見直す（index: `overdue_notice_open_requests_idx`）。

## 容量・性能・運用

| 観点 | 前提・観測値 | 設計判断 | 確認方法・閾値 |
|---|---|---|---|
| データ量 | 貸出300万件、基底イベント700万件 | 非partition | 基底イベント3,000万件で再評価 |
| 貸出の書込み | ピーク20件/秒 | 貸出を`SERIALIZABLE`の一transactionに閉じる | p95 50ms、`40001`の再試行率1%未満 |
| 通知の滞留 | 月2万件 | 未完了の要求だけを読む | Read-004で未完了が1,000件を超えたら警告 |

## 採用するRDB機能

### 機能: 部分一意index

- 採用箇所: `loans_book_active_key`
- 採用理由: 返却済みの行を残したまま、貸出中と延滞の行だけを一冊一つに限れる
- 利用可能な版: 対象版で利用できる
- 根拠: https://www.postgresql.org/docs/16/indexes-partial.html
- 検証状態: planned

### 機能: SERIALIZABLEの直列化失敗の検出

- 採用箇所: 貸出上限
- 採用理由: 件数を根拠にした判断を、集計列を足さずに守れる
- 利用可能な版: 対象版で利用できる
- 根拠: https://www.postgresql.org/docs/16/transaction-iso.html#XACT-SERIALIZABLE
- 検証状態: planned

### 機能: FOR UPDATE SKIP LOCKED

- 採用箇所: 通知の要求の回収
- 採用理由: 複数の送り手が同じ要求を待たずに、別の要求を取れる
- 利用可能な版: 対象版で利用できる
- 根拠: https://www.postgresql.org/docs/16/sql-select.html#SQL-FOR-UPDATE-SHARE
- 検証状態: planned

## 物理設計の完了条件

### 検証: 競合時の業務結果

- 対象: 貸出上限、同じ本、延滞と返却、通知の回収
- 状態: planned
- 方法: PostgreSQL 16.4の二sessionで各transactionを交差実行する
- 合格条件: 論理設計が許さない結果が起きず、後発へ決めた業務結果か再試行を返す
- 見直し条件: DBMS版、分離レベル、制約、再試行の方針の変更
- 根拠: この記載例は仮想条件であり、実機証拠は未作成

### 検証: 代表Readの性能

- 対象: Read-001からRead-004と、それを支えるindex
- 状態: planned
- 方法: 想定件数と分布を再現し、`EXPLAIN (ANALYZE, BUFFERS)`と反復計測を行う
- 合格条件: 各ReadのSLOを満たす
- 見直し条件: 件数、分布、通知の滞留の変化
- 根拠: この記載例の計測値は説明用の仮想結果

## 未決

- 通知のリース10分と回収の上限5回は、論理設計の仮説を写した。送り先の応答時間が分かれば確定する
- 貸出上限の再試行の上限3回は、ピークの競合率を実測してから確定する

## 代表的な読み取り

Readには、利用者の問い合わせだけでなく、背景処理の走査、監視の集計、書込みの中の判定条件も載せる。どれも件数とともに遅くなるからである。

### Read-001: 本を借りる前に、利用者の貸出状況と本の貸出を読む

- 利用者と目的: 本を借りる処理が、貸出上限と延滞の有無、本がほかに貸出中でないかを判断する（書込みの中の判定条件）
- 入力・検索条件: `user_number`の等価条件と`status IN ('lent', 'overdue')`、`book_number`の等価条件
- 結合: なし
- 並び順と上限: なし。利用者は最大5行、本は最大1行
- 返す情報: 借りている冊数、延滞の貸出があるか、本の貸出の有無
- 鮮度と一貫性: 貸出を書くのと同じ`SERIALIZABLE`のtransactionで読む
- 想定件数: 同時15万行のうち、利用者あたり最大5行
- SLO: p95 5ms
- 支えるindex: `loans_user_active_idx`、`loans_book_active_key`

### Read-002: 延滞にする候補を返却期限の順に走査する

- 利用者と目的: 延滞にする処理（背景処理）が、判定日に返却期限を過ぎた貸出中の貸出を探す
- 入力・検索条件: `status = 'lent'`、`due_on < 判定日`
- 結合: なし
- 並び順と上限: `due_on, loan_id`の昇順、100件ずつ
- 返す情報: 貸出、読んだ版
- 鮮度と一貫性: primaryから読む。延滞にするUPDATEが版で確かめるので、読んだ後の変化は許す
- 想定件数: 貸出中15万行のうち、一日分の候補は平均400行
- SLO: 100件の取得で p95 20ms
- 支えるindex: `loans_due_lent_idx`

### Read-003: 回収できる通知の要求を探す

- 利用者と目的: 延滞の通知の送り手（背景処理）が、成功も失敗も無く、生きている回収も無い要求を古い順に探す
- 入力・検索条件: 成功と失敗の表に無い要求、最新の回収が無いか`claimed_at`からリースの10分を過ぎたもの
- 結合: 成功と失敗の表とのアンチ結合、回収の表の最新版との結合
- 並び順と上限: `requested_at, request_id`の昇順、20件
- 返す情報: 要求、知らせる相手、次の回収の版
- 鮮度と一貫性: primaryから`FOR UPDATE SKIP LOCKED`で読む
- 想定件数: 要求の累計は月2万件ずつ増える。未完了は通常100件以下
- SLO: 20件の取得で p95 10ms
- 支えるindex: `overdue_notice_open_requests_idx`、`overdue_notice_claimed_events_request_version_key`

### Read-004: 通知の滞留と打ち切りを数える

- 利用者と目的: 運用担当者（監視）が、未完了の要求の件数と、この24時間に打ち切った件数を見る
- 入力・検索条件: 成功と失敗の表に無い要求、`failed_at`が直近24時間
- 結合: 成功と失敗の表とのアンチ結合
- 並び順と上限: なし（件数だけ）
- 返す情報: 未完了の件数、最も古い未完了の`requested_at`、打ち切った件数
- 鮮度と一貫性: 1分遅れてよい
- 想定件数: 未完了は通常100件以下、打ち切りは一日数件
- SLO: p95 50ms、1分ごと
- 支えるindex: `overdue_notice_open_requests_idx`
