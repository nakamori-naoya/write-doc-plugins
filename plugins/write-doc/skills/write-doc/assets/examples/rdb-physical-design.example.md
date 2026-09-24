# RDB物理設計 — 図書館の貸出

<!-- これは`rdb-physical-design`型の記載例である。**構成の基準資料ではなく、粒度と具体性の見本として読む。**
     架空の題材「図書館の貸出」の論理データモデルを写した。件数と計測値は説明用の仮想値である。 -->

**対象DBMSをPostgreSQL 16.4に固定し、論理設計の9テーブルを変えずに、導いた値の保存、制約、index、分離レベルとやり直し、代表的なReadを決める。** 論理設計はいまの貸出の状態を持たないが、毎回の貸出で「一冊一つ」と「一人5冊まで」を確かめるために、物理設計で貸出のいまの状態を導いて保存する。延滞の通知の回収は、利用者から見えないが件数とともに遅くなるReadとして台帳に載せる。

## 対象と論理設計

- 対象DBMS: PostgreSQL
- 対象バージョン: 16.4
- 論理モデル: `rdb-logical-data-modeling.example.md`（2026-10-01）
- 入力にした論理設計: [RDB論理設計の記載例](rdb-logical-data-modeling.example.md)（版: 2026-10-01 確定）
- 論理構造の指紋: sha256:bb48c8747e7969f3b0d2944b997e76a1c8aa2fb2d5a20bbef8ee8571de335880
- 要求資料: `requirements-discovery.example.md`（説明用の仮想入力）
- 利用・負荷モデル: `workload-model.example.md`（説明用の仮想入力）
- 品質要求資料: `quality-requirements.example.md`（説明用の仮想入力）
- 基盤構成資料: `cloud-architecture.example.md`（説明用の仮想入力）
- 検証証拠: 未実施。この記載例の数値は仮想であり、実案件では実行計画・競合試験の絶対pathへ置き換える
- 確認環境: PostgreSQL 16.4、1 primary（4 vCPU / 16 GiB）、2026-10-02
- 想定規模: 貸出の累計300万件、貸出中と延滞は同時に15万件、基底イベント700万件、通知の要求は月2万件、ピークは開館直後の20貸出/秒

論理設計のER図、BDD、Before / Afterは再掲しない。

## 物理制約

| 制約名 | 対象 | PostgreSQL 16.4での実現 | 適用時点 | 違反時の扱い |
|---|---|---|---|---|
| 一冊の本の貸出中か延滞の貸出は一つ | `loan_current_states` | `book_number`の部分一意index（`status IN ('lent', 'overdue')`） | 行の書込み時 | SQLSTATE `23505`を「貸出中の本を借りる」へ変換する。やり直さない |
| 一人の貸出中と延滞の貸出は5冊まで | `loan_current_states` | `SERIALIZABLE`のtransactionで件数を読んでから書く | commit時 | SQLSTATE `40001`なら transaction の中で最大3回やり直す |
| 貸出の中の版は一つずつ増える | `loan_base_events` | `loan_id, version`の一意制約。追加する版は読んだ最後の版の次にする | 行の書込み時 | `23505`なら競合として返す。やり直さない |
| 成功と失敗はどちらか一つ | `overdue_notice_succeeded_events`、`overdue_notice_failed_events` | 両表の`request_id`主キーと、書く前に他方が無いことを同じtransactionで確かめる | 書込み時 | 他方が先にあれば書かずに終える |

値の範囲の CHECK は、ドメインモデルだけが書く業務の表（`loans`、基底イベント、詳細イベント、`loan_current_states`）には置かない。値の正しさの持ち主はドメインモデルで、持ち主を二つにしないためである。技術処理の表はドメインモデルの外の送り手が書くので、`overdue_notice_claimed_events.version`が1以上であることと、`overdue_notice_failed_events.reason`が空でないことを CHECK で拒む。

## 物理化の方針

### 物理写像: 貸出のいまの状態

- 論理上の意味: 貸出のいまの状態は、最後の基底イベントの種類から導ける情報であり、論理設計は持たない
- 物理実装: 派生の表`loan_current_states`（`loan_id`、`user_number`、`book_number`、`status`、`last_version`、`due_on`）を置く。導いた値を保存する理由は、毎回の貸出で「一冊一つ」を部分一意indexで、「一人5冊まで」を件数で確かめ、延滞にする候補を返却期限で走査するためである。基底イベントを毎回畳み込むと、これらを索引で支えられない
- 一次データと同期: 一次データは基底イベントと詳細イベントである。基底イベントを追加するのと同じtransactionで`loan_current_states`を更新し、片方だけをcommitしない
- 再構築・撤去: 基底イベントを`version`順に畳み込んで作り直せる。毎日一度、作り直した結果と比べ、食い違いがあれば運用へ知らせる。要らなくなれば表を消すだけで、事実は失われない
- 不変条件の保存: `last_version`は、その貸出の基底イベントの最大の`version`と等しい

