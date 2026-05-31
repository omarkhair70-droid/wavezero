param(
    [string]$AudioDir = "$env:USERPROFILE\Desktop\wavezero-test-audio"
)

$scriptRoot = Split-Path -Parent $PSScriptRoot
$localIpScript = Join-Path $scriptRoot 'wavezero-local-ip.ps1'

if (-not (Test-Path $localIpScript)) {
    Write-Error "Missing helper script: $localIpScript"
    exit 1
}

$ip = & $localIpScript
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

Write-Output "WaveZero audio base URL: http://$ip:8090"

if (-not (Test-Path $AudioDir)) {
    Write-Error "Audio directory not found: $AudioDir"
    exit 1
}

Set-Location $AudioDir
Write-Output "Serving audio files from: $AudioDir"

python -m http.server 8090 --bind 0.0.0.0
