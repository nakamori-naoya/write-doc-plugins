# システム設計4型の日本語表記監査

監査対象は、要求発見資料、利用・負荷モデル、品質要求資料、クラウドアーキテクチャの詳細、テンプレート、記載例、およびそれらを選ぶカタログとREADMEである。見出し、説明、例文、判断理由、表、Mermaid図の表示名を確認した。

## 機械互換のため維持

- 型識別子の`requirements-discovery`、`workload-model`、`quality-requirements`、`cloud-architecture`
- JSON/YAMLのキー、列挙値、`status`、`open_questions`、`handoff.ready`、`blocked_by`
- 根拠状態の`fact`、`agreed_decision`、`hypothesis`、`open_question`、完了状態の`ready`、`unresolved`
- REQ、WL、QR、ADR、NODEで始まる追跡ID

これらは公開契約や文書間参照を壊さないため英語を維持し、初出または説明箇所で日本語の意味を対応させた。

## 英語が通例のため維持

- AWS、GCP、ADR、SLO、BDD、Mermaid、API、IaC、fan-out、hot key
- HTTPS、CloudFront、ALB、ECS on Fargate、Aurora PostgreSQL、RDS PostgreSQL、DynamoDB、SQS、EventBridge、Kafkaなどの規格名・製品名

正式名称や通例の技術語は維持し、役割、選定理由、図の表示名を日本語で記載した。

## 日本語化したもの

- 人間向けのactor/action/event/payloadを、利用者・操作・イベント・データ量へ変更した。
- latency、throughput、availability、consistency、durability、recovery、security、privacy、operability、costを、応答時間・処理量・可用性・整合性・永続性・復旧・安全性・プライバシー・運用性・費用へ変更した。
- provider、failure/degradation path、node、burst、trade-off、region、applicationを、プロバイダー、障害および縮退経路、ノード、バースト、トレードオフ、リージョン、アプリケーションへ変更した。
- テンプレートの全節に「書く」「書かない」の境界を日本語で示し、記載例の判断理由とMermaid図の表示名を日本語にした。

## 判断保留

現在はない。新しい正式製品名や定着していない技術語を追加するときは、日本語訳が意味を狭めないかを根拠付きで再監査する。

## 結果

予約サービスの同一題材とREQ/WL/QR/ADR/図ノードIDの追跡を維持したまま、人間向け文章を日本語へ統一した。検証スクリプトは、新規4型の記載例とテンプレートにあるASCIIだけの未置換プレースホルダー、壊れた同一文書内の節リンク、Mermaid表示名に残る日本語化対象の裸の英語を拒否する。正常なMermaid記法、HTML改行、機械キー、正式な技術名は受理する。

自動検査が保証するのは上記の構造的な表記規則までであり、あらゆる日本語表現の自然さや文脈ごとの最適な訳語までは保証しない。見出し、説明、例文、判断理由、図の表示名の自然さは本監査で人が読む観点から確認したが、将来の追記は同じ分類で再監査する。
