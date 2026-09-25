# RDB物理設計 — 図書館の貸出

対象DBMSをPostgreSQL 16.4に固定し、論理設計の9テーブルを変えずに、制約、index、分離レベルとやり直し、代表的なReadを決める。 借りている冊数は集計列を足さずに数え、貸出上限は`SERIALIZABLE`とやり直しで守る。延滞の通知の回収は、利用者から見えないが件数とともに遅くなるReadとして台帳に載せる。

## 対象と論理設計

- 対象DBMS: PostgreSQL
- 対象バージョン: 16.4
- 論理モデル: `rdb-logical-data-modeling.example.md`（2026-10-01）
- 要求資料: `requirements-discovery.example.md`
- 利用・負荷モデル: `workload-model.example.md`
- 品質要求資料: `quality-requirements.example.md`
- 基盤構成資料: `cloud-architecture.example.md`
- 検証証拠: 未実施
- 確認環境: PostgreSQL 16.4、プライマリ1台（4 vCPU / 16 GiB）、2026-10-02
- 想定規模: 貸出の累計300万件、貸出中と延滞は同時に15万件、基底イベント700万件、通知の要求は月2万件、ピークは開館直後の20貸出/秒

ER図とBDDは論理設計にあり、この資料には写さない。

## 業務制約は一意制約、条件付きの更新、SERIALIZABLE で守る

| 制約名 | 対象 | 実現方法 | 適用時点 | 違反時の扱い |
|---|---|---|---|---|
| 一冊の本の貸出中か延滞の貸出は一つ | `loans` | `book_number`の部分一意index（`status IN ('lent', 'overdue')`） | 行の書込み時 | SQLSTATE `23505`を「貸出中の本を借りる」へ変換する。やり直さない |
| 一人の貸出中と延滞の貸出は5冊まで | `loans` | `SERIALIZABLE`のトランザクションで件数を読んでから書く | コミット時 | SQLSTATE `40001`ならトランザクションの中で最大3回やり直す |
| 現在の版は最後のイベントの版 | `loans`、`loan_base_events` | `loans`の`current_version`を読んだ版で条件付きに更新し、`loan_base_events`の`loan_id, version`の一意制約と同じトランザクションで組み合わせる | 状態変更時 | 更新件数0か`23505`なら競合として返す。やり直さない |
| 成功と失敗はどちらか一つ | `overdue_notice_succeeded_events`、`overdue_notice_failed_events` | 両表の`request_id`主キーと、`READ COMMITTED`のトランザクションで要求の行を`FOR UPDATE`で押さえてから、他方が無いことを確かめて書く | 書込み時 | 他方が先にあれば書かずに終える |

値の範囲のCHECKは、ドメインモデルだけが書く業務の表（`loans`、基底イベント、詳細イベント）には置かない。値が正しいかを決めるのはドメインモデルで、決める場所を二つにしないためである。一方、技術処理の表はドメインモデルの外にある送り手が書く。そこで、`overdue_notice_claimed_events.version`が1以上であることと、`overdue_notice_failed_events.reason`が空でないことは、CHECKで拒む。

## 物理化の方針

### 物理写像: 貸出の状態と版

貸出のいまの状態と`current_version`は基底イベントから導けるが、楽観ロックと毎回の貸出での読み取りのために、論理設計が妥協として持っている。物理では`loans.status`を`text`、`loans.current_version`を`bigint`で持ち、状態を変えるたびに読んだ版を条件に更新する。

一次データは基底イベントと詳細イベントなので、基底イベントの追加と`loans`の更新を同じトランザクションで確定し、片方だけをコミットしない。こうすれば`current_version`は、その貸出の基底イベントの最大の`version`と等しいままになる。基底イベントを`version`順に畳み込めば状態と版を作り直せるので、毎日一度、作り直した結果と比べ、食い違いがあれば運用へ知らせる。

## index

indexは、下の四つのReadと、同じ本の二重の貸出を拒む制約を支えるものだけを置く。

