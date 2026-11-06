'use strict';
const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { getAuth } = require('firebase-admin/auth');
const { onCall } = require('firebase-functions/v2/https');
const { createStaffHandlers } = require('./staff');
const { createSchedulingHandlers } = require('./scheduling');
initializeApp();
const handlers = createStaffHandlers(getFirestore(), getAuth());
// No provisioning, migrations, triggers, or writes occur on module load.
exports.linkStaffAccount = onCall({ region: 'asia-southeast1' }, handlers.linkStaffAccount);
exports.setStaffAccountActive = onCall({ region: 'asia-southeast1' }, handlers.setStaffAccountActive);
const scheduling = createSchedulingHandlers(getFirestore(), getAuth());
for (const [name, handler] of Object.entries(scheduling)) {
  exports[name] = onCall({ region: 'asia-southeast1' }, async (request) => {
    const started = Date.now();
    const trace = (stage, extra = {}) => {
      if (process.env.FUNCTIONS_EMULATOR === 'true') console.info(JSON.stringify({
        event: 'scheduling', name, requestId: request.data?.requestId ?? 'read', stage,
        elapsedMs: Date.now() - started, ...extra,
      }));
    };
    trace('received');
    try {
      const result = await handler(request);
      trace('resolved', { result });
      return result;
    } catch (error) {
      trace('rejected', { code: error.code ?? 'internal' });
      throw error;
    }
  });
}
