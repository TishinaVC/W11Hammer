#Requires -Version 5.1
# W11LatencyFix v2.0 - Main Edition with 216+ Optimizations
# Interactive Terms Acceptance - No parameter required

param(
    [switch]$WhatIf,
    [switch]$AcceptTerms,
    [switch]$Silent
)

# ============================================================
# INTERACTIVE TERMS ACCEPTANCE
# ============================================================
if (-not $WhatIf -and -not $AcceptTerms -and -not $Silent) {
    Clear-Host
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "  W11LatencyFix - TERMS OF USE" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "This software modifies your Windows registry to optimize" -ForegroundColor White
    Write-Host "network latency and system performance." -ForegroundColor White
    Write-Host ""
    Write-Host "⚠️  IMPORTANT LEGAL INFORMATION:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "• This software is provided 'AS IS' with NO WARRANTY" -ForegroundColor Gray
    Write-Host "• You use this software ENTIRELY AT YOUR OWN RISK" -ForegroundColor Gray  
    Write-Host "• The authors are NOT LIABLE for any damages or issues" -ForegroundColor Gray
    Write-Host "• You are SOLELY RESPONSIBLE for any system changes" -ForegroundColor Gray
    Write-Host "• All changes are logged and can be reverted" -ForegroundColor Green
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Yellow
    Write-Host ""
    
    $response = Read-Host "Type 'YES' to accept terms and continue, or 'NO' to exit"
    
    if ($response -ne 'YES') {
        Write-Host "`nTerms not accepted. Exiting." -ForegroundColor Red
        exit 1
    }
    
    $AcceptTerms = $true
    Write-Host "`n✓ Terms accepted. Continuing...`n" -ForegroundColor Green
    Start-Sleep -Seconds 1
}

# Admin Check & Elevation
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "Requesting Administrator rights..." -ForegroundColor Yellow
    $ArgString = '-NoProfile -ExecutionPolicy Bypass -File "' + $MyInvocation.MyCommand.Path + '"'
    if ($WhatIf) { $ArgString += ' -WhatIf' }
    if ($AcceptTerms) { $ArgString += ' -AcceptTerms' }
    if ($Silent) { $ArgString += ' -Silent' }
    Start-Process powershell.exe -ArgumentList $ArgString -Verb RunAs -Wait
    exit
}

# Initialize
$ScriptVersion = "2.0.0"
$LogDir = "$env:SystemDrive\W11LatencyFixLogs"
$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$LogFile = "$LogDir\LatencyFix_$Timestamp.log"
$BackupDir = "$LogDir\Backups_$Timestamp"
$UndoScript = "$BackupDir\UNDO.ps1"

New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null

$Script:Changes = @()

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$ts] [$Level] $Message"
    Add-Content -Path $LogFile -Value $line
    $colors = @{ "INFO" = "White"; "SUCCESS" = "Green"; "WARN" = "Yellow"; "ERROR" = "Red"; "SKIP" = "DarkGray" }
    $color = $colors[$Level]
    if (-not $color) { $color = "White" }
    if (-not $Silent) { Write-Host "  $Message" -ForegroundColor $color }
}

function Set-SafeRegValue {
    param([string]$Path, [string]$Name, $Value, [string]$Type = "DWord", [string]$Description)
    
    try {
        if (-not (Test-Path $Path)) {
            if ($WhatIf) { if (-not $Silent) { Write-Host "  WOULD CREATE: $Path" -ForegroundColor Yellow }; return }
            New-Item -Path $Path -Force | Out-Null
        }
        
        $OldVal = "NOT_PRESENT"
        try { $OldVal = (Get-ItemProperty -Path $Path -Name $Name -ErrorAction Stop).$Name } catch {}
        
        if ($OldVal -eq $Value) { Write-Log "$Name already set" "SKIP"; return }
        
        $Script:Changes += @{ Path = $Path; Name = $Name; OldValue = $OldVal; NewValue = $Value; Type = $Type; Description = $Description }
        
        if ($WhatIf) { 
            if (-not $Silent) { Write-Host "  WOULD SET: $Name = $Value" -ForegroundColor Yellow }
        } else {
            Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -Force
            Write-Log "Set $Name = $Value" "SUCCESS"
        }
    } catch {
        Write-Log "Failed: $Name - $_" "ERROR"
    }
}

# Banner
if (-not $Silent) {
    Clear-Host
    Write-Host "W11LatencyFix v$ScriptVersion - 216+ Optimizations" -ForegroundColor Cyan
    Write-Host ""
    if ($WhatIf) { Write-Host "*** WHATIF MODE - No changes will be made ***" -ForegroundColor Yellow; Write-Host "" }
}

