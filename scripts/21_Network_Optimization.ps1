#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Network Adapter and TCP/IP Stack Optimization for Competitive Gaming
    Version: 1.0 | March 2026
.DESCRIPTION
    Applies system-level network optimizations for competitive gaming:
    adapter properties, DNS, registry tweaks, TCP/IP stack tuning.
    SAFETY: Speed/Duplex NEVER changed, TCP Auto-Tuning NEVER disabled,
    checksum offloads kept enabled, all properties checked before setting.
.NOTES
    Run as Administrator. Reboot required for some registry changes.
#>

$ErrorActionPreference = 'SilentlyContinue'
$Headless = $env:SENSEQUALITY_HEADLESS -eq "1"

# ============================================================
# HELPER FUNCTIONS
# ============================================================

function Set-AdapterPropertySafe {
    param(
        [string]$AdapterName,
        [string]$PropertyName,
        [string]$DesiredValue,
        [string]$CheckKey
    )

    $prop = Get-NetAdapterAdvancedProperty -Name $AdapterName -DisplayName $PropertyName -ErrorAction SilentlyContinue
    if (-not $prop) {
        Write-Host "  [SKIP] $PropertyName -- not available on this adapter" -ForegroundColor DarkGray
        Write-Host "[SQ_CHECK_WARN:${CheckKey}:PROPERTY_NOT_FOUND]"
        return
    }

    if ($prop.ValidDisplayValues -and $DesiredValue -notin $prop.ValidDisplayValues) {
        Write-Host "  [SKIP] $PropertyName -- value not valid for this adapter" -ForegroundColor DarkGray
        Write-Host "[SQ_CHECK_WARN:${CheckKey}:VALUE_NOT_VALID]"
        return
    }

    if ($prop.DisplayValue -eq $DesiredValue) {
        Write-Host "  [OK] $PropertyName already set to $DesiredValue" -ForegroundColor Green
        Write-Host "[SQ_CHECK_OK:${CheckKey}]"
        return
    }

    try {
        Set-NetAdapterAdvancedProperty -Name $AdapterName -DisplayName $PropertyName -DisplayValue $DesiredValue -ErrorAction Stop
        Write-Host "  [OK] $PropertyName set to $DesiredValue" -ForegroundColor Green
        Write-Host "[SQ_CHECK_OK:${CheckKey}]"
    }
    catch {
        Write-Host "  [FAIL] $PropertyName -- $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "[SQ_CHECK_FAIL:${CheckKey}:$($_.Exception.Message)]"
    }
}

function Set-RegistryValueSafe {
    param(
        [string]$Path,
        [string]$Name,
        [object]$Value,
        [string]$Type = "DWord",
        [string]$CheckKey,
        [string]$Label
    )

    try {
        if (-not (Test-Path $Path)) {
            New-Item -Path $Path -Force | Out-Null
        }
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -ErrorAction Stop
        Write-Host "  [OK] $Label" -ForegroundColor Green
        Write-Host "[SQ_CHECK_OK:${CheckKey}]"
    }
    catch {
        Write-Host "  [FAIL] $Label -- $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "[SQ_CHECK_FAIL:${CheckKey}:$($_.Exception.Message)]"
    }
}


# ============================================================
# HEADER
# ============================================================

if (-not $Headless) { Clear-Host }
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "  Network Adapter and TCP/IP Optimization v1.0" -ForegroundColor Cyan
Write-Host "  Competitive Gaming -- Latency and Jitter Reduction" -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host ""


# ============================================================
# SECTION 1: DETECT PRIMARY NETWORK ADAPTER
# ============================================================

Write-Host "------------------------------------------" -ForegroundColor DarkGray
Write-Host "[1/5] ADAPTER DETECTION" -ForegroundColor White
Write-Host "------------------------------------------" -ForegroundColor DarkGray

