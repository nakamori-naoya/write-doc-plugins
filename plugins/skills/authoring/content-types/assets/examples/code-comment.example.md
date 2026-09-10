# コードコメントの記載例

> これは`code-comment`型の記載例である。**構成の正本ではなく、粒度と具体性の見本として読む。**コードと業務前提は架空であり、予約作成を変更する開発者が、維持すべき境界をその場で読めるコメントを示す。掲載箇所は`src/reservations/create_tentative_hold.ts`で、[コード地図](code-map.example.md)の`src/reservations/`にある。

```typescript
// なぜ: 空き確認だけでは、同時要求が同じ会議室の重なる時間を占有し得るためDB制約へ委ねる。
// 前提: 予約と占有を同じtransactionで保存し、失敗時は両方をrollbackする。
// 注意: repositoryは制約名を保持してエラーを返す。23P01だけで競合と決めない。
//       room_booking_claims_room_time_exclの違反だけをSLOT_UNAVAILABLEへ変換する。
// 見直す条件: 同じ会議室を同時に複数顧客へ販売する場合は、占有の制約から再設計する。
await reservationRepository.createTentativeHold(input);
```

`23P01`はこの例で扱うDBの排他制約違反を示すコードである。別の制約の違反まで「利用枠が埋まった」と返すと、異なる障害を隠す。コメントはこの危険と、予約だけが残る部分保存を避ける前提を呼び出し行の隣に残している。

見直す条件が成立しても、コメントだけを削除してよいわけではない。制約とエラー変換を一緒に検討する。具体的な差分注釈は[実装解説の例](pr-walkthrough.example.md)で示す。
