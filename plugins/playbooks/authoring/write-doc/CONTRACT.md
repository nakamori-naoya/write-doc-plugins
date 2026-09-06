# write-doc 公開契約 v1

**この文書に書かれていることだけが契約である。** ここに無い振る舞い・名前・path・ファイル形式・工程の並びは、いつ変わってもよい提供側の内部事情であり、消費側はそれに依存してはならない。

| 項目 | 値 |
|---|---|
| 契約 ID | `write-doc/write-doc` |
| 版 | 1 |
| kind | `playbook` |
| playbook 名 | `write-doc` |
| marketplace | `write-doc` |
| plugin | `write-doc` |

消費側の `playbook.yml` はこれを次の 2 か所だけで要求する。

```yaml
requires:
  - {plugin: write-doc, marketplace: write-doc}

steps:
  - id: document
    playbook: write-doc
    purpose: 素材から資料を1本書いて保存する
    input:
      document_type: ${.document_type}   # 静的に決まる型だけ書く。実行時に決まるなら書かない
    needs: [material]
    provides: [document_path]
```

利用者は `~/.config/harness-plugins/dependencies.yml`（利用者ごと）、`<repo>/.harness-plugins/dependencies.yml`（repository ごと）、`<repo>/.harness-plugins/scopes/<入口 playbook>/dependencies.yml`（入口ごと）で、契約 ID `write-doc/write-doc` に別の実体を束縛できる。**消費側は `requires` を書き換えない。**

**束縛と `implements` は対になっている。** 利用者が書く `dependencies.yml` の `bindings` は、契約 ID `write-doc/write-doc` に対して差し替え先を `{plugin, marketplace}` で指すだけであり、path も version も書けない。差し替え先の側は自分の `plugin.json` の `metadata.harness.implements[]` に `{id: write-doc/write-doc, version: 1, kind: playbook, playbook: <入口 playbook 名>, types: [<扱える文書型>]}` を宣言する。resolver はこの 2 つを突き合わせ、宣言の無い plugin への束縛を `[error:binding-not-implemented]` で止める。消費側が `input.document_type` で要求した型が `types` に無ければ `[error:binding-capability-unsupported]` で止まる。top-level が `version: 1` と `bindings` だけであること、3 層の置き場所、優先順位は README「実行契約と保守」にある。

---

## 1. 入口

外部から参照してよいのは次の 4 点だけである。参照の形は**2 つ**しかない。`<root>` は `${.deps.<論理名>.root}`、入口 SKILL.md は `${.deps.<論理名>.entry}`。

| # | 入口 | 形 |
|---|---|---|
| E1 | `<root>/scripts/prepare.sh <repo> --input=<絶対path> [--scope=<dir>] [--bindings=<lock>]` | 解決済み YAML の**絶対 path を 1 行**、stdout へ。失敗は exit 2、stdout は空 |
| E2 | `<root>/playbook.yml` | `version: 2`、`name: write-doc` |
| E3 | `<root>/scripts/resolve.sh` | `prepare.sh` が内部で呼ぶ入口（`--check-steps` 経路を含む） |
| E4 | `${.deps.<論理名>.entry}` | **playbook 入口 SKILL.md の絶対 path**。実行手順はここに従う |

**`<root>` から組み立ててよいのは E1〜E3 の 3 つだけである。** `<root>/skills/...`、`<root>/references/...`、`<root>/config/...`、`<root>/scripts/` 配下のそれ以外のファイルは、存在しても参照してはならない。

**skill 名で入口を指す形（`deps.<論理名>` の `.skills.<名前>`）は禁止である。** 外部依存の入口は `entry` だけで指す。`entry` は、採用した実体の `implements[]` のうち**契約 ID が一致する要素の `playbook` が指す directory の `SKILL.md`** である。だから差し替え先が公開 skill をどう名付けていても、消費側の書き方は変わらない。

