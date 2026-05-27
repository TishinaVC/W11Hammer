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

# Main optimizations would go here
Write-Host "Script is working!" -ForegroundColor Green

Write-Log "Completed!" "SUCCESS"
