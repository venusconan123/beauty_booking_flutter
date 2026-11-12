'use strict';
const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

// Fail before constructing any SDK client if this is not a local demo suite.
const projectId = 'demo-men-hair-booking';
for (const [name, expected] of Object.entries({
  FIRESTORE_EMULATOR_HOST: '127.0.0.1:8180', FIREBASE_AUTH_EMULATOR_HOST: '127.0.0.1:9199',
})) {
  assert.equal(process.env[name], expected, `Refusing to run without local ${name}`);
}
assert.equal(process.env.GCLOUD_PROJECT, projectId, 'Only a demo project may be tested.');

const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const { doc, getDoc, getDocs, collection, query, where, setDoc, updateDoc, deleteDoc } = require('firebase/firestore');
const { initializeApp, deleteApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { getAuth } = require('firebase-admin/auth');
const { createStaffHandlers } = require('../src/staff');
const app = initializeApp({ projectId }, 'staff-tests');
const db = getFirestore(app);
const auth = getAuth(app);
const handlers = createStaffHandlers(db, auth);
let env;
const ctx = (uid, emailVerified = true) => env.authenticatedContext(uid, { email_verified: emailVerified }).firestore();
const request = (uid, data) => ({ auth: uid ? { uid } : null, data });
const rejectsCode = (promise, code) => assert.rejects(promise, (error) => error.code === code);

test('staff link write control rejects even an admin while preserving the existing account', async () => {
  const control = db.doc('app_settings/scheduling_v2');
  const account = db.doc('staff_accounts/staff-a');
  const before = (await account.get()).data();
  await control.set({ protocolVersion: 2, bookingWritesEnabled: true, rosterWritesEnabled: true, staffWritesEnabled: false });
  await rejectsCode(handlers.setStaffAccountActive(request('admin', { uid: 'staff-a', active: true })), 'failed-precondition');
  assert.deepEqual((await account.get()).data(), before);
  await control.update({ staffWritesEnabled: true });
});

test('Provisioning: only admin can create by email; denied requests create no Auth user', async () => {
  const data = { email: 'denied-provision@example.test', password: 'Initial-123!', employeeId: 'employee-a' };
  for (const uid of [null, 'customer', 'staff-a']) {
    await rejectsCode(handlers.createStaffAccount(request(uid, data)), uid ? 'permission-denied' : 'unauthenticated');
  }
  await assert.rejects(auth.getUserByEmail(data.email), e => e.code === 'auth/user-not-found');
});

test('Provisioning: pause and invalid employee prevent all Auth side effects', async () => {
  const data = { email: 'paused-provision@example.test', password: 'Initial-123!', employeeId: 'employee-a' };
  await db.doc('app_settings/scheduling_v2').update({ staffWritesEnabled: false });
  await rejectsCode(handlers.createStaffAccount(request('admin', data)), 'failed-precondition');
  await db.doc('app_settings/scheduling_v2').update({ staffWritesEnabled: true });
  await rejectsCode(handlers.createStaffAccount(request('admin', { ...data, employeeId: 'employee-off' })), 'failed-precondition');
  await rejectsCode(handlers.createStaffAccount(request('admin', { ...data, employeeId: 'missing' })), 'not-found');
  await assert.rejects(auth.getUserByEmail(data.email), e => e.code === 'auth/user-not-found');
});

test('Provisioning: creates a new email; duplicate creation preserves password and audit', async () => {
  await db.doc('employees/provision-worker').set({ name: 'New worker', salonId: 'salon_01', isActive: true });
  const data = { email: 'New.Worker@example.test', password: 'Initial-123!', employeeId: 'provision-worker' };
  const first = await handlers.createStaffAccount(request('admin', data));
  assert.equal(first.created, true);
  assert.equal(first.email, 'new.worker@example.test');
  assert.equal(first.requiresEmailVerification, true);
  const user = await auth.getUser(first.uid);
  assert.equal(user.emailVerified, false);
  assert.equal((await db.doc(`employee_accounts/${data.employeeId}`).get()).data().uid, first.uid);
  assert.equal((await db.doc(`staff_accounts/${first.uid}`).get()).data().email, first.email);
  assert.equal((await db.doc(`users/${first.uid}`).get()).exists, false);
  await auth.updateUser(first.uid, { password: 'Changed-123!' });
  await assert.rejects(handlers.createStaffAccount(request('admin', { ...data, password: 'Other-123!' })), error =>
    error.code === 'already-exists' && error.message === 'Email này đã được sử dụng.');
  assert.equal((await db.collection('audit_events').where('targetUid', '==', first.uid).get()).size, 1);
  const login = await fetch('http://127.0.0.1:9199/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=demo-key', {
    method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email: first.email, password: 'Changed-123!', returnSecureToken: true }),
  });
  assert.equal(login.status, 200);
  for (const password of ['Changed-123!', 'Another-123!']) {
    const signup = await fetch('http://127.0.0.1:9199/identitytoolkit.googleapis.com/v1/accounts:signUp?key=demo-key', {
      method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: first.email, password, returnSecureToken: true }),
    });
    assert.equal(signup.status, 400);
    assert.equal((await signup.json()).error.message, 'EMAIL_EXISTS');
  }
  assert.equal((await db.doc(`users/${first.uid}`).get()).exists, false);
  await db.doc('work_shifts/provision-shift').set({ employeeId: data.employeeId, salonId: 'salon_01', dateKey: '2026-12-01' });
  await assertFails(getDocs(query(collection(ctx(first.uid, false), 'work_shifts'), where('salonId', '==', 'salon_01'))));
  await auth.updateUser(first.uid, { emailVerified: true });
  await assertSucceeds(getDocs(query(collection(ctx(first.uid), 'work_shifts'), where('salonId', '==', 'salon_01'))));
  await assertFails(getDocs(query(collection(ctx(first.uid), 'work_shifts'), where('salonId', '==', 'salon_02'))));
});

