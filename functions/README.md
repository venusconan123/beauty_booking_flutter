# Staff accounts — email provisioning (10/11/2026)

Android + live Firebase Spark backend (12/11/2026):
[SPARK_ANDROID.md](../docs/SPARK_ANDROID.md). The default app now uses the
Cloudflare HTTPS transport; Firebase Functions deployment/Blaze is not required.

Current demo startup and end-to-end verification (12/11/2026):
[DEMO_RUNBOOK.md](../docs/DEMO_RUNBOOK.md). It supersedes the historical phase
counts and deferred-feature notes below for the local emulator demo.

The main app (`lib/main.dart`, normal `flutter run -d chrome`) uses one login.
Admins open **Tài khoản nhân viên**, choose an existing active employee and enter
the employee's email plus an initial password (8–128 characters for a new user).
`createStaffAccount` checks the admin on the server, accepts a NEW email only,
creates its Auth identity, and links both account directions transactionally.
As of 13/11/2026, any existing email (customer, staff, admin, disabled or
unverified) is rejected with `already-exists`: **Email này đã được sử dụng.**
It never upgrades an existing customer through this creation endpoint, even if
the customer signs up between the lookup and Auth creation. Role links
and private email are readable only by their owner/admin; clients cannot write
them. Passwords are sent over the authenticated callable and never stored in
Firestore, returned by the callable, or logged by application code.

New staff verify their email from the login verification screen, then enter
**Lịch làm** by default. They have no required customer `users` profile. Disabled
staff/employee records still block access. If Auth creation succeeds but linking
fails (for example an admin revocation), an administrator must inspect the
partially provisioned Auth entry. The strict new-email policy does not silently
attach existing accounts on retry; no employee permissions exist until both
links commit. Duplicate create attempts do not change passwords or add audits.

Production inspection is saved under `docs/firebase-staff-rollout`. The live
baseline lacked staff/shift rules and billing was disabled. The targeted
`firestore.staff-compat.rules` adds staff reads to that baseline, retaining its
existing booking/payment behavior. `firestore.rules` is the stricter scheduling
v2 candidate; do not substitute it for this targeted rollout without the full
scheduling cutover. `firebase.staff-rollout.json` selects the compatibility file.

The reviewed read-rules deployment uses
`node tools/deploy-staff-read-rules.cjs --apply`, with `FIREBASE_TOOLS_ROOT`
set to the installed firebase-tools package.
It checks for a changed live baseline, compiles/publishes the rules, verifies
the release, and creates the shift index without deleting other indexes.
The prior release/content is retained for a targeted rollback. The rules were
published and the active release verified; see `deployed.json`. The compatibility
rules and callable HTTP suite passed 19/19 before publication.

Cloud Functions deployment requires Blaze. The user chose to retain Spark and
test in Firebase Emulator; no billing was activated and no production Functions
were deployed. If Blaze is approved later, deploy only
`createStaffAccount`, `linkStaffAccount`, and `setStaffAccountActive` from the
`staff` codebase for this feature. Set `app_settings/scheduling_v2` to protocol 2
with `staffWritesEnabled: true`, preserving any existing fields; do not enable
booking/roster/payment writes as part of account provisioning. If the document
is absent, create it with those other three flags false. Never seed real staff
accounts or replace existing Auth records during deployment.

Validation: full emulator suite 48/48; Flutter suite 28/28 before the additional
default-schedule check; focused staff/transport tests 11/11 and analyzer clean.
The compatibility-rules suite also checks the real callable HTTP wrapper.

Interactive verification: the main app was built in release mode with
`FIREBASE_EMULATORS=true`, served at `http://127.0.0.1:7359`, and staff sign-in
was observed opening the selected **Lịch làm** tab with branch shifts loaded.
Demo accounts: `local-admin@example.test`, `local-staff@example.test`,
`local-customer@example.test`; shared demo password `Local-demo-123!`.
These credentials exist only in the emulator. Admins can use the two unlinked
employee fixtures to try creating an account through the email form.
Verification mail is simulated: press **Gửi email xác minh** and use the action
link printed by the Auth emulator (it is not delivered to a real mailbox).
For manual restarts use the emulator/seed commands below, then run
`flutter run -d chrome --dart-define=FIREBASE_EMULATORS=true` from this repository.

## Staff appointments and statistics (10/11/2026)