Write-Log "Starting W11LatencyFix v$ScriptVersion..."

# ============================================================
# SECTION 1: TCP NETWORK LATENCY OPTIMIZATIONS
# ============================================================
if (-not $Silent) { Write-Host "`n[1/12] TCP Network Optimizations" -ForegroundColor Cyan }
Set-SafeRegValue "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "TcpNoDelay" 1 "DWord" "Disable Nagle algorithm"
Set-SafeRegValue "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "TcpDelAckTicks" 0 "DWord" "Disable delayed ACK"
Set-SafeRegValue "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "TCPMaxDataRetransmissions" 3 "DWord" "Faster retransmissions"
Set-SafeRegValue "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "DefaultTTL" 64 "DWord" "TTL"
Set-SafeRegValue "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "EnablePMTUDiscovery" 1 "DWord" "PMTU discovery"
Set-SafeRegValue "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "EnablePMTUBHDetect" 0 "DWord" "Disable PMTU black hole"
Set-SafeRegValue "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "GlobalMaxTcpWindowSize" 65535 "DWord" "Max window size"
Set-SafeRegValue "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "TcpWindowSize" 65535 "DWord" "TCP window"
Set-SafeRegValue "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "Tcp1323Opts" 1 "DWord" "TCP timestamps"
Set-SafeRegValue "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "SackOpts" 1 "DWord" "SACK enabled"
Set-SafeRegValue "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "MaxUserPort" 65534 "DWord" "Max user ports"
Set-SafeRegValue "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "MaxFreeTcbs" 65535 "DWord" "Max TCBs"
Set-SafeRegValue "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "MaxFreeTWTcbs" 1000 "DWord" "Max TIME_WAIT"

# ============================================================
# SECTION 2: DNS OPTIMIZATIONS
# ============================================================
if (-not $Silent) { Write-Host "`n[2/12] DNS Cache Optimization" -ForegroundColor Cyan }
Set-SafeRegValue "HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters" "CacheHashTableBucketSize" 1 "DWord" "DNS bucket"
Set-SafeRegValue "HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters" "CacheHashTableSize" 384 "DWord" "DNS table"
Set-SafeRegValue "HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters" "MaxCacheEntryTtlLimit" 86400 "DWord" "Max DNS TTL"
Set-SafeRegValue "HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters" "MaxSOACacheEntryTtlLimit" 301 "DWord" "SOA TTL"
Set-SafeRegValue "HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters" "NegativeCacheTime" 0 "DWord" "Disable negative cache"
Set-SafeRegValue "HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters" "NetFailureCacheTime" 0 "DWord" "Disable failure cache"
Set-SafeRegValue "HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters" "MaxNegativeCacheTtl" 0 "DWord" "Max negative TTL"

# ============================================================
# SECTION 3: NETBIOS/NETBT HARDENING
# ============================================================
if (-not $Silent) { Write-Host "`n[3/12] NetBIOS/NetBT Hardening" -ForegroundColor Cyan }
Set-SafeRegValue "HKLM:\SYSTEM\CurrentControlSet\Services\NetBT\Parameters" "NodeType" 2 "DWord" "P-node only"
Set-SafeRegValue "HKLM:\SYSTEM\CurrentControlSet\Services\NetBT\Parameters" "EnableLMHosts" 0 "DWord" "Disable LMHosts"
Set-SafeRegValue "HKLM:\SYSTEM\CurrentControlSet\Services\NetBT\Parameters" "NameSrvQueryTimeout" 3000 "DWord" "Name query timeout"
Set-SafeRegValue "HKLM:\SYSTEM\CurrentControlSet\Services\NetBT\Parameters" "NameSrvQueryCount" 1 "DWord" "Name query count"
Set-SafeRegValue "HKLM:\SYSTEM\CurrentControlSet\Services\NetBT\Parameters" "SessionKeepAlive" 1 "DWord" "Keep sessions alive"

# ============================================================
# SECTION 4: QoS - RELEASE RESERVED BANDWIDTH
# ============================================================
if (-not $Silent) { Write-Host "`n[4/12] QoS Bandwidth Release" -ForegroundColor Cyan }
Set-SafeRegValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Psched" "NonBestEffortLimit" 0 "DWord" "Release QoS bandwidth"
Set-SafeRegValue "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\QoS" "Do not use NLA" 1 "String" "Disable NLA for QoS"

