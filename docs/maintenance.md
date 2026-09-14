# 検証と保守

**この文書は、この repository を変更した後に何を検証し、実行基盤と配布物をどう保守するかに答える。** 開発者向けの記録である。利用者向けの導入・設定・束縛は [README.md](../README.md) にある。

## 検証

```bash
bash scripts/validate.sh
```

## 実行契約と保守

設定はprepareが返すrun専用の絶対pathで引き継ぐ。別shellで同じpathを明示し、完了・失敗停止の最後に同梱run-configのcleanupを呼ぶ。中断後は保存したpathを使い、既にcleanup済みなら設定を再解決する。

依存宣言のversionは固定しない。対応する実行契約は`contractVersion: 1`で、契約版の宣言が無いfixtureは契約1として扱う。未知の契約版は拒否する。installed cacheでは安定版の最大SemVerを選び、prereleaseは`HARNESS_PLUGIN_ALLOW_PRERELEASE=1`を明示した場合だけ候補にする。解決したversion、内容hash、契約版を記録し、工程直前とwrite-doc再開時に内容変更を拒否する。

[doctor](../scripts/doctor.py)は`python3 scripts/doctor.py --repo <対象project>`でCLI構文、両runtime公開入口、依存、設定の解決元を読み取り専用で診断する。`--distribution-only`は依存・project設定を検査しない限定診断であり、full診断の代用にはしない。

doctorのfull診断は、依存を**実配布物**に対して解く。依存先は`HARNESS_PLUGIN_REAL_ROOTS`（契約ID→package rootのJSON）か、兄弟checkout `../<marketplace>-plugins/plugins`（親directoryは`HARNESS_PLUGIN_SIBLING_ROOT`で差し替える）から探し、どちらでも見つからなければfixtureへ倒さず理由付きでNGにする。同梱既定に実値を置かない`prompt_parameters`（`required: true`で`default`が無いもの）を持つskillは、上書きが無ければ必ず落ちるので実行せず、`skipped: requires-override`と必要なパラメータ名を出す。これは配布物の不具合ではないのでNGにしない。

依存参照の検査はresolverとlintが同じ関数で行う。外部依存を指せるのは`${.deps.<論理名>.root}`直下3点と`${.deps.<論理名>.entry}`だけで、それ以外は`external-dependency-path`で落ちる。内部依存（同一package）の`${.deps.<内部名>.skills.<名前>}`は、解決結果に実在するskill名だけを許し、綴り違いや名前の無い形は`internal-skill-unknown`で落ちる。`--explain`の依存行は`[外部] <論理名> → <marketplace>/<plugin> <version> [runtime/source_kind]: <root>`の形で、束縛で実体が変わったときだけ行末に`← <層>`が付く。

CIは同ownerの依存repositoryを兄弟directoryへcheckoutしてからvalidate.shを走らせる。**兄弟のrefは既定でmainである。** PR headと同名のbranchを採るのは、(1)実行が`pull_request`であり、(2)PR headが同一repository（forkではない）で、(3)同ownerの兄弟repoにその名前のbranchが実在する、の3つが揃うときだけで、選んだrefと理由はログへ出る。forkのPR作者はownerの兄弟repoにbranchを作れないため、PRから兄弟checkoutの内容を差し替える経路は無い。code scanningの`actions/untrusted-checkout/medium`はこの根拠により`won't fix`として扱う。

共通実装の開発時正本はProduct Planning repositoryの`shared/runtime-source`にある。更新時はそのsource checkoutを取得し、[生成CLI](../scripts/sync-runtime.py)へ`--source <取得した正本directory>`を渡す。`--check`は生成差分と[生成履歴](../shared/runtime-manifest.json)のversion・内容hash・対象集合を検査する。正本checkoutなしのCIでも同梱物のhashと対象集合を検査できる。実行時に別repositoryや生成CLIは不要である。変更は正本へ加え、同じ生成コマンドを各source repositoryへ適用する。

[release CLI](../scripts/release.py)は`--plugin --version --notes --breaking --migration --checks`で更新計画を返す。`--checks`にはcodex/claudeの実検証結果、または未検証と理由を明示する。`--apply`で両manifestとcatalogの整合を確認して一括更新し、releases配下へ変更内容・移行・検証結果のJSON記録を残す。依存宣言は変更しない。

[意味評価fixture](../evals/scenarios.json)を[評価runner](../scripts/evaluate-skills.py)へ渡し、異なる生成modelとjudge modelを指定する。モデル名、実model利用、適用設定、入力、出力、SKILL hash、判定の引用と理由を保存する。これはツール無効の次応答を対象とした代表caseの意味評価であり、実ツールを使った全工程E2Eや全行動の保証ではない。保存・CLI・再開の検証は[振る舞い回帰試験](../scripts/test-hardening.py)と既存validateが担う。実モデル未実行のfixtureを合格扱いにしない。

### explainの読み方

`scripts/prepare.sh`は`--explain`を引数に取らない。**explainは常にstderrへ出る。** stdoutは解決済みYAMLの絶対path1行だけなので、解決の内訳（選んだ設定層、依存の実体、束縛の出どころ、静的に解けた工程入力）はstderrで読む。`--explain`のような未知optionを渡すとusageを表示してexit 2で止まる。

### 開発CLIの入力境界

`doctor`、`release`、`sync-runtime`、意味評価runnerは、操作者が明示したローカルsource、出力先、adapter argvを扱う開発CLIである。外部から受け取った文書やモデル出力をCLI引数へ自動変換しない。doctorのfull modeは選んだrepositoryのresolverを実行するため、信頼するsource checkoutを対象にする。doctorは配布treeのsymlinkを読取・実行前に拒否し、sync-runtimeは生成先と正本treeのsymlinkをcopy前に拒否する。評価の会話・fixture・モデル出力はadapterへstdinデータとして渡し、実行argvに混ぜない。
