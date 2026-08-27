# データモデリングの型

## RDB論理設計

**読み手**: 業務を知る人と、業務事実をRDBへ永続化する人

**目的**: 永続化の作成・更新・削除に関係する業務シナリオから、時間を越えて残す事実とRDBの論理テーブル構造を決める

論理設計の内容、BDDとの対応、モデルの妥当性は呼び出し元のData Modeling／BDD専門pluginまたは依頼が与える。content-typesはモデルを設計せず、同梱の骨格と記載例だけを渡す。

**テンプレート**: [`assets/templates/rdb-logical-data-modeling.md`](../../assets/templates/rdb-logical-data-modeling.md)

**記載例**: [`assets/examples/rdb-logical-data-modeling.example.md`](../../assets/examples/rdb-logical-data-modeling.example.md)

---

## RDB物理設計

**読み手**: DB設計者、実装者、運用者

**目的**: 検査済みの論理データモデルを変えず、指定したRDB製品と版で実現・運用する方法を決める

物理設計の内容、製品・版の根拠、運用上の妥当性は呼び出し元のRDB専門pluginまたは依頼が与える。content-typesは物理方式を選ばず、同梱の骨格と記載例だけを渡す。

**テンプレート**: [`assets/templates/rdb-physical-design.md`](../../assets/templates/rdb-physical-design.md)

**記載例**: [`assets/examples/rdb-physical-design.example.md`](../../assets/examples/rdb-physical-design.example.md)
