# RDB論理設計 — 貸会議室の予約

> これは [`rdb-logical-data-modeling.md`](../templates/rdb-logical-data-modeling.md) の記載例である。
> RoomFlowは、組織内の共用会議室を予約する架空のサービスである。
> 型: RDB論理設計 ／ 読み手: 予約業務責任者、RDBデータ設計者 ／ 入力: [貸会議室予約の業務知識・コアドメイン](domain-rule.example.md)

**この論理設計は、予約の現在の姿を持つリソース系テーブルと、予約に一度起きた事実を積むイベント系テーブルを分ける。** 予約の`current_version`と基底イベントの`version`を対応させ、現在の姿へどの出来事まで反映済みかを説明できるようにする。

## 目的と範囲

- 支える業務: 会議室の仮押さえ、確定、予約者本人による取消、期限切れ
- 永続化の目的: 現在の予約可否へ答えながら、成立済みの業務イベントを上書きせず説明できるようにする
- 対象外: 予約待ちと顧客の予約資格の記録（別の論理設計）、会議室設備の管理、通知の送達結果
- 業務知識の正本: [貸会議室予約の業務知識・コアドメイン](domain-rule.example.md)
- 対応する具体例: 業務知識のBDD-001からBDD-005、BDD-013からBDD-017、BDD-023、BDD-024

## リソース系とイベント系

| 分類 | テーブル | 役割 | 時刻 |
|---|---|---|---|
| リソース系 | `reservations` | 予約の現在の姿と、反映済みの最新versionを持つ | `created_at`、`updated_at` |
| リソース系 | `room_booking_claims` | 現在占有されている会議室と利用枠を持つ | `created_at` |
| リソース系 | `tentative_hold_deadlines` | 現在有効な仮押さえ期限を持つ | `created_at` |
| イベント系 | `reservation_base_events` | イベント共通の対象、種類、version、行為者、発生日時を積む | `occurred_at` |
| イベント系 | `reservation_tentative_created_events` | 仮押さえ成立時点の予約内容と期限を残す | 基底イベントの`occurred_at`を使う |
| イベント系 | `reservation_confirmed_events` | 予約が確定した事実を基底イベントへ結びつける | 基底イベントの`occurred_at`を使う |
| イベント系 | `reservation_cancelled_events` | 予約者が予約を取り消した事実を基底イベントへ結びつける | 基底イベントの`occurred_at`を使う |
| イベント系 | `reservation_expired_events` | 仮押さえ期限が到来した事実を基底イベントへ結びつける | 基底イベントの`occurred_at`を使う |

イベント系テーブルに`created_at`は持たせない。業務上の成立時刻は基底イベントの`occurred_at`で一度だけ表す。詳細イベントは、対応する基底イベントがどの種類の事実であり、種類固有の何を残すかを表す。

## シナリオと記録の対応

| シナリオ | リソース系の変化 | 基底イベント | 追加する詳細イベント |
|---|---|---|---|
| BDD-001 仮押さえ | 予約、予約枠占有、仮押さえ期限を追加 | version 1を追加 | 仮押さえ成立イベント |
| BDD-002 期限時刻の確定 | 予約をversion 2へ更新し、占有と期限を削除 | version 2を追加 | 予約期限切れイベント |
| BDD-003 確定 | 予約をversion 2へ更新し、期限を削除 | version 2を追加 | 予約確定イベント |
| BDD-004 取消 | 予約をversion 3へ更新し、占有を削除 | version 3を追加 | 予約取消イベント |
| BDD-005 同時仮押さえ | 成立した一件分だけ追加 | 成立した予約のversion 1だけ追加 | 成立した予約の仮押さえ成立イベントだけ追加 |
| BDD-006 仮押さえの取消 | 予約をversion 2へ更新し、占有と期限を削除 | version 2を追加 | 予約取消イベント |
| BDD-007 第三者による取消 | 変更なし | 追加なし | 追加なし |
| BDD-008 隣接する利用枠 | 既存行を変えず、新しい予約、占有、期限を追加 | 新しい予約のversion 1を追加 | 新しい予約の仮押さえ成立イベント |
| BDD-009 期限切れ | 予約をversion 2へ更新し、占有と期限を削除 | version 2を追加 | 予約期限切れイベント |
| BDD-010 重複する利用枠 | 変更なし | 追加なし | 追加なし |

## 論理データモデル図

図内は`型 英語カラム名 PK・FK等 "日本語名 / NULL制約 / 値域または説明"`の順で記載する。

```mermaid
erDiagram
    reservations {
        uuid reservation_id PK "予約番号 / NOT NULL"
        text location_code "拠点 / NOT NULL"
        text room_code "会議室 / NOT NULL"
        text customer_code "予約者 / NOT NULL"
        timestamptz starts_at "利用開始 / NOT NULL / ends_atより前"
        timestamptz ends_at "利用終了 / NOT NULL"
        text status "予約状態 / NOT NULL / tentative・confirmed・cancelled・expired"
        bigint current_version "現在version / NOT NULL / 1以上"
        timestamptz created_at "作成日時 / NOT NULL"
        timestamptz updated_at "最終更新日時 / NOT NULL"
    }
    room_booking_claims {
        uuid reservation_id PK, FK "予約番号 / NOT NULL"
        text room_code "会議室 / NOT NULL"
        timestamptz starts_at "利用開始 / NOT NULL / ends_atより前"
        timestamptz ends_at "利用終了 / NOT NULL"
        timestamptz created_at "作成日時 / NOT NULL"
    }
    tentative_hold_deadlines {
        uuid reservation_id PK, FK "予約番号 / NOT NULL"
        timestamptz expires_at "期限 / NOT NULL"
        timestamptz created_at "作成日時 / NOT NULL"
    }
    reservation_base_events {
        uuid id PK "基底イベント番号 / NOT NULL"
        uuid reservation_id FK, UK "予約番号 / NOT NULL / versionとの複合UK"
        text event_type "イベント種別 / NOT NULL / tentative_created・confirmed・cancelled・expired"
        bigint version UK "イベントversion / NOT NULL / reservation_idとの複合UK / 1以上"
        text actor_code "行為者 / NOT NULL"
        timestamptz occurred_at "発生日時 / NOT NULL"
    }
    reservation_tentative_created_events {
        uuid id PK "仮押さえ成立イベント番号 / NOT NULL"
        uuid base_event_id FK, UK "基底イベント番号 / NOT NULL"
        text location_code "拠点 / NOT NULL"
        text room_code "会議室 / NOT NULL"
        text customer_code "予約者 / NOT NULL"
        timestamptz starts_at "利用開始 / NOT NULL"
        timestamptz ends_at "利用終了 / NOT NULL"
        timestamptz expires_at "仮押さえ期限 / NOT NULL"
    }
    reservation_confirmed_events {
        uuid id PK "予約確定イベント番号 / NOT NULL"
        uuid base_event_id FK, UK "基底イベント番号 / NOT NULL"
    }
    reservation_cancelled_events {
        uuid id PK "予約取消イベント番号 / NOT NULL"
        uuid base_event_id FK, UK "基底イベント番号 / NOT NULL"
    }
    reservation_expired_events {
        uuid id PK "予約期限切れイベント番号 / NOT NULL"
        uuid base_event_id FK, UK "基底イベント番号 / NOT NULL"
    }

    reservations ||--o| room_booking_claims : "現在の利用枠を占有する"
    reservations ||--o| tentative_hold_deadlines : "仮押さえ中だけ期限を持つ"
    reservations ||--|{ reservation_base_events : "出来事がversion順に積み上がる"
    reservation_base_events ||--o| reservation_tentative_created_events : "種別がtentative_createdのとき持つ"
    reservation_base_events ||--o| reservation_confirmed_events : "種別がconfirmedのとき持つ"
    reservation_base_events ||--o| reservation_cancelled_events : "種別がcancelledのとき持つ"
    reservation_base_events ||--o| reservation_expired_events : "種別がexpiredのとき持つ"
```

## 論理テーブル定義

### `reservations`（予約）

予約番号が同じなら、状態が変わっても同じ予約である。`current_version`は現在の姿へ最後に反映した基底イベントの`version`と一致する。

