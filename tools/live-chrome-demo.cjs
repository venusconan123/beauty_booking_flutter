'use strict';
// One explicitly approved live fixture, not a customer-booking API or migration.
// No production clock/validation changes. Default is read-only preview.
const path = require('node:path');
const { pathToFileURL } = require('node:url');
const project = 'men-hair-booking';
const date = '2026-11-12';
const bookingId = 'demo_chrome_20261112_lequoc';
const demoUid = 'demo_chrome_customer_20261112';
const start = Date.parse(`${date}T21:30:00+07:00`);
const fixtureTag = 'chrome-live-20261112-approved';

async function main() {
  if (process.env.FIRESTORE_EMULATOR_HOST) throw new Error('This fixture targets the explicitly approved live project only.');
  const root = process.env.FIREBASE_TOOLS_ROOT;
  if (!root) throw new Error('FIREBASE_TOOLS_ROOT is required');
  const { getGlobalDefaultAccount, getAccessToken } = require(path.join(root, 'lib/auth'));
  const { requireAuth } = require(path.join(root, 'lib/requireAuth'));
  const account = getGlobalDefaultAccount();
  if (!account) throw new Error('Firebase CLI login required');
  const authOptions = { project, user: account.user, tokens: account.tokens, nonInteractive: true };
  await requireAuth(authOptions);
  const tokenProvider = async () => (await getAccessToken(account.tokens.refresh_token, authOptions.authScopes)).access_token;
  const { RestFirestore } = await import(pathToFileURL(path.join(__dirname, '../cloudflare_worker/src/firestore-rest.js')));
  const { Timestamp, FieldValue } = require('../cloudflare_worker/src/firebase-primitives.cjs');
  const db = new RestFirestore({ projectId: project, tokenProvider });
  const employees = await db.collection('employees').where('salonId', '==', 'salon_01').get();
  const matching = employees.docs.filter(row => row.data().name === 'Lê Quốc');
  if (matching.length !== 1) throw new Error('Expected exactly one Lê Quốc profile in salon_01');
  const employee = matching[0];
  const ref = db.doc(`bookings/${bookingId}`);
  if (process.argv.includes('--inspect')) {
    const row = await ref.get();
    const value = row.data();
    const audits = await db.collection('audit_events').where('action', '==', 'booking.payment.record').get();
    console.log(JSON.stringify({ project, bookingId, exists: row.exists,
      status: value?.status, payment: value?.payment, receiptExists: !!value?.payment?.receipt,
      paymentAuditCount: audits.docs.filter(r => r.data().before?.bookingId === bookingId).length,
      startedBy: value?.startedBy, completedBy: value?.completedBy,
      fixtureTag: value?.demoFixture, preparation: value?.demoPreparation }, null, 2));
    return;
  }
  const apply = process.argv.includes('--apply');
  if (process.argv.includes('--prepare-in-service')) {
    const result = await db.runTransaction(async tx => {
      const guard = db.doc(`employee_days/${employee.id}_${date}`);
      const [row, guardDoc] = await tx.getAll(ref, guard);
      const b = row.data();
      if (!row.exists || b.demoFixture !== fixtureTag || b.userId !== demoUid ||
          b.barberId !== employee.id || b.salonId !== 'salon_01' || b.totalPrice !== 80000 ||
          b.appointmentAt?.toMillis() !== start || b.payment?.status !== 'unpaid' || b.payment?.receipt) {
        throw new Error('Fixture identity/payment no longer matches approved preparation');
      }
      if (b.status === 'in_service' && b.demoPreparation === 'simulated-start-approved-20261113') {
        return { unchanged: true, status: b.status };
      }
      if (b.status !== 'confirmed') throw new Error('Only the untouched confirmed demo can be prepared');
      const active = await tx.get(db.collection('bookings').where('barberId', '==', employee.id));
      if (active.docs.some(r => r.id !== bookingId && r.data().status === 'in_service')) {
        throw new Error('Another booking is in service; no fixture change');
      }
      if (new Date(Date.now() + 7 * 3600000).toISOString().slice(0, 10) !== '2026-11-13') {
        throw new Error('Preparation only approved for 13/11/2026');
      }
      if (apply) {
        const stamp = FieldValue.serverTimestamp();
        tx.update(ref, { status: 'in_service', startedAt: stamp, startedBy: 'demo_fixture_setup',
          demoPreparation: 'simulated-start-approved-20261113',
          demoNote: 'Bước bắt đầu phục vụ được chuẩn bị bằng dữ liệu thử theo xác nhận chủ dự án; không phải thao tác bắt đầu qua UI.',
          updatedAt: stamp });
        tx.set(guard, { version: (guardDoc.data()?.version ?? 0) + 1, updatedAt: stamp }, { merge: true });
        tx.create(db.collection('audit_events').doc(), { action: 'demo.fixture.prepare_in_service',
          actor: account.user.email, before: { bookingId, status: b.status },
          after: { status: 'in_service', simulated: true }, createdAt: stamp });
      }
      return { applied: apply, status: apply ? 'in_service' : 'confirmed', simulatedStart: true };
    });
    console.log(JSON.stringify({ project, bookingId, ...result }, null, 2));
    return;
  }
  const result = await db.runTransaction(async tx => {
    const guard = db.doc(`employee_days/${employee.id}_${date}`);
    const customer = db.doc(`users/${demoUid}`);
    const [existing, service, guardDoc, customerDoc, control, link] = await tx.getAll(ref,
      db.doc('services/service_hair_cut'), guard, customer,
      db.doc('app_settings/scheduling_v2'), db.doc(`employee_accounts/${employee.id}`));
    if (existing.exists) {
      if (existing.data().demoFixture !== fixtureTag) throw new Error('Fixture ID already occupied by other data');
      return { alreadyExists: true, status: existing.data().status, paymentStatus: existing.data().payment?.status };
    }
    if (new Date(Date.now() + 7 * 3600000).toISOString().slice(0, 10) !== date) throw new Error('Fixture only authorized for 12/11/2026');
    if (employee.data().isActive === false || control.data()?.bookingWritesEnabled !== true) throw new Error('Employee or booking writes inactive');
    if (!link.exists || !link.data().uid) throw new Error('Employee has no linked account');
    const staff = await tx.get(db.doc(`staff_accounts/${link.data().uid}`));
    if (!staff.exists || staff.data().employeeId !== employee.id || staff.data().active !== true) throw new Error('Staff account linkage inactive');
    const item = service.data();
    if (!service.exists || item.isActive !== true || item.price !== 80000 || item.durationMinutes !== 30) throw new Error('Approved service price/duration changed');
    if (customerDoc.exists && customerDoc.data().demoFixture !== fixtureTag) throw new Error('Demo customer ID occupied');
    const shifts = await tx.get(db.collection('work_shifts').where('employeeId', '==', employee.id).where('dateKey', '==', date));
    const assigned = shifts.docs.find(row => { const s = row.data(); return s.salonId === 'salon_01' && s.status === 'scheduled' && s.startMinute <= 1290 && s.endMinute >= 1320; });
    if (!assigned || shifts.docs.some(row => row.data().status === 'off')) throw new Error('Approved interval not covered by active shift');
    const bookings = await tx.get(db.collection('bookings').where('barberId', '==', employee.id));
    for (const row of bookings.docs) {
      const b = row.data();
      if (['completed', 'cancelled'].includes(b.status)) continue;
      const at = b.appointmentAt?.toMillis();
      const minutes = b.totalDurationMinutes ?? b.services?.reduce((n, s) => n + Number(s.durationMinutes || 0), 0);
      if (!Number.isFinite(at) || !Number.isSafeInteger(minutes) || minutes <= 0) throw new Error('Active legacy booking has invalid time');
      if (b.status === 'in_service' || (at < start + 1800000 && at + Math.ceil(minutes / 30) * 1800000 > start)) throw new Error('Conflicting booking; no fixture created');
    }
    const slotId = `${bookingId}_${start}`;
    const stamp = FieldValue.serverTimestamp();
    const booking = { schemaVersion: 2, demoFixture: fixtureTag,
      demoNote: 'Dữ liệu thử đã được chủ dự án đồng ý; không có thu tiền ngoài đời.',
      userId: demoUid, userName: 'KIỂM THỬ DEMO 12/11', userEmail: '', userPhone: '0000000000',
      salonId: 'salon_01', salonName: '30Shine 345 Nguyễn Văn Linh',
      barberId: employee.id, barberName: 'Lê Quốc', useAnyBarber: false, autoAssignedBarber: false,
      workShiftId: assigned.id, shiftRevision: assigned.data().revision,
      appointmentAt: Timestamp.fromMillis(start), selectedTime: '21:30',
      serviceIds: ['service_hair_cut'], services: [{ id: 'service_hair_cut', name: item.name, price: 80000, durationMinutes: 30 }],
      totalDurationMinutes: 30, originalPrice: 80000, discountAmount: 0, totalPrice: 80000,
      voucherIds: [], vouchers: [], voucher: null, hairstyle: null, status: 'confirmed', slotIds: [slotId],
      payment: { provider: 'vnpay', environment: 'sandbox', choice: 'pay_later', status: 'unpaid', amount: 80000 },
      createdAt: stamp, updatedAt: stamp };
    if (apply) {
      if (!customerDoc.exists) tx.create(customer, { name: booking.userName, demoFixture: fixtureTag, createdAt: stamp });
      tx.create(ref, booking);
      tx.create(db.doc(`booking_slots/${slotId}`), { bookingId, userId: demoUid, salonId: 'salon_01',
        barberId: employee.id, slotAt: booking.appointmentAt, state: 'active', createdAt: stamp });
      tx.set(guard, { version: (guardDoc.data()?.version ?? 0) + 1, updatedAt: stamp }, { merge: true });
      tx.create(db.collection('audit_events').doc(), { action: 'demo.fixture.create', actor: account.user.email,
        before: null, after: { bookingId, demoFixture: fixtureTag }, createdAt: stamp });
    }
    return { applied: apply, customerName: booking.userName, employeeId: employee.id, shiftId: assigned.id,
      appointmentAt: `${date} 21:30 +07:00`, amount: 80000, paymentChoice: 'pay_later' };
  });
  console.log(JSON.stringify({ project, bookingId, ...result }, null, 2));
}
main().catch(error => { console.error(error.message); process.exitCode = 1; });