$primaryAdapter = Get-NetAdapter -Physical | Where-Object { $_.Status -eq 'Up' } | Select-Object -First 1
if (-not $primaryAdapter) {
    Write-Host "  [FAIL] No active physical network adapter found (checked Ethernet and Wi-Fi)." -ForegroundColor Red
    Write-Host "[SQ_CHECK_FAIL:NET_ADAPTER:NO_ACTIVE_ADAPTER]"
    exit 1
}

$adapterName = $primaryAdapter.Name
$adapterGuid = $primaryAdapter.InterfaceGuid
$adapterDesc = $primaryAdapter.InterfaceDescription

Write-Host "  Adapter: $adapterDesc" -ForegroundColor DarkCyan
Write-Host "  Name: $adapterName | GUID: $adapterGuid" -ForegroundColor DarkGray
Write-Host "[SQ_CHECK_OK:NET_ADAPTER]"
Write-Host ""


# ============================================================
# SECTION 2: ADAPTER ADVANCED PROPERTIES
# WHY: Disabling interrupt moderation, LSO, flow control, and
#      energy-saving features reduces DPC latency and jitter.
# ============================================================

if ($env:SKIP_NET_ADAPTER_TUNE -eq '1') {
    Write-Host "[SKIP] Network Adapter Tuning -- skipped by user" -ForegroundColor DarkGray
    Write-Host "[SQ_SKIP:NET_ADAPTER_TUNE]"
} else {
    Write-Host "------------------------------------------" -ForegroundColor DarkGray
    Write-Host "[2/5] NETWORK ADAPTER PROPERTIES" -ForegroundColor White
    Write-Host "------------------------------------------" -ForegroundColor DarkGray

    $adapterFailed = $false

    Set-AdapterPropertySafe -AdapterName $adapterName -PropertyName "Interrupt Moderation" -DesiredValue "Disabled" -CheckKey "NET_INTERRUPT_MOD"
    Set-AdapterPropertySafe -AdapterName $adapterName -PropertyName "Interrupt Moderation Rate" -DesiredValue "Off" -CheckKey "NET_INTERRUPT_RATE"
    Set-AdapterPropertySafe -AdapterName $adapterName -PropertyName "Flow Control" -DesiredValue "Disabled" -CheckKey "NET_FLOW_CTRL"
    Set-AdapterPropertySafe -AdapterName $adapterName -PropertyName "Large Send Offload V2 (IPv4)" -DesiredValue "Disabled" -CheckKey "NET_LSO_V4"
    Set-AdapterPropertySafe -AdapterName $adapterName -PropertyName "Large Send Offload V2 (IPv6)" -DesiredValue "Disabled" -CheckKey "NET_LSO_V6"
    Set-AdapterPropertySafe -AdapterName $adapterName -PropertyName "Energy Efficient Ethernet" -DesiredValue "Disabled" -CheckKey "NET_EEE"
    Set-AdapterPropertySafe -AdapterName $adapterName -PropertyName "Adaptive Inter-Frame Spacing" -DesiredValue "Disabled" -CheckKey "NET_AIFS"
    Set-AdapterPropertySafe -AdapterName $adapterName -PropertyName "Receive Side Scaling" -DesiredValue "Enabled" -CheckKey "NET_RSS"
    Set-AdapterPropertySafe -AdapterName $adapterName -PropertyName "Receive Buffers" -DesiredValue "512" -CheckKey "NET_RX_BUF"
    Set-AdapterPropertySafe -AdapterName $adapterName -PropertyName "Transmit Buffers" -DesiredValue "512" -CheckKey "NET_TX_BUF"

    # Power saving properties -- disable all found variants (names vary by vendor)
    $powerSaveProps = @(
        @{ Name = "Green Ethernet";              Key = "NET_GREEN_ETH" },
        @{ Name = "Power Saving Mode";           Key = "NET_PWR_SAVE" },
        @{ Name = "Reduce Speed On Power Down";  Key = "NET_REDUCE_SPD" },
        @{ Name = "Ultra Low Power Mode";        Key = "NET_ULTRA_LP" },
        @{ Name = "Wake on Magic Packet";        Key = "NET_WOL_MAGIC" },
        @{ Name = "Wake on Pattern Match";       Key = "NET_WOL_PATTERN" },
        @{ Name = "Gigabit Lite";                Key = "NET_GBIT_LITE" },
        @{ Name = "Advanced EEE";                Key = "NET_ADV_EEE" }
    )
    foreach ($p in $powerSaveProps) {
        Set-AdapterPropertySafe -AdapterName $adapterName -PropertyName $p.Name -DesiredValue "Disabled" -CheckKey $p.Key
    }

    # Disable Receive Segment Coalescing at adapter level
    try {
        Disable-NetAdapterRsc -Name $adapterName -ErrorAction Stop
        Write-Host "  [OK] Receive Segment Coalescing (RSC) disabled at adapter level" -ForegroundColor Green
        Write-Host "[SQ_CHECK_OK:NET_RSC_ADAPTER]"
    } catch {
        Write-Host "  [WARN] RSC disable -- $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host "[SQ_CHECK_WARN:NET_RSC_ADAPTER:$($_.Exception.Message)]"
    }

    Write-Host "[SQ_OK:NET_ADAPTER_TUNE]"
    Write-Host ""
}