| カラム（日本語名） | 制約 | 型 | 値域・意味 |
|---|---|---|---|
| `reservation_id`（予約番号） | PK、NOT NULL | uuid | 予約を追跡する番号 |
| `location_code`（拠点） | NOT NULL | text | 会議室が属する場所 |
| `room_code`（会議室） | NOT NULL | text | 予約対象の会議室 |
| `customer_code`（予約者） | NOT NULL | text | 利用する予約者 |
| `starts_at`（利用開始） | NOT NULL、`starts_at < ends_at` | timestamptz | 利用枠の始点 |
| `ends_at`（利用終了） | NOT NULL | timestamptz | 利用枠の終点 |
| `status`（予約状態） | NOT NULL | text | `tentative`、`confirmed`、`cancelled`、`expired` |
| `current_version`（現在version） | NOT NULL、1以上 | bigint | 最後に反映したイベントのversion |
| `created_at`（作成日時） | NOT NULL | timestamptz | 予約リソースが成立した日時 |
| `updated_at`（最終更新日時） | NOT NULL | timestamptz | 現在の姿へ最後に変わった日時 |

#### 業務制約: 予約期間は正の長さ

- 守ること: 利用開始は利用終了より前である
- 根拠となるシナリオ: BDD-001

#### 業務制約: 現在versionは最後のイベントversionと一致する

- 守ること: 予約の現在versionは、その予約で最後に成立した基底イベントのversionと一致する
- 根拠となるシナリオ: BDD-001からBDD-010

### `room_booking_claims`（予約枠占有）

仮押さえ予約または確定予約が現在占有している利用枠を表す。取消済み予約と期限切れ予約には存在しない。

| カラム（日本語名） | 制約 | 型 | 値域・意味 |
|---|---|---|---|
| `reservation_id`（予約番号） | PK、FK、NOT NULL | uuid | 占有を持つ予約 |
| `room_code`（会議室） | NOT NULL | text | 占有されている会議室 |
| `starts_at`（利用開始） | NOT NULL、`starts_at < ends_at` | timestamptz | 半開区間の始点 |
| `ends_at`（利用終了） | NOT NULL | timestamptz | 半開区間の終点 |
| `created_at`（作成日時） | NOT NULL | timestamptz | 占有が成立した日時 |

同じ会議室の時間帯は、境界接触を除いて二つの占有に属さない。

#### 業務制約: 同じ会議室の占有は重ならない

- 守ること: 同じ会議室では、境界接触を除いて利用時間帯が重なる占有を二つ成立させない
- 根拠となるシナリオ: BDD-005、BDD-008、BDD-010

### `tentative_hold_deadlines`（仮押さえ期限）

| カラム（日本語名） | 制約 | 型 | 値域・意味 |
|---|---|---|---|
| `reservation_id`（予約番号） | PK、FK、NOT NULL | uuid | 期限が適用される仮押さえ予約 |
| `expires_at`（期限） | NOT NULL | timestamptz | 確定しなければ占有を解放する時刻 |
| `created_at`（作成日時） | NOT NULL | timestamptz | 期限が成立した日時 |

#### 業務制約: 仮押さえだけが期限を持つ

- 守ること: 仮押さえ予約だけが期限を持ち、確定・取消・期限切れの成立時には期限を残さない
- 根拠となるシナリオ: BDD-001からBDD-004、BDD-006、BDD-009

### `reservation_base_events`（予約基底イベント）

基底イベントは予約へ起きた出来事をversion順に積む。追加後は書き換えない。同じ予約の`version`は重複せず、1から欠番なく進む。

| カラム（日本語名） | 制約 | 型 | 値域・意味 |
|---|---|---|---|
| `id`（基底イベント番号） | PK、NOT NULL | uuid | 一つの出来事を追跡する番号 |
| `reservation_id`（予約番号） | FK、NOT NULL | uuid | 出来事が属する予約 |
| `event_type`（イベント種別） | NOT NULL | text | `tentative_created`、`confirmed`、`cancelled`、`expired` |
| `version`（イベントversion） | NOT NULL、予約番号との組で一意、1以上 | bigint | 同じ予約で出来事が成立した順序 |
| `actor_code`（行為者） | NOT NULL | text | 予約者または期限管理 |
| `occurred_at`（発生日時） | NOT NULL | timestamptz | 業務上、出来事が成立した日時 |

#### 業務制約: イベントversionは予約内で一意

- 守ること: 同じ予約に同じversionの基底イベントを二つ成立させない
- 根拠となるシナリオ: BDD-001からBDD-006、BDD-008、BDD-009

#### 業務制約: 基底イベントと詳細イベントは一対一

- 守ること: 一つの基底イベントは対応する詳細イベントを一つだけ持つ
- 根拠となるシナリオ: BDD-001からBDD-010

#### 業務制約: 基底イベントの種類と詳細の種類が一致する

- 守ること: 基底イベントのイベント種別と、存在する詳細イベントの種類を一致させる
- 根拠となるシナリオ: BDD-001からBDD-010

### 詳細イベント

一つの基底イベントは、`event_type`に対応する詳細イベントを一つだけ持つ。詳細イベントには`created_at`も`occurred_at`も持たせず、発生日時は基底イベントから読む。

| テーブル | 固有のカラム | 対応するイベント種別 | 残す事実 |
|---|---|---|---|
| `reservation_tentative_created_events` | `id`（PK）、`base_event_id`（FK・UK）、`location_code`、`room_code`、`customer_code`、`starts_at`、`ends_at`、`expires_at`（すべてNOT NULL） | `tentative_created` | 仮押さえ成立時点の予約内容と期限 |
| `reservation_confirmed_events` | `id`（PK）、`base_event_id`（FK・UK）（すべてNOT NULL） | `confirmed` | 予約者が利用意思を示して予約が確定した事実 |
| `reservation_cancelled_events` | `id`（PK）、`base_event_id`（FK・UK）（すべてNOT NULL） | `cancelled` | 予約者が自分の予約を取り消した事実 |
| `reservation_expired_events` | `id`（PK）、`base_event_id`（FK・UK）（すべてNOT NULL） | `expired` | 未確定のまま仮押さえ期限が到来した事実 |

## ライフサイクルと時間軸

| テーブル | 作成 | 更新 | 業務上の終了 | 保持 |
|---|---|---|---|---|
| `reservations` | 仮押さえ成立 | 確定、取消、期限切れで状態・現在version・最終更新日時を更新 | 行は消さず終端状態を持つ | 現在の姿として保持 |
| `room_booking_claims` | 仮押さえ成立 | 更新しない | 取消または期限切れで削除 | 現在の占有だけ保持 |
| `tentative_hold_deadlines` | 仮押さえ成立 | 更新しない | 確定、取消、期限切れで削除 | 現在の期限だけ保持 |
| `reservation_base_events` | 各業務イベントの成立 | 更新しない | 終了しない | version順に保持 |
| 4つの詳細イベント | 対応する業務イベントの成立 | 更新しない | 終了しない | 基底イベントと同じ期間保持 |

## 並行実行で必要な保証

| 競合 | 成立させる結果 | 防ぐ結果 |
|---|---|---|
| 同じ利用枠への二つの仮押さえ | 一方の予約、占有、期限、version 1イベントだけが成立する | 二つの占有と二組のイベントが残る |
| 確定と期限切れ | 一方だけが予約のversion 2になる | 同じ予約へversion 2が二つ積まれる |
| 取消と別予約者の仮押さえ | 取消の成立後なら別予約者が占有を得る | 古い占有と新しい占有が重なる |
| 予約者本人の取消と第三者による取消 | 予約者本人による取消だけが予約の次versionになる | 第三者の行為で状態やイベントが変わる |

## 論理設計の完了条件

- リソース系3テーブルとイベント系5テーブルを区別した
- 予約の`current_version`と基底イベントの`version`を対応させた
- イベントの発生日時を`occurred_at`、リソースの成立日時を`created_at`で表した
- すべてのカラムをNOT NULLとし、イベント種別ごとの違いをNULLで隠していない
- BDD-001からBDD-010で作成、更新、削除、時間境界、権限、拒否、同時進行を確かめた

## 未決

- 基底イベントと詳細イベントの保持期間は、予約業務責任者と法務が決める
- 期限管理を行為者としてどの業務コードで表すか

## BDD

以下のBDDは互いに独立している。前のBDDの結果は引き継がず、8テーブルすべてをBeforeとAfterへ記載する。0件のテーブルも全カラムの見出しと区切り行に続けて、全セルへ`&nbsp;`を1つずつ置いた表示上空白のデータ行を1行だけ置き、各表の直後を`<br>`で1行空ける。変化しないテーブルも全行を再掲する。

### Scenario BDD-001: 空き枠を仮押さえする

```gherkin
Given: 顧客C-4102は予約可能顧客である
  And: 会議室M-301の2026年9月18日 10:00から11:30までの利用枠には予約枠占有がない
  And: 現在日時は2026年9月1日 09:00である
When: C-4102が会議室M-301の2026年9月18日 10:00から11:30までを仮押さえする
Then: 予約R-20260901-0101が会議室M-301の2026年9月18日 10:00から11:30までの仮押さえ予約として成立する
  And: 予約の現在versionと基底イベントのversionは1で一致する
  And: 仮押さえ成立イベントに成立時点の予約内容が残る
```