- `entry_skill` は**表示用**である。解決結果に何という skill 名で見えているかを人へ見せるためのもので、path を組み立てる材料ではない。
- `entryRoot` は契約の解決に**使わない**。入口を決めるのは `implements[]` と `playbooks` だけで、二重管理を持たない。
- `<root>` も同じ `implements[]` から決まる。契約 ID が違えば `<root>` も違う。

### 呼び出し手順 — 2 段で、prepare は 1 回だけ

```
1. 呼び出し元が E1 を実行する
     CFG=$(bash "<root>/scripts/prepare.sh" "<repo>" \
             --input=<入力YAMLの絶対path> --scope=<入口のscope> --bindings=<束縛lock>)
   → 解決済み YAML の絶対 path が 1 行で返る（失敗は exit 2、stdout は空）

2. 呼び出し元が E4（`${.deps.<論理名>.entry}` の SKILL.md）を読み、**手順 1 で得た CFG を渡して**実行する
   → write-doc はその CFG をそのまま使う
```

**write-doc は E1 を自分でやり直さない。** 渡された解決済み YAML をそのまま使う。やり直せば、呼び出し元が載せた `--input` は失われ、`--scope` は write-doc 自身の名前で作り直され、`--bindings` は別の lock として引き直される。**入力・scope・束縛は、渡した側が決めたものが最後まで効く。**

逆に、**呼び出し元は E1 を省略できない。** SKILL.md だけを読ませて実行させると、write-doc は単独起動と見なして自分で prepare し、契約入力を受け取れない。

`--scope` と `--bindings` は、入口 playbook が決めたものをそのまま渡す。消費側が自分の名前で作り直さない。

**実行設定の後始末は、それを作った側が行う。** 呼び出し元が E1 で作った解決済み YAML は呼び出し元のものであり、write-doc は消さない。write-doc が内部で作った実行設定は write-doc が消す（G9）。消費側が `<root>` の script を後始末のために実行する形は契約に無い。

---

## 2. 入力 schema

`--input` へ渡す YAML。**未知のキーがあれば exit 2。**

**検査は入口で行う。** E1（`prepare.sh --input=<絶対path>`）を呼んだ時点で、契約 ID・版・文書型・保存先の排他規則・必須キー・未知キーをすべて見る。1 つでも満たさなければ **exit 2 で止まり、stdout は空**である。工程は 1 つも動かない。診断は stderr の `[error:<code>] key=value` に出る。

**path は絶対であればよい。正規化は提供側が行う。** 祖先や file 自身が symlink でもよく、提供側が realpath で正規化してから使う。呼び出し元は一時領域（macOS 既定の `TMPDIR` のような symlink 経由の path を含む）へ書いた絶対 path をそのまま渡してよい。相対 path、`.`、`..` で終わる path は exit 2。

```yaml
contract: write-doc/write-doc          # 必須。固定
version: 1                             # 必須。固定
document_type: domain-rule             # 任意。型 slug
material:                              # 必須。1つ以上の絶対path
  - /var/folders/x/harness-run-abc/material.yml
output_format: markdown                # 任意。markdown | html
name: order-cancellation.md            # 新規作成のとき必須
output_directory: /Users/me/src/acme/docs/domain   # 任意。無ければ利用者の設定で決まる
update_target: /Users/me/src/acme/docs/domain/order-cancellation.md  # 既存差し替えのとき必須
references:                            # 任意。追加指示（呼び出し元自身の文書）
  - /Users/me/src/acme-bdd/plugins/playbooks/bdd/domain-bdd-formulation/references/formulation-deliverable.md
output_to: /var/folders/x/harness-run-abc/write-doc-output.yml   # 必須
```