## index

### index: `loan_current_states_book_active_key`

- 対象: `loan_current_states (book_number)` の部分一意index。`status IN ('lent', 'overdue')`の行だけ
- 種類: B-tree部分一意index
- 目的: 一冊の本の貸出中か延滞の貸出を一つに限り、Read-001の本の確認を支える
- 列の順番: 単一列
- 対象Read・更新: 本を借りる、Read-001
- 根拠: 同時15万行のうち一冊の確認は1行を読む
- 更新費用: 貸出で追加、返却で対象外になる
- 検証状態: planned

### index: `loan_current_states_user_active_idx`

- 対象: `loan_current_states (user_number)` の部分index。`status IN ('lent', 'overdue')`の行だけ。`status`をINCLUDEする
- 種類: B-tree部分index
- 目的: 一人の貸出中と延滞の貸出を数え、延滞の有無を同時に見る
- 列の順番: 単一列
- 対象Read・更新: Read-001
- 根拠: 利用者あたり最大5行を読むIndex Only Scanという仮想結果を置く
- 更新費用: 貸出で追加、延滞でINCLUDE列を更新、返却で対象外になる
- 検証状態: planned

### index: `loan_current_states_due_lent_idx`

- 対象: `loan_current_states (due_on, loan_id)` の部分index。`status = 'lent'`の行だけ
- 種類: B-tree複合・部分index
- 目的: 延滞にする候補（返却期限を過ぎた貸出中の貸出）を返却期限の順に走査する
- 列の順番: `due_on`の範囲を先に絞り、同じ日の行を`loan_id`で安定して並べる
- 対象Read・更新: Read-002
- 根拠: 貸出中15万行のうち、一日分の候補は平均400行という仮想結果を置く
- 更新費用: 貸出で追加、延滞と返却で対象外になる
- 検証状態: planned

### index: `overdue_notice_requested_events_occurred_idx`

- 対象: `overdue_notice_requested_events (occurred_at, request_id)`
- 種類: B-tree複合index
- 目的: 回収できる要求を古い順に探す
- 列の順番: `occurred_at`の順に読み、同じ時点を`request_id`で安定して並べる
- 対象Read・更新: Read-003、Read-004
- 根拠: 要求は削除しないので累計は増え続ける。成功と失敗の主キーに対するアンチ結合で、未完了の要求だけを読む。未完了が100件以下なら p95 10ms という仮想結果を置く。累計が100万件を超えたら、未完了の要求だけの派生の表を再検討する
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

分離レベルと、transaction の中でのやり直しの回数は、この節が操作ごとに決める。実装はここで決めた指定をtransactionへ渡すだけにする。

### 分離性判断: 貸出上限

同じ利用者が二冊を同時に借りると、どちらも4冊と数えてから書き、6冊になりうる（書き込みスキュー）。`SERIALIZABLE`で守り、直列化の失敗（SQLSTATE `40001`）だけを transaction の中で最大3回、10〜50msの揺らぎを置いてやり直す。やり直しで5冊と数えたら「貸出上限に達している利用者が本を借りる」を返す。二つのsessionで4冊の状態から同時に借り、一方が`40001`で中断することを確かめる。

集計列（利用者ごとの借りている冊数）を足せば一行の問題にできるが、導いた値が二つになり、返却のたびに二か所を直すことになる。件数は最大5行なので、数えるほうを選んだ。

検証状態: planned

### 分離性判断: 同じ本を二人が借りる

同じ本を二人が同時に借りると、どちらも「まだ貸出中でない」と読んで書きうる。貸出上限と同じ`SERIALIZABLE`のtransactionの中で、`loan_current_states_book_active_key`の部分一意indexが後の一方を`23505`で拒む。やり直さず「貸出中の本を借りる」を返す。二つのsessionで同じ本を借り、後の一方が`23505`で中断することを確かめる。

検証状態: planned

### 分離性判断: 延滞にするのと返却が重なる

同じ貸出を延滞にする処理と本を返す処理が、どちらも版1を読んで版2を書こうとする（ロストアップデート）。`READ COMMITTED`で、`loan_id, version`の一意制約が後の一方を`23505`で拒む。やり直さない。延滞にする側は、その貸出を次の走査に任せる。二つのsessionで版1の貸出を同時に進め、後の一方が`23505`になることを確かめる。

検証状態: planned

### 分離性判断: 通知の要求の回収