#### Before / After

Before:

**`reservations`**

| 予約番号 | 拠点 | 会議室 | 予約者 | 利用開始 | 利用終了 | 状態 | 現在version | 作成日時 | 最終更新日時 |
|---|---|---|---|---|---|---|---:|---|---|
| &nbsp; | &nbsp; | &nbsp; | &nbsp; | &nbsp; | &nbsp; | &nbsp; | &nbsp; | &nbsp; | &nbsp; |

<br>

**`room_booking_claims`**

| 予約番号 | 会議室 | 利用開始 | 利用終了 | 作成日時 |
|---|---|---|---|---|
| &nbsp; | &nbsp; | &nbsp; | &nbsp; | &nbsp; |

<br>

**`tentative_hold_deadlines`**

| 予約番号 | 期限 | 作成日時 |
|---|---|---|
| &nbsp; | &nbsp; | &nbsp; |

<br>

**`reservation_base_events`**

| 基底イベント番号 | 予約番号 | 種別 | version | 行為者 | 発生日時 |
|---|---|---|---:|---|---|
| &nbsp; | &nbsp; | &nbsp; | &nbsp; | &nbsp; | &nbsp; |

<br>

**`reservation_tentative_created_events`**

| 詳細番号 | 基底イベント番号 | 拠点 | 会議室 | 予約者 | 利用開始 | 利用終了 | 期限 |
|---|---|---|---|---|---|---|---|
| &nbsp; | &nbsp; | &nbsp; | &nbsp; | &nbsp; | &nbsp; | &nbsp; | &nbsp; |

<br>

**`reservation_confirmed_events`**

| 詳細番号 | 基底イベント番号 |
|---|---|
| &nbsp; | &nbsp; |

<br>

**`reservation_cancelled_events`**

| 詳細番号 | 基底イベント番号 |
|---|---|
| &nbsp; | &nbsp; |

<br>

**`reservation_expired_events`**

| 詳細番号 | 基底イベント番号 |
|---|---|
| &nbsp; | &nbsp; |

<br>

After:

**`reservations`**

| 予約番号 | 拠点 | 会議室 | 予約者 | 利用開始 | 利用終了 | 状態 | 現在version | 作成日時 | 最終更新日時 |
|---|---|---|---|---|---|---|---:|---|---|
| **R-20260901-0101** | **丸の内** | **M-301** | **C-4102** | **2026年9月18日 10:00** | **2026年9月18日 11:30** | **tentative** | **1** | **2026年9月1日 09:00** | **2026年9月1日 09:00** |

<br>

**`room_booking_claims`**

| 予約番号 | 会議室 | 利用開始 | 利用終了 | 作成日時 |
|---|---|---|---|---|
| **R-20260901-0101** | **M-301** | **2026年9月18日 10:00** | **2026年9月18日 11:30** | **2026年9月1日 09:00** |

<br>

**`tentative_hold_deadlines`**

| 予約番号 | 期限 | 作成日時 |
|---|---|---|
| **R-20260901-0101** | **2026年9月1日 09:15** | **2026年9月1日 09:00** |

<br>

**`reservation_base_events`**

| 基底イベント番号 | 予約番号 | 種別 | version | 行為者 | 発生日時 |
|---|---|---|---:|---|---|
| **BE-0101-01** | **R-20260901-0101** | **tentative_created** | **1** | **C-4102** | **2026年9月1日 09:00** |

<br>

**`reservation_tentative_created_events`**

| 詳細番号 | 基底イベント番号 | 拠点 | 会議室 | 予約者 | 利用開始 | 利用終了 | 期限 |
|---|---|---|---|---|---|---|---|
| **TE-0101-01** | **BE-0101-01** | **丸の内** | **M-301** | **C-4102** | **2026年9月18日 10:00** | **2026年9月18日 11:30** | **2026年9月1日 09:15** |

<br>

**`reservation_confirmed_events`**

| 詳細番号 | 基底イベント番号 |
|---|---|
| &nbsp; | &nbsp; |

<br>

**`reservation_cancelled_events`**

| 詳細番号 | 基底イベント番号 |
|---|---|
| &nbsp; | &nbsp; |

<br>

**`reservation_expired_events`**

| 詳細番号 | 基底イベント番号 |
|---|---|
| &nbsp; | &nbsp; |

<br>

### Scenario BDD-002: 仮押さえ期限と同時刻の確定を期限切れとして記録する

```gherkin
Given: 予約R-20260901-0101は現在version 1の仮押さえ予約である
  And: 利用枠は会議室M-301の2026年9月18日 10:00から11:30までである
  And: 仮押さえ期限は2026年9月1日 09:15である
  And: 予約を確定したイベントはない
When: 予約者C-4102が2026年9月1日 09:15に予約を確定する
Then: 予約は現在version 2の期限切れ予約になる
  And: 予約枠占有と仮押さえ期限は削除される
  And: 予約確定イベントではなく予約期限切れイベントが追加される
```

#### Before / After

Before:

**`reservations`**

| 予約番号 | 拠点 | 会議室 | 予約者 | 利用開始 | 利用終了 | 状態 | 現在version | 作成日時 | 最終更新日時 |
|---|---|---|---|---|---|---|---:|---|---|
| R-20260901-0101 | 丸の内 | M-301 | C-4102 | 2026年9月18日 10:00 | 2026年9月18日 11:30 | tentative | 1 | 2026年9月1日 09:00 | 2026年9月1日 09:00 |

<br>

**`room_booking_claims`**

| 予約番号 | 会議室 | 利用開始 | 利用終了 | 作成日時 |
|---|---|---|---|---|
| R-20260901-0101 | M-301 | 2026年9月18日 10:00 | 2026年9月18日 11:30 | 2026年9月1日 09:00 |

<br>

**`tentative_hold_deadlines`**

| 予約番号 | 期限 | 作成日時 |
|---|---|---|
| R-20260901-0101 | 2026年9月1日 09:15 | 2026年9月1日 09:00 |

<br>

**`reservation_base_events`**

| 基底イベント番号 | 予約番号 | 種別 | version | 行為者 | 発生日時 |
|---|---|---|---:|---|---|
| BE-0101-01 | R-20260901-0101 | tentative_created | 1 | C-4102 | 2026年9月1日 09:00 |

<br>

**`reservation_tentative_created_events`**

| 詳細番号 | 基底イベント番号 | 拠点 | 会議室 | 予約者 | 利用開始 | 利用終了 | 期限 |
|---|---|---|---|---|---|---|---|
| TE-0101-01 | BE-0101-01 | 丸の内 | M-301 | C-4102 | 2026年9月18日 10:00 | 2026年9月18日 11:30 | 2026年9月1日 09:15 |

<br>

**`reservation_confirmed_events`**

| 詳細番号 | 基底イベント番号 |
|---|---|
| &nbsp; | &nbsp; |

<br>

**`reservation_cancelled_events`**

| 詳細番号 | 基底イベント番号 |
|---|---|
| &nbsp; | &nbsp; |

<br>

**`reservation_expired_events`**

| 詳細番号 | 基底イベント番号 |
|---|---|
| &nbsp; | &nbsp; |

<br>

After:

**`reservations`**

| 予約番号 | 拠点 | 会議室 | 予約者 | 利用開始 | 利用終了 | 状態 | 現在version | 作成日時 | 最終更新日時 |
|---|---|---|---|---|---|---|---:|---|---|
| R-20260901-0101 | 丸の内 | M-301 | C-4102 | 2026年9月18日 10:00 | 2026年9月18日 11:30 | **expired** | **2** | 2026年9月1日 09:00 | **2026年9月1日 09:15** |

<br>

**`room_booking_claims`**

| 予約番号 | 会議室 | 利用開始 | 利用終了 | 作成日時 |
|---|---|---|---|---|
| &nbsp; | &nbsp; | &nbsp; | &nbsp; | &nbsp; |

<br>

**`tentative_hold_deadlines`**

| 予約番号 | 期限 | 作成日時 |
|---|---|---|
| &nbsp; | &nbsp; | &nbsp; |

<br>

**`reservation_base_events`**

| 基底イベント番号 | 予約番号 | 種別 | version | 行為者 | 発生日時 |
|---|---|---|---:|---|---|
| BE-0101-01 | R-20260901-0101 | tentative_created | 1 | C-4102 | 2026年9月1日 09:00 |
| **BE-0101-02** | **R-20260901-0101** | **expired** | **2** | **期限管理** | **2026年9月1日 09:15** |

<br>

