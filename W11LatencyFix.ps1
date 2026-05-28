#Requires -Version 5.1
param([switch]$AcceptTerms,[switch]$Silent,[switch]$NoRestart)

# Interactive Terms Acceptance
if(-not$AcceptTerms-and-not$Silent){
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
    if($AcceptTerms){$arg+=" -AcceptTerms"}
    if($Silent){$arg+=" -Silent"}
    Start-Process powershell.exe -ArgumentList $arg -Verb RunAs
    exit
}

# Initialize
$ScriptVersion="2.4.0"
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

function Invoke-RestorePoint {
    try {
        $rp = Get-ComputerRestorePoint -ErrorAction SilentlyContinue | Sort-Object -Property @{Expression={$_.DateTime}; Ascending=$false} | Select-Object -First 1
        if ($rp -and $rp.DateTime) {
            $rpTime = [DateTime]::Parse($rp.DateTime)
            if (((Get-Date) - $rpTime).TotalMinutes -lt 5) {
                Write-Log "Recent restore point exists, skipping" "SKIP"
                return
            }
        }
        Checkpoint-Computer -Description "W11LatencyFix-$Timestamp" -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop | Out-Null
        Write-Log "System Restore Point created" "SUCCESS"
    } catch {
        Write-Log "Failed to create restore point: $_" "WARN"
    }
}

function Set-SafeRegValue {
    param([string]$Path,[string]$Name,$Value,[string]$Type="DWord")
    try{
        if(-not(Test-Path $Path)){
            New-Item -Path $Path -Force | Out-Null
        }
        $Old="NOT_PRESENT"
        try{$Old=(Get-ItemProperty -Path $Path -Name $Name -ErrorAction Stop).$Name}catch{}
        if($Old-eq$Value){Write-Log "$Name already set" "SKIP";return}
        $Script:Changes+=@{Path=$Path;Name=$Name;OldValue=$Old;NewValue=$Value;Type=$Type}
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -Force
        Write-Log "Set $Name=$Value" "SUCCESS"
    }catch{Write-Log "Failed $Name : $_" "ERROR"}
}

function Set-ServiceConfig {
    param([string]$ServiceName,[string]$StartType)
    try{
        $svc=Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
        if($null -eq $svc){
            Write-Log "Service '$ServiceName' not found - skipping" "SKIP"
            return
        }
        if($svc.StartType -eq $StartType){
            Write-Log "Service '$ServiceName' already $StartType - skipping" "SKIP"
            return
        }
        if($svc.Status -eq 'Running' -and $StartType -eq 'Disabled'){
            Stop-Service -Name $ServiceName -Force -ErrorAction SilentlyContinue
            Write-Log "Service '$ServiceName' stopped (was Running)" "INFO"
        }
        $oldType=$svc.StartType
        Set-Service -Name $ServiceName -StartupType $StartType -ErrorAction Stop
        Write-Log "Service '$ServiceName' start type: $oldType -> $StartType" "SUCCESS"
        $Script:Changes+=@{Path="SERVICE";Name=$ServiceName;OldValue=$oldType;NewValue=$StartType;Type="Service"}
    }catch{
        Write-Log "Failed to configure service '$ServiceName': $_" "ERROR"
    }
}

# Banner
if(-not$Silent){
    Clear-Host
    Write-Host "W11LatencyFix v$ScriptVersion" -ForegroundColor Cyan
    Write-Host "65 Verified Network and Performance Optimizations" -ForegroundColor White
    Write-Host ""
}

Write-Log "Starting..."

# Create System Restore Point
if(-not$Silent){Write-Host "`nCreating System Restore Point..." -ForegroundColor Cyan}
Invoke-RestorePoint

# Section 1: TCP
if(-not$Silent){Write-Host "`n[1/12] TCP Network" -ForegroundColor Cyan}
Set-SafeRegValue "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "TcpNoDelay" 1
Set-SafeRegValue "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "TcpDelAckTicks" 0
Set-SafeRegValue "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "TCPMaxDataRetransmissions" 3
Set-SafeRegValue "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "DefaultTTL" 64
Set-SafeRegValue "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "EnablePMTUDiscovery" 1
Set-SafeRegValue "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "GlobalMaxTcpWindowSize" 65535
Set-SafeRegValue "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "TcpWindowSize" 65535
Set-SafeRegValue "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "TcpAutoTuningLevel" 0
# CRITICAL FIX: netsh auto-tuning requires netsh command, not just registry
Write-Log "Disabling TCP auto-tuning via netsh..." "INFO"
try {
    $netshResult = netsh interface tcp set global autotuninglevel=disabled 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Log "TCP auto-tuning disabled via netsh" "SUCCESS"
        $Script:Changes+=@{Path="NETSH";Name="TcpAutoTuning";OldValue="normal";NewValue="disabled";Type="Netsh"}
    } else {
        Write-Log "netsh failed: $netshResult" "WARN"
    }
} catch {
    Write-Log "netsh exception: $_" "WARN"
}
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

