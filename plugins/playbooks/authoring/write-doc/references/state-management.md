# 実行状態を管理する

状態はリポジトリ内へ置かない。既定は `${XDG_STATE_HOME:-~/.local/state}/harness-plugins/playbooks/write-doc/<run-id>.json` である。

```bash
RUN_ID="${PLAYBOOK_RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)-$$}"
STATE="${PLUGIN_ROOT}/scripts/state.py"
python3 "$STATE" init --config "$CFG_FILE" --run-id "$RUN_ID" --repo "$(pwd)"
python3 "$STATE" start --config "$CFG_FILE" --run-id "$RUN_ID" --step type
python3 "$STATE" complete --config "$CFG_FILE" --run-id "$RUN_ID" --step type \
  --provide type=design-doc --provide template=/path/to/template.md
```

各工程の直前に`start`、成果物がすべて揃った後だけ`complete`を呼ぶ。失敗時は`fail --reason <理由>`を呼び、その後の工程へ進まない。`complete`は`provides`と同じ名前の`--provide key=value`が過不足なく揃わなければ拒否する。

中断後は同じ`PLAYBOOK_RUN_ID`で`init`し直すと再開する。`status`で現在地を読む。開始後にplaybook設定が変わっていれば再開できない。状態JSONへ成果物本文は入れず、識別子、path、ハッシュなどの参照だけを値にする。
