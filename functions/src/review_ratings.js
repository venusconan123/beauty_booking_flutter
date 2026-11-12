'use strict';
const { HttpsError } = require('firebase-functions/v2/https');
const validId = value => typeof value === 'string' && /^[A-Za-z0-9_-]{1,128}$/.test(value);

// Legacy employee.rating/reviewCount values are deliberately never read here.
// Join each review to its completed booking so a forged barberId cannot affect
// another employee. One document keyed by booking ID counts as one review.
async function employeeRatings(db, employeeIds) {
  const ids = [...new Set(employeeIds)];
  if (!ids.length) return [];
  const wanted = new Set(ids);
  return db.runTransaction(async tx => {
    const snapshot = await tx.get(db.collection('reviews'));
    const reviews = snapshot.docs.filter(row => {
      const r = row.data();
      return validId(row.id) && r.bookingId === row.id && wanted.has(r.barberId) &&
        typeof r.userId === 'string' && r.userId.length > 0 &&
        typeof r.salonId === 'string' && r.salonId.length > 0 &&
        Number.isInteger(r.barberRating) && r.barberRating >= 1 && r.barberRating <= 5;
    });
    const bookings = new Map();
    for (let offset = 0; offset < reviews.length; offset += 100) {
      const rows = await tx.getAll(...reviews.slice(offset, offset + 100).map(row => db.doc(`bookings/${row.id}`)));
      for (const row of rows) if (row.exists) bookings.set(row.id, row.data());
    }
    const totals = new Map(ids.map(id => [id, { employeeId: id, rating: 0, reviewCount: 0, ratingSum: 0 }]));
    for (const row of reviews) {
      const r = row.data(), booking = bookings.get(row.id);
      if (!booking || booking.status !== 'completed' || booking.demoFixture ||
          booking.userId !== r.userId || booking.barberId !== r.barberId ||
          booking.salonId !== r.salonId) continue;
      const total = totals.get(r.barberId);
      total.reviewCount++;
      total.ratingSum += r.barberRating;
    }
    return [...totals.values()].map(total => ({ ...total,
      rating: total.reviewCount ? total.ratingSum / total.reviewCount : 0 }));
  });
}

function createReviewRatingHandlers(db, auth) {
  return {
    async getBarberRatings(request) {
      if (!request.auth) throw new HttpsError('unauthenticated', 'Vui lòng đăng nhập.');
      const user = await auth.getUser(request.auth.uid);
      if (user.disabled) throw new HttpsError('permission-denied', 'Tài khoản đã ngừng hoạt động.');
      const ids = request.data?.employeeIds;
      if (!Array.isArray(ids) || ids.length > 100 || ids.some(id => !validId(id))) {
        throw new HttpsError('invalid-argument', 'Danh sách nhân viên không hợp lệ.');
      }
      return { ratings: await employeeRatings(db, ids) };
    },
  };
}

module.exports = { employeeRatings, createReviewRatingHandlers };