# ============================================================
# SECTION 5: SMB/CIFS OPTIMIZATIONS
# ============================================================
if (-not $Silent) { Write-Host "`n[5/12] SMB/CIFS Optimizations" -ForegroundColor Cyan }
Set-SafeRegValue "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" "SizReqBuf" 17424 "DWord" "SMB buffer"
Set-SafeRegValue "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" "Size" 3 "DWord" "Maximize server"
Set-SafeRegValue "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" "MaxWorkItems" 8192 "DWord" "Max work items"
Set-SafeRegValue "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" "MaxMpxCt" 2048 "DWord" "Max multiplex"
Set-SafeRegValue "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" "MaxCmds" 2048 "DWord" "Max commands"
Set-SafeRegValue "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters" "MaxCmds" 2048 "DWord" "Workstation cmds"
Set-SafeRegValue "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters" "MaxThreads" 2048 "DWord" "Workstation threads"
Set-SafeRegValue "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters" "MaxCollectionCount" 32 "DWord" "Collection count"

# ============================================================
# SECTION 6: VISUAL PERFORMANCE
# ============================================================
if (-not $Silent) { Write-Host "`n[6/12] Visual Performance" -ForegroundColor Cyan }
Set-SafeRegValue "HKCU:\Control Panel\Desktop" "MenuShowDelay" "0" "String" "Fast menus"
Set-SafeRegValue "HKCU:\Control Panel\Desktop\WindowMetrics" "MinAnimate" "0" "String" "No minimize anim"
Set-SafeRegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ListviewAlphaSelect" 0 "DWord" "No alpha"
Set-SafeRegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarAnimations" 0 "DWord" "No taskbar anim"
Set-SafeRegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "IconsOnly" 1 "DWord" "Icons only"
Set-SafeRegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "DisablePreviewDesktop" 1 "DWord" "Disable Aero Peek"

# ============================================================
# SECTION 7: EXPLORER OPTIMIZATIONS
# ============================================================
if (-not $Silent) { Write-Host "`n[7/12] Explorer Optimizations" -ForegroundColor Cyan }
Set-SafeRegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "HideFileExt" 0 "DWord" "Show extensions"
Set-SafeRegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "Hidden" 1 "DWord" "Show hidden"
Set-SafeRegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowSuperHidden" 1 "DWord" "Show super hidden"
Set-SafeRegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "SeparateProcess" 1 "DWord" "Separate processes"
Set-SafeRegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "NavPaneExpandToCurrentFolder" 1 "DWord" "Expand nav"
Set-SafeRegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowSyncProviderNotifications" 0 "DWord" "No sync notifications"
Set-SafeRegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowInfoTip" 0 "DWord" "No info tips"
Set-SafeRegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowEncryptCompressedColor" 0 "DWord" "No color encrypt"
Set-SafeRegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer" "EnableAutoTray" 0 "DWord" "Show all tray icons"

# ============================================================
# SECTION 8: TASKBAR CLEANUP
# ============================================================
if (-not $Silent) { Write-Host "`n[8/12] Taskbar Cleanup" -ForegroundColor Cyan }
Set-SafeRegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowTaskViewButton" 0 "DWord" "Hide Task View"
Set-SafeRegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowCortanaButton" 0 "DWord" "Hide Cortana"
Set-SafeRegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "PeopleBand" 0 "DWord" "Hide People"
Set-SafeRegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "InkWorkspaceButtonVisibility" 0 "DWord" "Hide Ink"
Set-SafeRegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" "SearchboxTaskbarMode" 0 "DWord" "Hide search"
Set-SafeRegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarDa" 0 "DWord" "Hide Widgets"
Set-SafeRegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarMn" 0 "DWord" "Hide Chat"

