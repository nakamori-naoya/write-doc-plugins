# システム設計の根拠を残す4型

この詳細は、要求、利用・負荷、品質、将来のクラウド構成を別々の正本として書くための型を定める。各型は呼び出し元が発見・検証した素材を受け取り、その意味を作り直さない。

## 要求発見正本

**読み手**: 何を作るか合意するプロダクト責任者と設計者  
**目的**: 要求源、受益者、目的、成功・失敗の観測、範囲、システム境界、制約を、根拠状態と要求ID付きで共有する  
**成功条件**: 読み手が各要求について「誰の何をなぜ実現するか」「根拠は何か」「確定か仮説か」「何で検証するか」「どの後続成果物に影響するか」を答えられる

Journey、Domain、データモデル、技術方式、クラウド選定は書かない。入力に実現手段があれば、要求、仮説、設計案へ分類し、設計案を要求へ逆流させない。

## 利用・負荷モデル

**読み手**: 容量と方式の前提を判断する設計者・運用者  
**目的**: 利用者（機械値: `actor`）・操作（機械値: `action`）・イベント（機械値: `event`）ごとの規模、平均・ピーク率、読み書き比、データ量（機械値: `payload`）、保持・増加、分布、fan-out、hot key、バーストを、単位・時間窓・母集団・根拠・確からしさ付きで共有する  
**成功条件**: 読み手が平均値だけでなく分布、偏り、ピーク、増加を説明し、未確認値がどの設計判断へ影響するかを答えられる

SLO、データモデル、クラウド構成は決めない。fan-outやhot keyは技術方式ではなく負荷特性として書く。

## 品質要求正本

**読み手**: 品質の優先順位と検証を合意する責任者・設計者  
**目的**: 応答時間（機械値: `latency`）、処理量（機械値: `throughput`）、可用性（機械値: `availability`）、整合性（機械値: `consistency`）、永続性（機械値: `durability`）、復旧（機械値: `recovery`）、安全性（機械値: `security`）、プライバシー（機械値: `privacy`）、運用性（機械値: `operability`）、費用（機械値: `cost`）を、観測点・指標・閾値・時間窓・対象母集団・検証方法付きで共有する  
**成功条件**: 読み手が各品質要求の測り方、根拠、対応する要求・負荷仮説、矛盾、未合意値を答えられる

クラウドや製品を選定せず、「高速」「高可用」のような測定不能表現を完成扱いにしない。根拠のない数値は仮説または未決として書く。

## クラウドアーキテクチャ

**読み手**: 将来構成を選び、実装・運用判断へ渡す設計者  
**目的**: 要求、利用・負荷、品質、組織・運用・予算制約を根拠に、プロバイダー（機械値: `provider`）と主要サービスを比較・選定し、代替案、ADR、要求追跡、障害および縮退経路、編集可能なMermaid図を共有する  
**成功条件**: 読み手が各主要選定について「どの要求・負荷・品質・制約を根拠にしたか」「代替案をなぜ採らないか」「どの未決が実装着手を止めるか」を答えられる

既存の`architecture`型が観測時点の**現在構成を説明する**のに対し、`cloud-architecture`型は根拠から**将来構成を比較・選定する**。要求、Journey、Domain、論理データモデルを作り直さず、アプリケーション内部設計やTerraform実装は書かない。

## 4型に共通する状態と追跡

各文書は事実（機械値: `fact`）、合意済み決定（機械値: `agreed_decision`）、仮説（機械値: `hypothesis`）、未決（機械値: `open_question`）を区別する。状態（機械キー: `status`）は準備完了（機械値: `ready`）または未解決（機械値: `unresolved`）とし、未解決でも文書を保存する。未決が1件でも後続判断を変えるなら引き継ぎ可否（機械キー: `handoff.ready`）を`false`にし、未決IDを阻害要因（機械キー: `blocked_by`）へ列挙する。REQ、WL、QR、ADR、図ノードのIDを別文書から参照し、仮説や未決を確定事項へ昇格させない。

**テンプレート**: [`requirements-discovery`](../../assets/templates/requirements-discovery.md)、[`workload-model`](../../assets/templates/workload-model.md)、[`quality-requirements`](../../assets/templates/quality-requirements.md)、[`cloud-architecture`](../../assets/templates/cloud-architecture.md)

**記載例**: [`requirements-discovery`](../../assets/examples/requirements-discovery.example.md)、[`workload-model`](../../assets/examples/workload-model.example.md)、[`quality-requirements`](../../assets/examples/quality-requirements.example.md)、[`cloud-architecture`](../../assets/examples/cloud-architecture.example.md)
