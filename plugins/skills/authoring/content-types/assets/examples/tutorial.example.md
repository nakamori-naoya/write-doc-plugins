# 予約の作成から取消までを体験する

> [`tutorial.md`](../templates/tutorial.md)の記載例。架空のRoomFlowの予約状態を、単体のPython教材で試す。実サービスのAPI、永続化、認証、予約資格を実装した教材ではない。

同じ予約を仮押さえ・確定・取消へ進め、表示の変化を自分で確かめる。完走すると、「仮押さえの期限」と「会議室の利用時間」を区別し、期限より前に確定する意味を説明できる。

## 始める状態をそろえる

Python 3を使う。空の練習用directoryに、次を`reservation_demo.py`として保存する。教材の時刻は分単位の整数で、10時を600として扱う。実際に15分待つ必要はない。

```python
# 練習用の一予約。利用枠は明日の10:00〜11:30で固定する。
def hold(now):
    return {"status": "仮押さえ", "expires": now + 15,
            "slot": "明日10:00〜11:30"}


def confirm(reservation, now):
    if reservation["status"] != "仮押さえ":
        raise ValueError("確定の対象は仮押さえだけ")
    if now >= reservation["expires"]:
        reservation["status"] = "期限切れ"
    else:
        reservation["status"] = "確定"
    return reservation["status"]


def cancel(reservation):
    if reservation["status"] != "確定":
        raise ValueError("この教材の取消対象は確定予約だけ")
    reservation["status"] = "取消済み"
    return reservation["status"]
```

この教材は、確定の操作時に期限を判定する。実サービスのように時刻到来を自動処理するものではない。取消も、利用開始前の確定予約を取り消す一場面に限っている。

保存したdirectoryで`python3 -i reservation_demo.py`を実行する。`>>>`が表示されたら、以下のPython式を順に入力する。ファイルが読み込めなければ、その先へ進まず保存先とファイル名を確認する。

## 体験する

### 1. 仮押さえ予約を作る

```python
reservation = hold(600)
print(reservation)
```

`status`は`仮押さえ`、`expires`は`615`、`slot`は`明日10:00〜11:30`となる。600は今日10時、615は今日10時15分である。

明日の90分間を使う予約について、今日の15分間だけ確定を待つ状態ができた。この後も、同じ変数`reservation`を使う。

### 2. 期限前に確定する

```python
print(confirm(reservation, 610))
print(reservation["slot"])
```

`確定`と`明日10:00〜11:30`が表示される。今日10時10分に確定しても、明日の利用枠は変わらない。

変わったのは利用時間ではなく、保留から約束へ進んだ予約の状態である。教材には期限の値が残るが、確定予約をその時刻に消す処理はない。

### 3. 確定予約を取り消す

```python
print(cancel(reservation))
```

`取消済み`となる。仮押さえから確定を経て、同じ予約の状態が変わったことを確認できた。実サービスでの利用枠の解放や履歴保存は、この教材では再現していない。

## 理解を確かめる

今度は、期限時刻ちょうどの確定が通るか予測してから試す。

```python
another = hold(660)
print(another["expires"])
print(confirm(another, 675))
```

期限は`675`、確定結果は`期限切れ`となる。11時に仮押さえした場合も、11時15分ちょうどは確定の猶予を過ぎた側として扱う。コードの`now >= reservation["expires"]`がその境界を表している。

- なぜ明日の利用枠は15分にならないか。`expires`は確定の猶予で、利用枠は別の`slot`にあるため。
- 確定した予約も15分で消えるか。この教材では消えない。期限判定は仮押さえを確定する操作にだけ使う。
- 仮押さえの取消も、この教材から判断できるか。できない。教材の取消は確定予約の一場面に絞っているため、業務全体の判断には正本が必要である。

## 片付けと次の作業

`exit()`でPythonを終了する。予約はメモリ上だけにあり、サーバーやDBにデータは作っていない。教材を残す必要がなければ、自分で作った`reservation_demo.py`だけを削除する。

業務の判断を詳しく知るなら[業務知識](domain-rule.example.md)へ進む。実際の操作の組み立て方は[予約のハウツー](how-to.example.md)で確認できる。
