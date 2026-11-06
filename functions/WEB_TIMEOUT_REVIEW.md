# Web save-shift timeout — local review, 2026-11-06

Only project `demo-men-hair-booking` and localhost Emulator endpoints were used.
No deployment, production writes, account changes, commit or push.

## Original incident (checked before sending any mutation)

- Saved shift: `gFGNSHWO1akp3X8JENdX`, `local-cross`, `2026-11-06`,
  `salon_01`, 07:00–21:00, revision 1.
- Operation: `1793927056847000_218367570`; its receipt points to that shift.
- Functions log (Vietnam time): OPTIONS accepted 08:04:17.096; runtime ready
  08:05:10.822; POST accepted 08:05:10.950; handler finished 08:05:11.747.
- The delay was worker cold startup during CORS preflight (about 54 seconds),
  before the transaction. The POST then completed in about 0.8 seconds.
- The previous client timed out after 45 seconds but did not cancel its
  underlying HTTP request. Thus POST could still execute after the UI reported
  timeout. Functions finished after that deadline; a late response could no longer
  resolve the already-timed-out Future. No historical browser Network capture is
  available to prove receipt of that original response. Firestore's independent
  stream displayed the committed shift.
- The old UI already had a `finally` resetting busy; the missing pieces were
  transport cancellation, an honest unknown-outcome state and stable retry ID.

## Fix

- Each call owns an HTTP client; closes it in `finally`, including timeouts.
  The 45-second deadline includes token retrieval; a late token cannot send POST.
- An unresolved mutation retains an immutable payload and request ID. A visible
  retry action resends those exact values; other mutations are blocked until
  resolution. Definitive backend rejection clears pending state and unlocks UI.
- Existing transactional operation receipts provide idempotent recovery. No
  Firestore model or Rules changes were needed for this fix.
- Client Console traces auth, HTTP start, status, timeout and close by request ID.
  Emulator-only backend traces receipt and handler resolution/rejection.
- Timeout is still 45 seconds. Cold starts may still exceed it, but now cannot
  silently leave the client waiting or turn a retry into a new operation.

## Actual browser verification (not VM/HTTP substituted for UI)

App: `http://127.0.0.1:7359/`, debug build with `FIREBASE_EMULATORS=true` and
`FUNCTIONS_EMULATOR_PORT=5002`. The demo-only proxy forwards to port 5001 and
delays exactly the first successful save response by 50 seconds.

1. Used Admin demo login and the visible create-shift form. Selected Nhân viên
   demo, branch 1, 06/11, 09:00–17:00, and pressed Save.
2. Request `1793936963361000_224498519` reached backend. Handler resolved in
   979 ms with shift `k0ps7S63ixY1GJXRyaOk`; proxy received HTTP 200 in 1058 ms.
3. Web Console: timeout at 45023 ms; close at 45025 ms. Proxy observed client
   disconnect at 44879 ms (different timers start at auth vs HTTP receipt).
   Delayed response was not delivered. UI stopped showing progress and displayed
   "Thử lại cùng yêu cầu"; the committed shift remained visible.
4. Clicked that retry button on Web. Same request ID, backend result in 107 ms;
   Web received HTTP 200 at 242 ms and closed at 245 ms. Pending banner disappeared
   and create/select controls were enabled again.
5. Read Emulator again: exactly **one** `local-employee` shift on 06/11,
   same ID and revision 1. Original `local-cross` shift also remains exactly
   one, same ID and revision 1. No duplicate shift or second audit mutation.
6. Submitted a deliberately overlapping shift through the form. Web received
   HTTP 409 at 300 ms, closed at 302 ms; progress stopped and controls re-enabled.

Network evidence is a local forwarding proxy trace correlated with browser
Console and Functions logs; a native Chrome DevTools Network capture was not
available. This was an interactive browser test, not a callable-only assertion.

## Regression checks

- Flutter tests: **14/14 passed**, including lost response after commit, same-ID
  recovery, no late POST after token timeout, and transport close on rejection.
- `flutter analyze --no-pub`: **passed, no issues**.
- `git diff --check`: passed; CRLF warnings only.
- Backend/Rules Emulator regression: **26/26 passed**, exit code 0. Tests used
  isolated ports 8180/9199/5101 and did not clear the interactive demo database.

## Reproduce locally

Keep the demo Emulator running (Auth 9099, Firestore 8080, Functions 5001).
Before interactive use, an OPTIONS probe to `saveShifts` can wait for its worker
to be ready without writing any data; this session's cold probe returned 204 in
10.7 seconds. Readiness at process start does not guarantee every worker is warm.

```powershell
node functions/tools/scheduling-response-proxy.cjs
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 7359 --dart-define=FIREBASE_EMULATORS=true --dart-define=FUNCTIONS_EMULATOR_PORT=5002 --no-pub
```

Proxy diagnostics: `.dart_tool/scheduling-network.log`. Client traces appear in
browser Console. Backend traces appear in `firebase-debug.log`. The proxy's first
delayed response has already been consumed in the current preview; later calls
pass through normally. Restart the proxy to repeat fault injection.

The unresolved request is retained while this screen stays open; reload/navigation
recovery is not newly implemented. Do not infer customer booking, employee routing,
other browsers/devices or every Web workflow passed from this save/retry test.
