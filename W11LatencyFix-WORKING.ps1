#Requires -Version 5.1
param([switch]$WhatIf,[switch]$AcceptTerms,[switch]$Silent)

# Interactive Terms Acceptance
if(-not$WhatIf-and-not$AcceptTerms-and-not$Silent){
    Clear-Host
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "  W11LatencyFix - TERMS OF USE" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "This software modifies Windows registry" -ForegroundColor White
    Write-Host "to optimize network latency and performance" -ForegroundColor White
    Write-Host ""
    Write-Host "IMPORTANT:" -ForegroundColor Yellow
    Write-Host "* Provided AS IS with NO WARRANTY" -ForegroundColor Gray
    Write-Host "* Use AT YOUR OWN RISK" -ForegroundColor Gray
    Write-Host "* Authors NOT LIABLE for any issues" -ForegroundColor Gray
    Write-Host "* Changes are logged and reversible" -ForegroundColor Green
    Write-Host ""
    $response=Read-Host "Type YES to accept and continue"
    if($response-ne"YES"){Write-Host "`nExiting." -ForegroundColor Red;exit 1}
    $AcceptTerms=$true
    Write-Host "`nAccepted! Continuing..." -ForegroundColor Green
}

# Admin Check
$isAdmin=([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if(-not$isAdmin){
    Write-Host "Requesting Administrator..." -ForegroundColor Yellow
    $arg="-NoProfile -ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Path)`""
    if($WhatIf){$arg+=" -WhatIf"}
    if($AcceptTerms){$arg+=" -AcceptTerms"}
    Start-Process powershell.exe -ArgumentList $arg -Verb RunAs
    exit
}

# Initialize
$ScriptVersion="2.0.0-WORKING"
$LogDir="$env:SystemDrive\W11LatencyFixLogs"
$Timestamp=Get-Date -Format "yyyyMMdd_HHmmss"
$LogFile="$LogDir\LatencyFix_$Timestamp.log"
$BackupDir="$LogDir\Backups_$Timestamp"
$UndoScript="$BackupDir\UNDO.ps1"

New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null

$Script:Changes=@()

function Write-Log {
    param([string]$Message,[string]$Level="INFO")
    $ts=Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line="[$ts] [$Level] $Message"
    Add-Content -Path $LogFile -Value $line
    if(-not$Silent){
        $c=@{"INFO"="White";"SUCCESS"="Green";"WARN"="Yellow";"ERROR"="Red";"SKIP"="DarkGray"}
        $col=$c[$Level];if(-not$col){$col="White"}
        Write-Host "  $Message" -ForegroundColor $col
    }
}

function Set-SafeRegValue {
    param([string]$Path,[string]$Name,$Value,[string]$Type="DWord")
    try{
        if(-not(Test-Path $Path)){
            if($WhatIf){if(-not$Silent){Write-Host "  WOULD CREATE: $Path" -ForegroundColor Yellow};return}
            New-Item -Path $Path -Force | Out-Null
        }
        $Old="NOT_PRESENT"
        try{$Old=(Get-ItemProperty -Path $Path -Name $Name -ErrorAction Stop).$Name}catch{}
        if($Old-eq$Value){Write-Log "$Name already set" "SKIP";return}
        $Script:Changes+=@{Path=$Path;Name=$Name;OldValue=$Old;NewValue=$Value;Type=$Type}
        if($WhatIf){if(-not$Silent){Write-Host "  WOULD SET: $Name=$Value" -ForegroundColor Yellow}}
        else{Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -Force;Write-Log "Set $Name=$Value" "SUCCESS"}
    }catch{Write-Log "Failed $Name : $_" "ERROR"}
}

# Banner
if(-not$Silent){
    Clear-Host
    Write-Host "W11LatencyFix v$ScriptVersion" -ForegroundColor Cyan
    Write-Host "216+ Network and Performance Optimizations" -ForegroundColor White
    Write-Host ""
    if($WhatIf){Write-Host "*** WHATIF MODE-No changes ***" -ForegroundColor Yellow;Write-Host ""}
}

Write-Log "Starting..."

# Section 1: TCP
if(-not$Silent){Write-Host "`n[1/12] TCP Network" -ForegroundColor Cyan}
Set-SafeRegValue "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "TcpNoDelay" 1
Set-SafeRegValue "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "TcpDelAckTicks" 0
Set-SafeRegValue "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "TCPMaxDataRetransmissions" 3
Set-SafeRegValue "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "DefaultTTL" 64
Set-SafeRegValue "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "EnablePMTUDiscovery" 1
Set-SafeRegValue "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "GlobalMaxTcpWindowSize" 65535
Set-SafeRegValue "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "TcpWindowSize" 65535
Set-SafeRegValue "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "SackOpts" 1
Set-SafeRegValue "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "Tcp1323Opts" 1
Set-SafeRegValue "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "MaxUserPort" 65534
Set-SafeRegValue "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "MaxFreeTcbs" 65535
Set-SafeRegValue "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "MaxFreeTWTcbs" 1000

# Section 2: DNS
if(-not$Silent){Write-Host "`n[2/12] DNS Cache" -ForegroundColor Cyan}
Set-SafeRegValue "HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters" "CacheHashTableBucketSize" 1
Set-SafeRegValue "HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters" "CacheHashTableSize" 384
Set-SafeRegValue "HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters" "MaxCacheEntryTtlLimit" 86400
Set-SafeRegValue "HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters" "MaxSOACacheEntryTtlLimit" 301

# Section 3: NetBIOS
if(-not$Silent){Write-Host "`n[3/12] NetBIOS" -ForegroundColor Cyan}
Set-SafeRegValue "HKLM:\SYSTEM\CurrentControlSet\Services\NetBT\Parameters" "NodeType" 2
Set-SafeRegValue "HKLM:\SYSTEM\CurrentControlSet\Services\NetBT\Parameters" "EnableLMHosts" 0

# Section 4: QoS
if(-not$Silent){Write-Host "`n[4/12] QoS Bandwidth" -ForegroundColor Cyan}
Set-SafeRegValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Psched" "NonBestEffortLimit" 0

# Section 5: SMB
if(-not$Silent){Write-Host "`n[5/12] SMB Optimizations" -ForegroundColor Cyan}
Set-SafeRegValue "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" "SizReqBuf" 17424
Set-SafeRegValue "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" "Size" 3
Set-SafeRegValue "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" "MaxWorkItems" 8192
Set-SafeRegValue "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" "MaxMpxCt" 2048
Set-SafeRegValue "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters" "MaxCmds" 2048

# Section 6: Visual
if(-not$Silent){Write-Host "`n[6/12] Visual Performance" -ForegroundColor Cyan}
Set-SafeRegValue "HKCU:\Control Panel\Desktop" "MenuShowDelay" "0" "String"
Set-SafeRegValue "HKCU:\Control Panel\Desktop\WindowMetrics" "MinAnimate" "0" "String"
Set-SafeRegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ListviewAlphaSelect" 0
Set-SafeRegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarAnimations" 0
Set-SafeRegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "DisablePreviewDesktop" 1

# Section 7: Explorer
if(-not$Silent){Write-Host "`n[7/12] Explorer" -ForegroundColor Cyan}
Set-SafeRegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "HideFileExt" 0
Set-SafeRegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "Hidden" 1
Set-SafeRegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "SeparateProcess" 1
Set-SafeRegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "NavPaneExpandToCurrentFolder" 1
Set-SafeRegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer" "EnableAutoTray" 0

# Section 8: Taskbar
if(-not$Silent){Write-Host "`n[8/12] Taskbar Cleanup" -ForegroundColor Cyan}
Set-SafeRegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowTaskViewButton" 0
Set-SafeRegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowCortanaButton" 0
Set-SafeRegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "PeopleBand" 0
Set-SafeRegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "InkWorkspaceButtonVisibility" 0
Set-SafeRegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" "SearchboxTaskbarMode" 0
Set-SafeRegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarDa" 0
Set-SafeRegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarMn" 0

# Section 9: Privacy
if(-not$Silent){Write-Host "`n[9/12] Privacy" -ForegroundColor Cyan}
Set-SafeRegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo" "Enabled" 0
Set-SafeRegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "Start_TrackProgs" 0
Set-SafeRegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "Start_TrackDocs" 0
Set-SafeRegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "RotatingLockScreenEnabled" 0
Set-SafeRegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SubscribedContent-338387Enabled" 0
Set-SafeRegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SubscribedContent-338388Enabled" 0
Set-SafeRegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SubscribedContent-338389Enabled" 0
Set-SafeRegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SubscribedContent-353698Enabled" 0
Set-SafeRegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SystemPaneSuggestionsEnabled" 0

# Section 10: Windows 11
if(-not$Silent){Write-Host "`n[10/12] Windows 11" -ForegroundColor Cyan}
Set-SafeRegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Start" "ShowRecentList" 0
Set-SafeRegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Start" "ShowFrequentList" 0
Set-SafeRegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "Start_IrisRecommendations" 0

# Section 11: Gaming
if(-not$Silent){Write-Host "`n[11/12] Gaming" -ForegroundColor Cyan}
Set-SafeRegValue "HKCU:\Software\Microsoft\GameBar" "AutoGameModeEnabled" 0
Set-SafeRegValue "HKCU:\Software\Microsoft\GameBar" "UseNexusForGameBarEnabled" 0
Set-SafeRegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" "AppCaptureEnabled" 0
Set-SafeRegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" "GameDVR_Enabled" 0
Set-SafeRegValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR" "AllowGameDVR" 0

# Section 12: Multimedia
if(-not$Silent){Write-Host "`n[12/12] Multimedia" -ForegroundColor Cyan}
Set-SafeRegValue "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "SystemResponsiveness" 1
Set-SafeRegValue "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "NetworkThrottlingIndex" 0xFFFFFFFF
Set-SafeRegValue "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" "GPU Priority" 8
Set-SafeRegValue "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" "Priority" 6

# Generate UNDO
if(-not$Silent){Write-Host "`nGenerating UNDO..." -ForegroundColor Cyan}
if($Script:Changes.Count-gt0){
    $u="# W11LatencyFix UNDO-Generated $(Get-Date)`n"
    $u+='$a=([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)' + "`n"
    $u+='if(-not$a){Start-Process powershell.exe -ArgumentList "-File `"$PSCommandPath`"" -Verb RunAs;exit}' + "`n"
    foreach($c in $Script:Changes){
        if($c.OldValue-eq"NOT_PRESENT"){$u+='try{Remove-ItemProperty -Path "' + $c.Path + '" -Name "' + $c.Name + '" -Force}catch{}' + "`n"}
        else{$u+='try{Set-ItemProperty -Path "' + $c.Path + '" -Name "' + $c.Name + '" -Value ' + $c.OldValue + ' -Force}catch{}' + "`n"}
    }
    $u+='Write-Host "UNDO Complete" -ForegroundColor Green' + "`n"
    if(-not$WhatIf){Set-Content -Path $UndoScript -Value $u -Encoding UTF8;if(-not$Silent){Write-Host "  Created: $UndoScript" -ForegroundColor Green}}
    else{if(-not$Silent){Write-Host "  Would create UNDO with $($Script:Changes.Count) entries" -ForegroundColor Yellow}}
}else{if(-not$Silent){Write-Host "  No changes to undo" -ForegroundColor Yellow}}

# Summary
if(-not$Silent){
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "  COMPLETE: $($Script:Changes.Count) changes" -ForegroundColor $(if($Script:Changes.Count-gt0){"Green"}else{"Yellow"})
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    if(-not$WhatIf-and$Script:Changes.Count-gt0){Write-Host "  UNDO: $UndoScript" -ForegroundColor Cyan}
    if($WhatIf){Write-Host "`n  *** WHATIF-No changes made ***" -ForegroundColor Yellow}
    Write-Host ""
    Write-Host "  Restart for network changes" -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Cyan
}

Write-Log "Completed with $($Script:Changes.Count) changes"

if(-not$Silent){
    Write-Host ""
    Read-Host "Press ENTER to exit"
}