| 名前 | 型 | 必須 | 意味 |
|---|---|---|---|
| `contract` | string | ○ | `write-doc/write-doc` 固定 |
| `version` | int | ○ | `1` 固定 |
| `document_type` | 型 slug | 任意 | 渡されたら**選び直さない**（G1）。実装済みの型でなければ exit 2 |
| `material` | 絶対 path[] | ○ | 資料の中身の元。呼び出し元が束ねたもの。**配列**で 1 つ以上、それぞれ regular file |
| `output_format` | `markdown` \| `html` | 任意 | 渡されたら提供側の既定より優先する（G4） |
| `name` | ファイル名 | △ | **新規作成のとき必須。** path 区切りを含まないファイル名 |
| `output_directory` | 絶対 path | 任意 | 新規作成先の directory。**省略できる**（下記） |
| `update_target` | 絶対 path | △ | 既存資料の差し替え先。regular file であること |
| `references` | 絶対 path[] | 任意 | 追加指示。**呼び出し元自身の文書**であること |
| `output_to` | 絶対 path | ○ | 出力 YAML の書き込み先。親 directory が存在し書き込めること。ファイル自体は無くてよい |

**保存先の規則**（提供側が検証し、破れば exit 2）:

呼び出し元は、**新規作成（`name`）か、既存の差し替え（`update_target`）のどちらか一方**を必ず渡す。

| 渡すもの | 意味 |
|---|---|
| `name` だけ | 新規作成。**保存する directory は利用者が作業 repository の設定で決める**（文書型ごとの振り分け、無ければ既定の保存先）。ファイル名は `name` |
| `name` + `output_directory` | 新規作成。**その directory へ保存する。** 依頼で保存先が明示されたときだけ使う |
| `update_target` | 既存資料の差し替え。**その絶対 path へ書く** |

- `update_target` と `name` は**排他**。両方あれば exit 2。**どちらも無ければ exit 2。**
- `output_directory` を渡すなら `name` も要る。`output_directory` だけなら exit 2。
- `references` に write-doc 自身の配布物内の path が含まれていたら exit 2。**提供側の references を呼び出し元が渡す形は契約に無い。**

**呼び出し元は、依頼に無い保存先を推測して渡さない。** 依頼が directory を指定していないなら `output_directory` を省き、利用者の設定に委ねる。

---

## 3. 出力 schema

write-doc は完了時に `output_to` の絶対 path へ次の YAML を書く。

```yaml
contract: write-doc/write-doc
version: 1
status: completed              # completed | failed
path: /Users/me/src/acme/docs/domain/order-cancellation.md
document_type: domain-rule
output_format: markdown
```

| 名前 | 型 | 意味 |
|---|---|---|
| `status` | `completed` \| `failed` | 保存と確認まで到達したか |
| `path` | 絶対 path | 保存した資料 1 本の path（`completed` のとき）。`update_target` を渡したならそれと一致し、`name` を渡したなら basename が `name` と一致する |
| `document_type` | 型 slug | 実際に使った型（`completed` のとき） |
| `output_format` | `markdown` \| `html` | 実際の媒体（`completed` のとき） |
| `reason` | string | 停止理由（`failed` のとき。`path` は持たない） |

**1 回の呼び出しで作る資料は 1 本だけである。** 複数本が要るなら、呼び出し元が複数回呼ぶ。

---

## 4. 契約の語と提供側の中の対応

この表の**左側だけが契約**である。右側は提供側がいつでも変えてよく、名前も存在も保証しない。

| 契約の語 | 提供側が内部でどうするか（**非契約**） |
|---|---|
| `document_type` | 型を決める工程へ渡し、選び直させない |
| `material` | 本文を書く工程の素材にする |
| `output_format` | 保存工程の媒体指定へ写す |
| `name` | 保存工程のファイル名にする |
| `output_directory` | 渡されたときだけ、保存工程の新規作成先 directory にする |
| `update_target` | 保存工程の差し替え先へ写す |
| `references` | 各工程への追加指示として読ませる |
| `output_to` | 完了時に出力 YAML を書く |

---

## 5. 保証

