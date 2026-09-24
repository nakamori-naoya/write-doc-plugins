# RDB物理設計 — 図書館の貸出

<!-- これは`rdb-physical-design`型の記載例である。**構成の基準資料ではなく、粒度と具体性の見本として読む。**
     架空の題材「図書館の貸出」の論理データモデルを写した。件数と計測値は説明用の仮想値である。 -->

**対象DBMSをPostgreSQL 16.4に固定し、論理設計の9テーブルを変えずに、制約、index、分離レベルとやり直し、代表的なReadを決める。** 借りている冊数は集計列を足さずに数え、貸出上限は`SERIALIZABLE`とやり直しで守る。延滞の通知の回収は、利用者から見えないが件数とともに遅くなるReadとして台帳に載せる。

## 対象と論理設計

- 対象DBMS: PostgreSQL
- 対象バージョン: 16.4
- 論理モデル: `rdb-logical-data-modeling.example.md`（2026-10-01）
- 入力にした論理設計: [RDB論理設計の記載例](rdb-logical-data-modeling.example.md)（版: 2026-10-01 確定）
- 論理構造の指紋: sha256:94ef79e7d5c823f2e615218d15754ffe2f63eaa38cc776543ba04db37a2c40d3
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
| 一冊の本の貸出中か延滞の貸出は一つ | `loans` | `book_number`の部分一意index（`status IN ('lent', 'overdue')`） | 行の書込み時 | SQLSTATE `23505`を「貸出中の本を借りる」へ変換する。やり直さない |
| 一人の貸出中と延滞の貸出は5冊まで | `loans` | `SERIALIZABLE`のtransactionで件数を読んでから書く | commit時 | SQLSTATE `40001`なら transaction の中で最大3回やり直す |
| 現在の版は最後のイベントの版 | `loans`、`loan_base_events` | `loans`の`current_version`を読んだ版で条件付きに更新し、`loan_base_events`の`loan_id, version`の一意制約と同じtransactionで組み合わせる | 状態変更時 | 更新件数0か`23505`なら競合として返す。やり直さない |
| 成功と失敗はどちらか一つ | `overdue_notice_succeeded_events`、`overdue_notice_failed_events` | 両表の`request_id`主キーと、書く前に他方が無いことを同じtransactionで確かめる | 書込み時 | 他方が先にあれば書かずに終える |

値の範囲の CHECK は、ドメインモデルだけが書く業務の表（`loans`、基底イベント、詳細イベント）には置かない。値の正しさの持ち主はドメインモデルで、持ち主を二つにしないためである。技術処理の表はドメインモデルの外の送り手が書くので、`overdue_notice_claimed_events.version`が1以上であることと、`overdue_notice_failed_events.reason`が空でないことを CHECK で拒む。

## 物理化の方針

### 物理写像: 貸出の状態と版

- 論理上の意味: 貸出のいまの状態と`current_version`は、基底イベントから導けるが、楽観ロックと毎回の貸出での読み取りのために論理設計が妥協として持つ
- 物理実装: `loans.status`は`text`、`loans.current_version`は`bigint`で持ち、状態を変えるたびに読んだ版を条件に更新する
- 一次データと同期: 一次データは基底イベントと詳細イベントである。基底イベントの追加と`loans`の更新を同じtransactionで確定し、片方だけをcommitしない
- 再構築・撤去: 基底イベントを`version`順に畳み込んで状態と版を作り直せる。毎日一度、作り直した結果と比べ、食い違いがあれば運用へ知らせる
- 不変条件の保存: `current_version`は、その貸出の基底イベントの最大の`version`と等しい

## index

index は、下の四つの Read と、同じ本の二重の貸出を拒む制約を支えるものだけを置く。

