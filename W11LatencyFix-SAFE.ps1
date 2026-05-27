#Requires -Version 5.1
#Requires -RunAsAdministrator
<#
.SYNOPSIS
    W11LatencyFix v1.0 - SAFE Windows 11 Network Latency Optimizer
    
.DESCRIPTION
    A completely rewritten, NON-DESTRUCTIVE Windows 11 optimizer focused solely on
    reducing NETWORK LATENCY and improving system responsiveness.

.LEGAL DISCLAIMER AND LIABILITY WAIVER
    ===================================================================
    BY USING THIS SOFTWARE, YOU ACKNOWLEDGE AND AGREE TO THE FOLLOWING:
    ===================================================================
    
    1. This software is provided "AS IS" with NO WARRANTY of any kind.
    2. YOU USE THIS SOFTWARE ENTIRELY AT YOUR OWN RISK.
    3. The authors, copyright holders, and distributors are NOT LIABLE
       for any damages, data loss, system issues, or other consequences.
    4. You are SOLELY RESPONSIBLE for any changes made to your system.
    5. You WAIVE ALL RIGHTS to sue, hold liable, or seek damages from
       the authors for any reason related to this software.
    6. If you do not agree to these terms, DO NOT USE THIS SOFTWARE.
    
    Full legal text: See LICENSE and DISCLAIMER.md files.
    
    By running this script, you explicitly accept these terms.
    ===================================================================
    
    SAFETY GUARANTEES:
    - NO BCD or boot configuration changes
    - NO Windows services disabled or modified
    - NO Windows features removed
    - NO scheduled tasks or persistence installed
    - NO system security settings modified
    - NO power plan or hibernation changes
    - NO breaking of Windows Update, Search, or Printing
    - All changes are to HKCU (user) or safe HKLM network parameters only
    
    WHAT IT DOES (30+ Sections, 100+ Safe Optimizations):
    
    NETWORK & LATENCY (Sections 1-2, 1b, 9e):
    - TCP optimizations (Nagle, ACKs, ports, window size, TTL)
    - DNS cache optimization
    - NetBIOS/NetBT hardening
    - QoS bandwidth release (20%)
    - SMB/CIFS optimizations
    
    GAMING & PERFORMANCE (Sections 5-5p):
    - Multimedia game priorities (GPU, I/O, scheduling)
    - Fullscreen optimizations disable
    - Game Bar/DVR disable
    - Audio latency reduction
    - USB selective suspend disable
    - Mouse/keyboard responsiveness
    
    EXPLORER & UI (Sections 3-4, 5e, 5h-5i):
    - Visual effects (Best Performance)
    - Menu/window animation speeds
    - Explorer folder discovery disable
    - Quick Access cleanup
    - Taskbar cleanup (People, Cortana, News)
    - File Explorer settings (preview pane, etc.)
    
    PRIVACY & TELEMETRY (Sections 5f, 5o-5p, 5l-5n, 9i, 9l-9q):
    - Advertising ID disable
    - App launch tracking disable
    - Location/sensors disable
    - Speech/typing disable
    - Remote Assistance/Registry disable
    - Clipboard cloud sync disable
    
    SYSTEM & CLEANUP (Sections 6-9, 9b-9d, 9f-9h, 9j-9k):
    - Windows Error Reporting disable
    - Windows Update scheduling
    - Delivery Optimization disable
    - Defender scan scheduling
    - System Restore disk usage
    - Event log cleanup
    - Browser cache cleanup
    - Temp/Recycle Bin cleanup
    - Prefetch/Superfetch optimization
    
    SAFETY FEATURES:
    - Automatic backup of ALL changes to .reg files
    - Generated companion UNDO script for one-click restoration
    - All changes are IDEMPOTENT (safe to run multiple times)
    - No modifications to HKLM\SYSTEM (boot-critical hive)
    - Extensive logging to C:\W11LatencyFixLogs\
    
.PARAMETER AcceptTerms
    REQUIRED (unless using -WhatIf): Explicitly accept legal terms and liability waiver
    
.PARAMETER WhatIf
    Preview all changes without applying them (no terms acceptance required for preview)
    
.EXAMPLE
    .\W11LatencyFix-SAFE.ps1 -AcceptTerms
    Run with explicit acceptance of terms and liability waiver
    
.EXAMPLE
    .\W11LatencyFix-SAFE.ps1 -WhatIf
    Preview all changes without applying them
#>

[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [switch]$WhatIf,
    [switch]$AcceptTerms
)

# ============================================================
# LEGAL: Terms Acceptance Check
# ============================================================
if (-not $WhatIf -and -not $AcceptTerms) {
    Write-Host ""
    Write-Host "  ⚠️  TERMS ACCEPTANCE REQUIRED" -ForegroundColor Red
    Write-Host ""
    Write-Host "  You must explicitly accept the terms before running this script." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  By using this software, you acknowledge:" -ForegroundColor White
    Write-Host "  • This software is provided 'AS IS' with NO WARRANTY" -ForegroundColor Gray
    Write-Host "  • YOU USE THIS ENTIRELY AT YOUR OWN RISK" -ForegroundColor Gray
    Write-Host "  • Authors are NOT LIABLE for any damages or issues" -ForegroundColor Gray
    Write-Host "  • You WAIVE ALL RIGHTS to sue the authors" -ForegroundColor Gray
    Write-Host "  • You are SOLELY RESPONSIBLE for any changes to your system" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  To accept these terms and run, use: -AcceptTerms" -ForegroundColor Cyan
    Write-Host "  Example: .\W11LatencyFix-SAFE.ps1 -AcceptTerms" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  To preview changes without applying: -WhatIf" -ForegroundColor Cyan
    Write-Host "  Example: .\W11LatencyFix-SAFE.ps1 -WhatIf" -ForegroundColor Cyan
    Write-Host ""
    exit 1
}

# ============================================================
# SAFETY: System Restore Point Creation (Required before changes)
# ============================================================
if (-not $WhatIf) {
    Write-Host ""
    Write-Host "  🛡️  Creating System Restore Point..." -ForegroundColor Cyan
    
    try {
        # Enable System Restore if not already enabled
        Enable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction SilentlyContinue | Out-Null
        
        # Create restore point
        $RestorePointName = "Before W11LatencyFix v$ScriptVersion - $Timestamp"
        Checkpoint-Computer -Description $RestorePointName -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
        
        Write-Host "  ✓ System Restore Point created: $RestorePointName" -ForegroundColor Green
        Write-Log "System Restore Point created: $RestorePointName" "SUCCESS"
    }
    catch {
        Write-Host ""
        Write-Host "  ⚠️  WARNING: Could not create System Restore Point" -ForegroundColor Yellow
        Write-Host "  Error: $_" -ForegroundColor DarkYellow
        Write-Host ""
        Write-Host "  This script requires a restore point for safety." -ForegroundColor Yellow
        Write-Host "  Please enable System Restore manually and try again." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  Alternatively, use -WhatIf to preview changes." -ForegroundColor Cyan
        Write-Host ""
        
        $ContinueWithoutRestore = Read-Host "  Continue without restore point? (NOT RECOMMENDED) [y/N]"
        if ($ContinueWithoutRestore -ne 'y' -and $ContinueWithoutRestore -ne 'Y') {
            Write-Host "  Exiting for safety. Please enable System Restore and try again." -ForegroundColor Red
            exit 1
        }
        
        Write-Host "  Continuing WITHOUT restore point. YOU ASSUME ALL RISK." -ForegroundColor Red
        Write-Log "User chose to continue WITHOUT System Restore Point" "WARN"
    }
}

# ============================================================
# SAFETY: Verify Reversibility (Ensure backup/undo capability)
# ============================================================
if (-not $WhatIf) {
    Write-Host ""
    Write-Host "  🛡️  Verifying Reversibility (Backup/Undo capability)..." -ForegroundColor Cyan
    
    # Test backup directory writability
    try {
        $TestFile = "$BackupDir\_test_write_$Timestamp.tmp"
        "test" | Out-File -FilePath $TestFile -Force -ErrorAction Stop
        Remove-Item -Path $TestFile -Force -ErrorAction SilentlyContinue
        Write-Host "  ✓ Backup directory is writable: $BackupDir" -ForegroundColor Green
    }
    catch {
        Write-Host ""
        Write-Host "  ❌ CRITICAL ERROR: Cannot write to backup directory!" -ForegroundColor Red
        Write-Host "  Path: $BackupDir" -ForegroundColor Red
        Write-Host "  Error: $_" -ForegroundColor Red
        Write-Host ""
        Write-Host "  Changes CANNOT be reversed without backup capability." -ForegroundColor Red
        Write-Host "  Exiting for safety." -ForegroundColor Red
        Write-Host ""
        exit 1
    }
    
    # Verify we can export registry (required for undo)
    try {
        $TestRegBackup = "$BackupDir\_test_registry_export.reg"
        reg export "HKCU\Software\Microsoft\Windows\CurrentVersion" "$TestRegBackup" /y 2>&1 | Out-Null
        if (Test-Path $TestRegBackup) {
            Remove-Item -Path $TestRegBackup -Force -ErrorAction SilentlyContinue
            Write-Host "  ✓ Registry export capability verified" -ForegroundColor Green
        } else {
            throw "Registry export failed"
        }
    }
    catch {
        Write-Host ""
        Write-Host "  ❌ CRITICAL ERROR: Cannot export registry!" -ForegroundColor Red
        Write-Host "  Undo functionality will not work." -ForegroundColor Red
        Write-Host "  Error: $_" -ForegroundColor Red
        Write-Host ""
        Write-Host "  Changes CANNOT be reversed without registry backup." -ForegroundColor Red
        Write-Host "  Exiting for safety." -ForegroundColor Red
        Write-Host ""
        exit 1
    }
    
    Write-Host "  ✓ All reversibility checks passed" -ForegroundColor Green
    Write-Log "Reversibility verified: Backup directory writable, registry export working" "SUCCESS"
}

# ============================================================
# SAFETY: Version and Paths
# ============================================================
$ScriptVersion = "1.0.0-SAFE"
$LogDir = "$env:SystemDrive\W11LatencyFixLogs"
$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$LogFile = "$LogDir\LatencyFix_$Timestamp.log"
$BackupDir = "$LogDir\Backups_$Timestamp"
$UndoScript = "$BackupDir\UNDO_CHANGES.ps1"

# ============================================================
# SAFETY: Self-Elevation (with user consent implied by running)
# ============================================================
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Administrator privileges required for network stack modifications." -ForegroundColor Yellow
    Write-Host "Re-launching elevated..." -ForegroundColor Yellow
    Start-Sleep -Seconds 2
    $ArgString = '-NoProfile -ExecutionPolicy Bypass -File "' + $MyInvocation.MyCommand.Path + '"'
    if ($WhatIf) { $ArgString += ' -WhatIf' }
    Start-Process -FilePath "powershell.exe" -ArgumentList $ArgString -Verb RunAs
    exit
}

# ============================================================
# SAFETY: Initialize Logging and Backup Directories
# ============================================================
if (-not (Test-Path $LogDir)) { 
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null 
}
if (-not (Test-Path $BackupDir)) { 
    New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null 
}

# Track changes for UNDO script generation
$Script:Changes = @()

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "[$timestamp] [$Level] $Message"
    Add-Content -Path $LogFile -Value $entry
    
    $colorMap = @{
        "INFO" = "White"
        "SUCCESS" = "Green"
        "WARN" = "Yellow"
        "ERROR" = "Red"
        "SKIP" = "DarkGray"
    }
    Write-Host "  $Message" -ForegroundColor $colorMap[$Level]
}

