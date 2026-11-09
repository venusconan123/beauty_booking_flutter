'use strict';
const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { getAuth } = require('firebase-admin/auth');
const { onCall } = require('firebase-functions/v2/https');
const { createStaffHandlers } = require('./staff');
const { createSchedulingHandlers } = require('./scheduling');
initializeApp();
const handlers = createStaffHandlers(getFirestore(), getAuth());
// Small dissertation workload: scale to zero and bound each callable separately.
// Fractional CPU disables multi-request concurrency; transactions still protect
// requests across instances/functions. This is not a billing hard cap.
const runtime = { region: 'asia-southeast1', minInstances: 0, maxInstances: 2,
  memory: '256MiB', cpu: 'gcf_gen1', concurrency: 1 };
// No provisioning, migrations, triggers, or writes occur on module load.
exports.linkStaffAccount = onCall(runtime, handlers.linkStaffAccount);
exports.setStaffAccountActive = onCall(runtime, handlers.setStaffAccountActive);
const scheduling = createSchedulingHandlers(getFirestore(), getAuth());
for (const [name, handler] of Object.entries(scheduling)) {
  exports[name] = onCall(runtime, async (request) => {
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
