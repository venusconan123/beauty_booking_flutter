'use strict';
const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
assert.equal(process.env.GCLOUD_PROJECT, 'demo-men-hair-booking');
assert.equal(process.env.FIRESTORE_EMULATOR_HOST, '127.0.0.1:8180');
assert.equal(process.env.FIREBASE_AUTH_EMULATOR_HOST, '127.0.0.1:9199');
const { initializeApp, deleteApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { getAuth } = require('firebase-admin/auth');
const { createReviewRatingHandlers } = require('../src/review_ratings');
const { createSchedulingHandlers } = require('../src/scheduling');
const app = initializeApp({ projectId: 'demo-men-hair-booking' }, 'review-rating-tests');
const db = getFirestore(app), auth = getAuth(app);
const api = createReviewRatingHandlers(db, auth);
let serial = 0;
const request = ids => ({ auth: { uid: 'rating-customer' }, data: { employeeIds: ids } });
async function worker() {
  const id = `rating-worker-${++serial}`;
  await db.doc(`employees/${id}`).set({ salonId: 'salon_01', name: id, isActive: true, rating: 4.9, reviewCount: 119 });
  return id;
}
async function review(employeeId, score, bookingChanges = {}, reviewChanges = {}) {
  const id = `rating-booking-${++serial}`;
  await db.doc(`bookings/${id}`).set({ userId: 'rating-customer', barberId: employeeId, salonId: 'salon_01', status: 'completed', ...bookingChanges });
  await db.doc(`reviews/${id}`).set({ bookingId: id, userId: 'rating-customer', barberId: employeeId, salonId: 'salon_01', barberRating: score, ...reviewChanges });
  return id;
}
before(async () => {
  await auth.createUser({ uid: 'rating-customer', email: 'rating-customer@example.test', emailVerified: true });
  await auth.createUser({ uid: 'rating-disabled', email: 'rating-disabled@example.test', disabled: true });
});
after(async () => deleteApp(app));

test('review ratings: no reviews means zero, not the seeded 4.9/119; reads never change profile data', async () => {
  const id = await worker(), before = (await db.doc(`employees/${id}`).get()).data();
  assert.deepEqual((await api.getBarberRatings(request([id]))).ratings, [{ employeeId: id, rating: 0, reviewCount: 0, ratingSum: 0 }]);
  assert.deepEqual((await db.doc(`employees/${id}`).get()).data(), before);
});

test('review ratings: average/count follow creation, edits and deletion without duplicate counting', async () => {
  const id = await worker();
  await review(id, 5); const second = await review(id, 4); await review(id, 3);
  const load = async () => (await api.getBarberRatings(request([id]))).ratings[0];
  assert.deepEqual(await load(), { employeeId: id, rating: 4, reviewCount: 3, ratingSum: 12 });
  await db.doc(`reviews/${second}`).update({ barberRating: 2 });
  assert.deepEqual(await load(), { employeeId: id, rating: 10 / 3, reviewCount: 3, ratingSum: 10 });
  assert.deepEqual(await load(), await load());
  await db.doc(`reviews/${second}`).delete();
  assert.deepEqual(await load(), { employeeId: id, rating: 4, reviewCount: 2, ratingSum: 8 });
  await db.doc(`employees/${id}`).update({ rating: 5, reviewCount: 999999 });
  assert.equal((await load()).reviewCount, 2);
});

test('review ratings: ignores missing, unfinished, demo, forged-owner/employee/branch and malformed reviews', async () => {
  const id = await worker();
  await review(id, 5, { status: 'confirmed' });
  await review(id, 5, { demoFixture: 'explicit-test' });
  await review(id, 5, {}, { userId: 'another-customer' });
  await review(id, 5, { barberId: 'another-worker' });
  await review(id, 5, {}, { salonId: 'salon_03' });
  await review(id, 6); await review(id, 2.5);
  await review(id, 5, {}, { bookingId: 'different-booking' });
  const missing = await review(id, 5); await db.doc(`bookings/${missing}`).delete();
  await review(id, 4);
  assert.deepEqual((await api.getBarberRatings(request([id]))).ratings[0], { employeeId: id, rating: 4, reviewCount: 1, ratingSum: 4 });
});

test('review ratings: authenticates callers and validates bounded employee IDs', async () => {
  await assert.rejects(api.getBarberRatings({ data: { employeeIds: [] } }), e => e.code === 'unauthenticated');
  await assert.rejects(api.getBarberRatings({ auth: { uid: 'rating-disabled' }, data: { employeeIds: [] } }), e => e.code === 'permission-denied');
  for (const ids of [undefined, ['../injection'], Array(101).fill('worker'), [{}]]) {
    await assert.rejects(api.getBarberRatings(request(ids)), e => e.code === 'invalid-argument');
  }
  assert.deepEqual(await api.getBarberRatings(request([])), { ratings: [] });
});

test('review ratings: bookable-staff endpoint also replaces manual values with verified review statistics', async () => {
  const id = await worker(); await review(id, 3);
  await db.doc(`work_shifts/rating-shift-${id}`).set({ employeeId: id, salonId: 'salon_01', dateKey: '2030-01-02', status: 'scheduled' });
  const scheduling = createSchedulingHandlers(db, auth, { clock: () => Date.UTC(2030, 0, 1) });
  const employees = (await scheduling.listBookableStaff({ auth: { uid: 'rating-customer' }, data: { salonId: 'salon_01' } })).employees;
  const row = employees.find(e => e.id === id);
  assert.equal(row.rating, 3); assert.equal(row.reviewCount, 1);
});