**`reservation_tentative_created_events`**

| 詳細番号 | 基底イベント番号 | 拠点 | 会議室 | 予約者 | 利用開始 | 利用終了 | 期限 |
|---|---|---|---|---|---|---|---|
| TE-0101-01 | BE-0101-01 | 丸の内 | M-301 | C-4102 | 2026年9月18日 10:00 | 2026年9月18日 11:30 | 2026年9月1日 09:15 |

<br>

**`reservation_confirmed_events`**

| 詳細番号 | 基底イベント番号 |
|---|---|
| &nbsp; | &nbsp; |

<br>

**`reservation_cancelled_events`**

| 詳細番号 | 基底イベント番号 |
|---|---|
| &nbsp; | &nbsp; |

<br>

**`reservation_expired_events`**

| 詳細番号 | 基底イベント番号 |
|---|---|
| **EE-0101-02** | **BE-0101-02** |

<br>

### Scenario BDD-003: 仮押さえ予約を確定する

```gherkin
Given: 予約R-20260901-0101は現在version 1の仮押さえ予約である
  And: 利用枠は会議室M-301の2026年9月18日 10:00から11:30までである
  And: version 1の仮押さえ成立イベントと仮押さえ期限がある
  And: 現在日時は期限前の2026年9月1日 09:05である
When: 予約者C-4102が予約を確定する
Then: 予約は現在version 2の確定予約になる
  And: 確定予約の利用枠は会議室M-301の2026年9月18日 10:00から11:30までのままである
  And: 仮押さえ期限は削除される
  And: version 2の基底イベントと予約確定イベントが追加される
```

#### Before / After

Before:

**`reservations`**

| 予約番号 | 拠点 | 会議室 | 予約者 | 利用開始 | 利用終了 | 状態 | 現在version | 作成日時 | 最終更新日時 |
|---|---|---|---|---|---|---|---:|---|---|
| R-20260901-0101 | 丸の内 | M-301 | C-4102 | 2026年9月18日 10:00 | 2026年9月18日 11:30 | tentative | 1 | 2026年9月1日 09:00 | 2026年9月1日 09:00 |

<br>

**`room_booking_claims`**

| 予約番号 | 会議室 | 利用開始 | 利用終了 | 作成日時 |
|---|---|---|---|---|
| R-20260901-0101 | M-301 | 2026年9月18日 10:00 | 2026年9月18日 11:30 | 2026年9月1日 09:00 |

<br>

**`tentative_hold_deadlines`**

| 予約番号 | 期限 | 作成日時 |
|---|---|---|
| R-20260901-0101 | 2026年9月1日 09:15 | 2026年9月1日 09:00 |

<br>

**`reservation_base_events`**

| 基底イベント番号 | 予約番号 | 種別 | version | 行為者 | 発生日時 |
|---|---|---|---:|---|---|
| BE-0101-01 | R-20260901-0101 | tentative_created | 1 | C-4102 | 2026年9月1日 09:00 |

<br>

**`reservation_tentative_created_events`**

| 詳細番号 | 基底イベント番号 | 拠点 | 会議室 | 予約者 | 利用開始 | 利用終了 | 期限 |
|---|---|---|---|---|---|---|---|
| TE-0101-01 | BE-0101-01 | 丸の内 | M-301 | C-4102 | 2026年9月18日 10:00 | 2026年9月18日 11:30 | 2026年9月1日 09:15 |

<br>

**`reservation_confirmed_events`**

| 詳細番号 | 基底イベント番号 |
|---|---|
| &nbsp; | &nbsp; |

<br>

**`reservation_cancelled_events`**

| 詳細番号 | 基底イベント番号 |
|---|---|
| &nbsp; | &nbsp; |

<br>

**`reservation_expired_events`**

| 詳細番号 | 基底イベント番号 |
|---|---|
| &nbsp; | &nbsp; |

<br>

After:

**`reservations`**

| 予約番号 | 拠点 | 会議室 | 予約者 | 利用開始 | 利用終了 | 状態 | 現在version | 作成日時 | 最終更新日時 |
|---|---|---|---|---|---|---|---:|---|---|
| R-20260901-0101 | 丸の内 | M-301 | C-4102 | 2026年9月18日 10:00 | 2026年9月18日 11:30 | **confirmed** | **2** | 2026年9月1日 09:00 | **2026年9月1日 09:05** |

<br>

**`room_booking_claims`**

| 予約番号 | 会議室 | 利用開始 | 利用終了 | 作成日時 |
|---|---|---|---|---|
| R-20260901-0101 | M-301 | 2026年9月18日 10:00 | 2026年9月18日 11:30 | 2026年9月1日 09:00 |

<br>

**`tentative_hold_deadlines`**

| 予約番号 | 期限 | 作成日時 |
|---|---|---|
| &nbsp; | &nbsp; | &nbsp; |

<br>

**`reservation_base_events`**

| 基底イベント番号 | 予約番号 | 種別 | version | 行為者 | 発生日時 |
|---|---|---|---:|---|---|
| BE-0101-01 | R-20260901-0101 | tentative_created | 1 | C-4102 | 2026年9月1日 09:00 |
| **BE-0101-02** | **R-20260901-0101** | **confirmed** | **2** | **C-4102** | **2026年9月1日 09:05** |

<br>

**`reservation_tentative_created_events`**

| 詳細番号 | 基底イベント番号 | 拠点 | 会議室 | 予約者 | 利用開始 | 利用終了 | 期限 |
|---|---|---|---|---|---|---|---|
| TE-0101-01 | BE-0101-01 | 丸の内 | M-301 | C-4102 | 2026年9月18日 10:00 | 2026年9月18日 11:30 | 2026年9月1日 09:15 |

<br>

**`reservation_confirmed_events`**

| 詳細番号 | 基底イベント番号 |
|---|---|
| **CE-0101-02** | **BE-0101-02** |

<br>

**`reservation_cancelled_events`**

| 詳細番号 | 基底イベント番号 |
|---|---|
| &nbsp; | &nbsp; |

<br>

**`reservation_expired_events`**

| 詳細番号 | 基底イベント番号 |
|---|---|
| &nbsp; | &nbsp; |

<br>

### Scenario BDD-004: 確定予約を取り消す

```gherkin
Given: 予約R-20260901-0101は現在version 2の確定予約である
  And: 利用枠は会議室M-301の2026年9月18日 10:00から11:30までである
  And: version 1の仮押さえ成立イベントとversion 2の予約確定イベントがある
  And: 現在日時は利用開始前である
When: 予約者C-4102が自分の予約を取り消す
Then: 予約は現在version 3の取消済み予約になる
  And: 予約枠占有は削除される
  And: version 3の基底イベントと予約取消イベントが追加される
```

#### Before / After

Before:

**`reservations`**

| 予約番号 | 拠点 | 会議室 | 予約者 | 利用開始 | 利用終了 | 状態 | 現在version | 作成日時 | 最終更新日時 |
|---|---|---|---|---|---|---|---:|---|---|
| R-20260901-0101 | 丸の内 | M-301 | C-4102 | 2026年9月18日 10:00 | 2026年9月18日 11:30 | confirmed | 2 | 2026年9月1日 09:00 | 2026年9月1日 09:05 |

<br>

**`room_booking_claims`**

| 予約番号 | 会議室 | 利用開始 | 利用終了 | 作成日時 |
|---|---|---|---|---|
| R-20260901-0101 | M-301 | 2026年9月18日 10:00 | 2026年9月18日 11:30 | 2026年9月1日 09:00 |

<br>

**`tentative_hold_deadlines`**

| 予約番号 | 期限 | 作成日時 |
|---|---|---|
| &nbsp; | &nbsp; | &nbsp; |

<br>

**`reservation_base_events`**

| 基底イベント番号 | 予約番号 | 種別 | version | 行為者 | 発生日時 |
|---|---|---|---:|---|---|
| BE-0101-01 | R-20260901-0101 | tentative_created | 1 | C-4102 | 2026年9月1日 09:00 |
| BE-0101-02 | R-20260901-0101 | confirmed | 2 | C-4102 | 2026年9月1日 09:05 |

<br>

**`reservation_tentative_created_events`**

| 詳細番号 | 基底イベント番号 | 拠点 | 会議室 | 予約者 | 利用開始 | 利用終了 | 期限 |
|---|---|---|---|---|---|---|---|
| TE-0101-01 | BE-0101-01 | 丸の内 | M-301 | C-4102 | 2026年9月18日 10:00 | 2026年9月18日 11:30 | 2026年9月1日 09:15 |

<br>

**`reservation_confirmed_events`**

| 詳細番号 | 基底イベント番号 |
|---|---|
| CE-0101-02 | BE-0101-02 |