# ============================================================
# SECTION 3: DNS OPTIMIZATION
# WHY: Cloudflare 1.1.1.1 has lowest global avg latency (~10ms).
#      NOTE: DNS only affects initial connections, NOT in-game ping.
# ============================================================

if ($env:SKIP_DNS -eq '1') {
    Write-Host "[SKIP] DNS Optimization -- skipped by user" -ForegroundColor DarkGray
    Write-Host "[SQ_SKIP:DNS]"
} else {
    Write-Host "------------------------------------------" -ForegroundColor DarkGray
    Write-Host "[3/5] DNS OPTIMIZATION" -ForegroundColor White
    Write-Host "------------------------------------------" -ForegroundColor DarkGray

    try {
        $activeAdapters = Get-NetAdapter -Physical | Where-Object { $_.Status -eq 'Up' }
        $dnsSet = 0
        foreach ($nic in $activeAdapters) {
            # Log existing DNS before overwriting (for user reference if they need to revert)
            $existingDns = Get-DnsClientServerAddress -InterfaceIndex $nic.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
            if ($existingDns -and $existingDns.ServerAddresses) {
                Write-Host "  [BACKUP] $($nic.Name) DNS was: $($existingDns.ServerAddresses -join ', ')" -ForegroundColor DarkGray
            }
            Set-DnsClientServerAddress -InterfaceIndex $nic.ifIndex -ServerAddresses @("1.1.1.1", "1.0.0.1", "8.8.8.8") -ErrorAction Stop
            $dnsSet++
        }
        Clear-DnsClientCache -ErrorAction SilentlyContinue
        Write-Host "  [OK] DNS set to Cloudflare 1.1.1.1 + 1.0.0.1 + Google 8.8.8.8 on $dnsSet adapter(s)" -ForegroundColor Green
        Write-Host "  [NOTE] DNS affects matchmaking/lobby connections, not in-game ping" -ForegroundColor DarkGray
        Write-Host "[SQ_CHECK_OK:NET_DNS]"
        Write-Host "[SQ_OK:DNS]"
    } catch {
        Write-Host "  [FAIL] DNS -- $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "[SQ_CHECK_FAIL:NET_DNS:$($_.Exception.Message)]"
        Write-Host "[SQ_FAIL:DNS]"
    }

    Write-Host ""
}


# ============================================================
# SECTION 4: REGISTRY NETWORK TWEAKS
# WHY: Removes Windows network throttling, optimizes TCP params,
#      disables Nagle algorithm, reorders host resolution priority.
# ============================================================

