# write-doc-cleanup

最終成果物と入力資料を保持し、資料化のためだけに生成した中間ファイルを明示パスで削除する単一skill pluginです。

削除対象を拡張子やdirectory名から推測しません。repository内の未追跡ファイルだけを扱い、追跡中のファイル、directory、repository外、`.git`配下、保持対象と一致するパスは拒否します。

`write-doc` playbookは削除を実行せず、このpluginを必須依存にしません。呼び出し元が、最終資料を`--keep`、資料作成後に不要になった未追跡の中間成果物を`--delete`として明示して、このpluginを呼び出します。
