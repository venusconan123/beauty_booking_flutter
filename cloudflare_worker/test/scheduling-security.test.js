import { test } from 'node:test';
import assert from 'node:assert/strict';
import worker from '../src/index.js';
const env = { FIREBASE_SERVICE_ACCOUNT_JSON: JSON.stringify({ project_id: 'men-hair-booking' }), FIREBASE_WEB_API_KEY: 'public-test-key' };
const call = (method, path, body, headers = {}) => new Request(`https://backend.test/api/scheduling/${path}`, {
  method, headers: { ...headers, ...(body ? { 'Content-Type': 'application/json' } : {}) }, ...(body ? { body: JSON.stringify(body) } : {}),
});
test('online health exposes only routing metadata and refuses the wrong Firebase project', async () => {
  const response = await worker.fetch(call('GET', 'health'), env);
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), { service: 'staff-scheduling', version: 1, projectId: 'men-hair-booking', transport: 'firestore-rest' });
  const wrong = await worker.fetch(call('GET', 'health'), { ...env, FIREBASE_SERVICE_ACCOUNT_JSON: '{"project_id":"other-project"}' });
  assert.equal(wrong.status, 503);
});
test('online scheduling rejects arbitrary method injection and non-POST mutations', async () => {
  assert.equal((await worker.fetch(call('POST', 'constructor', { data: {} }), env)).status, 404);
  assert.equal((await worker.fetch(call('GET', 'createStaffAccount'), env)).status, 405);
});
test('anonymous callers cannot grant themselves admin through a request body', async () => {
  const response = await worker.fetch(call('POST', 'createStaffAccount', { auth: { uid: 'admin' }, data: { uid: 'admin' } }), env);
  assert.equal(response.status, 401);
});
test('Firebase validates the bearer token; forged tokens and disabled accounts fail before service credentials are used', async () => {
  const original = globalThis.fetch;
  try {
    let token;
    globalThis.fetch = async (url, options) => {
      assert.equal(url, 'https://identitytoolkit.googleapis.com/v1/accounts:lookup?key=public-test-key');
      token = JSON.parse(options.body).idToken;
      return Response.json({ error: { message: 'INVALID_ID_TOKEN' } }, { status: 400 });
    };
    const request = () => call('POST', 'saveRoster', { data: {} }, { Authorization: 'Bearer forged-token' });
    assert.equal((await worker.fetch(request(), env)).status, 401);
    assert.equal(token, 'forged-token');
    globalThis.fetch = async () => Response.json({ users: [{ localId: 'disabled-user', disabled: true }] });
    assert.equal((await worker.fetch(request(), env)).status, 401);
  } finally { globalThis.fetch = original; }
});
