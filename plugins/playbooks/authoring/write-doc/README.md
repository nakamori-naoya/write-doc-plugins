# write-doc

素材から Markdown 資料を1本書いて保存する公開 playbook である。公開する入出力と保証は [CONTRACT.md](CONTRACT.md) を正本とする。

内部では `author-document` が、読み手と目的の固定、構成、直接執筆、推敲、整合性確認、保存を一気通貫で行う。中間 YAML、設定解決 script、外部 playbook は使わない。
