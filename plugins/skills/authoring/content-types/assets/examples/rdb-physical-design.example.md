# RDB物理設計 — 貸会議室の予約

> これは [`rdb-physical-design.md`](../templates/rdb-physical-design.md) の記載例である。
> 対象製品、件数、計測結果は架空だが、判断と検証の粒度は実案件で再利用できる形にしている。
>
> 型: RDB物理設計 ／ 読み手: DB設計者、実装者、運用者 ／ 入力: [RDB論理設計例](rdb-logical-data-modeling.example.md)

**対象DBMSをPostgreSQL 16.4に固定し、論理設計の8テーブルを変えずに、制約、index、分離性、代表的なReadを設計する。** 存在しない空き枠は行ロックできないため、重複占有の成立判定には時間範囲の排他制約を使う。

## 対象と論理設計

- 対象DBMS: PostgreSQL
- 対象バージョン: 16.4
- 論理モデル: `rdb-logical-data-modeling.example.md`（2026-09-01）
- 論理構造の指紋: sha256:a22f20db7250301ad021c3b35adf3174c4d6247985fb84cabf14ffd888e744c7
- 確認環境: PostgreSQL 16.4、1 primary、東京リージョン、2026-09-02
- 想定規模: 予約500万件、基底イベント2,000万件、ピーク150予約/秒、イベント7年保持

論理設計のER図、列定義、CUDのBDD、Before / Afterは再掲しない。以下の計測値は記載例の粒度を示す架空値であり、実案件では同じ条件を対象環境で測り直す。

## 物理制約

| 制約名 | 対象 | PostgreSQL 16.4での実現 | 適用時点 | 違反時の扱い |
|---|---|---|---|---|
| 予約期間は正の長さ | `reservations`、`room_booking_claims` | `starts_at < ends_at`のCHECK | 行の書込み時 | transactionを中断し、入力不正として扱う |
| 同じ会議室の占有は重ならない | `room_booking_claims` | `room_code`の等価と半開時間範囲の重なりをGiST排他制約で拒否 | 行の書込み時 | 後発を中断し、利用枠を確保できなかった結果へ変換する |
| 仮押さえだけが期限を持つ | `reservations`、`tentative_hold_deadlines` | 外部キーと、状態変更transaction内の状態再検査 | 状態変更時 | 前提不一致としてtransactionを中断する |
| イベントversionは予約内で一意 | `reservation_base_events` | `reservation_id, version`の一意制約 | 基底イベントの書込み時 | 競合した状態変更を中断する |
| 基底イベントと詳細イベントは一対一 | 4つの詳細イベント | `base_event_id`の外部キーと一意制約 | 詳細イベントの書込み時 | transaction全体を中断する |
| 基底イベントの種類と詳細の種類が一致する | 基底イベントと4つの詳細イベント | 一つのtransactionで対応する一種類だけを書き、commit前に整合を検査する | 業務イベントの成立時 | 不一致ならrollbackする |
| 現在versionは最後のイベントversionと一致する | `reservations`、`reservation_base_events` | 予約行ロック後のversion検査と、一意制約を同一transactionで組み合わせる | 状態変更時 | 更新件数0または一意制約違反として中断する |

異なるテーブルをまたぐ「イベント種別に対応する詳細がちょうど一行ある」という制約は、単純なCHECKだけでは表せない。基底イベントだけを先にcommitせず、基底イベントと対応する詳細イベントを同じtransactionで確定する。

## 物理化の方針

| 論理上の判断 | 物理化 | 理由 |
|---|---|---|
| 会議室と利用枠の重複禁止 | `btree_gist`を利用したGiST排他制約 | まだ行がない空き時間も、書込み時の範囲競合として判定できる |
| 予約の現在version | `bigint`のNOT NULL、1以上 | 基底イベントのversionと比較し、同じ事前状態からの二重成立を検出する |
| イベント発生日時 | 基底イベントの`occurred_at`だけに保持 | 詳細イベントへ時刻を重複させず、業務上の成立時刻を一意にする |
| リソース成立日時 | リソース系テーブルの`created_at`に保持 | イベント発生日時と、現在の占有・期限が作られた日時を区別する |
| 任意の詳細 | イベント種類ごとの詳細テーブルへ分離 | 種類によって使わない列をNULLにしない |

物理設計の資料には、論理設計にあるテーブルとカラムの定義表を複製しない。migrationはこの判断を実装する別成果物として管理し、対象バージョンで制約が有効になったことを検証する。

## index

### index: `room_booking_claims_room_time_excl`

