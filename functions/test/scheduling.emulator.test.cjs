'use strict';
const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
assert.equal(process.env.GCLOUD_PROJECT, 'demo-men-hair-booking');
assert.equal(process.env.FIRESTORE_EMULATOR_HOST, '127.0.0.1:8180');
assert.equal(process.env.FIREBASE_AUTH_EMULATOR_HOST, '127.0.0.1:9199');
const { initializeApp, deleteApp } = require('firebase-admin/app');
const { getFirestore, Timestamp } = require('firebase-admin/firestore');
const { getAuth } = require('firebase-admin/auth');
const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const { doc, getDoc, setDoc, updateDoc, deleteDoc, getDocs, collection, query, where } = require('firebase/firestore');
const { createSchedulingHandlers, dayStart } = require('../src/scheduling');
const app = initializeApp({ projectId: 'demo-men-hair-booking' }, 'scheduling-tests');
const db = getFirestore(app); const auth = getAuth(app);
const handlers = createSchedulingHandlers(db, auth, { clock: () => Date.UTC(2030, 0, 1) });
const d1 = '2030-01-02'; const d2 = '2030-01-03';
let n = 0; let env;
const request = (uid, data) => ({ auth: uid ? { uid } : null, data: { ...data, requestId: data.requestId ?? `s2-${++n}` } });
const admin = (data) => request('s2-admin', data);
const customer = (data) => request('s2-customer', data);
const denied = (promise, code) => assert.rejects(promise, (e) => e.code === code);
async function employee(salonId = 'salon_01') {
  const id = `s2-worker-${++n}`;
  await db.doc(`employees/${id}`).set({ name: id, salonId, isActive: true });
  return id;
}
async function shift(employeeId, date = d1, extra = {}) {
  const result = await handlers.saveShifts(admin({ employeeId, salonId: 'salon_01', dates: [date], startMinute: 540, endMinute: 1020, ...extra }));
  const ref = db.doc(`work_shifts/${result.shiftIds[0]}`); return { id: ref.id, ...(await ref.get()).data() };
}
function booking(employeeId, date = d1, minute = 540, extra = {}) {
  return { barberId: employeeId, salonId: 'salon_01', serviceIds: ['s2-cut'],
    appointmentAt: dayStart(date) + minute * 60000, userPhone: '0901234567', paymentChoice: 'pay_later', ...extra };
}
const readShift = (id) => db.doc(`work_shifts/${id}`).get();
before(async () => {
  env = await initializeTestEnvironment({ projectId: 'demo-men-hair-booking', firestore: {
    host: '127.0.0.1', port: 8180, rules: fs.readFileSync(path.join(__dirname, '../../firestore.rules'), 'utf8'),
  }});
  for (const uid of ['s2-admin', 's2-customer', 's2-staff']) await auth.createUser({ uid, email: `${uid}@example.test`, emailVerified: true });
  await db.doc('admins/s2-admin').set({ name: 'Admin' });
  await db.doc('users/s2-customer').set({ name: 'Khách', requiresEmailVerification: true });
  for (const [id, minutes, price] of [['s2-cut', 30, 80000], ['s2-wash', 20, 30000], ['s2-long', 90, 200000]]) {
    await db.doc(`services/${id}`).set({ name: id, price, durationMinutes: minutes, isActive: true });
  }
});
after(async () => { if (env) await env.cleanup(); await deleteApp(app); });

const cell = (employeeId, dateKey = d1, expected = []) => ({ employeeId, dateKey, expected });
const work = { kind: 'work', code: 'HC', startMinute: 540, endMinute: 1020 };
const roster = (cells, shift = { kind: 'off' }, extra = {}) => handlers.saveRoster(admin({ salonId: 'salon_01', cells, shift, ...extra }));

