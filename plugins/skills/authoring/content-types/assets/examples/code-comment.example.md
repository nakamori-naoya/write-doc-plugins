# コードコメントの記載例

> これは [`code-comment.md`](../templates/code-comment.md) の記載例である。型が資料本文ではなくコード断片なので、会議室予約の競合制御に適したコメントを示す。

```typescript
// なぜ: 空き確認だけでは、同時要求が同じ会議室の重なる時間を占有し得るためDB制約へ委ねる。
// 前提: room_booking_claimsには会議室と半開時間範囲のGiST排他制約がある。
// 注意: SQLSTATE 23P01だけをSLOT_UNAVAILABLEへ変換し、transaction全体をrollbackする。
// 解消条件: 一つの会議室を同時に複数顧客へ販売する業務へ変わったとき。
await reservationRepository.createTentativeHold(input);
```

このコメントは処理を読み上げず、コードだけでは復元できない理由、前提、危険、見直し条件を残している。
