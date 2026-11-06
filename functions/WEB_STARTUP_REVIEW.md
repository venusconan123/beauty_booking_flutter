# Blank local Web preview — 2026-11-06

## Diagnosis before replacement

- Port 7359 was served by `dartvm.exe` PID 1996, `flutter run -d web-server`
  in debug mode, with Emulator flags. It was not a dead server or another app.
- HTML, Flutter bootstrap, DDC loader and main bootstrap returned HTTP 200.
  Probed all 826 script URLs from the served manifest: 826 valid non-empty
  JavaScript responses, no failures or HTML substituted for JavaScript.
- The blank tab Console stopped at DDC module loading, with no Firebase warning
  or rendered `flutter-view`. DOM contained the final `on_load_end_bootstrap.js`
  and injected DWDS client. The served load-end script calls its callback, whose
  debug-injected code registers main with DWDS; DWDS calls main on `RunRequest`.
- These observations place the stall in the debug/DWDS startup handoff before
  app main/Firebase/UI. No Firebase permission or data issue was observed.
  The precise internal reason DWDS failed to hand off on this reload was not
  established; the preview no longer depends on that debug protocol.

## Change

- Replaced only the frontend preview process at 7359 with a release build,
  served by `dartvm.exe` PID 1956. It has no DDC/DWDS startup handoff.
- `tools/run-local-web-preview.ps1` runs this stable local preview, checks existing
  Emulator ports, and never starts/stops/reseeds Emulators. It sets
  `FIREBASE_EMULATORS=true`; Functions uses its normal Emulator port 5001.
- `--no-web-resources-cdn` serves CanvasKit JavaScript/WASM locally.
- Added a visible startup status/error message, removed on `flutter-first-frame`.
  Added Console milestones for entrypoint, engine, Dart main, Firebase demo,
  Auth/Firestore Emulator configuration and first frame. No credentials logged.

## Actual browser evidence

At `http://127.0.0.1:7359/`, reloaded the existing blank in-app browser tab twice.
Both reloads displayed the actual login screen (Email, Mật khẩu, Đăng nhập).
This was UI observation, not a VM or HTTP-only substitute.

- First reload: loading-entrypoint 04:08:22.264 UTC → entrypoint-loaded →
  engine-ready → dart-main → firebase-ready (demo) → auth-emulator-ready →
  firestore-emulator-ready → run-app → first-frame 04:08:24.338 UTC (**2.074 s**).
- Second reload: 04:09:20.861 → 04:09:21.466 UTC (**0.605 s**), same full sequence.
- Browser Console error list was empty after the second reload.
- Network/server probes: HTML, bootstrap, release `main.dart.js` (3,688,327 bytes),
  local CanvasKit JS and WASM all returned HTTP 200 with correct content types.
- A separate native Chrome window was not re-automated in this verification;
  confirmed UI evidence is from the in-app Chromium preview.

## Preservation and checks

- Auth/Functions PID 16552 and Firestore PID 18768 are unchanged. No Emulator
  restart, import, seed, account mutation or database write was performed.
- Read-only verification: original shift `gFGNSHWO1akp3X8JENdX` and timeout/retry
  test shift `k0ps7S63ixY1GJXRyaOk` both still exist at revision 1.
- Release Web build passed; `flutter analyze --no-pub` passed with no issues;
  `flutter test --no-pub` passed **14/14**; `git diff --check` passed.
- Log: `.dart_tool/web-preview-release.log`. No commit, push or deployment.

Start the same preview later with:

```powershell
.\tools\run-local-web-preview.ps1
```

Keep the current Emulator running to preserve its in-memory data.