test('roster: admin authorization, strict cells, dates, revisions and code/hours', async () => {
  const e = await employee(); const data = { salonId: 'salon_01', cells: [cell(e)], shift: work };
  await denied(handlers.saveRoster(request(null, data)), 'unauthenticated');
  for (const uid of ['s2-staff', 's2-customer']) await denied(handlers.saveRoster(request(uid, data)), 'permission-denied');
  for (const cells of [[null], [cell(e), cell(e)], [cell(e, '2030-02-30')], [{ ...cell(e), startMinute: 540 }],
    [cell(e, d1, [{ id: 'x', revision: -1 }])], [cell(e, d1, [{ id: 'x', revision: 1 }, { id: 'x', revision: 1 }])]]) {
    await denied(roster(cells, work), 'invalid-argument');
  }
  await denied(roster([cell(e)], { ...work, code: 'S' }), 'invalid-argument');
  await denied(roster([cell(e)], { ...work, code: 'T', startMinute: 540.5 }), 'invalid-argument');
});

test('roster: multiple people/days persist OFF, replay returns same rows and booking is denied', async () => {
  const a = await employee(), b = await employee();
  const cells = [cell(a), cell(a, d2), cell(b), cell(b, d2)];
  const requestId = `roster-replay-${++n}`;
  const result = await roster(cells, { kind: 'off' }, { requestId });
  assert.equal(result.shiftIds.length, 4);
  assert.deepEqual(await roster(cells, { kind: 'off' }, { requestId }), result);
  const saved = await db.getAll(...result.shiftIds.map((id) => db.doc(`work_shifts/${id}`)));
  assert.ok(saved.every((row) => row.data().status === 'off' && row.data().shiftCode === 'OFF' && row.data().startMinute === undefined));
  assert.equal((await db.collection('work_shifts').where('employeeId', '==', a).get()).size, 2);
  await denied(handlers.createBooking(customer(booking(a))), 'failed-precondition');
});

test('roster: replace and clear OFF retain history and reject stale previews', async () => {
  const e = await employee(); const old = await shift(e);
  const off = await roster([cell(e, d1, [{ id: old.id, revision: 1 }])]);
  assert.equal((await readShift(old.id)).data().status, 'cancelled');
  assert.equal((await readShift(old.id)).data().revision, 2);
  assert.deepEqual((await readShift(off.shiftIds[0])).data().supersedes, [old.id]);
  await denied(roster([cell(e, d1, [{ id: old.id, revision: 1 }])], work), 'aborted');
  await handlers.cancelShift(admin({ shiftId: off.shiftIds[0], expectedRevision: 1 }));
  assert.equal((await readShift(off.shiftIds[0])).data().status, 'cancelled');
  const restored = await roster([cell(e)], work);
  assert.equal((await readShift(restored.shiftIds[0])).data().status, 'scheduled');
});

test('roster: OFF and overlapping hours conflict across ALL branches; disjoint hours remain allowed', async () => {
  const e = await employee();
  const foreign = await shift(e, d1, { salonId: 'salon_02', endMinute: 600 });
  await denied(roster([cell(e)]), 'already-exists');
  await denied(roster([cell(e)], work), 'already-exists');
  const later = await roster([cell(e)], { kind: 'work', code: 'C', startMinute: 840, endMinute: 1320 });
  await denied(roster([cell(e, d1, [{ id: later.shiftIds[0], revision: 1 }])]), 'already-exists');
  assert.equal((await readShift(foreign.id)).data().revision, 1);
});

test('roster: occupied cell blocks OFF/shortening and rolls back every cell in the batch', async () => {
  const a = await employee(), b = await employee(); const s = await shift(a);
  await handlers.createBooking(customer(booking(a)));
  await denied(roster([cell(b), cell(a, d1, [{ id: s.id, revision: 1 }])]), 'failed-precondition');
  assert.equal((await db.collection('work_shifts').where('employeeId', '==', b).get()).size, 0);
  assert.equal((await readShift(s.id)).data().revision, 1);
  await denied(roster([cell(a, d1, [{ id: s.id, revision: 1 }])], { kind: 'work', code: 'C', startMinute: 840, endMinute: 1320 }), 'failed-precondition');
});

