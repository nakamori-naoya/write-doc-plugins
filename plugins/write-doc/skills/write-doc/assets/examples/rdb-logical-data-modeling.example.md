# 図書館の貸出の論理データモデル

<!-- これは`rdb-logical-data-modeling`型の記載例である。**構成の基準資料ではなく、分量と具体性の見本として読む。**
     架空の題材「図書館の貸出」の業務知識から作った。業務イベントは貸出、技術的な処理は延滞の通知である。 -->

図書館の窓口と利用者が「誰が、どの一冊を、いつまでに返す約束か」と「いつ延滞になったか」を後から説明できるように、貸出に起きたことを積む。いまの貸出の状態、借りている冊数、延滞の有無は、積んだ事実から導ける情報なので持たない。延滞になった利用者へ知らせる処理は、頼んだ通知が必ず一度は終わるように、要求から成功か失敗までを追加のみで残す。

## リソース系とイベント系

| 系列 | 性質 | 論理テーブル | 正式な定義 | 時刻 | 変化 | 根拠 |
|---|---|---|---|---|---|---|
| リソース系 | 業務 | `loans` | 現在状態 | なし | 追加のみ | 業務知識「貸出」 |
| イベント系 | 業務 | `loan_base_events` | イベント列 | `occurred_at` | 追加のみ | 業務知識「業務イベント」 |
| イベント系 | 業務 | `loan_lent_events` | イベント列 | なし | 追加のみ | 業務イベント「本が貸し出された」 |
| イベント系 | 業務 | `loan_returned_events` | イベント列 | なし | 追加のみ | 業務イベント「本が返却された」 |
| イベント系 | 業務 | `loan_marked_overdue_events` | イベント列 | なし | 追加のみ | 業務イベント「貸出が延滞になった」 |
| イベント系 | 技術 | `overdue_notice_requested_events` | イベント列 | `occurred_at` | 追加のみ | 延滞を利用者へ知らせる要求 |
| イベント系 | 技術 | `overdue_notice_claimed_events` | イベント列 | `occurred_at` | 追加のみ | 同上 |
| イベント系 | 技術 | `overdue_notice_succeeded_events` | イベント列 | `occurred_at` | 追加のみ | 同上 |
| イベント系 | 技術 | `overdue_notice_failed_events` | イベント列 | `occurred_at` | 追加のみ | 同上 |

貸出はイベント列を選んだ。貸出、返却、延滞という名前のある出来事が順に起き、「延滞になった後に返した」のような経過を後から説明する必要があるからである。`loans`は、誰の、どの一冊の貸出かという、貸出が生まれたときに決まり変わらない事実だけを持つ。いまの状態は最後の基底イベントの種類から導く。技術の処理は、追い続ける対象を持たず、要求そのものが最初の出来事なので、基底イベントを置かず出来事ごとの表だけにした。

## 論理データモデル図

```mermaid
erDiagram
    loans {
        uuid loan_id PK "貸出"
        text user_number "利用者番号"
        text book_number "資料番号"
    }
    loan_base_events {
        uuid event_id PK "イベント"
        uuid loan_id FK "貸出"
        text event_type "lent / returned / marked_overdue"
        bigint version "貸出の中の順序"
        timestamptz occurred_at "起きた時点"
    }
    loan_lent_events {
        uuid event_id PK, FK "基底イベント"
        date due_on "業務が与えた値。貸した時点の決まりで決まる返却期限"
    }
    loan_returned_events {
        uuid event_id PK, FK "基底イベント"
    }
    loan_marked_overdue_events {
        uuid event_id PK, FK "基底イベント"
        date judged_on "業務が与えた値。延滞と判断した基準の判定日"
    }
    overdue_notice_requested_events {
        uuid request_id PK "要求"
        uuid source_event_id FK "延滞になった基底イベント"
        timestamptz occurred_at "要求した時点"
    }
    overdue_notice_claimed_events {
        uuid claim_id PK "回収"
        uuid request_id FK "要求"
        bigint version "要求の中の回収の順序"
        timestamptz occurred_at "回収した時点"
    }
    overdue_notice_succeeded_events {
        uuid request_id PK, FK "要求"
        uuid claim_id FK "送った回収"
        timestamptz occurred_at "送った時点"
    }
    overdue_notice_failed_events {
        uuid request_id PK, FK "要求"
        uuid claim_id FK "打ち切った回収"
        text reason "打ち切った理由"
        timestamptz occurred_at "打ち切った時点"
    }
    loans ||--|{ loan_base_events : "起きたこと"
    loan_base_events ||--o| loan_lent_events : "貸出の事実"
    loan_base_events ||--o| loan_returned_events : "返却の事実"
    loan_base_events ||--o| loan_marked_overdue_events : "延滞の事実"
    loan_base_events ||--o| overdue_notice_requested_events : "知らせる要求"
    overdue_notice_requested_events ||--o{ overdue_notice_claimed_events : "回収"
    overdue_notice_requested_events ||--o| overdue_notice_succeeded_events : "成功"
    overdue_notice_requested_events ||--o| overdue_notice_failed_events : "失敗"
```

