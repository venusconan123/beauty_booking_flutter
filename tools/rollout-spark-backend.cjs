'use strict';
// Explicit-project rollout. Back up the live rules/control first. No billing,
// deletion, Auth changes, or employee/booking fixtures are performed here.
const fs = require('node:fs');
const path = require('node:path');
const project = 'men-hair-booking';
const root = process.env.FIREBASE_TOOLS_ROOT;
if (!root) throw new Error('FIREBASE_TOOLS_ROOT is required');
const { getGlobalDefaultAccount } = require(path.join(root, 'lib/auth'));
const { requireAuth } = require(path.join(root, 'lib/requireAuth'));
const { Client } = require(path.join(root, 'lib/apiv2'));
const rules = require(path.join(root, 'lib/gcp/rules'));
const repo = path.join(__dirname, '..');
async function main() {
  const account = getGlobalDefaultAccount();
  if (!account) throw new Error('Firebase CLI login required');
  await requireAuth({ project, user: account.user, tokens: account.tokens, nonInteractive: true });
  const db = new Client({ urlPrefix: 'https://firestore.googleapis.com', apiVersion: 'v1' });
  const base = `/projects/${project}/databases/(default)`;
  async function list(collection) {
    const rows = []; let pageToken;
    do {
      const result = await db.get(`${base}/documents/${collection}`, { queryParams: { pageSize: 300, ...(pageToken ? { pageToken } : {}) }, skipLog: { resBody: true } });
      rows.push(...(result.body.documents || [])); pageToken = result.body.nextPageToken;
    } while (pageToken);
    return rows;
  }
  const release = (await rules.listAllReleases(project)).find((r) => r.name.endsWith('/releases/cloud.firestore'));
  const currentRules = await rules.getRulesetContent(release.rulesetName);
  let control = null;
  try { control = (await db.get(`${base}/documents/app_settings/scheduling_v2`, { skipLog: { resBody: true } })).body; }
  catch (error) { if (error.status !== 404) throw error; }
  const [bookings, employees, services] = await Promise.all([list('bookings'), list('employees'), list('services')]);
  const invalid = bookings.filter((row) => {
    const value = row.fields;
    if (['completed', 'cancelled'].includes(value.status?.stringValue)) return false;
    const duration = Number(value.totalDurationMinutes?.integerValue || value.services?.arrayValue?.values?.reduce((total, service) => total + Number(service.mapValue?.fields?.durationMinutes?.integerValue || 0), 0));
    return !value.appointmentAt?.timestampValue || !Number.isInteger(duration) || duration <= 0;
  });
  const report = { project, previousRuleset: release.rulesetName, bookings: bookings.length,
    employees: employees.length, services: services.map((row) => row.name.split('/').at(-1)), invalidActiveBookings: invalid.map((row) => row.name.split('/').at(-1)),
    controlExists: !!control };
  console.log(JSON.stringify(report, null, 2));
  if (invalid.length) throw new Error('Active legacy bookings need repair before switching to the guarded backend. No cloud changes made.');
  if (!process.argv.includes('--apply')) return;
  const health = await fetch('https://men-hair-booking-vnpay.venusconan23.workers.dev/api/scheduling/health');
  const ready = await health.json();
  if (!health.ok || ready.projectId !== project || ready.version !== 1) throw new Error('Online Worker is not ready for the exact project.');
  const folder = path.join(repo, '.firebase', 'spark-rollout', new Date().toISOString().replaceAll(':', '-'));
  fs.mkdirSync(folder, { recursive: true });
  fs.writeFileSync(path.join(folder, 'backup.json'), JSON.stringify({ project, release, files: currentRules, control, services }, null, 2));
  const content = fs.readFileSync(path.join(repo, 'firestore.rules'), 'utf8').replace(/^\uFEFF/, '');
  const rulesetName = await rules.createRuleset(project, [{ name: 'firestore.rules', content }]);
  const recheck = (await rules.listAllReleases(project)).find((r) => r.name === release.name);
  if (recheck.rulesetName !== release.rulesetName) throw new Error('Live rules changed concurrently; aborting publication.');
  await rules.updateRelease(project, rulesetName, 'cloud.firestore');
  const verified = (await rules.listAllReleases(project)).find((r) => r.name === release.name);
  if (verified.rulesetName !== rulesetName) throw new Error('Could not verify active rules release');
  const indexes = JSON.parse(fs.readFileSync(path.join(repo, 'firestore.indexes.json'))).indexes;
  for (const index of indexes) {
    const url = `${base}/collectionGroups/${index.collectionGroup}/indexes`;
    const existing = (await db.get(url, { skipLog: { resBody: true } })).body.indexes || [];
    const found = existing.find((entry) => entry.queryScope === index.queryScope && index.fields.every((field, position) =>
      entry.fields[position]?.fieldPath === field.fieldPath && entry.fields[position]?.order === field.order));
    if (!found) await db.post(url, { queryScope: index.queryScope, fields: index.fields });
    for (let attempt = 0; attempt < 60; attempt++) {
      const states = (await db.get(url, { skipLog: { resBody: true } })).body.indexes || [];
      const ready = states.find((entry) => index.fields.every((field, position) =>
        entry.fields[position]?.fieldPath === field.fieldPath && entry.fields[position]?.order === field.order));
      if (ready?.state === 'READY') break;
      if (ready?.state === 'NEEDS_REPAIR' || attempt === 59) throw new Error('Shift index is not ready; write controls have not been enabled.');
      console.log(`Waiting for ${index.fields[0].fieldPath}/dateKey index...`);
      await new Promise((resolve) => setTimeout(resolve, 5000));
    }
  }
  // The Flutter catalog includes these fallbacks even before documents exist.
  // Materialize missing fallbacks so server pricing matches that existing UI.
  // Existing administrator prices, disabled services and custom records stay intact.
  const defaults = [
    ['service_combo_10', 'Combo 10 bước', 150000, 60, 'Combo chăm sóc tóc và thư giãn gồm 10 bước.'],
    ['service_hair_cut', 'Cắt tóc nam', 80000, 30, 'Tư vấn và cắt tóc theo kiểu phù hợp với khách hàng.'],
    ['service_hair_wash', 'Gội đầu', 30000, 20, 'Gội sạch tóc kết hợp massage thư giãn.'],
    ['service_styling', 'Tạo kiểu', 50000, 30, 'Sấy và tạo kiểu tóc theo yêu cầu.'],
    ['service_perm', 'Uốn tóc', 250000, 120, 'Uốn và tạo kiểu tóc nam.'],
    ['service_dye', 'Nhuộm tóc', 300000, 150, 'Tư vấn màu và nhuộm tóc theo yêu cầu.'],
    ['service_skin_care', 'Chăm sóc da', 100000, 45, 'Làm sạch và chăm sóc da mặt cơ bản.'],
  ];
  const present = new Set(services.map((row) => row.name.split('/').at(-1)));
  const writes = defaults.flatMap(([id, name, price, durationMinutes, description], order) => present.has(id) ? [] : [{
    update: { name: `projects/${project}/databases/(default)/documents/services/${id}`, fields: {
      name: { stringValue: name }, price: { integerValue: String(price) }, durationMinutes: { integerValue: String(durationMinutes) },
      description: { stringValue: description }, isActive: { booleanValue: true }, order: { integerValue: String(order) },
    } }, currentDocument: { exists: false }, updateTransforms: [{ fieldPath: 'createdAt', setToServerValue: 'REQUEST_TIME' }],
  }]);
  if (writes.length) await db.post(`${base}/documents:commit`, { writes });
  // Keep existing values; enable the reviewed server-only protocol last.
  const fields = { protocolVersion: { integerValue: '2' }, backend: { stringValue: 'cloudflare' },
    staffWritesEnabled: { booleanValue: true }, rosterWritesEnabled: { booleanValue: true },
    bookingWritesEnabled: { booleanValue: true }, paymentCreationEnabled: { booleanValue: true } };
  await db.post(`${base}/documents:commit`, { writes: [{
    update: { name: `projects/${project}/databases/(default)/documents/app_settings/scheduling_v2`, fields },
    updateMask: { fieldPaths: Object.keys(fields) },
    currentDocument: control ? { updateTime: control.updateTime } : { exists: false },
  }] });
  fs.writeFileSync(path.join(folder, 'result.json'), JSON.stringify({ ...report, rulesetName, activatedAt: new Date().toISOString() }, null, 2));
  console.log(JSON.stringify({ project, rulesetName, backupFolder: folder, configured: true, billingChanged: false }, null, 2));
}
main().catch((error) => { console.error(error.message); process.exitCode = 1; });
