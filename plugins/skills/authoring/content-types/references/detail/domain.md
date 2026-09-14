# 業務の型

## 業務知識・コアドメイン

**読み手**: 業務を知る人と、それを形にする人
**目的**: 業務として正しい知識を、実装説明とは別の正本として残す

内容の正しさ、業務上の境界、BDDの妥当性は呼び出し元のDomain／BDD専門pluginまたは依頼が与える。content-typesは業務知識を発見・分類・補完せず、同梱の骨格と記載例だけを渡す。

**テンプレート**: [`assets/templates/domain-rule.md`](../../assets/templates/domain-rule.md)

**記載例**: [`assets/examples/domain-rule.example.md`](../../assets/examples/domain-rule.example.md)

---

## ドメインモデル

**読み手**: 業務を形にするエンジニア
**目的**: 業務知識・コアドメインの正本に現れる業務概念を、値オブジェクト・エンティティ・集約・ドメインイベントへ割り当て、各要素の目的・何でないか・不変条件・操作の契約（事前条件・事後条件・拒む理由）を、実装言語に依らない共通理解として残す。モデル図は公開コマンドだけのclassDiagramで、合意するのは振る舞いであってフィールドやゲッターではない

要素の割り当て、集約の境界、状態ごとの操作の可否、BDDとの対応の妥当性は呼び出し元のドメインモデリング専門pluginまたは依頼が与える。content-typesはモデルを設計せず、同梱の骨格と記載例だけを渡す。永続化・層構成・画面・APIは、この型では検討先を示すだけで扱わない。

**テンプレート**: [`assets/templates/domain-model.md`](../../assets/templates/domain-model.md)

**記載例**: [`assets/examples/domain-model.example.md`](../../assets/examples/domain-model.example.md)
