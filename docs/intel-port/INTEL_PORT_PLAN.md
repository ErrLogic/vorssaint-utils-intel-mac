# Intel Port Plan — vorssaint-utils-intel-mac

Personal fork of `vorssaint/vorssaint-utils` (fork point: upstream `4f510c0`), ported to run on Intel Macs.
This fork does **not** track upstream on a schedule; upstream fixes are cherry-picked by hand when wanted.

## Target machine

| Item | Value |
|---|---|
| Model | MacBook Air 2017 (MacBookAir7,2) |
| CPU | Intel Core i5-5350U (Broadwell, 2C/4T) |
| RAM | 8 GB |
| OS | macOS 15.8.1 (24H32) via OpenCore Legacy Patcher |
| Toolchain | Command Line Tools only — Swift 6.1.2, SDK 15.5 |
| Display | No notch, no XDR/EDR headroom |
| GPU | Intel HD Graphics 6000 (OCLP root-patched) |

## Guiding principles

1. **Gate, don't delete.** Unsupported features are blocked through the app's existing hardware gate
   (`AppFeature.hardwareUnsupportedReason` in `Sources/Vorssaint/App/FeatureRuntime.swift`), not removed.
   The UI already greys out and explains blocked features, and the change stays a few lines per feature.
2. **Compile-time for architecture facts, runtime for hardware facts.**
   - `#if arch(x86_64)` only where the answer can never change on Intel (self-updater, fan control writes).
   - Runtime probes where the hardware decides (EDR headroom, HEVC encoder, SMC keys present).
3. **Intel code lives in new files** (e.g. `IntelSMCSensorMap.swift`) so the upstream files keep small diffs
   and cherry-picks stay possible.
4. **Never write to the SMC on Intel.** Fan control stays disabled; read-only sensors only.
5. **Every sensor key comes from an on-device dump**, never from memory or forum lists.

## Audit findings

Confidence: **High** = read directly from code. **Medium** = code read plus general platform knowledge, not yet run on the device. **Low** = depends on OCLP/hardware behaviour not observable from source.

### Build

| # | Finding | Location | Confidence |
|---|---|---|---|
| B1 | Target triple hardcoded to `arm64-apple-macosx14.0`; used by app, fan helper, Now Playing adapter and tests. Only hard build blocker found. | `build.sh:65` | High |
| B2 | Toolchain is compatible: upstream CI has a compatibility job on Swift 6.0.3 / SDK 15.2; this machine has 6.1.2 / 15.5. `#if compiler(>=6.2)` blocks fall back to the older path. | `.github/workflows/ci.yml`, ~17 UI files | Medium |
| B3 | Pinned `MacOSX26.sdk` is absent, so `build.sh` uses `xcrun` SDK 15.5 with no compat flags. Intended path. | `build.sh:199-213` | High |
| B4 | `actool` absent with CLT only → adaptive icon skipped, falls back to `AppIcon.icns`. Cosmetic. | `build.sh:641-672` | High |
| B5 | Signing: with no identity, `build.sh` creates a local self-signed identity (keychain prompt expected). | `build.sh:104` | High |
| B6 | Full build on 2C/4T + 8 GB will be slow; `-j hw.logicalcpu` = 4 parallel jobs may hit swap. | `build.sh:614` | Low (estimate) |

### Safety — must fix before using a release build

| # | Finding | Location | Confidence |
|---|---|---|---|
| S1 | **Self-updater would replace the Intel build with the official arm64 build.** It polls `vorssaint/vorssaint-utils` releases hourly, picks the first `.dmg`, and verifies only the maintainer's Team ID (`3D485NHW29`) — no architecture check. The official DMG passes that check, so clicking "Update" installs an app that cannot launch on this Mac. `--dev` builds already skip auto-checks. | `Services/Update/UpdateService.swift:30,63,102,208`; `UpdateInstallerSupport.swift:66,123` | High |
| S2 | Fan control requires `F<n>Md`/`F<n>md` mode keys. Pre-T2 Intel Macs use a different manual-mode scheme, so discovery should throw `.unsupported` and the existing gate (`hasControllableFan`) should already block it. Still force-block on x86_64: the write path was designed and tested for Apple Silicon only. | `Services/FanControl/FanControlHardware.swift:300-305,454`; `App/FeatureRuntime.swift:424-431` | Medium |