test('roster: concurrent booking versus OFF cannot commit inconsistent results', async () => {
  const e = await employee(); const s = await shift(e);
  const results = await Promise.allSettled([
    handlers.createBooking(customer(booking(e))), roster([cell(e, d1, [{ id: s.id, revision: 1 }])]),
  ]);
  assert.equal(results.filter((r) => r.status === 'fulfilled').length, 1);
});

test('roster: concurrent cross-branch assignments and A/B target OFF are protected', async () => {
  const e = await employee();
  const results = await Promise.allSettled([roster([cell(e)]), roster([cell(e)], work, { salonId: 'salon_02' })]);
  assert.equal(results.filter((r) => r.status === 'fulfilled').length, 1);
  const aId = await employee(), bId = await employee();
  const a = await shift(aId), b = await shift(bId, d2);
  await roster([cell(aId, d2)]);
  await assert.rejects(handlers.swapShifts(admin({ shiftAId: a.id, shiftBId: b.id, revisionA: 1, revisionB: 1 })), (error) => {
    assert.equal(error.code, 'already-exists');
    for (const text of [aId, '03/01/2030', 'OFF', '00:00–24:00', '09:00–17:00', '30Shine 345 Nguyễn Văn Linh']) {
      assert.ok(error.message.includes(text), text);
    }
    return true;
  });
  assert.equal((await readShift(a.id)).data().employeeId, aId);
  assert.equal((await readShift(b.id)).data().employeeId, bId);
});

test('roster Rules: anonymous/foreign reads and all direct mutations fail closed', async () => {
  const e = await employee(); const result = await roster([cell(e)]); const ref = `work_shifts/${result.shiftIds[0]}`;
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), ref)));
  for (const uid of ['s2-admin', 's2-staff', 's2-customer']) {
    const client = env.authenticatedContext(uid, { email_verified: true }).firestore();
    await assertFails(updateDoc(doc(client, ref), { employeeId: 'forged', extra: 'x'.repeat(10000), createdAt: 'forged' }));
    await assertFails(deleteDoc(doc(client, ref)));
  }
});

test('admin-only shift writes and strict input validation', async () => {
  const e = await employee(); const data = { employeeId: e, salonId: 'salon_01', dates: [d1], startMinute: 540, endMinute: 1020 };
  await denied(handlers.saveShifts(request(null, data)), 'unauthenticated');
  for (const uid of ['s2-customer', 's2-staff']) await denied(handlers.saveShifts(request(uid, data)), 'permission-denied');
  for (const extra of [{ dates: ['2030-02-30'] }, { startMinute: 541 }, { endMinute: 500 }, { salonId: 'unknown' }, { dates: [d1, d1] }]) {
    await denied(handlers.saveShifts(admin({ ...data, ...extra })), 'invalid-argument');
  }
});

test('repeat dates are atomic, idempotent and reject collisions across branches', async () => {
  const e = await employee();
  const data = { employeeId: e, salonId: 'salon_01', dates: [d1, d2], startMinute: 540, endMinute: 1020, requestId: `repeat-${++n}` };
  const result = await handlers.saveShifts(admin(data));
  assert.deepEqual(await handlers.saveShifts(admin(data)), result);
  await denied(handlers.saveShifts(admin({ ...data, requestId: `different-${++n}`, salonId: 'salon_02' })), 'already-exists');
  const count = await db.collection('work_shifts').where('employeeId', '==', e).get(); assert.equal(count.size, 2);
  await denied(handlers.saveShifts(admin({ ...data, requestId: `partial-${++n}`, dates: ['2030-01-04', d1] })), 'already-exists');
  assert.equal((await db.collection('work_shifts').where('employeeId', '==', e).get()).size, 2);
  await denied(handlers.saveShifts(admin({ ...data, requestId: data.requestId, endMinute: 1080 })), 'already-exists');
});