| index | 対象 | 種類 | 支えるRead・更新 | 更新費用 | 検証状態 |
|---|---|---|---|---|---|
| `loans_book_active_key` | `loans (book_number)`、`status IN ('lent', 'overdue')` の行だけ | B-tree部分一意index | 本を借りる、Read-001 | 貸出で追加、返却で対象外になる | planned |
| `loans_user_active_idx` | `loans (user_number)`、`status IN ('lent', 'overdue')` の行だけ、`status` をINCLUDE | B-tree部分index | Read-001 | 貸出で追加、延滞でINCLUDE列を更新、返却で対象外になる | planned |
| `loans_due_lent_idx` | `loans (due_on, loan_id)`、`status = 'lent'` の行だけ | B-tree複合・部分index | Read-002 | 貸出で追加、延滞と返却で対象外になる | planned |
| `overdue_notice_requested_events_occurred_idx` | `overdue_notice_requested_events (occurred_at, request_id)` | B-tree複合index | Read-003、Read-004 | 要求の追加ごとに一エントリ増える | planned |
| `overdue_notice_claimed_events_request_version_key` | `overdue_notice_claimed_events (request_id, version)` | 一意制約が作るB-tree複合index | 回収、Read-003 | 回収ごとに一エントリ増える | planned |

`loans_book_active_key`は、一冊の本の貸出中か延滞の貸出を一つに限る。本の確認は、同時に貸し出している15万行のうち1行を読むだけで済む。

`loans_user_active_idx`は、一人が借りている冊数と延滞の有無を、一度の走査で読むために置く。利用者あたり最大5行を、表を読まずにindexだけで返すという仮の結果を置いている。

`loans_due_lent_idx`は、返却期限を過ぎた貸出中の貸出を、返却期限の順に探すために置く。`due_on`の範囲で先に絞り、同じ日の行は`loan_id`で並びを安定させる。一日分の候補は平均400行という仮の値を置いている。

`overdue_notice_requested_events_occurred_idx`は、回収できる要求を古い順に探すために置く。要求は削除しないので、累計は増え続ける。成功と失敗の表の主キーとのアンチ結合で、未完了の要求だけを読む。未完了が100件以下なら p95 10ms という仮の値を置き、累計が100万件を超えたら、未完了の要求だけを持つ派生の表を考え直す。

`overdue_notice_claimed_events_request_version_key`は、同じ要求の同じ版を二度回収させない一意制約が作るindexである。`request_id`で要求に絞り、`version`の降順で最新の回収を引く用途にもそのまま使えるので、別のindexは足さない。

## トランザクションと分離レベル

分離レベルと、transaction の中でのやり直しの回数は、この節が操作ごとに決める。実装はここで決めた指定をtransactionへ渡すだけにする。

### 分離性判断: 貸出上限

同じ利用者が二冊を同時に借りると、どちらも4冊と数えてから書き、6冊になりうる（書き込みスキュー）。`SERIALIZABLE`で守り、直列化の失敗（SQLSTATE `40001`）だけを transaction の中で最大3回、10〜50msの揺らぎを置いてやり直す。やり直しで5冊と数えたら「貸出上限に達している利用者が本を借りる」を返す。二つのsessionで4冊の状態から同時に借り、一方が`40001`で中断することを確かめる。

集計列（利用者ごとの借りている冊数）を足せば一行の問題にできるが、導いた値が二つになり、返却のたびに二か所を直すことになる。件数は最大5行なので、数えるほうを選んだ。

検証状態: planned

### 分離性判断: 同じ本を二人が借りる

同じ本を二人が同時に借りると、どちらも「まだ貸出中でない」と読んで書きうる。貸出上限と同じ`SERIALIZABLE`のtransactionの中で、`loans_book_active_key`の部分一意indexが後の一方を`23505`で拒む。やり直さず「貸出中の本を借りる」を返す。二つのsessionで同じ本を借り、後の一方が`23505`で中断することを確かめる。

検証状態: planned

### 分離性判断: 延滞にするのと返却が重なる

同じ貸出を延滞にする処理と本を返す処理が、どちらも版1を読んで版2を書こうとする（ロストアップデート）。`READ COMMITTED`で、読んだ版を条件にした`loans`の更新が後の一方で0件になり、それでも進んだ場合は`loan_id, version`の一意制約が`23505`で拒む。やり直さない。延滞にする側は、その貸出を次の走査に任せる。二つのsessionで版1の貸出を同時に進め、後の一方の更新が0件になることを確かめる。

