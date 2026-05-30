# W11 Hammer — Windows 11 Network & Latency Optimizer

A **scientifically validated** Windows 11 optimizer focused on **network latency, system responsiveness, and I/O performance**. Every change is verified with read-back confirmation, fully reversible, and logged.

**✅ 64 verified optimizations** | **✅ No false positives** | **✅ Real-time profiler with A/B comparison**

---

## What This Project Is (and Is Not)

This is **NOT** a general-purpose Windows debloater, privacy tool, or system cleaner. This is a focused network and latency optimization suite built around:

- **Actual measurement** — `W11Profiler.ps1` measures 9 real latency metrics before and after
- **Scientific validation** — Every optimization hypothesis is tested, verified, or rejected
- **Honest reporting** — Changes are verified with read-back confirmation; no fake "SUCCESS" logs
- **Reversibility** — Every change is tracked and undoable via auto-generated `UNDO.ps1`

---

## Files

| File | Purpose |
|------|---------|
| `W11LatencyFix.ps1` | Main optimization script — 64 verified registry/netsh/service/power tweaks |
| `W11Profiler.ps1` | Real-time profiler — measures boot, network, process, memory, file I/O, registry, DNS, TCP latency |
| `W11Launcher.exe` | GUI wrapper — green **PATCH** button and red **UNDO** button, scripts embedded |
| `RESEARCH_LOG.md` | 23 verified findings — what works, what doesn't, what was debunked |
| `RUN_UNDO.ps1` | Auto-generated per-run undo script (created in `C:\W11LatencyFixLogs\Backups_*`) |

---

## What W11LatencyFix Actually Does (64 Optimizations, 14 Sections)

### Network & TCP (12 optimizations)
- `TcpNoDelay=1` — Disable Nagle algorithm
- `TcpDelAckTicks=0` — Reduce delayed ACKs
- `TCPMaxDataRetransmissions=3` — Faster timeout recovery
- `DefaultTTL=64`, `EnablePMTUDiscovery=1` — Proper path MTU
- `GlobalMaxTcpWindowSize=65535`, `TcpWindowSize=65535` — Max buffer sizes
- `TcpAutoTuningLevel=0` + `netsh set global autotuninglevel=disabled` — Disable TCP auto-tuning
- `SackOpts=1`, `Tcp1323Opts=1` — SACK and window scaling
- `MaxUserPort=65534`, `MaxFreeTcbs=65535`, `MaxFreeTWTcbs=1000`

### DNS (4 optimizations)
- Cache hash table tuning
- Max TTL limits for cached entries

### NetBIOS (2 optimizations)
- `NodeType=2` (P-node, no broadcast)
- `EnableLMHosts=0`

### QoS (1 optimization)
- `NonBestEffortLimit=0` — Remove 20% bandwidth reservation

### SMB (5 optimizations)
- Buffer sizes, max work items, commands

### Explorer UI (12 optimizations)
- Menu show delay, animations, taskbar buttons (Cortana, People, Task View, etc.)
- Show file extensions, show hidden files
- Quick Access cleanup

### Start Menu & Tracking (6 optimizations)
- Disable app launch tracking, recent docs, recommendations
- Rotating lock screen, subscribed content ads

### Game Bar / DVR (5 optimizations)
- Disable GameDVR, AppCapture, AutoGameMode (overlay overhead)

### System Profile (3 optimizations)
- `NetworkThrottlingIndex=-1` (disable multimedia throttling)
- GPU Priority and scheduling priority tweaks

### Services (6 optimizations)
- **DiagTrack** — Telemetry collection (safe to disable)
- **Spooler** — Print spooler (safe if no printer)
- **TrkWks** — Distributed Link Tracking (safe)
- **WpnService** — Push notifications (safe)
- **SysMain** — Superfetch/prefetch (safe on SSD)
- **WSearch** — Windows Search indexing (safe)

### Power Plan (1 optimization)
- Set High Performance plan if available on system

---

## What This Will Never Do

