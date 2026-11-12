# Stable browser preview: release mode avoids the DWDS debug handshake on reload.
# This command never starts/stops/reseeds the existing Firebase Emulators.
param([switch]$CheckOnly)

$ErrorActionPreference = 'Stop'
Set-Location (Split-Path -Parent $PSScriptRoot)
foreach ($previewPort in @(9099, 8080, 5001)) {
  $connection = [Net.Sockets.TcpClient]::new()
  try { $connection.Connect('127.0.0.1', $previewPort) }
  catch { throw "Emulator localhost:$previewPort is not running; existing data has not been changed." }
  finally { $connection.Dispose() }
}
# A listening port is not proof that Functions workers loaded successfully.
# OPTIONS exercises worker/CORS readiness without invoking scheduling handlers
# or writing data. Fail visibly rather than opening a misleading ready preview.
foreach ($previewFunction in @('listBookableStaff', 'getAvailability', 'createBooking', 'changeBookingStatus', 'recordBookingPayment', 'createStaffAccount', 'saveRoster', 'swapShifts', 'cancelShift')) {
  $functionReady = $false
  for ($attempt = 1; $attempt -le 2; $attempt++) {
    Write-Host "Checking Emulator worker $previewFunction ($attempt/2)..."
    try {
      # Exceed the worker discovery limit so retries cannot pile up cold workers.
      $preflight = Invoke-WebRequest -UseBasicParsing -Method Options -TimeoutSec 185 `
        -Uri "http://127.0.0.1:5001/demo-men-hair-booking/asia-southeast1/$previewFunction" `
        -Headers @{ Origin = 'http://127.0.0.1:7359'; 'Access-Control-Request-Method' = 'POST'; 'Access-Control-Request-Headers' = 'authorization,content-type' }
      if ($preflight.StatusCode -eq 204) { $functionReady = $true; break }
    } catch { Write-Host "Worker not ready: $($_.Exception.Message)" }
  }
  if (-not $functionReady) {
    throw "Functions worker $previewFunction is not ready. Inspect Emulator logs; no demo data was changed."
  }
}
Write-Host 'All booking, staff, payment and roster workers are ready.'
if (-not $CheckOnly) {
  flutter run -d web-server --release --web-hostname 127.0.0.1 --web-port 7359 --no-web-resources-cdn --dart-define=FIREBASE_EMULATORS=true --no-pub
}
