#Requires -Version 5.1
param(
    [switch]$WhatIf,
    [switch]$AcceptTerms
)

# Terms Check
if (-not $WhatIf -and -not $AcceptTerms) {
    Write-Host "Please use -AcceptTerms to run" -ForegroundColor Yellow
    exit 1
}

# Admin Check & Elevation
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "Re-launching as Administrator..." -ForegroundColor Yellow
    $ArgString = '-NoProfile -ExecutionPolicy Bypass -File "' + $MyInvocation.MyCommand.Path + '"'
    if ($WhatIf) { $ArgString += ' -WhatIf' }
    if ($AcceptTerms) { $ArgString += ' -AcceptTerms' }
    Start-Process powershell.exe -ArgumentList $ArgString -Verb RunAs -Wait
    exit
}

# Initialize
$ScriptVersion = "1.0.0"
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
    Write-Host "  $Message" -ForegroundColor $color
}

function Set-SafeRegValue {
    param([string]$Path, [string]$Name, $Value, [string]$Type = "DWord", [string]$Description)
    
    try {
        if (-not (Test-Path $Path)) {
            if ($WhatIf) { Write-Host "  WOULD CREATE: $Path" -ForegroundColor Yellow; return }
            New-Item -Path $Path -Force | Out-Null
        }
        
        $OldVal = "NOT_PRESENT"
        try { $OldVal = (Get-ItemProperty -Path $Path -Name $Name -ErrorAction Stop).$Name } catch {}
        
        if ($OldVal -eq $Value) { Write-Log "$Name already set" "SKIP"; return }
        
        $Script:Changes += @{ Path = $Path; Name = $Name; OldValue = $OldVal; NewValue = $Value; Type = $Type }
        
        if ($WhatIf) { 
            Write-Host "  WOULD SET: $Name = $Value" -ForegroundColor Yellow
        } else {
            Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -Force
            Write-Log "Set $Name = $Value" "SUCCESS"
        }
    } catch {
        Write-Log "Failed: $Name - $_" "ERROR"
    }
}

# Banner
Clear-Host
Write-Host "W11LatencyFix v$ScriptVersion" -ForegroundColor Cyan
Write-Host ""
if ($WhatIf) { Write-Host "*** WHATIF MODE ***" -ForegroundColor Yellow }
Write-Log "Starting..."

# === SECTION 1: TCP OPTIMIZATIONS ===
Write-Host "`nTCP Network Optimizations" -ForegroundColor Cyan
Set-SafeRegValue "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "TcpNoDelay" 1 "DWord" "Disable Nagle"
Set-SafeRegValue "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "TcpDelAckTicks" 0 "DWord" "Disable delayed ACK"
Set-SafeRegValue "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "TCPMaxDataRetransmissions" 3 "DWord" "Fast retransmit"
Set-SafeRegValue "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "DefaultTTL" 64 "DWord" "TTL"
Set-SafeRegValue "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "EnablePMTUDiscovery" 1 "DWord" "PMTU discovery"
Set-SafeRegValue "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "GlobalMaxTcpWindowSize" 65535 "DWord" "Max window"
Set-SafeRegValue "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "SackOpts" 1 "DWord" "SACK"

# === SECTION 2: DNS ===
Write-Host "`nDNS Cache Optimization" -ForegroundColor Cyan
Set-SafeRegValue "HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters" "CacheHashTableBucketSize" 1 "DWord" "DNS bucket"
Set-SafeRegValue "HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters" "MaxCacheEntryTtlLimit" 86400 "DWord" "Max DNS TTL"

# === SECTION 3: VISUAL ===
Write-Host "`nVisual Performance" -ForegroundColor Cyan
Set-SafeRegValue "HKCU:\Control Panel\Desktop" "MenuShowDelay" "0" "String" "Fast menus"
Set-SafeRegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ListviewAlphaSelect" 0 "DWord" "Disable alpha"
Set-SafeRegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarAnimations" 0 "DWord" "Disable animations"

# === SECTION 4: EXPLORER ===
Write-Host "`nExplorer Settings" -ForegroundColor Cyan
Set-SafeRegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "HideFileExt" 0 "DWord" "Show extensions"
Set-SafeRegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "Hidden" 1 "DWord" "Show hidden files"
Set-SafeRegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "NavPaneExpandToCurrentFolder" 1 "DWord" "Expand nav pane"

