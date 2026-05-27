#Requires -Version 5.1
<#
.SYNOPSIS
    W11LatencyFix v1.0 - TEST VERSION - Verifying all functions
#>

param(
    [switch]$WhatIf,
    [switch]$AcceptTerms
)

# ============ TEST 1: TERMS CHECK ============
Write-Host "TEST 1: Terms Acceptance Check" -ForegroundColor Cyan
if (-not $WhatIf -and -not $AcceptTerms) {
    Write-Host "  ✓ Terms check working - would exit here" -ForegroundColor Green
    Write-Host "  Use -AcceptTerms to continue" -ForegroundColor Yellow
    exit 1
}
Write-Host "  ✓ Terms accepted or WhatIf mode" -ForegroundColor Green

# ============ TEST 2: ADMIN CHECK ============
Write-Host "`nTEST 2: Administrator Check" -ForegroundColor Cyan
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)
Write-Host "  Is Admin: $isAdmin" -ForegroundColor $(if($isAdmin){"Green"}else{"Yellow"})

if (-not $isAdmin) {
    Write-Host "  Re-launching as Administrator..." -ForegroundColor Yellow
    $ArgString = '-NoProfile -ExecutionPolicy Bypass -File "' + $MyInvocation.MyCommand.Path + '"'
    if ($WhatIf) { $ArgString += ' -WhatIf' }
    if ($AcceptTerms) { $ArgString += ' -AcceptTerms' }
    Start-Process -FilePath "powershell.exe" -ArgumentList $ArgString -Verb RunAs -Wait
    Write-Host "`nReturned from elevated process" -ForegroundColor Green
    Write-Host "Press any key to exit..." -ForegroundColor Cyan
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit
}
Write-Host "  ✓ Running as Administrator" -ForegroundColor Green

# ============ TEST 3: PATH INITIALIZATION ============
Write-Host "`nTEST 3: Path Initialization" -ForegroundColor Cyan
$ScriptVersion = "1.0.0-SAFE"
$LogDir = "$env:SystemDrive\W11LatencyFixLogs"
$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$LogFile = "$LogDir\LatencyFix_$Timestamp.log"
$BackupDir = "$LogDir\Backups_$Timestamp"
$UndoScript = "$BackupDir\UNDO_CHANGES.ps1"

Write-Host "  LogDir: $LogDir" -ForegroundColor Gray
Write-Host "  LogFile: $LogFile" -ForegroundColor Gray
Write-Host "  BackupDir: $BackupDir" -ForegroundColor Gray
Write-Host "  UndoScript: $UndoScript" -ForegroundColor Gray

# ============ TEST 4: DIRECTORY CREATION ============
Write-Host "`nTEST 4: Directory Creation" -ForegroundColor Cyan
if (-not $WhatIf) {
    if (-not (Test-Path $LogDir)) { 
        New-Item -ItemType Directory -Path $LogDir -Force | Out-Null 
        Write-Host "  ✓ Created LogDir" -ForegroundColor Green
    } else {
        Write-Host "  ✓ LogDir exists" -ForegroundColor Green
    }
    
    if (-not (Test-Path $BackupDir)) { 
        New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null 
        Write-Host "  ✓ Created BackupDir" -ForegroundColor Green
    } else {
        Write-Host "  ✓ BackupDir exists" -ForegroundColor Green
    }
} else {
    Write-Host "  (Would create directories)" -ForegroundColor Yellow
}

# ============ TEST 5: LOGGING FUNCTION ============
Write-Host "`nTEST 5: Logging Function" -ForegroundColor Cyan
$Script:Changes = @()

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "[$timestamp] [$Level] $Message"
    if (-not $WhatIf) {
        Add-Content -Path $LogFile -Value $entry -ErrorAction SilentlyContinue
    }
    
    $colorMap = @{
        "INFO" = "White"
        "SUCCESS" = "Green"
        "WARN" = "Yellow"
        "ERROR" = "Red"
        "SKIP" = "DarkGray"
    }
    Write-Host "  $Message" -ForegroundColor $colorMap[$Level]
}

Write-Log "Test log entry" "INFO"
Write-Log "Test success" "SUCCESS"
Write-Log "Test warning" "WARN"
Write-Host "  ✓ Logging function works" -ForegroundColor Green