if ($env:SKIP_NET_THROTTLE -eq '1') {
    Write-Host "[SKIP] Network Throttling and QoS -- skipped by user" -ForegroundColor DarkGray
    Write-Host "[SQ_SKIP:NET_THROTTLE]"
} else {
    Write-Host "------------------------------------------" -ForegroundColor DarkGray
    Write-Host "[4/5] REGISTRY NETWORK TWEAKS" -ForegroundColor White
    Write-Host "------------------------------------------" -ForegroundColor DarkGray

    # NOTE: NetworkThrottlingIndex and SystemResponsiveness are handled by win-mmcss
    # (01_Windows_Optimization.ps1 Section 4). Not duplicated here to avoid conflicts.

    # QoS Packet Scheduler -- no reserved bandwidth
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Psched" -Name "NonBestEffortLimit" -Value 0 -CheckKey "REG_QOS" -Label "QoS NonBestEffortLimit = 0 (no reserved bandwidth)"

    # Global TCP Parameters
    $tcpParams = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
    Set-RegistryValueSafe -Path $tcpParams -Name "MaxUserPort" -Value 65534 -CheckKey "REG_MAX_PORT" -Label "MaxUserPort = 65534 (expanded ephemeral port range)"
    Set-RegistryValueSafe -Path $tcpParams -Name "TcpTimedWaitDelay" -Value 30 -CheckKey "REG_TCP_WAIT" -Label "TcpTimedWaitDelay = 30 (faster port recycling)"
    # NOTE: DefaultTTL is handled by win-network (01_Windows_Optimization.ps1 Section 5).

    # Per-Interface TCP -- Delayed ACK Ticks (complements win-network Nagle settings)
    # NOTE: TcpAckFrequency and TCPNoDelay are handled by win-network (01_Windows_Optimization.ps1
    # Section 5) on ALL interfaces. We only add TcpDelAckTicks here (not covered by win-network).
    if ($adapterGuid -notmatch '^\{') { $adapterGuid = "{$adapterGuid}" }
    $ifPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\$adapterGuid"
    Set-RegistryValueSafe -Path $ifPath -Name "TcpDelAckTicks" -Value 0 -CheckKey "REG_DEL_ACK" -Label "TcpDelAckTicks = 0 (no delayed ACK timer)"

    # Host Resolution Priority -- lower number = higher priority
    $svcProvider = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\ServiceProvider"
    Set-RegistryValueSafe -Path $svcProvider -Name "LocalPriority" -Value 4 -CheckKey "REG_HOST_LOCAL" -Label "Host resolution: LocalPriority = 4"
    Set-RegistryValueSafe -Path $svcProvider -Name "HostPriority" -Value 5 -CheckKey "REG_HOST_PRIORITY" -Label "Host resolution: HostPriority = 5"
    Set-RegistryValueSafe -Path $svcProvider -Name "DnsPriority" -Value 6 -CheckKey "REG_HOST_DNS" -Label "Host resolution: DnsPriority = 6"
    Set-RegistryValueSafe -Path $svcProvider -Name "NetbtPriority" -Value 7 -CheckKey "REG_HOST_NETBT" -Label "Host resolution: NetbtPriority = 7"

    Write-Host "[SQ_OK:NET_THROTTLE]"
    Write-Host ""
}


# ============================================================
# SECTION 5: TCP/IP STACK TUNING
# WHY: Ensures TCP auto-tuning is correct (NEVER disabled),
#      disables heuristics, turns off packet coalescing,
#      sets congestion provider to CTCP.
# ============================================================

