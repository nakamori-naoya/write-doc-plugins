# 出典を媒体へ写す

`writing-rules` が確定した出典リンク、引用、帰属、判断の役を媒体表現へ写す。引用の採否、量、内容は判断しない。

| 受け取る役 | Markdown | HTML |
|---|---|---|
| 出典リンク | `[出典名](URL)` | `<a href="URL">出典名</a>` |
| 原文の引用 | `> 引用` | `<blockquote><p>引用</p>…</blockquote>` |
| 出典の帰属 | 引用直下の通常文 | `<span class="attribution">…</span>` |
| 引用を受けた判断 | 引用後の通常段落 | `<p>…</p>` |

## Markdown

```markdown
[出典名](https://example.com/source)

> 受け取った原文の引用

受け取った判断。
```

## HTML

```html
<blockquote>
  <p>受け取った原文の引用</p>
  <span class="attribution">— <a href="https://example.com/source">出典名</a></span>
</blockquote>
<p>受け取った判断。</p>
```
