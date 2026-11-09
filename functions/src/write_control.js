'use strict';
const { HttpsError } = require('firebase-functions/v2/https');

// Read inside every mutation transaction so pausing races with writes safely.
// Production is fail-closed until this explicit, reviewed config exists.
async function requireWrites(tx, db, feature) {
  const snapshot = await tx.get(db.doc('app_settings/scheduling_v2'));
  const localDemo = (process.env.GCLOUD_PROJECT || '').startsWith('demo-') &&
    /^127\.0\.0\.1:\d+$/.test(process.env.FIRESTORE_EMULATOR_HOST || '');
  if (!snapshot.exists && localDemo) return;
  if (snapshot.data()?.protocolVersion !== 2 || snapshot.data()?.[feature] !== true) {
    throw new HttpsError('failed-precondition', 'Hệ thống đang tạm dừng thao tác này để bảo trì. Vui lòng thử lại sau.');
  }
}
module.exports = { requireWrites };
