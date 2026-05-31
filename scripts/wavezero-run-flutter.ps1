param()

$scriptRoot = $PSScriptRoot
$repoRoot = Split-Path -Parent $scriptRoot
$localIpScript = Join-Path $scriptRoot 'wavezero-local-ip.ps1'

if (-not (Test-Path $localIpScript)) {
    Write-Error "Missing helper script: $localIpScript"
    exit 1
}

$ip = & $localIpScript
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

$env:WAVEZERO_API_BASE_URL = "http://$($ip):8080"
Write-Output "WAVEZERO_API_BASE_URL = $env:WAVEZERO_API_BASE_URL"

$userHelper = Join-Path $env:USERPROFILE 'Desktop\wavezero-dev.ps1'
if (Test-Path $userHelper) {
    Write-Output "Found personal Flutter helper: $userHelper"
    Write-Output 'Ignoring helper launch because flutter run must receive --dart-define directly.'
}

Set-Location "$repoRoot\apps\flutter\wavezero_app"
flutter pub get
flutter run --dart-define="WAVEZERO_API_BASE_URL=$env:WAVEZERO_API_BASE_URL"
