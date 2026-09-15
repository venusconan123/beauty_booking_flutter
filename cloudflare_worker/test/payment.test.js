import assert from 'node:assert/strict';
import { createHmac, webcrypto } from 'node:crypto';
import { test } from 'node:test';

globalThis.crypto ||= webcrypto;

const { default: worker, sortedQuery, hmacSha512, formatVietnamTime } =
  await import('../src/index.js');

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
