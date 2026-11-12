'use strict';
// Read-only verification of one UI-created booking, restricted to local demo.
const assert = require('node:assert/strict');
const { createRequire } = require('node:module');
const path = require('node:path');
assert.equal(process.env.GCLOUD_PROJECT, 'demo-men-hair-booking');
assert.equal(process.env.FIRESTORE_EMULATOR_HOST, '127.0.0.1:8080');
assert.equal(process.env.FIREBASE_AUTH_EMULATOR_HOST, '127.0.0.1:9099');
const bookingId = process.argv[2];
assert.match(bookingId ?? '', /^[A-Za-z0-9_-]{1,128}$/);
const demoRequire = createRequire(path.resolve(__dirname, '../functions/package.json'));
const { initializeApp, deleteApp } = demoRequire('firebase-admin/app');
const { getFirestore } = demoRequire('firebase-admin/firestore');
const app = initializeApp({ projectId: 'demo-men-hair-booking' });
(async () => {
  try {
    const db = getFirestore(app);
    const snapshot = await db.doc(`bookings/${bookingId}`).get();
    assert.ok(snapshot.exists, 'Booking missing after restart');
    const row = snapshot.data();
    const audit = await db.collection('audit_events').where('after.bookingId', '==', bookingId).get();
    console.log(JSON.stringify({ id: snapshot.id, status: row.status,
      appointmentAt: row.appointmentAt.toDate().toISOString(), totalPrice: row.totalPrice,
      barberId: row.barberId, payment: row.payment, auditEvents: audit.size,
      paymentAuditEvents: audit.docs.filter((doc) => doc.data().action === 'booking.payment.record').length }, null, 2));
  } finally { await deleteApp(app); }
})().catch((error) => { console.error(error.message); process.exitCode = 1; });