### Sensors — wrong or missing data on Intel

| # | Finding | Location | Confidence |
|---|---|---|---|
| T1 | CPU temperature: `isCPUTemperatureKey` accepts only `Tp*`/`Te*` (Apple Silicon naming). Intel brand string maps to `.generic`, which falls back to the **max of all `Tp*`/`Te*` readings**. On Intel those prefixes are other sensors, so the panel can show a non-CPU value labelled as CPU. Intel CPU sensors are typically the `TC*` family. | `Services/Metrics/TemperatureSensorSelector.swift:86,98-114,144`; `Services/SystemMonitor/SystemMonitor.swift:1074-1093` | High (code) / Medium (Intel key names) |
| T2 | GPU temperature filter is `hasPrefix("Tg")` (lowercase, case-sensitive). Intel GPU keys typically use uppercase `TG*` or PECI keys, so likely no GPU temperature. | `SystemMonitor.swift:1076,1092`; `FanControlHardware.swift:315` | Medium |
| T3 | Battery temperature regex `^TB[0-9]T$` matches Intel naming. Should work. | `SystemMonitor.swift:1077` | Medium |
| T4 | SMC value codec already decodes `sp78`, `fpe2`, `flt `, `ui8 `, so Intel types are covered. | `Services/FanControl/FanControlSupport.swift:422-470` | High |
| T5 | GPU usage reads `PerformanceStatistics` → "Device Utilization %" from `IOAccelerator`; the code already handles multiple Intel accelerators. Whether the HD 6000 driver under OCLP publishes that key is unverified. | `SystemMonitor.swift:1195` | Low |
| T6 | Battery: charge % = `CurrentCapacity/MaxCapacity` (works for Intel mAh values); health falls back to `NominalChargeCapacity`/`DesignCapacity` if `system_profiler` lacks the field. Sign of `Amperage` on Intel must be checked on-device. | `Services/Metrics/PowerSampler.swift:84-130`; `MaxCapacityProbe.swift` | Medium |
| T7 | System/adapter power use SMC `PSTR`/`PDTR`; nil-safe if absent. | `PowerSampler.swift:57-82` | High (nil-safe) / Low (availability) |
| T8 | Per-core P/E grouping is `#if arch(arm64)`; Intel returns no groups, so a flat core list. Correct behaviour. | `Services/Metrics/CPUCoreSampler.swift:196` | High |

### Features — hardware or performance limits

| # | Finding | Location | Confidence |
|---|---|---|---|
| F1 | Extra Brightness needs real XDR headroom; it already self-detects (`capabilityFloor` 2.05; MacBook Air reports 2.0). Add to the hardware gate so it is not offered at all. | `Services/Display/ExtraBrightnessSupport.swift`; `ExtraBrightnessService.swift:111` | High |
| F2 | Recorder prefers HEVC, falling back to H.264 only when a test encode fails. Broadwell has no HEVC hardware encoder; if the software HEVC encoder passes the probe, real-time recording will drop frames and load the CPU. Prefer H.264 on x86_64. | `Services/Recorder/RecorderWriter.swift:84-90,135`; `RecorderExporter.swift:305` | Medium |
| F3 | Media tools offer HEVC presets via `avconvert`; works in software but slow. Default to H.264 on x86_64, keep HEVC selectable. | `Services/Media/MediaService.swift:990` | Medium |
| F4 | Notch / Dynamic Island already handles displays without a notch. No arch issue; performance on Broadwell to be judged in QA. | `Services/Notch/NotchSupport.swift:1644-1651` | Medium |
| F5 | ScreenCaptureKit / Metal users (screenshots, scrolling capture, recorder, window/Dock previews) are architecture-neutral but depend on OCLP graphics patches. Test one by one. | `Services/QuickTools/*`, `Services/Recorder/*`, `Services/Switcher/*` | Low |
| F6 | Now Playing adapter is loaded through `/usr/bin/perl` (universal binary), so an x86_64 dylib loads natively. | `build.sh:59-63,631` | Medium |
| F7 | `EventTimestamp` reads `mach_timebase_info` at runtime (1/1 on Intel → returns raw). No change needed. | `Services/EventTimestamp.swift` | High |
| F8 | Mouse acceleration uses a private HID event-system module; arch-neutral. | `Sources/HIDEventSystem`, `Services/MouseAcceleration/*` | Medium |
| F9 | No CoreML, FoundationModels or ANE usage found. Vision (OCR) works on Intel, slower. | framework import inventory | High |

