#Requires -Version 5.1
# W11LatencyFix Real-Time Performance Profiler
# Scientifically measures actual system latency with statistical rigor
# Uses real system calls - no simulations, no hypotheticals

param(
    [ValidateSet("Baseline","PostReboot","Compare")]
    [string]$Mode = "Baseline",
    [string]$BaselineFile,
    [switch]$ExploreRestart,
    [switch]$AutoCompare,
    [switch]$Silent
)

# Self-elevate
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "Requesting Administrator..." -ForegroundColor Yellow
    $arg = "-NoProfile -ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Path)`" -Mode $Mode"
    if ($BaselineFile) { $arg += " -BaselineFile `"$BaselineFile`"" }
    if ($ExploreRestart) { $arg += " -ExploreRestart" }
    if ($AutoCompare) { $arg += " -AutoCompare" }
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

# IQR Outlier Rejection - Scientifically removes interference spikes
function Get-Statistics {
    param([double[]]$Values)
    $sorted = $Values | Sort-Object
    $n = $Values.Count
    if ($n -lt 4) {
        $mean = ($Values | Measure-Object -Average).Average
        $variance = ($Values | ForEach-Object { [math]::Pow($_ - $mean, 2) } | Measure-Object -Average).Average
        return @{
            Samples = $n; Mean = [math]::Round($mean, 3); Median = [math]::Round($mean, 3)
            StdDev = [math]::Round([math]::Sqrt($variance), 3); Min = [math]::Round($sorted[0], 3)
            Max = [math]::Round($sorted[-1], 3); Raw = $Values; OutliersRejected = 0; CV = 0
        }
    }
    # IQR outlier rejection
    $q1Idx = [math]::Floor($n * 0.25)
    $q3Idx = [math]::Floor($n * 0.75)
    $q1 = $sorted[$q1Idx]
    $q3 = $sorted[$q3Idx]
    $iqr = $q3 - $q1
    $lower = $q1 - (1.5 * $iqr)
    $upper = $q3 + (1.5 * $iqr)
    $filtered = $Values | Where-Object { $_ -ge $lower -and $_ -le $upper }
    $rejected = $n - $filtered.Count
    $sortedF = $filtered | Sort-Object
    $nf = $filtered.Count
    $meanF = ($filtered | Measure-Object -Average).Average
    $medianF = if ($nf % 2 -eq 0) { ($sortedF[$nf/2 - 1] + $sortedF[$nf/2]) / 2 } else { $sortedF[($nf - 1) / 2] }
    $varianceF = ($filtered | ForEach-Object { [math]::Pow($_ - $meanF, 2) } | Measure-Object -Average).Average
    $stddevF = [math]::Sqrt($varianceF)
    $cv = if ($meanF -gt 0) { [math]::Round(($stddevF / $meanF) * 100, 1) } else { 0 }
    return @{
        Samples = $nf
        Mean    = [math]::Round($meanF, 3)
        Median  = [math]::Round($medianF, 3)
        StdDev  = [math]::Round($stddevF, 3)
        Min     = [math]::Round(($filtered | Measure-Object -Minimum).Minimum, 3)
        Max     = [math]::Round(($filtered | Measure-Object -Maximum).Maximum, 3)
        Raw     = $Values
        OutliersRejected = $rejected
        CV      = $cv
    }
}

function Test-SystemIdle {
    param([int]$Seconds = 3, [int]$MaxCpuPercent = 10)
    $samples = @()
    for ($i = 0; $i -lt $Seconds; $i++) {
        $cpu = (Get-Counter '\Processor(_Total)\% Processor Time' -SampleInterval 1 -MaxSamples 1).CounterSamples.CookedValue
        $samples += $cpu
        if ($cpu -gt $MaxCpuPercent) { return @{Idle = $false; Cpu = [math]::Round($cpu, 1)} }
    }
    $avgCpu = ($samples | Measure-Object -Average).Average
    return @{Idle = $true; Cpu = [math]::Round($avgCpu, 1)}
}

function Measure-MicroBenchmark {
    param(
        [scriptblock]$ScriptBlock,
        [int]$Warmup = 5,
        [int]$Iterations = 30,
        [int]$MaxRetries = 2,
        [double]$MaxCV = 25.0
    )
    # Wait for system idle
    $idleCheck = Test-SystemIdle -Seconds 2 -MaxCpuPercent 15
    if (-not $idleCheck.Idle -and -not $Silent) {
        Write-Host "    [WARN] System CPU was $($idleCheck.Cpu)% - measurements may be noisy" -ForegroundColor DarkYellow
    }
    # Set high priority for measurement consistency
    $oldPriority = [System.Diagnostics.Process]::GetCurrentProcess().PriorityClass
    [System.Diagnostics.Process]::GetCurrentProcess().PriorityClass = 'High'
    try {
        # Warmup
        for ($i = 0; $i -lt $Warmup; $i++) { & $ScriptBlock | Out-Null }
        $bestResult = $null
        for ($attempt = 0; $attempt -le $MaxRetries; $attempt++) {
            $times = @()
            for ($i = 0; $i -lt $Iterations; $i++) {
                $sw = [System.Diagnostics.Stopwatch]::StartNew()
                & $ScriptBlock | Out-Null
                $sw.Stop()
                $times += (Get-ElapsedMicroseconds $sw)
            }
            $stats = Get-Statistics $times
            if ($null -eq $bestResult -or $stats.CV -lt $bestResult.CV) {
                $bestResult = $stats
            }
            if ($stats.CV -le $MaxCV) { break }
            if (-not $Silent -and $attempt -lt $MaxRetries) {
                Write-Host "    [RETRY $attempt] CV $($stats.CV)% too high, re-measuring..." -ForegroundColor DarkYellow
                Start-Sleep -Milliseconds 500
            }
        }
        return $bestResult
    } finally {
        [System.Diagnostics.Process]::GetCurrentProcess().PriorityClass = $oldPriority
    }
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

function Measure-DnsResolutionLatency {
    # Actual DNS resolution using .NET Dns class
    $target = "localhost"
    return (Measure-MicroBenchmark -ScriptBlock {
        $null = [System.Net.Dns]::GetHostAddresses($target)
    } -Warmup 5 -Iterations 30)
}

function Measure-TcpConnectLatency {
    # Actual TCP socket connect to localhost ephemeral port
    # First we need a listener
    $listener = $null
    try {
        $listener = New-Object System.Net.Sockets.TcpListener ([System.Net.IPAddress]::Loopback, 0)
        $listener.Start()
        $port = $listener.LocalEndpoint.Port
        $results = @()
        $warmup = 3
        $samples = 20
        for ($i = 0; $i -lt ($warmup + $samples); $i++) {
            $sw = [System.Diagnostics.Stopwatch]::StartNew()
            $client = New-Object System.Net.Sockets.TcpClient
            $client.Connect("127.0.0.1", $port)
            $sw.Stop()
            $client.Close()
            if ($i -ge $warmup) {
                $results += (Get-ElapsedMicroseconds $sw)
            }
        }
        $listener.Stop()
        $stats = Get-Statistics $results
        $stats.Note = "TCP connect/disconnect to localhost ephemeral port"
        return $stats
    } catch {
        if ($listener) { $listener.Stop() }
        return @{Valid = $false; Note = "TCP connect test failed: $_"}
    }
}

function Measure-ServiceEnumerationLatency {
    # Measures overhead of querying all services (we disable many)
    return (Measure-MicroBenchmark -ScriptBlock {
        $null = Get-Service | Select-Object -First 1
    } -Warmup 5 -Iterations 30)
}

function Measure-RandomFileReadLatency {
    # Random 4KB reads from 16MB file
    # NOTE: Uses ZERO-filled data to avoid AV heuristic scanning of random bytes
    $testFile = "$env:TEMP\w11prf_rdr_$(Get-Random).dat"
    $fs = $null
    $readFs = $null
    try {
        # Create 16MB zero-filled file (AV-friendly)
        $fs = [System.IO.File]::Create($testFile)
        $zeros = New-Object byte[] 65536
        for ($i = 0; $i -lt 256; $i++) { $fs.Write($zeros, 0, 65536) }
        $fs.Close(); $fs = $null
        $fileSize = (Get-Item $testFile).Length
        $rng = New-Object Random
        $times = @()
        $warmup = 3
        $samples = 30
        $readFs = [System.IO.File]::Open($testFile, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::Read)
        for ($i = 0; $i -lt ($warmup + $samples); $i++) {
            $pos = $rng.Next(0, [int]($fileSize - 4096))
            $readFs.Position = $pos
            $buf = New-Object byte[] 4096
            $sw = [System.Diagnostics.Stopwatch]::StartNew()
            $readFs.Read($buf, 0, 4096) | Out-Null
            $sw.Stop()
            if ($i -ge $warmup) { $times += (Get-ElapsedMicroseconds $sw) }
        }
        $readFs.Close(); $readFs = $null
        Remove-Item $testFile -ErrorAction SilentlyContinue
        $stats = Get-Statistics $times
        $stats.Note = "Random 4KB read from 16MB file"
        return $stats
    } catch {
        if ($fs) { $fs.Close() }
        if ($readFs) { $readFs.Close() }
        Remove-Item $testFile -ErrorAction SilentlyContinue
        return @{Valid = $false; Note = "Random read test failed: $_"}
    }
}

function Measure-DnsCachePerformance {
    # Tests DNS cache optimization by measuring cold vs warm resolution
    $target = "docs.microsoft.com"
    try {
        # Warm cache resolution
        $warmTimes = @()
        for ($i = 0; $i -lt 5; $i++) {
            $sw = [System.Diagnostics.Stopwatch]::StartNew()
            $null = [System.Net.Dns]::GetHostAddresses($target)
            $sw.Stop()
            $warmTimes += (Get-ElapsedMicroseconds $sw)
            Start-Sleep -Milliseconds 50
        }
        $warmStats = Get-Statistics $warmTimes
        # Clear DNS cache
        Start-Process ipconfig -ArgumentList "/flushdns" -WindowStyle Hidden -Wait | Out-Null
        Start-Sleep -Milliseconds 200
        # Cold cache resolution
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $null = [System.Net.Dns]::GetHostAddresses($target)
        $sw.Stop()
        $coldTime = (Get-ElapsedMicroseconds $sw)
        return @{
            Valid = $true
            Mean = $warmStats.Mean
            WarmMean = $warmStats.Mean
            ColdTime = $coldTime
            WarmCV = $warmStats.CV
            Samples = $warmStats.Samples
            StdDev = $warmStats.StdDev
            Note = "DNS warm avg $($warmStats.Mean)us vs cold $coldTime`us"
        }
    } catch {
        return @{Valid = $false; Note = "DNS cache test failed: $_"}
    }
}

