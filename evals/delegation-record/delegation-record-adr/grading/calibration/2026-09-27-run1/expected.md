# 期待する判定

この較正の資料は、2026-09-27 の1回目の実行（claude plugin eval、`--runs 1 --ablation none`）で作られた ADR である。下の判定は、eval を組んだ担当が資料と素材を読んで出したもので、採点役がこれを再現できるかで採点の形を確かめる。境目と書いた条件は、読み方で判定が分かれうるので、一致の数を別に数える。採点役には、このファイルを読ませない。

## 判定

- fact-from-material: PASS
- certainty-marked: PASS
- no-work-log: PASS（境目）
- main-message-first: FAIL（境目）
- headings-and-prose: PASS
- headings-conclusion: FAIL
- no-empty-sections: PASS
- terms-consistent: PASS
- decision-state: PASS
- rejected-options-reasoned: PASS
- separate-decisions-kept-apart: PASS

## 理由

headings-conclusion は、節の見出しが「決定」「なぜ決める必要があったか」「判断基準と比較」のようにテンプレートのラベルのままで、どの節の見出しにも結論が入っていないので FAIL とした。

no-work-log は、「内部監査室がこの点を指摘し」「開発チームからは…懸念が出たが」が、誰が何を言ったかという経緯に近い。一方で、退けた理由の出どころや、測っていない見込みであることを示す文として読み手の判断にも要るので PASS としたが、読み方で分かれるので境目とした。

main-message-first は、冒頭の段落が承認済みであることと決めた人を述べるだけで、何を選んだか（判断した人と本人の両方を判断の時点の値で記録する）を本文で述べておらず、主メッセージは H1 にしか無いので FAIL とした。最初はこれを PASS と置いたが、採点役が三回とも FAIL とし、その根拠のほうが条件の文に合っていた。H1 を冒頭の一部と読めば PASS にもなるので、境目とした。