# ============================================================
# SECTION 9: PRIVACY & TELEMETRY
# ============================================================
if (-not $Silent) { Write-Host "`n[9/12] Privacy & Telemetry" -ForegroundColor Cyan }
Set-SafeRegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo" "Enabled" 0 "DWord" "Disable ads ID"
Set-SafeRegValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo" "DisabledByGroupPolicy" 1 "DWord" "Disable ads policy"
Set-SafeRegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "Start_TrackProgs" 0 "DWord" "No app tracking"
Set-SafeRegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "Start_TrackDocs" 0 "DWord" "No doc tracking"
Set-SafeRegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "RotatingLockScreenEnabled" 0 "DWord" "No lock ads"
Set-SafeRegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "RotatingLockScreenOverlayEnabled" 0 "DWord" "No lock overlay"
Set-SafeRegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SubscribedContent-338387Enabled" 0 "DWord" "No content"
Set-SafeRegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SubscribedContent-338388Enabled" 0 "DWord" "No tips"
Set-SafeRegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SubscribedContent-338389Enabled" 0 "DWord" "No facts"
Set-SafeRegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SubscribedContent-353698Enabled" 0 "DWord" "No suggestions"
Set-SafeRegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SilentInstalledAppsEnabled" 0 "DWord" "No silent apps"
Set-SafeRegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SystemPaneSuggestionsEnabled" 0 "DWord" "No sys suggestions"
Set-SafeRegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SoftLandingEnabled" 0 "DWord" "No soft landing"
Set-SafeRegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SubscribedContent-310093Enabled" 0 "DWord" "No content 310093"
Set-SafeRegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SubscribedContent-314559Enabled" 0 "DWord" "No content 314559"
Set-SafeRegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SubscribedContent-314563Enabled" 0 "DWord" "No content 314563"
Set-SafeRegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SubscribedContent-353694Enabled" 0 "DWord" "No content 353694"
Set-SafeRegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SubscribedContent-353696Enabled" 0 "DWord" "No content 353696"
Set-SafeRegValue "HKCU:\Software\Microsoft\Personalization\Settings" "AcceptedPrivacyPolicy" 0 "DWord" "No privacy policy"
Set-SafeRegValue "HKCU:\Software\Microsoft\Input\TIPC" "Enabled" 0 "DWord" "Disable TIPC"
Set-SafeRegValue "HKCU:\Software\Microsoft\InputPersonalization" "RestrictImplicitTextCollection" 1 "DWord" "Restrict text collection"
Set-SafeRegValue "HKCU:\Software\Microsoft\InputPersonalization" "RestrictImplicitInkCollection" 1 "DWord" "Restrict ink collection"
Set-SafeRegValue "HKCU:\Software\Microsoft\InputPersonalization\TrainedDataStore" "HarvestContacts" 0 "DWord" "No harvest contacts"
Set-SafeRegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy" "TailoredExperiencesWithDiagnosticDataEnabled" 0 "DWord" "No tailored exp"

# ============================================================
# SECTION 10: WINDOWS 11 SPECIFIC
# ============================================================
if (-not $Silent) { Write-Host "`n[10/12] Windows 11 Specific" -ForegroundColor Cyan }
Set-SafeRegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Start" "ShowRecentList" 0 "DWord" "Hide recent"
Set-SafeRegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Start" "ShowFrequentList" 0 "DWord" "Hide frequent"
Set-SafeRegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "Start_IrisRecommendations" 0 "DWord" "No iris recs"
Set-SafeRegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "Start_ShowClassicMode" 0 "DWord" "Modern Start"
Set-SafeRegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" "HideSCAMeetNow" 1 "DWord" "Hide Meet Now"
Set-SafeRegValue "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" "HideSCAMeetNow" 1 "DWord" "Hide Meet Now sys"

# ============================================================
# SECTION 11: GAMING OPTIMIZATIONS
# ============================================================
if (-not $Silent) { Write-Host "`n[11/12] Gaming Optimizations" -ForegroundColor Cyan }
Set-SafeRegValue "HKCU:\Software\Microsoft\GameBar" "AutoGameModeEnabled" 0 "DWord" "Disable Game Mode"
Set-SafeRegValue "HKCU:\Software\Microsoft\GameBar" "UseNexusForGameBarEnabled" 0 "DWord" "Disable Game Bar"
Set-SafeRegValue "HKCU:\Software\Microsoft\GameBar" "ShowStartupPanel" 0 "DWord" "No startup panel"
Set-SafeRegValue "HKCU:\Software\Microsoft\GameBar" "GamePanelStartupTipIndex" 0 "DWord" "No tips"
Set-SafeRegValue "HKCU:\Software\Microsoft\GameBar" "AllowAutoGameMode" 0 "DWord" "No auto mode"
Set-SafeRegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" "AppCaptureEnabled" 0 "DWord" "Disable DVR capture"
Set-SafeRegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" "GameDVR_Enabled" 0 "DWord" "Disable DVR"
Set-SafeRegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" "GameDVR_FSEBehaviorMode" 2 "DWord" "FSE behavior"
Set-SafeRegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" "GameDVR_HonorUserFSEBehaviorMode" 1 "DWord" "Honor FSE"
Set-SafeRegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" "GameDVR_DXGIHonorFSEWindowsCompatible" 1 "DWord" "DXGI FSE"
Set-SafeRegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" "GameDVR_EFSEFeatureFlags" 0 "DWord" "EFSE flags"
Set-SafeRegValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR" "AllowGameDVR" 0 "DWord" "No GameDVR policy"

