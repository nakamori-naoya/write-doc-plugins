# write-doc-plugins 抜本改革仕様書（方針・構造・受け入れ条件）

> **対象リポジトリ**: `/Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/write-doc-plugins`  
> **準拠規約**:  
> - `/Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/.agents/rules/harness-principles.md`  
> - `/Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/.agents/rules/plugin-package-contract.md`  
> **作成日**: 2026-09-15  
> **合意形成**: Gemini (Antigravity) & Astra (GPT-6) の合同レビューに基づく確定仕様

---

## 1. 改革の背景と目的

### 背景と課題
現行の `write-doc-plugins` は、細分化されたスキル構成（5 スキル）、重厚な執筆規律（12 参照ファイル）、中間 YAML ファイルのリレー、およびシェルスクリプト駆動（`prepare.sh`, `run-config.py`, `yq`）によって運用されています。  
その結果、以下の重大な問題が発生しています。

1. **防衛的記述（Defensive Writing）の肥大化**:
   - トゥールミンモデルや反駁・前提の過剰な形式主義（旧 `argument.md` 等）により、エージェントが批判を避けるための注釈や限定、文献参照を過剰に詰め込み、1 文 100〜150 文字の読みにくい複文を生成している。
2. **表と図（SVG/Mermaid）の役割崩壊**:
   - 表のセル内に長大な論証段落を詰め込んで俯瞰性を損ない、図の中に長文の条件テキストを押し込んで直感的な可視化を殺している。
3. **機械的オーバーヘッドによる認知資源の浪費**:
   - SKILL.md の多くがシェルスクリプトの実行と exit code 監視に占有され、エージェントのコンテキストと計算資源が「文章の推敲」ではなく「スクリプトの調整」に浪費されている。

### 改革の目的
上位規約である `harness-principles.md`（Simple made easy, 明確で宣言的, 80:20, 機械検査は決定論的述語のみ, 後方互換なし）に完全準拠し、**文章を書く判断を一箇所に戻し、読者の認知負荷を最小化するクリアなドキュメントを直接生成できる最小構成へ一括刷新**します。

※ ただし、過剰な数値制約（40〜60文字絶対化、20〜30%削減の数値義務化等）は新たな形式主義を生むため排除し、**本質的な文章規律（1文1メッセージ、結論ファースト、読者理解に寄与しない記述の削除）** を採用します。

---

## 2. アーキテクチャ設計（あるべき姿）

上位規約 `plugin-package-contract.md` および上位検査スクリプト（`validate-plugin-repository.py`）の「公開 Playbook 必須」「内部 Skill 1 つ以上宣言」の制約を満たす最小構造として、**公開入口 1 ＋ 内部執筆能力 1** に集約します。

```text
/Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/write-doc-plugins/
├── AGENTS.md
├── README.md
├── plugins/
│   ├── playbooks/authoring/write-doc/
│   │   ├── playbook.yml          # 公開 Playbook: 外部契約と内部スキルの接続のみ
│   │   ├── SKILL.md              # 公開入口: 契約入力を受け取り内部スキルへ渡す
│   │   └── CONTRACT.md           # 公開契約: 入力(素材・型・保存先)と出力(パス・状態)
│   └── skills/authoring/author-document/
│       ├── SKILL.md              # 内部 Skill: 読者確認・構成・執筆・推敲・保存を一気通貫
│       ├── references/
│       │   ├── core-principles.md    # 参照1: 目的、構成、文、用語、推敲
│       │   ├── visuals-and-tables.md # 参照2: 表、図、コード、強調
│       │   └── integrity-check.md    # 参照3: 根拠、数値、重要条件、読後の確認
│       └── assets/                   # ← content-types から完全継承
│           ├── templates/            # 23 本の型別テンプレート
│           ├── examples/             # 19 本の記載例
│           ├── personas/             # 5 人の読者ペルソナ
│           └── template-examples.yml # 型 slug とファイルの対応表
```

