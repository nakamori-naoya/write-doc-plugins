# 強調を媒体へ写す

`writing-rules` が付与済みの役だけを、次の表で機械的に変換する。役の選択、個数、位置、妥当性は判断しない。

| 受け取る役 | HTML | Markdown |
|---|---|---|
| 要点 | `<mark>…</mark>` | `**…**` |
| キーワード | `<mark class="kw">…</mark>` | `` `…` `` |
| 一言でいうと | `<p class="hitokoto">…</p>` | `> …` |
| 要約項目（最重要） | `<span class="badge imp">最重要</span>` | `**[最重要]**` |
| 要約項目（ポイント） | `<span class="badge pt">ポイント</span>` | `**[ポイント]**` |

HTML の見た目は `assets/html-shell.html` の定義を使う。ここで本文を読み直して役を追加・削除・変更しない。
