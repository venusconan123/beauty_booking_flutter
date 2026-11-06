# Phase 2A — local shift scheduling and booking

This step adds admin shift creation, recurrence within a month, revision-checked
editing, soft cancellation and A/B exchange. Employees can read their own shifts
and shifts at their primary branch. Customers receive only public bookable staff
and availability from callables, not the raw employee shift collection.

All new mutations are disabled outside the explicit Flutter emulator mode.
No deployment, production migration, account provisioning or push is included.

## Data and concurrency contract

- `work_shifts/{id}`: employeeId, salonId, dateKey, startMinute, endMinute,
  status, revision, seriesId, creator/update timestamps and actor. Cancelled
  shifts remain in the collection. The employee's primary branch is unchanged
  when an admin assigns a shift at another branch.
- `employee_days/{employeeId_dateKey}`: backend-only revision guard. Every
  reservation write and shift write reads and updates the relevant guards in
  the same Firestore transaction. This includes both sides of an edited/moved
  shift and all four employee/day combinations in a swap.
- `schedule_operations/{ownerHash_requestId}`: backend-only idempotency result
  and request fingerprint. A replay returns the original result; reusing a key
  for different input is rejected. User scope is hashed to avoid key ambiguity.
- Existing `bookings` retain their IDs. New rows include schemaVersion 2,
  workShiftId and shiftRevision. Service prices/durations are read from the
  server catalog; vouchers are validated and redeemed in the same transaction.
- Slot records are retained and marked `released`, not deleted. New reservations
  use booking-specific slot IDs, preserving previously released reservations.
- Shift/status/service changes append before/after audit events. Neither client
  customers nor client admins may directly write bookings, slots, shift records
  or guards, so they cannot bypass the concurrency protocol.

The authoritative occupancy source includes active legacy bookings at every
branch. Missing legacy duration can be inferred from the stored service lines;
rows with unusable appointment/duration data cause a conservative error rather
than being silently omitted. No production backfill is performed.

## Business decisions

- Three branches: salon_01, salon_02, salon_03; opening hours 07:00–22:00.
- Shift boundaries and booking starts follow the existing 30-minute grid.
  Reserved duration rounds up to 30 minutes and must fit wholly in one shift;
  a reservation cannot cross a break or another branch's shift.
- Recurrence materializes 1–31 selected dates in one atomic request. The UI
  previews the dates and excludes past dates. One conflict rejects the entire
  request, without partially creating the month.
- Editing preserves all active bookings inside the resulting schedule. A/B
  exchange is deliberately stricter: A/day1, A/day2, B/day1 and B/day2 must all
  have no active bookings, at any branch. Pending, confirmed and in_service
  bookings count as active; completed/cancelled bookings do not.
- Swap exchanges only employee assignments; each shift keeps its date, hours,
  branch and ID. Target-employee shift overlaps and stale revisions are rejected.
- Availability is a hint refreshed by the UI. Booking commit always rechecks
  catalog, employee activity, shift coverage and occupancy in a transaction.
- A stale client price/duration quote is rejected instead of silently charging
  a different catalog price.
- Existing admin completion is retained through the guarded backend for
  compatibility. There is no new staff start/complete workflow, no new
  completion ledger and no financial/statistical work from phases 2B/2C.

## Run tests without changing the interactive demo

Use Node 22 and Java 21 (the Android Studio JBR is suitable):

```powershell
npx -y firebase-tools@latest emulators:exec --project demo-men-hair-booking --config firebase.test.json --only "auth,firestore,functions" "npm --prefix functions test"
flutter analyze --no-pub
flutter test --no-pub
```

The test suite uses Firestore 8180, Auth 9199 and Functions 5101. Its host/project
guards prevent it from addressing production or the interactive demo's services.
The interactive demo continues to use firebase.emulator.json and 8080/9099/5001.

For interactive preview, start the demo emulators, run the guarded seed script,
then run `.\tools\run-local-web-preview.ps1` from the repository root for the
release preview at port 7359. Seed only adds missing profiles,
catalog entries and three future dates of shifts; it does not overwrite existing
shift history or recreate a manually cancelled shift.

Local demo users: local-admin@example.test, local-staff@example.test,
local-customer@example.test. Password: Local-demo-123!

## Local verification — 2026-11-06

Later interactive Web save/timeout/retry verification is recorded in
[WEB_TIMEOUT_REVIEW.md](WEB_TIMEOUT_REVIEW.md). It supersedes the earlier
unverified save-flow status below, without claiming other Web workflows passed.
The later blank-preview diagnosis and two successful login reloads are recorded
in [WEB_STARTUP_REVIEW.md](WEB_STARTUP_REVIEW.md).

- Git branch: `codex/staff-phase-one`; HEAD remains `93a06d9`. Phase 2A
  changes remain uncommitted. No push, deployment or production writes.
- Emulator final run: **26/26 passed**, including real callable HTTP requests
  using Auth Emulator tokens: admin creates a shift, customer books it, replay
  returns the same booking, overlapping booking is rejected, occupied shift
  cannot be cancelled, staff/customer cannot create shifts.
- Existing transaction tests cover repeat atomicity, shift history, stale
  revisions, all four A/B booking checks, overlap and booking races against
  edit/cancel/swap. Rules tests cover staff visibility, deactivation and denied
  direct client writes.
- `flutter analyze --no-pub`: passed, no issues.
- `flutter test --no-pub`: **11/11 passed** on retry.
- `git diff --check`: passed (line-ending warnings only).
- Initial emulator run: 24/25 passed; Functions discovery exceeded 10 seconds,
  so its HTTP test received 404. Subsequent runs loaded Functions successfully;
  final run uses `FUNCTIONS_DISCOVERY_TIMEOUT=60`.
- Initial Flutter test invocation hit a generated native-assets copy collision
  (`PathExistsException`). A separate retry passed all tests.
- Flutter Web request IDs now use a random bound of `1 << 30`; the VM test
  generates 100 distinct IDs. **Browser verification is still incomplete**:
  Chrome test compiled/launched but stalled before individual test results on
  two attempts. Verbose diagnostic log: `.dart_tool/chrome-scheduling-check.log`.
- Interactive preview at port 7358 showed only a loading screen in this
  session. Full admin/staff/customer UI flows, actual browser Save after the
  request-ID fix, and responsive/device checks remain unverified.
- Phase 2B/2C and production compatibility/migration are outside this run.

Admin: menu → Lịch làm nhân viên. Select All branches to exchange shifts across
branches; select exactly two shifts to show Đổi A/B. Employee: Lịch làm tab.
Customer: choose branch/service/worker, then select an available date/time.

The root emulator-only padding keeps Firebase Auth's emulator banner from
covering the four navigation tabs. Real VNPAY calls remain disabled in demo mode.

## Review before any later deployment

Rules are still a prototype. Deployment must coordinate new client callables and
Rules because older clients' direct writes will be rejected. Catalog/profile
readiness and legacy malformed rows must be reviewed in a separate migration
preview. Six existing moderate indirect-dependency audit findings remain known.
