#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Restore Network Settings to Windows Defaults
    Version: 1.0 | March 2026
.DESCRIPTION
    Reverses all changes made by 21_Network_Optimization.ps1:
    adapter properties, DNS, registry tweaks, TCP/IP stack settings.
    Restores everything to standard Windows defaults.
.NOTES
    Run as Administrator. Reboot required for some registry changes.
#>

$ErrorActionPreference = 'SilentlyContinue'
$Headless = $env:SENSEQUALITY_HEADLESS -eq "1"

# ============================================================
# HELPER FUNCTIONS
# ============================================================

function Restore-AdapterPropertySafe {
    param(
        [string]$AdapterName,
        [string]$PropertyName,
        [string]$DefaultValue,
        [string]$CheckKey
    )

    $prop = Get-NetAdapterAdvancedProperty -Name $AdapterName -DisplayName $PropertyName -ErrorAction SilentlyContinue
    if (-not $prop) {
        Write-Host "  [SKIP] $PropertyName -- not available on this adapter" -ForegroundColor DarkGray
        Write-Host "[SQ_CHECK_WARN:${CheckKey}:PROPERTY_NOT_FOUND]"
        return
    }

    if ($prop.ValidDisplayValues -and $DefaultValue -notin $prop.ValidDisplayValues) {
        Write-Host "  [SKIP] $PropertyName -- default value not valid for this adapter" -ForegroundColor DarkGray
        Write-Host "[SQ_CHECK_WARN:${CheckKey}:VALUE_NOT_VALID]"
        return
    }

    if ($prop.DisplayValue -eq $DefaultValue) {
        Write-Host "  [OK] $PropertyName already at default ($DefaultValue)" -ForegroundColor Green
        Write-Host "[SQ_CHECK_OK:${CheckKey}]"
        return
    }

    try {
        Set-NetAdapterAdvancedProperty -Name $AdapterName -DisplayName $PropertyName -DisplayValue $DefaultValue -ErrorAction Stop
        Write-Host "  [OK] $PropertyName restored to $DefaultValue" -ForegroundColor Green
        Write-Host "[SQ_CHECK_OK:${CheckKey}]"
    }
    catch {
        Write-Host "  [FAIL] $PropertyName -- $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "[SQ_CHECK_FAIL:${CheckKey}:$($_.Exception.Message)]"
    }
}

