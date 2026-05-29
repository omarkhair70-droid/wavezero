Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$AndroidDir = Join-Path $RepoRoot "apps\android"
$ApkPath = Join-Path $AndroidDir "app\build\outputs\apk\debug\app-debug.apk"
$AssembleScript = Join-Path $PSScriptRoot "android-assemble-debug.ps1"

$Adb = Get-Command adb -ErrorAction SilentlyContinue
if ($null -eq $Adb) {
    Write-Error "adb was not found on PATH. Install Android Studio or add Android SDK platform-tools to PATH."
    exit 1
}

if (-not (Test-Path $ApkPath)) {
    Write-Host "Debug APK not found; building it first."
    & $AssembleScript
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
}

$DeviceLines = @((& $Adb.Source devices) | Where-Object { $_ -match "\tdevice$" })
if ($DeviceLines.Count -eq 0) {
    Write-Host "No connected Android device was found. Current adb devices output:"
    & $Adb.Source devices
    Write-Error "Connect a USB device, authorize debugging, or pair a Wireless Debugging device before installing."
    exit 1
}

Write-Host "Installing debug APK on connected device: $ApkPath"
& $Adb.Source install -r $ApkPath
if ($LASTEXITCODE -ne 0) {
    Write-Error "adb install failed with exit code $LASTEXITCODE."
    exit $LASTEXITCODE
}

Write-Host "Install complete."