- 対象: `room_booking_claims`の`room_code`、`tstzrange(starts_at, ends_at, '[)')`
- 種類: GiST排他制約を支えるindex
- 目的: 同じ会議室の重なる占有を拒否し、指定会議室・指定期間の重なり検索を支える
- 列の順番: 会議室を等価条件で限定してから、その会議室内の時間範囲を重なり演算子で調べる。時間範囲を先にして全会議室を候補に広げない
- 対象Read・更新: 同時仮押さえ、Read-001
- 根拠: 500万件相当でBitmap Index Scan、対象180件、p95 18msという検証条件を置く
- 更新費用: 仮押さえの追加と、取消・期限切れの削除で更新する。ピーク150件/秒でp95 24msを上限とする

### index: `tentative_hold_deadlines_expires_at_reservation_id_idx`

- 対象: `tentative_hold_deadlines (expires_at, reservation_id)`
- 種類: B-tree複合index
- 目的: 期限が到来した仮押さえを時刻順に100件ずつ取得する
- 列の順番: 全予約を対象に`expires_at <= 現在日時`という範囲を先に絞り、同時刻の行を`reservation_id`で安定して並べる。`reservation_id`を先にすると、全体の期限到来走査を支えられない
- 対象Read・更新: 期限切れ処理
- 根拠: 50万件中100件取得でIndex Scan、p95 7msという検証条件を置く
- 更新費用: 仮押さえで追加し、確定・取消・期限切れで削除する

### index: `reservation_base_events_reservation_id_version_key`

- 対象: `reservation_base_events (reservation_id, version)`
- 種類: 一意制約が作るB-tree複合index
- 目的: イベントversionの一意性と、一予約の履歴をversion順に読む処理を支える
- 列の順番: `reservation_id`の等価条件で一予約に絞り、続く`version`で範囲検索と昇順取得を行う。`version`を先にすると一予約の履歴がindex上で連続しない
- 対象Read・更新: 全状態変更、Read-003
- 根拠: 一意制約が同じindexを作るため、同じ列の追加indexは作らない
- 更新費用: 業務イベント成立ごとに一エントリ増える

### index: `reservations_customer_upcoming_idx`

- 対象: `reservations (customer_code, starts_at, reservation_id)`。`status`が`tentative`または`confirmed`の行だけを対象とし、返却列をINCLUDEする
- 種類: B-tree複合・部分index
- 目的: 予約者本人が今後の予約を開始日時順に読む
- 列の順番: `customer_code`の等価条件を先頭にし、`starts_at`の範囲条件と並び順を続け、同時刻の予約を`reservation_id`で安定してページングする。この順番を変えると一予約者の範囲走査か安定順のどちらかを失う
- 対象Read・更新: Read-002
- 根拠: 500万件中の有効予約160万件を対象にIndex Only Scan、p95 12msという検証条件を置く
- 更新費用: 仮押さえで追加、確定でINCLUDE列を更新、取消・期限切れで除外される。終端状態の検索には使えない

### index: 各詳細イベントの`base_event_id`一意index

- 対象: 4つの詳細イベントそれぞれの`base_event_id`
- 種類: 一意制約が作る単一列B-tree index
- 目的: 一つの基底イベントへ同種の詳細を二重登録せず、Read-003の結合を支える
- 列の順番: 単一列なので順番の選択はない。結合キー以外を足すと一対一検査に不要な更新費用が増えるため追加しない
- 対象Read・更新: 全イベント書込み、Read-003
- 根拠: 一意制約と結合の双方を同じindexで満たす
- 更新費用: 対応するイベント成立時に一エントリだけ増える

## トランザクションと分離レベル

### 分離性判断: 同じ空き時間への同時仮押さえ

- 同時に進む操作: 同じ会議室の重なる時間へ二つの占有を追加する
- 許してはいけない結果: 二つの予約が同じ時間帯を占有する
- 発生し得る現象: 事前確認だけでは書き込みスキューに相当する重複占有が起きる
- 選択する分離レベル: READ COMMITTED
- 併用する仕組み: GiST排他制約
- 対象バージョンでの確認: 二つのsessionから同じ範囲を書き、先行commit後に後発がSQLSTATE `23P01`になることを確認する
- 競合時の扱い: 後発transactionを再試行せず、利用枠を確保できなかった結果へ変換する

空き時間にはロック対象の行が存在しないため、`SELECT ... FOR UPDATE`だけでは守れない。空き検索は利用者への応答には使えるが、成立の最終判断は排他制約へ任せる。

