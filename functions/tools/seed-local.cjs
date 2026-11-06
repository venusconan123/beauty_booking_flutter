'use strict';
// Local preview fixtures only. Never creates accounts in a real Firebase project.
const assert = require('node:assert/strict');
assert.equal(process.env.GCLOUD_PROJECT, 'demo-men-hair-booking');
assert.equal(process.env.FIRESTORE_EMULATOR_HOST, '127.0.0.1:8080');
assert.equal(process.env.FIREBASE_AUTH_EMULATOR_HOST, '127.0.0.1:9099');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, Timestamp } = require('firebase-admin/firestore');
const { getAuth } = require('firebase-admin/auth');
const { createStaffHandlers } = require('../src/staff');
const { createSchedulingHandlers, dateKey } = require('../src/scheduling');
initializeApp({ projectId: 'demo-men-hair-booking' });
const db = getFirestore();
const auth = getAuth();
async function main() {
  const password = 'Local-demo-123!';
  for (const role of ['admin', 'staff', 'customer']) {
    const uid = `local-${role}`;
    try { await auth.getUser(uid); }
    catch (error) {
      if (error.code !== 'auth/user-not-found') throw error;
      await auth.createUser({ uid, email: `local-${role}@example.test`, password, emailVerified: true });
    }
  }
  const records = {
    'admins/local-admin': { name: 'Quản trị viên demo' },
    'users/local-admin': { name: 'Admin demo' },
    'users/local-staff': { name: 'Nhân viên demo' },
    'users/local-customer': { name: 'Khách demo' },
    'employees/local-employee': { name: 'Nhân viên demo', salonId: 'salon_01', isActive: true },
    'employees/local-peer': { name: 'Đồng nghiệp demo', salonId: 'salon_01', isActive: true },
    'employees/local-cross': { name: 'Nhân viên chi nhánh 2', salonId: 'salon_02', isActive: true },
    'bookings/local-assignment': {
      userId: 'local-customer', userName: 'Khách demo', barberId: 'local-employee',
      salonId: 'salon_01', salonName: 'Chi nhánh 1', status: 'confirmed',
      appointmentAt: Timestamp.fromMillis(Date.now() + 86400000),
      services: [{ id: 'cut', name: 'Cắt tóc', price: 80000, durationMinutes: 30 }],
      totalPrice: 80000, payment: { choice: 'pay_later', status: 'unpaid' },
    },
  };
  for (const [id, data] of Object.entries(records)) {
    const ref = db.doc(id);
    if (!(await ref.get()).exists) await ref.create(data);
  }
  await createStaffHandlers(db, auth).linkStaffAccount({
    auth: { uid: 'local-admin' }, data: { uid: 'local-staff', employeeId: 'local-employee' },
  });
  const defaults = [
    ['service_combo_10', 'Combo 10 bước', 150000, 60],
    ['service_hair_cut', 'Cắt tóc nam', 80000, 30],
    ['service_hair_wash', 'Gội đầu', 30000, 20],
    ['service_styling', 'Tạo kiểu', 50000, 30],
    ['service_perm', 'Uốn tóc', 250000, 120],
    ['service_dye', 'Nhuộm tóc', 300000, 150],
    ['service_skin_care', 'Chăm sóc da', 100000, 45],
  ];
  for (const [key, name, price, durationMinutes] of defaults) {
    const ref = db.doc(`services/${key}`);
    if (!(await ref.get()).exists) await ref.create({ name, price, durationMinutes, isActive: true });
  }
  const scheduler = createSchedulingHandlers(db, auth);
  for (const [employeeId, salonId] of [['local-employee', 'salon_01'], ['local-peer', 'salon_01'], ['local-cross', 'salon_02']]) {
    const existing = await db.collection('work_shifts').where('employeeId', '==', employeeId).get();
    const days = new Set(existing.docs.map((row) => row.data().dateKey));
    const offsets = employeeId === 'local-peer' ? [1, 2, 3, 4] : employeeId === 'local-cross' ? [1, 2, 3, 5] : [1, 2, 3];
    const dates = offsets.map((offset) => dateKey(Date.now() + offset * 86400000)).filter((date) => !days.has(date));
    if (dates.length) await scheduler.saveShifts({ auth: { uid: 'local-admin' }, data: {
      employeeId, salonId, dates, startMinute: 420, endMinute: 1320,
      requestId: `preview-${employeeId}-${dates.join('_')}`,
    }});
  }
  console.log('Local demo only: local-admin@example.test / local-staff@example.test / local-customer@example.test');
  console.log(`Local demo password: ${password}`);
  await db.terminate();
}
main().catch((error) => { console.error(error.message); process.exitCode = 1; });