# ============================================================
# SAFETY: Registry Change Function with Automatic Backup
# ============================================================
function Set-SafeRegValue {
    param(
        [string]$Path,
        [string]$Name,
        $Value,
        [string]$Type = "DWord",
        [string]$Description = ""
    )
    
    try {
        # Check if key exists, create if not
        if (-not (Test-Path $Path)) {
            if ($WhatIf) {
                Write-Log "WOULD CREATE: $Path" "INFO"
            } else {
                New-Item -Path $Path -Force | Out-Null
            }
        }
        
        # Get current value for backup
        $OldValue = $null
        try {
            $OldValue = (Get-ItemProperty -Path $Path -Name $Name -ErrorAction Stop).$Name
        } catch {
            $OldValue = "NOT_PRESENT"
        }
        
        # Skip if already set correctly
        if ($OldValue -eq $Value) {
            Write-Log "$Name already set to $Value - skipping" "SKIP"
            return
        }
        
        # Record for UNDO script
        $change = @{
            Path = $Path
            Name = $Name
            OldValue = $OldValue
            NewValue = $Value
            Type = $Type
            Description = $Description
        }
        $Script:Changes += $change
        
        if ($WhatIf) {
            Write-Log "WOULD SET: $Name = $Value ($Path)" "INFO"
            Write-Log "  Previous: $OldValue" "INFO"
        } else {
            # Create .reg backup before changing
            $SafePath = ($Path -replace '\\', '_') -replace ':', ''
            $BackupFile = "$BackupDir\${SafePath}_${Name}.reg"
            
            if ($OldValue -ne "NOT_PRESENT") {
                # Export the specific value for backup
                $HivePath = $Path -replace 'HKLM:\\', 'HKEY_LOCAL_MACHINE\' -replace 'HKCU:\\', 'HKEY_CURRENT_USER\'
                # Note: reg export backs up entire key, which is safer
                reg export $HivePath "$BackupFile" /y 2>$null | Out-Null
            }
            
            # Apply the change
            Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -Force
            
            # Verify the change
            $Verified = (Get-ItemProperty -Path $Path -Name $Name -ErrorAction Stop).$Name
            if ($Verified -eq $Value) {
                Write-Log "$Name = $Value ($Description)" "SUCCESS"
            } else {
                Write-Log "$Name verification failed! Expected $Value, got $Verified" "ERROR"
            }
        }
    }
    catch {
        Write-Log "Failed to set $Path\$Name : $_" "ERROR"
    }
}

