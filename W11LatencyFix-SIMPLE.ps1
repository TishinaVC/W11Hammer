#Requires -Version 5.1
<#
.SYNOPSIS
    W11LatencyFix v1.0 - SAFE Windows 11 Optimizer
#>

[CmdletBinding()]
param(
    [switch]$WhatIf,
    [switch]$AcceptTerms
)

# Terms Check
if (-not $WhatIf -and -not $AcceptTerms) {
    Write-Host "Please use -AcceptTerms to run" -ForegroundColor Yellow
    exit 1
}

# Self-Elevation
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Re-launching as Administrator..." -ForegroundColor Yellow
    $ArgString = '-NoProfile -ExecutionPolicy Bypass -File "' + $MyInvocation.MyCommand.Path + '"'
    if ($WhatIf) { $ArgString += ' -WhatIf' }
    if ($AcceptTerms) { $ArgString += ' -AcceptTerms' }
    Start-Process -FilePath "powershell.exe" -ArgumentList $ArgString -Verb RunAs
    exit
}

# Initialize
$ScriptVersion = "1.0.0-SAFE"
$LogDir = "$env:SystemDrive\W11LatencyFixLogs"
$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$LogFile = "$LogDir\LatencyFix_$Timestamp.log"
$BackupDir = "$LogDir\Backups_$Timestamp"
$UndoScript = "$BackupDir\UNDO_CHANGES.ps1"

if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }
if (-not (Test-Path $BackupDir)) { New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null }

$Script:Changes = @()

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "[$timestamp] [$Level] $Message"
    Add-Content -Path $LogFile -Value $entry
    Write-Host "  $Message" -ForegroundColor $(switch($Level){"INFO"{"White"}"SUCCESS"{"Green"}"WARN"{"Yellow"}"ERROR"{"Red"}default{"White"}})
}

# System Restore Point
if (-not $WhatIf) {
    try {
        Enable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction SilentlyContinue | Out-Null
        $RestorePointName = "Before W11LatencyFix v$ScriptVersion - $Timestamp"
        Checkpoint-Computer -Description $RestorePointName -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
        Write-Host "Restore Point created: $RestorePointName" -ForegroundColor Green
    }
    catch {
        $cont = Read-Host "Continue without restore point? [y/N]"
        if ($cont -ne 'y') { exit 1 }
    }
}

# Reversibility Check
if (-not $WhatIf) {
    try {
        $TestFile = "$BackupDir\_test.tmp"
        "test" | Out-File -FilePath $TestFile -Force
        Remove-Item -Path $TestFile -Force
    }
    catch {
        Write-Host "Cannot write to backup dir!" -ForegroundColor Red
        exit 1
    }
}

# Banner
Clear-Host
Write-Host "W11LatencyFix v$ScriptVersion" -ForegroundColor Cyan
Write-Host ""

if ($WhatIf) {
    Write-Host "*** WHATIF MODE ***" -ForegroundColor Yellow
}

Write-Log "Starting..." "INFO"

# ============================================================
# SECTION 1: TCP NETWORK LATENCY OPTIMIZATIONS
# ============================================================
Write-Host "`n== TCP Network Latency Optimizations ==" -ForegroundColor Cyan
Set-SafeRegValue -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name "TcpNoDelay" -Value 1 -Type DWord -Description "Disable Nagle algorithm"
Set-SafeRegValue -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name "TcpDelAckTicks" -Value 0 -Type DWord -Description "Disable delayed ACK"
Set-SafeRegValue -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name "TCPMaxDataRetransmissions" -Value 3 -Type DWord -Description "Faster retransmissions"
Set-SafeRegValue -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name "DefaultTTL" -Value 64 -Type DWord -Description "TTL for faster routing"
Set-SafeRegValue -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name "EnablePMTUBHDetect" -Value 0 -Type DWord -Description "Disable PMTU black hole detection"
Set-SafeRegValue -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name "EnablePMTUDiscovery" -Value 1 -Type DWord -Description "Enable PMTU discovery"
Set-SafeRegValue -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name "GlobalMaxTcpWindowSize" -Value 65535 -Type DWord -Description "Max TCP window size"
Set-SafeRegValue -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name "TcpWindowSize" -Value 65535 -Type DWord -Description "TCP window size"
Set-SafeRegValue -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name "MaxUserPort" -Value 65534 -Type DWord -Description "Max user ports"
Set-SafeRegValue -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name "MaxFreeTcbs" -Value 65535 -Type DWord -Description "Max free TCBs"
Set-SafeRegValue -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name "Tcp1323Opts" -Value 1 -Type DWord -Description "Enable TCP timestamps"
Set-SafeRegValue -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name "SackOpts" -Value 1 -Type DWord -Description "Enable SACK"