The main staff portal now has searchable assigned appointments with status/day
filters, customer/service/payment details and confirmed status actions. Staff
may start only their own verified, active assignment when its Vietnam appointment
day is today and its time has arrived; only one appointment may be in service.
Staff completion requires `in_service`. Backend transactions recheck both role
links and employee state, write timestamps/actor IDs, retain retry IDs, release
slots on completion and preserve the existing loyalty workflow. Completion
does not collect money or change the booking price/payment. Admin/customer
appointment lists recognize `in_service` so those appointments remain visible.

Personal statistics reuse one portal-lifetime assigned-booking subscription
(switching tabs never resubscribes), with day/week (Monday
start)/month/year/all filters based on the Vietnam appointment date. Completed
service value uses `totalPrice` after discounts; the paid subset requires
`payment.status == paid`. These figures are neither salary/commission nor a
cash receipt ledger. No new Firestore collections, read grants or production
deployment are required for these screens. Status actions are tested locally;
the real project remains Spark without production Functions.

The seed script adds create-if-absent fixtures for `local-employee` and
`local-cross`: two confirmed appointments today plus two completed historical
appointments, one paid and one unpaid. Existing emulator account links and
completed actions are retained on reseed. These are demo records only.

Validation: Firebase emulator suite 50/50, including employee isolation,
verification/deactivation checks, idempotent completion and concurrent start
protection. Flutter model/widget tests cover Vietnam period boundaries,
payment separation, phone layout, confirmation and definitive rejection.
Direct browser verification with `nhanvien2@example.test` started and completed
one demo appointment, then opened Statistics: 4 assigned appointments, 3
completed, completed service value 240,000 VND and paid subset 80,000 VND.
One additional confirmed appointment remains for the user to try. Live
Firestore permissions/data and billing were not changed for this feature.

## Admin collection after service completion (10/11/2026)

In **Quản lý lịch hẹn → Hoàn thành**, an unpaid `pay_later` booking has a
**Ghi nhận thanh toán** button. Admin chooses cash or bank transfer, verifies
the already-received full amount shown after discounts, then confirms. This is
manual bookkeeping, not a transfer or charge. Partial payments/refunds are not
introduced. Paid VNPAY transactions are never overwritten or collected again.

`recordBookingPayment` rechecks the admin and booking write switch inside a
transaction, requires `completed`/`unpaid`/`pay_later` and an exact expected total,
and records payment status/method/paidAt/paidBy plus `payment.receipt` with stable
ID, amount, employee, branch, actor and server timestamp. The same transaction
adds one audit event and one customer notification. The booking read is the
guard against two admins collecting concurrently; different requests after
payment return already-paid without another receipt. The client preserves its
request ID for uncertain retries. No new collection or client write grant is
needed; existing booking permissions protect the receipt.

The admin dashboard now separates completed service value, paid completed
value and remaining unpaid completed value (within its existing created-date
filter). Staff statistics update from the same live booking payment change
and continue to use the labeled Vietnam appointment-date period. Completing
service alone does not count as collection. Receipt details are visible on the
admin booking, and manual payment is labeled separately from VNPAY.

Validation: Firebase emulator suite 52/52, covering forbidden actors, unfinished
or cancelled bookings, stale amounts, concurrent collection, replay and retaining
online payments. Flutter tests cover confirmation/cancel, selected method and
retaining the same request payload after a lost response. This feature is run
in the existing local emulator; Spark/billing and production Functions remain
unchanged as requested.

Browser verification recorded 80,000 VND cash on the completed
`staff-demo-local-cross-2026-11-10` fixture; the paid banner, server receipt,
`local-admin` actor and timestamp appeared. The dashboard then showed completed
service value 400,000 VND, paid completed value 240,000 VND and outstanding
160,000 VND. An admin-screen timer/dialog lifecycle regression was also fixed:
one booking stream is retained for the screen lifetime so refreshes do not
dispose the payment button while its confirmation is open. The regression test
advances that timer while the dialog is open and verifies the same button state.

## Historical phase-one review notes

Phase 2A implementation, safety boundaries and test/demo instructions are now
documented in [PHASE_2A.md](PHASE_2A.md). This file retains the phase-one baseline.

No production migration or deployment is included. The phase-one instructions
below are historical; current local index configuration is described in the
development handoff. Local permission-probe scripts are excluded from this commit
and are not used by the emulator or test suite.

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
npx -y firebase-tools@latest emulators:exec --project demo-men-hair-booking --config firebase.test.json --only "auth,firestore,functions" "npm --prefix functions test"
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

## Development snapshot

Monthly-roster development is paused and remains unverified. See
[MONTHLY_ROSTER_WIP.md](MONTHLY_ROSTER_WIP.md) before continuing or interpreting
the earlier verification results in this repository.
