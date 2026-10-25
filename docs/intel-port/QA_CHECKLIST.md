# Intel Port QA Checklist (Phase 4)

On-device QA for the Intel build on the MacBook Air 2017 (MacBookAir7,2, i5-5350U, 8 GB, macOS 15.8.1 via
OCLP). Run it on the **release build** (`./build.sh`, no `--dev`), not the developer variant: the
developer build skips the updater on its own and would hide the Phase 1 checks.

Result codes: `PASS`, `FAIL`, `GATED` (blocked on purpose, with a reason shown), `SKIP` (not testable here,
say why). A failing feature is **gated in `hardwareUnsupportedReason`** with a clear reason, never deleted
(plan, Phase 4). Record the build under test first.

| Item | Value |
|---|---|
| Commit | `git rev-parse --short HEAD` → |
| Build time | |
| Bundle | `build/stage/Vorssaint.app` |
| Date / tester | |

## 0. Run the build

```sh
open "build/stage/Vorssaint.app"
PID=$(pgrep -x Vorssaint)
```

The release build is signed with the local self-signed identity, so macOS may ask for a keychain
password once. Grant Accessibility and Screen Recording when a feature asks; those grants survive
rebuilds under this identity.

## 1. Phase 1 gates (release build)

| # | Check | How | Result |
|---|---|---|---|
| 1.1 | No network call to GitHub | Launch, wait 2 min (the first update check was due at 6 s, then hourly): `nettop -p $PID -L 1 -s 1 -m tcp -x` and `lsof -nP -i -a -p $PID`. Expect no connection to `api.github.com` / `github.com`. For a stricter run, watch with LuLu or Little Snitch. | PASS (2026-10-25): `nettop -p $PID -L 100 -s 1 -x` from the first second of launch for 100 s recorded no connection row at all; `lsof -i` empty. Positive control: the same capture on a `curl` to localhost lists its process and TCP row. Auto-check was at its default (on). |
| 1.2 | Updates page explains itself | Settings → Updates shows the "Updates are turned off in this Intel build…" note, no toggles, no Check Now button. | PASS (2026-10-25, observed by the tester) |
| 1.3 | Menu "Check for updates…" | Opens Settings, makes no request (repeat 1.1). | |
| 1.4 | Fan Control greyed | Settings → Features: row disabled, reason "Fan control is not supported on Intel Macs…". | PASS (2026-10-25, observed by the tester) |
| 1.5 | Extra Brightness greyed | Same, reason "Extra Brightness needs XDR display headroom…". On a clean first run it must not be installed. | PASS (2026-10-25, observed by the tester; `featureAvailable.extraBrightness` = 0) |
| 1.6 | First-run picker | Reset onboarding (`defaults delete com.vorssaint.utils`), relaunch: the picker refuses Fan Control and Extra Brightness with a tooltip; presets Essential, Windows, Battery never install them. | PASS for the Essential preset (2026-10-25): the installed set is keepAwake, mixer and the six monitors; `featureAvailable.fanControl` = 0. Windows and Battery presets not tried. |
| 1.7 | Install-all | Hub "install all": both stay uninstalled, counter reaches its maximum without hanging one short. | |
| 1.8 | No fan helper | `launchctl list \| grep -i vorssaint` shows no fan-control helper; no admin prompt appeared. | PASS (2026-10-25): the only `launchctl` entry is the app itself; no admin prompt. |

## 2. Resource use

Measure with the Essential preset, then again with everything you plan to use daily. Quit other apps first
and let the app settle for 2 minutes after launch.

```sh
# Idle CPU: 7 samples 10 s apart; ignore the first line (it averages since launch).
top -l 7 -s 10 -pid $PID -stats pid,cpu,mem,rsize
# Memory footprint.
footprint -p $PID
```