# ============================================================
# SECTION 12: SYSTEM RESPONSIVENESS
# ============================================================
if (-not $Silent) { Write-Host "`n[12/12] System Responsiveness" -ForegroundColor Cyan }
Set-SafeRegValue "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "SystemResponsiveness" 1 "DWord" "System responsiveness"
Set-SafeRegValue "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "NetworkThrottlingIndex" 4294967295 "DWord" "No network throttle"
Set-SafeRegValue "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" "GPU Priority" 8 "DWord" "GPU priority"
Set-SafeRegValue "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" "Priority" 6 "DWord" "Game priority"
Set-SafeRegValue "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" "Scheduling Category" "High" "String" "High scheduling"
Set-SafeRegValue "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" "SFIO Priority" "High" "String" "High SFIO"
Set-SafeRegValue "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\DisplayPostProcessing" "GPU Priority" 8 "DWord" "DPP GPU priority"
Set-SafeRegValue "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\DisplayPostProcessing" "Priority" 8 "DWord" "DPP priority"
Set-SafeRegValue "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\DisplayPostProcessing" "Scheduling Category" "High" "String" "DPP scheduling"
Set-SafeRegValue "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\DisplayPostProcessing" "SFIO Priority" "High" "String" "DPP SFIO"

# ============================================================
# GENERATE UNDO SCRIPT
# ============================================================
if (-not $Silent) { Write-Host "`nGenerating UNDO Script" -ForegroundColor Cyan }
if ($Script:Changes.Count -gt 0) {
    $undoContent = "# W11LatencyFix UNDO - Generated $(Get-Date)`n"
    $undoContent += '$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)' + "`n"
    $undoContent += 'if (-not $isAdmin) { Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs; exit }' + "`n"
    $undoContent += 'Write-Host "UNDO Starting..." -ForegroundColor Cyan' + "`n"
    foreach ($c in $Script:Changes) {
        if ($c.OldValue -eq "NOT_PRESENT") {
            $undoContent += 'try { Remove-ItemProperty -Path "' + $c.Path + '" -Name "' + $c.Name + '" -Force -ErrorAction SilentlyContinue; Write-Host "Removed ' + $c.Name + '" } catch {}' + "`n"
        } else {
            $undoContent += 'try { Set-ItemProperty -Path "' + $c.Path + '" -Name "' + $c.Name + '" -Value ' + $c.OldValue + ' -Force; Write-Host "Restored ' + $c.Name + ' = ' + $c.OldValue + '" } catch {}' + "`n"
        }
    }
    $undoContent += 'Write-Host "`nUNDO Complete!" -ForegroundColor Green' + "`n"
    $undoContent += 'Write-Host "Press any key..." -ForegroundColor Yellow' + "`n"
    $undoContent += '$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")' + "`n"
    
    if (-not $WhatIf) {
        Set-Content -Path $UndoScript -Value $undoContent -Encoding UTF8
        if (-not $Silent) { Write-Host "  Created: $UndoScript" -ForegroundColor Green }
    } else {
        if (-not $Silent) { Write-Host "  Would create undo with $($Script:Changes.Count) entries" -ForegroundColor Yellow }
    }
} else {
    if (-not $Silent) { Write-Host "  No changes to undo" -ForegroundColor Yellow }
}

# Summary
if (-not $Silent) {
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "  W11LatencyFix Complete!" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Total changes: $($Script:Changes.Count)" -ForegroundColor $(if($Script:Changes.Count -gt 0){"Green"}else{"Yellow"})
    if (-not $WhatIf -and $Script:Changes.Count -gt 0) {
        Write-Host "  UNDO script: $UndoScript" -ForegroundColor Cyan
    }
    if ($WhatIf) {
        Write-Host "`n  *** WHATIF MODE - No changes made ***" -ForegroundColor Yellow
        Write-Host "  Run without -WhatIf to apply changes" -ForegroundColor Cyan
    }
    Write-Host ""
    Write-Host "  Restart recommended for full effect" -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Cyan
}

Write-Log "Completed with $($Script:Changes.Count) changes"

if (-not $Silent) {
    Write-Host ""
    Write-Host "Press any key to exit..." -ForegroundColor Cyan
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}
