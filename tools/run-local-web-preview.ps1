# Stable browser preview: release mode avoids the DWDS debug handshake on reload.
# This command never starts/stops/reseeds the existing Firebase Emulators.
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path -Parent $PSScriptRoot)
foreach ($previewPort in @(9099, 8080, 5001)) {
  $connection = [Net.Sockets.TcpClient]::new()
  try { $connection.Connect('127.0.0.1', $previewPort) }
  catch { throw "Emulator localhost:$previewPort is not running; existing data has not been changed." }
  finally { $connection.Dispose() }
}
flutter run -d web-server --release --web-hostname 127.0.0.1 --web-port 7359 --no-web-resources-cdn --dart-define=FIREBASE_EMULATORS=true --no-pub
