// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// The Intel build must never take an update from the arm64 releases and must
/// refuse the two features it cannot run. The gate itself is a pure value; the
/// call sites are checked in source, as the other feature contracts do.
enum IntelPortGateTests {
    static func run(_ suite: TestSuite) {
        #if arch(x86_64)
        suite.expect(!IntelPortGate.selfUpdateSupported,
                     "an x86_64 build never updates itself from the arm64 releases")
        #else
        suite.expect(IntelPortGate.selfUpdateSupported,
                     "an arm64 build keeps its self-updater")
        #endif

        let reasons = [IntelPortGate.fanControlReason,
                       IntelPortGate.extraBrightnessReason,
                       IntelPortGate.updatesDisabledNote]
        suite.expect(reasons.allSatisfy { !$0.isEmpty }, "every blocked path has a reason to show")
        suite.expect(Set(reasons).count == reasons.count, "each reason names its own feature")

        let updates = source("Sources/Vorssaint/Services/Update/UpdateService.swift")
        suite.expect(updates.components(separatedBy: "IntelPortGate.selfUpdateSupported").count - 1 >= 5,
                     "start, schedule, check, stale check and install are all gated")
        for entry in ["func startAutomaticChecks()", "private func configureAutomaticChecks()",
                      "func check(manual: Bool)", "func checkIfStale(", "func downloadAndInstall()"] {
            suite.expect(updates.contains(entry), "\(entry) still exists, so its gate was reviewed")
        }

        let runtime = source("Sources/Vorssaint/App/FeatureRuntime.swift")
        suite.expect(runtime.contains("#if arch(x86_64)")
                     && runtime.contains("IntelPortGate.fanControlReason")
                     && runtime.contains("IntelPortGate.extraBrightnessReason"),
                     "the hardware gate blocks fan control and Extra Brightness on x86_64")
        suite.expect(runtime.contains("return !available || feature.isHardwareSupported"),
                     "every install path still passes the hardware gate")

        let settings = source("Sources/Vorssaint/UI/Settings/SettingsView.swift")
        suite.expect(settings.contains("IntelPortGate.updatesDisabledNote"),
                     "Settings explains that updates come from rebuilding the fork")
    }

    private static func source(_ path: String) -> String {
        (try? String(contentsOfFile: path, encoding: .utf8)) ?? ""
    }
}
