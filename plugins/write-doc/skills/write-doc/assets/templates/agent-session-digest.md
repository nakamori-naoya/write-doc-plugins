---
schema: 2
kind: agent-session-digest
target_date: <YYYY-MM-DD>
timezone: <IANA timezone。例 Asia/Tokyo>
input_hash: <素材が与えるsha256>
generated_at: <保存時刻。ISO 8601>
session_count: <素材が与えるroot sessionの件数>
summary_schema: 1
sessions:
  - source: <素材のsource>
    source_id: <素材の不透明化済みsource_id>
    observed_at: <素材のobserved_at>
generator:
  model: <実際に要約したmodel ID>
  prompt_ref: agent-session-digest
validation:
  privacy: <passed / failed / not_checked>
  structure: <passed / failed / not_checked>
  source_unchanged: <passed / failed / not_checked>
human_reviewed: false
tags:
  projects: []
  repositories: []
  purposes: []
  decisions: []
  open_questions: []
---

# <対象日> エージェントセッションの日次記録

<!-- 執筆指示: 対象日に活動したClaude Code / Codexセッションについて、セッションごとに後から仕事へ再利用できる事実と判断を書く。
     会話の時系列や発言の言い換えではなく、達成・変更・判断・却下・検証・未解決・次の一手として再構成する。必要な根拠を保ち、文字数を内容品質の代理条件にしない。
     素材はセッションごとのrecords（source / source_id / source_path / source_fingerprint / relation / parent_source_id / target_date / display / observed_at / collector）である。
     `display` が真のセッションだけを本文に載せる。`source_path` の原文は要約するときだけ読み、全文・中間要約・native compact summaryを保存しない。
     front matterは素材が与える値をそのまま置く（`input_hash`、`session_count`、`sessions` の各値、`target_date`）。不明な値を推測しない。
     `generator.model` は実際に要約したmodel ID、`prompt_ref` はこの文書型の名前。`validation` は実行した確認だけを `passed` / `failed` にし、実行していない確認は `not_checked` にする。
     `human_reviewed` は保存時 `false`。`tags` は利用者が設定または依頼で明示した公開可能なaliasだけを短く安定した値で入れ、原文から顧客名・repository名・案件名を推測して入れない。明示が無ければ空配列にする。
     冒頭は本文段落で始め、誰が何のために読み、何が観測できたら完了かを文章で運ぶ。型・対象・日付・確認者の一覧や引用blockを冒頭に置かない。 -->

<!-- privacy境界（この型の資料は共有される可能性があるものとして書く。原文に存在することは書いてよい理由にならない）:
     出さない: 氏名・メールアドレス・アカウント名・顧客名・組織名など主体を特定できる情報、token・credential・secret・cookie・内部URL・非公開host名、native session ID・絶対path・cwd・branch名・repository URL・未承認のrepository名や案件名、system prompt・tool入出力・ログ・コードや会話原文の長い引用、契約・価格・脆弱性・未公開機能など公開可否を確認できない内容、native compact summary。
     残し方: 人物や顧客ではなく役割と行った判断を書く。固有名ではなく利用者が明示した公開可能なaliasを使う。secretそのものではなく「認証設定を更新した」のように作業の意味だけを書く。repositoryやpathではなく「対象実装」「設定」「テスト」のように変更の種類を書く。原文を引用せず、達成・判断・検証・未解決事項として再構成する。伏せ字、先頭数文字、hash化は匿名化とみなさない。
     判断に迷う情報は一般化せずに省き、必要な意味まで失うなら要約を止める。保存前に本文とタグを読み直し、禁止情報が無いと実際に確認した場合だけ `validation.privacy` を `passed` にする。混入を見つけたら `failed` にして保存しない。 -->

<冒頭の言い切り。対象日に何件のセッションで何が進んだか。この記録を読んだ利用者が、その日の仕事をどの粒度で振り返り、次の作業へ何を持ち込めるか>

## <sourceの表示名>（<不透明化済みsource_id>）

<!-- 書く: セッション1件ごとにこの節を置き、次の7つの小見出しをこの順で持つ。該当しない小見出しも省略せず「なし」と書く。
     書かない: 会話の時系列、発言の言い換え、原文の引用、セッションIDやpathの生の値。 -->

### 達成したこと

<このセッションで完了した成果。何がどう変わったか>

### 変更した対象

<変更の種類（対象実装、設定、テスト、資料など）。pathやrepository名ではなく種類で書く>

### 採用した判断と理由

<選んだ判断と、その根拠>

### 却下した選択肢

<検討して採らなかった案と、採らなかった理由。無ければ「なし」>

### 実行した検証と結果

<実行した検査・テストと、その結果。未実行の検証は「未実行」と書く>

### 未解決事項

<残った問い、失敗、保留。無ければ「なし」>

### 次にやること

<このセッションの続きとして次に行う作業。無ければ「なし」>
