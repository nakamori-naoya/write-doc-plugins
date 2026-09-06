# 出典を媒体へ写す

`writing-rules` が確定した出典リンク、引用、帰属、判断の役を媒体表現へ写す。引用の採否、量、内容は判断しない。

| 受け取る役 | Markdown | HTML |
|---|---|---|
| 出典リンク | `[出典名](URL)` | `<a href="URL">出典名</a>` |
| 原文の引用 | `> 引用` | `<blockquote><p>引用</p>…</blockquote>` |
| 引用の日本語訳 | 同じ引用ブロック内、原文の次の段落に `訳: …` | 同じ `<blockquote>` 内の `<p class="translation">訳: …</p>` |
| 出典の帰属 | 引用直下の通常文 | `<span class="attribution">…</span>` |
| 引用を受けた判断 | 引用後の通常段落 | `<p>…</p>` |

## Markdown

```markdown
[出典名](https://example.com/source)

> 受け取った原文の引用
>
> 訳: 受け取った日本語訳

受け取った判断。
```

訳は原文が日本語以外のときだけ受け取る。原文を省いて訳だけにしない。

## HTML

```html
<blockquote>
  <p>受け取った原文の引用</p>
  <p class="translation">訳: 受け取った日本語訳</p>
  <span class="attribution">— <a href="https://example.com/source">出典名</a></span>
</blockquote>
<p>受け取った判断。</p>
```
