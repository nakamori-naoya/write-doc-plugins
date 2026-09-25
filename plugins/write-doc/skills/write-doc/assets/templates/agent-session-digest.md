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
tags:
  projects: []
  repositories: []
  purposes: []
  decisions: []
  open_questions: []
---

# <対象日> エージェントセッションの日次記録

<!-- 執筆指示: 対象日に動いたClaude Code / Codexのセッションを1件ずつ取り上げ、後から仕事に使い回せる事実と判断を書く。
     会話を時系列でなぞったり、発言を言い換えたりはしない。達成、変更、判断、却下、検証、未解決、次の一手に組み直す。根拠は必要な分だけ残し、長く書けば質が上がるとは考えない。
     素材はセッションごとのrecordsで、各recordには source / source_id / source_path / source_fingerprint / relation / parent_source_id / target_date / display / observed_at / collector が入っている。本文に載せるのは `display` が真のセッションだけである。`source_path` の原文は要約するときにだけ読み、全文も途中の要約もnative compact summaryも保存しない。
     front matterには、素材が与える値（`input_hash`、`session_count`、`sessions` の各値、`target_date`）をそのまま置き、分からない値を推測で埋めない。`generator.model` には実際に要約したmodel IDを、`prompt_ref` にはこの文書型の名前を入れる。`tags` に入れてよいのは、利用者が設定か依頼で明示した公開可能な別名（alias）だけで、短く、表記を変えない値にする。顧客名、repository名、案件名を原文から推測して入れない。明示が無ければ空配列にする。
     冒頭は地の文の段落で始める。誰が何のために読むのか、どの日を扱うのか、読み終えたら何ができるのかを、その段落で書く。 -->

<!-- 共有してよい範囲: この型の資料は、共有されるものとして書く。原文にあったことは、書いてよい理由にならない。
     出さないもの: 氏名、メールアドレス、アカウント名、顧客名、組織名など、誰かを特定できる情報。token、credential、secret、cookie、内部URL、非公開のhost名。native session ID、絶対path、cwd、branch名、repository URL、利用者が承認していないrepository名や案件名。system prompt、tool の入出力、ログ、コードや会話の原文の長い引用。契約、価格、脆弱性、未公開機能のように、公開してよいかを確かめられない内容。native compact summary。
     出さずに意味を残す書き方:
       人物や顧客 → その役割と、行った判断
       固有名 → 利用者が明示した公開可能な別名
       secretそのもの → 「認証設定を更新した」のような作業の意味
       repositoryやpath → 「対象実装」「設定」「テスト」のような変更の種類
       原文の引用 → 達成、判断、検証、未解決事項に組み直した文
     伏せ字、先頭の数文字だけを残すこと、hash化は、どれも匿名化とみなさない。
     迷う情報は、ぼかして残さずに省く。省くと必要な意味まで失われるなら、要約をやめる。保存の前に本文とタグを読み直し、出さないものが混じっていたら保存しない。 -->

<冒頭の段落。対象日に何件のセッションで何が進んだかを言い切る。続けて、何が決まり何が残ったか、翌日どこから再開できるかを書く>

## <sourceの表示名>（<不透明化済みsource_id>）

<!-- 書く: セッション1件につきこの節を1つ置き、下の小見出しをこの順で並べる。書くことが無い小見出しは置かない。
     書かない: 会話の時系列、発言の言い換え、原文の引用、セッションIDやpathの生の値。 -->

### 達成したこと

<このセッションで完了した成果。何がどう変わったか>

### 変更した対象

<変更の種類（対象実装、設定、テスト、資料など）。pathやrepository名ではなく種類で書く>

### 採用した判断と理由

<選んだ判断と、そう決めた理由>

### 却下した選択肢

<検討して採らなかった案と、採らなかった理由。理由があるので箇条書きにせず、案ごとに段落で書く>

### 実行した検証と結果

<実行した検査やテストと、その結果。実行していない検証は「未実行」と書く>

### 未解決事項

<残った問い、失敗、保留>

### 次にやること

<このセッションの続きとして次に行う作業>