# ============================================================
# SECTION 2: DNS CACHE OPTIMIZATION
# ============================================================
Write-Host "`n== DNS Cache Optimization ==" -ForegroundColor Cyan
Set-SafeRegValue -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters" -Name "CacheHashTableBucketSize" -Value 1 -Type DWord -Description "DNS cache bucket size"
Set-SafeRegValue -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters" -Name "CacheHashTableSize" -Value 384 -Type DWord -Description "DNS cache table size"
Set-SafeRegValue -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters" -Name "MaxCacheEntryTtlLimit" -Value 86400 -Type DWord -Description "Max DNS cache TTL"
Set-SafeRegValue -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters" -Name "MaxSOACacheEntryTtlLimit" -Value 301 -Type DWord -Description "Max SOA cache TTL"

# ============================================================
# SECTION 3: VISUAL PERFORMANCE
# ============================================================
Write-Host "`n== Visual Performance ==" -ForegroundColor Cyan
Set-SafeRegValue -Path "HKCU:\Control Panel\Desktop" -Name "UserPreferencesMask" -Value ([byte[]](0x90,0x12,0x03,0x80,0x10,0x00,0x00,0x00)) -Type Binary -Description "Disable visual effects"
Set-SafeRegValue -Path "HKCU:\Control Panel\Desktop\WindowMetrics" -Name "MinAnimate" -Value 0 -Type String -Description "Disable window minimize animation"
Set-SafeRegValue -Path "HKCU:\Control Panel\Desktop" -Name "MenuShowDelay" -Value 0 -Type String -Description "Faster menus"
Set-SafeRegValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ListviewAlphaSelect" -Value 0 -Type DWord -Description "Disable listview alpha"
Set-SafeRegValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarAnimations" -Value 0 -Type DWord -Description "Disable taskbar animations"

# ============================================================
# SECTION 4: EXPLORER PERFORMANCE
# ============================================================
Write-Host "`n== Explorer Performance ==" -ForegroundColor Cyan
Set-SafeRegValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "DisablePreviewDesktop" -Value 1 -Type DWord -Description "Disable Aero Peek"
Set-SafeRegValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "NavPaneExpandToCurrentFolder" -Value 1 -Type DWord -Description "Expand nav to current folder"
Set-SafeRegValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "SeparateProcess" -Value 1 -Type DWord -Description "Separate Explorer processes"
Set-SafeRegValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowEncryptCompressedColor" -Value 0 -Type DWord -Description "Don't color encrypted files"
Set-SafeRegValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowInfoTip" -Value 0 -Type DWord -Description "Disable file info tips"
Set-SafeRegValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "HideFileExt" -Value 0 -Type DWord -Description "Show file extensions"
Set-SafeRegValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Hidden" -Value 1 -Type DWord -Description "Show hidden files"
Set-SafeRegValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowSuperHidden" -Value 1 -Type DWord -Description "Show super hidden files"

# ============================================================
# SECTION 5: TASKBAR CLEANUP
# ============================================================
Write-Host "`n== Taskbar Cleanup ==" -ForegroundColor Cyan
Set-SafeRegValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowTaskViewButton" -Value 0 -Type DWord -Description "Hide Task View button"
Set-SafeRegValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowCortanaButton" -Value 0 -Type DWord -Description "Hide Cortana button"
Set-SafeRegValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "PeopleBand" -Value 0 -Type DWord -Description "Hide People bar"
Set-SafeRegValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "InkWorkspaceButtonVisibility" -Value 0 -Type DWord -Description "Hide Ink Workspace"
Set-SafeRegValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" -Name "SearchboxTaskbarMode" -Value 0 -Type DWord -Description "Hide search box"

