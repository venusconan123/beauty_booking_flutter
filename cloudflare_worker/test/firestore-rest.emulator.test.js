import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { RestFirestore, rosterHints } from '../src/firestore-rest.js';
import { RestAuth } from '../src/staff-scheduling.js';
const require = createRequire(new URL('../../functions/package.json', import.meta.url));
const enabled = process.env.FIRESTORE_EMULATOR_HOST === '127.0.0.1:8180';
let sdk, auth, app;
const projectId = 'demo-men-hair-booking';
const config = { projectId, baseUrl: 'http://127.0.0.1:8180/v1', tokenProvider: async () => 'owner' };
const restAuth = new RestAuth({ projectId, baseUrl: 'http://127.0.0.1:9199/identitytoolkit.googleapis.com/v1', tokenProvider: async () => 'owner' });
const { createSchedulingHandlers, dayStart } = require('./src/scheduling');
const { createStaffHandlers } = require('./src/staff');
const { createReviewRatingHandlers } = require('./src/review_ratings');
let now = Date.UTC(2030, 0, 1), serial = 0;
const request = (uid, data) => ({ auth: { uid }, data: { ...data, requestId: data.requestId || `rest-${++serial}` } });
const api = (hints = {}) => createSchedulingHandlers(new RestFirestore({ ...config, hints }), restAuth, { clock: () => now });
before(async () => {
  if (!enabled) return;
  assert.equal(process.env.GCLOUD_PROJECT, projectId);
  assert.equal(process.env.FIREBASE_AUTH_EMULATOR_HOST, '127.0.0.1:9199');
  app = require('firebase-admin/app').initializeApp({ projectId }, 'rest-tests');
  sdk = require('firebase-admin/firestore').getFirestore(app); auth = require('firebase-admin/auth').getAuth(app);
  for (const uid of ['rest-admin', 'rest-customer']) await auth.createUser({ uid, email: `${uid}@example.test`, emailVerified: true });
  await sdk.doc('admins/rest-admin').set({ name: 'REST admin' });
  await sdk.doc('users/rest-customer').set({ name: 'REST customer', email: 'rest-customer@example.test', phone: '0901234567' });
  await sdk.doc('app_settings/scheduling_v2').set({ protocolVersion: 2, staffWritesEnabled: true, bookingWritesEnabled: true, rosterWritesEnabled: true });
  await sdk.doc('employees/rest-employee').set({ name: 'REST employee', salonId: 'salon_01', isActive: true });
  await sdk.doc('employees/rest-monthly').set({ name: 'REST monthly', salonId: 'salon_02', isActive: true });
  await sdk.doc('services/rest-cut').set({ name: 'REST cut', price: 110000, durationMinutes: 50, isActive: true });
});
after(async () => { if (app) await require('firebase-admin/app').deleteApp(app); });

test('REST adapter: Auth provisioning, booking, assigned staff, one admin receipt and immutable audit', { skip: !enabled }, async () => {
  const staff = createStaffHandlers(new RestFirestore(config), restAuth);
  const data = { email: 'rest-worker@example.test', password: 'Rest-demo-123!', employeeId: 'rest-employee' };
  const provisioned = await staff.createStaffAccount(request('rest-admin', data));
  assert.equal(provisioned.created, true);
  assert.equal(provisioned.requiresEmailVerification, true);
  await assert.rejects(staff.createStaffAccount(request('rest-admin', { ...data, password: '' })), error =>
    error.code === 'already-exists' && error.message === 'Email này đã được sử dụng.');
  await assert.rejects(staff.createStaffAccount(request('rest-admin', { ...data,
    email: 'rest-customer@example.test', employeeId: 'rest-monthly' })), error =>
    error.code === 'already-exists' && error.message === 'Email này đã được sử dụng.');
  assert.equal((await sdk.doc('staff_accounts/rest-customer').get()).exists, false);
  assert.equal((await sdk.doc('employee_accounts/rest-monthly').get()).exists, false);
  await auth.updateUser(provisioned.uid, { emailVerified: true });
  await api().saveShifts(request('rest-admin', { employeeId: 'rest-employee', salonId: 'salon_01', dates: ['2030-01-02'], startMinute: 420, endMinute: 1320 }));
  const availability = await api().getAvailability(request('rest-customer', { salonId: 'salon_01', barberId: 'rest-employee', dateKey: '2030-01-02', serviceIds: ['rest-cut'] }));
  assert.ok(availability.slots.some((slot) => slot.time === '09:00'));
  assert.ok((await api().listBookableStaff(request('rest-customer', { salonId: 'salon_01' }))).employees.some((employee) => employee.id === 'rest-employee'));
  const slot = dayStart('2030-01-02') + 540 * 60000;
  const bookingRequest = request('rest-customer', { barberId: 'rest-employee', salonId: 'salon_01', serviceIds: ['rest-cut'], appointmentAt: slot, userPhone: '0901234567', paymentChoice: 'pay_later' });
  const created = await api().createBooking(bookingRequest);
  assert.equal((await api().createBooking(bookingRequest)).bookingId, created.bookingId);
  now = slot + 1000;
  await assert.rejects(api().recordBookingPayment(request('rest-admin', { bookingId: created.bookingId, expectedAmount: 110000, method: 'cash' })), (error) => error.code === 'failed-precondition');
  await api().changeBookingStatus(request(provisioned.uid, { bookingId: created.bookingId, status: 'in_service' }));
  await api().changeBookingStatus(request(provisioned.uid, { bookingId: created.bookingId, status: 'completed' }));
  const unpaid = (await sdk.doc(`bookings/${created.bookingId}`).get()).data();
  assert.equal(unpaid.payment.status, 'unpaid');
  const collection = request('rest-admin', { bookingId: created.bookingId, expectedAmount: 110000, method: 'cash' });
  await api().recordBookingPayment(collection);
  const receipts = await Promise.all([api().recordBookingPayment(collection), api().recordBookingPayment(request('rest-admin', { ...collection.data, requestId: 'rest-concurrent-payment' }))]);
  assert.equal(receipts[0].receiptId, receipts[1].receiptId);
  const paid = (await sdk.doc(`bookings/${created.bookingId}`).get()).data();
  assert.equal(paid.payment.status, 'paid'); assert.equal(paid.payment.amount, 110000);
  assert.equal(paid.payment.choice, 'pay_later'); assert.equal(paid.payment.receipt.recordedBy, 'rest-admin');
  assert.ok(paid.payment.receipt.recordedAt.toMillis() > 0);
  const audit = await sdk.collection('audit_events').where('action', '==', 'booking.payment.record').get();
  assert.equal(audit.docs.filter((row) => row.data().after.bookingId === created.bookingId).length, 1);
  const query = await new RestFirestore(config).collection('bookings').where('barberId', '==', 'rest-employee').get();
  assert.equal(query.docs.find((row) => row.id === created.bookingId).data().payment.status, 'paid');
});
test('REST adapter: same-day swap exchanges both employees and bumps each day guard once', { skip: !enabled }, async () => {
  now = Date.UTC(2030, 0, 1);
  const date = '2030-01-04', workers = ['rest-swap-a', 'rest-swap-b'];
  for (const id of workers) await sdk.doc(`employees/${id}`).set({ name: id, salonId: 'salon_01', isActive: true });
  const shifts = [];
  for (const [index, employeeId] of workers.entries()) {
    shifts.push((await api().saveShifts(request('rest-admin', { employeeId, salonId: 'salon_01', dates: [date],
      startMinute: index ? 840 : 420, endMinute: index ? 1320 : 900 }))).shiftIds[0]);
  }
  const before = await Promise.all(workers.map(async id => (await sdk.doc(`employee_days/${id}_${date}`).get()).data().version));
  const data = request('rest-admin', { shiftAId: shifts[0], shiftBId: shifts[1], revisionA: 1, revisionB: 1 });
  const result = await api().swapShifts(data);
  assert.deepEqual(await api().swapShifts(data), result);
  for (const [index, id] of shifts.entries()) {
    const saved = (await sdk.doc(`work_shifts/${id}`).get()).data();
    assert.equal(saved.employeeId, workers[1 - index]);
    assert.equal(saved.dateKey, date);
    assert.equal(saved.revision, 2);
    assert.equal((await sdk.doc(`employee_days/${workers[index]}_${date}`).get()).data().version, before[index] + 1);
  }
});

