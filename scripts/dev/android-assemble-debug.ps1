Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$AndroidDir = Join-Path $RepoRoot "apps\android"
$DefaultJbr = "C:\Program Files\Android\Android Studio\jbr"
$ApkPath = Join-Path $AndroidDir "app\build\outputs\apk\debug\app-debug.apk"

if (-not (Test-Path $AndroidDir)) {
    Write-Error "Android project directory not found: $AndroidDir"
    exit 1
}

if ([string]::IsNullOrWhiteSpace($env:JAVA_HOME) -and (Test-Path $DefaultJbr)) {
    $env:JAVA_HOME = $DefaultJbr
    $env:PATH = "$env:JAVA_HOME\bin;$env:PATH"
    Write-Host "JAVA_HOME was missing; using Android Studio JBR: $env:JAVA_HOME"
}

Set-Location $AndroidDir

$GradleWrapper = Join-Path $AndroidDir "gradlew.bat"
if (Test-Path $GradleWrapper) {
    $GradleCommand = $GradleWrapper
    Write-Host "Using local Gradle wrapper: $GradleCommand"
} else {
    $GradleCommandInfo = Get-Command gradle -ErrorAction SilentlyContinue
    if ($null -eq $GradleCommandInfo) {
        Write-Error "Neither apps\android\gradlew.bat nor a system 'gradle' command was found. Install Gradle locally or generate a wrapper without committing wrapper binary artifacts."
        exit 1
    }
    $GradleCommand = $GradleCommandInfo.Source
    Write-Host "gradlew.bat not found; using system Gradle: $GradleCommand"
}

& $GradleCommand ":app:assembleDebug"
if ($LASTEXITCODE -ne 0) {
    Write-Error "Gradle debug build failed with exit code $LASTEXITCODE."
    exit $LASTEXITCODE
}

if (Test-Path $ApkPath) {
    Write-Host "Debug APK generated: $ApkPath"
} else {
    Write-Error "Gradle completed, but expected APK was not found: $ApkPath"
    exit 1
}