function Get-SystemResourceSnapshot {
    # Snapshot of system resource usage
    $proc = Get-Process -Id $PID
    $allProcs = Get-Process
    return @{
        ProcessCount = $allProcs.Count
        ThreadCount = ($allProcs | ForEach-Object { $_.Threads.Count } | Measure-Object -Sum).Sum
        HandleCount = $proc.HandleCount
        WorkingSetMB = [math]::Round($proc.WorkingSet64 / 1MB, 2)
        PrivateMemoryMB = [math]::Round($proc.PrivateMemorySize64 / 1MB, 2)
        GdiObjects = $proc.MainWindowHandle  # Not directly available, use proxy
        Note = "System resource snapshot at profile time"
    }
}

function Get-ServiceConfigurationState {
    # Count services by start type - we disable many
    $svcs = Get-Service
    $disabled = ($svcs | Where-Object { $_.StartType -eq 'Disabled' }).Count
    $manual = ($svcs | Where-Object { $_.StartType -eq 'Manual' }).Count
    $auto = ($svcs | Where-Object { $_.StartType -eq 'Automatic' }).Count
    $running = ($svcs | Where-Object { $_.Status -eq 'Running' }).Count
    return @{
        Disabled = $disabled
        Manual = $manual
        Automatic = $auto
        Running = $running
        Total = $svcs.Count
        Note = "Service configuration state"
    }
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

function Get-SystemForensics {
    # SAFELY captures system state for anomaly investigation
    # All operations are READ-ONLY - never modifies anything
    param([string]$TriggerReason)
    $forensics = @{}
    $forensics.CaptureTime = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    $forensics.Trigger = $TriggerReason
    
    # 1. All running processes with resource usage
    try {
        $forensics.Processes = Get-Process | Select-Object Name, Id, CPU, WorkingSet64, PagedMemorySize64, Threads, Path, Company, @{N="CpuPercent";E={if($_.CPU -gt 0){[math]::Round($_.CPU,2)}else{0}}} | Sort-Object -Property CPU -Descending | Select-Object -First 30 | ForEach-Object { @{Name=$_.Name; Id=$_.Id; CPU=$_.CpuPercent; WorkingSetMB=[math]::Round($_.WorkingSet64/1MB,1); Threads=$_.Threads.Count; Path=$_.Path} }
    } catch { $forensics.Processes = "ERROR: $_" }
    
    # 2. Top CPU consumers in last second
    try {
        $counters = Get-Counter '\Process(*)\% Processor Time' -MaxSamples 1 -ErrorAction SilentlyContinue
        $forensics.TopCpu = $counters.CounterSamples | Where-Object { $_.InstanceName -notin '_total','idle' } | Sort-Object -Property CookedValue -Descending | Select-Object -First 10 | ForEach-Object { @{Process=$_.InstanceName; CpuPercent=[math]::Round($_.CookedValue,1)} }
    } catch { $forensics.TopCpu = "ERROR: $_" }
    
    # 3. Network connections (read-only)
    try {
        $forensics.NetConnections = Get-NetTCPConnection -ErrorAction SilentlyContinue | Select-Object -First 20 | ForEach-Object { @{Local=$_.LocalAddress; Remote=$_.RemoteAddress; State=$_.State; OwningProcess=$_.OwningProcess} }
    } catch { $forensics.NetConnections = "ERROR: $_" }
    
    # 4. Recent Windows events (last 2 minutes)
    try {
        $startTime = (Get-Date).AddMinutes(-2)
        $forensics.RecentEvents = Get-WinEvent -FilterHashtable @{LogName='System','Application'; StartTime=$startTime} -MaxEvents 20 -ErrorAction SilentlyContinue | ForEach-Object { @{Time=$_.TimeCreated.ToString("HH:mm:ss"); Level=$_.LevelDisplayName; Source=$_.ProviderName; Id=$_.Id; Message=($_.Message -replace '`r`n',' ').Substring(0,[Math]::Min(120,($_.Message -replace '`r`n',' ').Length))} }
    } catch { $forensics.RecentEvents = "ERROR: $_" }
    
    # 5. Services that recently changed
    try {
        $forensics.ServiceStates = Get-Service | Where-Object { $_.Status -ne 'Running' -and $_.StartType -eq 'Automatic' } | Select-Object -First 10 | ForEach-Object { @{Name=$_.Name; Status=$_.Status; StartType=$_.StartType} }
    } catch { $forensics.ServiceStates = "ERROR: $_" }
    
    # 6. Windows Defender status (read-only)
    try {
        $defender = Get-MpComputerStatus -ErrorAction SilentlyContinue
        $forensics.Defender = @{RealTimeProtection=$defender.RealTimeProtectionEnabled; BehaviorMonitor=$defender.BehaviorMonitorEnabled; QuickScanAge=$defender.QuickScanAge}
    } catch { $forensics.Defender = @{Note="Unable to query Defender status"} }
    
    # 7. Windows Update active status
    try {
        $wu = Get-Service wuauserv -ErrorAction SilentlyContinue
        $forensics.WindowsUpdate = @{Status=$wu.Status; StartType=$wu.StartType}
    } catch { $forensics.WindowsUpdate = @{Note="Unable to query WU"} }
    
    # 8. Disk queue depth
    try {
        $disk = Get-Counter '\PhysicalDisk(_Total)\Current Disk Queue Length' -MaxSamples 1 -ErrorAction SilentlyContinue
        $forensics.DiskQueue = [math]::Round($disk.CounterSamples[0].CookedValue, 2)
    } catch { $forensics.DiskQueue = "ERROR" }
    
    return $forensics
}

function Save-ForensicsReport($forensics, $profileFile) {
    $forensicsFile = $profileFile -replace '\.json$', '_FORENSICS.json'
    $forensics | ConvertTo-Json -Depth 5 | Set-Content -Path $forensicsFile -Encoding UTF8
    Write-Host "  Forensics saved: $forensicsFile" -ForegroundColor Magenta
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
    $meanVal = if ($null -ne $stats.Mean) { $stats.Mean } else { $stats }
    $outlierNote = if ($stats.OutliersRejected -gt 0) { "  outliers=$($stats.OutliersRejected)" } else { "" }
    $cvNote = if ($stats.CV -gt 25) { "  CV=$($stats.CV)%" } else { "" }
    $warn = ""
    if ($stats.OutliersRejected -gt 5) { $warn = " [FORENSICS TRIGGERED]" }
    elseif ($stats.CV -gt 50) { $warn = " [HIGH VARIANCE]" }
    Write-Host "    $label" -ForegroundColor White -NoNewline
    Write-Host "  mean=$meanVal$u  median=$($stats.Median)$u  stddev=$($stats.StdDev)$u  n=$($stats.Samples)$outlierNote$cvNote$warn" -ForegroundColor Gray
    if ($warn -and -not $Silent) {
        Write-Host "      -> System contamination suspected during this test" -ForegroundColor DarkYellow
    }
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

function Import-ProfileData($path) {
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

function Show-ComparisonTable($before, $after) {
    Show-SectionHeader "Performance Delta Summary"
    $rows = @()
    $tests = @(
        @{Label="Network RTT"; Before=$before.NetworkLatency; After=$after.NetworkLatency; Unit="ms"; Reboot=$true},
        @{Label="Process Creation"; Before=$before.ProcessCreation; After=$after.ProcessCreation; Unit="us"; Reboot=$false},
        @{Label="Memory Commit"; Before=$before.MemoryCommit; After=$after.MemoryCommit; Unit="us"; Reboot=$false},
        @{Label="Registry Read"; Before=$before.RegistryRead; After=$after.RegistryRead; Unit="us"; Reboot=$false},
        @{Label="File Write"; Before=$before.FileWrite; After=$after.FileWrite; Unit="us"; Reboot=$false},
        @{Label="DNS Resolution"; Before=$before.DnsResolution; After=$after.DnsResolution; Unit="us"; Reboot=$false},
        @{Label="TCP Connect"; Before=$before.TcpConnect; After=$after.TcpConnect; Unit="us"; Reboot=$true},
        @{Label="Service Enum"; Before=$before.ServiceEnum; After=$after.ServiceEnum; Unit="us"; Reboot=$false},
        @{Label="Random File Read"; Before=$before.RandomFileRead; After=$after.RandomFileRead; Unit="us"; Reboot=$false},
        @{Label="DNS Cache Warm"; Before=$before.DnsCache; After=$after.DnsCache; Unit="us"; Reboot=$true}
    )
    foreach ($t in $tests) {
        $b = $t.Before; $a = $t.After
        if (-not $b -or -not $a -or $b.Valid -eq $false -or $a.Valid -eq $false) {
            $rows += [PSCustomObject]@{
                Test = $t.Label
                Before = "N/A"; After = "N/A"; Delta = "N/A"; Pct = "N/A"
                Status = "---"; Reboot = if($t.Reboot){"*"}else{""}
            }
            continue
        }
        $delta = [math]::Round($a.Mean - $b.Mean, 2)
        $pct = if ($b.Mean -ne 0) { [math]::Round(($delta / $b.Mean) * 100, 1) } else { 0 }
        $improved = $delta -lt 0
        $status = if ($improved) { "IMPROVED" } else { "WORSENED" }
        $rows += [PSCustomObject]@{
            Test = $t.Label
            Before = "$($b.Mean) $($t.Unit)"
            After = "$($a.Mean) $($t.Unit)"
            Delta = "$delta $($t.Unit)"
            Pct = "$pct%"
            Status = $status
            Reboot = if($t.Reboot){"*"}else{""}
        }
    }
    $rows | Format-Table Test, Before, After, Delta, Pct, Status, Reboot -AutoSize | ForEach-Object { Write-Host "  $_" -ForegroundColor White }
    Write-Host "    * = Requires reboot for registry changes to take effect" -ForegroundColor Yellow
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
$ProfileData = @{
    Timestamp   = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    Mode        = $Mode
    Computer    = $env:COMPUTERNAME
    Windows     = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").ReleaseId
}

# 1. Boot Time (from Windows Event Log - actual measured data)
if (-not $Silent) { Show-SectionHeader "1. Boot Time (Windows-measured)" }
$ProfileData.BootTime = Measure-BootTime
if ($ProfileData.BootTime.Valid) {
    Show-StatLine "MainPathBoot" @{Mean = $ProfileData.BootTime.MainPathBootMs; Median = $ProfileData.BootTime.MainPathBootMs; StdDev = 0; Samples = 1} "ms"
    Show-StatLine "BootPostBoot" @{Mean = $ProfileData.BootTime.BootPostBootMs; Median = $ProfileData.BootTime.BootPostBootMs; StdDev = 0; Samples = 1} "ms"
    Show-StatLine "TotalBoot" @{Mean = $ProfileData.BootTime.TotalBootMs; Median = $ProfileData.BootTime.TotalBootMs; StdDev = 0; Samples = 1} "ms"
    Write-Host "    Boot recorded: $($ProfileData.BootTime.BootDate)" -ForegroundColor Gray
} else {
    Write-Host "    $($ProfileData.BootTime.Note)" -ForegroundColor Yellow
}

# 2. Network Latency (actual ICMP RTT to gateway)
if (-not $Silent) { Show-SectionHeader "2. Network RTT (ICMP to gateway)" }
$ProfileData.NetworkLatency = Measure-NetworkLatency
if ($ProfileData.NetworkLatency.Valid) {
    Show-StatLine "RTT" $ProfileData.NetworkLatency "ms"
    Write-Host "    Target: $($ProfileData.NetworkLatency.Target)  Loss: $($ProfileData.NetworkLatency.PacketLossPercent)%" -ForegroundColor Gray
    Write-Host "    NOTE: TCP registry tweaks require REBOOT to affect this measurement." -ForegroundColor Yellow
} else {
    Write-Host "    $($ProfileData.NetworkLatency.Note)" -ForegroundColor Yellow
}

# 3. Process Creation Latency (actual CreateProcess)
if (-not $Silent) { Show-SectionHeader "3. Process Creation Latency" }
$ProfileData.ProcessCreation = Measure-ProcessCreationLatency
Show-StatLine "CreateProcess" $ProfileData.ProcessCreation

# 4. Memory Commit Latency (actual AllocHGlobal/FreeHGlobal)
if (-not $Silent) { Show-SectionHeader "4. Memory Commit Latency" }
$ProfileData.MemoryCommit = Measure-MemoryCommitLatency
Show-StatLine "Alloc+Free 4KB" $ProfileData.MemoryCommit

# 5. Registry Read Latency (actual RegQueryValueEx)
if (-not $Silent) { Show-SectionHeader "5. Registry Read Latency" }
$ProfileData.RegistryRead = Measure-RegistryReadLatency
Show-StatLine "RegQueryValueEx" $ProfileData.RegistryRead

# 6. File Write Latency (actual WriteFile+Flush)
if (-not $Silent) { Show-SectionHeader "6. File Write Latency" }
$ProfileData.FileWrite = Measure-FileWriteLatency
Show-StatLine "Write+Flush 1MB" $ProfileData.FileWrite

# 7. Explorer Cold Start (optional, invasive)
if (-not $Silent) { Show-SectionHeader "7. Explorer Cold Start" }
$ProfileData.ExplorerStart = Measure-ExplorerColdStart
if ($ProfileData.ExplorerStart.Valid) {
    Write-Host "    Startup time: $($ProfileData.ExplorerStart.StartupUs) ms" -ForegroundColor Green
} else {
    Write-Host "    $($ProfileData.ExplorerStart.Note)" -ForegroundColor Yellow
}

# 8. DNS Resolution Latency
if (-not $Silent) { Show-SectionHeader "8. DNS Resolution Latency" }
$ProfileData.DnsResolution = Measure-DnsResolutionLatency
Show-StatLine "Resolve localhost" $ProfileData.DnsResolution

# 9. TCP Connect Latency
if (-not $Silent) { Show-SectionHeader "9. TCP Connect Latency (localhost)" }
$ProfileData.TcpConnect = Measure-TcpConnectLatency
if ($ProfileData.TcpConnect.Valid) {
    Show-StatLine "TCP connect+close" $ProfileData.TcpConnect
    Write-Host "    NOTE: TCP stack registry tweaks require REBOOT to affect this." -ForegroundColor Yellow
} else {
    Write-Host "    $($ProfileData.TcpConnect.Note)" -ForegroundColor Yellow
}

# 10. Service Enumeration Latency
if (-not $Silent) { Show-SectionHeader "10. Service Enumeration Latency" }
$ProfileData.ServiceEnum = Measure-ServiceEnumerationLatency
Show-StatLine "Get-Service query" $ProfileData.ServiceEnum

# 11. Random File Read Latency
if (-not $Silent) { Show-SectionHeader "11. Random File Read Latency" }
$ProfileData.RandomFileRead = Measure-RandomFileReadLatency
Show-StatLine "Random 4KB read" $ProfileData.RandomFileRead

# 12. DNS Cache Performance (cold vs warm)
if (-not $Silent) { Show-SectionHeader "12. DNS Cache Performance" }
$ProfileData.DnsCache = Measure-DnsCachePerformance
if ($ProfileData.DnsCache.Valid) {
    Write-Host "    Warm cache avg: $($ProfileData.DnsCache.WarmMean)us  Cold: $($ProfileData.DnsCache.ColdTime)us  CV=$($ProfileData.DnsCache.WarmCV)%" -ForegroundColor Gray
    Write-Host "    NOTE: DNS cache size/ttl tweaks require REBOOT to affect this." -ForegroundColor Yellow
} else {
    Write-Host "    $($ProfileData.DnsCache.Note)" -ForegroundColor Yellow
}

# 13. System Resource Snapshot
if (-not $Silent) { Show-SectionHeader "13. System Resource Snapshot" }
$ProfileData.Resources = Get-SystemResourceSnapshot
Write-Host "    Processes: $($ProfileData.Resources.ProcessCount)  Threads: $($ProfileData.Resources.ThreadCount)  Handles: $($ProfileData.Resources.HandleCount)" -ForegroundColor Gray
Write-Host "    WorkingSet: $($ProfileData.Resources.WorkingSetMB)MB  Private: $($ProfileData.Resources.PrivateMemoryMB)MB" -ForegroundColor Gray

# 14. Service Configuration State
if (-not $Silent) { Show-SectionHeader "14. Service Configuration State" }
$ProfileData.Services = Get-ServiceConfigurationState
Write-Host "    Disabled: $($ProfileData.Services.Disabled)  Manual: $($ProfileData.Services.Manual)  Auto: $($ProfileData.Services.Automatic)  Running: $($ProfileData.Services.Running) / $($ProfileData.Services.Total)" -ForegroundColor Gray

# 15. Optimization States (registry value audit)
if (-not $Silent) { Show-SectionHeader "15. Registry Optimization Audit" }
$ProfileData.OptimizationStates = Get-OptimizationStates
Show-OptimizationStatus $ProfileData.OptimizationStates

# Auto-detect baseline for Compare mode
if ($AutoCompare -and -not $BaselineFile) {
    $latestBaseline = Get-ChildItem "$ProfileDir\Profile_Baseline_*.json" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($latestBaseline) {
        $BaselineFile = $latestBaseline.FullName
        if (-not $Silent) { Write-Host "  Auto-selected baseline: $($latestBaseline.Name)" -ForegroundColor Cyan }
    }
}

# Save profile
Save-Profile $ProfileData $OutputFile

# Forensics: Check for contamination and capture system state
$contaminatedTests = @()
$testFields = @('NetworkLatency','ProcessCreation','MemoryCommit','RegistryRead','FileWrite','DnsResolution','TcpConnect','ServiceEnum','RandomFileRead','DnsCache')
foreach ($tf in $testFields) {
    $t = $ProfileData.$tf
    if ($t -and $t.CV -gt 50) { $contaminatedTests += "$tf (CV=$($t.CV)%)" }
    elseif ($t -and $t.OutliersRejected -gt 5) { $contaminatedTests += "$tf (outliers=$($t.OutliersRejected))" }
}
if ($contaminatedTests.Count -gt 0) {
    $reason = "Contamination detected in: $($contaminatedTests -join ', ')"
    if (-not $Silent) {
        Write-Host ""
        Write-Host "  [ANOMALY DETECTED] Capturing system forensics..." -ForegroundColor Magenta
    }
    $forensics = Get-SystemForensics -TriggerReason $reason
    Save-ForensicsReport $forensics $OutputFile
    if (-not $Silent) {
        Write-Host "    Top CPU at capture: $(($forensics.TopCpu | Select-Object -First 3 | ForEach-Object { "$($_.Process)=$($_.CpuPercent)%" }) -join ', ')" -ForegroundColor Gray
        Write-Host "    Disk queue: $($forensics.DiskQueue)" -ForegroundColor Gray
    }
}

# ============================================================================
# COMPARE MODE
# ============================================================================

if ($Mode -eq "Compare" -and $BaselineFile) {
    $Baseline = Import-ProfileData $BaselineFile
    if (-not $Silent) {
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host "  COMPARISON REPORT" -ForegroundColor Cyan
        Write-Host "  Baseline: $($Baseline.Timestamp)" -ForegroundColor Gray
        Write-Host "  Current:  $($ProfileData.Timestamp)" -ForegroundColor Gray
        Write-Host "========================================" -ForegroundColor Cyan
        
        Show-ComparisonTable $Baseline $ProfileData
        Compare-BootTime $Baseline.BootTime $ProfileData.BootTime
        if ($Baseline.ExplorerStart.Valid -and $ProfileData.ExplorerStart.Valid) {
            $bd = $Baseline.ExplorerStart.StartupUs
            $ad = $ProfileData.ExplorerStart.StartupUs
            $delta = [math]::Round($ad - $bd, 2)
            $pct = if ($bd -gt 0) { [math]::Round(($delta / $bd) * 100, 1) } else { 0 }
            $color = if ($delta -lt 0) { "Green" } else { "Red" }
            Write-Host "    Explorer Start  ${bd}ms -> ${ad}ms  ($delta ms / $pct%)" -ForegroundColor $color
        }
        # Service Configuration comparison
        Show-SectionHeader "Service Configuration Delta"
        $bs = $Baseline.Services; $as = $ProfileData.Services
        if ($bs -and $as) {
            $svcDelta = $as.Disabled - $bs.Disabled
            $svcColor = if ($svcDelta -gt 0) { "Green" } else { "White" }
            Write-Host "    Disabled services: $($bs.Disabled) -> $($as.Disabled) (delta: $svcDelta)" -ForegroundColor $svcColor
            Write-Host "    Manual services: $($bs.Manual) -> $($as.Manual)" -ForegroundColor Gray
            Write-Host "    Auto services: $($bs.Automatic) -> $($as.Automatic)" -ForegroundColor Gray
            Write-Host "    Running: $($bs.Running) -> $($as.Running)" -ForegroundColor Gray
        }
        # Resource comparison
        Show-SectionHeader "Resource Usage Delta"
        $br = $Baseline.Resources; $ar = $ProfileData.Resources
        if ($br -and $ar) {
            Write-Host "    Processes: $($br.ProcessCount) -> $($ar.ProcessCount)" -ForegroundColor Gray
            Write-Host "    Threads: $($br.ThreadCount) -> $($ar.ThreadCount)" -ForegroundColor Gray
            Write-Host "    WorkingSet: $($br.WorkingSetMB)MB -> $($ar.WorkingSetMB)MB" -ForegroundColor Gray
        }
        # DNS Cache comparison
        if ($Baseline.DnsCache.Valid -and $ProfileData.DnsCache.Valid) {
            Show-SectionHeader "DNS Cache Delta"
            $bdns = $Baseline.DnsCache; $adns = $ProfileData.DnsCache
            Write-Host "    Warm cache: $($bdns.WarmMean)us -> $($adns.WarmMean)us" -ForegroundColor Gray
            Write-Host "    Cold cache: $($bdns.ColdTime)us -> $($adns.ColdTime)us" -ForegroundColor Gray
        }
        Compare-OptimizationStates $Baseline.OptimizationStates $ProfileData.OptimizationStates
        
        Write-Host ""
        Write-Host "  Green = improved (lower latency)" -ForegroundColor Green
        Write-Host "  Red   = worsened (higher latency)" -ForegroundColor Red
        Write-Host "  NOTE: Tests marked * require a system REBOOT before changes are measurable." -ForegroundColor Yellow
        Write-Host "        Same-session measurements are only valid for HKCU/Explorer changes." -ForegroundColor Yellow
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
    Write-Host "  Compare with auto baseline:         .\W11Profiler.ps1 -Mode Compare -AutoCompare" -ForegroundColor Gray
    Write-Host "  Compare specific file:              .\W11Profiler.ps1 -Mode Compare -BaselineFile <path>" -ForegroundColor Gray
    Write-Host ""
    Read-Host "Press ENTER to exit"
}