## 論理テーブル定義

### `loans`（貸出）

一冊の本を一人の利用者へ預けた約束を見分ける。貸出が生まれたときに決まる、誰の、どの一冊の貸出かだけを持ち、以後変わらない。

#### 業務制約: 一冊の本の貸出中か延滞の貸出は一つ

最後の基底イベントが`lent`か`marked_overdue`の貸出は、同じ`book_number`について一つしか無い（BDD-003、BDD-011）。

#### 業務制約: 一人の貸出中と延滞の貸出は5冊まで

最後の基底イベントが`lent`か`marked_overdue`の貸出は、同じ`user_number`について5つを超えない（BDD-002）。

### `loan_base_events`（貸出に起きたこと）

貸出に起きた業務イベントに共通する事実である。貸出日は、`lent`の`occurred_at`を図書館の暦日で読んだ日である。

#### 業務制約: 貸出の中の版は一つずつ増える

同じ`loan_id`の`version`は1から一つずつ増え、同じ版は一つしか無い（BDD-006）。

### `loan_lent_events`（本が貸し出された）

貸したときに業務が与えた返却期限を持つ。返却期限は貸出日の14日後だが、後で貸出期間の決まりが変わっても、この貸出の約束は変わらないのでデータとして持つ。

### `loan_returned_events`（本が返却された）

返却に固有の事実は無い。種類ごとの表として置く。

### `loan_marked_overdue_events`（貸出が延滞になった）

延滞と判断した基準の判定日を持つ。延滞にする処理が遅れて翌日の`occurred_at`になっても、判定日は変わらない。

### `overdue_notice_requested_events`（延滞の通知を頼んだ）

延滞になった貸出の利用者へ知らせる要求である。「貸出が延滞になった」と同じ一つの変更で記録する。知らせる相手は、起因の基底イベントから貸出を辿って読む。

### `overdue_notice_claimed_events`（延滞の通知を引き受けた）

送る側が要求を引き受けた事実である。最新の回収の`occurred_at`から10分（リース。仮説）を過ぎても成功も失敗も無ければ、要求は再び回収できる。`request_id`と`version`の組は一意である。

### `overdue_notice_succeeded_events`（延滞の通知を送った）

要求ごとに一件だけある。

### `overdue_notice_failed_events`（延滞の通知を打ち切った）

再試行しても結果が変わらないと分かった要求と、回収の回数が上限（5回。仮説）に達した要求を、候補から外す。要求ごとに一件だけある。

#### 業務制約: 成功と失敗はどちらか一つ

同じ`request_id`が成功と失敗の両方に現れない。

## 並行実行で必要な保証

同じ利用者が二冊を同時に借りるとき、借りている冊数が4冊なら、成立するのは一冊だけである。二冊とも成立して6冊になることを許さない。競合するのは、その利用者の貸出と、それぞれの最後の基底イベントの集まりである。

同じ本を二人が同時に借りるとき、成立するのは一人だけである。競合するのは、その本の貸出と、それぞれの最後の基底イベントである（BDD-011）。

延滞にするのと本を返すのが同じ貸出で重なったとき、先に記録した方だけが成立する。後の方は、読んだ版の次の版がすでにあるので成立しない（BDD-006）。

同じ要求を二つの送り手が同時に回収するとき、同じ`version`の回収は一つしか成立しない（BDD-009）。

## 業務知識のシナリオとの対応

| 業務知識のBDD | この資料のBDD | 対象外の理由 |
|---|---|---|
| BDD-001 | BDD-001 | |
| BDD-002 | | 4冊目までの貸出は BDD-001 と同じ記録になる |
| BDD-003 | BDD-002 | |
| BDD-004 | | 延滞の有無で拒むのは BDD-002 と同じ形で、記録を変えない |
| BDD-005 | BDD-003 | |
| BDD-006 | | 本人の確認で拒まれ、記録に届かない |
| BDD-007 | | 返却の記録は BDD-004 と同じ形 |
| BDD-008 | BDD-004 | |
| BDD-009 | | 返却済みは状態で拒まれ、記録を変えない |
| BDD-010 | BDD-005 | |
| BDD-011 | | 延滞にする前に拒まれ、記録を変えない |
| BDD-012 | BDD-006 | |
| BDD-013 | BDD-011 | |