| # | Scenario | CPU % (avg of samples 2–7) | Footprint MB | Result / notes |
|---|---|---|---|---|
| 2.1 | Essential preset, no panel open | 0.0 (7 samples; CPU time unchanged over 30 s) | 79 (peak 82; RSS 159) | PASS (2026-10-25, release build, 27 min after launch) |
| 2.2 | Menu panel open, monitor visible | see 2.4 (measured together with 2.3 and 2.4) | 88 | measured combined |
| 2.3 | Dynamic Island on, idle | see 2.4 | 88 | measured combined; installed island set: calendar, notifications, gestures, timer, accessories, lyrics, queue, live equalizer, downloads, watch |
| 2.4 | Dynamic Island on, music playing | 3.6 (avg of samples 2–7: 3.2, 3.0, 4.1, 4.2, 2.9, 4.2) | 88 (peak 90) | PASS (2026-10-25): panel open, island on, Spotify playing. System context: WindowServer ~21 %, Spotify ~9 %. WindowServer was already ~25 % before the app was launched, so it is not caused by the island. |
| 2.5 | Daily set (all you use) | | | |
| 2.6 | Under CPU load (`yes > /dev/null` × 4, then `pkill yes`): does the app stay responsive? | | | |

Target: well under 5 % CPU at idle on Essential. If 2.1–2.3 are high, lower the monitor sampling defaults
on x86_64 (plan, Phase 3 item 3) as a separate change.

## 3. Sensors

Compare the panel with `sudo powermetrics --samplers smc -n 1 -i 1000` and Macs Fan Control, taken
together, idle and under load.

| # | Check | Expect | Result |
|---|---|---|---|
| 3.1 | CPU temperature (panel / menu bar) | Equals powermetrics "CPU die temperature" (TC0F) within 1 °C | PASS (2026-10-25): panel 78 °C vs TC0F 78.1 in the same second (`qa/panel-system-tab.png`); powermetrics match shown in Phase 2 |
| 3.2 | CPU per-core list | Two cores, no P/E grouping | |
| 3.3 | GPU temperature | Tracks MFC "GPU Intel HD Graphics 6000" (TCGC) | PASS (2026-10-25): panel 71 °C vs TCGC 71.0 in the same second; MFC "GPU Intel HD Graphics 6000" 75.0 vs TCGC 75.0 in a second capture (`qa/mfc-release-run.png`) |
| 3.4 | Battery temperature | Matches MFC "Battery Max" | PASS (2026-10-25): panel 38 °C vs TB0T 37.7 in the same second (`qa/panel-power-tab.png`); the keys also match MFC (TBXT 37.6 = Battery Max, TB2T 34.6 = Sensor 2) |
| 3.5 | Fan speed readout | Matches MFC fan RPM; read-only | PARTIAL (2026-10-25): SMC F0Ac 1406 vs MFC 1413 rpm a second or two apart; the app's own readout is not seen yet |
| 3.6 | Battery: charge %, health, charging sign | Charge/discharge sign is right (T6); health is plausible | PARTIAL (2026-10-25). Discharge PASS: on battery, `Amperage` -1240 mA at 8.33 V → panel "On battery 10 W"; charge 98 % = 5913/6019; health 84 % = 6019/7150 (the gauge re-learned MaxCapacity from 6162 to 6019 after unplugging); "4h 46m" = TimeRemaining 286 min; 480 cycles (`qa/panel-power-tab-on-battery.png`). IOKit hands `Amperage` over as a signed 32-bit number (`ioreg` prints it unsigned), so `as? Int` is correct. Note: for about a minute after unplugging the gauge is stale (Amperage -5 mA, time "Calculating…"), so the panel shows 0.0 W; this is the battery, not the app. Charging sign deferred: after plugging in, macOS reports the pack as fully charged at 97.8 % (`FullyCharged` = Yes, `IsCharging` = No), so there is no charge current to read. Retest once the battery is below about 90 %. Finding (cosmetic, upstream logic): on AC and full, the gauge idles at -5 mA, so the Battery row reads "On battery 0,0 W" with the adapter row shown at the same time (`qa/panel-power-tab-full-on-ac.png`); the caption comes only from the sign of `batteryWatts` in `PowerSection.swift`. |
| 3.7 | System / adapter power | Shows a value or hides cleanly (PSTR/PDTR, T7) | PASS (2026-10-25): System 11 W vs PSTR 11.1; Adapter 12 W (45 W max) vs PDTR 11.4, within the second-to-second fluctuation of the power graph |
| 3.8 | GPU usage % | Shows a value or hides cleanly (T5, IOAccelerator "Device Utilization %") | PASS (2026-10-25): the HD 6000 driver under OCLP publishes it; panel shows GPU 2 % |
| 3.9 | `Vorssaint --sensors` | TC0F/TC1C/TC2C `cpu-core`, TCMX `cpu-aux`, TCGC `gpu` | PASS (2026-10-25, release build) |

