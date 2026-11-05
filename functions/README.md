# Staff phase one — local review

No production migration or deployment is included. `firebase.json` is unchanged.
The pre-existing `tools/check-firebase-access.cjs` is retained; it is not used by
the emulator or the test suite.

## Scope

- Shared email/password sign-in, then live admin/customer/staff role routing.
- `staff_accounts/{uid}` maps Auth UID to employee; `employee_accounts/{employeeId}`
  holds the inverse. Links are immutable, including after deactivation. Both
  directions are created in one transaction. Repeating the identical link is a
  no-op. Concurrent competing links cannot both commit.
- Admin-only callables validate an existing, enabled, email-verified Auth user,
  an existing active employee, and primary branch `salon_01`, `salon_02` or
  `salon_03`. They never create Auth users, grant admin roles, or change IAM.
- Deactivation changes only `staff_accounts.active`; it preserves all records.
  Rules check the account, inverse link, and live employee profile on each read.
  The UI listens to all three and disposes the staff workspace when blocked.
  Role routing and appointment display wait for server-confirmed snapshots;
  cached/offline permissions do not reopen the employee workspace.
- Staff can read bookings where `barberId` equals their linked employee ID.
  Primary branch is taken from the existing employee profile, never client input.
  An admin role remains independent and takes priority over a staff link.
- New links, audit records and activation flags cannot be written directly by
  any client, including admin clients. They use authorized backend transactions.

## Local commands (PowerShell)

Use Java 21 and Node 22 for the backend. The first local verification also ran
on the host's Node 24; final verification uses Node 22 from a temporary cache
without replacing the system installation.

```powershell
$env:JAVA_HOME = 'C:\Program Files\Android\Android Studio\jbr'
$env:PATH = $env:JAVA_HOME + '\bin;' + $env:PATH
npm --prefix functions ci
npx -y firebase-tools@latest emulators:exec --project demo-men-hair-booking --config firebase.emulator.json --only "auth,firestore,functions" "npm --prefix functions test"
flutter analyze --no-pub
flutter test --no-pub
node --test cloudflare_worker/test/payment.test.js
```

Tests refuse to run unless the Auth/Firestore hosts are loopback and the project
is exactly `demo-men-hair-booking`. All accounts and fixture data are ephemeral
emulator data. No production credentials are required.

## Interactive preview

In one terminal, start the emulators:

```powershell
npx -y firebase-tools@latest emulators:start --project demo-men-hair-booking --config firebase.emulator.json --only "auth,firestore,functions"
```

In a second terminal, seed local preview accounts and run the app:

```powershell
$env:GCLOUD_PROJECT = 'demo-men-hair-booking'
$env:FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080'
$env:FIREBASE_AUTH_EMULATOR_HOST = '127.0.0.1:9099'
node functions/tools/seed-local.cjs
flutter run -d chrome --dart-define=FIREBASE_EMULATORS=true
```

The script prints local demo credentials. Sign in as staff to see assigned
appointments, or as admin to open **Tài khoản nhân viên** from the admin menu.
Two browsers/profiles allow testing deactivation while staff is signed in.
The app explicitly initializes a demo project with local Auth and Firestore;
payments and staff-link mutations cannot reach production from this mode.
Outside emulator mode, new staff-link mutations are disabled in this review build.

## Firebase change preview

After future approval, linking one existing UID/employee pair would create:

1. `staff_accounts/{uid}`: employeeId, active, createdAt, updatedAt, updatedBy.
2. `employee_accounts/{employeeId}`: uid, createdAt.
3. A `staff.link` event in `audit_events`.

Activating/deactivating would update active/updatedAt/updatedBy and add an audit
event. No employee profile, existing appointment, account or database is deleted.
New Rules permit staff-only assigned appointment reads and deny client writes to
the link and audit collections. Existing customer/admin rules are retained.
These prototype Rules have only been validated for this phase; the broader
booking validation issues identified before this work are still out of scope.

## Deferred phases

Starting/completing appointments, shift authoring/recurrence/swaps, colleague
shift visibility, completion snapshots and financial statistics are not enabled.
The schedule and statistics tabs explicitly show that they are not available yet.
Production billing/API/service-account checks, deployment config, migration,
account provisioning and push are also excluded. Do not deploy this branch as a
standalone app update: production Rules must be reviewed and coordinated with
role routing, otherwise the new role reads will fail closed.

## Verification notes

- Flutter analyzer: no issues; Flutter tests: 9 passed.
- Auth/Firestore/Functions Emulator suite: 12 tests, including concurrent link
  attempts in both directions, active-session deactivation, role spoofing,
  private data access, missing profiles and authenticated callable HTTP.
- Existing VNPAY Worker tests: 8 passed.
- Dependency audit after compatible patches: 0 high/critical findings, 6
  moderate findings in indirect glob/minimatch/rimraf and Google client
  dependencies. No forced major transitive overrides were applied for these.
