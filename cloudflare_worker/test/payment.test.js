import assert from 'node:assert/strict';
import { createHmac, webcrypto } from 'node:crypto';
import { test } from 'node:test';

globalThis.crypto ||= webcrypto;

const {
  default: worker,
  sortedQuery,
  hmacSha512,
  formatVietnamTime,
  canPayBooking,
  bookingStatusAfterPayment,
} = await import('../src/index.js');

test('auto-confirms a booking only after a successful VNPAY payment', () => {
  assert.equal(bookingStatusAfterPayment('pending', 'paid'), 'confirmed');
  assert.equal(bookingStatusAfterPayment('pending', 'failed'), 'pending');
  assert.equal(bookingStatusAfterPayment('pending', 'pending'), 'pending');
  assert.equal(bookingStatusAfterPayment('confirmed', 'paid'), 'confirmed');
});

test('permits immediate payment for a pending booking only when chosen', () => {
  assert.equal(canPayBooking({ status: 'pending', payment: { choice: 'pay_now' } }), true);
  assert.equal(canPayBooking({ status: 'pending', payment: { choice: 'pay_later' } }), false);
  assert.equal(canPayBooking({ status: 'confirmed', payment: { choice: 'pay_later' } }), true);
  assert.equal(canPayBooking({ status: 'cancelled', payment: { choice: 'pay_now' } }), false);
});

test('sorts and encodes VNPAY parameters consistently', () => {
  assert.equal(sortedQuery({ vnp_TxnRef: 'A 1', vnp_Amount: '15000000' }),
    'vnp_Amount=15000000&vnp_TxnRef=A+1');
});

test('signs VNPAY URL using HMAC-SHA512', async () => {
  const query = 'vnp_Amount=15000000&vnp_TxnRef=A+1';
  const secret = 'a-local-test-secret';
  assert.equal(await hmacSha512(secret, query),
    createHmac('sha512', secret).update(query).digest('hex'));
});

test('formats Vietnam time independently of server timezone', () => {
  assert.equal(formatVietnamTime(new Date('2026-09-14T04:00:00Z')),
    '20260914110000');
});

test('rejects unsigned IPN without changing payment state', async () => {
  const response = await worker.fetch(
    new Request('https://worker.example/vnpay-ipn?vnp_TxnRef=order1'),
    {
      VNP_TMN_CODE: 'TESTCODE',
      VNP_HASH_SECRET: 'a-local-test-secret',
      FIREBASE_WEB_API_KEY: 'test',
      FIREBASE_SERVICE_ACCOUNT_JSON: '{}',
    },
  );
  assert.deepEqual(await response.json(),
    { RspCode: '97', Message: 'Invalid signature' });
});