| index | 対象 | 種類 | 支えるRead・更新 | 更新費用 | 検証状態 |
|---|---|---|---|---|---|
| `loans_book_active_key` | `loans (book_number)`、`status IN ('lent', 'overdue')` の行だけ | B-tree部分一意index | 本を借りる、Read-001 | 貸出で追加、返却で対象外になる | planned |
| `loans_user_active_idx` | `loans (user_number)`、`status IN ('lent', 'overdue')` の行だけ、`status` をINCLUDE | B-tree部分index | Read-001 | 貸出で追加、延滞でINCLUDE列を更新、返却で対象外になる | planned |
| `loans_due_lent_idx` | `loans (due_on, loan_id)`、`status = 'lent'` の行だけ | B-tree複合・部分index | Read-002 | 貸出で追加、延滞と返却で対象外になる | planned |
| `overdue_notice_requested_events_occurred_idx` | `overdue_notice_requested_events (occurred_at, request_id)` | B-tree複合index | Read-003、Read-004 | 要求の追加ごとに一エントリ増える | planned |
| `overdue_notice_claimed_events_request_version_key` | `overdue_notice_claimed_events (request_id, version)` | 一意制約が作るB-tree複合index | 回収、Read-003 | 回収ごとに一エントリ増える | planned |

`loans_book_active_key`は、一冊の本の貸出中か延滞の貸出を一つに限る。本の確認は、同時に貸し出している15万行のうち1行を読むだけで済む。

`overdue_notice_requested_events_occurred_idx`は、回収できる要求を古い順に探すために置く。要求は削除しないので、累計は増え続ける。成功と失敗の表の主キーとのアンチ結合で、未完了の要求だけを読む。未完了が100件以下ならp95で10msという仮の値を置き、累計が100万件を超えたら、未完了の要求だけを持つ派生の表を考え直す。

## トランザクションと分離レベル

分離レベルと、トランザクションの中でのやり直しの回数は、この節が操作ごとに決める。実装はここで決めた指定をトランザクションへ渡すだけにする。

### 分離性判断: 貸出上限

同じ利用者が二冊を同時に借りると、どちらも4冊と数えてから書き、6冊になりうる（書き込みスキュー）。`SERIALIZABLE`で守り、直列化の失敗（SQLSTATE `40001`）だけをトランザクションの中で最大3回、10〜50msの揺らぎを置いてやり直す。やり直しで5冊と数えたら「貸出上限に達している利用者が本を借りる」を返す。二つのセッションで4冊の状態から同時に借り、一方が`40001`で中断することを確かめる。

集計列（利用者ごとの借りている冊数）を足せば一行の問題にできるが、導いた値が二つになり、返却のたびに二か所を直すことになる。件数は最大5行なので、数えるほうを選んだ。

検証状態: planned

### 分離性判断: 延滞にするのと返却が重なる

同じ貸出を延滞にする処理と本を返す処理が、どちらも版1を読んで版2を書こうとする（ロストアップデート）。`READ COMMITTED`で、読んだ版を条件にした`loans`の更新が後の一方で0件になり、それでも進んだ場合は`loan_id, version`の一意制約が`23505`で拒む。やり直さない。延滞にする側は、その貸出を次の走査に任せる。二つのセッションで版1の貸出を同時に進め、後の一方の更新が0件になることを確かめる。

検証状態: planned

### 分離性判断: 成功と失敗を書く

リースが切れて二つの送り手が同じ要求を持つと、一方が成功を、他方が失敗を同時に書きうる。書く表が別なので、主キーだけでは両方が入る（書き込みスキュー）。`READ COMMITTED`で、成功か失敗を書く前に`overdue_notice_requested_events`の要求の行を`SELECT … FOR UPDATE`で押さえ、同じトランザクションの中で他方の表にその`request_id`が無いことを確かめてから書く。後から来た一方は、ロックが解けた後に他方を読み、書かずに終える。やり直さない。`SERIALIZABLE`でも守れるが、この処理は一件ずつで競合の相手が決まっているので、行ロックで足りる。二つのセッションで同じ要求の成功と失敗を同時に書き、後の一方が何も書かずに終わることを確かめる。

