param()

$scriptRoot = Split-Path -Parent $PSScriptRoot
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

$env:WAVEZERO_AUDIO_BASE_URL = "http://$ip:8090"
Write-Output "WAVEZERO_AUDIO_BASE_URL = $env:WAVEZERO_AUDIO_BASE_URL"

Set-Location $repoRoot
cargo run --manifest-path services/api/Cargo.toml
