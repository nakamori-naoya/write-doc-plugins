---
name: remove-intermediate-artifacts
description: 最終資料や入力資料を残し、資料化後に不要となった明示パスの中間生成ファイルだけを検査して削除する。「最終成果物だけ残して」「資料化後の中間ファイルを片付けて」と言われたときに使う。追跡中のファイルやdirectoryは削除しない。
---

# remove-intermediate-artifacts

削除対象を推測せず、最終成果物が存在することを確かめてから、明示された未追跡の中間ファイルだけを削除する。

## 0. plugin rootを検証する

<!-- BEGIN shared:skill-entry/root-only -->
```bash
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-/absolute/path/to/this/plugin}"
bash "${PLUGIN_ROOT}/scripts/prepare.sh" --root-only >/dev/null || exit 2
```

**このコマンドは説明例ではない。必ず実行する。** 失敗したら先へ進まない。
<!-- END shared:skill-entry/root-only -->

## 1. 削除と保持を分ける

削除候補には、この実行が作り、最終資料へ内容を取り込んだ中間ファイルの絶対パスだけを渡す。最終資料、入力資料、実行可能な仕様、利用者が残すよう指定した成果物は保持候補へ渡す。拡張子やdirectory名から削除対象を増やさない。

## 2. 削除前に検査する

```bash
python3 "${PLUGIN_ROOT}/scripts/cleanup.py" check --repo-root <repository> \
  --delete <中間ファイル> --keep <最終資料> [--delete <中間ファイル> ...] [--keep <保持ファイル> ...]
```

追跡中のファイル、directory、repository外、`.git`配下、保持候補との一致、存在しない保持候補が一つでもあれば停止する。検査結果の`deletable`が意図した対象と一致しなければ削除しない。

## 3. 同じ指定で削除する

`check`と同じ引数で先頭だけ`delete`へ変える。削除後に空になった親directoryはrepository rootまで片付ける。存在しない削除候補は再実行可能にするため`missing`として扱う。

## 4. 報告する

削除したパス、既に無かったパス、保持したパスを返す。拒否した対象があれば、削除済みと報告しない。
