'use strict';
// Only the unique email namespace created by salon_assistant_live_test.dart.
// Defaults to preview; never targets staff/customer or other test namespaces.
const path = require('node:path');
async function main() {
  const root = process.env.FIREBASE_TOOLS_ROOT;
  if (!root) throw Error('FIREBASE_TOOLS_ROOT is required');
  const { getGlobalDefaultAccount, getAccessToken } = require(path.join(root, 'lib/auth'));
  const { requireAuth } = require(path.join(root, 'lib/requireAuth'));
  const account = getGlobalDefaultAccount();
  if (!account) throw Error('Firebase CLI login required');
  const options = { project: 'men-hair-booking', user: account.user, tokens: account.tokens, nonInteractive: true };
  await requireAuth(options);
  const token = (await getAccessToken(account.tokens.refresh_token, options.authScopes)).access_token;
  const base = 'https://identitytoolkit.googleapis.com/v1/projects/men-hair-booking/accounts';
  const headers = { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' };
  let pageToken;
  const matches = [];
  do {
    const url = new URL(`${base}:batchGet`);
    url.searchParams.set('maxResults', '1000');
    if (pageToken) url.searchParams.set('nextPageToken', pageToken);
    const response = await fetch(url, { headers, signal: AbortSignal.timeout(30000) });
    const value = await response.json();
    if (!response.ok) throw Error(`Auth list failed: ${response.status}`);
    matches.push(...(value.users || []).filter(user => /^ai-ui-\d{15,18}-\d{1,10}@example\.test$/.test(user.email || '') &&
      Number(user.createdAt) >= Date.parse('2026-11-13T00:00:00+07:00')));
    pageToken = value.nextPageToken;
  } while (pageToken);
  console.log(JSON.stringify({ matchingAiUiTestAccounts: matches.length, apply: process.argv.includes('--apply') }));
  if (process.argv.includes('--apply')) {
    for (const user of matches) {
      const response = await fetch(`${base}:delete`, { method: 'POST', headers,
        body: JSON.stringify({ localId: user.localId }), signal: AbortSignal.timeout(30000) });
      if (!response.ok) throw Error(`Test account cleanup failed: ${response.status}`);
    }
    console.log(`Removed ${matches.length} isolated AI UI test accounts.`);
  }
}
main().catch(error => { console.error(error.message); process.exitCode = 1; });
