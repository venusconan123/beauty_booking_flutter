'use strict';
const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { getAuth } = require('firebase-admin/auth');
const { onCall } = require('firebase-functions/v2/https');
const { createStaffHandlers } = require('./staff');
initializeApp();
const handlers = createStaffHandlers(getFirestore(), getAuth());
// No provisioning, migrations, triggers, or writes occur on module load.
exports.linkStaffAccount = onCall({ region: 'asia-southeast1' }, handlers.linkStaffAccount);
exports.setStaffAccountActive = onCall({ region: 'asia-southeast1' }, handlers.setStaffAccountActive);
