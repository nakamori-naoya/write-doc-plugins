# コード注釈を媒体へ写す

`writing-rules` が確定したコードの役と境界を媒体表現へ変換する。掲載範囲、注釈内容、読ませる層と参照させる層、段階、省略箇所は判断しない。

## 対応表

| 受け取る役 | HTML | Markdown |
|---|---|---|
| 読ませるコード | `<div class="code-listing">` | 通常の fenced code block |
| 参照させるコード | `<details class="code-listing appendix">` | 付録見出し下の fenced code block |
| 行番号 | `<td class="ln">` | 付けない |
| コード本体 | `<td class="code">` | fenced code block 内 |
| 注釈 | `<tr class="anno-row"><td></td><td class="anno">…</td></tr>` | `▼` で始まるコードコメント |
| 空行 | `<tr class="blank"><td></td><td></td></tr>` | 空行 |
| 省略の印 | `<tr class="elision">` | `…` と原典リンク |
| 段階 | `<section class="stage" id="stage-N">` | 見出し |
| 段階の入出力 | `<ul class="stage-io">` | 箇条書き |
| 次の段階への導線 | `<p class="next">` | 相対リンク |

## HTML の形

```html
<div class="code-listing">
  <div class="code-listing-head">
    <span class="path">path/to/file</span>
    <span class="tag">受け取った区分</span>
  </div>
  <div class="code-block"><table class="code-table">
    <tr><td class="ln">21</td><td class="code">code</td></tr>
    <tr class="anno-row"><td></td><td class="anno">受け取った注釈</td></tr>
    <tr class="elision"><td class="ln">⋯</td><td class="code">⋯ <a href="原典URL">原典</a></td></tr>
  </table></div>
</div>
```

参照させるコードでは外側だけを `<details class="code-listing appendix">` に置換する。段階として受け取った単位は `section.stage` で囲み、受け取った段階番号を `id="stage-N"` とリンクへ同じ値で写す。

## Markdown の形

````markdown
`path/to/file`

```text
code
▼ 受け取った注釈
```
````

元のコードコメントと注釈を区別するため、注釈行の先頭へ `▼` を付ける。行番号は生成しない。
