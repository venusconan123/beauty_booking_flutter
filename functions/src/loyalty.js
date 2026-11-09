'use strict';
const { FieldValue } = require('firebase-admin/firestore');

// Preserve the existing admin-completion rewards, but commit them with status.
// No completion statistics/ledger or new staff workflow is introduced here.
async function prepareLoyalty(tx, db, bookingId, booking) {
  const settings = (await tx.get(db.doc('app_settings/loyalty'))).data() || {};
  const number = (value, fallback, max = Number.MAX_SAFE_INTEGER) =>
    Math.max(1, Math.min(max, Number.isFinite(value) ? Math.floor(value) : fallback));
  const legacy = settings.isEnabled !== false;
  const visitsEnabled = settings.visitRewardEnabled ?? (legacy && settings.rewardType !== 'minimum_order');
  const ordersEnabled = settings.orderRewardEnabled ?? (legacy && settings.rewardType === 'minimum_order');
  const requiredVisits = number(settings.requiredVisits, 10);
  const minimumOrder = number(settings.minimumOrderAmount, 500000);
  const legacyDiscount = number(settings.discountPercent, 25, 100);
  const candidates = [];
  if (ordersEnabled && (booking.totalPrice ?? booking.price ?? 0) >= minimumOrder) {
    candidates.push({ id: `loyalty_order_${bookingId}`, code: 'CHITIEU', rewardType: 'minimum_order',
      discountPercent: number(settings.orderDiscountPercent, legacyDiscount, 100), title: 'Ưu đãi cho đơn hàng đủ điều kiện' });
  }
  if (visitsEnabled) {
    const history = await tx.get(db.collection('bookings').where('userId', '==', booking.userId).where('status', '==', 'completed'));
    const completed = history.docs.filter((d) => d.id !== bookingId && d.data().status === 'completed').length + 1;
    if (completed >= requiredVisits) {
      const milestone = Math.floor(completed / requiredVisits);
      candidates.push({ id: `loyalty_visit_${requiredVisits}_${milestone}`, code: `TRI_AN${milestone * requiredVisits}LAN`,
        rewardType: 'visit_count', milestone, discountPercent: number(settings.visitDiscountPercent, legacyDiscount, 100),
        title: `Tri ân ${milestone * requiredVisits} lần sử dụng dịch vụ` });
    }
  }
  const refs = candidates.map((v) => db.doc(`users/${booking.userId}/vouchers/${v.id}`));
  const existing = refs.length ? await tx.getAll(...refs) : [];
  return () => {
    candidates.forEach(({ id, ...voucher }, index) => {
      if (existing[index].exists) return;
      const stamp = FieldValue.serverTimestamp();
      tx.create(refs[index], { ...voucher, description: voucher.title, minOrderAmount: 0,
        isActive: true, isUsed: false, source: 'loyalty', sourceBookingId: bookingId, createdAt: stamp, updatedAt: stamp });
      tx.set(db.doc(`users/${booking.userId}/notifications/voucher_${id}`), {
        type: 'voucher_received', title: `Bạn vừa nhận voucher giảm ${voucher.discountPercent}%`,
        message: voucher.title, voucherId: id, createdAt: stamp,
      });
    });
  };
}
module.exports = { prepareLoyalty };
