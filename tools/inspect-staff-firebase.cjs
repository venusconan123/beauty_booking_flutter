// Read-only cloud inventory. Uses the existing Firebase CLI login, never prints tokens.
const fs = require('node:fs');
const path = require('node:path');
const root = process.env.FIREBASE_TOOLS_ROOT;
if (!root) throw new Error('FIREBASE_TOOLS_ROOT is required');
const { getGlobalDefaultAccount } = require(path.join(root, 'lib/auth'));
const { requireAuth } = require(path.join(root, 'lib/requireAuth'));
const { Client } = require(path.join(root, 'lib/apiv2'));
const rules = require(path.join(root, 'lib/gcp/rules'));
async function main() {
  const project = 'men-hair-booking';
  const account = getGlobalDefaultAccount();
  if (!account) throw new Error('Firebase CLI login required');
  await requireAuth({ project, user: account.user, tokens: account.tokens, nonInteractive: true });
  const folder = path.join(__dirname, '../docs/firebase-staff-rollout');
  fs.mkdirSync(folder, { recursive: true });
  const releases = await rules.listAllReleases(project);
  const release = releases.find(r => r.name.endsWith('/releases/cloud.firestore'));
  if (!release) throw new Error('Firestore release not found');
  const files = await rules.getRulesetContent(release.rulesetName);
  const backup = path.join(folder, 'live-before.rules');
  if (!fs.existsSync(backup)) fs.writeFileSync(backup, files.map(f => f.content).join('\n'));
  const output = { project, rulesetName: release.rulesetName,
    hasStaffAccounts: files.some(f => f.content.includes('match /staff_accounts/')),
    hasWorkShifts: files.some(f => f.content.includes('match /work_shifts/')) };
  const billing = new Client({ urlPrefix: 'https://cloudbilling.googleapis.com', apiVersion: 'v1' });
  try { output.billingEnabled = (await billing.get(`/projects/${project}/billingInfo`, { skipLog: { resBody: true } })).body.billingEnabled; }
  catch (e) { output.billingError = e.message; }
  const db = new Client({ urlPrefix: 'https://firestore.googleapis.com', apiVersion: 'v1' });
  const base = `/projects/${project}/databases/(default)/documents`;
  for (const name of ['admins', 'staff_accounts', 'employee_accounts', 'work_shifts']) {
    const result = await db.get(`${base}/${name}`, { queryParams: { pageSize: 100 }, skipLog: { resBody: true } });
    output[`${name}CountFirstPage`] = result.body.documents?.length ?? 0;
  }
  try { output.control = (await db.get(`${base}/app_settings/scheduling_v2`, { skipLog: { resBody: true } })).body.fields; }
  catch (e) { output.controlError = e.status === 404 ? 'missing' : e.message; }
  output.shiftIndexes = ((await db.get(`/projects/${project}/databases/(default)/collectionGroups/work_shifts/indexes`,
    { skipLog: { resBody: true } })).body.indexes ?? []).map(i => ({ name: i.name, state: i.state }));
  const inventoryPath = path.join(folder, 'inventory.json');
  fs.writeFileSync(fs.existsSync(inventoryPath) ? path.join(folder, 'inventory-latest.json') : inventoryPath,
    JSON.stringify(output, null, 2));
  console.log(JSON.stringify(output, null, 2));
}
main().catch(e => { console.error(e.message); process.exitCode = 1; });