test('edit versions, cancelled shift history and audit are retained', async () => {
  const e = await employee(); const s = await shift(e);
  await handlers.saveShifts(admin({ shiftId: s.id, expectedRevision: 1, employeeId: e, salonId: 'salon_02', dates: [d1], startMinute: 600, endMinute: 1080 }));
  await denied(handlers.cancelShift(admin({ shiftId: s.id, expectedRevision: 1 })), 'aborted');
  await handlers.cancelShift(admin({ shiftId: s.id, expectedRevision: 2 }));
  const row = (await readShift(s.id)).data(); assert.equal(row.status, 'cancelled'); assert.equal(row.revision, 3);
  assert.equal(row.createdAt.toMillis(), s.createdAt.toMillis());
});

test('booking needs active shift, correct branch, available time and full rounded duration', async () => {
  const e = await employee();
  await denied(handlers.createBooking(customer(booking(e))), 'failed-precondition');
  await shift(e, d1, { endMinute: 600 });
  await denied(handlers.createBooking(customer(booking(e, d1, 540, { expectedPrice: 1 }))), 'failed-precondition');
  await denied(handlers.createBooking(customer(booking(e, d1, 540, { salonId: 'salon_02' }))), 'failed-precondition');
  await denied(handlers.createBooking(customer(booking(e, d1, 510))), 'failed-precondition');
  await denied(handlers.createBooking(customer(booking(e, d1, 570, { serviceIds: ['s2-cut', 's2-wash'] }))), 'failed-precondition');
  const result = await handlers.createBooking(customer(booking(e, d1, 540, { serviceIds: ['s2-cut', 's2-wash'], totalPrice: 1, totalDurationMinutes: 1 })));
  const saved = (await db.doc(`bookings/${result.bookingId}`).get()).data();
  assert.equal(saved.totalPrice, 110000); assert.equal(saved.totalDurationMinutes, 50); assert.equal(saved.slotIds.length, 2);
  await denied(handlers.createBooking(customer(booking(e, d1, 570))), 'failed-precondition');
});

test('auto-assignment skips inactive employees and supports a shift outside the home branch', async () => {
  const inactive = await employee(); const active = await employee('salon_02');
  await shift(inactive, d1, { salonId: 'salon_03' }); await shift(active, d1, { salonId: 'salon_03' });
  await db.doc(`employees/${inactive}`).update({ isActive: false });
  const list = await handlers.listBookableStaff(customer({ salonId: 'salon_03' }));
  assert.ok(list.employees.every((p) => p.id !== inactive));
  const result = await handlers.createBooking(customer(booking(active, d1, 540, { salonId: 'salon_03', barberId: null })));
  assert.equal((await db.doc(`bookings/${result.bookingId}`).get()).data().barberId, active);
});

test('voucher ownership and server prices are revalidated; retries do not redeem twice', async () => {
  const e = await employee(); await shift(e);
  const key = `s2-personal-${++n}`;
  await db.doc(`users/s2-customer/vouchers/${key}`).set({ isActive: true, isUsed: false, discountPercent: 20, rewardType: 'visit_count' });
  const data = { ...booking(e), vouchers: [{ id: key, isPersonal: true }], requestId: `voucher-${++n}` };
  const first = await handlers.createBooking(customer(data));
  assert.deepEqual(await handlers.createBooking(customer(data)), first);
  assert.equal((await db.doc(`bookings/${first.bookingId}`).get()).data().totalPrice, 64000);
  assert.equal((await db.doc(`users/s2-customer/vouchers/${key}`).get()).data().usedBookingId, first.bookingId);
  await denied(handlers.createBooking(customer(booking(e, d1, 600, { vouchers: [{ id: key, isPersonal: true }] }))), 'failed-precondition');
});

