# システム構成 — RoomFlow 予約サービス

<!-- これは`architecture`型の記載例である。**構成の正本ではなく、粒度と具体性の見本として読む。**
     RoomFlowは組織内の共用会議室を予約する架空のサービスで、プロジェクトID・リージョン・値はすべて説明用である。実在の構成を確認したものではない。 -->

RoomFlowは、Cloud Run上のAPIとワーカーがCloud SQL（PostgreSQL）を共有して動く。利用者からの入口はロードバランサである。仮押さえ期限の到来だけをCloud Tasks経由で非同期処理する。組織のIDプロバイダより外へ出る通信は無い。

## 目的と範囲

- 対象: RoomFlow 予約サービス（API、期限処理ワーカー、データベース、入口）。本番と検証の2環境
- 観測時点: 2026-08-28。Google Cloud コンソールと `infra/` のTerraform定義で照合した
- 含めない: 組織のIDプロバイダ（Okta）の内部、会議室の入退室記録システム（別チーム所管。[入退室連携の資料](how-to.example.md)へ）

## 全体構成

```mermaid
flowchart LR
    利用者[予約者のブラウザ] --> LB[外部HTTPSロードバランサ]
    LB --> API[roomflow-api]
    API --> DB[(roomflow-db)]
    API -->|期限到来タスクを登録| TASKS[roomflow-hold-expiry]
    TASKS -->|期限時刻に配送| WORKER[roomflow-worker]
    WORKER --> DB
    API -->|IDトークン検証| OKTA[Okta]
    API --> SECRETS[Secret Manager]
    WORKER --> SECRETS
    API --> LOGS[Cloud Logging]
    WORKER --> LOGS
```

## 構成要素

利用者のWebリクエストを処理する `roomflow-api` と、期限切れタスクを処理する `roomflow-worker` は、いずれもコンテナとして Cloud Run 上で独立して稼働する。Webトラフィックの急激なスパイクが起きた場合でも、期限切れ処理の負荷が同期APIの応答を圧迫しないよう、処理境界を分離している。

| 要素 | 役割（一文） | 実行場所 | 技術・製品 | 所有者 |
|---|---|---|---|---|
| 外部HTTPSロードバランサ | 利用者からのHTTPSを受け、`roomflow-api`へ転送する | Google Cloud `roomflow-prod`、グローバル | Cloud Load Balancing、マネージド証明書 | 予約チーム |
| roomflow-api | 予約の作成・確定・取消・空き検索を受け付け、期限到来タスクを登録する | Cloud Run、`asia-northeast1` | Go 1.24、コンテナは`roomflow-api:<git sha>` | 予約チーム |
| roomflow-worker | 期限到来タスクを受け取り、未確定の仮押さえ予約を期限切れにする | Cloud Run、`asia-northeast1`、外部からは到達不可 | Go 1.24、コンテナは`roomflow-worker:<git sha>` | 予約チーム |
| roomflow-hold-expiry | 仮押さえ成立から15分後に配送するタスクの待ち行列 | Cloud Tasks、`asia-northeast1` | Cloud Tasks キュー | 予約チーム |
| roomflow-db | 予約・予約待ち・顧客の予約資格の現在の姿と、成立した業務イベントを保持する | Cloud SQL、`asia-northeast1`、プライベートIPのみ | PostgreSQL 16、`db-custom-2-8192` | 予約チーム |
| Secret Manager | DB接続文字列とOktaのクライアント秘密を保持する | Google Cloud `roomflow-prod` | Secret Manager | 予約チーム |
| Okta | 予約者の認証。IDトークンを発行する | 組織共通（所管外） | OIDC | 情報システム部 |
| Cloud Logging | アクセスログとアプリケーションログを保持する | Google Cloud `roomflow-prod`、`asia-northeast1` | Cloud Logging | 予約チーム |

## 通信と依存

APIとワーカー間の連携には Cloud Tasks を採用している。仮押さえの発生から15分後の期限到来を非同期タスクとして配送することで、データベースの定期ポーリングを不要にし、DBのCPU負荷とロック競合を最小限に抑えている。