## 未決

貸出を見分ける`loan_id`は、業務知識に語が無い。ドメインモデルが「貸出番号」を業務知識へ提案している。

回収のリースを10分、打ち切るまでの回収の回数を5回と仮に置いた。通知を送る相手の応答時間が分かれば確定する。

## BDD

### [BDD-001] 本を借りると貸出と貸出の事実が生まれる

```gherkin
Given: 利用者 U-0001 は本を1冊も借りておらず、延滞の貸出も無い
  And: 本 B-1001 はどの貸出にも属していない
When: 利用者 U-0001 が2026年10月1日 10:00に本 B-1001 を借りる
Then: 貸出 L-001 が生まれ、最後の出来事は貸出である
  And: 返却期限は2026年10月15日である
```

#### データの状態

**Before**

**`loans`**

| loan_id | user_number | book_number |
|---|---|---|

**`loan_base_events`**

| event_id | loan_id | event_type | version | occurred_at |
|---|---|---|---|---|

**`loan_lent_events`**

| event_id | due_on |
|---|---|

**After**

**`loans`**

| loan_id | user_number | book_number |
|---|---|---|
| **L-001** | **U-0001** | **B-1001** |

**`loan_base_events`**

| event_id | loan_id | event_type | version | occurred_at |
|---|---|---|---|---|
| **E-001** | **L-001** | **lent** | **1** | **2026年10月1日 10:00** |

**`loan_lent_events`**

| event_id | due_on |
|---|---|
| **E-001** | **2026年10月15日** |

### [BDD-002] 5冊借りている利用者の6冊目は記録されない

```gherkin
Given: 利用者 U-0001 の5つの貸出は、どれも最後の出来事が貸出である
When: 利用者 U-0001 が2026年10月1日 10:00に本 B-1006 を借りる
Then: 貸出は生まれない
  NOTE: Rule: 貸出上限に達している利用者が本を借りる
    Reason: 一人の貸出中と延滞の貸出は5冊を超えない
```

#### データの状態

**Before**

**`loans`**

| loan_id | user_number | book_number |
|---|---|---|
| L-001 | U-0001 | B-1001 |
| L-002 | U-0001 | B-1002 |
| L-003 | U-0001 | B-1003 |
| L-004 | U-0001 | B-1004 |
| L-005 | U-0001 | B-1005 |

**`loan_base_events`**

| event_id | loan_id | event_type | version | occurred_at |
|---|---|---|---|---|
| E-001 | L-001 | lent | 1 | 2026年9月26日 10:00 |
| E-002 | L-002 | lent | 1 | 2026年9月26日 10:01 |
| E-003 | L-003 | lent | 1 | 2026年9月28日 15:00 |
| E-004 | L-004 | lent | 1 | 2026年9月28日 15:02 |
| E-005 | L-005 | lent | 1 | 2026年9月30日 11:00 |

**After**

**`loans`**

| loan_id | user_number | book_number |
|---|---|---|
| L-001 | U-0001 | B-1001 |
| L-002 | U-0001 | B-1002 |
| L-003 | U-0001 | B-1003 |
| L-004 | U-0001 | B-1004 |
| L-005 | U-0001 | B-1005 |

**`loan_base_events`**

| event_id | loan_id | event_type | version | occurred_at |
|---|---|---|---|---|
| E-001 | L-001 | lent | 1 | 2026年9月26日 10:00 |
| E-002 | L-002 | lent | 1 | 2026年9月26日 10:01 |
| E-003 | L-003 | lent | 1 | 2026年9月28日 15:00 |
| E-004 | L-004 | lent | 1 | 2026年9月28日 15:02 |
| E-005 | L-005 | lent | 1 | 2026年9月30日 11:00 |

### [BDD-003] ほかの利用者に貸出中の本は記録されない

```gherkin
Given: 本 B-1001 の貸出 L-001 は利用者 U-0001 のもので、最後の出来事は貸出である
When: 利用者 U-0003 が2026年10月2日 11:00に本 B-1001 を借りる
Then: 貸出は生まれない
  NOTE: Rule: 貸出中の本を借りる
    Reason: 一冊の本の貸出中か延滞の貸出は一つ
```

#### データの状態

**Before**

**`loans`**

| loan_id | user_number | book_number |
|---|---|---|
| L-001 | U-0001 | B-1001 |

**`loan_base_events`**

| event_id | loan_id | event_type | version | occurred_at |
|---|---|---|---|---|
| E-001 | L-001 | lent | 1 | 2026年10月1日 10:00 |

