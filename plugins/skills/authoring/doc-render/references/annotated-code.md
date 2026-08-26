# コード注釈を媒体へ写す

**どこへ注釈を付けるかは、書く側の規律が決める。** ここはマークアップだけ。

## HTML での書き方

行番号とコードを表の2列にし、**注釈を行として挟む**。

```html
<div class="code-listing">
  <div class="code-listing-head">
    <span class="path"><a href="vscode-insiders://file/絶対パス">相対パス</a></span>
    <span class="tag">通常投票</span>
  </div>
  <div class="code-block"><table class="code-table">
<tr><td class="ln">14</td><td class="code">func (s *Impl) GetVoteEntrySet(</td></tr>
<tr class="anno-row"><td></td><td class="anno"><b>21行目・コメントのみ変更</b> — 呼び出し自体は旧実装と一字一句同じ。番号コメントが今回付いただけ。</td></tr>
<tr><td class="ln">21</td><td class="code">    // 1. 母集団を決める。</td></tr>
<tr><td class="ln">22</td><td class="code">    voteGroup := models.GetRandomVoteGroup()</td></tr>
<tr class="blank"><td></td><td></td></tr>
  </table></div>
</div>
```

| 要素 | 役割 |
|---|---|
| `td.ln` | 行番号。`user-select: none` にして、コピーしたときに混ざらないようにする |
| `td.code` | コード本体。`white-space: pre` |
| `tr.anno-row` / `td.anno` | 注釈。左に色帯を立て、背景を薄く敷いて**コードと視覚的に分ける** |
| `tr.blank` | 空行。高さだけ確保する |

**注釈はコードと違うフォントにする。** 同じ等幅で書くと、コードの一部に見える。

`code-listing` は横に長くなるので、`overflow-x: auto` の入れ物に入れる。**ページ全体を横スクロールさせない。**

ファイルパスは**エディタで開けるリンク**にする（`vscode-insiders://file/絶対パス`）。読み手が実物へ飛べる。**原典（リモートの blob URL）を併記してよい。** 手元に clone を持たない読み手はそちらから開く。

## 読ませるコードと、参照させるコード

**媒体としての違いは1つだけ——畳むか、畳まないか。**

| | マークアップ | 既定の状態 |
|---|---|---|
| 読ませるコード | `<div class="code-listing">` | **開いている** |
| 参照させるコード | `<details class="code-listing appendix">` | 閉じていてよい |

**`<details>` を読ませるコードへ使わない。** 閉じたコードは開かれない。

`<details>` を使うときも、**閉じた状態でファイル名と行数が見えるようにする。**

```html
<details class="code-listing appendix" id="appendix-usecase">
  <summary><span class="path">usecase/debug_usecase/…go</span><span class="tag">全177行</span></summary>
  <div class="code-block"><table class="code-table">…</table></div>
</details>
```

## 段階ブロック（実行順に読ませるとき）

**注釈の単位を「ファイル」ではなく「段階」にする。** 1つの段階が2ファイルにまたがるなら、同じ段階の中に `code-listing` を2つ置く。

```html
<section class="stage" id="stage-3">
  <div class="stage-head"><span class="num">3</span><h3>キャッシュを引く</h3></div>
  <ul class="stage-io">
    <li><b>入力</b> cacheKey（段階2で確定）、userID</li>
    <li><b>確定する値</b> voteEntrySet（キャッシュが使えなければ nil）</li>
    <li><b>分岐</b> 9件揃っていれば段階7へ。揃わなければ段階4へ</li>
    <li><b>副作用</b> Redis GET</li>
    <li><b>次の呼び出し</b> GetVoteEntrySetFromCache</li>
  </ul>

  <div class="code-listing">…（読ませるコード。畳まない）…</div>

  <p class="next"><a href="#stage-4">次: 段階4 — 本番と同じロジックで抽選する</a></p>
</section>
```

| 要素 | 役割 |
|---|---|
| `section.stage` ＋ `id="stage-N"` | 段階の入れ物。**一覧からここへ飛ばす** |
| `.stage-head .num` | 段階番号。一覧の番号と一致させる |
| `ul.stage-io` | 入力・確定する値・分岐・副作用・次の呼び出し |
| `p.next` | **次の段階への導線。** 各段階の末尾に1つ置く |

**一覧（`.flow`）の各段階から `#stage-N` へリンクする。** リンク数と段階数が合っていること。

## 省略の印

**選んで載せた以上、省いた場所を示す。**

```html
<tr class="elision"><td class="ln">⋯</td><td class="code">⋯ 100〜115行目は省略（<a href="https://github.com/…/file.go#L100-L115">原典</a>）</td></tr>
```

**印を置かずに飛ばさない。** 読み手には、載っているものが全部か一部かを判別する手段が無い。

**媒体は中身を判断しない。** どこを省いてよいか・何を読ませる層に置くかは、書く側と型の判断である。ここが決めるのは**印の書き方だけ**である。


## Markdown での書き方

行番号つきの表が使えないので、**注釈をコードコメントとして本文へ差し込む**。

````markdown
`service/one_phrase_events_service/get_vote_entry_set.go`

**このファイルの責務**: usecase 層から呼ばれ、投票画面に出す9人を1トランザクションで確定する。

```go
func (s *OnePhraseEventsServiceImpl) GetVoteEntrySet(
	ctx context.Context,
	userID string,
) (*models.OnePhraseEventVoteEntrySet, error) {
	// ▼［コメントのみ変更］呼び出し自体は旧実装と一字一句同じ。番号コメントが今回付いただけ
	// 1. 母集団を決める。
	voteGroup := models.GetRandomVoteGroup()
```
````

**`▼` で始まる行が注釈**と決めておく。元のコードのコメントと混ざらないよう、印を必ず付ける。

Markdown では**行番号を振らない**。手で振ると、コードを直したときに必ずずれる。