### 廃止・撤廃するもの
- 5 つの分散スキル: `content-types`, `writing-rules`, `visual-guidance`, `doc-render`, `write-doc-cleanup`
- 内部工程間の中間 YAML 生成（`reader_context.yml`, `reading_path.yml`, `figures_applied.yml`, `decisions.yml`）
- 独自の中間強調記法（役の印）
- SKILL.md 内の動的解決スクリプト呼び出し（`prepare.sh`, `run-config.py cleanup`, `yq`）
- `grill` への自動依存（合意形成は呼び出し元の責務とし、write-doc からは切り離す）

---

## 3. 各コンポーネントの詳細仕様

### (1) 公開 Playbook: `write-doc`
- **`CONTRACT.md`**:
  - 外部から渡される入力: `material`（必須）, `document_type`（任意）, `output_directory`（任意）, `update_target`（任意）, `name`（新規作成時必須）
  - 出力: `path`（保存された絶対パス）, `status`（`completed` または `failed`）
  - 旧設定解決スクリプト（`prepare.sh`）の呼び出しや複雑な終了コードの公開を全廃し、純粋な入力/出力スキーマのみを契約とする。
- **`playbook.yml`**:
  - `requires` から `grill`, `content-types`, `writing-rules`, `visual-guidance`, `doc-render` を削除。
  - `steps` は内部スキル `author-document` を 1 回呼ぶだけの単一ステップとする。
- **`SKILL.md`**:
  - 契約入力を受け取り、内部スキル `author-document` を起動して結果を契約形式で返すだけの薄いディスパッチャとする（スクリプト実行呪文なし）。

---

### (2) 内部 Skill: `author-document`
- **`SKILL.md` の責務**:
  - 読者・目的の固定 → 構成決定（テンプレート参照） → Markdown 直接執筆 → 推敲・正確性確認 → ファイル保存 までを一気通貫で実行。
  - シェルスクリプトによる設定解決や状態管理を行わず、エージェント自身のインメモリ推論で完結させる。

- **参照 1: `references/core-principles.md`（文章原則）**:
  - **読後ゴールの固定**: 主な読み手と、読後にできる判断・行動を決める。
  - **答えを先に示す**: 冒頭で読者の問いに答える。見出しは答えまたは対象を示す。
  - **1 文 1 メッセージ**: 1 つの文で伝える中心内容を 1 つにする。独立した主張は接続助詞で繋がず分ける。日本語説明文は 40〜60 文字程度を目安とし、因果関係が明瞭な文は無理に分割しない。
  - **1 段落 1 トピック**: 段落冒頭に要点を置き、理由や具体例で支える。
  - **同じものを同じ言葉で呼ぶ**: 用語の統一と初出定義。
  - **推敲（引き算の美学）**: 「削っても読者の理解・判断・行動が変わらない記述を削る」。削減率の数値縛りは置かない。

- **参照 2: `references/visuals-and-tables.md`（図表規約）**:
  - **役割分担**: 表は「比較・属性」、図は「構造・関係性」、本文は「理由・因果」を担当。
  - **表の規約**: セル内には 1 つの値または短い要約を置く。複数段落や長大な散文をセルに押し込めない。
  - **図の規約**: 要素名、関係（矢印）、短い遷移条件を残し、説明段落を入れない。詳細な理由は図の直下の本文で記述する。
  - **強調の規約**: 太字（Bold）は本当に重要なキーワード・要点に限定し、見出し直下の文を丸ごと太字にしない。

- **参照 3: `references/integrity-check.md`（正確性とセルフチェック）**:
  - **出典と主張の対応**: 出典の原文引用を一律に強制せず、事実と根拠の対応関係を正確に示す。
  - **重要条件の保持**: 判断を変える境界値や条件を省略しない。
  - **事実と推定の区別**: 未検証事項や仮説は明示する。
  - **読後到達点のセルフレビュー**: 読者の前提で本文を読み、読後に答えるべき問いに答えられるかを確認する。

---

### (3) 資産（Assets）の完全継承と調整
- `/Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/write-doc-plugins/plugins/skills/authoring/content-types/assets/` 配下の資産を、`author-document/assets/` へそのまま移動する。
  - `templates/`（23 本）
  - `examples/`（19 本）
  - `personas/`（5 本）
  - `template-examples.yml`
