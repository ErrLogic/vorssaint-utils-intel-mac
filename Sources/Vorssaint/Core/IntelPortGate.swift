// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

/// What the Intel build of this fork refuses to do, and why. The gate is a
/// compile-time fact: the official releases are Apple Silicon only, so an
/// Intel build can never take an update from them, and the fan write path was
/// designed and tested for Apple Silicon only. Reasons are English only.
enum IntelPortGate {
    /// The official release DMGs are arm64. Installing one over an Intel build
    /// would leave an app that cannot launch, so an Intel build never checks
    /// for, downloads or installs an update.
    static var selfUpdateSupported: Bool {
        #if arch(x86_64)
        return false
        #else
        return true
        #endif
    }

    /// Whether the recorder tries HEVC before H.264. Broadwell has no HEVC
    /// hardware encoder, so a software HEVC encode that passes the probe would
    /// still drop frames and load the CPU during a recording. An Intel build
    /// goes straight to H.264 and never runs the HEVC probe.
    static var hevcPreferred: Bool {
        #if arch(x86_64)
        return false
        #else
        return true
        #endif
    }

    static let fanControlReason =
        "Fan control is not supported on Intel Macs. The fan write path is only built for Apple Silicon."

    static let extraBrightnessReason =
        "Extra Brightness needs XDR display headroom, which this Intel Mac does not have."

    static let updatesDisabledNote =
        "Updates are turned off in this Intel build. The official releases are Apple Silicon only, "
        + "so to update, pull the fork and rebuild it with ./build.sh."
}