### Tests

Unit tests assert Apple Silicon platform mapping by brand string (pure functions), so they pass on any host. New Intel mappings need their own tests in `Tests/MetricsFeatureTests.swift`.

## Phased plan

Each phase is one branch, one Claude Code session, one commit series. Do not start a phase before the previous one is verified on the MacBook.

### Phase 0 — Baseline build and sensor dump (no feature changes)

Goal: prove the x86_64 build works and capture real SMC data.

1. Make the target architecture configurable in `build.sh` (B1): default to the host architecture
   (`uname -m`), overridable with `VORSSAINT_ARCH=arm64|x86_64`.
2. `./build.sh --dev`, record build time, run `./build/Vorssaint --selftest`.
3. Add a read-only diagnostic CLI under `Tools/` that reuses `SMCClient.swift` and prints every SMC key
   starting with `T`, `F` or `P` with type, size and decoded value. Run it idle and under load; save the
   output to `docs/intel-port/smc-dump-MacBookAir7,2.txt`.
4. Record `ioreg -rc AppleSmartBattery` and `ioreg -rc IOAccelerator -d 1` output in the same folder.

Exit criteria: dev build launches; dumps committed.

### Phase 1 — Safety gates

1. Disable the self-updater on x86_64 at compile time (S1): no checks, no download, and the Settings row
   says updates come from rebuilding the fork. Keep the code; gate the entry points.
2. Extend `hardwareUnsupportedReason` (`FeatureRuntime.swift:424`) with `#if arch(x86_64)` cases:
   `.fanControl` (S2), `.extraBrightness` (F1). Reasons localized in English at minimum.
3. Make sure no installed-state is stranded: an Intel first run must never auto-enable a blocked feature.

Exit criteria: release build (`./build.sh`) shows both features greyed with a reason; no network call to
the GitHub releases API (verify with Little Snitch/LuLu or `nettop`).

### Phase 2 — Intel sensor map

1. Add `case intel` to `CPUTemperaturePlatform`; `platform(brandString:)` maps `Intel(R) …` to it.
2. New file `Services/Metrics/IntelSMCSensorMap.swift` with CPU core/package keys and GPU keys **taken
   from the Phase 0 dump only**.
3. `isCPUTemperatureKey`/`isCPUCoreKey` and the GPU key filters (`SystemMonitor.swift:1076,1092`,
   `FanControlHardware.swift:315`) consult the Intel map when the platform is `.intel`.
4. For `.intel`, no fallback to "max of all `T*` keys" (T1): show nothing rather than a wrong number.
5. Unit tests for the Intel brand-string mapping and key selection.

Exit criteria: CPU temperature tracks `sudo powermetrics --samplers smc -n 1` within a few °C under load.

### Phase 3 — Performance defaults for Broadwell

1. Recorder: on x86_64 use H.264 directly, skip the HEVC probe (F2).
2. Media tools: default codec H.264 on x86_64; HEVC stays selectable (F3).
3. Optional: lower monitor sampling frequency defaults on x86_64 if Phase 4 shows high idle CPU.

### Phase 4 — On-device QA

Run the checklist in `docs/intel-port/QA_CHECKLIST.md` (to be written after Phase 0) feature by feature:
idle CPU % of the app, memory footprint, and pass/fail per feature. Anything failing because of OCLP
graphics gets gated in `hardwareUnsupportedReason` with a clear reason, not deleted.

### Phase 5 — Fork identity (optional, required only if the build is ever shared)