**After**

**`loans`**

| loan_id | user_number | book_number |
|---|---|---|
| L-001 | U-0001 | B-1001 |

**`loan_base_events`**

| event_id | loan_id | event_type | version | occurred_at |
|---|---|---|---|---|
| E-001 | L-001 | lent | 1 | 2026年10月1日 10:00 |

### [BDD-004] 延滞の本を返すと返却の事実が積まれる

```gherkin
Given: 貸出 L-002 の最後の出来事は延滞で、版は2である
When: 2026年10月20日 15:00に本 B-1002 が返される
Then: 貸出 L-002 の最後の出来事は返却になり、版は3になる
```

#### データの状態

**Before**

**`loan_base_events`**

| event_id | loan_id | event_type | version | occurred_at |
|---|---|---|---|---|
| E-011 | L-002 | lent | 1 | 2026年10月1日 09:00 |
| E-012 | L-002 | marked_overdue | 2 | 2026年10月16日 00:05 |

**`loan_returned_events`**

| event_id |
|---|

**After**

**`loan_base_events`**

| event_id | loan_id | event_type | version | occurred_at |
|---|---|---|---|---|
| E-011 | L-002 | lent | 1 | 2026年10月1日 09:00 |
| E-012 | L-002 | marked_overdue | 2 | 2026年10月16日 00:05 |
| **E-013** | **L-002** | **returned** | **3** | **2026年10月20日 15:00** |

**`loan_returned_events`**

| event_id |
|---|
| **E-013** |

### [BDD-005] 返却期限の翌日に延滞になり、通知の要求が同時に積まれる

```gherkin
Given: 貸出 L-001 の最後の出来事は貸出で、返却期限は2026年10月15日、版は1である
When: 図書館が判定日2026年10月16日に、00:05に貸出 L-001 を延滞にする
Then: 貸出 L-001 の最後の出来事は延滞になり、版は2になる
  And: 利用者へ知らせる要求が同じ変更で積まれる
```

#### データの状態

**Before**

**`loan_base_events`**

| event_id | loan_id | event_type | version | occurred_at |
|---|---|---|---|---|
| E-001 | L-001 | lent | 1 | 2026年10月1日 10:00 |

**`loan_lent_events`**

| event_id | due_on |
|---|---|
| E-001 | 2026年10月15日 |

**`loan_marked_overdue_events`**

| event_id | judged_on |
|---|---|

**`overdue_notice_requested_events`**

| request_id | source_event_id | occurred_at |
|---|---|---|

**After**

**`loan_base_events`**

| event_id | loan_id | event_type | version | occurred_at |
|---|---|---|---|---|
| E-001 | L-001 | lent | 1 | 2026年10月1日 10:00 |
| **E-002** | **L-001** | **marked_overdue** | **2** | **2026年10月16日 00:05** |

**`loan_lent_events`**

| event_id | due_on |
|---|---|
| E-001 | 2026年10月15日 |

**`loan_marked_overdue_events`**

| event_id | judged_on |
|---|---|
| **E-002** | **2026年10月16日** |

**`overdue_notice_requested_events`**

| request_id | source_event_id | occurred_at |
|---|---|---|
| **R-001** | **E-002** | **2026年10月16日 00:05** |

### [BDD-006] 返却が先に記録された貸出は延滞にならない

```gherkin
Given: 貸出 L-001 は版1で最後の出来事が貸出のときに読まれた
  And: その後、2026年10月15日 18:00の返却が版2で先に記録された
When: 図書館が判定日2026年10月16日に、読んだ版1の貸出 L-001 を延滞にする
Then: 版2はすでにあるので延滞は記録されず、最後の出来事は返却のまま変わらない
  NOTE: Rule: 返却済みの貸出は変わらない
    Reason: 読んだ版の次の版がすでにある
```

#### データの状態

**Before**

**`loan_base_events`**

| event_id | loan_id | event_type | version | occurred_at |
|---|---|---|---|---|
| E-001 | L-001 | lent | 1 | 2026年10月1日 10:00 |
| E-003 | L-001 | returned | 2 | 2026年10月15日 18:00 |

**After**

**`loan_base_events`**

| event_id | loan_id | event_type | version | occurred_at |
|---|---|---|---|---|
| E-001 | L-001 | lent | 1 | 2026年10月1日 10:00 |
| E-003 | L-001 | returned | 2 | 2026年10月15日 18:00 |

### [BDD-007] 通知の要求を回収して送ると成功が積まれる