#### 具体的な解決手順

1. 予約、占有、期限、基底イベント、仮押さえ成立イベントを一つのtransactionで書く。
2. 占有の追加時に排他制約で重なりを判定する。
3. SQLSTATE `23P01`ならtransaction全体をrollbackし、先に書いた予約やイベントも残さない。
4. lock timeoutだけ最大1回再試行し、排他制約違反は再試行しない。

```sql
BEGIN;
SET LOCAL lock_timeout = '2s';

INSERT INTO reservations (
    reservation_id, location_code, room_code, customer_code, starts_at, ends_at,
    status, current_version, created_at, updated_at
) VALUES ($1, $2, $3, $4, $5, $6, 'tentative', 1, $7, $7);

INSERT INTO room_booking_claims
    (reservation_id, room_code, starts_at, ends_at, created_at)
VALUES ($1, $3, $5, $6, $7);

INSERT INTO tentative_hold_deadlines (reservation_id, expires_at, created_at)
VALUES ($1, $8, $7);

INSERT INTO reservation_base_events
    (id, reservation_id, event_type, version, actor_code, occurred_at)
VALUES ($9, $1, 'tentative_created', 1, $4, $7);

INSERT INTO reservation_tentative_created_events
    (id, base_event_id, location_code, room_code, customer_code, starts_at, ends_at, expires_at)
VALUES ($10, $9, $2, $3, $4, $5, $6, $8);
COMMIT;
```

- 競合の検知: SQLSTATE `23P01`
- 業務結果への変換: 「その利用枠は先に確保された」
- 再試行: lock timeoutだけ最大1回、50〜150msのjitter後。`23P01`は再試行しない
- 失敗時の原子性: 8テーブルのどこにも後発予約の行を残さない

### 分離性判断: 確定と期限切れの競合

- 同時に進む操作: 同じ仮押さえ予約を確定する処理と期限切れにする処理
- 許してはいけない結果: 同じ現在version 1から、確定と期限切れがともにversion 2として成立する
- 発生し得る現象: ロストアップデート
- 選択する分離レベル: READ COMMITTED
- 併用する仕組み: 予約行の`FOR UPDATE`、状態とcurrent_versionの再検査、基底イベントの一意制約
- 対象バージョンでの確認: 二つのsessionで同じ予約を進め、後発がロック取得後に新しい状態を観測して書込みを中止することを確認する
- 競合時の扱い: 後発は再試行せず、先に成立した現在状態を返す

#### 具体的な解決手順

1. 予約行を`FOR UPDATE`で取得し、同じ予約の状態変更を直列化する。
2. ロック取得後に`status`と`current_version`を再検査する。
3. 一方だけが予約をversion 2へ進め、期限を削除し、必要なら占有も削除する。
4. 基底イベントと、確定または期限切れの詳細イベントを同じtransactionで追加する。

```sql
BEGIN;
SELECT status, current_version
FROM reservations
WHERE reservation_id = $1
FOR UPDATE;

UPDATE reservations
SET status = $2, current_version = 2, updated_at = $3
WHERE reservation_id = $1
  AND status = 'tentative'
  AND current_version = 1;

DELETE FROM tentative_hold_deadlines WHERE reservation_id = $1;
DELETE FROM room_booking_claims
WHERE reservation_id = $1 AND $2 = 'expired';

INSERT INTO reservation_base_events
    (id, reservation_id, event_type, version, actor_code, occurred_at)
VALUES ($4, $1, $2, 2, $5, $3);

-- $2に対応する confirmed または expired の詳細イベントを一行追加する。
COMMIT;
```

- 競合の検知: ロック後の状態不一致、条件付きUPDATEの更新件数0、またはversion一意制約違反
- 業務結果への変換: 後発へ現在の確定済みまたは期限切れを返す
- 再試行: lock timeoutとデッドロックだけ最大1回。状態不一致は再試行しない
- 失敗時の原子性: 現在状態、期限、占有、基底イベント、詳細イベントをまとめてcommitまたはrollbackする

### 分離性判断: 取消と別の仮押さえの競合

- 同時に進む操作: 既存占有を削除する取消と、同じ時間へ新しい占有を追加する仮押さえ
- 許してはいけない結果: 取消がrollbackしたのに新しい占有も成立する
- 発生し得る現象: ダーティライト
- 選択する分離レベル: READ COMMITTED
- 併用する仕組み: 予約行ロックと、未commitの競合行を待つGiST排他制約
- 対象バージョンでの確認: 取消を未commitのまま新しい占有を書き、取消のcommit時だけ新規占有が成立することを確認する
- 競合時の扱い: lock timeoutを超えた場合だけ最大1回再試行する

