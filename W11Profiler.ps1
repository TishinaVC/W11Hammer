#Requires -Version 5.1
# W11LatencyFix Real-Time Performance Profiler
# Scientifically measures actual system latency with statistical rigor
# Uses real system calls - no simulations, no hypotheticals

param(
    [ValidateSet("Baseline","PostReboot","Compare")]
    [string]$Mode = "Baseline",
    [string]$BaselineFile,
    [switch]$ExploreRestart,
    [switch]$Silent
)

# Self-elevate
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "Requesting Administrator..." -ForegroundColor Yellow
    $arg = "-NoProfile -ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Path)`" -Mode $Mode"
    if ($BaselineFile) { $arg += " -BaselineFile `"$BaselineFile`"" }
    if ($ExploreRestart) { $arg += " -ExploreRestart" }
    if ($Silent) { $arg += " -Silent" }
    Start-Process powershell.exe -ArgumentList $arg -Verb RunAs
    exit
}

# Output directory
$ProfileDir = "$env:SystemDrive\W11LatencyFixLogs\Profiles"
New-Item -ItemType Directory -Path $ProfileDir -Force | Out-Null

$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$OutputFile = "$ProfileDir\Profile_$Mode`_$Timestamp.json"

# High-resolution timer wrapper
$Script:Freq = [System.Diagnostics.Stopwatch]::Frequency
function Get-ElapsedMicroseconds($sw) {
    return [math]::Round(($sw.ElapsedTicks * 1000000.0) / $Script:Freq, 3)
}

# Statistical analysis
function Get-Statistics {
    param([double[]]$Values)
    $sorted = $Values | Sort-Object
    $n = $Values.Count
    $mean = ($Values | Measure-Object -Average).Average
    $median = if ($n % 2 -eq 0) { ($sorted[$n/2 - 1] + $sorted[$n/2]) / 2 } else { $sorted[($n - 1) / 2] }
    $variance = ($Values | ForEach-Object { [math]::Pow($_ - $mean, 2) } | Measure-Object -Average).Average
    $stddev = [math]::Sqrt($variance)
    return @{
        Samples = $n
        Mean    = [math]::Round($mean, 3)
        Median  = [math]::Round($median, 3)
        StdDev  = [math]::Round($stddev, 3)
        Min     = [math]::Round(($Values | Measure-Object -Minimum).Minimum, 3)
        Max     = [math]::Round(($Values | Measure-Object -Maximum).Maximum, 3)
        Raw     = $Values
    }
}

# Generic micro-benchmark runner
function Measure-MicroBenchmark {
    param(
        [scriptblock]$ScriptBlock,
        [int]$Warmup = 5,
        [int]$Iterations = 30
    )
    # Warmup
    for ($i = 0; $i -lt $Warmup; $i++) { & $ScriptBlock | Out-Null }
    # Actual measurement
    $times = @()
    for ($i = 0; $i -lt $Iterations; $i++) {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        & $ScriptBlock | Out-Null
        $sw.Stop()
        $times += (Get-ElapsedMicroseconds $sw)
    }
    return (Get-Statistics $times)
}

# ============================================================================
# REAL MEASUREMENT FUNCTIONS
# ============================================================================

function Measure-BootTime {
    # Windows measures its own boot time in Event ID 100
    try {
        $ev = Get-WinEvent -FilterHashtable @{LogName = 'Microsoft-Windows-Diagnostics-Performance/Operational'; ID = 100} -MaxEvents 1 -ErrorAction Stop
        $mainPathBoot = $ev.Properties[0].Value   # MainPathBootTime in ms
        $bootPost = $ev.Properties[1].Value       # BootPostBootTime in ms
        return @{
            MainPathBootMs = $mainPathBoot
            BootPostBootMs = $bootPost
            TotalBootMs    = $mainPathBoot + $bootPost
            BootDate       = $ev.TimeCreated.ToString("yyyy-MM-dd HH:mm:ss")
            Valid          = $true
        }
    } catch {
        return @{Valid = $false; Note = "Boot event not found. Reboot required for measurement."}
    }
}

function Measure-NetworkLatency {
    # Ping default gateway (most stable local target)
    $gateway = (Get-NetRoute -DestinationPrefix "0.0.0.0/0" | Select-Object -First 1).NextHop
    if (-not $gateway) { $gateway = "127.0.0.1" }
    
    $ping = New-Object System.Net.NetworkInformation.Ping
    $results = @()
    $lost = 0
    $warmup = 5
    $samples = 50
    
    for ($i = 0; $i -lt ($warmup + $samples); $i++) {
        try {
            $reply = $ping.Send($gateway, 1000)
            if ($i -ge $warmup -and $reply.Status -eq 'Success') {
                $results += [double]$reply.RoundtripTime
            } elseif ($i -ge $warmup) {
                $lost++
            }
        } catch {
            if ($i -ge $warmup) { $lost++ }
        }
        Start-Sleep -Milliseconds 10
    }
    $ping.Dispose()
    
    if ($results.Count -eq 0) {
        return @{Valid = $false; Note = "All packets lost to gateway $gateway"}
    }
    
    $stats = Get-Statistics $results
    $stats.PacketLossPercent = [math]::Round(($lost / $samples) * 100, 1)
    $stats.Target = $gateway
    $stats.Valid = $true
    return $stats
}

function Measure-ProcessCreationLatency {
    # Real CreateProcess overhead: cmd /c exit
    return (Measure-MicroBenchmark -ScriptBlock {
        $p = Start-Process cmd -ArgumentList "/c exit" -PassThru -WindowStyle Hidden
        $p.WaitForExit(2000) | Out-Null
    } -Warmup 5 -Iterations 30)
}

function Measure-MemoryCommitLatency {
    # Real heap allocation / deallocation
    return (Measure-MicroBenchmark -ScriptBlock {
        $ptr = [System.Runtime.InteropServices.Marshal]::AllocHGlobal(4096)
        [System.Runtime.InteropServices.Marshal]::FreeHGlobal($ptr)
    } -Warmup 10 -Iterations 100)
}

function Measure-RegistryReadLatency {
    # Real RegQueryValueEx timing
    $path = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"
    $name = "CurrentVersion"
    return (Measure-MicroBenchmark -ScriptBlock {
        $null = (Get-ItemProperty -Path $path -Name $name -ErrorAction SilentlyContinue).$name
    } -Warmup 10 -Iterations 100)
}

function Measure-FileWriteLatency {
    # Real WriteFile+Flush timing
    $testFile = "$env:TEMP\w11profiler_write_$(Get-Random).tmp"
    $data = New-Object byte[] 4096
    $times = @()
    $warmup = 2
    $runs = 10
    for ($r = 0; $r -lt ($warmup + $runs); $r++) {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $fs = [System.IO.File]::OpenWrite($testFile)
        for ($i = 0; $i -lt 256; $i++) {  # 1MB total
            $fs.Write($data, 0, 4096)
            $fs.Flush()
        }
        $fs.Close()
        $sw.Stop()
        Remove-Item $testFile -ErrorAction SilentlyContinue
        if ($r -ge $warmup) { $times += (Get-ElapsedMicroseconds $sw) }
    }
    $stats = Get-Statistics $times
    $stats.Note = "1MB sequential write in 4KB chunks with flush (10 runs)"
    return $stats
}

function Measure-ExplorerColdStart {
    # Real Explorer.exe cold start (invasive - optional)
    if (-not $ExploreRestart) {
        return @{Valid = $false; Note = "Use -ExploreRestart to measure (kills Explorer)"}
    }
    Write-Host "  Restarting Explorer for cold-start measurement..." -ForegroundColor Yellow
    Get-Process explorer -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep -Milliseconds 500
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $proc = Start-Process explorer -PassThru
    # Wait until shell window is ready
    $timeout = [DateTime]::Now.AddSeconds(10)
    while ($proc.MainWindowHandle -eq 0 -and [DateTime]::Now -lt $timeout) {
        Start-Sleep -Milliseconds 50
        $proc.Refresh()
    }
    $sw.Stop()
    return @{
        Valid      = $true
        StartupUs  = [math]::Round($sw.Elapsed.TotalMilliseconds, 2)
        WindowHandle = $proc.MainWindowHandle
        Note       = "Time from process start to window ready"
    }
}

function Get-OptimizationStates {
    # Read all 61 optimization registry values as they exist RIGHT NOW
    # Returns current state for comparison
    $states = @{}
    $defs = @(
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"; Name="TcpNoDelay"; Expected=1},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"; Name="TcpDelAckTicks"; Expected=0},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"; Name="TCPMaxDataRetransmissions"; Expected=3},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"; Name="DefaultTTL"; Expected=64},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"; Name="EnablePMTUDiscovery"; Expected=1},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"; Name="GlobalMaxTcpWindowSize"; Expected=65535},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"; Name="TcpWindowSize"; Expected=65535},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"; Name="SackOpts"; Expected=1},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"; Name="Tcp1323Opts"; Expected=1},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"; Name="MaxUserPort"; Expected=65534},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"; Name="MaxFreeTcbs"; Expected=65535},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"; Name="MaxFreeTWTcbs"; Expected=1000},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters"; Name="CacheHashTableBucketSize"; Expected=1},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters"; Name="CacheHashTableSize"; Expected=384},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters"; Name="MaxCacheEntryTtlLimit"; Expected=86400},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters"; Name="MaxSOACacheEntryTtlLimit"; Expected=301},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\NetBT\Parameters"; Name="NodeType"; Expected=2},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\NetBT\Parameters"; Name="EnableLMHosts"; Expected=0},
        @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\Psched"; Name="NonBestEffortLimit"; Expected=0},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters"; Name="SizReqBuf"; Expected=17424},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters"; Name="Size"; Expected=3},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters"; Name="MaxWorkItems"; Expected=8192},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters"; Name="MaxMpxCt"; Expected=2048},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters"; Name="MaxCmds"; Expected=2048},
        @{Path="HKCU:\Control Panel\Desktop"; Name="MenuShowDelay"; Expected="0"},
        @{Path="HKCU:\Control Panel\Desktop\WindowMetrics"; Name="MinAnimate"; Expected="0"},
        @{Path="HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name="ListviewAlphaSelect"; Expected=0},
        @{Path="HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name="TaskbarAnimations"; Expected=0},
        @{Path="HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name="DisablePreviewDesktop"; Expected=1},
        @{Path="HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name="HideFileExt"; Expected=0},
        @{Path="HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name="Hidden"; Expected=1},
        @{Path="HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name="SeparateProcess"; Expected=1},
        @{Path="HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name="NavPaneExpandToCurrentFolder"; Expected=1},
        @{Path="HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer"; Name="EnableAutoTray"; Expected=0},
        @{Path="HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name="ShowTaskViewButton"; Expected=0},
        @{Path="HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name="ShowCortanaButton"; Expected=0},
        @{Path="HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name="PeopleBand"; Expected=0},
        @{Path="HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name="InkWorkspaceButtonVisibility"; Expected=0},
        @{Path="HKCU:\Software\Microsoft\Windows\CurrentVersion\Search"; Name="SearchboxTaskbarMode"; Expected=0},
        @{Path="HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name="TaskbarMn"; Expected=0},
        @{Path="HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo"; Name="Enabled"; Expected=0},
        @{Path="HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name="Start_TrackProgs"; Expected=0},
        @{Path="HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name="Start_TrackDocs"; Expected=0},
        @{Path="HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; Name="RotatingLockScreenEnabled"; Expected=0},
        @{Path="HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; Name="SubscribedContent-338387Enabled"; Expected=0},
        @{Path="HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; Name="SubscribedContent-338388Enabled"; Expected=0},
        @{Path="HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; Name="SubscribedContent-338389Enabled"; Expected=0},
        @{Path="HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; Name="SubscribedContent-353698Enabled"; Expected=0},
        @{Path="HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; Name="SystemPaneSuggestionsEnabled"; Expected=0},
        @{Path="HKCU:\Software\Microsoft\Windows\CurrentVersion\Start"; Name="ShowRecentList"; Expected=0},
        @{Path="HKCU:\Software\Microsoft\Windows\CurrentVersion\Start"; Name="ShowFrequentList"; Expected=0},
        @{Path="HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name="Start_IrisRecommendations"; Expected=0},
        @{Path="HKCU:\Software\Microsoft\GameBar"; Name="AutoGameModeEnabled"; Expected=0},
        @{Path="HKCU:\Software\Microsoft\GameBar"; Name="UseNexusForGameBarEnabled"; Expected=0},
        @{Path="HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR"; Name="AppCaptureEnabled"; Expected=0},
        @{Path="HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR"; Name="GameDVR_Enabled"; Expected=0},
        @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR"; Name="AllowGameDVR"; Expected=0},
        @{Path="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"; Name="SystemResponsiveness"; Expected=1},
        @{Path="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"; Name="NetworkThrottlingIndex"; Expected=4294967295},
        @{Path="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"; Name="GPU Priority"; Expected=8},
        @{Path="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"; Name="Priority"; Expected=6}
    )
    foreach ($d in $defs) {
        try {
            $actual = (Get-ItemProperty -Path $d.Path -Name $d.Name -ErrorAction Stop).$($d.Name)
            $states[$d.Name] = @{Current = $actual; Expected = $d.Expected; Applied = ($actual -eq $d.Expected) }
        } catch {
            $states[$d.Name] = @{Current = "NOT_PRESENT"; Expected = $d.Expected; Applied = $false }
        }
    }
    $appliedCount = ($states.Values | Where-Object { $_.Applied }).Count
    return @{Settings = $states; AppliedCount = $appliedCount; Total = $defs.Count}
}

# ============================================================================
# REPORTING
# ============================================================================

function Show-SectionHeader($title) {
    Write-Host ""
    Write-Host "  [$title]" -ForegroundColor Cyan
    Write-Host "  " + ("-" * 50) -ForegroundColor DarkGray
}

function Show-StatLine($label, $stats, $unit = "us") {
    if ($stats.Valid -eq $false) {
        Write-Host "    $label : $($stats.Note)" -ForegroundColor Yellow
        return
    }
    $u = if ($unit -eq "ms") { "ms" } else { "us" }
    $meanVal = if ($stats.Mean -ne $null) { $stats.Mean } else { $stats }
    Write-Host "    $label" -ForegroundColor White -NoNewline
    Write-Host "  mean=$meanVal$u  median=$($stats.Median)$u  stddev=$($stats.StdDev)$u  n=$($stats.Samples)" -ForegroundColor Gray
}

function Show-OptimizationStatus($optStates) {
    Show-SectionHeader "Optimization States ($( $optStates.AppliedCount )/$( $optStates.Total ) applied)"
    foreach ($name in ($optStates.Settings.Keys | Sort-Object)) {
        $s = $optStates.Settings[$name]
        $color = if ($s.Applied) { "Green" } else { "Red" }
        $status = if ($s.Applied) { "APPLIED" } else { "NOT_APPLIED" }
        Write-Host "    $name = $($s.Current) [$status]" -ForegroundColor $color
    }
}

# ============================================================================
# PROFILE SAVE / LOAD
# ============================================================================

function Save-Profile($data, $path) {
    $data | ConvertTo-Json -Depth 10 | Set-Content -Path $path -Encoding UTF8
    if (-not $Silent) {
        Write-Host "  Saved profile: $path" -ForegroundColor Green
    }
}

function Load-Profile($path) {
    if (-not (Test-Path $path)) {
        Write-Host "ERROR: Profile not found: $path" -ForegroundColor Red
        exit 1
    }
    return (Get-Content $path -Raw | ConvertFrom-Json)
}

# ============================================================================
# COMPARISON LOGIC
# ============================================================================

function Compare-Stats($before, $after, $label, $unit, $lowerIsBetter = $true) {
    if ($before.Valid -eq $false -or $after.Valid -eq $false) { return }
    $delta = [math]::Round($after.Mean - $before.Mean, 3)
    $pct = if ($before.Mean -ne 0) { [math]::Round(($delta / $before.Mean) * 100, 1) } else { 0 }
    $improved = if ($lowerIsBetter) { $delta -lt 0 } else { $delta -gt 0 }
    $color = if ($improved) { "Green" } else { "Red" }
    $arrow = if ($improved) { "DOWN" } else { "UP" }
    Write-Host "    $label" -ForegroundColor White -NoNewline
    Write-Host "  $($before.Mean)$unit -> $($after.Mean)$unit  ($arrow $delta$unit / $pct%)" -ForegroundColor $color
}

function Compare-BootTime($before, $after) {
    if ($before.Valid -and $after.Valid) {
        $delta = $after.TotalBootMs - $before.TotalBootMs
        $pct = if ($before.TotalBootMs -gt 0) { [math]::Round(($delta / $before.TotalBootMs) * 100, 1) } else { 0 }
        $color = if ($delta -lt 0) { "Green" } else { "Red" }
        $arrow = if ($delta -lt 0) { "FASTER" } else { "SLOWER" }
        Write-Host "    Boot Time  $($before.TotalBootMs)ms -> $($after.TotalBootMs)ms  ($arrow by $delta ms / $pct%)" -ForegroundColor $color
    }
}

function Compare-OptimizationStates($before, $after) {
    Show-SectionHeader "Optimization Change Tracking"
    $changes = @()
    foreach ($name in ($after.Settings | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name)) {
        $b = $before.Settings.$name
        $a = $after.Settings.$name
        if (-not $b) { continue }
        if ($b.Current -ne $a.Current) {
            $changes += "$name`: $($b.Current) -> $($a.Current)"
        }
    }
    if ($changes.Count -gt 0) {
        foreach ($c in $changes) { Write-Host "    CHANGED: $c" -ForegroundColor Green }
    } else {
        Write-Host "    No registry changes detected between runs." -ForegroundColor Yellow
    }
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

if (-not $Silent) {
    Clear-Host
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  W11LatencyFix REAL-TIME PROFILER" -ForegroundColor Cyan
    Write-Host "  Mode: $Mode" -ForegroundColor White
    Write-Host "========================================" -ForegroundColor Cyan
}

# Gather all measurements
$Profile = @{
    Timestamp   = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    Mode        = $Mode
    Computer    = $env:COMPUTERNAME
    Windows     = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").ReleaseId
}

# 1. Boot Time (from Windows Event Log - actual measured data)
if (-not $Silent) { Show-SectionHeader "1. Boot Time (Windows-measured)" }
$Profile.BootTime = Measure-BootTime
if ($Profile.BootTime.Valid) {
    Show-StatLine "MainPathBoot" @{Mean = $Profile.BootTime.MainPathBootMs; Median = $Profile.BootTime.MainPathBootMs; StdDev = 0; Samples = 1} "ms"
    Show-StatLine "BootPostBoot" @{Mean = $Profile.BootTime.BootPostBootMs; Median = $Profile.BootTime.BootPostBootMs; StdDev = 0; Samples = 1} "ms"
    Show-StatLine "TotalBoot" @{Mean = $Profile.BootTime.TotalBootMs; Median = $Profile.BootTime.TotalBootMs; StdDev = 0; Samples = 1} "ms"
    Write-Host "    Boot recorded: $($Profile.BootTime.BootDate)" -ForegroundColor Gray
} else {
    Write-Host "    $($Profile.BootTime.Note)" -ForegroundColor Yellow
}

# 2. Network Latency (actual ICMP RTT to gateway)
if (-not $Silent) { Show-SectionHeader "2. Network RTT (ICMP to gateway)" }
$Profile.NetworkLatency = Measure-NetworkLatency
if ($Profile.NetworkLatency.Valid) {
    Show-StatLine "RTT" $Profile.NetworkLatency "ms"
    Write-Host "    Target: $($Profile.NetworkLatency.Target)  Loss: $($Profile.NetworkLatency.PacketLossPercent)%" -ForegroundColor Gray
    Write-Host "    NOTE: TCP registry tweaks require REBOOT to affect this measurement." -ForegroundColor Yellow
} else {
    Write-Host "    $($Profile.NetworkLatency.Note)" -ForegroundColor Yellow
}

# 3. Process Creation Latency (actual CreateProcess)
if (-not $Silent) { Show-SectionHeader "3. Process Creation Latency" }
$Profile.ProcessCreation = Measure-ProcessCreationLatency
Show-StatLine "CreateProcess" $Profile.ProcessCreation

# 4. Memory Commit Latency (actual AllocHGlobal/FreeHGlobal)
if (-not $Silent) { Show-SectionHeader "4. Memory Commit Latency" }
$Profile.MemoryCommit = Measure-MemoryCommitLatency
Show-StatLine "Alloc+Free 4KB" $Profile.MemoryCommit

# 5. Registry Read Latency (actual RegQueryValueEx)
if (-not $Silent) { Show-SectionHeader "5. Registry Read Latency" }
$Profile.RegistryRead = Measure-RegistryReadLatency
Show-StatLine "RegQueryValueEx" $Profile.RegistryRead

# 6. File Write Latency (actual WriteFile+Flush)
if (-not $Silent) { Show-SectionHeader "6. File Write Latency" }
$Profile.FileWrite = Measure-FileWriteLatency
Show-StatLine "Write+Flush 1MB" $Profile.FileWrite

# 7. Explorer Cold Start (optional, invasive)
if (-not $Silent) { Show-SectionHeader "7. Explorer Cold Start" }
$Profile.ExplorerStart = Measure-ExplorerColdStart
if ($Profile.ExplorerStart.Valid) {
    Write-Host "    Startup time: $($Profile.ExplorerStart.StartupUs) ms" -ForegroundColor Green
} else {
    Write-Host "    $($Profile.ExplorerStart.Note)" -ForegroundColor Yellow
}

# 8. Optimization States (registry value audit)
if (-not $Silent) { Show-SectionHeader "8. Registry Optimization Audit" }
$Profile.OptimizationStates = Get-OptimizationStates
Show-OptimizationStatus $Profile.OptimizationStates

# Save profile
Save-Profile $Profile $OutputFile

# ============================================================================
# COMPARE MODE
# ============================================================================

if ($Mode -eq "Compare" -and $BaselineFile) {
    $Baseline = Load-Profile $BaselineFile
    if (-not $Silent) {
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host "  COMPARISON REPORT" -ForegroundColor Cyan
        Write-Host "  Baseline: $($Baseline.Timestamp)" -ForegroundColor Gray
        Write-Host "  Current:  $($Profile.Timestamp)" -ForegroundColor Gray
        Write-Host "========================================" -ForegroundColor Cyan
        
        Compare-BootTime $Baseline.BootTime $Profile.BootTime
        Compare-Stats $Baseline.NetworkLatency $Profile.NetworkLatency "Network RTT" "ms"
        Compare-Stats $Baseline.ProcessCreation $Profile.ProcessCreation "Process Creation" "us"
        Compare-Stats $Baseline.MemoryCommit $Profile.MemoryCommit "Memory Commit" "us"
        Compare-Stats $Baseline.RegistryRead $Profile.RegistryRead "Registry Read" "us"
        Compare-Stats $Baseline.FileWrite $Profile.FileWrite "File Write" "us"
        if ($Baseline.ExplorerStart.Valid -and $Profile.ExplorerStart.Valid) {
            $bd = $Baseline.ExplorerStart.StartupUs
            $ad = $Profile.ExplorerStart.StartupUs
            $delta = [math]::Round($ad - $bd, 2)
            $pct = if ($bd -gt 0) { [math]::Round(($delta / $bd) * 100, 1) } else { 0 }
            $color = if ($delta -lt 0) { "Green" } else { "Red" }
            Write-Host "    Explorer Start  ${bd}ms -> ${ad}ms  ($delta ms / $pct%)" -ForegroundColor $color
        }
        Compare-OptimizationStates $Baseline.OptimizationStates $Profile.OptimizationStates
        
        Write-Host ""
        Write-Host "  Green = improved (lower latency)" -ForegroundColor Green
        Write-Host "  Red   = worsened (higher latency)" -ForegroundColor Red
        Write-Host "  NOTE: Registry changes marked [REBOOT REQUIRED] need a restart" -ForegroundColor Yellow
        Write-Host "        before their performance impact is measurable." -ForegroundColor Yellow
    }
}

if (-not $Silent) {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  Profile saved to:" -ForegroundColor Cyan
    Write-Host "  $OutputFile" -ForegroundColor White
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host "  Baseline (before W11LatencyFix):  .\W11Profiler.ps1 -Mode Baseline" -ForegroundColor Gray
    Write-Host "  Post-Reboot (after restart):        .\W11Profiler.ps1 -Mode PostReboot" -ForegroundColor Gray
    Write-Host "  Compare two runs:                   .\W11Profiler.ps1 -Mode Compare -BaselineFile <path>" -ForegroundColor Gray
    Write-Host ""
    Read-Host "Press ENTER to exit"
}
