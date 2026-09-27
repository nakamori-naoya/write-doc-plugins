---
plugins: ["../../../plugins/write-doc"]
description: 事実、未確認、作業の経緯が混ざった検討メモを素材に、write-doc で ADR を一本書かせる。
tags: [write-doc, adr, pilot]
max_turns: 80
timeout_seconds: 1800
allowed_tools: [Read, Glob, Grep, Skill, TodoWrite, Write, Edit]
---

作業場所の `input/代理判断の記録の検討メモ.md` を素材にして、代理承認者の判断をどう記録するかの決定を、ADR（文書型 `adr`）として一本書いてください。読むのは、経費精算システムの開発チームに後から加わる人です。

保存先は、作業場所の `out/` ディレクトリに `adr-代理判断の記録.md` という名前で置いてください。write-doc の入力に渡すパスは、作業場所の絶対パスにしてください。

最後に、日本語で、保存したパス、仮に置いた読み手や判断があればその根拠を短く報告してください。