# === SECTION 5: TASKBAR ===
Write-Host "`nTaskbar Cleanup" -ForegroundColor Cyan
Set-SafeRegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowTaskViewButton" 0 "DWord" "Hide Task View"
Set-SafeRegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowCortanaButton" 0 "DWord" "Hide Cortana"
Set-SafeRegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" "SearchboxTaskbarMode" 0 "DWord" "Hide search box"
Set-SafeRegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "PeopleBand" 0 "DWord" "Hide People bar"

# === SECTION 6: PRIVACY ===
Write-Host "`nPrivacy Settings" -ForegroundColor Cyan
Set-SafeRegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo" "Enabled" 0 "DWord" "Disable advertising ID"
Set-SafeRegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "Start_TrackProgs" 0 "DWord" "Disable app tracking"
Set-SafeRegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "RotatingLockScreenEnabled" 0 "DWord" "Disable lock screen ads"
Set-SafeRegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SubscribedContent-338387Enabled" 0 "DWord" "Disable tips"

# === SECTION 7: WINDOWS 11 ===
Write-Host "`nWindows 11 Specific" -ForegroundColor Cyan
Set-SafeRegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarDa" 0 "DWord" "Disable Widgets"
Set-SafeRegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarMn" 0 "DWord" "Disable Chat"
Set-SafeRegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Start" "ShowRecentList" 0 "DWord" "Hide recent"
Set-SafeRegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Start" "ShowFrequentList" 0 "DWord" "Hide frequent"

# === SECTION 8: GAMING ===
Write-Host "`nGaming Optimizations" -ForegroundColor Cyan
Set-SafeRegValue "HKCU:\Software\Microsoft\GameBar" "AutoGameModeEnabled" 0 "DWord" "Disable Game Mode"
Set-SafeRegValue "HKCU:\Software\Microsoft\GameBar" "UseNexusForGameBarEnabled" 0 "DWord" "Disable Game Bar"
Set-SafeRegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" "AppCaptureEnabled" 0 "DWord" "Disable Game DVR"
Set-SafeRegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" "GameDVR_Enabled" 0 "DWord" "Disable DVR recording"

# === UNDO SCRIPT ===
Write-Host "`nGenerating Undo Script" -ForegroundColor Cyan
if ($Script:Changes.Count -gt 0) {
    $undoContent = "# W11LatencyFix UNDO - Generated $(Get-Date)`n"
    $undoContent += '# Self-elevation' + "`n"
    $undoContent += '$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)' + "`n"
    $undoContent += 'if (-not $isAdmin) { Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs; exit }' + "`n"
    $undoContent += 'Write-Host "UNDO Script Starting..." -ForegroundColor Cyan' + "`n"
    foreach ($c in $Script:Changes) {
        if ($c.OldValue -eq "NOT_PRESENT") {
            $undoContent += 'try { Remove-ItemProperty -Path "' + $c.Path + '" -Name "' + $c.Name + '" -Force -ErrorAction SilentlyContinue } catch {}' + "`n"
        } else {
            $undoContent += 'try { Set-ItemProperty -Path "' + $c.Path + '" -Name "' + $c.Name + '" -Value ' + $c.OldValue + ' -Force } catch {}' + "`n"
        }
    }
    $undoContent += 'Write-Host "`nUNDO Complete!" -ForegroundColor Green' + "`n"
    $undoContent += 'Write-Host "Press any key to exit..." -ForegroundColor Yellow' + "`n"
    $undoContent += '$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")' + "`n"
    if (-not $WhatIf) {
        Set-Content -Path $UndoScript -Value $undoContent -Encoding UTF8
        Write-Host "  Created: $UndoScript" -ForegroundColor Green
    } else {
        Write-Host "  Would create undo script with $($Script:Changes.Count) entries" -ForegroundColor Yellow
    }
} else {
    Write-Host "  No changes to undo" -ForegroundColor Yellow
}

# Summary
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  COMPLETE: $($Script:Changes.Count) changes applied" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
if ($WhatIf) {
    Write-Host "  This was WHATIF mode - no changes made" -ForegroundColor Yellow
    Write-Host "  Run without -WhatIf to apply changes" -ForegroundColor Cyan
} else {
    Write-Host "  Changes saved to: $LogFile" -ForegroundColor Cyan
    Write-Host "  To UNDO: $UndoScript" -ForegroundColor Cyan
}
Write-Host ""
Write-Host "  Restart recommended for network changes" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan
Write-Log "Completed with $($Script:Changes.Count) changes"

Write-Host ""
Write-Host "Press any key to exit..." -ForegroundColor Cyan
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
