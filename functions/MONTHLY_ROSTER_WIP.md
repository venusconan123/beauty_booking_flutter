# Monthly roster — paused development handoff

Historical snapshot at commit `3598f5c`. For subsequent implementation and
verification status, see [MONTHLY_ROSTER_REVIEW.md](MONTHLY_ROSTER_REVIEW.md).

Development was paused at the user's request so the current source can be
continued on GitHub. This is a development snapshot, not a release-ready build.

## Current source

- Monthly employee/day matrix replaces the main shift list. Branch/month/year
  filters, synchronized frozen name/header panes, horizontal scrolling, shift
  colors/legend, OFF vs blank, cell selection and preview UI are present.
- Staff view is intended to remain read-only for their home branch.
- A new `saveRoster` callable prepares atomic multi-cell assignment (up to 100
  cells), expected-version checking and soft-cancel history. It shares existing
  employee/day guards. OFF occupies the full day and is not bookable.
- Existing A/B transaction checks remain. New roster source adds OFF to collision
  checks. Monthly query index configuration is prepared locally.

## Not yet validated / remaining review

- No new Emulator tests have yet been written/run for `saveRoster`, OFF,
  multi-cell rollback, stale previews or concurrency with bookings/A/B.
- The monthly matrix has not been opened or exercised on Web/phone. Frozen-pane
  behavior, month reload completeness, recurrence preview and staff access need
  dedicated UI and Emulator verification.
- The previous 26-test backend result predates the monthly-roster changes.
  Earlier successful timeout/retry and Web startup checks apply to that earlier
  UI, not proof of the new matrix.
- Review API validation limits and legacy data handling before deployment.
  Only the UI/query index configuration is prepared; no index or Rules deploy
  has been performed.

The prior validated local work is described in PHASE_2A.md,
WEB_TIMEOUT_REVIEW.md and WEB_STARTUP_REVIEW.md. Current pre-commit analyze/test
results: `flutter analyze --no-pub` passed with no issues; existing Flutter tests
passed 14/14; Node syntax checks and `git diff --check` passed. These checks do
not cover the new monthly-grid workflow. The timeout transport test's synthetic
25 ms deadline was changed to 500 ms to tolerate busy test hosts; the application
deadline remains 45 seconds.

Do not deploy this development snapshot. Continue using project
`demo-men-hair-booking` and the isolated Emulator test configuration.
