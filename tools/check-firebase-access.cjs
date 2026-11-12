// Read-only permission probe using the already authenticated Firebase CLI.
// Never prints credentials and never grants permissions or writes project data.
const path = require('node:path');
const root = process.env.FIREBASE_TOOLS_ROOT;
if (!root) throw new Error('Set FIREBASE_TOOLS_ROOT to the firebase-tools package directory.');
const { getGlobalDefaultAccount } = require(path.join(root, 'lib/auth'));
const { requireAuth } = require(path.join(root, 'lib/requireAuth'));
const { testIamPermissions } = require(path.join(root, 'lib/gcp/iam'));

async function main() {
  if (process.env.FIREBASE_SKIP_INFORMATIONAL_IAM) {
    throw new Error('Refusing to skip the actual IAM check.');
  }
  const account = getGlobalDefaultAccount();
  if (!account) throw new Error('No existing Firebase CLI login.');
  const project = 'men-hair-booking';
  await requireAuth({ project, user: account.user, tokens: account.tokens, nonInteractive: true });
  const permissions = [
    'firebase.projects.get', 'firebase.clients.list',
    'datastore.databases.get', 'datastore.databases.getMetadata',
    'datastore.entities.get', 'datastore.entities.list',
    'datastore.entities.create', 'datastore.entities.update',
    'firebaserules.rulesets.get', 'firebaserules.rulesets.list',
    'firebaserules.rulesets.create', 'firebaserules.releases.get',
    'firebaserules.releases.list', 'firebaserules.releases.create',
    'firebaserules.releases.update',
    'firebaseauth.users.get', 'firebaseauth.users.create', 'firebaseauth.users.update',
    'resourcemanager.projects.getIamPolicy',
    'cloudfunctions.functions.get', 'cloudfunctions.functions.list',
    'cloudfunctions.functions.create', 'cloudfunctions.functions.update',
    'cloudbuild.builds.create', 'cloudbuild.builds.get',
    'artifactregistry.repositories.get', 'artifactregistry.repositories.create',
    'artifactregistry.repositories.uploadArtifacts',
    'run.services.get', 'run.services.create', 'run.services.update',
    'serviceusage.services.get', 'serviceusage.services.list',
    'serviceusage.services.use', 'serviceusage.services.enable',
    'iam.serviceAccounts.actAs',
  ];
  const result = await testIamPermissions(project, permissions);
  console.log(JSON.stringify({ project, account: account.user.email, ...result }, null, 2));
}
main().catch((error) => { console.error(error.message); process.exitCode = 1; });