test('Provisioning: rejects every existing email without converting customer, admin or unverified identities', async () => {
  for (const id of ['existing-worker', 'admin-worker', 'conflict-worker']) {
    await db.doc(`employees/${id}`).set({ name: id, salonId: 'salon_01', isActive: true });
  }
  for (const uid of ['customer', 'admin', 'unverified', 'auth-disabled', 'staff-a']) {
    const old = (await db.doc(`staff_accounts/${uid}`).get()).data();
    await assert.rejects(handlers.createStaffAccount(request('admin', { email: ` ${uid.toUpperCase()}@EXAMPLE.TEST `,
      password: 'Other-123!', employeeId: 'existing-worker' })), error =>
      error.code === 'already-exists' && error.message === 'Email này đã được sử dụng.');
    assert.deepEqual((await db.doc(`staff_accounts/${uid}`).get()).data(), old);
    assert.equal((await db.doc('employee_accounts/existing-worker').get()).exists, false);
  }
  await rejectsCode(handlers.createStaffAccount(request('admin', { email: 'different@example.test', password: 'Initial-123!', employeeId: 'employee-a' })), 'already-exists');
  await assert.rejects(auth.getUserByEmail('different@example.test'), e => e.code === 'auth/user-not-found');
});

test('Provisioning: concurrent duplicate attempts yield one creation and one email-in-use error', async () => {
  await db.doc('employees/race-provision').set({ salonId: 'salon_02', isActive: true });
  const data = { email: 'race-provision@example.test', password: 'Initial-123!', employeeId: 'race-provision' };
  const results = await Promise.allSettled([1, 2].map(() => handlers.createStaffAccount(request('admin', data))));
  assert.equal(results.filter(r => r.status === 'fulfilled').length, 1);
  const failure = results.find(r => r.status === 'rejected').reason;
  assert.equal(failure.code, 'already-exists');
  assert.equal(failure.message, 'Email này đã được sử dụng.');
  const user = results.find(r => r.status === 'fulfilled').value;
  assert.equal((await db.collection('audit_events').where('targetUid', '==', user.uid).get()).size, 1);
});

test('Provisioning: customer signup racing after email lookup is never linked as staff', async () => {
  await db.doc('employees/signup-race-worker').set({ name: 'Race worker', salonId: 'salon_01', isActive: true });
  const racing = createStaffHandlers(db, {
    getUser: uid => auth.getUser(uid), getUserByEmail: email => auth.getUserByEmail(email),
    createUser: async data => {
      await auth.createUser({ uid: 'signup-race-customer', email: data.email, password: 'Customer-123!' });
      await db.doc('users/signup-race-customer').set({ name: 'Original customer' });
      return auth.createUser(data);
    },
  });
  await assert.rejects(racing.createStaffAccount(request('admin', {
    employeeId: 'signup-race-worker', email: 'signup-race@example.test', password: 'Employee-123!',
  })), error => error.code === 'already-exists' && error.message === 'Email này đã được sử dụng.');
  assert.equal((await auth.getUserByEmail('signup-race@example.test')).uid, 'signup-race-customer');
  assert.equal((await db.doc('staff_accounts/signup-race-customer').get()).exists, false);
  assert.equal((await db.doc('employee_accounts/signup-race-worker').get()).exists, false);
  assert.deepEqual((await db.doc('users/signup-race-customer').get()).data(), { name: 'Original customer' });
});

