#Requires -Version 5.1
# W11LatencyFix UNDO Launcher - Dynamically finds latest UNDO script

param()

# Self-elevate
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "Requesting Administrator rights..." -ForegroundColor Yellow
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

$LogDir = "$env:SystemDrive\W11LatencyFixLogs"
if (-not (Test-Path $LogDir)) {
    Write-Host "ERROR: No W11LatencyFix log directory found at $LogDir" -ForegroundColor Red
    Read-Host "Press ENTER to exit"
    exit 1
}

# Find the most recent backup UNDO script
$latestUndo = Get-ChildItem "$LogDir\Backups_*\UNDO.ps1" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $latestUndo) {
    Write-Host "ERROR: No UNDO script found in $LogDir" -ForegroundColor Red
    Write-Host "Run W11LatencyFix.ps1 first to generate an UNDO script." -ForegroundColor Yellow
    Read-Host "Press ENTER to exit"
    exit 1
}

Write-Host "Found UNDO: $($latestUndo.FullName)" -ForegroundColor Cyan
Write-Host "Running UNDO script..." -ForegroundColor White

# Execute with error capture
try {
    & $latestUndo.FullName
    Write-Host "`n========================================" -ForegroundColor Green
    Write-Host "UNDO script finished!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "  NOTE: Restart recommended to complete undo." -ForegroundColor Yellow
} catch {
    Write-Host "`n========================================" -ForegroundColor Red
    Write-Host "UNDO script failed!" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "  Error: $_" -ForegroundColor Yellow
}

Write-Host "`nPress ENTER to close this window..." -ForegroundColor Yellow
Read-Host