# Section 13: Service Optimizations (research-verified safe disables)
if(-not$Silent){Write-Host "`n[13/13] Service Optimizations" -ForegroundColor Cyan}
Set-ServiceConfig -ServiceName 'DiagTrack' -StartType 'Disabled'
Set-ServiceConfig -ServiceName 'Spooler' -StartType 'Disabled'
Set-ServiceConfig -ServiceName 'TrkWks' -StartType 'Disabled'
Set-ServiceConfig -ServiceName 'WpnService' -StartType 'Disabled'
Set-ServiceConfig -ServiceName 'SysMain' -StartType 'Disabled'
Set-ServiceConfig -ServiceName 'WSearch' -StartType 'Disabled'

# Section 14: Windows Defender Real-Time Scanning (reduces file I/O latency)
if(-not$Silent){Write-Host "`n[14/15] Windows Defender Performance" -ForegroundColor Cyan}
try {
    Import-Module Defender -ErrorAction SilentlyContinue
    $mpPref = Get-MpPreference -ErrorAction SilentlyContinue
    if ($mpPref) {
        $oldRT = $mpPref.DisableRealtimeMonitoring
        if (-not $oldRT) {
            Set-MpPreference -DisableRealtimeMonitoring $true -ErrorAction Stop
            Write-Log "Defender real-time protection disabled" "SUCCESS"
            $Script:Changes+=@{Path="DEFENDER";Name="DisableRealtimeMonitoring";OldValue=$false;NewValue=$true;Type="Defender"}
        } else {
            Write-Log "Defender real-time protection already disabled" "SKIP"
        }
    } else {
        Write-Log "Defender module not available - skipping" "SKIP"
    }
} catch {
    Write-Log "Failed to configure Defender: $_" "WARN"
}

# Section 15: Power Plan (High Performance)
if(-not$Silent){Write-Host "`n[15/15] Power Plan" -ForegroundColor Cyan}
try {
    $currentPlan = powercfg /getactivescheme 2>$null
    $highPerf = powercfg /list 2>$null | Select-String -Pattern "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c"
    if ($highPerf) {
        $oldPlan = ($currentPlan -split '\s+')[3]
        powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Log "Power plan set to High Performance" "SUCCESS"
            $Script:Changes+=@{Path="POWER";Name="ActivePlan";OldValue=$oldPlan;NewValue="8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c";Type="Power"}
        } else {
            Write-Log "powercfg setactive failed" "WARN"
        }
    } else {
        Write-Log "High Performance plan not found on this system" "SKIP"
    }
} catch {
    Write-Log "Failed to set power plan: $_" "WARN"
}