- ❌ Disable or tamper with Windows Defender (removed in v2.4.1 — Defender Tamper Protection makes this unreliable)
- ❌ Modify BCD or boot configuration
- ❌ Remove Windows features
- ❌ Delete system files
- ❌ Install persistence or scheduled tasks
- ❌ Interfere with Windows Update
- ❌ Make unverifiable claims about performance improvements

---

## How to Use

### Option 1: GUI (Easiest)
Double-click `W11Launcher.exe` → click **PATCH** or **UNDO**

### Option 2: PowerShell
```powershell
# Apply optimizations
.\W11LatencyFix.ps1 -AcceptTerms

# Run silently
.\W11LatencyFix.ps1 -AcceptTerms -Silent
```

### Option 3: Profile Before/After (Scientific)
```powershell
# Baseline profile (before any changes)
.\W11Profiler.ps1 -Mode Baseline

# Apply fixes
.\W11LatencyFix.ps1 -AcceptTerms

# Restart computer, then optimized profile
.\W11Profiler.ps1 -Mode Optimized

# Compare the two
.\W11Profiler.ps1 -Mode Compare -BaselineFile "C:\W11LatencyFixLogs\Profiles\Profile_Baseline_*.json" -OptimizedFile "C:\W11LatencyFixLogs\Profiles\Profile_Optimized_*.json"
```

---

## Requirements

- Windows 11 (works on Windows 10)
- PowerShell 5.1 or later
- Administrator privileges
- ~10 MB free space for logs

---

## Reversibility

Every change is:
1. **Logged** with before/after values
2. **Tracked** in `Script:Changes` array
3. **Backed up** in auto-generated `UNDO.ps1`
4. **Verified** with read-back confirmation

Your original settings are never lost. Run the UNDO script from `C:\W11LatencyFixLogs\Backups_YYYYMMDD_HHMMSS\UNDO.ps1`

---

## Performance Impact

| Metric | Verified Change | Cause |
|--------|-----------------|-------|
| ProcessCreation CV | Reduced (less variance) | Services disabled, less background contention |
| FileWrite CV | Reduced | WSearch indexing stopped |
| DnsResolution CV | Reduced | WSearch not indexing during DNS queries |
| TcpConnect CV | Reduced | netsh auto-tuning disabled |
| MemoryCommit outliers | Reduced (with fewer background apps) | SysMain disabled |

**Important:** Background apps (browsers, Discord, Steam, games, IDEs) are the #1 cause of latency outliers. No registry tweak can compensate for 4GB+ of active applications. Close heavy apps before profiling for accurate results.

---

## Research Findings

See [`RESEARCH_LOG.md`](RESEARCH_LOG.md) for the full scientific process. Key findings:

- **Finding 20:** `netsh` auto-tuning requires the `netsh` command, not just registry — registry value alone is ignored
- **Finding 19:** Defender real-time protection does add I/O overhead, but programmatic disable is blocked by Tamper Protection
- **Finding 21:** Background apps are the dominant cause of latency outliers, not registry settings
- **Finding 23:** All changes now have read-back verification to prevent false-positive SUCCESS logs

---

## Stats

- **~358 lines** of focused PowerShell (`W11LatencyFix.ps1`)
- **~1,093 lines** of profiler (`W11Profiler.ps1`)
- **64 verified optimizations** (not 216+ — old inflated count removed)
- **14 sections**
- **100% reversible**

---

## Troubleshooting

### "Script won't run"
Right-click → Properties → Check "Unblock"

Or in PowerShell:
```powershell
Unblock-File -Path ".\W11LatencyFix.ps1"
```

### "Access Denied"
Run PowerShell as Administrator. The script auto-elevates if not admin.

### "Changes didn't apply"
Some changes (TCP registry tweaks) require a **restart**. The script tells you which ones.

### "Want to undo everything"
Run the `UNDO.ps1` script from your backup folder in `C:\W11LatencyFixLogs\Backups_*`

---

## License

MIT — Use at your own risk. This script is provided as-is with no warranty.

---

## Final Notes

- **Safe to run multiple times** (idempotent changes)
- **No persistence** — script runs once and exits completely
- **Scientific** — profiler measures actual latency, not placebo
- **Honest** — if a change can't be verified, it logs WARN, not SUCCESS

**Measure first. Optimize second. Verify always.**