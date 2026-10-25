// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

/// Temperature sensors of an Intel Mac. Every key was matched on a
/// MacBookAir7,2 (i5-5350U) against Macs Fan Control and powermetrics, reading the SMC and the
/// app at the same moment, idle and under a 4-process CPU load. The paired
/// evidence is in docs/intel-port/mfc-crosscheck/; the line numbers below
/// refer to idle-dump.txt and load-dump.txt there.
///
/// Keys that tracked the load but could not be matched to a single named
/// sensor (TC0E, TCXC, TCSA, TCHP) are left out on purpose: an unmapped
/// sensor shows nothing, a wrong one shows a wrong number.
enum IntelSMCSensorMap {
    /// "CPU die temperature" of `powermetrics --samplers smc`, read in the same
    /// second as the SMC: TC0F idle 70.082 vs 70.08, load 100.695 vs 100.70
    /// (docs/intel-port/mfc-crosscheck/powermetrics.txt). It is the number macOS
    /// itself reports, so it leads the display; the cores read 6 degrees lower
    /// at idle and 3 lower under load.
    static let cpuDieKeys: Set<String> = ["TC0F"]

    /// "CPU Core 1" and "CPU Core 2" in Macs Fan Control: TC1C idle 74.0 /
    /// load 103.0 (lines 54), TC2C idle 73.0 / load 102.0 (lines 55). The
    /// i5-5350U has two cores, one key each.
    static let cpuCoreKeys: Set<String> = ["TC1C", "TC2C"]

    /// "CPU PECI" in Macs Fan Control: TCMX idle 74.7 / load 103.0 (lines 58).
    /// TCXC is not listed: under load it read 102.875 against the 103.0 shown.
    static let cpuPackageKeys: Set<String> = ["TCMX"]

    /// "GPU Intel HD Graphics 6000" in Macs Fan Control: TCGC idle 74.0 / load
    /// 95.0 (lines 56). TCSA read 95.0 under load too, but 72.0 at idle against
    /// the 74.0 shown, so only TCGC matches in both states.
    static let gpuKeys: Set<String> = ["TCGC"]

    /// The keys read on every tick: the ones that decide the displayed value.
    static let preferredKeys: Set<String> = cpuDieKeys.union(cpuCoreKeys)

    static func isCPUKey(_ key: String) -> Bool {
        preferredKeys.contains(key) || cpuPackageKeys.contains(key)
    }

    /// The die temperature when it answers, otherwise the hottest core,
    /// otherwise the package reading, otherwise nothing. Never a reading from
    /// a key outside this map.
    static func displayedCPUTemperature(_ readings: [(key: String, value: Double)]) -> Double? {
        if let die = readings.filter({ cpuDieKeys.contains($0.key) }).map(\.value).max() {
            return die
        }
        let cores = readings.filter { cpuCoreKeys.contains($0.key) }.map(\.value)
        if let hottest = cores.max() { return hottest }
        return readings.filter { cpuPackageKeys.contains($0.key) }.map(\.value).max()
    }
}