before(async () => {
  env = await initializeTestEnvironment({ projectId, firestore: {
    host: '127.0.0.1', port: 8180,
    rules: fs.readFileSync(path.join(__dirname, '../../', process.env.STAFF_RULES_FILE || 'firestore.rules'), 'utf8'),
  }});
  for (const uid of ['admin', 'staff-a', 'staff-b', 'customer', 'target', 'target-2', 'target-off',
    'duplicate-1', 'duplicate-2', 'same-uid', 'unverified', 'auth-disabled']) {
    await auth.createUser({ uid, email: `${uid}@example.test`, password: 'Local-test-123!',
      emailVerified: uid !== 'unverified', disabled: uid === 'auth-disabled' });
  }
  const batch = db.batch();
  for (const [id, data] of Object.entries({
    'admins/admin': { name: 'Admin local' },
    'employees/employee-a': { name: 'Nhân viên A', salonId: 'salon_01', isActive: true },
    'employees/employee-b': { name: 'Nhân viên B', salonId: 'salon_02', isActive: true },
    'employees/employee-off': { name: 'Ngừng hoạt động', salonId: 'salon_01', isActive: false },
    'staff_accounts/staff-a': { employeeId: 'employee-a', active: true },
    'employee_accounts/employee-a': { uid: 'staff-a' },
    'staff_accounts/staff-b': { employeeId: 'employee-b', active: true },
    'employee_accounts/employee-b': { uid: 'staff-b' },
    'users/customer': { name: 'Khách', email: 'private@example.test' },
    'bookings/assigned-a': { barberId: 'employee-a', userId: 'customer', salonId: 'salon_01', status: 'confirmed' },
    'bookings/assigned-b': { barberId: 'employee-b', userId: 'customer', salonId: 'salon_02', status: 'confirmed' },
  })) batch.set(db.doc(id), data);
  await batch.commit();
});
after(async () => { if (env) await env.cleanup(); await deleteApp(app); });

test('Rules: staff can query only assigned bookings; admin and customer retain access', async () => {
  const staff = ctx('staff-a');
  await assertSucceeds(getDoc(doc(staff, 'bookings/assigned-a')));
  const result = await assertSucceeds(getDocs(query(collection(staff, 'bookings'), where('barberId', '==', 'employee-a'))));
  assert.equal(result.size, 1);
  await assertFails(getDoc(doc(staff, 'bookings/assigned-b')));
  await assertFails(getDocs(collection(staff, 'bookings')));
  await assertFails(getDocs(query(collection(staff, 'bookings'), where('barberId', '==', 'employee-b'))));
  await assertSucceeds(getDocs(collection(ctx('admin'), 'bookings')));
  await assertSucceeds(getDocs(query(collection(ctx('customer'), 'bookings'), where('userId', '==', 'customer'))));
});

test('Rules: anonymous and unverified staff cannot read assigned bookings', async () => {
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'bookings/assigned-a')));
  await assertFails(getDoc(doc(ctx('staff-a', false), 'bookings/assigned-a')));
});

test('Rules: private links cannot be enumerated; users cannot self-assign or modify roles', async () => {
  const staff = ctx('staff-a');
  await assertSucceeds(getDoc(doc(staff, 'staff_accounts/staff-a')));
  await assertSucceeds(getDoc(doc(staff, 'employee_accounts/employee-a')));
  await assertFails(getDocs(collection(staff, 'staff_accounts')));
  await assertFails(getDoc(doc(staff, 'staff_accounts/staff-b')));
  await assertFails(getDoc(doc(staff, 'employee_accounts/employee-b')));
  await assertFails(getDoc(doc(staff, 'users/customer')));
  for (const uid of ['customer', 'staff-a', 'admin']) {
    await assertFails(setDoc(doc(ctx(uid), 'staff_accounts/self'), { employeeId: 'employee-a', active: true }));
    await assertFails(updateDoc(doc(ctx(uid), 'staff_accounts/staff-a'), { active: true }));
    await assertFails(deleteDoc(doc(ctx(uid), 'employee_accounts/employee-a')));
  }
  await assertFails(setDoc(doc(ctx('customer'), 'admins/customer'), { role: 'admin' }));
  await assertSucceeds(getDocs(collection(ctx('admin'), 'staff_accounts')));
});