## 4. Features

Tag `[GFX]` marks features that depend on the OCLP graphics patches (ScreenCaptureKit, Metal, window
previews, video). Test each one on its own; a hang or a black frame is a FAIL.
Install a feature from Settings → Features before testing it.

### Windows and Dock

| Feature | Test | Result |
|---|---|---|
| switcher `[GFX]` | Alt-Tab style switcher opens, shows window previews, switches | |
| dockPreview `[GFX]` | Hover a Dock icon: preview appears, no flicker | |
| dockClick | Click a running app's icon: minimize / hide / cycle as configured | |
| windowMaximizer | Maximize shortcut and double-click behave | |
| windowLayout | Snap left/right/halves; Stage Manager reserve space if enabled | |
| autoQuit | Close last window of a test app: it quits after the delay | |
| spacesOrder | Spaces keep their set order after switching | |

### Mouse and keyboard

| Feature | Test | Result |
|---|---|---|
| scrollInverter | Mouse vs trackpad scroll direction independent | |
| scrollHorizontal | Modifier + wheel scrolls sideways | |
| focusFollowsMouse | Focus follows pointer; turn off cleanly | |
| smoothScroll / linearScroll | Wheel feels smooth, no stutter at idle CPU | |
| mouseAcceleration | Slider changes pointer speed; reset on quit | |
| mouseNavigation / mouseButtonShortcuts / middleClick | Extra buttons trigger their actions (needs a mouse with buttons) | |
| mouseClickDebounce | Double-click chatter filtered | |
| keyboardDebounce | Repeated key ignored within the window | |
| textSnippets | Abbreviation expands in TextEdit | |
| superKey | Chord works, no stuck modifiers | |
| quitWindowProtection | ⌘Q needs the confirmation | |

### Clipboard and files

| Feature | Test | Result |
|---|---|---|
| clipboardHistory | Copy text/image/file: history lists them; paste back | |
| pastePlain | Paste as plain text strips formatting | |
| finderCutPaste | ⌘X / ⌘V moves a file in Finder | |
| finderRename | Rename shortcut in Finder | |
| shelf | Drag a file in and out | |
| urlCleaner | Tracking parameters stripped from a copied URL | |
| diskImageInstaller | Open a `.dmg` with an app: install flow runs | |

### Sound

| Feature | Test | Result |
|---|---|---|
| mixer | Per-app volume changes audible; levels move | |
| soundOutputSwitcher | Switch between speakers and headphones/AirPlay | |
| audioPriority | Priority list reorders outputs | |
| micMute | Shortcut mutes the mic, indicator updates | |
| musicBlock | Blocks the Music/Spotify autostart | |

### Energy and display

| Feature | Test | Result |
|---|---|---|
| keepAwake | Prevents sleep; timer ends it; lid-close behaviour | |
| brightness | Brightness keys / slider; software dimming route if used | |
| extraBrightness | **GATED** (see 1.5) | |
| bluetoothSleep | Bluetooth off on sleep, back on wake | |

### Tools