二つの送り手が同じ要求を回収しようとすると、どちらも未回収と読んで回収を書きうる。`READ COMMITTED`で、`request_id, version`の一意制約が後の一方を`23505`で拒み、その送り手は次の候補へ進む。追加のみの型にそのまま合うので一意制約を既定にした。回収の待ち行列が長く衝突が多すぎる場合に限り、候補の走査に`FOR UPDATE SKIP LOCKED`を足して他の送り手が見ている要求を飛ばす。外部への送信は、回収のtransactionをcommitしてから行う。

検証状態: planned

## パーティションと配置

初期は論理設計の9テーブルと派生の表とも非partitionとする。基底イベントが3,000万件を超えたら、`occurred_at`による年次partitionを再検討する。通知の要求は削除しないので、累計100万件で走査の方法を見直す（index: `overdue_notice_requested_events_occurred_idx`）。

## 容量・性能・運用

| 観点 | 前提・観測値 | 設計判断 | 確認方法・閾値 |
|---|---|---|---|
| データ量 | 貸出300万件、基底イベント700万件 | 非partition | 基底イベント3,000万件で再評価 |
| 貸出の書込み | ピーク20件/秒 | 貸出を`SERIALIZABLE`の一transactionに閉じる | p95 50ms、`40001`のやり直し率1%未満 |
| 派生の表の整合 | 毎日一度作り直して比べる | 食い違いは運用へ知らせる | 食い違いが1件でもあれば調査 |
| 通知の滞留 | 月2万件 | 未完了の要求だけを読む | Read-004で未完了が1,000件を超えたら警告 |

## 採用するRDB機能

### 機能: 部分一意index

- 採用箇所: `loan_current_states_book_active_key`
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

## 物理設計の完了条件

### 検証: 競合時の業務結果

- 対象: 貸出上限、同じ本、延滞と返却、通知の回収
- 状態: planned
- 方法: PostgreSQL 16.4の二sessionで各transactionを交差実行する
- 合格条件: 論理設計が許さない結果が起きず、後の一方へ決めた業務結果かやり直しを返す
- 見直し条件: DBMS版、分離レベル、制約、やり直しの方針の変更
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
- 貸出上限のやり直しの上限3回は、ピークの競合率を実測してから確定する

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
- 支えるindex: `loan_current_states_user_active_idx`、`loan_current_states_book_active_key`

### Read-002: 延滞にする候補を返却期限の順に走査する

- 利用者と目的: 延滞にする処理（背景処理）が、判定日に返却期限を過ぎた貸出中の貸出を探す
- 入力・検索条件: `status = 'lent'`、`due_on < 判定日`
- 結合: なし
- 並び順と上限: `due_on, loan_id`の昇順、100件ずつ
- 返す情報: 貸出、読んだ版
- 鮮度と一貫性: primaryから読む。延滞にする書込みが版の一意で確かめるので、読んだ後の変化は許す
- 想定件数: 貸出中15万行のうち、一日分の候補は平均400行
- SLO: 100件の取得で p95 20ms
- 支えるindex: `loan_current_states_due_lent_idx`

### Read-003: 回収できる通知の要求を探す

- 利用者と目的: 延滞の通知の送り手（背景処理）が、成功も失敗も無く、生きている回収も無い要求を古い順に探す
- 入力・検索条件: 成功と失敗の表に無い要求、最新の回収が無いか、その`occurred_at`からリースの10分を過ぎたもの
- 結合: 成功と失敗の表とのアンチ結合、回収の表の最新版との結合
- 並び順と上限: `occurred_at, request_id`の昇順、20件
- 返す情報: 要求、起因の基底イベント、次の回収の版
- 鮮度と一貫性: primaryから読む
- 想定件数: 要求の累計は月2万件ずつ増える。未完了は通常100件以下
- SLO: 20件の取得で p95 10ms
- 支えるindex: `overdue_notice_requested_events_occurred_idx`、`overdue_notice_claimed_events_request_version_key`

### Read-004: 通知の滞留と打ち切りを数える

- 利用者と目的: 運用担当者（監視）が、未完了の要求の件数と、この24時間に打ち切った件数を見る
- 入力・検索条件: 成功と失敗の表に無い要求、失敗の`occurred_at`が直近24時間
- 結合: 成功と失敗の表とのアンチ結合
- 並び順と上限: なし（件数だけ）
- 返す情報: 未完了の件数、最も古い未完了の`occurred_at`、打ち切った件数
- 鮮度と一貫性: 1分遅れてよい
- 想定件数: 未完了は通常100件以下、打ち切りは一日数件
- SLO: p95 50ms、1分ごと
- 支えるindex: `overdue_notice_requested_events_occurred_idx`
