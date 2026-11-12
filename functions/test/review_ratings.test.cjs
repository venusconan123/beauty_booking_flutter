'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { employeeRatings } = require('../src/review_ratings');

test('reviews with a missing branch on both review and booking are not treated as verified', async () => {
  const owner = { userId: 'customer', barberId: 'worker' };
  const reviews = [
    { id: 'missing-branch', data: () => ({ ...owner, bookingId: 'missing-branch', barberRating: 5 }) },
    { id: 'valid', data: () => ({ ...owner, bookingId: 'valid', salonId: 'salon_01', barberRating: 3 }) },
  ];
  const bookings = new Map([
    ['missing-branch', { ...owner, status: 'completed' }],
    ['valid', { ...owner, status: 'completed', salonId: 'salon_01' }],
  ]);
  const db = {
    collection: () => 'reviews', doc: path => path.split('/').at(-1),
    runTransaction: async callback => callback({
      get: async () => ({ docs: reviews }),
      getAll: async (...ids) => ids.map(id => ({ id, exists: bookings.has(id), data: () => bookings.get(id) })),
    }),
  };
  assert.deepEqual(await employeeRatings(db, ['worker', 'worker', 'unrated']), [
    { employeeId: 'worker', rating: 3, reviewCount: 1, ratingSum: 3 },
    { employeeId: 'unrated', rating: 0, reviewCount: 0, ratingSum: 0 },
  ]);
});
