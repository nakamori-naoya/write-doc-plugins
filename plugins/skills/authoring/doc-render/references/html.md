# HTML へ写す

受け取った本文、役、段落境界、図を HTML 表現へ変換する。本文の構成、強調箇所、図の採否と型は変更しない。

## 骨格

[html-shell.html](../assets/html-shell.html) の `{{TITLE}}`、`{{META}}`、`{{BODY}}`、`{{THEME}}` を置換する。外部 CSS・外部フォント・CDN は追加せず、HTML 本体は1ファイルで完結させる。

| 受け取る役 | HTML |
|---|---|
| 本文 | `<article>` |
| 冒頭要約 | `<section class="summary">` |
| 末尾総括 | `<section class="review"><ul class="structure">…</ul></section>` |
| 要点 | `<mark>` |
| キーワード | `<mark class="kw">` |
| 一言でいうと | `<p class="hitokoto">` |
| 要約項目 | `<span class="badge imp">` または `<span class="badge pt">` |
| 出典の帰属 | `<span class="attribution">` |
| 横長の入れ物 | `<div class="scroll-x">` |

段落境界は別々の `<p>`、箇条書き項目の境界は別々の `<li>` へ写す。内容を結合・分割しない。

## テーマ

設定 `output.theme` の値を `<html data-theme="{{THEME}}">` へそのまま入れる。

| 値 | 写像 |
|---|---|
| `dark` | dark 用 CSS 変数 |
| `light` | light 用 CSS 変数 |
| `auto` | `prefers-color-scheme` で両方の CSS 変数 |

面を持つ要素には `color: var(--ink)` を指定する。図も HTML シェルと同じ CSS 変数を使い、固定 HEX 色へ変換しない。

## 機械検査

- [ ] テンプレート変数が残っていない
- [ ] 受け取った役が対応する要素へ一対一で写っている
- [ ] 段落と箇条書きの境界が保持されている
- [ ] 外部 CSS・外部フォント・CDN の参照がない
- [ ] theme と CSS 変数が解決されている
- [ ] 横長の表・図がページ全体を横スクロールさせない