検証状態: planned

### 分離性判断: 通知の要求の回収

二つの送り手が同じ要求を回収しようとすると、どちらも未回収と読んで回収を書きうる。`READ COMMITTED`で、`request_id, version`の一意制約が後の一方を`23505`で拒み、その送り手は次の候補へ進む。追加のみの型にそのまま合うので一意制約を既定にした。回収の待ち行列が長く衝突が多すぎる場合に限り、候補の走査に`FOR UPDATE SKIP LOCKED`を足して他の送り手が見ている要求を飛ばす。外部への送信は、回収のtransactionをcommitしてから行う。

検証状態: planned

## パーティションと配置

初期は9テーブルとも非partitionとする。基底イベントが3,000万件を超えたら、`occurred_at`による年次partitionを再検討する。通知の要求は削除しないので、累計100万件で走査の方法を見直す（index: `overdue_notice_requested_events_occurred_idx`）。

## 容量・性能・運用

| 観点 | 前提・観測値 | 設計判断 | 確認方法・閾値 |
|---|---|---|---|
| データ量 | 貸出300万件、基底イベント700万件 | 非partition | 基底イベント3,000万件で再評価 |
| 貸出の書込み | ピーク20件/秒 | 貸出を`SERIALIZABLE`の一transactionに閉じる | p95 50ms、`40001`のやり直し率1%未満 |
| 状態と版の整合 | 毎日一度イベントから作り直して比べる | 食い違いは運用へ知らせる | 食い違いが1件でもあれば調査 |
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

| Read | 利用者 | 並び順と上限 | 鮮度と一貫性 | 想定件数 | SLO | 支えるindex |
|---|---|---|---|---|---|---|
| Read-001 | 本を借りる処理（書込みの中の判定） | なし。利用者は最大5行、本は最大1行 | 貸出を書くのと同じ`SERIALIZABLE`のtransactionで読む | 同時15万行のうち、利用者あたり最大5行 | p95 5ms | `loans_user_active_idx`、`loans_book_active_key` |
| Read-002 | 延滞にする処理（背景処理） | `due_on, loan_id`の昇順、100件ずつ | primaryから読む。読んだ後の変化は許す | 一日分の候補は平均400行 | 100件の取得で p95 20ms | `loans_due_lent_idx` |
| Read-003 | 延滞の通知の送り手（背景処理） | `occurred_at, request_id`の昇順、20件 | primaryから読む | 要求の累計は月2万件ずつ増え、未完了は通常100件以下 | 20件の取得で p95 10ms | `overdue_notice_requested_events_occurred_idx`、`overdue_notice_claimed_events_request_version_key` |
| Read-004 | 運用担当者（監視） | なし（件数だけ） | 1分遅れてよい | 未完了は通常100件以下、打ち切りは一日数件 | 1分ごとに p95 50ms | `overdue_notice_requested_events_occurred_idx` |

Read-001は、本を借りてよいかを判断するための読み取りである。`user_number`と`status IN ('lent', 'overdue')`で利用者の貸出を読み、借りている冊数と延滞の貸出があるかを返す。あわせて`book_number`で、その本がほかに貸し出されていないかを確かめる。結合はしない。

Read-002は、判定の日に返却期限を過ぎた貸出中の貸出を探す。条件は`status = 'lent'`と`due_on < 判定日`で、結合はせず、貸出と読んだ版を返す。延滞にする書込みが読んだ版で確かめ直すので、読んだ後に返却されても誤って延滞にはしない。

Read-003は、成功も失敗も無く、生きている回収も無い通知の要求を、古い順に探す。成功と失敗の表とはアンチ結合し、回収の表からは最新の版を結合する。最新の回収が無いか、その`occurred_at`からリースの10分を過ぎていれば、回収できる。返すのは、要求、起因になった基底イベント、次の回収の版である。

Read-004は、未完了の要求の件数と、この24時間に打ち切った件数を数える。成功と失敗の表とのアンチ結合で未完了を数え、最も古い未完了の`occurred_at`もあわせて返す。打ち切りは、失敗の`occurred_at`が直近24時間のものを数える。
