param(
  [string]$NodePath = 'node',
  [string]$FirebaseCliPath = '',
  [string]$JavaHome = $env:JAVA_HOME,
  [string]$DataPath = '.firebase/demo-data',
  [switch]$RunTests,
  [string]$TestCommand = 'npm --prefix functions test'
)
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path -Parent $PSScriptRoot)
$nodeCommand = (Get-Command $NodePath -ErrorAction Stop).Source
$nodeVersion = & $nodeCommand --version
if ($nodeVersion -notmatch '^v22\.') { throw "Functions requires Node 22; found $nodeVersion. Pass -NodePath <node.exe for Node 22>." }
# The CLI and its child workers must resolve the same Node major version.
$env:PATH = "$(Split-Path -Parent $nodeCommand);$env:PATH"
if (-not $JavaHome -and (Test-Path 'C:/Program Files/Android/Android Studio/jbr/bin/java.exe')) {
  $JavaHome = 'C:/Program Files/Android/Android Studio/jbr'
}
if ($JavaHome) {
  if (-not (Test-Path (Join-Path $JavaHome 'bin/java.exe'))) { throw 'JavaHome must contain bin/java.exe.' }
  $env:JAVA_HOME = $JavaHome
  $env:PATH = "$(Join-Path $JavaHome 'bin');$env:PATH"
}
$javaVersion = (& java -version 2>&1 | Out-String)
if ($javaVersion -notmatch 'version "(\d+)' -or [int]$Matches[1] -lt 21) { throw 'Firebase Emulator requires Java 21 or newer. Pass -JavaHome <JDK directory>.' }
$env:FUNCTIONS_DISCOVERY_TIMEOUT = '180'
$env:FIREBASE_EMULATOR_HUB = if ($RunTests) { '127.0.0.1:4440' } else { '127.0.0.1:4400' }
$ports = if ($RunTests) { @(9199, 8180, 5101, 4440) } else { @(9099, 8080, 5001, 4400) }
foreach ($port in $ports) {
  $connection = [Net.Sockets.TcpClient]::new()
  try {
    $connection.Connect('127.0.0.1', $port)
    throw "Port $port is already in use. Stop the existing demo gracefully before restarting."
  } catch [Net.Sockets.SocketException] { }
  finally { $connection.Dispose() }
}
if ($RunTests) {
  $arguments = @('emulators:exec', '--project', 'demo-men-hair-booking', '--config', 'firebase.test.json', '--only', 'auth,firestore,functions', $TestCommand)
} else {
  $arguments = @('emulators:start', '--project', 'demo-men-hair-booking', '--config', 'firebase.emulator.json', '--only', 'auth,firestore,functions', "--export-on-exit=$DataPath")
  if (Test-Path (Join-Path $DataPath 'firebase-export-metadata.json')) { $arguments += "--import=$DataPath" }
  elseif (Test-Path '.firebase/monthly-review-20261109/firebase-export-metadata.json') {
    Write-Host 'Importing the existing local checkpoint. Future exits save to the persistent demo directory.'
    $arguments += '--import=.firebase/monthly-review-20261109'
  }
}
if ($RunTests) { Write-Host 'Running disposable tests on ports 9199/8180/5101; interactive demo data is not imported.' }
else { Write-Host 'Starting isolated local demo. Stop with Ctrl+C and wait for the export to finish.' }
if ($FirebaseCliPath) { & $nodeCommand $FirebaseCliPath @arguments }
else { & firebase @arguments }
if ($LASTEXITCODE -ne 0) { throw "Emulators exited with code $LASTEXITCODE. See firebase-debug.log." }