| Feature | Test | Result |
|---|---|---|
| quickLauncher / commandBar | Open by shortcut, search, run an action; emoji panel | |
| quickToggles | Toggles (dark mode, etc.) flip | |
| colorPicker `[GFX]` | Pick a color from the screen | |
| screenOCR `[GFX]` | Select an area: text recognised (Vision runs on Intel, slower) | |
| cleaningMode | Locks input, unlock gesture works | |
| mediaTools `[GFX]` | Convert a video; **default codec is H.264**; HEVC selectable and works (slow is fine) | |
| cleaner / uninstaller / homebrew | Scan runs; uninstall a test app; brew list loads | |
| appUpdates | App update list loads (this is *other* apps, not the fork) | |
| screenshot `[GFX]` | Area, window, full screen capture; editor opens | |
| scrolling capture `[GFX]` | Capture a long page; width and overlap correct | |
| cameraPreview | Camera window opens (permission prompt) | |
| radialMenu | Opens at the pointer, actions fire | |
| scratchpad | Create, edit, persist a note | |
| screenRecorder `[GFX]` | Record 10 s at 1080p: **file is H.264**, no dropped-frame warning, plays back; with system audio and mic | |
| recorder editor/export `[GFX]` | Trim and export: output is H.264, completes | |
| wallpaper `[GFX]` | Set an animated / dynamic wallpaper; CPU stays reasonable | |
| killProcess / portManager | List processes/ports, terminate a test process | |

### Dynamic Island

The Air has no notch: the island must still show as a floating capsule. Judge smoothness on this CPU.

| Feature | Test | Result |
|---|---|---|
| notch `[GFX]` | Appears, expands on hover, animations smooth | |
| notchCalendar / notchNotifications / notchTimer | Show events, notifications, run a timer | |
| notchGestures | Gestures open/close | |
| notchAccessories | Battery/AirPods/charging chips | |
| notchLyrics / notchQueue / notchLiveEqualizer | Music extras work with Music / Spotify | |
| notchDownloads / notchAgents / notchWatch / notchMascot | Each shows its content | |
| Now Playing adapter | Track title and artwork appear (the perl-loaded x86_64 dylib, F6) | |

### System monitor

| Feature | Test | Result |
|---|---|---|
| monitorCPU / monitorGPU / monitorMemory / monitorNetwork / monitorDisk / monitorPower | Each panel shows live data; menu bar items render | |
| connectedDevices | Lists USB devices and peripheral battery | |
| fanControl | **GATED** (see 1.4) | |

## 5. System

| # | Check | Result |
|---|---|---|
| 5.1 | Launch at login works; relaunch after reboot restores state | |
| 5.2 | Quit: the app leaves nothing running (no helper, no stuck modifiers) | |
| 5.3 | Uninstall (`Tools/uninstall.sh` or in-app) removes preferences | |
| 5.4 | No crash logs in `~/Library/Logs/DiagnosticReports` for Vorssaint during the run | PASS so far (2026-10-25): no Vorssaint report in DiagnosticReports after a 27-minute session. |
| 5.5 | Sleep/wake and display unplug/replug: windows, island and monitors recover | |

## 6. Failure handling

1. Reproduce it twice and note whether it needs a specific feature on, a permission, or graphics.
2. If it depends on the OCLP graphics patches or Intel hardware and cannot be fixed cheaply, add the
   feature to `hardwareUnsupportedReason` under `#if arch(x86_64)` in
   `Sources/Vorssaint/App/FeatureRuntime.swift`, with its reason in `IntelPortGate`.
3. If it is a code bug, fix it on its own branch and add a test.
4. Record the outcome in the table above and keep the row.

## 7. Summary

| | Count |
|---|---|
| PASS | |
| FAIL (fixed / gated) | |
| GATED on purpose | 2 (Fan Control, Extra Brightness) |
| SKIP | |

Idle CPU on Essential: ___ %. Footprint: ___ MB. Open items: ___
