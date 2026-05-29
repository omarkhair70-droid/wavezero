Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
Set-Location $RepoRoot

function Write-Check($Name, $Ok, $Detail) {
    if ($Ok) {
        Write-Host "[OK]   $Name - $Detail"
    } else {
        Write-Host "[WARN] $Name - $Detail"
    }
}

$Git = Get-Command git -ErrorAction SilentlyContinue
if ($null -ne $Git) {
    $Branch = (& $Git.Source branch --show-current 2>$null)
    if ([string]::IsNullOrWhiteSpace($Branch)) { $Branch = "detached or unavailable" }
    Write-Check "Git branch" $true $Branch
} else {
    Write-Check "Git branch" $false "git is not on PATH"
}

$Java = Get-Command java -ErrorAction SilentlyContinue
if ($null -ne $Java) {
    $JavaVersion = (& $Java.Source -version 2>&1 | Select-Object -First 1)
    Write-Check "Java" $true $JavaVersion
} elseif (-not [string]::IsNullOrWhiteSpace($env:JAVA_HOME)) {
    Write-Check "Java" $false "JAVA_HOME is set to $env:JAVA_HOME, but java was not found on PATH"
} else {
    Write-Check "Java" $false "java not found; set JAVA_HOME or install Android Studio/Java 17"
}

$Adb = Get-Command adb -ErrorAction SilentlyContinue
if ($null -ne $Adb) {
    $Devices = (& $Adb.Source devices | Select-Object -Skip 1 | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($Devices.Count -gt 0) {
        Write-Check "adb" $true ("found; devices: " + ($Devices -join "; "))
    } else {
        Write-Check "adb" $true "found; no devices currently listed"
    }
} else {
    Write-Check "adb" $false "adb not found on PATH"
}

$Flutter = Get-Command flutter -ErrorAction SilentlyContinue
if ($null -ne $Flutter) {
    $FlutterVersion = (& $Flutter.Source --version 2>$null | Select-Object -First 1)
    Write-Check "Flutter" $true $FlutterVersion
} else {
    Write-Check "Flutter" $false "flutter not found on PATH"
}

if ([string]::IsNullOrWhiteSpace($env:FIREBASE_APP_ID)) {
    Write-Check "FIREBASE_APP_ID" $false "not set; required only for Firebase App Distribution upload"
} else {
    Write-Check "FIREBASE_APP_ID" $true "set"
}

$ExpectedDirs = @(
    "apps\android",
    "apps\flutter\wavezero_app",
    "crates\wavezero-core",
    "crates\wavezero-ffi",
    "services\api"
)

foreach ($Dir in $ExpectedDirs) {
    $FullPath = Join-Path $RepoRoot $Dir
    Write-Check "Directory $Dir" (Test-Path $FullPath) $FullPath
}