test('service edit rechecks shift and other bookings; cancellation releases but never deletes history', async () => {
  const e = await employee(); await shift(e, d1, { endMinute: 660 });
  const first = await handlers.createBooking(customer(booking(e)));
  await handlers.createBooking(customer(booking(e, d1, 600)));
  await denied(handlers.updateBookingServices(customer({ bookingId: first.bookingId, serviceIds: ['s2-long'] })), 'failed-precondition');
  await handlers.changeBookingStatus(customer({ bookingId: first.bookingId, status: 'cancelled' }));
  const slots = await db.collection('booking_slots').where('bookingId', '==', first.bookingId).get();
  assert.ok(slots.size > 0); assert.ok(slots.docs.every((s) => s.data().state === 'released'));
  await handlers.createBooking(customer(booking(e)));
  assert.equal((await db.doc(`bookings/${first.bookingId}`).get()).data().status, 'cancelled');
});

test('shift cannot be shortened, moved or cancelled if it would strand a live booking', async () => {
  const e = await employee(); const s = await shift(e); await handlers.createBooking(customer(booking(e)));
  await denied(handlers.cancelShift(admin({ shiftId: s.id, expectedRevision: 1 })), 'failed-precondition');
  await denied(handlers.saveShifts(admin({ shiftId: s.id, expectedRevision: 1, employeeId: e, salonId: 'salon_02', dates: [d1], startMinute: 540, endMinute: 1020 })), 'failed-precondition');
  await handlers.saveShifts(admin({ shiftId: s.id, expectedRevision: 1, employeeId: e, salonId: 'salon_01', dates: [d1], startMinute: 510, endMinute: 1080 }));
});

test('A/B rejects EACH of A/day1, A/day2, B/day1, B/day2, even at another branch', async () => {
  for (const [which, date] of [[0, d1], [0, d2], [1, d1], [1, d2]]) {
    const ids = [await employee(), await employee()]; const a = await shift(ids[0]); const b = await shift(ids[1], d2);
    const ref = db.collection('bookings').doc();
    await ref.set({ barberId: ids[which], salonId: 'salon_03', userId: 's2-customer', status: 'pending',
      appointmentAt: Timestamp.fromMillis(dayStart(date) + 720 * 60000), totalDurationMinutes: 30 });
    await denied(handlers.swapShifts(admin({ shiftAId: a.id, shiftBId: b.id, revisionA: 1, revisionB: 1 })), 'failed-precondition');
    assert.equal((await readShift(a.id)).data().employeeId, ids[0]); assert.equal((await readShift(b.id)).data().employeeId, ids[1]);
  }
});

test('A/B swaps both shifts atomically, rejects overlapping target shifts and stale versions', async () => {
  const aId = await employee(); const bId = await employee(); const a = await shift(aId); const b = await shift(bId, d2);
  const clash = await shift(aId, d2, { startMinute: 900, endMinute: 1080, salonId: 'salon_03' });
  await assert.rejects(handlers.swapShifts(admin({ shiftAId: a.id, shiftBId: b.id, revisionA: 1, revisionB: 1 })), (error) => {
    assert.equal(error.code, 'already-exists');
    for (const text of [aId, '03/01/2030', '15:00–18:00', '09:00–17:00', '30Shine Sơn Trà (mô phỏng)', '30Shine 345 Nguyễn Văn Linh']) {
      assert.ok(error.message.includes(text), text);
    }
    return true;
  });
  assert.equal((await readShift(a.id)).data().employeeId, aId);
  await handlers.cancelShift(admin({ shiftId: clash.id, expectedRevision: 1 }));
  await handlers.swapShifts(admin({ shiftAId: a.id, shiftBId: b.id, revisionA: 1, revisionB: 1 }));
  assert.equal((await readShift(a.id)).data().employeeId, bId); assert.equal((await readShift(b.id)).data().employeeId, aId);
  await denied(handlers.swapShifts(admin({ shiftAId: a.id, shiftBId: b.id, revisionA: 1, revisionB: 1 })), 'aborted');
});

