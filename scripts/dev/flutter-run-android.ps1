Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$FlutterDir = Join-Path $RepoRoot "apps\flutter\wavezero_app"
$AndroidPackageName = "com.wavezero.flutter"
$ApkCandidates = @(
    Join-Path $FlutterDir "build\app\outputs\flutter-apk\app-debug.apk",
    Join-Path $FlutterDir "android\app\build\outputs\apk\debug\app-debug.apk"
)

$Flutter = Get-Command flutter -ErrorAction SilentlyContinue
if ($null -eq $Flutter) {
    Write-Error "Flutter was not found on PATH. Install the Flutter SDK, add its bin directory to PATH, then run this script again."
    exit 1
}

if (-not (Test-Path $FlutterDir)) {
    Write-Error "Flutter project directory not found: $FlutterDir"
    exit 1
}

function Install-And-Launch-DebugApk {
    $Adb = Get-Command adb -ErrorAction SilentlyContinue
    if ($null -eq $Adb) {
        Write-Error "flutter run failed and adb was not found on PATH, so the debug APK fallback cannot install or launch the app."
        exit 1
    }

    $DeviceLines = @((& $Adb.Source devices) | Where-Object { $_ -match "`tdevice$" })
    if ($DeviceLines.Count -eq 0) {
        Write-Error "flutter run failed and no Android device is connected for the debug APK fallback."
        exit 1
    }

    $Apk = $ApkCandidates |
        Where-Object { Test-Path $_ } |
        ForEach-Object { Get-Item $_ } |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

    if ($null -eq $Apk) {
        Write-Error "flutter run failed and no debug APK was found in the expected output paths."
        exit 1
    }

    Write-Warning "flutter run failed after build. Falling back to adb install + launch."
    Write-Host "Installing debug APK fallback: $($Apk.FullName)"
    & $Adb.Source install -r $Apk.FullName
    if ($LASTEXITCODE -ne 0) {
        Write-Error "adb install fallback failed with exit code $LASTEXITCODE."
        exit $LASTEXITCODE
    }

    Write-Host "Launching $AndroidPackageName"
    & $Adb.Source shell monkey -p $AndroidPackageName 1
    if ($LASTEXITCODE -ne 0) {
        Write-Error "adb launch fallback failed with exit code $LASTEXITCODE."
        exit $LASTEXITCODE
    }

    Write-Host "Fallback install and launch complete."
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
    Install-And-Launch-DebugApk
}