- **テンプレートの手入れ**:
  - 例: `rdb-logical-data-modeling.md` などの一部テンプレートにある「全論理列や制約を図へ載せる」といった過密な指示を、「関係性は図、列や制約は表・本文」に整理する。

---

## 4. 受け入れ条件（Acceptance Criteria）

本リファクタリングの完了は、以下の条件をすべて満たすことによって判定されます。

### AC 1: 上位規約・構造検査の完全通過
- リポジトリルートの検査スクリプトが成功すること:
  ```bash
  bash /Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/scripts/validate.sh /Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/write-doc-plugins
  ```
- 検査において、公開 Playbook（`write-doc`）が 1 つ、内部 Skill（`author-document`）が 1 つ宣言され、名前の衝突や禁止語、未宣言依存が存在しないこと。

### AC 2: シェルスクリプト依存と中間 YAML の完全撤廃
- `write-doc/SKILL.md` および `author-document/SKILL.md` の本文に、`prepare.sh`、`run-config.py`、`yq`、exit 2 監視などのランタイムスクリプト呼び出しが一切存在しないこと。
- 資料作成プロセスにおいて、`reader_context.yml` や `reading_path.yml` などの不要な中間ファイルがディスク上に生成されないこと。

### AC 3: テンプレート・記載例資産の 100% 保持
- `author-document/assets/templates/` に 23 本のテンプレート、`author-document/assets/examples/` に 19 本の記載例、`author-document/assets/personas/` に 5 本のペルソナがすべて保持されていること。
- 各テンプレート・記載例が `author-document/SKILL.md` から直接参照可能であること。

### AC 4: 参照ドキュメントの 3 本集約と文章規律の適正化
- 参照ドキュメントが `core-principles.md`, `visuals-and-tables.md`, `integrity-check.md` の 3 本のみに集約されていること。
- 旧 12 本の参照ファイル（728 行）が廃止されていること。
- 数値による過剰な形式主義（40〜60文字絶対化、20〜30%削減義務、毎節三段構成強制）が排除され、Astra レビューで合意された本質的規律になっていること。

### AC 5: 外部契約と呼び出し元の整合性
- `CONTRACT.md` が新しいシンプルな入出力形式に更新されていること。
- `write-doc` を利用している兄弟リポジトリ群（`product-planning-plugins`, `system-design-plugins` 等）の依存宣言と呼び出し手順が、新契約に合わせて一括更新可能な状態になっていること。

---

## 5. 移行作業手順（Execution Steps）

Astra（GPT-6）は、以下の手順に従って実装を段階的に進めてください。

1. **Phase 1: 資産の移動と新スキルの作成**
   - ディレクトリ `/Users/naoya-nakamoriq/Documents/Github/harness-pluginsv2/write-doc-plugins/plugins/skills/authoring/author-document` を作成。
   - `content-types/assets` を `author-document/assets` へ移動。
   - `author-document/references/` 配下に 3 本の参照ドキュメント（`core-principles.md`, `visuals-and-tables.md`, `integrity-check.md`）を作成。
   - `author-document/SKILL.md` を作成。
2. **Phase 2: テンプレートの過密要件チューニング**
   - `author-document/assets/templates/` 内の図表過密指示（全列・全制約を図に描かせる等）を修正。
3. **Phase 3: 公開 Playbook の刷新**
   - `plugins/playbooks/authoring/write-doc/` 配下の `CONTRACT.md`, `playbook.yml`, `SKILL.md` を新仕様へ書き換え。
   - `metadata.harness` や manifest（`.claude-plugin/` および `.agents/plugins/`）の登録情報を更新。
4. **Phase 4: 旧スキルの削除とクリーンアップ**
   - 旧 5 スキル（`content-types`, `writing-rules`, `visual-guidance`, `doc-render`, `write-doc-cleanup`）を削除。
   - `write-doc-plugins` 直下の `scripts/validate.sh` を新構造に合わせて整理（恣意的な文言検査の削除）。
5. **Phase 5: 静的検証と動作確認**
   - `bash scripts/validate.sh` を実行し、全項目合格を確認。
   - 実際に 1 本のドキュメント作成テストを行い、生成される Markdown の品質（複文がないか、図表がスッキリしているか、結論ファーストか）を確認。