<br>

**`reservation_cancelled_events`**

| 詳細番号 | 基底イベント番号 |
|---|---|
| &nbsp; | &nbsp; |

<br>

**`reservation_expired_events`**

| 詳細番号 | 基底イベント番号 |
|---|---|
| &nbsp; | &nbsp; |

<br>

After:

**`reservations`**

| 予約番号 | 拠点 | 会議室 | 予約者 | 利用開始 | 利用終了 | 状態 | 現在version | 作成日時 | 最終更新日時 |
|---|---|---|---|---|---|---|---:|---|---|
| R-20260901-0101 | 丸の内 | M-301 | C-4102 | 2026年9月18日 10:00 | 2026年9月18日 11:30 | **cancelled** | **3** | 2026年9月1日 09:00 | **2026年9月10日 14:20** |

<br>

**`room_booking_claims`**

| 予約番号 | 会議室 | 利用開始 | 利用終了 | 作成日時 |
|---|---|---|---|---|
| &nbsp; | &nbsp; | &nbsp; | &nbsp; | &nbsp; |

<br>

**`tentative_hold_deadlines`**

| 予約番号 | 期限 | 作成日時 |
|---|---|---|
| &nbsp; | &nbsp; | &nbsp; |

<br>

**`reservation_base_events`**

| 基底イベント番号 | 予約番号 | 種別 | version | 行為者 | 発生日時 |
|---|---|---|---:|---|---|
| BE-0101-01 | R-20260901-0101 | tentative_created | 1 | C-4102 | 2026年9月1日 09:00 |
| BE-0101-02 | R-20260901-0101 | confirmed | 2 | C-4102 | 2026年9月1日 09:05 |
| **BE-0101-03** | **R-20260901-0101** | **cancelled** | **3** | **C-4102** | **2026年9月10日 14:20** |

<br>

**`reservation_tentative_created_events`**

| 詳細番号 | 基底イベント番号 | 拠点 | 会議室 | 予約者 | 利用開始 | 利用終了 | 期限 |
|---|---|---|---|---|---|---|---|
| TE-0101-01 | BE-0101-01 | 丸の内 | M-301 | C-4102 | 2026年9月18日 10:00 | 2026年9月18日 11:30 | 2026年9月1日 09:15 |

<br>

**`reservation_confirmed_events`**

| 詳細番号 | 基底イベント番号 |
|---|---|
| CE-0101-02 | BE-0101-02 |

<br>

**`reservation_cancelled_events`**

| 詳細番号 | 基底イベント番号 |
|---|---|
| **CAE-0101-03** | **BE-0101-03** |

<br>

**`reservation_expired_events`**

| 詳細番号 | 基底イベント番号 |
|---|---|
| &nbsp; | &nbsp; |

<br>

### Scenario BDD-005: 同じ空き時間への同時仮押さえは一方だけ成立する

```gherkin
Given: 顧客C-4102と顧客C-5821は予約可能顧客である
  And: 会議室M-301の2026年9月18日 10:00から11:30までの利用枠には予約枠占有がない
When: 二人が会議室M-301の2026年9月18日 10:00から11:30までを同時に仮押さえする
Then: 先に成立した一方だけが現在version 1の仮押さえ予約になる
  And: 成立した予約のリソース系3行とイベント系2行だけが追加される
  And: もう一方に属する行は8テーブルのどこにも作られない
```

#### Before / After

Before:

**`reservations`**

| 予約番号 | 拠点 | 会議室 | 予約者 | 利用開始 | 利用終了 | 状態 | 現在version | 作成日時 | 最終更新日時 |
|---|---|---|---|---|---|---|---:|---|---|
| &nbsp; | &nbsp; | &nbsp; | &nbsp; | &nbsp; | &nbsp; | &nbsp; | &nbsp; | &nbsp; | &nbsp; |

<br>

**`room_booking_claims`**

| 予約番号 | 会議室 | 利用開始 | 利用終了 | 作成日時 |
|---|---|---|---|---|
| &nbsp; | &nbsp; | &nbsp; | &nbsp; | &nbsp; |

<br>

**`tentative_hold_deadlines`**

| 予約番号 | 期限 | 作成日時 |
|---|---|---|
| &nbsp; | &nbsp; | &nbsp; |

<br>

**`reservation_base_events`**

| 基底イベント番号 | 予約番号 | 種別 | version | 行為者 | 発生日時 |
|---|---|---|---:|---|---|
| &nbsp; | &nbsp; | &nbsp; | &nbsp; | &nbsp; | &nbsp; |

<br>

**`reservation_tentative_created_events`**

| 詳細番号 | 基底イベント番号 | 拠点 | 会議室 | 予約者 | 利用開始 | 利用終了 | 期限 |
|---|---|---|---|---|---|---|---|
| &nbsp; | &nbsp; | &nbsp; | &nbsp; | &nbsp; | &nbsp; | &nbsp; | &nbsp; |

<br>

**`reservation_confirmed_events`**

| 詳細番号 | 基底イベント番号 |
|---|---|
| &nbsp; | &nbsp; |

<br>

**`reservation_cancelled_events`**

| 詳細番号 | 基底イベント番号 |
|---|---|
| &nbsp; | &nbsp; |

<br>

**`reservation_expired_events`**

| 詳細番号 | 基底イベント番号 |
|---|---|
| &nbsp; | &nbsp; |

<br>

After（C-4102の操作が先に成立した場合）:

**`reservations`**

| 予約番号 | 拠点 | 会議室 | 予約者 | 利用開始 | 利用終了 | 状態 | 現在version | 作成日時 | 最終更新日時 |
|---|---|---|---|---|---|---|---:|---|---|
| **R-20260901-0101** | **丸の内** | **M-301** | **C-4102** | **2026年9月18日 10:00** | **2026年9月18日 11:30** | **tentative** | **1** | **2026年9月1日 09:00** | **2026年9月1日 09:00** |

<br>

**`room_booking_claims`**

| 予約番号 | 会議室 | 利用開始 | 利用終了 | 作成日時 |
|---|---|---|---|---|
| **R-20260901-0101** | **M-301** | **2026年9月18日 10:00** | **2026年9月18日 11:30** | **2026年9月1日 09:00** |

<br>

**`tentative_hold_deadlines`**

| 予約番号 | 期限 | 作成日時 |
|---|---|---|
| **R-20260901-0101** | **2026年9月1日 09:15** | **2026年9月1日 09:00** |

<br>

**`reservation_base_events`**

| 基底イベント番号 | 予約番号 | 種別 | version | 行為者 | 発生日時 |
|---|---|---|---:|---|---|
| **BE-0101-01** | **R-20260901-0101** | **tentative_created** | **1** | **C-4102** | **2026年9月1日 09:00** |

<br>

**`reservation_tentative_created_events`**

| 詳細番号 | 基底イベント番号 | 拠点 | 会議室 | 予約者 | 利用開始 | 利用終了 | 期限 |
|---|---|---|---|---|---|---|---|
| **TE-0101-01** | **BE-0101-01** | **丸の内** | **M-301** | **C-4102** | **2026年9月18日 10:00** | **2026年9月18日 11:30** | **2026年9月1日 09:15** |

<br>

**`reservation_confirmed_events`**

| 詳細番号 | 基底イベント番号 |
|---|---|
| &nbsp; | &nbsp; |

<br>

**`reservation_cancelled_events`**

| 詳細番号 | 基底イベント番号 |
|---|---|
| &nbsp; | &nbsp; |

<br>

**`reservation_expired_events`**

| 詳細番号 | 基底イベント番号 |
|---|---|
| &nbsp; | &nbsp; |

<br>

C-5821に属する予約、占有、期限、基底イベント、詳細イベントは、8テーブルのどこにも存在しない。

### Scenario BDD-006: 仮押さえ予約を取り消す

```gherkin
Given: 予約R-20260901-0101は現在version 1の仮押さえ予約である
  And: 利用枠は会議室M-301の2026年9月18日 10:00から11:30までである
  And: version 1の仮押さえ成立イベントと仮押さえ期限がある
  And: 現在日時は利用開始前の2026年9月1日 09:05である
When: 予約者C-4102が自分の予約を取り消す
Then: 予約は現在version 2の取消済み予約になる
  And: 予約枠占有と仮押さえ期限は削除される
  And: version 2の基底イベントと予約取消イベントが追加される
```

#### Before / After

Before:

**`reservations`**

| 予約番号 | 拠点 | 会議室 | 予約者 | 利用開始 | 利用終了 | 状態 | 現在version | 作成日時 | 最終更新日時 |
|---|---|---|---|---|---|---|---:|---|---|
| R-20260901-0101 | 丸の内 | M-301 | C-4102 | 2026年9月18日 10:00 | 2026年9月18日 11:30 | tentative | 1 | 2026年9月1日 09:00 | 2026年9月1日 09:00 |

