#Requires -Version 5.1
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
