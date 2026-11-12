// Targeted deployment: retain live booking/payment rules; add staff read access.
// Refuses to replace a ruleset changed since inspect-staff-firebase.cjs ran.
const fs = require('node:fs');
const path = require('node:path');
const root = process.env.FIREBASE_TOOLS_ROOT;
if (!root) throw new Error('FIREBASE_TOOLS_ROOT is required');
const { getGlobalDefaultAccount } = require(path.join(root, 'lib/auth'));
const { requireAuth } = require(path.join(root, 'lib/requireAuth'));
const { Client } = require(path.join(root, 'lib/apiv2'));
const rules = require(path.join(root, 'lib/gcp/rules'));
async function main() {
  if (!process.argv.includes('--apply')) throw new Error('Pass --apply to publish the reviewed staff-read rules.');
  const project = 'men-hair-booking';
  const account = getGlobalDefaultAccount();
  if (!account) throw new Error('Firebase CLI login required');
  await requireAuth({ project, user: account.user, tokens: account.tokens, nonInteractive: true });
  const folder = path.join(__dirname, '../docs/firebase-staff-rollout');
  const inventory = JSON.parse(fs.readFileSync(path.join(folder, 'inventory.json')));
  const releaseName = `projects/${project}/releases/cloud.firestore`;
  const current = (await rules.listAllReleases(project)).find(r => r.name === releaseName);
  if (current?.rulesetName !== inventory.rulesetName) throw new Error('Live rules changed. Review the new baseline before applying.');
  const content = fs.readFileSync(path.join(__dirname, '../firestore.staff-compat.rules'), 'utf8').replace(/^\uFEFF/, '');
  const rulesetName = await rules.createRuleset(project, [{ name: 'firestore.rules', content }]);
  const recheck = (await rules.listAllReleases(project)).find(r => r.name === releaseName);
  if (recheck?.rulesetName !== inventory.rulesetName) throw new Error('Live release changed during compilation; not publishing.');
  await rules.updateRelease(project, rulesetName, 'cloud.firestore');
  const actual = (await rules.listAllReleases(project)).find(r => r.name === releaseName);
  if (actual?.rulesetName !== rulesetName) throw new Error('Published release could not be verified');
  const result = { project, previousRuleset: inventory.rulesetName, rulesetName,
    verifiedAt: new Date().toISOString(), functionsDeployed: false };
  fs.writeFileSync(path.join(folder, 'deployed.json'), JSON.stringify(result, null, 2));
  console.log(JSON.stringify(result, null, 2));
  const db = new Client({ urlPrefix: 'https://firestore.googleapis.com', apiVersion: 'v1' });
  const indexPath = `/projects/${project}/databases/(default)/collectionGroups/work_shifts/indexes`;
  const existing = (await db.get(indexPath, { skipLog: { resBody: true } })).body.indexes ?? [];
  const found = existing.find(i => i.queryScope === 'COLLECTION' && i.fields?.[0]?.fieldPath === 'salonId' &&
    i.fields[0].order === 'ASCENDING' && i.fields?.[1]?.fieldPath === 'dateKey' && i.fields[1].order === 'ASCENDING');
  result.index = found ? { name: found.name, state: found.state } :
    (await db.post(indexPath, { queryScope: 'COLLECTION', fields: [
      { fieldPath: 'salonId', order: 'ASCENDING' }, { fieldPath: 'dateKey', order: 'ASCENDING' },
    ] })).body;
  fs.writeFileSync(path.join(folder, 'deployed.json'), JSON.stringify(result, null, 2));
  console.log('Shift query index checked/created without deleting other indexes.');
}
main().catch(e => { console.error(e.message); process.exitCode = 1; });