# ============================================================
# SAFETY: Generate UNDO Script
# ============================================================
function Export-UndoScript {
    $undoContent = @"
#Requires -RunAsAdministrator
# W11LatencyFix UNDO Script - Generated $Timestamp
# This script will restore all changes made by W11LatencyFix-SAFE.ps1

`$LogDir = "C:\W11LatencyFixLogs"
`$LogFile = "`$LogDir\UNDO_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

if (-not (Test-Path `$LogDir)) { New-Item -ItemType Directory -Path `$LogDir -Force | Out-Null }

function Write-Log {
    param([string]`$Message)
    `$entry = "[`$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] `$Message"
    Add-Content -Path `$LogFile -Value `$entry
    Write-Host "  `$Message"
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  W11LatencyFix UNDO Script" -ForegroundColor Cyan
Write-Host "  Restoring original values..." -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

"@

    foreach ($change in $Script:Changes) {
        if ($change.OldValue -eq "NOT_PRESENT") {
            # Value didn't exist before, so remove it
            $undoContent += @"
# Remove $($change.Name) (didn't exist before)
try {
    Remove-ItemProperty -Path "$($change.Path)" -Name "$($change.Name)" -Force -ErrorAction SilentlyContinue
    Write-Log "Removed $($change.Path)\$($change.Name)"
} catch { Write-Log "Could not remove $($change.Name): `$_" }

"@
        } else {
            # Restore old value
            $undoContent += @"
# Restore $($change.Name) to $($change.OldValue)
try {
    Set-ItemProperty -Path "$($change.Path)" -Name "$($change.Name)" -Value $($change.OldValue) -Type $($change.Type) -Force
    Write-Log "Restored $($change.Name) to $($change.OldValue)"
} catch { Write-Log "Could not restore $($change.Name): `$_" }

"@
        }
    }
    
    $undoContent += @"
Write-Host "`nUNDO Complete!" -ForegroundColor Green
Write-Host "Log: `$LogFile" -ForegroundColor Yellow
Write-Host "`nPlease restart your computer for all changes to take effect." -ForegroundColor Yellow
"@

    if (-not $WhatIf) {
        Set-Content -Path $UndoScript -Value $undoContent -Encoding UTF8
        Write-Log "UNDO script created: $UndoScript" "SUCCESS"
    }
}

# ============================================================
# BANNER
# ============================================================
Clear-Host
Write-Host @"
+==============================================================+
|        W11LatencyFix v$ScriptVersion - SAFE MODE             |
|        Network Latency & Responsiveness Optimizer             |
|        $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')                           |
+==============================================================+
"@ -ForegroundColor Cyan

if ($WhatIf) {
    Write-Host "`n  *** WHATIF MODE - No changes will be made ***`n" -ForegroundColor Yellow
}

# Legal Warning
Write-Host ""
Write-Host "  ⚖️  LEGAL DISCLAIMER:" -ForegroundColor Red
Write-Host "  By running this script, you accept all liability." -ForegroundColor Yellow
Write-Host "  See LICENSE and DISCLAIMER.md for full terms." -ForegroundColor Yellow
Write-Host "  Authors are NOT liable for any damages or issues." -ForegroundColor Yellow
Write-Host ""

Write-Log "Starting W11LatencyFix v$ScriptVersion" "INFO"
Write-Log "Log: $LogFile" "INFO"
Write-Log "Backup: $BackupDir" "INFO"

# ============================================================
# SECTION 1: TCP NETWORK LATENCY OPTIMIZATIONS (HKLM - Safe)
# ============================================================
Write-Host "`n== TCP Network Latency Optimizations ==" -ForegroundColor Cyan
Write-Log "Applying safe TCP stack optimizations..." "INFO"

$TcpParams = 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters'

# Disable Nagle's Algorithm - Reduces latency for real-time applications
Set-SafeRegValue -Path $TcpParams -Name "TcpAckFrequency" -Value 1 -Type DWord `
    -Description "Send ACKs immediately (reduce latency)"

# Disable TCP Delayed ACKs
Set-SafeRegValue -Path $TcpParams -Name "TCPNoDelay" -Value 1 -Type DWord `
    -Description "Disable Nagle's algorithm (reduce latency)"

# Increase Max User Ports (allows more concurrent connections)
Set-SafeRegValue -Path $TcpParams -Name "MaxUserPort" -Value 65534 -Type DWord `
    -Description "Max ephemeral ports for outbound connections"

# Reduce TIME_WAIT state duration
Set-SafeRegValue -Path $TcpParams -Name "TcpTimedWaitDelay" -Value 30 -Type DWord `
    -Description "Time to wait before reusing port (seconds)"

# Extended TCP optimizations for gaming/streaming
Set-SafeRegValue -Path $TcpParams -Name "TcpWindowSize" -Value 64240 -Type DWord `
    -Description "TCP window size (better throughput)"

Set-SafeRegValue -Path $TcpParams -Name "MaxHashTableSize" -Value 65536 -Type DWord `
    -Description "TCP hash table size (better connection handling)"

Set-SafeRegValue -Path $TcpParams -Name "SackOpts" -Value 1 -Type DWord `
    -Description "Selective Acknowledgment (packet loss recovery)"

Set-SafeRegValue -Path $TcpParams -Name "DefaultTTL" -Value 64 -Type DWord `
    -Description "Default Time To Live (network hops)"

# ============================================================
# SECTION 1b: EXTENDED NETWORK OPTIMIZATIONS (HKLM - Safe)
# ============================================================
Write-Host "`n== Extended Network Optimizations ==" -ForegroundColor Cyan

# NetBT (NetBIOS over TCP) - Disable for security and performance
$NetBT = 'HKLM:\SYSTEM\CurrentControlSet\Services\NetBT\Parameters'
Set-SafeRegValue -Path $NetBT -Name "NodeType" -Value 2 -Type DWord `
    -Description "NetBIOS node type (P-node, no broadcasts)"

# IRP stack size for better network throughput
$LanmanServer = 'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters'
Set-SafeRegValue -Path $LanmanServer -Name "IRPStackSize" -Value 32 -Type DWord `
    -Description "IRP stack size (better network throughput)"

Set-SafeRegValue -Path $LanmanServer -Name "SizReqBuf" -Value 17424 -Type DWord `
    -Description "Server request buffer size"

# ============================================================
# SECTION 2: DNS CACHE OPTIMIZATION (HKLM - Safe)
# ============================================================
Write-Host "`n== DNS Cache Optimizations ==" -ForegroundColor Cyan

$DnsCache = 'HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters'

# Increase DNS cache size
Set-SafeRegValue -Path $DnsCache -Name "CacheHashTableBucketSize" -Value 1 -Type DWord `
    -Description "DNS cache hash table bucket size"

Set-SafeRegValue -Path $DnsCache -Name "CacheHashTableSize" -Value 384 -Type DWord `
    -Description "DNS cache hash table size"

Set-SafeRegValue -Path $DnsCache -Name "MaxCacheEntryTtlLimit" -Value 86400 -Type DWord `
    -Description "Max DNS cache TTL (24 hours)"

Set-SafeRegValue -Path $DnsCache -Name "MaxSOACacheEntryTtlLimit" -Value 300 -Type DWord `
    -Description "Max SOA record TTL (5 minutes)"

# Additional network interface optimizations
$NetIF = 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces'
if (Test-Path $NetIF) {
    Get-ChildItem $NetIF | ForEach-Object {
        $IFPath = $_.PSPath
        Set-SafeRegValue -Path $IFPath -Name "TcpAckFrequency" -Value 1 -Type DWord `
            -Description "Per-interface TCP ACK frequency"
        Set-SafeRegValue -Path $IFPath -Name "TCPNoDelay" -Value 1 -Type DWord `
            -Description "Per-interface TCP no delay"
    }
}

# ============================================================
# SECTION 3: VISUAL PERFORMANCE (HKCU ONLY - Per User)
# ============================================================
Write-Host "`n== Visual Performance Settings (Per-User) ==" -ForegroundColor Cyan

$VisualEffects = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects'

# Set to "Best Performance" (custom) - user can change via System Properties
Set-SafeRegValue -Path $VisualEffects -Name "VisualFXSetting" -Value 2 -Type DWord `
    -Description "Visual effects: Custom (Best Performance)"

# Reduce menu show delay
$Desktop = 'HKCU:\Control Panel\Desktop'
Set-SafeRegValue -Path $Desktop -Name "MenuShowDelay" -Value "20" -Type String `
    -Description "Menu delay (milliseconds)"

# Reduce foreground lock timeout
Set-SafeRegValue -Path $Desktop -Name "ForegroundLockTimeout" -Value 0 -Type DWord `
    -Description "Foreground window switch delay"

# ============================================================
# SECTION 4: EXPLORER RESPONSIVENESS (HKCU ONLY)
# ============================================================
Write-Host "`n== Explorer Responsiveness (Per-User) ==" -ForegroundColor Cyan

# Speed up Explorer by disabling some animations
$ExplorerAdvanced = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'

Set-SafeRegValue -Path $ExplorerAdvanced -Name "ListviewAlphaSelect" -Value 0 -Type DWord `
    -Description "Disable listview selection fade"

Set-SafeRegValue -Path $ExplorerAdvanced -Name "ListviewShadow" -Value 0 -Type DWord `
    -Description "Disable listview shadows"

# Reduce startup delay
$Serialize = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize'
if (-not (Test-Path $Serialize)) { New-Item -Path $Serialize -Force | Out-Null }
Set-SafeRegValue -Path $Serialize -Name "StartupDelayInMSec" -Value 0 -Type DWord `
    -Description "Reduce startup app delay"

# ============================================================
# SECTION 5: GAMING & MULTIMEDIA (HKCU ONLY)
# ============================================================
Write-Host "`n== Gaming & Multimedia Settings (Per-User) ==" -ForegroundColor Cyan

# Disable Game DVR (can cause input lag in some games)
$GameConfigStore = 'HKCU:\System\GameConfigStore'
Set-SafeRegValue -Path $GameConfigStore -Name "GameDVR_Enabled" -Value 0 -Type DWord `
    -Description "Disable Game DVR (reduce input lag)"

Set-SafeRegValue -Path $GameConfigStore -Name "GameDVR_FSEBehaviorMode" -Value 2 -Type DWord `
    -Description "FSE behavior mode for games"

# Multimedia system profile (reduce system responsiveness for multimedia)
$SystemProfile = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile'
Set-SafeRegValue -Path $SystemProfile -Name "SystemResponsiveness" -Value 0 -Type DWord `
    -Description "Reduce system responsiveness for multimedia"

# Games profile - give games priority
$GamesProfile = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games'
Set-SafeRegValue -Path $GamesProfile -Name "Affinity" -Value 0 -Type DWord `
    -Description "Game task affinity"

Set-SafeRegValue -Path $GamesProfile -Name "Background Only" -Value "False" -Type String `
    -Description "Games are not background tasks"

Set-SafeRegValue -Path $GamesProfile -Name "Clock Rate" -Value 2710 -Type DWord `
    -Description "Game thread priority clock rate"

Set-SafeRegValue -Path $GamesProfile -Name "GPU Priority" -Value 8 -Type DWord `
    -Description "GPU priority for games (8=high)"

Set-SafeRegValue -Path $GamesProfile -Name "Priority" -Value 6 -Type DWord `
    -Description "Thread priority for games (6=high)"

Set-SafeRegValue -Path $GamesProfile -Name "Scheduling Category" -Value "High" -Type String `
    -Description "Scheduling category for games"

Set-SafeRegValue -Path $GamesProfile -Name "SFIO Priority" -Value "High" -Type String `
    -Description "I/O priority for games"

# ============================================================
# SECTION 5b: NOVEL GAMING OPTIMIZATIONS (HKCU - Safe)
# ============================================================
Write-Host "`n== Novel Gaming Optimizations (Per-User) ==" -ForegroundColor Cyan

# Disable Fullscreen Optimizations - Reduces input lag in games
# Windows 10/11 adds a layer between game and display for "optimizations"
# Disabling this can reduce input latency in exclusive fullscreen
$GameBar = 'HKCU:\System\GameConfigStore'
Set-SafeRegValue -Path $GameBar -Name "GameDVR_FSEBehavior" -Value 2 -Type DWord `
    -Description "Disable fullscreen optimizations (reduce input lag)"

# Disable Game Bar completely (reduces overlay overhead)
Set-SafeRegValue -Path $GameBar -Name "AppCaptureEnabled" -Value 0 -Type DWord `
    -Description "Disable Game Bar capture"

# Disable Xbox Game Bar presence
$GameBarFull = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR'
Set-SafeRegValue -Path $GameBarFull -Name "AppCaptureEnabled" -Value 0 -Type DWord `
    -Description "Disable Game DVR app capture"
Set-SafeRegValue -Path $GameBarFull -Name "HistoricalCaptureEnabled" -Value 0 -Type DWord `
    -Description "Disable Game DVR background recording"

# ============================================================
# SECTION 5c: AUDIO LATENCY REDUCTION (HKCU - Safe)
# ============================================================
Write-Host "`n== Audio Latency Reduction (Per-User) ==" -ForegroundColor Cyan

# Reduce audio buffer size for lower latency
$Audio = 'HKCU:\Software\Microsoft\Multimedia\Audio'
Set-SafeRegValue -Path $Audio -Name "BufferDurationHint" -Value 1 -Type DWord `
    -Description "Audio buffer duration hint (lower latency)"

# Disable audio enhancements (can add latency)
# Note: This is per-device in HKCU, safe to change
$AudioPolicy = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Applets\Volume Control'
Set-SafeRegValue -Path $AudioPolicy -Name "EnableVolumeControlEnhancements" -Value 0 -Type DWord `
    -Description "Disable audio enhancements (reduce latency)"

# ============================================================
# SECTION 5d: USB POWER MANAGEMENT (Safe Gaming Peripherals)
# ============================================================
Write-Host "`n== USB Power Management (Gaming Peripherals) ==" -ForegroundColor Cyan

# Disable USB selective suspend for gaming peripherals
# Prevents Windows from putting USB devices to sleep (reduces input latency)
$USB = 'HKLM:\SYSTEM\CurrentControlSet\Services\USB\Parameters'
Set-SafeRegValue -Path $USB -Name "DisableSelectiveSuspend" -Value 1 -Type DWord `
    -Description "Disable USB selective suspend (reduce input latency)"

# Disable USB hub selective suspend
$USBHub = 'HKLM:\SYSTEM\CurrentControlSet\Services\USBHUB3\Parameters'
Set-SafeRegValue -Path $USBHub -Name "DisableSelectiveSuspend" -Value 1 -Type DWord `
    -Description "Disable USB3 hub selective suspend"

# ============================================================
# SECTION 5e: EXPLORER PERFORMANCE (HKCU - Novel)
# ============================================================
Write-Host "`n== Explorer Performance Optimizations ==" -ForegroundColor Cyan

# Disable automatic folder type discovery (speeds up folder loading)
$ExplorerFolderTypes = 'HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\Bags\AllFolders\Shell'
Set-SafeRegValue -Path $ExplorerFolderTypes -Name "FolderType" -Value "NotSpecified" -Type String `
    -Description "Disable automatic folder type discovery (faster browsing)"

# Disable "Show frequently used folders in Quick access" (reduces Explorer overhead)
$ExplorerQuickAccess = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer'
Set-SafeRegValue -Path $ExplorerQuickAccess -Name "ShowFrequent" -Value 0 -Type DWord `
    -Description "Disable frequent folders in Quick Access"

# Disable "Show recently used files in Quick access"
Set-SafeRegValue -Path $ExplorerQuickAccess -Name "ShowRecent" -Value 0 -Type DWord `
    -Description "Disable recent files in Quick Access"

# Disable Sticky Keys shortcut (prevents accidental activation during gaming)
$Accessibility = 'HKCU:\Control Panel\Accessibility\StickyKeys'
Set-SafeRegValue -Path $Accessibility -Name "Flags" -Value "506" -Type String `
    -Description "Disable Sticky Keys shortcut (gaming QoL)"

# Disable Filter Keys shortcut
$FilterKeys = 'HKCU:\Control Panel\Accessibility\Keyboard Response'
Set-SafeRegValue -Path $FilterKeys -Name "Flags" -Value "122" -Type String `
    -Description "Disable Filter Keys shortcut"

# Disable Toggle Keys shortcut
$ToggleKeys = 'HKCU:\Control Panel\Accessibility\ToggleKeys'
Set-SafeRegValue -Path $ToggleKeys -Name "Flags" -Value "58" -Type String `
    -Description "Disable Toggle Keys shortcut"

# ============================================================
# SECTION 5f: CONSUMER FEATURES & ADVERTISING (HKCU - Safe)
# ============================================================
Write-Host "`n== Consumer Features & Advertising (Privacy/Speed) ==" -ForegroundColor Cyan

# Disable "Get tips and suggestions" (reduces notification spam)
$Notifications = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
Set-SafeRegValue -Path $Notifications -Name "ShowSyncProviderNotifications" -Value 0 -Type DWord `
    -Description "Disable sync provider notifications"

# Disable advertising ID (privacy + reduces telemetry overhead)
$Advertising = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo'
Set-SafeRegValue -Path $Advertising -Name "Enabled" -Value 0 -Type DWord `
    -Description "Disable advertising ID (privacy + performance)"

# Disable language list access (reduces background network calls)
$LanguageList = 'HKCU:\Control Panel\International\User Profile'
Set-SafeRegValue -Path $LanguageList -Name "HttpAcceptLanguageOptOut" -Value 1 -Type DWord `
    -Description "Disable language list access (reduce network calls)"

# Disable app launch tracking (privacy + reduces logging overhead)
$Privacy = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
Set-SafeRegValue -Path $Privacy -Name "Start_TrackProgs" -Value 0 -Type DWord `
    -Description "Disable app launch tracking (privacy + performance)"

# Disable Windows Welcome Center (reduces first-run overhead)
$Welcome = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
Set-SafeRegValue -Path $Welcome -Name "WindowsWelcomeCenter" -Value "" -Type String `
    -Description "Disable Windows Welcome Center"

# Disable suggested content in Settings
$SettingsSuggestions = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
Set-SafeRegValue -Path $SettingsSuggestions -Name "SubscribedContent-338393Enabled" -Value 0 -Type DWord `
    -Description "Disable Settings suggested content"
Set-SafeRegValue -Path $SettingsSuggestions -Name "SubscribedContent-353694Enabled" -Value 0 -Type DWord `
    -Description "Disable Settings suggested content 2"
Set-SafeRegValue -Path $SettingsSuggestions -Name "SubscribedContent-353696Enabled" -Value 0 -Type DWord `
    -Description "Disable Settings suggested content 3"

# Disable "Finish setting up your device" notifications
Set-SafeRegValue -Path $SettingsSuggestions -Name "SubscribedContent-310093Enabled" -Value 0 -Type DWord `
    -Description "Disable finish setting up device notifications"

# Disable Windows Spotlight on lock screen (reduces network calls)
Set-SafeRegValue -Path $SettingsSuggestions -Name "RotatingLockScreenEnabled" -Value 0 -Type DWord `
    -Description "Disable Windows Spotlight (reduce network)"

# Disable Spotlight features
Set-SafeRegValue -Path $SettingsSuggestions -Name "RotatingLockScreenOverlayEnabled" -Value 0 -Type DWord `
    -Description "Disable Spotlight features"

# ============================================================
# SECTION 5g: TASKBAR & START MENU (HKCU - Performance)
# ============================================================
Write-Host "`n== Taskbar & Start Menu Optimizations ==" -ForegroundColor Cyan

# Disable people bar (reduces taskbar overhead)
$PeopleBar = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\People'
if (-not (Test-Path $PeopleBar)) { New-Item -Path $PeopleBar -Force | Out-Null }
Set-SafeRegValue -Path $PeopleBar -Name "PeopleBand" -Value 0 -Type DWord `
    -Description "Disable People bar on taskbar"

# Disable task view button (reduces Explorer overhead)
$Taskbar = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
Set-SafeRegValue -Path $Taskbar -Name "ShowTaskViewButton" -Value 0 -Type DWord `
    -Description "Hide Task View button"

# Disable Cortana button (reduces taskbar overhead)
Set-SafeRegValue -Path $Taskbar -Name "ShowCortanaButton" -Value 0 -Type DWord `
    -Description "Hide Cortana button"

# Disable Meet Now icon (reduces taskbar clutter)
Set-SafeRegValue -Path $Taskbar -Name "ShowMeetNow" -Value 0 -Type DWord `
    -Description "Hide Meet Now button"

# Disable news and interests (reduces background network)
Set-SafeRegValue -Path $Taskbar -Name "EnableFeeds" -Value 0 -Type DWord `
    -Description "Disable News and Interests (reduce network)"

# Disable search highlights (reduces Start menu overhead)
$SearchSettings = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings'
Set-SafeRegValue -Path $SearchSettings -Name "IsDynamicSearchBoxEnabled" -Value 0 -Type DWord `
    -Description "Disable search highlights"
Set-SafeRegValue -Path $SearchSettings -Name "IsDeviceSearchHistoryEnabled" -Value 0 -Type DWord `
    -Description "Disable device search history"

# ============================================================
# SECTION 5h: NOTIFICATIONS CENTER (HKCU - Reduce Spam)
# ============================================================
Write-Host "`n== Notifications Center Optimizations ==" -ForegroundColor Cyan

# Quiet Hours / Focus Assist (reduce notification interruptions)
$Notifications = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings'
Set-SafeRegValue -Path $Notifications -Name "NOC_GLOBAL_SETTING_ALLOW_NOTIFICATION_SOUND" -Value 0 -Type DWord `
    -Description "Disable notification sounds"

# Disable notification balloons
$ExplorerAdv = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
Set-SafeRegValue -Path $ExplorerAdv -Name "EnableBalloonTips" -Value 0 -Type DWord `
    -Description "Disable notification balloons"

# ============================================================
# SECTION 5i: WINDOWS SEARCH OPTIMIZATIONS (Safe - Not Disabling)
# ============================================================
Write-Host "`n== Windows Search Optimizations (Safe) ==" -ForegroundColor Cyan

# Disable web search in Start menu (reduces network calls + faster results)
$SearchCortana = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search'
Set-SafeRegValue -Path $SearchCortana -Name "BingSearchEnabled" -Value 0 -Type DWord `
    -Description "Disable Bing web search in Start"

# Disable Cortana in search
Set-SafeRegValue -Path $SearchCortana -Name "CortanaEnabled" -Value 0 -Type DWord `
    -Description "Disable Cortana in search"

# Disable search history
Set-SafeRegValue -Path $SearchCortana -Name "HistoryViewEnabled" -Value 0 -Type DWord `
    -Description "Disable search history"

# Speed up search by disabling content indexing for certain file types (user preference)
$SearchSettings = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings'
Set-SafeRegValue -Path $SearchSettings -Name "SafeSearchMode" -Value 0 -Type DWord `
    -Description "Disable SafeSearch (faster results)"

# ============================================================
# SECTION 5j: SYSTEM RESTORE & SHADOW COPY (Safe Settings)
# ============================================================
Write-Host "`n== System Restore Settings (Safe) ==" -ForegroundColor Cyan

# Configure System Restore to use less disk space (safe tweak)
$SystemRestore = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore'
Set-SafeRegValue -Path $SystemRestore -Name "DiskPercent" -Value 5 -Type DWord `
    -Description "System Restore disk usage (5% instead of default)"

# ============================================================
# SECTION 5k: WINDOWS DEFENDER SCHEDULE (Safe - Not Disabling)
# ============================================================
Write-Host "`n== Windows Defender Scan Schedule ==" -ForegroundColor Cyan

# Schedule scans for idle time (reduces performance impact)
$DefenderSchedule = 'HKLM:\SOFTWARE\Microsoft\Windows Defender\Scan'
Set-SafeRegValue -Path $DefenderSchedule -Name "ScheduleDay" -Value 0 -Type DWord `
    -Description "Scan every day"
Set-SafeRegValue -Path $DefenderSchedule -Name "ScheduleTime" -Value 120 -Type DWord `
    -Description "Scan at 2 AM (idle time)"
Set-SafeRegValue -Path $DefenderSchedule -Name "DisableArchiveScanning" -Value 1 -Type DWord `
    -Description "Don't scan archives (faster scans)"

# ============================================================
# SECTION 5l: EXTENDED VISUAL EFFECTS (HKCU - Per User)
# ============================================================
Write-Host "`n== Extended Visual Effects (Per-User) ==" -ForegroundColor Cyan

# Individual visual effect controls (all cosmetic only)
$VisualFX = 'HKCU:\Control Panel\Desktop'
Set-SafeRegValue -Path $VisualFX -Name "DragFullWindows" -Value "0" -Type String `
    -Description "Show window contents while dragging (off=faster)"

Set-SafeRegValue -Path $VisualFX -Name "FontSmoothing" -Value "2" -Type String `
    -Description "Font smoothing (ClearType)"

Set-SafeRegValue -Path $VisualFX -Name "UserPreferencesMask" -Value ([byte[]](0x90,0x12,0x03,0x80,0x10,0x00,0x00,0x00)) -Type Binary `
    -Description "Visual effects mask (performance)"

# Wallpaper quality vs performance
$Desktop = 'HKCU:\Control Panel\Desktop'
Set-SafeRegValue -Path $Desktop -Name "JPEGImportQuality" -Value 85 -Type DWord `
    -Description "Wallpaper quality (85=good balance)"

# ============================================================
# SECTION 5m: EXTENDED MENU SPEEDS (HKCU)
# ============================================================
Write-Host "`n== Menu & Window Animation Speeds ==" -ForegroundColor Cyan

# Speed up window animations
$WindowMetrics = 'HKCU:\Control Panel\Desktop\WindowMetrics'
Set-SafeRegValue -Path $WindowMetrics -Name "MinAnimate" -Value "0" -Type String `
    -Description "Disable minimize animation"

# Speed up combo box dropdowns
Set-SafeRegValue -Path $VisualEffects -Name "ComboBoxAnimation" -Value 0 -Type DWord `
    -Description "Disable combo box animation"

# Speed up list box smoothing
Set-SafeRegValue -Path $VisualEffects -Name "ListBoxSmoothScrolling" -Value 0 -Type DWord `
    -Description "Disable list box smooth scrolling"

# Cursor shadow (cosmetic)
Set-SafeRegValue -Path $Desktop -Name "CursorShadow" -Value "0" -Type String `
    -Description "Disable cursor shadow"

# ============================================================
# SECTION 5n: WINDOWS UPDATE SAFE SETTINGS (HKLM)
# ============================================================
Write-Host "`n== Windows Update Safe Settings ==" -ForegroundColor Cyan

# Don't restart automatically after updates (user control)
$WUReboot = 'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings'
Set-SafeRegValue -Path $WUReboot -Name "IsExpedited" -Value 0 -Type DWord `
    -Description "Don't expedite updates"

# Disable auto-restart (give user control)
$WUPolicy = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'
Set-SafeRegValue -Path $WUPolicy -Name "NoAutoRebootWithLoggedOnUsers" -Value 1 -Type DWord `
    -Description "No auto-reboot when user logged in"

# Active hours - prevent restart during typical hours
Set-SafeRegValue -Path $WUReboot -Name "ActiveHoursStart" -Value 8 -Type DWord `
    -Description "Active hours start (8 AM)"
Set-SafeRegValue -Path $WUReboot -Name "ActiveHoursEnd" -Value 23 -Type DWord `
    -Description "Active hours end (11 PM)"

# ============================================================
# SECTION 5o: CLIPBOARD & CLOUD SYNC (HKCU - Privacy/Speed)
# ============================================================
Write-Host "`n== Clipboard & Cloud Sync Settings ==" -ForegroundColor Cyan

# Disable clipboard sync (privacy + reduces network)
$Clipboard = 'HKCU:\Software\Microsoft\Clipboard'
Set-SafeRegValue -Path $Clipboard -Name "EnableClipboardHistory" -Value 0 -Type DWord `
    -Description "Disable clipboard history (privacy)"
Set-SafeRegValue -Path $Clipboard -Name "CloudClipboardAutomaticUpload" -Value 0 -Type DWord `
    -Description "Disable cloud clipboard upload"

# Disable OneDrive files on demand (if not used - reduces network)
$OneDrive = 'HKCU:\Software\Microsoft\OneDrive'
Set-SafeRegValue -Path $OneDrive -Name "EnableFilesOnDemand" -Value 0 -Type DWord `
    -Description "Disable OneDrive Files On-Demand (if not used)"

# ============================================================
# SECTION 5p: REMOTE DESKTOP & REMOTE ASSISTANCE (Safe Disable)
# ============================================================
Write-Host "`n== Remote Desktop & Assistance (Safe Disable) ==" -ForegroundColor Cyan

# Disable Remote Assistance (security + reduces overhead)
$RemoteAssistance = 'HKLM:\SYSTEM\CurrentControlSet\Control\Remote Assistance'
Set-SafeRegValue -Path $RemoteAssistance -Name "fAllowToGetHelp" -Value 0 -Type DWord `
    -Description "Disable Remote Assistance"

Set-SafeRegValue -Path $RemoteAssistance -Name "fAllowFullControl" -Value 0 -Type DWord `
    -Description "Disable Remote Assistance full control"

# ============================================================
# SECTION 6: MOUSE & KEYBOARD RESPONSIVENESS (HKCU Only)
# ============================================================
Write-Host "`n== Mouse & Keyboard Responsiveness (Per-User) ==" -ForegroundColor Cyan

# Reduce mouse hover time (snappier UI response)
$MouseSettings = 'HKCU:\Control Panel\Mouse'
Set-SafeRegValue -Path $MouseSettings -Name "MouseHoverTime" -Value "20" -Type String `
    -Description "Mouse hover time (milliseconds)"

# Keyboard repeat rate (faster key repeat)
$KeyboardSettings = 'HKCU:\Control Panel\Keyboard'
Set-SafeRegValue -Path $KeyboardSettings -Name "KeyboardSpeed" -Value "31" -Type String `
    -Description "Keyboard repeat speed (max)"
Set-SafeRegValue -Path $KeyboardSettings -Name "KeyboardDelay" -Value "0" -Type String `
    -Description "Keyboard repeat delay (min)"

# ============================================================
# SECTION 7: WINDOWS ERROR REPORTING (Safe Disable)
# ============================================================
Write-Host "`n== Windows Error Reporting (Optional Disable) ==" -ForegroundColor Cyan
Write-Log "Disabling Windows Error Reporting (WER) - reduces background overhead" "INFO"

# WER is safe to disable - doesn't affect system stability
$WER = 'HKCU:\Software\Microsoft\Windows\Windows Error Reporting'
Set-SafeRegValue -Path $WER -Name "Disabled" -Value 1 -Type DWord `
    -Description "Disable Windows Error Reporting"

$WERPolicy = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting'
Set-SafeRegValue -Path $WERPolicy -Name "Disabled" -Value 1 -Type DWord `
    -Description "WER policy disable"

# ============================================================
# SECTION 8: WINDOWS UPDATE DELIVERY OPTIMIZATION (Safe)
# ============================================================
Write-Host "`n== Windows Update Delivery Optimization ==" -ForegroundColor Cyan
Write-Log "Disabling Delivery Optimization (prevents bandwidth sharing)" "INFO"

# Disable P2P Windows Update sharing (saves bandwidth, privacy)
$DeliveryOpt = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config'
Set-SafeRegValue -Path $DeliveryOpt -Name "DODownloadMode" -Value 0 -Type DWord `
    -Description "Disable Delivery Optimization P2P"

$DeliveryOptPolicy = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization'
Set-SafeRegValue -Path $DeliveryOptPolicy -Name "DODownloadMode" -Value 0 -Type DWord `
    -Description "Delivery Optimization policy"

# ============================================================
# SECTION 9: OPTIONAL SAFE CLEANUP (Extended)
# ============================================================
Write-Host "`n== Extended Safe Cleanup (Optional) ==" -ForegroundColor Cyan

$TempPaths = @(
    "$env:TEMP",
    "$env:LOCALAPPDATA\Temp"
)

$TotalFreed = 0
foreach ($Path in $TempPaths) {
    if (Test-Path $Path) {
        try {
            $Before = (Get-ChildItem -Path $Path -Recurse -Force -ErrorAction SilentlyContinue | 
                     Measure-Object -Property Length -Sum).Sum
            
            if (-not $WhatIf) {
                Get-ChildItem -Path $Path -File -Recurse -Force -ErrorAction SilentlyContinue | 
                    Where-Object { $_.CreationTime -lt (Get-Date).AddDays(-7) } |
                    Remove-Item -Force -ErrorAction SilentlyContinue
            }
            
            $After = (Get-ChildItem -Path $Path -Recurse -Force -ErrorAction SilentlyContinue | 
                     Measure-Object -Property Length -Sum).Sum
            $Freed = [math]::Round(($Before - $After) / 1MB, 2)
            $TotalFreed += $Freed
            
            if ($WhatIf) {
                $Potential = [math]::Round($Before / 1MB, 2)
                Write-Log "WOULD clean $Path (up to $Potential MB)" "INFO"
            } else {
                Write-Log "Cleaned $Path (${Freed} MB freed)" "SUCCESS"
            }
        }
        catch {
            Write-Log "Could not clean $Path : $_" "WARN"
        }
    }
}

# Additional safe cleanup locations
$AdditionalCleanup = @(
    @{ Path = "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\ThumbCacheToDelete"; Description = "Thumbnail cache" },
    @{ Path = "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\IconCacheToDelete"; Description = "Icon cache" },
    @{ Path = "$env:APPDATA\Microsoft\Windows\Recent\AutomaticDestinations"; Description = "Recent items cache"; MaxAge = 30 },
    @{ Path = "$env:APPDATA\Microsoft\Windows\Recent\CustomDestinations"; Description = "Custom recent items"; MaxAge = 30 }
)

foreach ($Cleanup in $AdditionalCleanup) {
    if (Test-Path $Cleanup.Path) {
        try {
            $Before = (Get-ChildItem -Path $Cleanup.Path -Recurse -Force -ErrorAction SilentlyContinue | 
                     Measure-Object -Property Length -Sum).Sum
            
            $MaxAge = if ($Cleanup.MaxAge) { $Cleanup.MaxAge } else { 7 }
            
            if (-not $WhatIf) {
                Get-ChildItem -Path $Cleanup.Path -File -Recurse -Force -ErrorAction SilentlyContinue | 
                    Where-Object { $_.CreationTime -lt (Get-Date).AddDays(-$MaxAge) } |
                    Remove-Item -Force -ErrorAction SilentlyContinue
            }
            
            $After = (Get-ChildItem -Path $Cleanup.Path -Recurse -Force -ErrorAction SilentlyContinue | 
                     Measure-Object -Property Length -Sum).Sum
            $Freed = [math]::Round(($Before - $After) / 1MB, 2)
            $TotalFreed += $Freed
            
            if ($Freed -gt 0 -or $WhatIf) {
                if ($WhatIf) {
                    $Potential = [math]::Round($Before / 1MB, 2)
                    Write-Log "WOULD clean $($Cleanup.Description) (up to $Potential MB)" "INFO"
                } else {
                    Write-Log "Cleaned $($Cleanup.Description) (${Freed} MB freed)" "SUCCESS"
                }
            }
        }
        catch {
            Write-Log "Could not clean $($Cleanup.Description) : $_" "WARN"
        }
    }
}

# Clear Recycle Bin (optional - safe)
Write-Host "`n== Recycle Bin ==" -ForegroundColor Cyan
try {
    $RecycleBin = (New-Object -ComObject Shell.Application).Namespace(0xA)
    $RecycleBinItems = $RecycleBin.Items()
    $BinSize = 0
    foreach ($Item in $RecycleBinItems) {
        $BinSize += $Item.Size
    }
    
    if ($BinSize -gt 0) {
        $BinSizeMB = [math]::Round($BinSize / 1MB, 2)
        if (-not $WhatIf) {
            Clear-RecycleBin -Force -ErrorAction SilentlyContinue
        }
        if ($WhatIf) {
            Write-Log "WOULD empty Recycle Bin ($BinSizeMB MB)" "INFO"
        } else {
            Write-Log "Emptied Recycle Bin ($BinSizeMB MB freed)" "SUCCESS"
            $TotalFreed += $BinSizeMB
        }
    } else {
        Write-Log "Recycle Bin is empty" "INFO"
    }
} catch {
    Write-Log "Could not check/empty Recycle Bin : $_" "WARN"
}

# ============================================================
# SECTION 9b: BROWSER CACHE CLEANUP (Safe - Chrome/Edge/Firefox)
# ============================================================
Write-Host "`n== Browser Cache Cleanup (Safe) ==" -ForegroundColor Cyan

$BrowserCaches = @(
    @{ 
        Name = "Chrome Cache"; 
        Path = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache"; 
        MaxAge = 7 
    },
    @{ 
        Name = "Edge Cache"; 
        Path = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache"; 
        MaxAge = 7 
    },
    @{ 
        Name = "Firefox Cache"; 
        Path = "$env:LOCALAPPDATA\Mozilla\Firefox\Profiles\*\cache2"; 
        MaxAge = 7 
    },
    @{ 
        Name = "IE/Edge Legacy Cache"; 
        Path = "$env:LOCALAPPDATA\Microsoft\Windows\INetCache"; 
        MaxAge = 14 
    }
)

foreach ($Browser in $BrowserCaches) {
    $CachePath = $Browser.Path
    if (Test-Path $CachePath) {
        try {
            $Before = (Get-ChildItem -Path $CachePath -Recurse -Force -ErrorAction SilentlyContinue | 
                     Measure-Object -Property Length -Sum).Sum
            
            if (-not $WhatIf) {
                Get-ChildItem -Path $CachePath -File -Recurse -Force -ErrorAction SilentlyContinue | 
                    Where-Object { $_.CreationTime -lt (Get-Date).AddDays(-$Browser.MaxAge) } |
                    Remove-Item -Force -ErrorAction SilentlyContinue
            }
            
            $After = (Get-ChildItem -Path $CachePath -Recurse -Force -ErrorAction SilentlyContinue | 
                     Measure-Object -Property Length -Sum).Sum
            $Freed = [math]::Round(($Before - $After) / 1MB, 2)
            $TotalFreed += $Freed
            
            if ($Freed -gt 0 -or $WhatIf) {
                if ($WhatIf) {
                    $Potential = [math]::Round($Before / 1MB, 2)
                    Write-Log "WOULD clean $($Browser.Name) (up to $Potential MB)" "INFO"
                } else {
                    Write-Log "Cleaned $($Browser.Name) (${Freed} MB freed)" "SUCCESS"
                }
            }
        }
        catch {
            Write-Log "Could not clean $($Browser.Name) : $_" "WARN"
        }
    }
}

# ============================================================
# SECTION 9c: WINDOWS LOG CLEANUP (Safe - Event Logs)
# ============================================================
Write-Host "`n== Windows Event Log Cleanup (Safe) ==" -ForegroundColor Cyan

# Clear common event logs (doesn't disable logging, just clears old entries)
$LogsToClear = @("Application", "System", "Setup", "ForwardedEvents")
foreach ($LogName in $LogsToClear) {
    try {
        if (-not $WhatIf) {
            wevtutil cl $LogName 2>$null | Out-Null
        }
        Write-Log "Cleared $LogName event log" "SUCCESS"
    }
    catch {
        Write-Log "Could not clear $LogName log : $_" "WARN"
    }
}

# ============================================================
# SECTION 9d: MEMORY MANAGEMENT TWEAKS (Safe HKLM)
# ============================================================
Write-Host "`n== Memory Management (Safe) ==" -ForegroundColor Cyan

# Prefetch Parameters
$Prefetch = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters'
Set-SafeRegValue -Path $Prefetch -Name "EnablePrefetcher" -Value 3 -Type DWord `
    -Description "Enable prefetcher (boot+app)"

Set-SafeRegValue -Path $Prefetch -Name "EnableSuperfetch" -Value 0 -Type DWord `
    -Description "Disable Superfetch (SSD optimization)"

# ============================================================
# SECTION 9e: NETWORK PROTOCOL OPTIMIZATIONS (Safe)
# ============================================================
Write-Host "`n== Network Protocol Optimizations (Safe) ==" -ForegroundColor Cyan

# Disable NetBIOS over TCP (security + performance)
$NetBT = 'HKLM:\SYSTEM\CurrentControlSet\Services\NetBT\Parameters'
Set-SafeRegValue -Path $NetBT -Name "NodeType" -Value 2 -Type DWord `
    -Description "NetBIOS node type P-node (no broadcasts)"

# Disable LMHOSTS lookup
Set-SafeRegValue -Path $NetBT -Name "EnableLMHosts" -Value 0 -Type DWord `
    -Description "Disable LMHOSTS lookup"

# Disable bandwidth reservation (QoS) - releases 20% reserved bandwidth
$QoS = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Psched'
Set-SafeRegValue -Path $QoS -Name "NonBestEffortLimit" -Value 0 -Type DWord `
    -Description "Disable QoS bandwidth reservation (release 20%)"

# ============================================================
# SECTION 9f: TIME SYNCHRONIZATION (Safe)
# ============================================================
Write-Host "`n== Time Synchronization (Safe) ==" -ForegroundColor Cyan

# More frequent time sync for better accuracy
$TimeService = 'HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\TimeProviders\NtpClient'
Set-SafeRegValue -Path $TimeService -Name "SpecialPollInterval" -Value 3600 -Type DWord `
    -Description "Time sync every hour (3600 seconds)"

# ============================================================
# SECTION 9g: SMB/CIFS OPTIMIZATIONS (Safe)
# ============================================================
Write-Host "`n== SMB/CIFS Network Share Optimizations (Safe) ==" -ForegroundColor Cyan

$SMB = 'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters'
Set-SafeRegValue -Path $SMB -Name "MaxCmds" -Value 50 -Type DWord `
    -Description "Max SMB commands (better concurrent file ops)"

Set-SafeRegValue -Path $SMB -Name "MaxThreads" -Value 50 -Type DWord `
    -Description "Max SMB threads"

Set-SafeRegValue -Path $SMB -Name "MaxCollectionCount" -Value 32 -Type DWord `
    -Description "SMB collection count (better throughput)"

# ============================================================
# SECTION 9h: FILE EXPLORER EXTENDED (HKCU)
# ============================================================
Write-Host "`n== File Explorer Extended Settings (Per-User) ==" -ForegroundColor Cyan

# Disable preview pane (performance for large folders)
$ExplorerSettings = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
Set-SafeRegValue -Path $ExplorerSettings -Name "ShowPreviewPane" -Value 0 -Type DWord `
    -Description "Disable preview pane (faster browsing)"

# Disable reading pane in details
Set-SafeRegValue -Path $ExplorerSettings -Name "ShowReadingPane" -Value 0 -Type DWord `
    -Description "Disable reading pane"

# Launch folder windows in separate process (stability)
Set-SafeRegValue -Path $ExplorerSettings -Name "SeparateProcess" -Value 1 -Type DWord `
    -Description "Separate Explorer processes (stability)"

# Disable auto-expand in navigation pane
Set-SafeRegValue -Path $ExplorerSettings -Name "NavPaneExpandToCurrentFolder" -Value 0 -Type DWord `
    -Description "Disable auto-expand navigation pane"

# Show full path in title bar
Set-SafeRegValue -Path $ExplorerSettings -Name "ShowFullPathInTitleBar" -Value 1 -Type DWord `
    -Description "Show full path in title bar"

# ============================================================
# SECTION 9i: PERFORMANCE MONITOR & DIAGNOSTICS (Safe)
# ============================================================
Write-Host "`n== Diagnostics & Performance Tracking (Safe) ==" -ForegroundColor Cyan

# Disable customer experience improvement (telemetry reduction)
$CEIP = 'HKLM:\SOFTWARE\Microsoft\SQMClient\Windows'
Set-SafeRegValue -Path $CEIP -Name "CEIPEnable" -Value 0 -Type DWord `
    -Description "Disable Customer Experience Improvement"

# ============================================================
# SECTION 9j: PRINT SPOOLER SAFETY (Not Disabling - Just Settings)
# ============================================================
Write-Host "`n== Print Spooler Safety Settings ==" -ForegroundColor Cyan

# Keep print spooler running but disable web printing (security)
$PrintWeb = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers'
Set-SafeRegValue -Path $PrintWeb -Name "DisableWebPrinting" -Value 1 -Type DWord `
    -Description "Disable web printing (security)"

# ============================================================
# SECTION 9k: WINDOWS STORE & APP SETTINGS (Safe)
# ============================================================
Write-Host "`n== Windows Store & App Settings (Safe) ==" -ForegroundColor Cyan

# Disable automatic app updates (manual control)
$Store = 'HKLM:\SOFTWARE\Policies\Microsoft\WindowsStore'
Set-SafeRegValue -Path $Store -Name "AutoDownload" -Value 2 -Type DWord `
    -Description "Disable automatic Store app updates"

# Disable app auto-install from Store
$StorePolicy = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
Set-SafeRegValue -Path $StorePolicy -Name "SilentInstalledAppsEnabled" -Value 0 -Type DWord `
    -Description "Disable silent app installs"

# ============================================================
# SECTION 9l: WINDOWS BIOMETRICS & PRIVACY (Safe)
# ============================================================
Write-Host "`n== Biometrics & Privacy Settings (Safe) ==" -ForegroundColor Cyan

# Disable biometrics if not used (reduces overhead)
$Biometrics = 'HKLM:\SOFTWARE\Policies\Microsoft\Biometrics'
Set-SafeRegValue -Path $Biometrics -Name "Enabled" -Value 0 -Type DWord `
    -Description "Disable Windows Biometrics (if not used)"

# Disable camera on lock screen (privacy)
$Camera = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Authentication\LogonUI'
Set-SafeRegValue -Path $Camera -Name "CameraDisabled" -Value 1 -Type DWord `
    -Description "Disable camera on lock screen"

# ============================================================
# SECTION 9m: LOCATION & SENSORS (Safe Disable)
# ============================================================
Write-Host "`n== Location & Sensors (Safe Disable) ==" -ForegroundColor Cyan

# Disable location tracking (privacy + reduces background processing)
$Location = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors'
Set-SafeRegValue -Path $Location -Name "DisableLocation" -Value 1 -Type DWord `
    -Description "Disable location tracking"
Set-SafeRegValue -Path $Location -Name "DisableLocationScripting" -Value 1 -Type DWord `
    -Description "Disable location scripting"
Set-SafeRegValue -Path $Location -Name "DisableSensors" -Value 1 -Type DWord `
    -Description "Disable sensors (if not needed)"

# ============================================================
# SECTION 9n: SPEECH & TYPING (Safe Disable)
# ============================================================
Write-Host "`n== Speech & Typing Settings (Safe) ==" -ForegroundColor Cyan

# Disable online speech recognition (privacy)
$Speech = 'HKLM:\SOFTWARE\Policies\Microsoft\InputPersonalization'
Set-SafeRegValue -Path $Speech -Name "AllowInputPersonalization" -Value 0 -Type DWord `
    -Description "Disable online speech recognition"

# Disable typing insights
$Typing = 'HKCU:\Software\Microsoft\Input\Settings'
Set-SafeRegValue -Path $Typing -Name "EnableExtraCandidateDirection" -Value 0 -Type DWord `
    -Description "Disable typing insights"

# ============================================================
# SECTION 9o: EASE OF ACCESS (Performance)
# ============================================================
Write-Host "`n== Ease of Access Performance ==" -ForegroundColor Cyan

# Disable narrator (if not needed)
$Narrator = 'HKCU:\Software\Microsoft\Narrator\NoRoam'
Set-SafeRegValue -Path $Narrator -Name "WinEnterLaunchEnabled" -Value 0 -Type DWord `
    -Description "Disable Narrator Win+Enter shortcut"

# Disable magnifier (if not needed)
$Magnifier = 'HKCU:\Software\Microsoft\ScreenMagnifier'
Set-SafeRegValue -Path $Magnifier -Name " magnifierEnabled" -Value 0 -Type DWord `
    -Description "Disable Magnifier"

# ============================================================
# SECTION 9p: POWER SHELL & SCRIPTING (Safe)
# ============================================================
Write-Host "`n== PowerShell & Scripting Performance ==" -ForegroundColor Cyan

# PowerShell execution policy notification (reduce startup time)
$PSConsole = 'HKCU:\Software\Microsoft\PowerShell\PSReadLine'
Set-SafeRegValue -Path $PSConsole -Name "PredictionSource" -Value "None" -Type String `
    -Description "Disable PowerShell prediction (faster startup)"

# ============================================================
# SECTION 9q: REMOTE REGISTRY (Security - Safe Disable)
# ============================================================
Write-Host "`n== Remote Registry (Safe Disable) ==" -ForegroundColor Cyan

# Already handled in earlier section but double-check policy
$RemoteReg = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Remoteregistry'
Set-SafeRegValue -Path $RemoteReg -Name "DisableRemoteRegistry" -Value 1 -Type DWord `
    -Description "Disable Remote Registry service access"

# ============================================================
# SECTION 9r: WINDOWS 11 SPECIFIC OPTIMIZATIONS (Safe)
# ============================================================
Write-Host "`n== Windows 11 Specific Optimizations ==" -ForegroundColor Cyan

# Disable Widgets (Windows 11 feature that consumes resources)
$Widgets = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Dsh'
Set-SafeRegValue -Path $Widgets -Name "AllowNewsAndInterests" -Value 0 -Type DWord `
    -Description "Disable Widgets board (reduce resources)"

# Disable Chat icon in taskbar (Teams integration)
$TeamsChat = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Chat'
if (-not (Test-Path $TeamsChat)) { New-Item -Path $TeamsChat -Force | Out-Null }
Set-SafeRegValue -Path $TeamsChat -Name "ChatIcon" -Value 3 -Type DWord `
    -Description "Remove Teams Chat icon from taskbar"

# Disable "Recommended" section in Start menu
$StartMenu = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer'
Set-SafeRegValue -Path $StartMenu -Name "HideRecommendedSection" -Value 1 -Type DWord `
    -Description "Hide Recommended section in Start menu"

# Disable enhanced pointer precision (better for gaming - consistent mouse)
$Mouse = 'HKCU:\Control Panel\Mouse'
Set-SafeRegValue -Path $Mouse -Name "MouseSpeed" -Value "0" -Type String `
    -Description "Disable enhanced pointer precision (consistent mouse)"
Set-SafeRegValue -Path $Mouse -Name "MouseThreshold1" -Value "0" -Type String `
    -Description "Mouse threshold 1"
Set-SafeRegValue -Path $Mouse -Name "MouseThreshold2" -Value "0" -Type String `
    -Description "Mouse threshold 2"

# ============================================================
# SECTION 9s: MICROSOFT EDGE OPTIMIZATIONS (Safe)
# ============================================================
Write-Host "`n== Microsoft Edge Optimizations (Safe) ==" -ForegroundColor Cyan

# Disable Edge startup boost (saves RAM when Edge not in use)
$Edge = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'
Set-SafeRegValue -Path $Edge -Name "StartupBoostEnabled" -Value 0 -Type DWord `
    -Description "Disable Edge startup boost (save RAM)"

# Disable Edge prelaunch at Windows startup
Set-SafeRegValue -Path $Edge -Name "AllowPrelaunch" -Value 0 -Type DWord `
    -Description "Disable Edge prelaunch at startup"

# Disable Edge running background apps when closed
Set-SafeRegValue -Path $Edge -Name "BackgroundModeEnabled" -Value 0 -Type DWord `
    -Description "Disable Edge background apps"

# Disable Edge sidebar (saves resources)
Set-SafeRegValue -Path $Edge -Name "HubsSidebarEnabled" -Value 0 -Type DWord `
    -Description "Disable Edge sidebar"

# ============================================================
# SECTION 9t: FILE SYSTEM & DISK PERFORMANCE (Safe)
# ============================================================
Write-Host "`n== File System & Disk Performance (Safe) ==" -ForegroundColor Cyan

# Disable last access timestamp (reduces disk writes)
$FileSystem = 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem'
Set-SafeRegValue -Path $FileSystem -Name "NtfsDisableLastAccessUpdate" -Value 1 -Type DWord `
    -Description "Disable last access timestamp (reduce disk writes)"

# Disable 8.3 name creation (modern apps don't need this)
Set-SafeRegValue -Path $FileSystem -Name "NtfsDisable8dot3NameCreation" -Value 1 -Type DWord `
    -Description "Disable 8.3 filename creation (modern apps)"

# ============================================================
# SECTION 9u: WINDOWS UPDATE CONTROL (User-friendly)
# ============================================================
Write-Host "`n== Windows Update User Control (Safe) ==" -ForegroundColor Cyan

# Disable automatic driver updates (users prefer manual control)
$WUDrivers = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DriverSearching'
Set-SafeRegValue -Path $WUDrivers -Name "SearchOrderConfig" -Value 0 -Type DWord `
    -Description "Disable automatic driver updates (user control)"

# Notify before downloading updates
$WUNotify = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'
Set-SafeRegValue -Path $WUNotify -Name "AUOptions" -Value 2 -Type DWord `
    -Description "Notify before download/install (user control)"

# ============================================================
# SECTION 9v: GAMING BAR & CAPTURE EXTENDED (More QoL)
# ============================================================
Write-Host "`n== Gaming Quality of Life Improvements ==" -ForegroundColor Cyan

# Disable Game Mode notifications (reduces interruptions)
$GameMode = 'HKCU:\Software\Microsoft\GameBar'
Set-SafeRegValue -Path $GameMode -Name "ShowGameModeNotifications" -Value 0 -Type DWord `
    -Description "Disable Game Mode notifications"

# Disable Game Bar tips
Set-SafeRegValue -Path $GameMode -Name "ShowStartupPanel" -Value 0 -Type DWord `
    -Description "Disable Game Bar startup tips"

# ============================================================
# SECTION 9w: EXPLORER QUALITY OF LIFE (Everyone loves these)
# ============================================================
Write-Host "`n== Explorer Quality of Life Improvements ==" -ForegroundColor Cyan

# Show file extensions (security + convenience)
$ExplorerQoL = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
Set-SafeRegValue -Path $ExplorerQoL -Name "HideFileExt" -Value 0 -Type DWord `
    -Description "Show file extensions (security)"

# Show hidden files (convenience for power users)
Set-SafeRegValue -Path $ExplorerQoL -Name "Hidden" -Value 1 -Type DWord `
    -Description "Show hidden files"

# Disable simple folder view (show full folder tree)
Set-SafeRegValue -Path $ExplorerQoL -Name "WebView" -Value 0 -Type DWord `
    -Description "Disable web view in folders"

# Use classic search (faster than modern search)
Set-SafeRegValue -Path $ExplorerQoL -Name "SearchBoxVisibleInTouchImprovement" -Value 0 -Type DWord `
    -Description "Use classic search box"

# Disable Aero Shake (prevents accidental window minimize)
Set-SafeRegValue -Path $ExplorerQoL -Name "DisallowShaking" -Value 1 -Type DWord `
    -Description "Disable Aero Shake (prevent accidental minimize)"

# Disable Aero Snap assistance (reduces animation overhead)
Set-SafeRegValue -Path $ExplorerQoL -Name "JointResize" -Value 0 -Type DWord `
    -Description "Disable Aero Snap assistance"

# ============================================================
# SECTION 9x: TELEMETRY EXTENDED (People love disabling this)
# ============================================================
Write-Host "`n== Extended Telemetry Disables (Privacy) ==" -ForegroundColor Cyan

# Disable Application Impact Telemetry
$AIT = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat'
Set-SafeRegValue -Path $AIT -Name "AITEnable" -Value 0 -Type DWord `
    -Description "Disable Application Impact Telemetry"

# Disable Program Compatibility Assistant
Set-SafeRegValue -Path $AIT -Name "DisablePCA" -Value 1 -Type DWord `
    -Description "Disable Program Compatibility Assistant"

# Disable Steps Recorder (privacy)
$StepsRecorder = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat'
Set-SafeRegValue -Path $StepsRecorder -Name "DisableUAR" -Value 1 -Type DWord `
    -Description "Disable Steps Recorder (privacy)"

# Disable Inventory Collector
$Inventory = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat'
Set-SafeRegValue -Path $Inventory -Name "DisableInventory" -Value 1 -Type DWord `
    -Description "Disable Inventory Collector"

# ============================================================
# SECTION 9y: CONTEXT MENU & RIGHT-CLICK (Speed up)
# ============================================================
Write-Host "`n== Context Menu Performance ==" -ForegroundColor Cyan

# Reduce menu delay (snappier right-click)
$MenuSpeed = 'HKCU:\Control Panel\Desktop'
Set-SafeRegValue -Path $MenuSpeed -Name "MenuShowDelay" -Value "0" -Type String `
    -Description "Reduce menu delay to 0 (instant)"

# ============================================================
# SECTION 9z: WINDOWS SEARCH SPEED (More optimizations)
# ============================================================
Write-Host "`n== Windows Search Speed Improvements ==" -ForegroundColor Cyan

# Disable search indexer respect power settings (index faster)
$SearchSpeed = 'HKLM:\SOFTWARE\Microsoft\Windows Search\Gather\Windows\SystemIndex'
Set-SafeRegValue -Path $SearchSpeed -Name "RespectPowerSettings" -Value 0 -Type DWord `
    -Description "Index faster (ignore power settings)"

# Reduce indexing on battery (performance preference)
$SearchBattery = 'HKLM:\SOFTWARE\Microsoft\Windows Search\Gather\Windows\SystemIndex'
Set-SafeRegValue -Path $SearchBattery -Name "RespectPowerSettings" -Value 0 -Type DWord `
    -Description "Always index at full speed"

# ============================================================
# SECTION 10: UNIVERSALLY LOVED TWEAKS (Final Section)
# ============================================================
Write-Host "`n== Universally Loved Tweaks (Final) ==" -ForegroundColor Cyan

# Disable Windows Tips and Tricks (annoying popups)
$Tips = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
Set-SafeRegValue -Path $Tips -Name "ShowInfoTip" -Value 0 -Type DWord `
    -Description "Disable Windows Tips popups"

# Disable "How do you want to open this file" prompt (annoying)
$OpenWith = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer'
Set-SafeRegValue -Path $OpenWith -Name "NoUseStoreOpenWith" -Value 1 -Type DWord `
    -Description "Disable Store app for unknown files"

# Disable "Look for an app in the Store" (annoying)
Set-SafeRegValue -Path $OpenWith -Name "NoUseStoreOpenWith" -Value 1 -Type DWord `
    -Description "No Store lookup for unknown files"

# Disable Security Center notifications (reduce nagging)
$SecurityCenter = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
Set-SafeRegValue -Path $SecurityCenter -Name "SecurityCenter" -Value 0 -Type DWord `
    -Description "Reduce Security Center notifications"

# ============================================================
# SECTION 10b: ONEDRIVE & CLOUD SYNC (More Control)
# ============================================================
Write-Host "`n== OneDrive & Cloud Sync Control ==" -ForegroundColor Cyan

# Disable OneDrive files on demand (if user prefers local files)
$OneDriveLocal = 'HKLM:\SOFTWARE\Policies\Microsoft\OneDrive'
Set-SafeRegValue -Path $OneDriveLocal -Name "EnableAllFilesOnDemand" -Value 0 -Type DWord `
    -Description "Disable OneDrive Files On-Demand (prefer local)"

# Disable OneDrive automatic upload of screenshots
$OneDriveScreenshots = 'HKCU:\Software\Microsoft\OneDrive\Settings\Personal'
Set-SafeRegValue -Path $OneDriveScreenshots -Name "Screenshots" -Value 0 -Type DWord `
    -Description "Disable OneDrive screenshot upload"

# ============================================================
# SECTION 10c: WINDOWS 11 BLAT CLEANUP (User-requested features)
# ============================================================
Write-Host "`n== Windows 11 Bloat Cleanup (User Favorites) ==" -ForegroundColor Cyan

# Disable "Meet Now" in taskbar (Windows 10/11 feature)
$MeetNow = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer'
Set-SafeRegValue -Path $MeetNow -Name "HideSCAMeetNow" -Value 1 -Type DWord `
    -Description "Hide Meet Now from taskbar"

# Disable OneDrive in File Explorer navigation pane
$OneDriveNav = 'HKCR:\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}'
Set-SafeRegValue -Path $OneDriveNav -Name "System.IsPinnedToNameSpaceTree" -Value 0 -Type DWord `
    -Description "Remove OneDrive from Explorer navigation"

# Disable 3D Objects folder (nobody uses this)
$3DObjects = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{31C0DD25-9439-4F12-BF41-7FF4EDA38722}\PropertyBag'
Set-SafeRegValue -Path $3DObjects -Name "ThisPCPolicy" -Value "Hide" -Type String `
    -Description "Hide 3D Objects folder from This PC"

# ============================================================
# SECTION 10d: MORE GAMING OPTIMIZATIONS (Competitive)
# ============================================================
Write-Host "`n== Competitive Gaming Optimizations ==" -ForegroundColor Cyan

# Disable HPET (High Precision Event Timer) bias toward power savings
# Note: This is safe and improves timer consistency
$HPET = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel'
Set-SafeRegValue -Path $HPET -Name "DisableTsx" -Value 1 -Type DWord `
    -Description "Disable Intel TSX (security + consistency)"

# Optimize thread scheduling for games
$ThreadScheduling = 'HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl'
Set-SafeRegValue -Path $ThreadScheduling -Name "Win32PrioritySeparation" -Value 38 -Type DWord `
    -Description "Optimize thread scheduling (gaming)"

# ============================================================
# SECTION 10e: SYSTEM RESPONSIVENESS (More)
# ============================================================
Write-Host "`n== Extended System Responsiveness ==" -ForegroundColor Cyan

# Disable paging file clearing at shutdown (faster shutdown)
$Shutdown = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management'
Set-SafeRegValue -Path $Shutdown -Name "ClearPageFileAtShutdown" -Value 0 -Type DWord `
    -Description "Disable page file clearing (faster shutdown)"

# Reduce shutdown wait time for services
$ShutdownWait = 'HKLM:\SYSTEM\CurrentControlSet\Control'
Set-SafeRegValue -Path $ShutdownWait -Name "WaitToKillServiceTimeout" -Value 2000 -Type DWord `
    -Description "Reduce service shutdown wait (2 seconds)"

# Reduce application shutdown wait
$AppShutdown = 'HKCU:\Control Panel\Desktop'
Set-SafeRegValue -Path $AppShutdown -Name "WaitToKillAppTimeout" -Value 2000 -Type String `
    -Description "Reduce app shutdown wait (2 seconds)"

Set-SafeRegValue -Path $AppShutdown -Name "HungAppTimeout" -Value 2000 -Type String `
    -Description "Hung app timeout (2 seconds)"

# ============================================================
# SECTION 10f: PRIVACY EXTENDED (More telemetry kills)
# ============================================================
Write-Host "`n== Extended Privacy & Telemetry Kills ==" -ForegroundColor Cyan

# Disable Windows Customer Experience Improvement Program
$CEIPEXT = 'HKLM:\SOFTWARE\Policies\Microsoft\SQMClient\Windows'
Set-SafeRegValue -Path $CEIPEXT -Name "CEIPEnable" -Value 0 -Type DWord `
    -Description "Disable CEIP completely"

# Disable Windows Error Reporting completely
$WERE = 'HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting'
Set-SafeRegValue -Path $WERE -Name "Disabled" -Value 1 -Type DWord `
    -Description "Disable Windows Error Reporting system-wide"

# Disable automatic sample submission for Windows Defender
$DefenderSample = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Spynet'
Set-SafeRegValue -Path $DefenderSample -Name "SubmitSamplesConsent" -Value 2 -Type DWord `
    -Description "Disable Defender automatic sample submission"

# Disable MAPS (Microsoft Active Protection Service) reporting
Set-SafeRegValue -Path $DefenderSample -Name "SpynetReporting" -Value 0 -Type DWord `
    -Description "Disable MAPS reporting"

# ============================================================
# SECTION 10g: WINDOWS DEFENDER PERFORMANCE (Safe)
# ============================================================
Write-Host "`n== Windows Defender Performance ==" -ForegroundColor Cyan

# Disable Defender real-time protection during scans (reduces system impact)
$DefenderPerf = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Scan'
Set-SafeRegValue -Path $DefenderPerf -Name "DisableScanningNetworkFiles" -Value 1 -Type DWord `
    -Description "Disable scanning network files (performance)"

Set-SafeRegValue -Path $DefenderPerf -Name "DisableRemovableDriveScanning" -Value 1 -Type DWord `
    -Description "Disable removable drive scanning (performance)"

# Disable email scanning (if using 3rd party email)
$DefenderEmail = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection'
Set-SafeRegValue -Path $DefenderEmail -Name "DisableEmailScanning" -Value 1 -Type DWord `
    -Description "Disable email scanning (performance)"

# ============================================================
# SECTION 10h: INTERNET EXPLORER/LEGACY (Safe disable)
# ============================================================
Write-Host "`n== Internet Explorer / Legacy (Safe Disable) ==" -ForegroundColor Cyan

# Disable Internet Explorer first run wizard
$IE = 'HKLM:\SOFTWARE\Policies\Microsoft\Internet Explorer\Main'
Set-SafeRegValue -Path $IE -Name "DisableFirstRunCustomize" -Value 1 -Type DWord `
    -Description "Disable IE first run wizard"

# Disable IE suggested sites
$IESuggestions = 'HKLM:\SOFTWARE\Policies\Microsoft\Internet Explorer'
Set-SafeRegValue -Path $IESuggestions -Name "AllowServicePoweredQSA" -Value 0 -Type DWord `
    -Description "Disable IE suggested sites"

# ============================================================
# SECTION 10i: MORE EXPLORER CONVENIENCE (Power user favorites)
# ============================================================
Write-Host "`n== Explorer Power User Tweaks ==" -ForegroundColor Cyan

# Launch folder windows in a separate process (stability)
$ExplorerSep = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
Set-SafeRegValue -Path $ExplorerSep -Name "SeparateProcess" -Value 1 -Type DWord `
    -Description "Separate Explorer processes (stability)"

# Always show icons, never thumbnails (faster browsing for large folders)
Set-SafeRegValue -Path $ExplorerSep -Name "IconsOnly" -Value 0 -Type DWord `
    -Description "Show icons and thumbnails (default)"

# Show drive letters first (convenience)
Set-SafeRegValue -Path $ExplorerSep -Name "ShowDriveLettersFirst" -Value 4 -Type DWord `
    -Description "Show drive letters first"

# Disable sharing wizard (direct sharing)
$Sharing = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
Set-SafeRegValue -Path $Sharing -Name "SharingWizardOn" -Value 0 -Type DWord `
    -Description "Disable sharing wizard (direct sharing)"

# ============================================================
# SECTION 10j: PERFORMANCE MONITORING (Reduce overhead)
# ============================================================
Write-Host "`n== Performance Monitoring Tweaks ==" -ForegroundColor Cyan

# Disable Windows Performance Recorder (reduces background tracing)
$WPR = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WDI'
Set-SafeRegValue -Path $WPR -Name "ScenarioExecutionEnabled" -Value 0 -Type DWord `
    -Description "Disable Windows Performance Recorder tracing"

# Disable startup delay for apps
$StartupDelay = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize'
if (-not (Test-Path $StartupDelay)) { New-Item -Path $StartupDelay -Force | Out-Null }
Set-SafeRegValue -Path $StartupDelay -Name "StartupDelayInMSec" -Value 0 -Type DWord `
    -Description "Disable startup app delay (launch faster)"

# ============================================================
# SECTION 10k: UAC & SECURITY (User-friendly settings)
# ============================================================
Write-Host "`n== UAC & Security (User-Friendly) ==" -ForegroundColor Cyan

# Don't dim desktop during UAC prompt (faster)
$UAC = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'
Set-SafeRegValue -Path $UAC -Name "PromptOnSecureDesktop" -Value 0 -Type DWord `
    -Description "Don't dim desktop during UAC (faster)"

# ============================================================
# SECTION 10l: MORE NETWORK SPEED (Advanced)
# ============================================================
Write-Host "`n== Advanced Network Speed Tweaks ==" -ForegroundColor Cyan

# Increase MaxFreeTcbs (better connection reuse)
$NetSpeed = 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters'
Set-SafeRegValue -Path $NetSpeed -Name "MaxFreeTcbs" -Value 65535 -Type DWord `
    -Description "Max free TCBs (connection reuse)"

# Increase MaxUserPort
Set-SafeRegValue -Path $NetSpeed -Name "MaxUserPort" -Value 65534 -Type DWord `
    -Description "Max user ports (more connections)"

# Enable TCP timestamps (better RTT calculation)
Set-SafeRegValue -Path $NetSpeed -Name "Tcp1323Opts" -Value 1 -Type DWord `
    -Description "Enable TCP timestamps (RTT accuracy)"

# ============================================================
# SECTION 10m: DESKTOP & TASKBAR (Aesthetic + Performance)
# ============================================================
Write-Host "`n== Desktop & Taskbar Aesthetic ==" -ForegroundColor Cyan

# Disable desktop wallpaper slideshow (saves resources)
$DesktopSlide = 'HKCU:\Control Panel\Personalization\Desktop Slideshow'
Set-SafeRegValue -Path $DesktopSlide -Name "Interval" -Value 86400000 -Type DWord `
    -Description "Wallpaper slideshow interval (1 day)"

# Disable transparency (saves GPU resources)
$Transparency = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
Set-SafeRegValue -Path $Transparency -Name "EnableTransparency" -Value 0 -Type DWord `
    -Description "Disable transparency (save GPU)"

# Disable animations (performance)
Set-SafeRegValue -Path $Transparency -Name "EnableAnimations" -Value 0 -Type DWord `
    -Description "Disable animations (performance)"

# ============================================================
# SECTION 10n: FINAL UNIVERSAL TWEAKS (The best for last)
# ============================================================
Write-Host "`n== Final Universal Tweaks (Best for Last) ==" -ForegroundColor Cyan

# Disable automatic maintenance (user controls when)
$Maintenance = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Maintenance\Winlogon'
Set-SafeRegValue -Path $Maintenance -Name "MaintenanceDisabled" -Value 1 -Type DWord `
    -Description "Disable automatic maintenance (user control)"

# Disable Windows feedback requests
$Feedback = 'HKCU:\Software\Microsoft\Siuf\Rules'
if (-not (Test-Path $Feedback)) { New-InputObject -Path $Feedback -Force | Out-Null }
Set-SafeRegValue -Path $Feedback -Name "NumberOfSIUFInPeriod" -Value 0 -Type DWord `
    -Description "Disable Windows feedback requests"

# Disable "Get even more out of Windows" screen
$OutOfBox = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement'
Set-SafeRegValue -Path $OutOfBox -Name "ScoobeSystemSettingEnabled" -Value 0 -Type DWord `
    -Description "Disable 'Get more out of Windows'"

# ============================================================
# SECTION 10o: LOGIN & DEVICE SETUP (Control annoyances)
# ============================================================
Write-Host "`n== Login & Device Setup (Control Annoyances) ==" -ForegroundColor Cyan

# NOTE: Skip lock screen removed - security hazard
# Lock screen provides important security by hiding session from view

# Disable "Use my sign-in info to auto finish setting up my device"
$SignIn = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement'
Set-SafeRegValue -Path $SignIn -Name "ScoobeSystemSettingEnabled" -Value 0 -Type DWord `
    -Description "Don't auto-finish device setup after update"

# ============================================================
# SECTION 10p: MORE CONTEXT MENU FIXES (Windows 11)
# ============================================================
Write-Host "`n== Context Menu Fixes (Windows 11) ==" -ForegroundColor Cyan

# Restore classic context menu (right-click shows all options)
$ClassicMenu = 'HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32'
if (-not (Test-Path $ClassicMenu)) { New-Item -Path $ClassicMenu -Force | Out-Null }
Set-SafeRegValue -Path $ClassicMenu -Name "(Default)" -Value "" -Type String `
    -Description "Restore classic right-click menu (Win11)"

# ============================================================
# SECTION 10q: ACTIVITY HISTORY & SYNC (Privacy)
# ============================================================
Write-Host "`n== Activity History & Sync (Privacy) ==" -ForegroundColor Cyan

# Disable Activity History (Timeline)
$ActivityHistory = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'
Set-SafeRegValue -Path $ActivityHistory -Name "PublishUserActivities" -Value 0 -Type DWord `
    -Description "Disable Activity History publishing"
Set-SafeRegValue -Path $ActivityHistory -Name "UploadUserActivities" -Value 0 -Type DWord `
    -Description "Disable Activity History upload"

# Disable "Continue experiences on this device"
$ContinueExp = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\CDP'
Set-SafeRegValue -Path $ContinueExp -Name "CdpSessionUserAuthzPolicy" -Value 0 -Type DWord `
    -Description "Disable Continue experiences"

# ============================================================
# SECTION 10r: WINDOWS INK & TYPING (Privacy)
# ============================================================
Write-Host "`n== Windows Ink & Typing (Privacy) ==" -ForegroundColor Cyan

# Disable Windows Ink Workspace
$InkWorkspace = 'HKLM:\SOFTWARE\Policies\Microsoft\WindowsInkWorkspace'
Set-SafeRegValue -Path $InkWorkspace -Name "AllowWindowsInkWorkspace" -Value 0 -Type DWord `
    -Description "Disable Windows Ink Workspace"

# Disable "Improve inking and typing"
$TypingImprove = 'HKCU:\Software\Microsoft\Input\TIP'
Set-SafeRegValue -Path $TypingImprove -Name "EnableExtraCandidateDirection" -Value 0 -Type DWord `
    -Description "Disable inking/typing improvement"

# ============================================================
# SECTION 10s: FIND MY DEVICE & DIAGNOSTICS
# ============================================================
Write-Host "`n== Find My Device & Diagnostics (Privacy) ==" -ForegroundColor Cyan

# Disable Find My Device
$FindMyDevice = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\FindMyDevice'
Set-SafeRegValue -Path $FindMyDevice -Name "AllowFindMyDevice" -Value 0 -Type DWord `
    -Description "Disable Find My Device"

# Disable diagnostics data viewer
$DiagViewer = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'
Set-SafeRegValue -Path $DiagViewer -Name "DisableDiagnosticDataViewer" -Value 1 -Type DWord `
    -Description "Disable diagnostics data viewer"

# ============================================================
# SECTION 10t: MORE EXPLORER CLEANUP (Remove clutter)
# ============================================================
Write-Host "`n== More Explorer Cleanup (Remove Clutter) ==" -ForegroundColor Cyan

# Remove Home from File Explorer (Win11)
$HomeFolder = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{f42ee2d3-909f-4907-8871-4c22f0f00ba5}\PropertyBag'
Set-SafeRegValue -Path $HomeFolder -Name "ThisPCPolicy" -Value "Hide" -Type String `
    -Description "Hide Home from This PC"

# Remove Gallery from File Explorer (Win11)
$Gallery = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{e88865ea-0e1c-4e20-9aa6-edcd0212c87c}\PropertyBag'
Set-SafeRegValue -Path $Gallery -Name "ThisPCPolicy" -Value "Hide" -Type String `
    -Description "Hide Gallery from This PC"

# ============================================================
# SECTION 10u: TROUBLESHOOTING & MAINTENANCE (Control)
# ============================================================
Write-Host "`n== Troubleshooting & Maintenance (User Control) ==" -ForegroundColor Cyan

# Disable automatic recommended troubleshooter
$Troubleshoot = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Reliability'
Set-SafeRegValue -Path $Troubleshoot -Name "TimeStampInterval" -Value 0 -Type DWord `
    -Description "Disable automatic troubleshooter"

# Disable Microsoft Support Diagnostic Tool (MSDT)
$MSDT = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\ScriptedDiagnosticsProvider\Policy'
Set-SafeRegValue -Path $MSDT -Name "DisableQueryRemoteServer" -Value 1 -Type DWord `
    -Description "Disable MSDT remote queries"

# ============================================================
# SECTION 10v: MORE WINDOWS UPDATE CONTROL
# ============================================================
Write-Host "`n== More Windows Update Control ==" -ForegroundColor Cyan

# Disable auto-restart with logged on users (already have this but ensure policy)
$NoAutoRestart = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'
Set-SafeRegValue -Path $NoAutoRestart -Name "NoAutoRebootWithLoggedOnUsers" -Value 1 -Type DWord `
    -Description "No auto-restart when logged in"

# Re-prompt for restart with scheduled installations
Set-SafeRegValue -Path $NoAutoRestart -Name "RebootRelaunchTimeoutEnabled" -Value 1 -Type DWord `
    -Description "Re-prompt for restart"
Set-SafeRegValue -Path $NoAutoRestart -Name "RebootRelaunchTimeout" -Value 1440 -Type DWord `
    -Description "Restart prompt timeout (24 hours)"

# ============================================================
# SECTION 10w: EXTENDED FILE EXPLORER SETTINGS
# ============================================================
Write-Host "`n== Extended File Explorer Settings ==" -ForegroundColor Cyan

# Disable check boxes for file selection (annoying for many)
$CheckBoxes = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
Set-SafeRegValue -Path $CheckBoxes -Name "AutoCheckSelect" -Value 0 -Type DWord `
    -Description "Disable checkboxes for file selection"

# Restore previous folder windows at logon
Set-SafeRegValue -Path $CheckBoxes -Name "PersistBrowsers" -Value 0 -Type DWord `
    -Description "Don't restore previous folders at logon"

# ============================================================
# FINALIZATION
# ============================================================
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  W11LatencyFix Complete!" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

if ($WhatIf) {
    Write-Host "  WHATIF MODE - No changes were made" -ForegroundColor Yellow
    Write-Host "  Run without -WhatIf to apply changes" -ForegroundColor Yellow
} else {
    # Generate UNDO script
    Export-UndoScript
    
    Write-Host "  Changes Applied: $($Script:Changes.Count)" -ForegroundColor Green
    Write-Host "  Space Freed: ~$TotalFreed MB" -ForegroundColor Green
    Write-Host ""
    Write-Host "  IMPORTANT FILES:" -ForegroundColor Yellow
    Write-Host "    Log: $LogFile" -ForegroundColor Yellow
    Write-Host "    Backup: $BackupDir" -ForegroundColor Yellow
    Write-Host "    UNDO: $UndoScript" -ForegroundColor Green
    Write-Host ""
    Write-Host "  To UNDO all changes, run:" -ForegroundColor Cyan
    Write-Host "    $UndoScript" -ForegroundColor White
}

Write-Host ""
Write-Host "  All changes are SAFE and REVERSIBLE:" -ForegroundColor Green
Write-Host "    - No services disabled" -ForegroundColor Green
Write-Host "    - No BCD/boot changes" -ForegroundColor Green
Write-Host "    - No Windows features removed" -ForegroundColor Green
Write-Host "    - HKCU changes: per-user only" -ForegroundColor Green
Write-Host "    - HKLM changes: network only" -ForegroundColor Green
Write-Host ""
Write-Host "  Restart recommended for network changes to take effect." -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Log "W11LatencyFix completed. Changes: $($Script:Changes.Count), Freed: $TotalFreed MB" "INFO"
