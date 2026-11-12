'use strict';
// Create one temporary unprivileged Auth account to test the public online API.
// Never grants admin/staff, changes existing users or sends verification mail.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const key = fs.readFileSync(path.join(__dirname, '../lib/firebase_options.dart'), 'utf8').match(/apiKey:\s*'([^']+)'/)?.[1];
if (!key) throw new Error('Firebase public web configuration missing');
const base = 'https://men-hair-booking-vnpay.venusconan23.workers.dev/api/scheduling';
const identity = `https://identitytoolkit.googleapis.com/v1/accounts`;
async function jsonPost(url, body, token) {
  const response = await fetch(url, { method: 'POST', headers: { 'Content-Type': 'application/json',
    ...(token ? { Authorization: `Bearer ${token}` } : {}) }, body: JSON.stringify(body), signal: AbortSignal.timeout(45000) });
  return { status: response.status, body: await response.json() };
}
(async () => {
  let token;
  try {
    const signup = await jsonPost(`${identity}:signUp?key=${key}`, {
      email: `spark-connectivity-${crypto.randomUUID()}@example.test`, password: crypto.randomBytes(24).toString('base64url'), returnSecureToken: true,
    });
    if (signup.status !== 200) throw new Error(`Auth connectivity test: ${signup.body.error?.message || signup.status}`);
    token = signup.body.idToken;
    const checks = [];
    for (const [method, data, expected] of [
      ['listBookableStaff', { salonId: 'salon_01' }, 200],
      ['getBarberRatings', { employeeIds: ['barber_03'] }, 200],
      ['getAvailability', { salonId: 'salon_01', dateKey: new Date(Date.now() + 7 * 3600000).toISOString().slice(0, 10), serviceIds: ['service_hair_cut'] }, 200],
      ['createStaffAccount', { employeeId: 'not-created', email: 'not-created@example.test', password: 'Not-created-123!' }, 403],
      ['saveRoster', { salonId: 'salon_01', cells: [] }, 403],
    ]) {
      const result = await jsonPost(`${base}/${method}`, { data }, token);
      checks.push({ method, status: result.status, expected, passed: result.status === expected });
      if (result.status !== expected) throw new Error(`${method}: HTTP ${result.status}, ${result.body.error?.message || 'unexpected result'}`);
      if (method === 'getBarberRatings') {
        const row = result.body.result?.ratings?.[0];
        if (row?.employeeId !== 'barber_03' || !Number.isInteger(row.reviewCount) || row.reviewCount < 0 ||
            typeof row.rating !== 'number' || (row.reviewCount === 0 ? row.rating !== 0 : row.rating < 1 || row.rating > 5)) {
          throw new Error('Online rating response has invalid statistics');
        }
        checks.at(-1).rating = row.rating;
        checks.at(-1).reviewCount = row.reviewCount;
      }
    }
    console.log(JSON.stringify({ project: 'men-hair-booking', checks, noPrivilegedAccountCreated: true }, null, 2));
  } finally {
    if (token) {
      const removed = await jsonPost(`${identity}:delete?key=${key}`, { idToken: token });
      if (removed.status !== 200) throw new Error('Temporary connectivity-test account could not be removed');
      console.log('Temporary connectivity-test account removed.');
    }
  }
})().catch((error) => { console.error(error.message); process.exitCode = 1; });