test('Rules: staff cannot start/complete or reassign bookings in phase one', async () => {
  for (const change of [{ status: 'completed' }, { status: 'in_service' }, { barberId: 'employee-b' }, { totalPrice: 1 }]) {
    await assertFails(updateDoc(doc(ctx('staff-a'), 'bookings/assigned-a'), change));
  }
  await assertFails(setDoc(doc(ctx('staff-a'), 'work_shifts/unauthorized'), { employeeId: 'employee-a' }));
  await assertFails(setDoc(doc(ctx('staff-a'), 'audit_events/forged'), { actorUid: 'admin' }));
});

test('Backend: anonymous/customer/staff cannot link or activate accounts', async () => {
  for (const uid of [null, 'customer', 'staff-a']) {
    const expected = uid ? 'permission-denied' : 'unauthenticated';
    await rejectsCode(handlers.linkStaffAccount(request(uid, { uid: 'target', employeeId: 'employee-a' })), expected);
    await rejectsCode(handlers.setStaffAccountActive(request(uid, { uid: 'staff-a', active: true })), expected);
  }
});

test('Backend: validates existing Auth, verified/enabled accounts, employee and branch', async () => {
  await rejectsCode(handlers.linkStaffAccount(request('admin', { uid: 'not-real', employeeId: 'employee-a' })), 'not-found');
  await rejectsCode(handlers.linkStaffAccount(request('admin', { uid: 'auth-disabled', employeeId: 'employee-a' })), 'failed-precondition');
  await rejectsCode(handlers.linkStaffAccount(request('admin', { uid: 'unverified', employeeId: 'employee-a' })), 'failed-precondition');
  await rejectsCode(handlers.linkStaffAccount(request('admin', { uid: 'target', employeeId: 'not-real' })), 'not-found');
  await rejectsCode(handlers.linkStaffAccount(request('admin', { uid: 'target', employeeId: 'employee-off' })), 'failed-precondition');
  await db.doc('employees/bad-branch').set({ salonId: 'other', isActive: true });
  await rejectsCode(handlers.linkStaffAccount(request('admin', { uid: 'target', employeeId: 'bad-branch' })), 'failed-precondition');
  await rejectsCode(handlers.linkStaffAccount(request('admin', { uid: '../bad', employeeId: 'employee-a' })), 'invalid-argument');
  await rejectsCode(handlers.linkStaffAccount(request('admin', { uid: 'target', employeeId: '..' })), 'invalid-argument');
  await rejectsCode(handlers.setStaffAccountActive(request('admin', { uid: 'staff-a', active: 'true' })), 'invalid-argument');
  await rejectsCode(handlers.setStaffAccountActive(request('admin', { uid: 'unverified', active: true })), 'failed-precondition');
});

test('Backend: links both directions atomically and replay does not duplicate audit', async () => {
  await db.doc('employees/target-employee').set({ name: 'Target', salonId: 'salon_03', isActive: true });
  const data = { uid: 'target', employeeId: 'target-employee' };
  assert.equal((await handlers.linkStaffAccount(request('admin', data))).alreadyLinked, false);
  assert.equal((await handlers.linkStaffAccount(request('admin', data))).alreadyLinked, true);
  assert.equal((await db.doc('employee_accounts/target-employee').get()).data().uid, 'target');
  assert.equal((await db.doc('staff_accounts/target').get()).data().employeeId, 'target-employee');
  assert.equal((await db.collection('audit_events').where('targetUid', '==', 'target').get()).size, 1);
  await rejectsCode(handlers.linkStaffAccount(request('admin', { uid: 'target-2', employeeId: 'target-employee' })), 'already-exists');
  await rejectsCode(handlers.linkStaffAccount(request('admin', { uid: 'target', employeeId: 'employee-a' })), 'already-exists');
});

