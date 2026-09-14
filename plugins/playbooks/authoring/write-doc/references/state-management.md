# 実行状態を管理する

**工程の状態遷移・再開・保存場所の規則は、この文書だけが持つ。** 各工程は `pending → running → completed` の順で進み、失敗は `failed` で止まる。前工程を飛ばした開始や、`provides` 不足での完了は拒否する。状態管理が検査するのは記録の受け渡しであり、文章の意味は評価しない。

状態はリポジトリ内へ置かない。既定は `${XDG_STATE_HOME:-~/.local/state}/harness-plugins/playbooks/write-doc/<run-id>.json` である。

```bash
RUN_ID="${PLAYBOOK_RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)-$$}"
STATE="${PLUGIN_ROOT}/scripts/state.py"
python3 "$STATE" init --config "$CFG_FILE" --run-id "$RUN_ID" --repo "$(pwd)"
python3 "$STATE" start --config "$CFG_FILE" --run-id "$RUN_ID" --step reader
python3 "$STATE" complete --config "$CFG_FILE" --run-id "$RUN_ID" --step reader \
  --provide persona=/path/to/personas/backend-1.md \
  --provide reader_context=/path/to/reader-context.md \
  --provide goal_questions=/path/to/goal-questions.md \
  --provide open_questions=/path/to/open-questions.md \
  --provide type=adr --provide template=/path/to/template.md
```

各工程の直前に`start`、成果物がすべて揃った後だけ`complete`を呼ぶ。`when`を持つ工程は、条件が偽なら`skip --step <id> --reason <条件の評価>`で飛ばす。条件の無い工程は飛ばせず、飛ばした工程の成果物は登録されない。失敗時は`fail --reason <理由>`を呼び、その後の工程へ進まない。`complete`は`provides`と同じ名前の`--provide key=value`が過不足なく揃わなければ拒否する。

中断後は同じ`PLAYBOOK_RUN_ID`で`init`し直すと再開する。`status`で現在地を読む。開始後にplaybook設定が変わっていれば再開できない。状態JSONへ成果物本文は入れず、識別子、path、ハッシュなどの参照だけを値にする。

失敗後の`init`は`needs_retry`を返す。修復後に`retry`を明示して失敗工程だけをpendingへ戻し、`start`する。自動retryはしない。別repository、開始時と異なる設定・依存identityは拒否する。run-idを変更して新しく開始する。全更新はrun単位の排他下で行い、壊れた状態を初期化し直さない。saveの`path`は実在する絶対pathの通常ファイルであることを検査する。