<br>

**`room_booking_claims`**

| 予約番号 | 会議室 | 利用開始 | 利用終了 | 作成日時 |
|---|---|---|---|---|
| R-20260901-0101 | M-301 | 2026年9月18日 10:00 | 2026年9月18日 11:30 | 2026年9月1日 09:00 |

<br>

**`tentative_hold_deadlines`**

| 予約番号 | 期限 | 作成日時 |
|---|---|---|
| R-20260901-0101 | 2026年9月1日 09:15 | 2026年9月1日 09:00 |

<br>

**`reservation_base_events`**

| 基底イベント番号 | 予約番号 | 種別 | version | 行為者 | 発生日時 |
|---|---|---|---:|---|---|
| BE-0101-01 | R-20260901-0101 | tentative_created | 1 | C-4102 | 2026年9月1日 09:00 |

<br>

**`reservation_tentative_created_events`**

| 詳細番号 | 基底イベント番号 | 拠点 | 会議室 | 予約者 | 利用開始 | 利用終了 | 期限 |
|---|---|---|---|---|---|---|---|
| TE-0101-01 | BE-0101-01 | 丸の内 | M-301 | C-4102 | 2026年9月18日 10:00 | 2026年9月18日 11:30 | 2026年9月1日 09:15 |

<br>

**`reservation_confirmed_events`**

| 詳細番号 | 基底イベント番号 |
|---|---|
| &nbsp; | &nbsp; |

<br>

**`reservation_cancelled_events`**

| 詳細番号 | 基底イベント番号 |
|---|---|
| &nbsp; | &nbsp; |

<br>

**`reservation_expired_events`**

| 詳細番号 | 基底イベント番号 |
|---|---|
| &nbsp; | &nbsp; |

<br>

After:

**`reservations`**

| 予約番号 | 拠点 | 会議室 | 予約者 | 利用開始 | 利用終了 | 状態 | 現在version | 作成日時 | 最終更新日時 |
|---|---|---|---|---|---|---|---:|---|---|
| R-20260901-0101 | 丸の内 | M-301 | C-4102 | 2026年9月18日 10:00 | 2026年9月18日 11:30 | **cancelled** | **2** | 2026年9月1日 09:00 | **2026年9月1日 09:05** |

<br>

**`room_booking_claims`**

| 予約番号 | 会議室 | 利用開始 | 利用終了 | 作成日時 |
|---|---|---|---|---|
| &nbsp; | &nbsp; | &nbsp; | &nbsp; | &nbsp; |

<br>

**`tentative_hold_deadlines`**

| 予約番号 | 期限 | 作成日時 |
|---|---|---|
| &nbsp; | &nbsp; | &nbsp; |

<br>

**`reservation_base_events`**

| 基底イベント番号 | 予約番号 | 種別 | version | 行為者 | 発生日時 |
|---|---|---|---:|---|---|
| BE-0101-01 | R-20260901-0101 | tentative_created | 1 | C-4102 | 2026年9月1日 09:00 |
| **BE-0101-02** | **R-20260901-0101** | **cancelled** | **2** | **C-4102** | **2026年9月1日 09:05** |

<br>

**`reservation_tentative_created_events`**

| 詳細番号 | 基底イベント番号 | 拠点 | 会議室 | 予約者 | 利用開始 | 利用終了 | 期限 |
|---|---|---|---|---|---|---|---|
| TE-0101-01 | BE-0101-01 | 丸の内 | M-301 | C-4102 | 2026年9月18日 10:00 | 2026年9月18日 11:30 | 2026年9月1日 09:15 |

<br>

**`reservation_confirmed_events`**

| 詳細番号 | 基底イベント番号 |
|---|---|
| &nbsp; | &nbsp; |

<br>

**`reservation_cancelled_events`**

| 詳細番号 | 基底イベント番号 |
|---|---|
| **CAE-0101-02** | **BE-0101-02** |

<br>

**`reservation_expired_events`**

| 詳細番号 | 基底イベント番号 |
|---|---|
| &nbsp; | &nbsp; |

<br>

### Scenario BDD-007: 第三者による確定予約の取消を拒む

```gherkin
Given: 顧客C-4102の確定予約R-20260901-0101がある
  And: 利用枠は会議室M-301の2026年9月18日 10:00から11:30までである
  And: 現在日時は利用開始前の2026年9月10日 14:20である
  And: 顧客C-5821はR-20260901-0101の予約者ではない
When: C-5821がR-20260901-0101を取り消す
Then: R-20260901-0101は現在version 2の確定予約のままである
  And: 予約枠占有と成立済みイベントは変わらない
  And: 予約取消イベントは追加されない
```

#### Before / After

Before:

**`reservations`**

| 予約番号 | 拠点 | 会議室 | 予約者 | 利用開始 | 利用終了 | 状態 | 現在version | 作成日時 | 最終更新日時 |
|---|---|---|---|---|---|---|---:|---|---|
| R-20260901-0101 | 丸の内 | M-301 | C-4102 | 2026年9月18日 10:00 | 2026年9月18日 11:30 | confirmed | 2 | 2026年9月1日 09:00 | 2026年9月1日 09:05 |

<br>

**`room_booking_claims`**

| 予約番号 | 会議室 | 利用開始 | 利用終了 | 作成日時 |
|---|---|---|---|---|
| R-20260901-0101 | M-301 | 2026年9月18日 10:00 | 2026年9月18日 11:30 | 2026年9月1日 09:00 |

<br>

**`tentative_hold_deadlines`**

| 予約番号 | 期限 | 作成日時 |
|---|---|---|
| &nbsp; | &nbsp; | &nbsp; |

<br>

**`reservation_base_events`**

| 基底イベント番号 | 予約番号 | 種別 | version | 行為者 | 発生日時 |
|---|---|---|---:|---|---|
| BE-0101-01 | R-20260901-0101 | tentative_created | 1 | C-4102 | 2026年9月1日 09:00 |
| BE-0101-02 | R-20260901-0101 | confirmed | 2 | C-4102 | 2026年9月1日 09:05 |

<br>

**`reservation_tentative_created_events`**

| 詳細番号 | 基底イベント番号 | 拠点 | 会議室 | 予約者 | 利用開始 | 利用終了 | 期限 |
|---|---|---|---|---|---|---|---|
| TE-0101-01 | BE-0101-01 | 丸の内 | M-301 | C-4102 | 2026年9月18日 10:00 | 2026年9月18日 11:30 | 2026年9月1日 09:15 |

<br>

**`reservation_confirmed_events`**

| 詳細番号 | 基底イベント番号 |
|---|---|
| CE-0101-02 | BE-0101-02 |

<br>

**`reservation_cancelled_events`**

| 詳細番号 | 基底イベント番号 |
|---|---|
| &nbsp; | &nbsp; |

<br>

**`reservation_expired_events`**

| 詳細番号 | 基底イベント番号 |
|---|---|
| &nbsp; | &nbsp; |

<br>

After:

**`reservations`**

| 予約番号 | 拠点 | 会議室 | 予約者 | 利用開始 | 利用終了 | 状態 | 現在version | 作成日時 | 最終更新日時 |
|---|---|---|---|---|---|---|---:|---|---|
| R-20260901-0101 | 丸の内 | M-301 | C-4102 | 2026年9月18日 10:00 | 2026年9月18日 11:30 | confirmed | 2 | 2026年9月1日 09:00 | 2026年9月1日 09:05 |

<br>

**`room_booking_claims`**

| 予約番号 | 会議室 | 利用開始 | 利用終了 | 作成日時 |
|---|---|---|---|---|
| R-20260901-0101 | M-301 | 2026年9月18日 10:00 | 2026年9月18日 11:30 | 2026年9月1日 09:00 |

<br>

**`tentative_hold_deadlines`**

| 予約番号 | 期限 | 作成日時 |
|---|---|---|
| &nbsp; | &nbsp; | &nbsp; |

<br>

**`reservation_base_events`**

| 基底イベント番号 | 予約番号 | 種別 | version | 行為者 | 発生日時 |
|---|---|---|---:|---|---|
| BE-0101-01 | R-20260901-0101 | tentative_created | 1 | C-4102 | 2026年9月1日 09:00 |
| BE-0101-02 | R-20260901-0101 | confirmed | 2 | C-4102 | 2026年9月1日 09:05 |

<br>

**`reservation_tentative_created_events`**

