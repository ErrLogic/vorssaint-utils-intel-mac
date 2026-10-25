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
| Bundle | `build/stage.noindex/Vorssaint.app` |
| Date / tester | |

## 0. Run the build

```sh
open "build/stage.noindex/Vorssaint.app"
PID=$(pgrep -x Vorssaint)
```

The release build is signed with the local self-signed identity, so macOS may ask for a keychain
password once. Grant Accessibility and Screen Recording when a feature asks; those grants survive
rebuilds under this identity.

## 1. Phase 1 gates (release build)

| # | Check | How | Result |
|---|---|---|---|
| 1.1 | No network call to GitHub | Launch, wait 2 min (the first update check was due at 6 s, then hourly): `nettop -p $PID -L 1 -s 1 -m tcp -x` and `lsof -nP -i -a -p $PID`. Expect no connection to `api.github.com` / `github.com`. For a stricter run, watch with LuLu or Little Snitch. | |
| 1.2 | Updates page explains itself | Settings → Updates shows the "Updates are turned off in this Intel build…" note, no toggles, no Check Now button. | |
| 1.3 | Menu "Check for updates…" | Opens Settings, makes no request (repeat 1.1). | |
| 1.4 | Fan Control greyed | Settings → Features: row disabled, reason "Fan control is not supported on Intel Macs…". | |
| 1.5 | Extra Brightness greyed | Same, reason "Extra Brightness needs XDR display headroom…". On a clean first run it must not be installed. | |
| 1.6 | First-run picker | Reset onboarding (`defaults delete com.vorssaint.utils`), relaunch: the picker refuses Fan Control and Extra Brightness with a tooltip; presets Essential, Windows, Battery never install them. | |
| 1.7 | Install-all | Hub "install all": both stay uninstalled, counter reaches its maximum without hanging one short. | |
| 1.8 | No fan helper | `launchctl list \| grep -i vorssaint` shows no fan-control helper; no admin prompt appeared. | |

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
| 2.1 | Essential preset, no panel open | | | |
| 2.2 | Menu panel open, monitor visible | | | |
| 2.3 | Dynamic Island on, idle | | | |
| 2.4 | Dynamic Island on, music playing | | | |
| 2.5 | Daily set (all you use) | | | |
| 2.6 | Under CPU load (`yes > /dev/null` × 4, then `pkill yes`): does the app stay responsive? | | | |

Target: well under 5 % CPU at idle on Essential. If 2.1–2.3 are high, lower the monitor sampling defaults
on x86_64 (plan, Phase 3 item 3) as a separate change.

## 3. Sensors

Compare the panel with `sudo powermetrics --samplers smc -n 1 -i 1000` and Macs Fan Control, taken
together, idle and under load.

| # | Check | Expect | Result |
|---|---|---|---|
| 3.1 | CPU temperature (panel / menu bar) | Equals powermetrics "CPU die temperature" (TC0F) within 1 °C | |
| 3.2 | CPU per-core list | Two cores, no P/E grouping | |
| 3.3 | GPU temperature | Tracks MFC "GPU Intel HD Graphics 6000" (TCGC) | |
| 3.4 | Battery temperature | Matches MFC "Battery Max" | |
| 3.5 | Fan speed readout | Matches MFC fan RPM; read-only | |
| 3.6 | Battery: charge %, health, charging sign | Charge/discharge sign is right (T6); health is plausible | |
| 3.7 | System / adapter power | Shows a value or hides cleanly (PSTR/PDTR, T7) | |
| 3.8 | GPU usage % | Shows a value or hides cleanly (T5, IOAccelerator "Device Utilization %") | |
| 3.9 | `Vorssaint --sensors` | TC0F/TC1C/TC2C `cpu-core`, TCMX `cpu-aux`, TCGC `gpu` | |

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
| 5.4 | No crash logs in `~/Library/Logs/DiagnosticReports` for Vorssaint during the run | |
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
