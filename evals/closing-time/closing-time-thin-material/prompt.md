---
plugins: ["../../../plugins/write-doc"]
description: 選んだ案も提案する案も無いメモを素材に ADR を頼み、write-doc が素材の不足を返して止まるかを見る。
tags: [write-doc, adr, stop]
max_turns: 60
timeout_seconds: 1200
allowed_tools: [Read, Glob, Grep, Skill, TodoWrite, Write, Edit]
---

作業場所の `input/締めの時刻のメモ.md` を素材にして、経費精算の月次の締めの時刻についての決定を、ADR（文書型 `adr`）として一本書いてください。読むのは、経費精算システムの開発チームです。

保存先は、作業場所の `out/` ディレクトリに `adr-締めの時刻.md` という名前で置いてください。write-doc の入力に渡すパスは、作業場所の絶対パスにしてください。

最後に、日本語で、保存したパスか、保存しなかったならその理由を短く報告してください。