test('Backend: simultaneous links to one employee allow exactly one UID', async () => {
  await db.doc('employees/race-employee').set({ salonId: 'salon_01', isActive: true });
  const results = await Promise.allSettled(['duplicate-1', 'duplicate-2'].map((uid) =>
    handlers.linkStaffAccount(request('admin', { uid, employeeId: 'race-employee' }))));
  assert.equal(results.filter((r) => r.status === 'fulfilled').length, 1);
  assert.equal(results.find((r) => r.status === 'rejected').reason.code, 'already-exists');
});

test('Backend: simultaneous links of one UID to two employees allow exactly one employee', async () => {
  for (const id of ['race-a', 'race-b']) await db.doc(`employees/${id}`).set({ salonId: 'salon_01', isActive: true });
  const results = await Promise.allSettled(['race-a', 'race-b'].map((employeeId) =>
    handlers.linkStaffAccount(request('admin', { uid: 'same-uid', employeeId }))));
  assert.equal(results.filter((r) => r.status === 'fulfilled').length, 1);
  assert.equal(results.find((r) => r.status === 'rejected').reason.code, 'already-exists');
});

test('Backend + Rules: deactivation immediately denies a still-authenticated client', async () => {
  const staff = ctx('staff-a');
  await assertSucceeds(getDoc(doc(staff, 'bookings/assigned-a')));
  await handlers.setStaffAccountActive(request('admin', { uid: 'staff-a', active: false }));
  await assertFails(getDoc(doc(staff, 'bookings/assigned-a')));
  await assertSucceeds(getDoc(doc(staff, 'staff_accounts/staff-a')));
  await rejectsCode(handlers.linkStaffAccount(request('admin', { uid: 'target-off', employeeId: 'employee-a' })), 'already-exists');
  await handlers.setStaffAccountActive(request('admin', { uid: 'staff-a', active: true }));
  await assertSucceeds(getDoc(doc(staff, 'bookings/assigned-a')));
});

test('Rules: inactive/missing employee or broken inverse link fails closed', async () => {
  const ref = db.doc('employees/employee-a');
  await ref.update({ isActive: false });
  await assertFails(getDoc(doc(ctx('staff-a'), 'bookings/assigned-a')));
  await rejectsCode(handlers.setStaffAccountActive(request('admin', { uid: 'staff-a', active: true })), 'failed-precondition');
  await ref.update({ isActive: true });
  await db.doc('employee_accounts/employee-a').update({ uid: 'different' });
  await assertFails(getDoc(doc(ctx('staff-a'), 'bookings/assigned-a')));
  await db.doc('employee_accounts/employee-a').update({ uid: 'staff-a' });
  await db.doc('staff_accounts/orphan').set({ employeeId: 'missing-employee', active: true });
  await db.doc('employee_accounts/missing-employee').set({ uid: 'orphan' });
  await db.doc('bookings/orphan-booking').set({ barberId: 'missing-employee', userId: 'customer', salonId: 'salon_01' });
  await assertFails(getDoc(doc(ctx('orphan'), 'bookings/orphan-booking')));
});