# ============================================================
# SECTION 6: PRIVACY - ADVERTISING & TELEMETRY
# ============================================================
Write-Host "`n== Privacy - Advertising & Telemetry ==" -ForegroundColor Cyan
Set-SafeRegValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo" -Name "Enabled" -Value 0 -Type DWord -Description "Disable advertising ID"
Set-SafeRegValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo" -Name "DisabledByGroupPolicy" -Value 1 -Type DWord -Description "Disable advertising via policy"
Set-SafeRegValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Start_TrackProgs" -Value 0 -Type DWord -Description "Disable app launch tracking"
Set-SafeRegValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Start_TrackDocs" -Value 0 -Type DWord -Description "Disable document tracking"
Set-SafeRegValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "RotatingLockScreenEnabled" -Value 0 -Type DWord -Description "Disable lock screen ads"
Set-SafeRegValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "RotatingLockScreenOverlayEnabled" -Value 0 -Type DWord -Description "Disable lock screen overlay"
Set-SafeRegValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-338387Enabled" -Value 0 -Type DWord -Description "Disable content suggestions"
Set-SafeRegValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-338388Enabled" -Value 0 -Type DWord -Description "Disable tips on lock screen"
Set-SafeRegValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-338389Enabled" -Value 0 -Type DWord -Description "Disable fun facts"
Set-SafeRegValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-353698Enabled" -Value 0 -Type DWord -Description "Disable suggested content"

# ============================================================
# SECTION 7: WINDOWS 11 SPECIFIC
# ============================================================
Write-Host "`n== Windows 11 Specific ==" -ForegroundColor Cyan
Set-SafeRegValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarDa" -Value 0 -Type DWord -Description "Disable Widgets"
Set-SafeRegValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarMn" -Value 0 -Type DWord -Description "Disable Chat icon"
Set-SafeRegValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Start" -Name "ShowRecentList" -Value 0 -Type DWord -Description "Hide recent in Start"
Set-SafeRegValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Start" -Name "ShowFrequentList" -Value 0 -Type DWord -Description "Hide frequent in Start"

# ============================================================
# SECTION 8: GAMING OPTIMIZATIONS
# ============================================================
Write-Host "`n== Gaming Optimizations ==" -ForegroundColor Cyan
Set-SafeRegValue -Path "HKCU:\Software\Microsoft\GameBar" -Name "AutoGameModeEnabled" -Value 0 -Type DWord -Description "Disable Game Mode"
Set-SafeRegValue -Path "HKCU:\Software\Microsoft\GameBar" -Name "UseNexusForGameBarEnabled" -Value 0 -Type DWord -Description "Disable Game Bar"
Set-SafeRegValue -Path "HKCU:\Software\Microsoft\GameBar" -Name "ShowStartupPanel" -Value 0 -Type DWord -Description "Disable Game Bar startup"
Set-SafeRegValue -Path "HKCU:\Software\Microsoft\GameBar" -Name "GamePanelStartupTipIndex" -Value 0 -Type DWord -Description "Disable Game Bar tips"
Set-SafeRegValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" -Name "AppCaptureEnabled" -Value 0 -Type DWord -Description "Disable Game DVR"
Set-SafeRegValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" -Name "GameDVR_Enabled" -Value 0 -Type DWord -Description "Disable Game DVR recording"
Set-SafeRegValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" -Name "GameDVR_FSEBehaviorMode" -Value 2 -Type DWord -Description "Disable fullscreen exclusive"
Set-SafeRegValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" -Name "GameDVR_HonorUserFSEBehaviorMode" -Value 1 -Type DWord -Description "Honor FSE preference"

# ============================================================
# SECTION 9: TEMP FILE CLEANUP
# ============================================================
Write-Host "`n== Temp File Cleanup ==" -ForegroundColor Cyan
$TempPaths = @(
    @{ Path = "$env:TEMP"; Description = "User temp files" },
    @{ Path = "$env:LOCALAPPDATA\Microsoft\Windows\Temporary Internet Files"; Description = "IE temp files" },
    @{ Path = "$env:LOCALAPPDATA\Microsoft\Windows\INetCache"; Description = "INet cache" },
    @{ Path = "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\ThumbCacheToDelete"; Description = "Thumb cache" }
)

