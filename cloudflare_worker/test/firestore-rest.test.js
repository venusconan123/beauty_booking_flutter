import { test } from 'node:test';
import assert from 'node:assert/strict';
import { RestFirestore, encodeFields, decodeFields, makeWrite, rosterHints } from '../src/firestore-rest.js';
import primitives from '../src/firebase-primitives.cjs';
import { RestAuth } from '../src/staff-scheduling.js';

test('REST wire format preserves nested values, nulls, money and timestamps', () => {
  const data = { amount: 110000, zero: 0, active: false, value: null, rating: 4.5,
    appointmentAt: primitives.Timestamp.fromMillis(1893538800000), services: [{ name: 'Cắt tóc', price: 80000 }] };
  const decoded = decodeFields(encodeFields(data));
  assert.equal(decoded.appointmentAt.toMillis(), data.appointmentAt.toMillis());
  assert.deepEqual({ ...decoded, appointmentAt: null }, { ...data, appointmentAt: null });
});
test('partial payment updates mask only touched fields and use server receipt timestamps', () => {
  const write = makeWrite({ name: 'projects/demo/databases/(default)/documents/bookings/one' }, {
    'payment.status': 'paid', 'payment.paidAt': primitives.FieldValue.serverTimestamp(),
    'payment.receipt': { amount: 110000, recordedAt: primitives.FieldValue.serverTimestamp() },
  }, 'update');
  assert.deepEqual(write.updateMask.fieldPaths.sort(), ['payment.receipt', 'payment.status']);
  assert.deepEqual(write.updateTransforms.map((value) => value.fieldPath).sort(), ['payment.paidAt', 'payment.receipt.recordedAt']);
  assert.equal(write.currentDocument.exists, true);
});
test('transaction abort retries from fresh reads; rollback never commits a partial batch', async () => {
  const calls = []; let attempts = 0;
  const db = new RestFirestore({ projectId: 'demo-men-hair-booking', tokenProvider: async () => 'owner',
    fetchImpl: async (url, options) => {
      calls.push({ url, body: JSON.parse(options.body) });
      if (url.endsWith(':beginTransaction')) return Response.json({ transaction: `tx-${++attempts}` });
      if (url.endsWith(':commit') && attempts === 1) return Response.json({ error: { status: 'ABORTED' } }, { status: 409 });
      return Response.json({});
    } });
  const result = await db.runTransaction(async (tx) => { tx.create(db.doc('test/one'), { value: attempts }); return attempts; });
  assert.equal(result, 2);
  assert.equal(calls.filter((call) => call.url.endsWith(':rollback')).length, 1);
  assert.equal(calls.at(-1).body.transaction, 'tx-2');
  assert.equal(calls.at(-1).body.writes[0].update.fields.value.integerValue, '2');
});
test('roster hints batch guards and never accept path injection', () => {
  const hints = rosterHints({ cells: [{ employeeId: 'worker', dateKey: '2030-01-02' },
    { employeeId: 'worker', dateKey: '2030-01-03' }, { employeeId: '../admins', dateKey: '2030-01-02' }] });
  assert.deepEqual(hints.documents, ['employees/worker', 'employee_days/worker_2030-01-02', 'employee_days/worker_2030-01-03']);
  assert.deepEqual(rosterHints({ dates: 'invalid' }), { dates: [], documents: [] });
});
test('Firestore field names cannot mutate the wire object prototype', () => {
  const data = JSON.parse('{"__proto__":{"polluted":true},"normal":1}');
  const write = makeWrite({ name: 'test/doc' }, data, 'create');
  assert.equal({}.polluted, undefined);
  assert.equal(JSON.parse(JSON.stringify(write)).update.fields.__proto__.mapValue.fields.polluted.booleanValue, true);
});
test('Workers fetch keeps its global receiver for both Auth and Firestore', async () => {
  async function fetchWithReceiver(url) {
    assert.equal(this, globalThis, 'Workers global fetch must not receive the adapter instance');
    if (url.includes('accounts:lookup')) return Response.json({ users: [{ localId: 'test-user' }] });
    return Response.json([{ missing: 'projects/demo-men-hair-booking/databases/(default)/documents/test/one' }]);
  }
  const options = { projectId: 'demo-men-hair-booking', tokenProvider: async () => 'owner', fetchImpl: fetchWithReceiver };
  assert.equal((await new RestAuth(options).getUser('test-user')).uid, 'test-user');
  const db = new RestFirestore(options);
  assert.equal((await db.doc('test/one').get()).exists, false);
});