Per `TRADEMARKS.md`: own app name, bundle ID, icon. Not needed for personal use.

## Claude Code session prompts

Use one prompt per phase. Each assumes Claude Code runs in the repo root on the MacBook.

### Phase 0

```text
Context: This is a personal fork of vorssaint-utils being ported to an Intel MacBook Air 2017
(i5-5350U, 8 GB, macOS 15.8.1 via OCLP, Command Line Tools only, Swift 6.1.2, SDK 15.5).
Read docs/intel-port/INTEL_PORT_PLAN.md first; it is the source of truth.

Task: Phase 0 only.
1. In build.sh, replace the hardcoded TARGET with an architecture chosen from the host
   (uname -m), overridable via VORSSAINT_ARCH (arm64|x86_64). Reject any other value with a clear error.
   Do not change anything else in build.sh.
2. Create Tools/SMCDump.swift: a read-only CLI that reuses Sources/Vorssaint/Services/SystemMonitor/SMCClient.swift
   and the decoder in FanControlSupport.swift, enumerates all SMC keys, and prints keys whose names start
   with T, F or P as: name, data type, size, decoded value. It must never write to the SMC.
   Add a build.sh flag or a small script under Tools/ that compiles it for the host arch.
3. Do not modify any other source file.

Constraints: minimal diffs; English for code and comments; no new dependencies.
When done: show me the diff summary and the exact commands to build and run the dump. Stop there.
```

### Phase 1

```text
Read docs/intel-port/INTEL_PORT_PLAN.md (findings S1, S2, F1 and Phase 1).

Task: Phase 1 only.
1. Disable the self-updater on x86_64 using #if arch(x86_64) at the entry points in
   Sources/Vorssaint/Services/Update/UpdateService.swift (automatic checks, manual check, downloadAndInstall).
   The Settings UI must show that updates come from rebuilding the fork instead of an update button.
   Keep the arm64 behaviour byte-for-byte unchanged.
2. Extend AppFeature.hardwareUnsupportedReason in Sources/Vorssaint/App/FeatureRuntime.swift with
   #if arch(x86_64) cases for .fanControl and .extraBrightness, each with a user-facing reason string
   added through the existing localization structs (English required; other languages may reuse English).
3. Verify that a first run on x86_64 cannot enable a blocked feature through presets or the first-run picker.
4. Add or update unit tests where the logic is pure.

Run ./build.sh --test and ./build.sh --dev. Report results and the diff summary. Stop there.
```

### Phase 2

```text
Read docs/intel-port/INTEL_PORT_PLAN.md (findings T1, T2, Phase 2) and the SMC dump in
docs/intel-port/smc-dump-MacBookAir7,2.txt.

Task: Phase 2 only.
1. Add case intel to CPUTemperaturePlatform; map brand strings starting with "Intel(R)" to it.
2. Create Sources/Vorssaint/Services/Metrics/IntelSMCSensorMap.swift holding CPU and GPU temperature
   keys. Use ONLY keys that appear in the dump with plausible values; for each key, cite the dump line
   in a comment. If the dump is ambiguous, stop and ask me instead of guessing.
3. Route isCPUTemperatureKey, isCPUCoreKey and the GPU key filters (SystemMonitor.swift and
   FanControlHardware.swift) through the Intel map when the platform is .intel.
4. For .intel, do not fall back to the max of unrelated T* keys; return nil when mapped keys are silent.
5. Add tests in Tests/MetricsFeatureTests.swift for the Intel mapping.
6. Make sure the fan helper target in build.sh still compiles (it includes TemperatureSensorSelector.swift).

Run ./build.sh --test and ./build.sh --dev. Report results. Stop there.
```

### Phase 3

```text
Read docs/intel-port/INTEL_PORT_PLAN.md (findings F2, F3, Phase 3).

Task: Phase 3 only.
1. Recorder: on x86_64 select H.264 directly and skip the HEVC probe in RecorderWriter and RecorderExporter.
2. Media tools: default to H.264 on x86_64; HEVC must remain selectable by the user.
Keep arm64 behaviour unchanged. Run ./build.sh --test and ./build.sh --dev. Report results. Stop there.
```
