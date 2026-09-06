# 段階的開示と密度を軸にした改修（2026-09-06）

## 何を変えたか

生成資料への指摘は4点だった。文章量で中身の薄さを補っている。冒頭要約が札付き箇条書きで、未導入の語を使っている。図が外部SVGで、Mermaidを使っていない。外国語の引用に訳が無い。根本原因は、読み手の理解を「読む前」から「読んだ後」へ運ぶ経路を設計する規律が無く、役（一言でいうと・要約項目）と枠（summary・review）が冒頭要約と末尾総括を誘発していたことにある。

| 変更 | 場所 |
|---|---|
| 経路表（概念・足場・導入する節・初めて使う節・図）を先に作り、本文の順序と長さをそこから決める規律を追加 | writing-rules `references/path.md`、`apply.md`、`finalize.sh` |
| 強調の役を要点・キーワードの2つへ縮小。一言でいうと・要約項目・summary・review・badge を廃止 | writing-rules `emphasis.md`、doc-render `emphasis.md` `html.md` `html-shell.html`、playbook `playbook.yml` `roles.md` |
| 見出しが主張を運ぶ、末尾で反復しない、未確認は主張の隣に置く | writing-rules `structure.md` |
| 同じ理解に至るなら短い方を選ぶ。主張はストレートに言い切る | writing-rules `style.md`、`final-check.md` |
| Markdownの図はMermaidを第一候補にし、表現しきれないものだけ画像。枚数の上限なし | doc-render `markdown.md` `figures.md`、visual-guidance、playbook `figures.md` |
| 日本語以外の引用に日本語訳を添える | writing-rules `citation.md`、doc-render `citation.md` |
| grill@grillを`requires`へ宣言し、`open_questions.count > 0`のときだけ動く`settle`工程を追加。`state.py skip`で条件付き工程を飛ばせる | playbook `playbook.yml` `SKILL.md`、`scripts/state.py`、`scripts/validate.sh`（grillのcache fixture） |
| draft工程が`reading_path`を残し、review-docが本文と照合する | playbook `playbook.yml` `reader-contract.md`、review-doc、`scripts/test-reader-contract.py` |

## 確認

`bash scripts/validate.sh`は24項目成功・0失敗。工程テストは`reading_path`が無いdraft完了を拒み、揃えば完了することを検査する。文章の意味は自動採点していない。同日に生成した4本の資料は、installed cache 1.0.0（source より10 commit前）で作られており、この改修の効果は次の生成で確認する。
