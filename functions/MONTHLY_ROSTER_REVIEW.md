# Monthly roster verification

Local development only, on `codex/staff-phase-one`. No production writes,
deployment, merge, commit or push are part of this continuation.

## Implemented

- Monthly employee/day matrix with branch/month/year filters, weekday headers,
  frozen employee names and header, and horizontal scrolling. Saved work shifts,
  explicit OFF and unassigned cells have separate rendering and a time legend.
- Admin multi-cell assignment, weekday recurrence, immutable preview with
  expected revisions, cell details, replacement/cancellation and two-cell swap.
  Replaced records are soft-cancelled; historical records remain available.
- Staff have a read-only matrix restricted to their linked primary branch.
  Rules now enforce that restriction even for their own shifts outside it.
- Backend validates every cell, checks all-branch employee occupancy and active
  appointments, then applies the whole batch atomically. Shared employee/day
  guards serialize bookings, assignment, edits, cancellations and swaps.
- A/B checks all four employee/day combinations for active bookings and checks
  destination overlap. Stable request IDs and operation receipts prevent replay
  from creating duplicate assignments.
- Hardened roster input against cell-level field overrides, duplicate/stale
  revisions and malformed cells. Legacy custom shift codes and missing times
  render safely.

## Automated verification

The 2026-11-06 local run passed 34/34 backend/Rules Emulator tests. Backend and
Rules code has not changed since that run. The final 2026-11-09 Flutter run
passed 18/18 tests and `flutter analyze --no-pub` reported no issues. Logs are
local ignored artifacts in `.dart_tool`.

Backend coverage includes OFF persistence/replay, history, cancellation, stale
previews, all-branch overlaps, valid non-overlapping cross-branch shifts,
appointments blocking OFF/shortening, all-or-nothing batches, booking versus OFF,
simultaneous assignments and the existing A/B four-day and race tests.

Flutter coverage includes month lengths, old records, recurrence, expected
revisions, a 390px-wide frozen-pane/scroll widget test and read-only staff taps.
These are not evidence of a completed browser workflow.

Scoped Rules checks: unauthenticated reads denied; staff home-branch get and
monthly query allowed; foreign-branch reads/queries denied, including own shifts;
direct create/update/delete denied even to admin clients. Malformed fields,
ownership changes, oversized values and timestamp changes cannot bypass the
backend-only write boundary. This is a prototype review of the schedule path,
not a claim that every unrelated collection has been audited.

## Browser verification

The actual Web login screen renders, but the first browser run rejected demo
login with `api-key-not-valid`. The served bundle was checked, rather than
assuming a rebuild had taken effect. FlutterFire 6.2.7 can skip the emulator
connection because of a session hint, and can silently ignore a connection made
after persisted Auth restoration has begun.

Removing the old session hint alone, and the SDK default emulator-host option,
did not fix persisted-session reload: FlutterFire calls `initializeAuth` directly
and bypasses the `getAuth` defaults. The demo bootstrap now uses the public JS
`initializeAuth` / `connectAuthEmulator` APIs synchronously before FlutterFire
initializes. It uses identical persistence/resolver options and the same SDK
version (12.17.0, aligned with the locked Core Web package), then verifies public
`Auth.emulatorConfig` before running the app. Only explicitly enabled demo builds
call this bootstrap. No stored users, credentials or database records are cleared.
The version fallback must be reviewed when upgrading firebase_core_web.

The first Web save timed out during OPTIONS because the local Functions worker
took longer than its 60-second startup deadline. No transaction ran on that
attempt. A same-request retry after worker initialization saved exactly the two
requested assignments. The preview launcher now checks actual OPTIONS readiness
for roster/save/swap/cancel workers, rather than relying on open TCP ports. The
application deadline remains 45 seconds.

Verified in the in-app Web browser on 2026-11-09: admin login, saved November
records, December two-cell HC preview/save,
same-request retry, OFF versus blank, five recurring Thursday C shifts, successful
A/B swap, rejection of a swap with a seeded live booking, month re-open, saved
details and HC-to-S replacement. After the Auth fix, staff demo login displayed
its assigned appointment, the home-branch matrix and colleague records. Clicking
the branch selector did not open other branches; saved cell details offered
only Close. Reload preserved the staff session and returned to assigned
appointments. A 390x844 browser viewport confirmed horizontal wheel scrolling
through later days while employee names remained fixed.

The shorter embedded preview exposed a separate layout issue: filters left too
little height for employee rows. Controls now have a separately scrollable,
height-capped region, reserving space for the grid and its frozen header. The
regression widget test confirms control scrolling does not move the grid header.
Final browser verification of this adjustment is recorded below.

Final build check passed: persisted staff session restored after reload; the
short embedded viewport displayed the employee row and December S/C shifts;
scrolling the controls left the date/weekday header fixed. The browser tab is
left on staff December 2026 at http://127.0.0.1:7359/.

Read-only data reconciliation found 9 December records: 7 scheduled, 1 OFF,
1 cancelled historical record. A local export completed successfully at
`.firebase/monthly-review-20261109`, excluded from Git. The earlier same-request
save generated only the requested two assignments.

Demo login: choose Demo -> Admin demo or Nhân viên demo. Fixture emails are
`local-admin@example.test` and `local-staff@example.test`, with password
`Local-demo-123!`. These accounts exist only in the isolated Emulator.

SDK references:
- https://firebase.google.com/docs/reference/js/auth#connectauthemulator
- https://github.com/firebase/firebase-js-sdk/blob/main/packages/auth/src/platform_browser/index.ts
- https://github.com/firebase/firebase-js-sdk/blob/main/packages/util/src/defaults.ts

The previous in-memory demo processes were no longer running on 2026-11-09 and
no export was available. A fresh isolated demo session was seeded; no existing
running database was cleared. The current session enables export-on-exit to the
ignored `.firebase/emulator-data` directory.

## Remaining checks

- Cancellation, stale-preview rejection and simultaneous operations are covered
  by Emulator tests; those cases were not all repeated manually through Web.
- Native Chrome and physical-phone behavior have not been independently checked.
- No reference image is available in this chat; layout follows the textual
  requirements, without a pixel-match claim.
- Production Rules/index rollout and any data migration require a separate
  review and authorization. No phase 2B/2C implementation is included.
