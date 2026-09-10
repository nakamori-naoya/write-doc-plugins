# バックエンドエンジニア5年目

サーバー側の実装と、その周りの基盤を5年扱ってきた。設計から運用まで一人で通せる。

## 実務で使える

**説明なしで使ってよい語である。**

- サーバー実装: Go、gRPC（unary）、HTTP API、エラーハンドリング、ロギング
- データ: PostgreSQL、明示的なSQL、sqlc、マイグレーション、トランザクション、排他制約、index
- 基盤: Terraform、Cloud Run、Cloud Deploy、Docker、GitHub Actions
- 非同期: Pub/Sub のpush配信、リトライ、デッドレターキュー、冪等性
- テスト: 単体テスト、モック、E2E、テスト用のDB
- 設計: ドメインの決まりを資料にすること、BDD、論理データモデルと物理設計の分離

## 言われれば分かる

**初出で一言添えれば通じる。説明なしで論の土台には使えない。**

- クラウドのネットワーク: Direct VPC egress、private services access、Private Service Connect、private DNS、serverless NEG、HTTPSロードバランサ、Cloud Armor
- 認証・認可: OAuth 2.0、OpenID Connect、JWT、JWKS、ロールベースのアクセス制御
- フロントエンド: React、Next.js の App Router、RSC、CSR、SSR、Server Action、SWR
- Cloud Run Worker Pool
- Cloud Spanner

これらは、動いているものを読んだり、設計書を書いたりはしている。**自分で一から組み立てた経験は無い。**

## 知らない

**目的と前提から説明しないと通じない。**

- Kubernetes、GKE、Helm、サービスメッシュ
- gRPC のストリーミング、バックプレッシャー、ストリームのキャンセル
- Pub/Sub の ordering key、exactly-once 配信
- ORM の unit of work、遅延読み込み、エンティティ追跡
- Next.js の Pages Router 固有のデータ取得
- Redux とその周辺
- Jenkins、Argo CD、Flux
- Saga、プロセスマネージャー、分散トランザクションの調停
- 形式手法、TLA+、モデル検査

## この人へ書くときに落ちやすいところ

- **クラウドのネットワークを既知として書く。** 「Private Service Connect で繋ぐ」とだけ書くと、何と何がどう繋がるのかが伝わらない。
- **フロントの内部を既知として書く。** RSC と Client Component の境界がどこにあるかは、言われれば思い出せるが、その上に議論を積むと落ちる。
- **認証プロトコルの内部を既知として書く。** トークンを検証していることは分かるが、認可コードの交換手順は追えない。