test('REST adapter: real review aggregates validate bookings, batch over 100 reviews and track edits', { skip: !enabled }, async () => {
  const employeeId = 'rest-rating-worker';
  const batch = sdk.batch();
  await sdk.doc(`employees/${employeeId}`).set({ salonId: 'salon_01', rating: 4.9, reviewCount: 119 });
  for (let i = 0; i < 101; i++) {
    const id = `rest-rating-book-${i}`;
    batch.set(sdk.doc(`bookings/${id}`), { userId: 'rest-customer', barberId: employeeId, salonId: 'salon_01', status: 'completed' });
    batch.set(sdk.doc(`reviews/${id}`), { bookingId: id, userId: 'rest-customer', barberId: employeeId, salonId: 'salon_01', barberRating: 5 });
  }
  await batch.commit();
  let requests = 0;
  const db = new RestFirestore({ ...config, fetchImpl: async (...args) => { requests++; return fetch(...args); } });
  const api = createReviewRatingHandlers(db, restAuth);
  const data = request('rest-customer', { employeeIds: [employeeId] });
  assert.deepEqual((await api.getBarberRatings(data)).ratings[0], { employeeId, rating: 5, reviewCount: 101, ratingSum: 505 });
  assert.ok(requests < 10, `${requests} Firestore requests`);
  await sdk.doc('reviews/rest-rating-book-0').update({ barberRating: 1 });
  assert.deepEqual((await api.getBarberRatings(data)).ratings[0], { employeeId, rating: 501 / 101, reviewCount: 101, ratingSum: 501 });
  assert.equal((await sdk.doc(`employees/${employeeId}`).get()).data().reviewCount, 119);
});

test('REST adapter: a full month is atomic and fits the Workers Free HTTP budget', { skip: !enabled }, async () => {
  now = Date.UTC(2030, 0, 1);
  const cells = Array.from({ length: 31 }, (_, i) => ({ employeeId: 'rest-monthly', dateKey: `2030-02-${String(i + 1).padStart(2, '0')}`, expected: [] }));
  // Use a real 31-day month; invalid calendar dates remain rejected by shared handlers.
  cells.forEach((cell) => { cell.dateKey = cell.dateKey.replace('2030-02', '2030-03'); });
  let requests = 0;
  const db = new RestFirestore({ ...config, hints: rosterHints({ cells }), fetchImpl: async (...args) => { requests++; return fetch(...args); } });
  await createSchedulingHandlers(db, restAuth, { clock: () => now }).saveRoster(request('rest-admin', {
    salonId: 'salon_02', cells, shift: { kind: 'work', code: 'F', startMinute: 420, endMinute: 1320 },
  }));
  const shifts = await sdk.collection('work_shifts').where('employeeId', '==', 'rest-monthly').get();
  assert.equal(shifts.docs.filter((row) => row.data().status === 'scheduled').length, 31);
  assert.ok(requests < 40, `${requests} Firestore requests leaves room for Auth and OAuth`);
});