```gherkin
Given: 要求 R-001 には回収も成功も失敗も無い
When: 送り手が2026年10月16日 00:06に要求 R-001 を回収し、同じ分に送り終える
Then: 回収と成功が一件ずつ積まれ、要求 R-001 は以後回収されない
```

#### データの状態

**Before**

**`overdue_notice_claimed_events`**

| claim_id | request_id | version | occurred_at |
|---|---|---|---|

**`overdue_notice_succeeded_events`**

| request_id | claim_id | occurred_at |
|---|---|---|

**After**

**`overdue_notice_claimed_events`**

| claim_id | request_id | version | occurred_at |
|---|---|---|---|
| **C-001** | **R-001** | **1** | **2026年10月16日 00:06** |

**`overdue_notice_succeeded_events`**

| request_id | claim_id | occurred_at |
|---|---|---|
| **R-001** | **C-001** | **2026年10月16日 00:06** |

### [BDD-008] リースが切れた要求は再び回収される

```gherkin
Given: 要求 R-001 は2026年10月16日 00:06に回収 C-001 で回収され、成功も失敗も無い
  And: 送り手は相手の応答を待つ間に止まった
When: 別の送り手が2026年10月16日 00:17に回収できる要求を探す
Then: 最新の回収からリースの10分を過ぎているので、要求 R-001 が版2で回収される
```

#### データの状態

**Before**

**`overdue_notice_claimed_events`**

| claim_id | request_id | version | occurred_at |
|---|---|---|---|
| C-001 | R-001 | 1 | 2026年10月16日 00:06 |

**After**

**`overdue_notice_claimed_events`**

| claim_id | request_id | version | occurred_at |
|---|---|---|---|
| C-001 | R-001 | 1 | 2026年10月16日 00:06 |
| **C-002** | **R-001** | **2** | **2026年10月16日 00:17** |

### [BDD-009] 同じ要求を二つの送り手が同時に回収すると一方だけが回収する

```gherkin
Given: 要求 R-002 には回収も成功も失敗も無い
When: 二つの送り手が2026年10月16日 00:06に同時に要求 R-002 を版1で回収する
Then: 回収は一件だけ積まれる
```

#### データの状態

**Before**

**`overdue_notice_claimed_events`**

| claim_id | request_id | version | occurred_at |
|---|---|---|---|

**After**

**`overdue_notice_claimed_events`**

| claim_id | request_id | version | occurred_at |
|---|---|---|---|
| **C-011** | **R-002** | **1** | **2026年10月16日 00:06** |

### [BDD-010] 送り先の無い要求は失敗として打ち切られ、以後回収されない

```gherkin
Given: 要求 R-003 の貸出の利用者には連絡先が登録されていない
  And: 要求 R-003 は2026年10月16日 00:06に回収 C-021 で回収された
When: 送り手が送り先を得られないと分かる
Then: 失敗が積まれ、要求 R-003 は以後回収されない
```

#### データの状態

**Before**

**`overdue_notice_claimed_events`**

| claim_id | request_id | version | occurred_at |
|---|---|---|---|
| C-021 | R-003 | 1 | 2026年10月16日 00:06 |

**`overdue_notice_failed_events`**

| request_id | claim_id | reason | occurred_at |
|---|---|---|---|

**After**

**`overdue_notice_claimed_events`**

| claim_id | request_id | version | occurred_at |
|---|---|---|---|
| C-021 | R-003 | 1 | 2026年10月16日 00:06 |

**`overdue_notice_failed_events`**

| request_id | claim_id | reason | occurred_at |
|---|---|---|---|
| **R-003** | **C-021** | **送り先が無い** | **2026年10月16日 00:06** |

### [BDD-011] 同じ本を二人が同時に借りると一人の貸出だけが記録される

```gherkin
Given: 本 B-1009 はどの貸出にも属していない
When: 利用者 U-0001 と利用者 U-0003 が2026年10月1日 10:00に同時に本 B-1009 を借りる
Then: 先に記録した利用者 U-0001 の貸出だけが記録される
  And: 利用者 U-0003 は「貸出中の本を借りる」で拒まれる
```

#### データの状態

**Before**

**`loans`**

| loan_id | user_number | book_number |
|---|---|---|

**`loan_base_events`**

| event_id | loan_id | event_type | version | occurred_at |
|---|---|---|---|---|

**After**

**`loans`**

| loan_id | user_number | book_number |
|---|---|---|
| **L-021** | **U-0001** | **B-1009** |

**`loan_base_events`**

| event_id | loan_id | event_type | version | occurred_at |
|---|---|---|---|---|
| **E-021** | **L-021** | **lent** | **1** | **2026年10月1日 10:00** |
