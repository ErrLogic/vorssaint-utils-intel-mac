// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

// Read-only SMC diagnostic: prints every key whose name starts with T, F or P
// with its type, size, raw bytes and decoded value. It never writes to the SMC.
//
// Build and run with Tools/smc-dump.sh, which compiles this file together with
// the app's SMCClient and SMCValueCodec for the host architecture.

import Foundation

@main
struct SMCDump {
    static let prefixes: Set<Character> = ["T", "F", "P"]

    static func main() {
        guard let client = SMCClient() else {
            FileHandle.standardError.write(Data("✗ cannot open AppleSMC\n".utf8))
            exit(1)
        }

        let keys = client.keys { name in
            guard let first = name.first else { return false }
            return prefixes.contains(first)
        }.sorted { $0.name < $1.name }

        print("# SMC dump \(ISO8601DateFormatter().string(from: Date()))")
        print("# keys: \(keys.count)")
        print(pad("name", 6) + pad("type", 6) + pad("size", 6) + pad("raw", 20) + "value")

        for key in keys {
            let bytes = client.readBytes(key)
            let raw = bytes.map { $0.map { String(format: "%02x", $0) }.joined() } ?? "-"
            let value = client.readValue(key).map { String(format: "%.3f", $0) } ?? "-"
            print(pad(key.name, 6) + pad(key.dataType, 6) + pad(String(key.dataSize), 6)
                  + pad(raw, 20) + value)
        }
    }

    static func pad(_ text: String, _ width: Int) -> String {
        text.count >= width ? text + " " : text + String(repeating: " ", count: width - text.count)
    }
}
