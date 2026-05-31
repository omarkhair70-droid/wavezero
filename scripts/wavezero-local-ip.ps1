param()

function Get-ActiveIpv4Addresses {
    Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object {
        $_.IPAddress -notmatch '^(127|169\.254|0)\.' -and
        $_.PrefixOrigin -in @('Dhcp', 'Manual')
    }
}

function Is-VirtualAdapter {
    param([string]$alias, [string]$description)
    $virtualRegex = 'Virtual|vEthernet|Hyper-V|Loopback|Container|VPN|Bluetooth|Hamachi|TAP|VMware|VirtualBox|HyperV|Pseudo|Bridge|Virtual Adapter'
    return ($alias -match $virtualRegex) -or ($description -match $virtualRegex)
}

$addresses = Get-ActiveIpv4Addresses | ForEach-Object {
    $adapter = Get-NetAdapter -InterfaceIndex $_.InterfaceIndex -ErrorAction SilentlyContinue
    $description = ''
    $status = 'Up'
    if ($adapter) {
        $description = $adapter.InterfaceDescription
        $status = $adapter.Status
    }

    [pscustomobject]@{
        IPAddress = $_.IPAddress
        InterfaceAlias = $_.InterfaceAlias
        InterfaceDescription = $description
        Status = $status
        IsVirtual = Is-VirtualAdapter $_.InterfaceAlias $description
    }
}

if (-not $addresses) {
    Write-Error 'Unable to detect an active local IPv4 address. Ensure your device is connected to Wi-Fi or Ethernet.'
    exit 1
}

$preferredWifi = $addresses | Where-Object {
    ($_.InterfaceAlias -match 'Wi[-]?Fi|WLAN|Wireless|802\.11' -or $_.InterfaceDescription -match 'Wi[-]?Fi|WLAN|Wireless|802\.11') -and
    $_.Status -eq 'Up' -and
    -not $_.IsVirtual
} | Select-Object -First 1

if ($preferredWifi) {
    Write-Output $preferredWifi.IPAddress
    exit 0
}

$preferred = $addresses | Where-Object { $_.Status -eq 'Up' -and -not $_.IsVirtual } | Select-Object -First 1
if ($preferred) {
    Write-Output $preferred.IPAddress
    exit 0
}

$first = $addresses | Select-Object -First 1
if ($first) {
    Write-Output $first.IPAddress
    exit 0
}

Write-Error 'Unable to select a valid local IPv4 address for WaveZero. Check adapter status and IP configuration.'
exit 1