#### 具体的な解決手順

1. 取消側は予約行をロックし、予約状態とcurrent_versionを再検査する。
2. 予約を取消済みへ進め、占有と仮押さえ期限を削除し、取消の基底・詳細イベントを追加する。
3. 新しい仮押さえ側は占有を書き、排他制約が取消transactionの終了を待って成否を決める。
4. 取消がrollbackしたら旧占有が残り、新しい仮押さえは成立しない。

- 競合の検知: 排他制約待機、SQLSTATE `23P01`、lock timeout
- 業務結果への変換: 取消commit後にだけ新規仮押さえを成立させる。旧占有が残れば利用枠を確保できなかった結果にする
- 再試行: lock timeoutだけ最大1回。排他制約違反は再試行しない
- 失敗時の原子性: 取消の現在状態、占有、期限、基底イベント、詳細イベントは同じtransactionで確定する

## パーティションと配置

初期リリースでは8テーブルすべてを非partitionとする。基底イベント2,000万件で、予約番号による履歴取得と日次バックアップが目標内に収まるという検証条件を置く。

基底イベントが5,000万件を超えるか、保持期限を過ぎたイベントの月次削除が30分を超えた時点で、`occurred_at`による月次partitionを再検討する。詳細イベントは基底イベントと同じ保持単位で扱い、孤立させない。

## 容量・性能・運用

| 観点 | 前提・観測値 | 設計判断 | 確認方法・閾値 |
|---|---|---|---|
| データ量 | 予約500万件、基底イベント2,000万件 | 初期は非partition、イベント7年保持 | 月次件数と総容量を記録し、5,000万件で再評価 |
| 主要な書込み | 平常30件/秒、ピーク150件/秒 | 排他制約を含む仮押さえを一transactionに閉じる | p95 100ms、排他制約待機p99 500ms |
| 主要なRead | 一会議室31日分、予約者の20件、予約履歴100件 | 4つの根拠付きindexを使う | 各ReadのSLOと実行計画を継続確認 |
| 統計 | 会議室と時間帯に偏りがある | 毎日`ANALYZE`、変更率20%で自動解析 | 推定行数と実行行数が10倍乖離したら調査 |
| バックアップ | RPO 5分、RTO 60分 | 継続アーカイブと日次base backup | 四半期ごとに別環境へ復旧し60分以内を確認 |

## 採用するRDB機能

### 機能: GiST排他制約

- 採用箇所: 同じ会議室の重なる時間帯を`room_booking_claims`から排除する
- 採用理由: まだ存在しない空き時間をロックせず、書込み時に重複時間を拒否できる
- 対象バージョンで確認すること: `btree_gist`を有効化し、境界接触する二範囲は共存し、一分でも重なる範囲は拒否されること
- 運用上の注意: extensionをmigration前に確認し、GiST indexの膨張率を月次監視する

### 機能: transaction単位の行ロック

- 採用箇所: 同じ予約に対する確定、取消、期限切れ
- 採用理由: 状態とcurrent_versionを再検査するまで後発の更新を待機させられる
- 対象バージョンで確認すること: 待機後のstatementが最新状態を読み、同じversionから二つの状態変更を作らないこと
- 運用上の注意: transaction内で外部通知を行わず、ロック保持時間を100ms以内にする

## 物理設計の完了条件

- 論理設計のER図、列定義、CUDのBDD、Before / Afterを複製していない
- PostgreSQL 16.4で排他制約、境界接触、競合待機、制約違反を確認する手順がある
- すべてのindexに対象、目的、列順の理由、根拠、更新費用がある
- 同時仮押さえ、確定対期限切れ、取消対新規仮押さえに必要な分離性と具体策がある
- 代表的なReadに検索条件、結合、並び順、件数、鮮度、一貫性、SLO、支えるindexがある
- 件数、SLO、再評価条件、バックアップ復旧条件を数値で置いた

## 未決

- 実環境の500万件相当データで、GiST indexの更新p99とVACUUM時間を再計測する
- イベント7年保持は法務判断待ちであり、2026-09-30までに確定する

## 代表的な読み取り

以下はindexと配置を決めるためのReadである。CUDの業務規則を確かめるBDDではなく、物理設計で保証する検索条件、鮮度、一貫性、性能を固定する。

### Read-001: 会議室の占有時間を読み、予約可能時間を判断する