| 呼ぶ側 → 呼ばれる側 | 経路 | 認証 | 相手が応答しないとき |
|---|---|---|---|
| 予約者のブラウザ → 外部HTTPSロードバランサ | 同期HTTPS | OktaのIDトークン（Bearer） | 利用者に「接続できない」を表示する |
| 外部HTTPSロードバランサ → roomflow-api | 同期HTTP（内部） | ロードバランサのサービスアカウントからのみ受ける | 503を返す。再試行はブラウザ側 |
| roomflow-api → roomflow-db | 同期、Cloud SQL Auth Proxy経由のプライベートIP | IAMデータベース認証 | 要求を失敗させ、予約は作らない。部分的な書き込みを残さない |
| roomflow-api → roomflow-hold-expiry | タスク登録（非同期） | サービスアカウント `roomflow-api@` | 登録に失敗したら仮押さえ自体を失敗させる。期限の無い仮押さえを作らない |
| roomflow-hold-expiry → roomflow-worker | HTTP push、期限時刻に配送 | OIDCトークン（`roomflow-tasks@`） | 配送失敗は最大5回、指数バックオフで再試行する。5回失敗したタスクはキューに残り、日次の点検で拾う |
| roomflow-worker → roomflow-db | 同期、プライベートIP | IAMデータベース認証 | タスクを失敗扱いにし、Cloud Tasksの再試行に委ねる |
| roomflow-api → Okta | 同期HTTPS（トークン検証は公開鍵を1時間キャッシュ） | クライアントID・秘密 | キャッシュ内の公開鍵で検証を続ける。キャッシュ切れなら401 |

## データの置き場

| データ | 置き場 | 保持 | 復元の手段 |
|---|---|---|---|
| 予約・予約待ち・顧客の予約資格・業務イベント | roomflow-db（PostgreSQL） | 無期限。取消済み・期限切れも残す | 日次の自動バックアップ（7世代）とポイントインタイムリカバリ（7日） |
| 期限到来タスク | roomflow-hold-expiry（Cloud Tasks） | 配送完了まで。最長15分＋再試行 | 復元しない。DBの仮押さえ期限から再登録できる（[期限タスクを再登録する](how-to.example.md)） |
| 秘密情報 | Secret Manager | 版ごとに保持 | Secret Managerの版から戻す |
| アクセスログ・アプリケーションログ | Cloud Logging | 30日 | 復元しない |

論理データモデルは[貸会議室予約のRDB論理設計](rdb-logical-data-modeling.example.md)、業務の決まりは[貸会議室予約の業務知識・コアドメイン](domain-rule.example.md)が正本である。この資料はそれらを繰り返さない。

## 環境

| 環境 | 本番との差分 | 到達経路 |
|---|---|---|
| 本番（`roomflow-prod`） | — | `https://roomflow.example.com` |
| 検証（`roomflow-stg`） | Cloud SQLは`db-custom-1-3840`、バックアップ世代は3、Oktaは検証テナント。それ以外は同じ | `https://stg.roomflow.example.com`（組織内IPからのみ） |

## 制約と境界

| 制約 | 値・条件 | 変えるときに影響する要素 |
|---|---|---|
| 同時受付 | 実測80件/分、推定上限150〜200件/分 | roomflow-api、roomflow-db |
| 仮押さえ期限の精度 | 期限時刻から配送まで最大60秒の遅れを許容する（Cloud Tasksの配送遅延を含む） | roomflow-hold-expiry、roomflow-worker |
| 可用性 | 単一リージョン。リージョン障害では停止する | すべて |
| セキュリティ境界 | roomflow-dbとroomflow-workerは外部から到達できない。外へ出る通信はOktaだけ | 外部HTTPSロードバランサ、roomflow-api |
| データの所在 | すべて`asia-northeast1` | roomflow-db、Cloud Logging |

同時受付の実測値は、2026年8月の1か月についてCloud Loggingを1分単位で集計した最大値である。推定上限は、1インスタンスあたり15〜20件/分の実測と最大10インスタンスから算出した。

## 未決

| 未決 | 影響する要素 | 何が分かれば確定するか |
|---|---|---|
| 同時受付が150件/分を超えたときの振る舞い | roomflow-api、roomflow-db | 負荷試験の結果。「推定」を実測に置き換える |
| リージョン障害時の目標復旧時間 | すべて | 運用責任者の判断。決まるまで「停止する」のまま |

## この資料に書かないもの

| 書かないこと | 検討先 |
|---|---|
| なぜCloud Tasksで期限処理をするか | [ADR](adr.example.md) |
| デプロイ・復旧・期限タスクの再登録の手順 | [ハウツーガイド](how-to.example.md) |
| テーブル定義・論理データモデル | [RDB論理設計](rdb-logical-data-modeling.example.md) |
| 業務の決まり | [業務知識・コアドメイン](domain-rule.example.md) |