検証状態: planned

## パーティションと配置

初期は9テーブルともパーティションに分けない。基底イベントが3,000万件を超えたら、`occurred_at`による年次パーティションを再検討する。通知の要求は削除しないので、累計100万件で走査の方法を見直す（index: `overdue_notice_requested_events_occurred_idx`）。

## 採用するRDB機能

### 機能: 部分一意index

`loans_book_active_key`で使う。返却済みの行を残したまま、貸出中と延滞の行だけを一冊一つに限れる。

- 利用可能な版: 対象版で利用できる
- 根拠: https://www.postgresql.org/docs/16/indexes-partial.html
- 検証状態: planned

## 物理設計の完了条件

### 検証: 競合時の業務結果

貸出上限、延滞と返却、成功と失敗のそれぞれを、PostgreSQL 16.4の二つのセッションで交差実行する。論理設計が許さない結果が起きず、後の一方へ決めた業務結果かやり直しを返せば合格とする。DBMS版、分離レベル、制約、やり直しの方針が変われば見直す。実機での証拠はまだ無い。

- 状態: planned

### 検証: 代表Readの性能

Read-001からRead-004と、それを支えるindexについて、想定件数と分布を再現し、`EXPLAIN (ANALYZE, BUFFERS)`と反復計測を行う。各ReadのSLOを満たせば合格とし、件数、分布、通知の滞留が変われば見直す。

- 状態: planned

## 未決

- 通知のリース10分と回収の上限5回は、論理設計の仮説を写した。送り先の応答時間が分かれば確定する
- 貸出上限のやり直しの上限3回は、ピークの競合率を実測してから確定する

## 代表的な読み取り

Readには、利用者の問い合わせだけでなく、背景処理の走査、監視の集計、書込みの中の判定条件も載せる。どれも件数とともに遅くなるからである。

| Read | 利用者 | 並び順と上限 | 鮮度と一貫性 | 想定件数 | SLO | 支えるindex |
|---|---|---|---|---|---|---|
| Read-001 | 本を借りる処理（書込みの中の判定） | なし。利用者は最大5行、本は最大1行 | 貸出を書くのと同じ`SERIALIZABLE`のトランザクションで読む | 同時15万行のうち、利用者あたり最大5行 | p95 5ms | `loans_user_active_idx`、`loans_book_active_key` |
| Read-002 | 延滞にする処理（背景処理） | `due_on, loan_id`の昇順、100件ずつ | プライマリから読む。読んだ後の変化は許す | 一日分の候補は平均400行 | 100件の取得で p95 20ms | `loans_due_lent_idx` |
| Read-003 | 延滞の通知の送り手（背景処理） | `occurred_at, request_id`の昇順、20件 | プライマリから読む | 要求の累計は月2万件ずつ増え、未完了は通常100件以下 | 20件の取得で p95 10ms | `overdue_notice_requested_events_occurred_idx`、`overdue_notice_claimed_events_request_version_key` |
| Read-004 | 運用担当者（監視） | なし（件数だけ） | 1分遅れてよい | 未完了は通常100件以下、打ち切りは一日数件 | 1分ごとに p95 50ms | `overdue_notice_requested_events_occurred_idx` |

Read-001は、本を借りてよいかを判断するための読み取りである。`user_number`と`status IN ('lent', 'overdue')`で利用者の貸出を読み、借りている冊数と延滞の貸出があるかを返す。あわせて`book_number`で、その本がほかに貸し出されていないかを確かめる。結合はしない。

Read-003は、成功も失敗も無く、生きている回収も無い通知の要求を、古い順に探す。成功と失敗の表とはアンチ結合し、回収の表からは最新の版を結合する。最新の回収が無いか、その`occurred_at`からリースの10分を過ぎていれば、回収できる。返すのは、要求、起因になった基底イベント、次の回収の版である。