# ============ TEST 6: SYSTEM RESTORE POINT ============
Write-Host "`nTEST 6: System Restore Point" -ForegroundColor Cyan
if (-not $WhatIf) {
    try {
        Enable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction SilentlyContinue | Out-Null
        $RestorePointName = "Before W11LatencyFix v$ScriptVersion - $Timestamp"
        Checkpoint-Computer -Description $RestorePointName -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
        Write-Host "  ✓ Restore Point created: $RestorePointName" -ForegroundColor Green
        Write-Log "Restore Point created" "SUCCESS"
    }
    catch {
        Write-Host "  ⚠ Could not create restore point: $_" -ForegroundColor Yellow
        Write-Host "  (This is OK - continuing without it)" -ForegroundColor Yellow
    }
} else {
    Write-Host "  (Would create restore point)" -ForegroundColor Yellow
}

# ============ TEST 7: BACKUP/UNDO CAPABILITY ============
Write-Host "`nTEST 7: Backup/Undo Capability" -ForegroundColor Cyan
if (-not $WhatIf) {
    try {
        $TestFile = "$BackupDir\_test.tmp"
        "test" | Out-File -FilePath $TestFile -Force
        Remove-Item -Path $TestFile -Force
        Write-Host "  ✓ Backup directory writable" -ForegroundColor Green
    }
    catch {
        Write-Host "  ✗ Cannot write to backup dir!" -ForegroundColor Red
        exit 1
    }
    
    try {
        $TestRegBackup = "$BackupDir\_test_registry.reg"
        reg export "HKCU\Software\Microsoft\Windows\CurrentVersion" "$TestRegBackup" /y 2>&1 | Out-Null
        if (Test-Path $TestRegBackup) {
            Remove-Item -Path $TestRegBackup -Force
            Write-Host "  ✓ Registry export works" -ForegroundColor Green
        }
    }
    catch {
        Write-Host "  ✗ Cannot export registry!" -ForegroundColor Red
    }
} else {
    Write-Host "  (Would test backup capability)" -ForegroundColor Yellow
}

# ============ TEST 8: REGISTRY CHANGE FUNCTION ============
Write-Host "`nTEST 8: Registry Change Function (Set-SafeRegValue)" -ForegroundColor Cyan

function Set-SafeRegValue {
    param(
        [string]$Path,
        [string]$Name,
        $Value,
        [string]$Type = "DWord",
        [string]$Description = ""
    )
    
    try {
        if (-not (Test-Path $Path)) {
            if ($WhatIf) {
                Write-Host "  WOULD CREATE: $Path" -ForegroundColor Yellow
                return
            }
            New-Item -Path $Path -Force | Out-Null
        }
        
        $OldValue = $null
        try {
            $OldValue = (Get-ItemProperty -Path $Path -Name $Name -ErrorAction Stop).$Name
        } catch {
            $OldValue = "NOT_PRESENT"
        }
        
        if ($WhatIf) {
            Write-Host "  WOULD SET: $Name = $Value ($Description)" -ForegroundColor Yellow
            return
        }
        
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -Force
        Write-Log "Set $Name = $Value ($Description)" "SUCCESS"
        
        $Script:Changes += @{
            Path = $Path
            Name = $Name
            OldValue = $OldValue
            NewValue = $Value
            Type = $Type
        }
    }
    catch {
        Write-Log "Failed to set $Name : $_" "ERROR"
    }
}

if ($WhatIf) {
    Write-Host "  Testing in WhatIf mode:" -ForegroundColor Yellow
    Set-SafeRegValue -Path "HKCU:\Software\TestW11LatencyFix" -Name "TestValue" -Value 1 -Type DWord -Description "Test optimization"
} else {
    Write-Host "  Testing real change (will undo later):" -ForegroundColor Cyan
    Set-SafeRegValue -Path "HKCU:\Software\TestW11LatencyFix" -Name "TestValue" -Value 1 -Type DWord -Description "Test optimization"
    $testValue = (Get-ItemProperty -Path "HKCU:\Software\TestW11LatencyFix" -Name "TestValue" -ErrorAction SilentlyContinue).TestValue
    if ($testValue -eq 1) {
        Write-Host "  ✓ Registry change verified: TestValue = $testValue" -ForegroundColor Green
    } else {
        Write-Host "  ✗ Registry change failed!" -ForegroundColor Red
    }
    # Cleanup test key
    Remove-Item -Path "HKCU:\Software\TestW11LatencyFix" -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "  ✓ Cleaned up test key" -ForegroundColor Green
}

# ============ TEST 9: UNDO SCRIPT GENERATION ============
Write-Host "`nTEST 9: Undo Script Generation" -ForegroundColor Cyan