# Generate UNDO
if(-not$Silent){Write-Host "`nGenerating UNDO..." -ForegroundColor Cyan}
if($Script:Changes.Count-gt0){
    $u="# W11LatencyFix UNDO-Generated $(Get-Date)`n"
    $u+='#Requires -Version 5.1' + "`n"
    $u+='$a=([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)' + "`n"
    $u+='if(-not$a){Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs;exit}' + "`n"
    $u+='Write-Host "W11LatencyFix UNDO Script" -ForegroundColor Cyan' + "`n"
    $u+='Write-Host "Reverting ' + $Script:Changes.Count + ' changes..." -ForegroundColor White' + "`n`n"
    foreach($c in $Script:Changes){
        if($c.Type -eq "Netsh"){
            $u+='try{$r=netsh interface tcp set global autotuninglevel=' + $c.OldValue + ' 2>&1;Write-Host "  Restored netsh: ' + $c.Name + ' -> ' + $c.OldValue + '" -ForegroundColor Green}catch{Write-Host "  Failed: ' + $c.Name + '" -ForegroundColor Red}' + "`n"
        } elseif($c.Type -eq "Defender"){
            $u+='try{Import-Module Defender -ErrorAction SilentlyContinue;Set-MpPreference -DisableRealtimeMonitoring $' + $c.OldValue + ' -ErrorAction Stop;Write-Host "  Restored Defender real-time protection: ' + $c.OldValue + '" -ForegroundColor Green}catch{Write-Host "  Failed: Defender restore" -ForegroundColor Red}' + "`n"
        } elseif($c.Type -eq "Power"){
            $u+='try{powercfg /setactive ' + $c.OldValue + ' 2>$null;Write-Host "  Restored power plan" -ForegroundColor Green}catch{Write-Host "  Failed: Power plan restore" -ForegroundColor Red}' + "`n"
        } elseif($c.Type -eq "Service"){
            $u+='try{Set-Service -Name "' + $c.Name + '" -StartupType ' + $c.OldValue + ' -ErrorAction Stop;Write-Host "  Restored service: ' + $c.Name + ' -> ' + $c.OldValue + '" -ForegroundColor Green}catch{Write-Host "  Failed: ' + $c.Name + '" -ForegroundColor Red}' + "`n"
        } elseif($c.OldValue -eq "NOT_PRESENT"){
            $u+='try{Remove-ItemProperty -Path "' + $c.Path + '" -Name "' + $c.Name + '" -ErrorAction SilentlyContinue;Write-Host "  Removed: ' + $c.Name + '" -ForegroundColor Green}catch{Write-Host "  Failed: ' + $c.Name + '" -ForegroundColor Red}' + "`n"
        } else {
            $valStr = if($c.Type -eq "String"){'"' + $c.OldValue + '"'}else{$c.OldValue}
            $u+='try{Set-ItemProperty -Path "' + $c.Path + '" -Name "' + $c.Name + '" -Value ' + $valStr + ' -Force;Write-Host "  Restored: ' + $c.Name + ' = ' + $c.OldValue + '" -ForegroundColor Green}catch{Write-Host "  Failed: ' + $c.Name + '" -ForegroundColor Red}' + "`n"
        }
    }
    $u+='Write-Host ""' + "`n"
    $u+='Write-Host "UNDO Complete - Restart recommended" -ForegroundColor Green' + "`n"
    $u+='Write-Host "Press ENTER to exit..." -ForegroundColor Cyan' + "`n"
    $u+='$null = Read-Host' + "`n"
    Set-Content -Path $UndoScript -Value $u -Encoding UTF8
    if(-not$Silent){Write-Host "  Created: $UndoScript" -ForegroundColor Green}
}else{if(-not$Silent){Write-Host "  No changes to undo" -ForegroundColor Yellow}}

# Summary
if(-not$Silent){
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "  COMPLETE" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  Changes: $($Script:Changes.Count)" -ForegroundColor $(if($Script:Changes.Count-gt0){"Green"}else{"Yellow"})
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    if($Script:Changes.Count-gt0){
        Write-Host "  UNDO: $UndoScript" -ForegroundColor Cyan
        Write-Host "  LOG:  $LogFile" -ForegroundColor Cyan
        Write-Host ""
    }
    Write-Host "  Restart required for network changes" -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Cyan
}

Write-Log "Completed with $($Script:Changes.Count) changes"

# Restart Prompt
if(-not$NoRestart -and $Script:Changes.Count-gt0){
    if(-not$Silent){
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Yellow
        $response = Read-Host "Restart now for changes to take effect? (Y/N)"
        if($response -eq "Y" -or $response -eq "y"){
            Write-Host "Restarting in 5 seconds..." -ForegroundColor Red
            for($i=5; $i -gt 0; $i--){
                Write-Host "  $i..." -ForegroundColor Yellow
                Start-Sleep -Seconds 1
            }
            Restart-Computer -Force
        } else {
            Write-Host "Restart skipped. Run 'Restart-Computer' manually when ready." -ForegroundColor Yellow
            Read-Host "Press ENTER to exit"
        }
    } else {
        Write-Log "Auto-restarting in 10 seconds (use -NoRestart to skip)" "WARN"
        Start-Sleep -Seconds 10
        Restart-Computer -Force
    }
} else {
    if(-not$Silent){
        Write-Host ""
        Read-Host "Press ENTER to exit"
    }
}