| 詳細番号 | 基底イベント番号 | 拠点 | 会議室 | 予約者 | 利用開始 | 利用終了 | 期限 |
|---|---|---|---|---|---|---|---|
| TE-0101-01 | BE-0101-01 | 丸の内 | M-301 | C-4102 | 2026年9月18日 10:00 | 2026年9月18日 11:30 | 2026年9月1日 09:15 |

<br>

**`reservation_confirmed_events`**

| 詳細番号 | 基底イベント番号 |
|---|---|
| CE-0101-02 | BE-0101-02 |

<br>

**`reservation_cancelled_events`**

| 詳細番号 | 基底イベント番号 |
|---|---|
| &nbsp; | &nbsp; |

<br>

**`reservation_expired_events`**

| 詳細番号 | 基底イベント番号 |
|---|---|
| &nbsp; | &nbsp; |

<br>

### Scenario BDD-008: 確定予約に隣接する利用枠を仮押さえする

```gherkin
Given: 顧客C-4102の確定予約R-20260901-0101がある
  And: 予約は会議室M-301の2026年9月18日 10:00から11:00までを占有している
  And: 顧客C-5821は予約可能顧客である
When: C-5821が同じ会議室の2026年9月18日 11:00から12:00までを仮押さえする
Then: 予約R-20260901-0201が会議室M-301の2026年9月18日 11:00から12:00までの仮押さえ予約として成立する
  And: 二つの予約枠占有は境界で接するだけで重ならない
  And: R-20260901-0201のversion 1イベントと仮押さえ期限が追加される
```

#### Before / After

Before:

**`reservations`**

| 予約番号 | 拠点 | 会議室 | 予約者 | 利用開始 | 利用終了 | 状態 | 現在version | 作成日時 | 最終更新日時 |
|---|---|---|---|---|---|---|---:|---|---|
| R-20260901-0101 | 丸の内 | M-301 | C-4102 | 2026年9月18日 10:00 | 2026年9月18日 11:00 | confirmed | 2 | 2026年9月1日 09:00 | 2026年9月1日 09:05 |

<br>

**`room_booking_claims`**

| 予約番号 | 会議室 | 利用開始 | 利用終了 | 作成日時 |
|---|---|---|---|---|
| R-20260901-0101 | M-301 | 2026年9月18日 10:00 | 2026年9月18日 11:00 | 2026年9月1日 09:00 |

<br>

**`tentative_hold_deadlines`**

| 予約番号 | 期限 | 作成日時 |
|---|---|---|
| &nbsp; | &nbsp; | &nbsp; |

<br>

**`reservation_base_events`**

| 基底イベント番号 | 予約番号 | 種別 | version | 行為者 | 発生日時 |
|---|---|---|---:|---|---|
| BE-0101-01 | R-20260901-0101 | tentative_created | 1 | C-4102 | 2026年9月1日 09:00 |
| BE-0101-02 | R-20260901-0101 | confirmed | 2 | C-4102 | 2026年9月1日 09:05 |

<br>

**`reservation_tentative_created_events`**

| 詳細番号 | 基底イベント番号 | 拠点 | 会議室 | 予約者 | 利用開始 | 利用終了 | 期限 |
|---|---|---|---|---|---|---|---|
| TE-0101-01 | BE-0101-01 | 丸の内 | M-301 | C-4102 | 2026年9月18日 10:00 | 2026年9月18日 11:00 | 2026年9月1日 09:15 |

<br>

**`reservation_confirmed_events`**

| 詳細番号 | 基底イベント番号 |
|---|---|
| CE-0101-02 | BE-0101-02 |

<br>

**`reservation_cancelled_events`**

| 詳細番号 | 基底イベント番号 |
|---|---|
| &nbsp; | &nbsp; |

<br>

**`reservation_expired_events`**

| 詳細番号 | 基底イベント番号 |
|---|---|
| &nbsp; | &nbsp; |

<br>

After:

**`reservations`**

| 予約番号 | 拠点 | 会議室 | 予約者 | 利用開始 | 利用終了 | 状態 | 現在version | 作成日時 | 最終更新日時 |
|---|---|---|---|---|---|---|---:|---|---|
| R-20260901-0101 | 丸の内 | M-301 | C-4102 | 2026年9月18日 10:00 | 2026年9月18日 11:00 | confirmed | 2 | 2026年9月1日 09:00 | 2026年9月1日 09:05 |
| **R-20260901-0201** | **丸の内** | **M-301** | **C-5821** | **2026年9月18日 11:00** | **2026年9月18日 12:00** | **tentative** | **1** | **2026年9月1日 09:10** | **2026年9月1日 09:10** |

<br>

**`room_booking_claims`**

| 予約番号 | 会議室 | 利用開始 | 利用終了 | 作成日時 |
|---|---|---|---|---|
| R-20260901-0101 | M-301 | 2026年9月18日 10:00 | 2026年9月18日 11:00 | 2026年9月1日 09:00 |
| **R-20260901-0201** | **M-301** | **2026年9月18日 11:00** | **2026年9月18日 12:00** | **2026年9月1日 09:10** |

<br>

**`tentative_hold_deadlines`**

| 予約番号 | 期限 | 作成日時 |
|---|---|---|
| **R-20260901-0201** | **2026年9月1日 09:25** | **2026年9月1日 09:10** |

<br>

**`reservation_base_events`**

| 基底イベント番号 | 予約番号 | 種別 | version | 行為者 | 発生日時 |
|---|---|---|---:|---|---|
| BE-0101-01 | R-20260901-0101 | tentative_created | 1 | C-4102 | 2026年9月1日 09:00 |
| BE-0101-02 | R-20260901-0101 | confirmed | 2 | C-4102 | 2026年9月1日 09:05 |
| **BE-0201-01** | **R-20260901-0201** | **tentative_created** | **1** | **C-5821** | **2026年9月1日 09:10** |

<br>

**`reservation_tentative_created_events`**

| 詳細番号 | 基底イベント番号 | 拠点 | 会議室 | 予約者 | 利用開始 | 利用終了 | 期限 |
|---|---|---|---|---|---|---|---|
| TE-0101-01 | BE-0101-01 | 丸の内 | M-301 | C-4102 | 2026年9月18日 10:00 | 2026年9月18日 11:00 | 2026年9月1日 09:15 |
| **TE-0201-01** | **BE-0201-01** | **丸の内** | **M-301** | **C-5821** | **2026年9月18日 11:00** | **2026年9月18日 12:00** | **2026年9月1日 09:25** |

<br>

**`reservation_confirmed_events`**

| 詳細番号 | 基底イベント番号 |
|---|---|
| CE-0101-02 | BE-0101-02 |

<br>

**`reservation_cancelled_events`**

| 詳細番号 | 基底イベント番号 |
|---|---|
| &nbsp; | &nbsp; |

<br>

**`reservation_expired_events`**

| 詳細番号 | 基底イベント番号 |
|---|---|
| &nbsp; | &nbsp; |

<br>

### Scenario BDD-009: 未確定のまま仮押さえ期限が到来する

```gherkin
Given: 予約R-20260901-0101は現在version 1の仮押さえ予約である
  And: 利用枠は会議室M-301の2026年9月18日 10:00から11:30までである
  And: version 1の仮押さえ成立イベントと仮押さえ期限がある
  And: 予約を確定したイベントはない
When: 2026年9月1日 09:15に仮押さえ期限が到来する
Then: 予約は現在version 2の期限切れ予約になる
  And: 予約枠占有と仮押さえ期限は削除される
  And: version 2の基底イベントと予約期限切れイベントが追加される
```

#### Before / After

Before:

**`reservations`**

| 予約番号 | 拠点 | 会議室 | 予約者 | 利用開始 | 利用終了 | 状態 | 現在version | 作成日時 | 最終更新日時 |
|---|---|---|---|---|---|---|---:|---|---|
| R-20260901-0101 | 丸の内 | M-301 | C-4102 | 2026年9月18日 10:00 | 2026年9月18日 11:30 | tentative | 1 | 2026年9月1日 09:00 | 2026年9月1日 09:00 |

<br>

**`room_booking_claims`**

| 予約番号 | 会議室 | 利用開始 | 利用終了 | 作成日時 |
|---|---|---|---|---|
| R-20260901-0101 | M-301 | 2026年9月18日 10:00 | 2026年9月18日 11:30 | 2026年9月1日 09:00 |

<br>

**`tentative_hold_deadlines`**

| 予約番号 | 期限 | 作成日時 |
|---|---|---|
| R-20260901-0101 | 2026年9月1日 09:15 | 2026年9月1日 09:00 |

<br>

**`reservation_base_events`**

