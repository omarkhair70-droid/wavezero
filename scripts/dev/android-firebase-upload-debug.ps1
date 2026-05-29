Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$AndroidDir = Join-Path $RepoRoot "apps\android"
$DefaultJbr = "C:\Program Files\Android\Android Studio\jbr"
$AssembleScript = Join-Path $PSScriptRoot "android-assemble-debug.ps1"

if ([string]::IsNullOrWhiteSpace($env:FIREBASE_APP_ID)) {
    Write-Error "FIREBASE_APP_ID is required for Firebase App Distribution. Set it to the Firebase Android App ID, for example: `$env:FIREBASE_APP_ID = '1:PROJECT_NUMBER:android:APP_ID'."
    exit 1
}

if ([string]::IsNullOrWhiteSpace($env:GOOGLE_APPLICATION_CREDENTIALS)) {
    Write-Error "GOOGLE_APPLICATION_CREDENTIALS is not set. Point it to a local service account JSON file outside this repository, or configure equivalent Firebase Application Default Credentials before uploading. Do not commit credential files."
    exit 1
}

if (-not (Test-Path $env:GOOGLE_APPLICATION_CREDENTIALS)) {
    Write-Error "GOOGLE_APPLICATION_CREDENTIALS points to a file that does not exist: $env:GOOGLE_APPLICATION_CREDENTIALS"
    exit 1
}

if ([string]::IsNullOrWhiteSpace($env:JAVA_HOME) -and (Test-Path $DefaultJbr)) {
    $env:JAVA_HOME = $DefaultJbr
    $env:PATH = "$env:JAVA_HOME\bin;$env:PATH"
    Write-Host "JAVA_HOME was missing; using Android Studio JBR: $env:JAVA_HOME"
}

& $AssembleScript
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
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

Write-Host "Checking for Firebase App Distribution Gradle task."
$TasksOutput = & $GradleCommand "tasks" "--all"
if ($LASTEXITCODE -ne 0) {
    Write-Error "Could not list Gradle tasks; cannot verify Firebase App Distribution upload task."
    exit $LASTEXITCODE
}

if (-not (($TasksOutput -join "`n") -match "appDistributionUploadDebug")) {
    Write-Error "Gradle task ':app:appDistributionUploadDebug' was not found. Confirm the Firebase App Distribution Gradle plugin is applied before uploading."
    exit 1
}

Write-Host "Uploading debug APK to Firebase App Distribution."
& $GradleCommand ":app:appDistributionUploadDebug"
if ($LASTEXITCODE -ne 0) {
    Write-Error "Firebase App Distribution upload failed with exit code $LASTEXITCODE."
    exit $LASTEXITCODE
}

Write-Host "Firebase App Distribution upload complete."