function Remove-RegistryValueSafe {
    param(
        [string]$Path,
        [string]$Name,
        [string]$CheckKey,
        [string]$Label
    )

    try {
        $exists = Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue
        if (-not $exists) {
            Write-Host "  [OK] $Label -- already absent" -ForegroundColor Green
            Write-Host "[SQ_CHECK_OK:${CheckKey}]"
            return
        }
        Remove-ItemProperty -Path $Path -Name $Name -ErrorAction Stop
        Write-Host "  [OK] $Label -- removed" -ForegroundColor Green
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
Write-Host "======================================================" -ForegroundColor Yellow
Write-Host "  Network Settings -- Restore to Windows Defaults" -ForegroundColor Yellow
Write-Host "  Reverting all optimizations from Network Optimizer" -ForegroundColor Yellow
Write-Host "======================================================" -ForegroundColor Yellow
Write-Host ""


# ============================================================
# SECTION 1: DETECT PRIMARY NETWORK ADAPTER
# ============================================================

Write-Host "------------------------------------------" -ForegroundColor DarkGray
Write-Host "[1/5] ADAPTER DETECTION" -ForegroundColor White
Write-Host "------------------------------------------" -ForegroundColor DarkGray

$primaryAdapter = Get-NetAdapter -Physical | Where-Object { $_.Status -eq 'Up' } | Select-Object -First 1
if (-not $primaryAdapter) {
    Write-Host "  [FAIL] No active physical network adapter found." -ForegroundColor Red
    Write-Host "[SQ_CHECK_FAIL:REVERT_ADAPTER:NO_ACTIVE_ADAPTER]"
    exit 1
}

$adapterName = $primaryAdapter.Name
$adapterGuid = $primaryAdapter.InterfaceGuid
$adapterDesc = $primaryAdapter.InterfaceDescription

Write-Host "  Adapter: $adapterDesc" -ForegroundColor DarkCyan
Write-Host "  Name: $adapterName | GUID: $adapterGuid" -ForegroundColor DarkGray
Write-Host "[SQ_CHECK_OK:REVERT_ADAPTER]"
Write-Host ""


# ============================================================
# SECTION 2: RESTORE ADAPTER PROPERTIES TO WINDOWS DEFAULTS
# ============================================================

Write-Host "------------------------------------------" -ForegroundColor DarkGray
Write-Host "[2/5] RESTORE ADAPTER PROPERTIES" -ForegroundColor White
Write-Host "------------------------------------------" -ForegroundColor DarkGray

Restore-AdapterPropertySafe -AdapterName $adapterName -PropertyName "Interrupt Moderation" -DefaultValue "Enabled" -CheckKey "REVERT_INTERRUPT_MOD"
Restore-AdapterPropertySafe -AdapterName $adapterName -PropertyName "Interrupt Moderation Rate" -DefaultValue "Adaptive" -CheckKey "REVERT_INTERRUPT_RATE"
Restore-AdapterPropertySafe -AdapterName $adapterName -PropertyName "Flow Control" -DefaultValue "Rx & Tx Enabled" -CheckKey "REVERT_FLOW_CTRL"
Restore-AdapterPropertySafe -AdapterName $adapterName -PropertyName "Large Send Offload V2 (IPv4)" -DefaultValue "Enabled" -CheckKey "REVERT_LSO_V4"
Restore-AdapterPropertySafe -AdapterName $adapterName -PropertyName "Large Send Offload V2 (IPv6)" -DefaultValue "Enabled" -CheckKey "REVERT_LSO_V6"
Restore-AdapterPropertySafe -AdapterName $adapterName -PropertyName "Energy Efficient Ethernet" -DefaultValue "Enabled" -CheckKey "REVERT_EEE"
Restore-AdapterPropertySafe -AdapterName $adapterName -PropertyName "Adaptive Inter-Frame Spacing" -DefaultValue "Enabled" -CheckKey "REVERT_AIFS"
Restore-AdapterPropertySafe -AdapterName $adapterName -PropertyName "Receive Side Scaling" -DefaultValue "Enabled" -CheckKey "REVERT_RSS"
Restore-AdapterPropertySafe -AdapterName $adapterName -PropertyName "Receive Buffers" -DefaultValue "256" -CheckKey "REVERT_RX_BUF"
Restore-AdapterPropertySafe -AdapterName $adapterName -PropertyName "Transmit Buffers" -DefaultValue "256" -CheckKey "REVERT_TX_BUF"

# Power saving properties -- restore all found variants to enabled (Windows defaults)
$powerSaveProps = @(
    @{ Name = "Green Ethernet";              Key = "REVERT_GREEN_ETH" },
    @{ Name = "Power Saving Mode";           Key = "REVERT_PWR_SAVE" },
    @{ Name = "Reduce Speed On Power Down";  Key = "REVERT_REDUCE_SPD" },
    @{ Name = "Ultra Low Power Mode";        Key = "REVERT_ULTRA_LP" },
    @{ Name = "Wake on Magic Packet";        Key = "REVERT_WOL_MAGIC" },
    @{ Name = "Wake on Pattern Match";       Key = "REVERT_WOL_PATTERN" },
    @{ Name = "Gigabit Lite";                Key = "REVERT_GBIT_LITE" },
    @{ Name = "Advanced EEE";                Key = "REVERT_ADV_EEE" }
)
foreach ($p in $powerSaveProps) {
    Restore-AdapterPropertySafe -AdapterName $adapterName -PropertyName $p.Name -DefaultValue "Enabled" -CheckKey $p.Key
}

# Re-enable Receive Segment Coalescing at adapter level
try {
    Enable-NetAdapterRsc -Name $adapterName -ErrorAction Stop
    Write-Host "  [OK] Receive Segment Coalescing (RSC) re-enabled at adapter level" -ForegroundColor Green
    Write-Host "[SQ_CHECK_OK:REVERT_RSC_ADAPTER]"
} catch {
    Write-Host "  [WARN] RSC enable -- $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host "[SQ_CHECK_WARN:REVERT_RSC_ADAPTER:$($_.Exception.Message)]"
}

Write-Host ""


# ============================================================
# SECTION 3: RESET DNS TO DHCP (AUTOMATIC)
# ============================================================

Write-Host "------------------------------------------" -ForegroundColor DarkGray
Write-Host "[3/5] RESET DNS TO AUTOMATIC (DHCP)" -ForegroundColor White
Write-Host "------------------------------------------" -ForegroundColor DarkGray

try {
    $activeAdapters = Get-NetAdapter -Physical | Where-Object { $_.Status -eq 'Up' }
    $dnsReset = 0
    foreach ($nic in $activeAdapters) {
        $existingDns = Get-DnsClientServerAddress -InterfaceIndex $nic.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
        if ($existingDns -and $existingDns.ServerAddresses) {
            Write-Host "  [INFO] $($nic.Name) DNS was: $($existingDns.ServerAddresses -join ', ')" -ForegroundColor DarkGray
        }
        Set-DnsClientServerAddress -InterfaceIndex $nic.ifIndex -ResetServerAddresses -ErrorAction Stop
        $dnsReset++
    }
    Clear-DnsClientCache -ErrorAction SilentlyContinue
    Write-Host "  [OK] DNS reset to automatic (DHCP) on $dnsReset adapter(s), cache cleared" -ForegroundColor Green
    Write-Host "[SQ_CHECK_OK:REVERT_DNS]"
} catch {
    Write-Host "  [FAIL] DNS reset -- $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "[SQ_CHECK_FAIL:REVERT_DNS:$($_.Exception.Message)]"
}

Write-Host ""


# ============================================================
# SECTION 4: REMOVE REGISTRY NETWORK TWEAKS
# ============================================================

Write-Host "------------------------------------------" -ForegroundColor DarkGray
Write-Host "[4/5] REMOVE REGISTRY NETWORK TWEAKS" -ForegroundColor White
Write-Host "------------------------------------------" -ForegroundColor DarkGray

# QoS Packet Scheduler
Remove-RegistryValueSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Psched" -Name "NonBestEffortLimit" -CheckKey "REVERT_REG_QOS" -Label "QoS NonBestEffortLimit"

# Global TCP Parameters
$tcpParams = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
Remove-RegistryValueSafe -Path $tcpParams -Name "MaxUserPort" -CheckKey "REVERT_REG_MAX_PORT" -Label "MaxUserPort"
Remove-RegistryValueSafe -Path $tcpParams -Name "TcpTimedWaitDelay" -CheckKey "REVERT_REG_TCP_WAIT" -Label "TcpTimedWaitDelay"

# Per-Interface TCP -- Delayed ACK Ticks
if ($adapterGuid -notmatch '^\{') { $adapterGuid = "{$adapterGuid}" }
$ifPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\$adapterGuid"
Remove-RegistryValueSafe -Path $ifPath -Name "TcpDelAckTicks" -CheckKey "REVERT_REG_DEL_ACK" -Label "TcpDelAckTicks"

# Host Resolution Priority
$svcProvider = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\ServiceProvider"
Remove-RegistryValueSafe -Path $svcProvider -Name "LocalPriority" -CheckKey "REVERT_REG_HOST_LOCAL" -Label "Host resolution: LocalPriority"
Remove-RegistryValueSafe -Path $svcProvider -Name "HostPriority" -CheckKey "REVERT_REG_HOST_PRIORITY" -Label "Host resolution: HostPriority"
Remove-RegistryValueSafe -Path $svcProvider -Name "DnsPriority" -CheckKey "REVERT_REG_HOST_DNS" -Label "Host resolution: DnsPriority"
Remove-RegistryValueSafe -Path $svcProvider -Name "NetbtPriority" -CheckKey "REVERT_REG_HOST_NETBT" -Label "Host resolution: NetbtPriority"

Write-Host ""


# ============================================================
# SECTION 5: RESET TCP/IP STACK TO WINDOWS DEFAULTS
# ============================================================

Write-Host "------------------------------------------" -ForegroundColor DarkGray
Write-Host "[5/5] RESET TCP/IP STACK TO DEFAULTS" -ForegroundColor White
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

Invoke-NetshSafe -Command "interface tcp set heuristics enabled" -Label "TCP heuristics restored to enabled" -CheckKey "REVERT_TCP_HEURISTICS"
Invoke-NetshSafe -Command "interface tcp set global ecncapability=default" -Label "ECN restored to default" -CheckKey "REVERT_TCP_ECN"
Invoke-NetshSafe -Command "interface tcp set global timestamps=default" -Label "TCP timestamps restored to default" -CheckKey "REVERT_TCP_TIMESTAMPS"
Invoke-NetshSafe -Command "interface tcp set global rsc=enabled" -Label "Receive Segment Coalescing (RSC) re-enabled globally" -CheckKey "REVERT_TCP_RSC"
Invoke-NetshSafe -Command "interface tcp set global rss=enabled" -Label "Receive Side Scaling (RSS) verified as enabled (Windows default)" -CheckKey "REVERT_TCP_RSS"
Invoke-NetshSafe -Command "interface tcp set global initialRto=3000" -Label "Initial RTO restored to 3000ms (Windows default)" -CheckKey "REVERT_TCP_INITIAL_RTO"
# Chimney offload is deprecated on modern Windows but attempt restore for older builds
Invoke-NetshSafe -Command "interface tcp set global chimney=enabled" -Label "TCP chimney offload restored to enabled (deprecated, may not exist)" -CheckKey "REVERT_TCP_CHIMNEY"

try {
    Set-NetOffloadGlobalSetting -PacketCoalescingFilter Enabled -ErrorAction Stop
    Write-Host "  [OK] Packet coalescing filter restored to enabled" -ForegroundColor Green
    Write-Host "[SQ_CHECK_OK:REVERT_TCP_PKT_COALESCE]"
} catch {
    Write-Host "  [WARN] Packet coalescing -- $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host "[SQ_CHECK_WARN:REVERT_TCP_PKT_COALESCE:$($_.Exception.Message)]"
}

try {
    Set-NetTCPSetting -SettingName InternetCustom -CongestionProvider Default -ErrorAction Stop
    Write-Host "  [OK] TCP congestion provider restored to Default" -ForegroundColor Green
    Write-Host "[SQ_CHECK_OK:REVERT_TCP_CONGESTION]"
} catch {
    Write-Host "  [WARN] TCP congestion provider -- $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host "[SQ_CHECK_WARN:REVERT_TCP_CONGESTION:$($_.Exception.Message)]"
}

Write-Host ""


# ============================================================
# COMPLETION SUMMARY
# ============================================================

Write-Host "======================================================" -ForegroundColor Green
Write-Host "  NETWORK SETTINGS RESTORED TO WINDOWS DEFAULTS" -ForegroundColor Green
Write-Host "======================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Applied to adapter: $adapterDesc" -ForegroundColor DarkCyan
Write-Host ""
Write-Host "  REBOOT REQUIRED for these changes:" -ForegroundColor Yellow
Write-Host "    - Registry tweaks (QoS, MaxUserPort, TcpTimedWaitDelay, etc.)" -ForegroundColor Yellow
Write-Host "    - Host resolution priority" -ForegroundColor Yellow
Write-Host ""
Write-Host "  No reboot needed for:" -ForegroundColor DarkGray
Write-Host "    - Adapter properties, DNS, netsh TCP settings" -ForegroundColor DarkGray
Write-Host ""