if ($env:SKIP_TCP_STACK -eq '1') {
    Write-Host "[SKIP] TCP Stack Optimization -- skipped by user" -ForegroundColor DarkGray
    Write-Host "[SQ_SKIP:TCP_STACK]"
} else {
    Write-Host "------------------------------------------" -ForegroundColor DarkGray
    Write-Host "[5/5] TCP/IP STACK TUNING" -ForegroundColor White
    Write-Host "------------------------------------------" -ForegroundColor DarkGray

    # Helper: run netsh and check $LASTEXITCODE for honest SQ_CHECK reporting
    function Invoke-NetshSafe {
        param([string]$Command, [string]$Label, [string]$CheckKey)
        $output = Invoke-Expression "netsh $Command" 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  [OK] $Label" -ForegroundColor Green
            Write-Host "[SQ_CHECK_OK:${CheckKey}]"
        } else {
            Write-Host "  [WARN] $Label -- netsh exit code $LASTEXITCODE" -ForegroundColor Yellow
            Write-Host "[SQ_CHECK_WARN:${CheckKey}:NETSH_EXIT_$LASTEXITCODE]"
        }
    }

    # TCP auto-tuning MUST stay normal (disabling is a harmful Vista-era myth)
    Invoke-NetshSafe -Command "interface tcp set global autotuninglevel=normal" -Label "TCP Auto-Tuning verified as normal (NEVER disable this)" -CheckKey "TCP_AUTO_TUNING"
    Invoke-NetshSafe -Command "interface tcp set heuristics disabled" -Label "TCP heuristics disabled (lets auto-tuning work unimpeded)" -CheckKey "TCP_HEURISTICS"
    Invoke-NetshSafe -Command "interface tcp set global ecncapability=disabled" -Label "ECN disabled (ISP compatibility)" -CheckKey "TCP_ECN"
    Invoke-NetshSafe -Command "interface tcp set global timestamps=disabled" -Label "TCP timestamps disabled (saves 12 bytes/segment)" -CheckKey "TCP_TIMESTAMPS"
    Invoke-NetshSafe -Command "interface tcp set global chimney=disabled" -Label "TCP chimney offload disabled (deprecated, may not exist)" -CheckKey "TCP_CHIMNEY"
    Invoke-NetshSafe -Command "interface tcp set global rsc=disabled" -Label "Receive Segment Coalescing (RSC) disabled globally" -CheckKey "TCP_RSC"
    Invoke-NetshSafe -Command "interface tcp set global rss=enabled" -Label "Receive Side Scaling (RSS) enabled" -CheckKey "TCP_RSS"
    Invoke-NetshSafe -Command "interface tcp set global initialRto=2000" -Label "Initial RTO set to 2000ms (RFC recommended)" -CheckKey "TCP_INITIAL_RTO"

    try {
        Set-NetOffloadGlobalSetting -PacketCoalescingFilter Disabled -ErrorAction Stop
        Write-Host "  [OK] Packet coalescing filter disabled" -ForegroundColor Green
        Write-Host "[SQ_CHECK_OK:TCP_PKT_COALESCE]"
    } catch {
        Write-Host "  [WARN] Packet coalescing -- $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host "[SQ_CHECK_WARN:TCP_PKT_COALESCE:$($_.Exception.Message)]"
    }

    try {
        Set-NetTCPSetting -SettingName InternetCustom -CongestionProvider CTCP -ErrorAction Stop
        Write-Host "  [OK] TCP congestion provider set to CTCP (Compound TCP)" -ForegroundColor Green
        Write-Host "[SQ_CHECK_OK:TCP_CONGESTION]"
    } catch {
        Write-Host "  [WARN] TCP congestion provider -- $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host "[SQ_CHECK_WARN:TCP_CONGESTION:$($_.Exception.Message)]"
    }

    Write-Host "[SQ_OK:TCP_STACK]"
    Write-Host ""
}


# ============================================================
# COMPLETION SUMMARY
# ============================================================

Write-Host "======================================================" -ForegroundColor Green
Write-Host "  NETWORK OPTIMIZATION COMPLETE" -ForegroundColor Green
Write-Host "======================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Applied to adapter: $adapterDesc" -ForegroundColor DarkCyan
Write-Host ""
Write-Host "  REBOOT REQUIRED for these changes:" -ForegroundColor Yellow
Write-Host "    - QoS, MaxUserPort, TcpTimedWaitDelay, TcpDelAckTicks" -ForegroundColor Yellow
Write-Host "    - Host resolution priority" -ForegroundColor Yellow
Write-Host ""
Write-Host "  No reboot needed for:" -ForegroundColor DarkGray
Write-Host "    - Adapter properties, DNS, netsh TCP settings" -ForegroundColor DarkGray
Write-Host ""
