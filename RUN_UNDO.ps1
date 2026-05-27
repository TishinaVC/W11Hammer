#Requires -Version 5.1
param()

# Self-elevate
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "Requesting Administrator rights..." -ForegroundColor Yellow
    $undoPath = "C:\W11LatencyFixLogs\Backups_20260527_074723\UNDO.ps1"
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$undoPath`"" -Verb RunAs
    exit
}

Write-Host "Running UNDO script..." -ForegroundColor Cyan
& "C:\W11LatencyFixLogs\Backups_20260527_074723\UNDO.ps1"

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "UNDO script finished!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "`nPress ENTER to close this window..." -ForegroundColor Yellow
Read-Host