test('concurrent booking vs cancel/edit/swap cannot both commit an inconsistent schedule', async () => {
  for (const mode of ['cancel', 'edit', 'swap']) {
    const e = await employee(); const s = await shift(e); const other = await employee(); const b = await shift(other, d2);
    const mutation = () => mode === 'cancel' ? handlers.cancelShift(admin({ shiftId: s.id, expectedRevision: 1 })) :
      mode === 'edit' ? handlers.saveShifts(admin({ shiftId: s.id, expectedRevision: 1, employeeId: e,
        salonId: 'salon_01', dates: [d1], startMinute: 600, endMinute: 1020 })) :
      handlers.swapShifts(admin({ shiftAId: s.id, shiftBId: b.id, revisionA: 1, revisionB: 1 }));
    const result = await Promise.allSettled([handlers.createBooking(customer(booking(e))), mutation()]);
    assert.equal(result.filter((r) => r.status === 'fulfilled').length, 1, mode);
    const current = (await readShift(s.id)).data();
    if (result[0].status === 'fulfilled') assert.equal(current.employeeId, e);
  }
});

test('two simultaneous bookings for the same employee/time yield exactly one booking', async () => {
  const e = await employee(); await shift(e);
  const result = await Promise.allSettled([handlers.createBooking(customer(booking(e))), handlers.createBooking(customer(booking(e)))]);
  assert.equal(result.filter((r) => r.status === 'fulfilled').length, 1);
});

test('Rules: staff views only home-branch shifts, including monthly queries; clients cannot bypass guards', async () => {
  const own = await employee(); const peer = await employee(); const elsewhere = await employee('salon_02');
  const a = await shift(own, d1, { salonId: 'salon_03' }); const b = await shift(peer); const c = await shift(elsewhere, d1, { salonId: 'salon_02' });
  await db.doc('staff_accounts/s2-staff').set({ employeeId: own, active: true });
  await db.doc(`employee_accounts/${own}`).set({ uid: 's2-staff' });
  const staff = env.authenticatedContext('s2-staff', { email_verified: true }).firestore();
  await assertFails(getDoc(doc(staff, `work_shifts/${a.id}`)));
  await assertSucceeds(getDoc(doc(staff, `work_shifts/${b.id}`)));
  await assertFails(getDocs(query(collection(staff, 'work_shifts'), where('employeeId', '==', own))));
  await assertSucceeds(getDocs(query(collection(staff, 'work_shifts'), where('salonId', '==', 'salon_01'), where('dateKey', '>=', '2030-01-01'), where('dateKey', '<', '2030-02-01'))));
  await assertSucceeds(getDocs(query(collection(staff, 'work_shifts'), where('salonId', '==', 'salon_01'))));
  await assertFails(getDoc(doc(staff, `work_shifts/${c.id}`)));
  for (const uid of ['s2-staff', 's2-customer', 's2-admin']) {
    const client = env.authenticatedContext(uid, { email_verified: true }).firestore();
    await assertFails(setDoc(doc(client, 'work_shifts/forged'), { employeeId: own }));
    await assertFails(setDoc(doc(client, 'bookings/forged'), { barberId: own }));
    await assertFails(setDoc(doc(client, 'employee_days/forged'), { version: 1 }));
    await assertFails(setDoc(doc(client, 'booking_slots/forged'), { bookingId: 'forged' }));
    await assertFails(deleteDoc(doc(client, `employees/${own}`)));
  }
  await db.doc('staff_accounts/s2-staff').update({ active: false });
  await assertFails(getDoc(doc(staff, `work_shifts/${a.id}`)));
  const customerDb = env.authenticatedContext('s2-customer', { email_verified: true }).firestore();
  await assertFails(getDoc(doc(customerDb, `work_shifts/${b.id}`)));
});
