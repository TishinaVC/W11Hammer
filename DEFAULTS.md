# W11LatencyFix - Verified Windows Default Registry Values

## Source Priority
1. **Oldest UNDO backup** (`Backups_20260527_074723`) - Actual pre-tweak values from this machine
2. **Microsoft official documentation** - docs.microsoft.com, learn.microsoft.com
3. **Reputable tech sources** - SS64, ElevenForum, TechTarget
4. **Community consensus** - Reddit r/techsupport, StackOverflow

---

## TCP/IP Parameters (HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters)

| Key | Default | Source | Notes |
|-----|---------|--------|-------|
| TcpNoDelay | **NOT PRESENT** | MS Docs | Nagle algorithm ON by default |
| TcpDelAckTicks | **NOT PRESENT** | MS Docs | Delayed ACK enabled |
| TCPMaxDataRetransmissions | **NOT PRESENT** | MS Docs | Default = 5 retries |
| DefaultTTL | **NOT PRESENT** | MS Docs | Default = 128 (Windows 10/11) |
| EnablePMTUDiscovery | **NOT PRESENT** | MS Docs | Enabled by default |
| GlobalMaxTcpWindowSize | **NOT PRESENT** | MS Docs | Auto-calculated |
| TcpWindowSize | **NOT PRESENT** | MS Docs | Auto-calculated |
| SackOpts | **NOT PRESENT** | MS Docs | SACK enabled by default |
| Tcp1323Opts | **NOT PRESENT** | MS Docs | RFC1323 enabled by default |
| MaxUserPort | **NOT PRESENT** | MS Docs | Range 49152-65535 |
| MaxFreeTcbs | **NOT PRESENT** | MS Docs | Auto-managed |
| MaxFreeTWTcbs | **NOT PRESENT** | MS Docs | Auto-managed |

**UNDO Action:** `Remove-ItemProperty` (delete key)

---

## DNS Cache (HKLM\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters)

| Key | Default | Source |
|-----|---------|--------|
| CacheHashTableBucketSize | **1** | StackOverflow |
| CacheHashTableSize | **384** (0x180) | StackOverflow |
| MaxCacheEntryTtlLimit | **3600** (0x0e10) or **64000** (0xfa00) | Multiple sources conflict |
| MaxSOACacheEntryTtlLimit | **301** (0x12d) | StackOverflow |

**UNDO Action:** `Remove-ItemProperty` (these keys do not exist by default on all systems)

---

## NetBIOS (HKLM\SYSTEM\CurrentControlSet\Services\NetBT\Parameters)

| Key | Default | Source |
|-----|---------|--------|
| NodeType | **NOT PRESENT** | MS Docs / CIS |
| EnableLMHosts | **1** | Security hardening guides |

**UNDO Action:** `Remove-ItemProperty` for NodeType; `Set-ItemProperty -Value 1` for EnableLMHosts

---

## QoS (HKLM\SOFTWARE\Policies\Microsoft\Windows\Psched)

| Key | Default | Source |
|-----|---------|--------|
| NonBestEffortLimit | **NOT PRESENT** | MS Docs |

When NOT present, Windows reserves 20% bandwidth (QoS behavior).
**UNDO Action:** `Remove-ItemProperty`

---

## SMB Server (HKLM\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters)

| Key | Default | Source |
|-----|---------|--------|
| SizReqBuf | **16644** | TechTarget |
| Size | **1** or **3** | Context-dependent |
| MaxWorkItems | **Not present / Auto** | MS Docs |
| MaxMpxCt | **50** | SmallVoid |

**UNDO Action:** `Remove-ItemProperty` (auto-managed by default)

## SMB Workstation (HKLM\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters)

| Key | Default | Source |
|-----|---------|--------|
| MaxCmds | **50** | SmallVoid |

**UNDO Action:** `Remove-ItemProperty`

---

## Visual / Explorer (HKCU keys)