test('Callable HTTP: verifies Auth token and applies admin authorization in Functions emulator', async () => {
  const endpoint = `http://127.0.0.1:5101/${projectId}/asia-southeast1/linkStaffAccount`;
  const anonymous = await fetch(endpoint, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ data: {} }) });
  assert.equal(anonymous.status, 401);
  const login = await fetch('http://127.0.0.1:9199/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=demo-key', {
    method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email: 'customer@example.test', password: 'Local-test-123!', returnSecureToken: true }),
  });
  assert.equal(login.status, 200);
  const token = (await login.json()).idToken;
  const denied = await fetch(endpoint, { method: 'POST', headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
    body: JSON.stringify({ data: { uid: 'target', employeeId: 'employee-a' } }) });
  assert.equal(denied.status, 403);
  const adminLogin = await fetch('http://127.0.0.1:9199/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=demo-key', {
    method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email: 'admin@example.test', password: 'Local-test-123!', returnSecureToken: true }),
  });
  assert.equal(adminLogin.status, 200);
  await db.doc('employees/http-employee').set({ salonId: 'salon_03', isActive: true });
  const adminToken = (await adminLogin.json()).idToken;
  const linked = await fetch(endpoint, { method: 'POST', headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${adminToken}` },
    body: JSON.stringify({ data: { uid: 'target-2', employeeId: 'http-employee' } }) });
  assert.equal(linked.status, 200);
  assert.equal((await linked.json()).result.employeeId, 'http-employee');
  await db.doc('employees/http-new-staff').set({ name: 'HTTP staff', salonId: 'salon_01', isActive: true });
  const provisionEndpoint = endpoint.replace('linkStaffAccount', 'createStaffAccount');
  const data = { email: 'http-new-staff@example.test', password: 'Initial-123!', employeeId: 'http-new-staff' };
  const forbidden = await fetch(provisionEndpoint, { method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
    body: JSON.stringify({ data }) });
  assert.equal(forbidden.status, 403);
  const provisioned = await fetch(provisionEndpoint, { method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${adminToken}` },
    body: JSON.stringify({ data }) });
  assert.equal(provisioned.status, 200);
  const result = (await provisioned.json()).result;
  assert.equal(result.created, true);
  assert.equal(result.email, data.email);
  assert.equal((await db.doc(`staff_accounts/${result.uid}`).get()).data().employeeId, data.employeeId);
  const duplicate = await fetch(provisionEndpoint, { method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${adminToken}` },
    body: JSON.stringify({ data: { ...data, password: 'Different-123!' } }) });
  assert.equal(duplicate.status, 409);
  const duplicateError = (await duplicate.json()).error;
  assert.equal(duplicateError.status, 'ALREADY_EXISTS');
  assert.equal(duplicateError.message, 'Email này đã được sử dụng.');
});

test('Callable HTTP: admin creates a shift, customer books it, staff cannot mutate shifts', async () => {
  async function tokenFor(email) {
    const response = await fetch('http://127.0.0.1:9199/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=demo-key', {
      method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password: 'Local-test-123!', returnSecureToken: true }),
    });
    assert.equal(response.status, 200);
    return (await response.json()).idToken;
  }
  async function call(name, token, data) {
    const response = await fetch(`http://127.0.0.1:5101/${projectId}/asia-southeast1/${name}`, {
      method: 'POST', headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
      body: JSON.stringify({ data }),
    });
    return { status: response.status, body: await response.json() };
  }
  const adminToken = await tokenFor('admin@example.test');
  const customerToken = await tokenFor('customer@example.test');
  const staffToken = await tokenFor('staff-a@example.test');
  const { dateKey, dayStart } = require('../src/scheduling');
  const date = dateKey(Date.now() + 2 * 86400000);
  await db.doc('employees/http-schedule-worker').set({ name: 'HTTP worker', salonId: 'salon_01', isActive: true });
  await db.doc('services/http-cut').set({ name: 'HTTP cut', durationMinutes: 30, price: 80000, isActive: true });
  const payload = { requestId: 'http-shift', employeeId: 'http-schedule-worker', salonId: 'salon_01', dates: [date], startMinute: 540, endMinute: 660 };
  assert.equal((await call('saveShifts', staffToken, payload)).status, 403);
  assert.equal((await call('saveShifts', customerToken, payload)).status, 403);
  const shift = await call('saveShifts', adminToken, payload);
  assert.equal(shift.status, 200, JSON.stringify(shift.body));
  const bookingData = { requestId: 'http-booking', barberId: payload.employeeId, salonId: payload.salonId,
    serviceIds: ['http-cut'], appointmentAt: dayStart(date) + 540 * 60000, userPhone: '0901234567', paymentChoice: 'pay_later' };
  const booked = await call('createBooking', customerToken, bookingData);
  assert.equal(booked.status, 200, JSON.stringify(booked.body));
  const replay = await call('createBooking', customerToken, bookingData);
  assert.equal(replay.status, 200);
  assert.equal(replay.body.result.bookingId, booked.body.result.bookingId);
  const saved = (await db.doc(`bookings/${booked.body.result.bookingId}`).get()).data();
  assert.equal(saved.workShiftId, shift.body.result.shiftIds[0]);
  assert.equal(saved.totalPrice, 80000);
  assert.equal(saved.totalDurationMinutes, 30);
  assert.equal((await call('createBooking', customerToken, { ...bookingData, requestId: 'http-conflict' })).status, 400);
  assert.equal((await call('cancelShift', adminToken, { requestId: 'http-cancel', shiftId: saved.workShiftId, expectedRevision: 1 })).status, 400);
  assert.equal((await db.doc(`work_shifts/${saved.workShiftId}`).get()).data().status, 'scheduled');
});