- 利用者と目的: 予約者が、指定会議室を指定期間に予約できるか判断する
- 入力・検索条件: `room_code`の等価条件と、対象期間に重なる半開時間範囲
- 結合: なし
- 並び順と上限: `starts_at, reservation_id`の昇順、最大500件
- 返す情報: 予約番号、利用開始、利用終了
- 鮮度と一貫性: primaryから読む。ただし検索結果は成立保証ではなく、書込み時の排他制約が最終判断する
- 想定件数: 占有500万件、対象は平均180件、繁忙会議室で最大500件
- SLO: p95 50ms、p99 100ms、statement timeout 300ms
- 支えるindex: `room_booking_claims_room_time_excl`

```sql
SELECT reservation_id, starts_at, ends_at
FROM room_booking_claims
WHERE room_code = $1
  AND tstzrange(starts_at, ends_at, '[)') && tstzrange($2, $3, '[)')
ORDER BY starts_at, reservation_id
LIMIT 500;
```

**対象バージョンでの確認**: 500万件相当でGiSTのBitmap Index Scan、推定186行、実行180行、p95 18msを確認する。

### Read-002: 予約者が今後の自分の予約を読む

- 利用者と目的: 予約者本人が、今後の仮押さえ予約と確定予約を確認する
- 入力・検索条件: `customer_code`の等価条件、現在日時以降の`starts_at`、予約中の二状態
- 結合: なし
- 並び順と上限: `starts_at, reservation_id`の昇順、20件
- 返す情報: 予約番号、拠点、会議室、利用開始、利用終了、予約状態
- 鮮度と一貫性: 直前の取消や確定を反映するためprimaryからstatement単位で読む
- 想定件数: 予約500万件、有効予約160万件、予約者あたり平均3件、最大120件
- SLO: p95 30ms、p99 80ms、statement timeout 200ms
- 支えるindex: `reservations_customer_upcoming_idx`

```sql
SELECT reservation_id, location_code, room_code, starts_at, ends_at, status
FROM reservations
WHERE customer_code = $1
  AND starts_at >= $2
  AND status IN ('tentative', 'confirmed')
ORDER BY starts_at, reservation_id
LIMIT 20;
```

**対象バージョンでの確認**: 500万件相当でIndex Only Scan、推定4行、実行3行、heap fetch 0、p95 12msを確認する。

### Read-003: 予約の現在状態と業務イベントを同じ時点で読む

- 利用者と目的: 予約業務責任者が、一つの予約へ何が起きたか説明する
- 入力・検索条件: 一つの`reservation_id`
- 結合: 基底イベントから、`event_type`に対応する4つの詳細イベントへ`base_event_id`で外部結合する
- 並び順と上限: `version`の昇順、最大100件
- 返す情報: 予約の現在状態・現在version、各イベントのversion・種類・行為者・発生日時・種類固有の事実
- 鮮度と一貫性: primary上のREAD ONLY REPEATABLE READ transactionで同じsnapshotを使う
- 想定件数: 予約500万件、基底イベント2,000万件、一予約あたり平均4件、最大100件
- SLO: transaction全体でp95 20ms、p99 50ms、statement timeout 200ms
- 支えるindex: `reservations_pkey`、`reservation_base_events_reservation_id_version_key`、各詳細イベントの`base_event_id`一意index

```sql
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY;

SELECT reservation_id, status, current_version, updated_at
FROM reservations
WHERE reservation_id = $1;

SELECT e.version, e.event_type, e.actor_code, e.occurred_at,
       t.location_code, t.room_code, t.starts_at, t.ends_at, t.expires_at,
       (c.base_event_id IS NOT NULL) AS confirmed,
       (x.base_event_id IS NOT NULL) AS cancelled,
       (d.base_event_id IS NOT NULL) AS expired
FROM reservation_base_events AS e
LEFT JOIN reservation_tentative_created_events AS t ON t.base_event_id = e.id
LEFT JOIN reservation_confirmed_events AS c ON c.base_event_id = e.id
LEFT JOIN reservation_cancelled_events AS x ON x.base_event_id = e.id
LEFT JOIN reservation_expired_events AS d ON d.base_event_id = e.id
WHERE e.reservation_id = $1
ORDER BY e.version
LIMIT 100;

COMMIT;
```

**対象バージョンでの確認**: 2,000万基底イベント相当で予約ごとのIndex Scanと詳細の一意indexによる結合を使い、4イベント取得p95 9ms、100イベントでも50ms以内を確認する。