| Key | Path | Default | Source |
|-----|------|---------|--------|
| MenuShowDelay | Control Panel\Desktop | **"400"** | ElevenForum, NinjaOne |
| MinAnimate | Control Panel\Desktop\WindowMetrics | **"1"** | NinjaOne |
| ListviewAlphaSelect | Explorer\Advanced | **1** | VisualFX defaults |
| TaskbarAnimations | Explorer\Advanced | **1** | VisualFX defaults |
| DisablePreviewDesktop | Explorer\Advanced | **0** | VisualFX defaults |
| HideFileExt | Explorer\Advanced | **1** | Oldest UNDO |
| Hidden | Explorer\Advanced | **2** | Oldest UNDO |
| SeparateProcess | Explorer\Advanced | **0** | GitHub issue #299 |
| NavPaneExpandToCurrentFolder | Explorer\Advanced | **0** | ElevenForum |
| EnableAutoTray | Explorer | **1** | Reddit r/sysadmin |

---

## Taskbar (HKCU keys)

| Key | Path | Default | Source |
|-----|------|---------|--------|
| ShowTaskViewButton | Explorer\Advanced | **1** | NinjaOne |
| ShowCortanaButton | Explorer\Advanced | **1** | Windows 11 default |
| PeopleBand | Explorer\Advanced | **1** | Windows 10/11 default |
| InkWorkspaceButtonVisibility | Explorer\Advanced | **1** | Windows 11 default |
| SearchboxTaskbarMode | Search | **2** | Oldest UNDO |
| TaskbarMn | Explorer\Advanced | **1** | Windows 11 default |

---

## Privacy (HKCU keys)

| Key | Path | Default | Source |
|-----|------|---------|--------|
| Enabled | AdvertisingInfo | **1** | MS Docs |
| Start_TrackProgs | Explorer\Advanced | **1** | SS64 |
| Start_TrackDocs | Explorer\Advanced | **1** | SS64 |
| RotatingLockScreenEnabled | ContentDeliveryManager | **1** | ElevenForum |
| SubscribedContent-338387Enabled | ContentDeliveryManager | **1** | ElevenForum |
| SubscribedContent-338388Enabled | ContentDeliveryManager | **1** | ElevenForum |
| SubscribedContent-338389Enabled | ContentDeliveryManager | **1** | ElevenForum |
| SubscribedContent-353698Enabled | ContentDeliveryManager | **1** | ElevenForum |
| SystemPaneSuggestionsEnabled | ContentDeliveryManager | **1** | ElevenForum |

---

## Windows 11 Start (HKCU keys)

| Key | Path | Default | Source |
|-----|------|---------|--------|
| ShowRecentList | Start | **1** | ElevenForum |
| ShowFrequentList | Start | **1** | ElevenForum |
| Start_IrisRecommendations | Explorer\Advanced | **1** | Windows 11 default |

---

## Gaming (HKCU keys)

| Key | Path | Default | Source |
|-----|------|---------|--------|
| AutoGameModeEnabled | GameBar | **0** | MS Q&A |
| UseNexusForGameBarEnabled | GameBar | **0** | MS Q&A |
| AppCaptureEnabled | GameDVR | **1** | Tom's Hardware |
| GameDVR_Enabled | GameDVR | **1** | Tom's Hardware |
| AllowGameDVR | HKLM\SOFTWARE\Policies\... | **1** or NOT PRESENT | Policy key |

---

## Multimedia SystemProfile (HKLM keys)

| Key | Path | Default | Source |
|-----|------|---------|--------|
| SystemResponsiveness | Multimedia\SystemProfile | **20** | MS Docs / Reddit |
| NetworkThrottlingIndex | Multimedia\SystemProfile | **10** | MS Docs |
| GPU Priority | SystemProfile\Tasks\Games | **8** | Gaming default |
| Priority | SystemProfile\Tasks\Games | **6** | Gaming default |

**Note:** GPU Priority and Priority for Games task may already be 8/6 by default.

---

## Legend

- **NOT PRESENT** = Key does not exist in default Windows installation. Removing it restores default behavior.
- Values shown are **decimal** unless prefixed with 0x (hex).

---

## Verification Method

1. Oldest UNDO (`Backups_20260527_074723\UNDO.ps1`) was compared against web research
2. Where sources conflict, oldest UNDO values were prioritized
3. TCP/IP keys that don't exist by default use `Remove-ItemProperty`
4. All other keys use `Set-ItemProperty` with verified default value