| # | 保証 |
|---|---|
| G1 | `document_type` が指定されたら、**その型で書く。選び直さない** |
| G2 | `update_target` が無い限り、**既存 path を読まずに上書きしない**。同名があれば停止する |
| G3 | `update_target` が渡されたら、**その絶対 path へ差し替える**。別の保存先を作り直さない |
| G3b | `name` が渡されたら、**そのファイル名で保存する**。`output_directory` があればその directory、無ければ利用者の設定が決めた directory へ置く |
| G4 | `output_format` が指定されたら、提供側の既定より優先する |
| G5 | **保存前に自己確認する。** 本文だけで読み手が目的の判断・行動へ到達できるかを検査し、届かない箇所を直してから保存する |
| G6 | **失敗は停止する。** 劣化した結果を返さない。下段が欠けたまま書かない |
| G7 | `references` に渡された追加指示に従う。無視しない |
| G8 | `output_to` へ出力 YAML を書く。書けない場合は G6 で停止する |
| G9 | 自分が作った実行設定の後始末を自分で行う。呼び出し元に委ねない。**呼び出し元が E1 で作った解決済み YAML は消さない** |
| G10 | 入力が schema を満たさなければ、**補わずに exit 2 する**。検査は E1 を呼んだ入口で完結し、工程は 1 つも動かない |

---

## 6. 非契約

契約に書かれていないものはすべて非契約である。以下は代表例であり、網羅ではない。

| 種別 | 具体 |
|---|---|
| 工程 id | 資料を作る途中の工程の並びと名前 |
| 内部 skill 名・内部 plugin 名 | package の内部で使う名前。消費側から `skill:` で指しても解決しない。公開 skill 名も `entry_skill` の表示以上の意味を持たない |
| 内部 script | 保存・整形・後始末を行う script とその引数・exit code |
| テンプレートと骨格 | 型ごとの骨格・記載例・カタログのファイル |
| 図の選び方 | 図の型の決め方と、その手引き |
| 媒体表現 | 役をどのタグ・記号へ写すか |
| `playbook.contract.*` | 下段どうしをつなぐための内部の対応表 |
| references | `references/` 配下の手引き |
| config | `.harness-plugins/` に置く内部 plugin の設定キー（利用者が触るのは可、消費側 plugin が語るのは不可） |
| `run-config.py cleanup` | 後始末は G9 で提供側が行う |

**言い換え表**

| 内部語（禁止） | 契約の言葉 |
|---|---|
| 保存モード名を渡す | `update_target`（差し替え）または `name`（新規作成） |
| 差し替えの option を付ける | （不要。`update_target` があれば差し替え） |
| 同名衝突の exit code を見る | （不要。G2 で提供側が停止する） |
| 骨格の option へ型を渡す | `document_type` |
| 出力先の option を渡す | `output_directory` |
| `logical_update_target` | `update_target` |
| 内部 skill を `skill:` で呼ぶ | `playbook: write-doc` へ `material` を渡す |
| `deps.write-doc` の `.skills.write-doc` を読む | `${.deps.write-doc.entry}` |
| 中間生成物の削除を write-doc へ頼む | 消費側が自分の後片付けを持つ |

---

## 7. 文書型

型の一覧は、この配布物が `metadata.harness.implements[].types` で自己宣言する。**消費側は型 slug を指定するだけで、テンプレート・骨格・記載例・カタログのファイルには触れない。**

- 静的に決まる型は、消費側 `playbook.yml` の `steps[].input.document_type` に書く。resolver が解決時に突き合わせ、実装されていない型なら resolve の時点で落ちる。
- 実行時に決まる型は `steps[].input` に書かず、`--input` の `document_type` として渡す。入口の検査で実装済みの型かどうかを見る。
- `document_type` を渡さないと、write-doc が読み手と目的から型を選ぶ。

差し替え先の実体は、同じ契約 ID を実装していても**型の集合が違ってよい**。消費側が要求した型を実装していなければ、束縛の時点で止まる。