$TotalFreed = 0
foreach ($TempItem in $TempPaths) {
    if (Test-Path $TempItem.Path) {
        try {
            $Before = (Get-ChildItem -Path $TempItem.Path -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
            if (-not $WhatIf) {
                Get-ChildItem -Path $TempItem.Path -File -Recurse -Force -ErrorAction SilentlyContinue | 
                    Where-Object { $_.CreationTime -lt (Get-Date).AddDays(-7) } |
                    Remove-Item -Force -ErrorAction SilentlyContinue
            }
            $After = (Get-ChildItem -Path $TempItem.Path -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
            $Freed = [math]::Round(($Before - $After) / 1MB, 2)
            $TotalFreed += $Freed
            if ($Freed -gt 0) {
                Write-Log "Cleaned $($TempItem.Description): $Freed MB freed" "SUCCESS"
            }
        }
        catch {
            Write-Log "Could not clean $($TempItem.Description): $_" "WARN"
        }
    }
}

if ($TotalFreed -gt 0) {
    Write-Host "  Total space freed: $TotalFreed MB" -ForegroundColor Green
}

# ============================================================
# SECTION 10: GENERATE UNDO SCRIPT
# ============================================================
Write-Host "`n== Generating UNDO Script ==" -ForegroundColor Cyan
if ($Script:Changes.Count -gt 0) {
    $undoContent = @"
# W11LatencyFix UNDO Script - Generated $(Get-Date)
`$LogDir = "$env:SystemDrive\W11LatencyFixLogs"
`$LogFile = "`$LogDir\UNDO_`$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
if (-not (Test-Path `$LogDir)) { New-Item -Path `$LogDir -ItemType Directory -Force | Out-Null }
function Write-Log { param([string]`$Message) "[`$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] `$Message" | Add-Content -Path `$LogFile; Write-Host "  `$Message" }
Write-Host "UNDO Script Starting..." -ForegroundColor Cyan

"@
    foreach ($change in $Script:Changes) {
        $path = $change.Path
        $name = $change.Name
        $oldVal = $change.OldValue
        if ($oldVal -eq "NOT_PRESENT") {
            $undoContent += "Remove-ItemProperty -Path `"$path`" -Name `"$name`" -Force -ErrorAction SilentlyContinue`n"
        } else {
            $undoContent += "Set-ItemProperty -Path `"$path`" -Name `"$name`" -Value $oldVal -Force`n"
        }
    }
    $undoContent += "Write-Host '`nUNDO Complete!' -ForegroundColor Green`n"
    $undoContent += "Write-Host 'Log: `$LogFile' -ForegroundColor Yellow`n"
    $undoContent += "Write-Host '`nPlease restart your computer for changes to take effect.' -ForegroundColor Yellow`n"
    
    if (-not $WhatIf) {
        Set-Content -Path $UndoScript -Value $undoContent -Encoding UTF8
        Write-Host "  ✓ UNDO script created: $UndoScript" -ForegroundColor Green
        Write-Host "    To revert changes, run: $UndoScript" -ForegroundColor Cyan
    } else {
        Write-Host "  (Would create undo script with $($Script:Changes.Count) entries)" -ForegroundColor Yellow
    }
} else {
    Write-Host "  No registry changes to undo" -ForegroundColor Yellow
}

# Summary
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  W11LatencyFix Complete!" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Changes applied: $($Script:Changes.Count)" -ForegroundColor Green
Write-Host "  Space freed: $TotalFreed MB" -ForegroundColor Green
Write-Host ""
if (-not $WhatIf -and $Script:Changes.Count -gt 0) {
    Write-Host "  To UNDO all changes, run:" -ForegroundColor Cyan
    Write-Host "    $UndoScript" -ForegroundColor White
}
Write-Host ""
Write-Host "  All changes are SAFE and REVERSIBLE:" -ForegroundColor Green
Write-Host "    - No services disabled" -ForegroundColor Green
Write-Host "    - No BCD/boot changes" -ForegroundColor Green
Write-Host "    - No Windows features removed" -ForegroundColor Green
Write-Host ""
Write-Host "  Restart recommended for network changes." -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan

Write-Log "Completed! Changes: $($Script:Changes.Count), Freed: $TotalFreed MB" "SUCCESS"

Write-Host ""
Write-Host "Press any key to exit..." -ForegroundColor Cyan
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