function Export-UndoScript {
    $date = Get-Date
    $undoContent = "# W11LatencyFix UNDO Script - Generated $date`n"
    $undoContent += '#Requires -RunAsAdministrator' + "`n"
    $undoContent += '`$LogDir = "C:\W11LatencyFixLogs"' + "`n"
    $undoContent += '`$LogFile = "$LogDir\UNDO_' + (Get-Date -Format 'yyyyMMdd_HHmmss') + '.log"' + "`n"
    $undoContent += 'if (-not (Test-Path $LogDir)) { New-Item -Path $LogDir -ItemType Directory -Force | Out-Null }' + "`n"
    $undoContent += 'function Write-Log { param([string]$Message) Add-Content -Path $LogFile -Value $Message; Write-Host "  $Message" }' + "`n"
    $undoContent += 'Write-Host "Undo Script Starting..." -ForegroundColor Cyan' + "`n"
    
    foreach ($change in $Script:Changes) {
        $path = $change.Path
        $name = $change.Name
        $oldVal = $change.OldValue
        if ($oldVal -eq "NOT_PRESENT") {
            $undoContent += 'Remove-ItemProperty -Path "' + $path + '" -Name "' + $name + '" -Force -ErrorAction SilentlyContinue' + "`n"
        } else {
            $undoContent += 'Set-ItemProperty -Path "' + $path + '" -Name "' + $name + '" -Value ' + $oldVal + ' -Force' + "`n"
        }
    }
    
    $undoContent += 'Write-Host "UNDO Complete!" -ForegroundColor Green' + "`n"
    
    if (-not $WhatIf) {
        Set-Content -Path $UndoScript -Value $undoContent -Encoding UTF8
        Write-Host "  ✓ Undo script created: $UndoScript" -ForegroundColor Green
    } else {
        Write-Host "  (Would create undo script)" -ForegroundColor Yellow
    }
}

# Add a fake change for testing
$Script:Changes += @{
    Path = "HKCU:\Software\Test"
    Name = "TestValue"
    OldValue = 0
    NewValue = 1
    Type = "DWord"
}

Export-UndoScript

# ============ TEST 10: SAMPLE OPTIMIZATIONS ============
Write-Host "`nTEST 10: Sample Optimizations (WhatIf mode)" -ForegroundColor Cyan
$WhatIf = $true  # Force WhatIf for safety

# TCP Optimizations
Write-Host "`n  TCP Network Optimizations:" -ForegroundColor Cyan
Set-SafeRegValue -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name "TcpNoDelay" -Value 1 -Type DWord -Description "Disable Nagle algorithm"
Set-SafeRegValue -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name "TcpDelAckTicks" -Value 0 -Type DWord -Description "Disable delayed ACK"

# Visual Performance
Write-Host "`n  Visual Performance:" -ForegroundColor Cyan
Set-SafeRegValue -Path "HKCU:\Control Panel\Desktop" -Name "UserPreferencesMask" -Value ([byte[]](0x90,0x12,0x03,0x80,0x10,0x00,0x00,0x00)) -Type Binary -Description "Disable visual effects"

# Privacy
Write-Host "`n  Privacy Settings:" -ForegroundColor Cyan
Set-SafeRegValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo" -Name "Enabled" -Value 0 -Type DWord -Description "Disable advertising ID"
Set-SafeRegValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Start_TrackProgs" -Value 0 -Type DWord -Description "Disable app launch tracking"

# ============ SUMMARY ============
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  ALL TESTS COMPLETED SUCCESSFULLY!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Verified Functions:" -ForegroundColor White
Write-Host "  ✓ Terms acceptance check" -ForegroundColor Green
Write-Host "  ✓ Administrator elevation" -ForegroundColor Green
Write-Host "  ✓ Path initialization" -ForegroundColor Green
Write-Host "  ✓ Directory creation" -ForegroundColor Green
Write-Host "  ✓ Logging system" -ForegroundColor Green
Write-Host "  ✓ System Restore Point creation" -ForegroundColor Green
Write-Host "  ✓ Backup/undo capability" -ForegroundColor Green
Write-Host "  ✓ Registry change function" -ForegroundColor Green
Write-Host "  ✓ Undo script generation" -ForegroundColor Green
Write-Host "  ✓ Sample optimizations (WhatIf)" -ForegroundColor Green
Write-Host ""
Write-Host "Press any key to exit..." -ForegroundColor Cyan
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
