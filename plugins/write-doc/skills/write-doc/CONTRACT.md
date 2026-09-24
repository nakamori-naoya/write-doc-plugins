# write-doc 公開契約 v2

`write-doc` は、渡された素材から Markdown 資料を1本作り、明示された保存先へ保存する。

| 項目 | 値 |
|---|---|
| 契約 ID | `write-doc/write-doc` |
| 版 | `2` |
| kind | `playbook` |
| playbook | `write-doc` |
| marketplace / plugin | `write-doc` / `write-doc` |

## 入力

| 名前 | 必須 | 型 | 意味 |
|---|---|---|---|
| `material` | 必須 | object[] | 本文の根拠にする素材。下記の要素を1つ以上 |
| `document_type` | 任意 | string | 型の一覧（`assets/template-examples.yml`）にある文書型の名前。省略時は目的に合う型を選ぶ |
| `output_directory` | 条件付き | absolute path | 新規作成先。`name` と組み合わせる |
| `update_target` | 条件付き | absolute path | 更新する既存 Markdown ファイル |
| `name` | 条件付き | string | 新規作成する `.md` ファイル名 |
| `references` | 任意 | absolute path[] | 追加で従う資料 |

新規作成では `output_directory` と `name` を両方渡す。更新では `update_target` を渡す。両方式を同時に渡さない。保存先を省略した入力は失敗とし、write-doc は保存先を推測しない。

`material` の各要素は、インライン素材なら `{kind: text, content: "..."}`、ファイル素材なら `{kind: file, path: /absolute/path}` とする。空の `content`、相対 path、読み取れない path、未知の kind やキーは受け付けない。この区別により、存在しないファイルパスを文章として扱わない。

`references` は読み取り可能な絶対パスでなければならない。プロジェクト固有の規約や文脈は、対象repositoryのAGENTS.md / CLAUDE.mdと `references` で渡される。`update_target` は `.md` ファイルでなければならない。`name` はパス要素を含まない `.md` ファイル名とする。表にない入力キーは受け付けない。`document_type` が渡された場合は選び直さない。

## 出力

成功:

```yaml
status: completed
path: /absolute/path/to/document.md
```

失敗:

```yaml
status: failed
reason: 保存できなかった理由
```

| 名前 | 条件 | 型 | 意味 |
|---|---|---|---|
| `status` | 常時 | `completed` または `failed` | 実行結果 |
| `path` | 成功時 | absolute path | 保存して確認した Markdown 資料 |
| `reason` | 失敗時 | string | 停止理由 |

出力は呼び出し元へ直接返す。中間 YAML や出力 YAML は作らない。1回の呼び出しで作る資料は1本だけである。

## 保証

- 素材、追加参照、確定済みの文書型を執筆に反映する。
- `update_target` を渡した場合だけ既存ファイルを更新する。
- 新規作成先に同名ファイルが存在する場合は上書きせず失敗する。
- 完成した Markdown と、その資料から参照する最終版の画像・図以外の中間成果物を作らない。
- 保存と整合性確認を完了した場合だけ `completed` を返す。

## 公開する資料

ほかの package が読んでよい資料は、次の一つだけである。

| 名前 | 場所（この公開入口の directory からの相対 path） | 目的 |
|---|---|---|
| 書くときの規範 | `references/writing-norms.md` | 人が読む文の書き方の基準。write-doc が作る資料だけでなく、ほかの package の SKILL.md や資料も、文の書き方はこの規範に従ってよい |

この資料の名前と場所は、契約の版2の間は変えない。変えるときは契約の版を上げる。消費側は、名前と場所で指すだけにし、中身を写したり、節の名前に依存したりしない。

これ以外の工程、内部 skill、テンプレート、参照文書、実装用 script は非公開であり、消費側は参照しない。
