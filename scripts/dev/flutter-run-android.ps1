Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$FlutterDir = Join-Path $RepoRoot "apps\flutter\wavezero_app"

$Flutter = Get-Command flutter -ErrorAction SilentlyContinue
if ($null -eq $Flutter) {
    Write-Error "Flutter was not found on PATH. Install the Flutter SDK, add its bin directory to PATH, then run this script again."
    exit 1
}

if (-not (Test-Path $FlutterDir)) {
    Write-Error "Flutter project directory not found: $FlutterDir"
    exit 1
}

Set-Location $FlutterDir
Write-Host "Running flutter pub get in $FlutterDir"
& $Flutter.Source pub get
if ($LASTEXITCODE -ne 0) {
    Write-Error "flutter pub get failed with exit code $LASTEXITCODE."
    exit $LASTEXITCODE
}

Write-Host "Starting Flutter on Android. Select a device if prompted."
& $Flutter.Source run
if ($LASTEXITCODE -ne 0) {
    Write-Error "flutter run failed with exit code $LASTEXITCODE."
    exit $LASTEXITCODE
}