| 基底イベント番号 | 予約番号 | 種別 | version | 行為者 | 発生日時 |
|---|---|---|---:|---|---|
| BE-0101-01 | R-20260901-0101 | tentative_created | 1 | C-4102 | 2026年9月1日 09:00 |

<br>

**`reservation_tentative_created_events`**

| 詳細番号 | 基底イベント番号 | 拠点 | 会議室 | 予約者 | 利用開始 | 利用終了 | 期限 |
|---|---|---|---|---|---|---|---|
| TE-0101-01 | BE-0101-01 | 丸の内 | M-301 | C-4102 | 2026年9月18日 10:00 | 2026年9月18日 11:30 | 2026年9月1日 09:15 |

<br>

**`reservation_confirmed_events`**

| 詳細番号 | 基底イベント番号 |
|---|---|
| &nbsp; | &nbsp; |

<br>

**`reservation_cancelled_events`**

| 詳細番号 | 基底イベント番号 |
|---|---|
| &nbsp; | &nbsp; |

<br>

**`reservation_expired_events`**

| 詳細番号 | 基底イベント番号 |
|---|---|
| &nbsp; | &nbsp; |

<br>

After:

**`reservations`**

| 予約番号 | 拠点 | 会議室 | 予約者 | 利用開始 | 利用終了 | 状態 | 現在version | 作成日時 | 最終更新日時 |
|---|---|---|---|---|---|---|---:|---|---|
| R-20260901-0101 | 丸の内 | M-301 | C-4102 | 2026年9月18日 10:00 | 2026年9月18日 11:30 | **expired** | **2** | 2026年9月1日 09:00 | **2026年9月1日 09:15** |

<br>

**`room_booking_claims`**

| 予約番号 | 会議室 | 利用開始 | 利用終了 | 作成日時 |
|---|---|---|---|---|
| &nbsp; | &nbsp; | &nbsp; | &nbsp; | &nbsp; |

<br>

**`tentative_hold_deadlines`**

| 予約番号 | 期限 | 作成日時 |
|---|---|---|
| &nbsp; | &nbsp; | &nbsp; |

<br>

**`reservation_base_events`**

| 基底イベント番号 | 予約番号 | 種別 | version | 行為者 | 発生日時 |
|---|---|---|---:|---|---|
| BE-0101-01 | R-20260901-0101 | tentative_created | 1 | C-4102 | 2026年9月1日 09:00 |
| **BE-0101-02** | **R-20260901-0101** | **expired** | **2** | **期限管理** | **2026年9月1日 09:15** |

<br>

**`reservation_tentative_created_events`**

| 詳細番号 | 基底イベント番号 | 拠点 | 会議室 | 予約者 | 利用開始 | 利用終了 | 期限 |
|---|---|---|---|---|---|---|---|
| TE-0101-01 | BE-0101-01 | 丸の内 | M-301 | C-4102 | 2026年9月18日 10:00 | 2026年9月18日 11:30 | 2026年9月1日 09:15 |

<br>

**`reservation_confirmed_events`**

| 詳細番号 | 基底イベント番号 |
|---|---|
| &nbsp; | &nbsp; |

<br>

**`reservation_cancelled_events`**

| 詳細番号 | 基底イベント番号 |
|---|---|
| &nbsp; | &nbsp; |

<br>

**`reservation_expired_events`**

| 詳細番号 | 基底イベント番号 |
|---|---|
| **EE-0101-02** | **BE-0101-02** |

<br>

### Scenario BDD-010: 確定予約と重なる利用枠の仮押さえを拒む

```gherkin
Given: 顧客C-4102の確定予約R-20260901-0101がある
  And: 予約は会議室M-301の2026年9月18日 10:00から11:00までを占有している
  And: 顧客C-5821は予約可能顧客である
When: C-5821が同じ会議室の2026年9月18日 10:30から11:30までを仮押さえする
Then: C-5821の仮押さえ予約は成立しない
  And: R-20260901-0101の現在の姿と成立済みイベントは変わらない
  And: C-5821に属する予約、占有、期限、イベントは追加されない
```

#### Before / After

Before:

**`reservations`**

| 予約番号 | 拠点 | 会議室 | 予約者 | 利用開始 | 利用終了 | 状態 | 現在version | 作成日時 | 最終更新日時 |
|---|---|---|---|---|---|---|---:|---|---|
| R-20260901-0101 | 丸の内 | M-301 | C-4102 | 2026年9月18日 10:00 | 2026年9月18日 11:00 | confirmed | 2 | 2026年9月1日 09:00 | 2026年9月1日 09:05 |

<br>

**`room_booking_claims`**

| 予約番号 | 会議室 | 利用開始 | 利用終了 | 作成日時 |
|---|---|---|---|---|
| R-20260901-0101 | M-301 | 2026年9月18日 10:00 | 2026年9月18日 11:00 | 2026年9月1日 09:00 |

<br>

**`tentative_hold_deadlines`**

| 予約番号 | 期限 | 作成日時 |
|---|---|---|
| &nbsp; | &nbsp; | &nbsp; |

<br>

**`reservation_base_events`**

| 基底イベント番号 | 予約番号 | 種別 | version | 行為者 | 発生日時 |
|---|---|---|---:|---|---|
| BE-0101-01 | R-20260901-0101 | tentative_created | 1 | C-4102 | 2026年9月1日 09:00 |
| BE-0101-02 | R-20260901-0101 | confirmed | 2 | C-4102 | 2026年9月1日 09:05 |

<br>

**`reservation_tentative_created_events`**

| 詳細番号 | 基底イベント番号 | 拠点 | 会議室 | 予約者 | 利用開始 | 利用終了 | 期限 |
|---|---|---|---|---|---|---|---|
| TE-0101-01 | BE-0101-01 | 丸の内 | M-301 | C-4102 | 2026年9月18日 10:00 | 2026年9月18日 11:00 | 2026年9月1日 09:15 |

<br>

**`reservation_confirmed_events`**

| 詳細番号 | 基底イベント番号 |
|---|---|
| CE-0101-02 | BE-0101-02 |

<br>

**`reservation_cancelled_events`**

| 詳細番号 | 基底イベント番号 |
|---|---|
| &nbsp; | &nbsp; |

<br>

**`reservation_expired_events`**

| 詳細番号 | 基底イベント番号 |
|---|---|
| &nbsp; | &nbsp; |

<br>

After:

**`reservations`**

| 予約番号 | 拠点 | 会議室 | 予約者 | 利用開始 | 利用終了 | 状態 | 現在version | 作成日時 | 最終更新日時 |
|---|---|---|---|---|---|---|---:|---|---|
| R-20260901-0101 | 丸の内 | M-301 | C-4102 | 2026年9月18日 10:00 | 2026年9月18日 11:00 | confirmed | 2 | 2026年9月1日 09:00 | 2026年9月1日 09:05 |

<br>

**`room_booking_claims`**

| 予約番号 | 会議室 | 利用開始 | 利用終了 | 作成日時 |
|---|---|---|---|---|
| R-20260901-0101 | M-301 | 2026年9月18日 10:00 | 2026年9月18日 11:00 | 2026年9月1日 09:00 |

<br>

**`tentative_hold_deadlines`**

| 予約番号 | 期限 | 作成日時 |
|---|---|---|
| &nbsp; | &nbsp; | &nbsp; |

<br>

**`reservation_base_events`**

| 基底イベント番号 | 予約番号 | 種別 | version | 行為者 | 発生日時 |
|---|---|---|---:|---|---|
| BE-0101-01 | R-20260901-0101 | tentative_created | 1 | C-4102 | 2026年9月1日 09:00 |
| BE-0101-02 | R-20260901-0101 | confirmed | 2 | C-4102 | 2026年9月1日 09:05 |

<br>

**`reservation_tentative_created_events`**

| 詳細番号 | 基底イベント番号 | 拠点 | 会議室 | 予約者 | 利用開始 | 利用終了 | 期限 |
|---|---|---|---|---|---|---|---|
| TE-0101-01 | BE-0101-01 | 丸の内 | M-301 | C-4102 | 2026年9月18日 10:00 | 2026年9月18日 11:00 | 2026年9月1日 09:15 |

<br>

**`reservation_confirmed_events`**

| 詳細番号 | 基底イベント番号 |
|---|---|
| CE-0101-02 | BE-0101-02 |

<br>

**`reservation_cancelled_events`**

| 詳細番号 | 基底イベント番号 |
|---|---|
| &nbsp; | &nbsp; |

<br>

**`reservation_expired_events`**

| 詳細番号 | 基底イベント番号 |
|---|---|
| &nbsp; | &nbsp; |

<br>

C-5821に属する予約、占有、期限、基底イベント、詳細イベントは、8テーブルのどこにも存在しない。
