// SPDX-License-Identifier: GPL-3.0-only
// Explicit guarded compatibility launch. Does not replace signatures or game files.
import AppKit
import Foundation
guard CommandLine.arguments.count == 2 else { exit(2) }
let root = URL(fileURLWithPath: CommandLine.arguments[1])
let configURL = root.appendingPathComponent("Launch.json")
guard let data = try? Data(contentsOf: configURL),
      let config = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
      let path = config["app"] as? String,
      let environment = config["environment"] as? [String: String] else { exit(2) }
let existing = NSWorkspace.shared.runningApplications.filter { ["com.remedygames.control-ue-steam", "com.remedygames.control-ue"].contains($0.bundleIdentifier ?? "") }
guard existing.isEmpty else { fputs("A Control instance is already running; no launch performed.\n", stderr); exit(2) }
let settings = NSWorkspace.OpenConfiguration()
settings.createsNewApplicationInstance = false
settings.activates = true
settings.environment = environment
NSWorkspace.shared.openApplication(at: URL(fileURLWithPath:path), configuration:settings) { app,error in
    if let error = error { fputs("Launch failed: \(error.localizedDescription)\n",stderr);exit(1) }
    print("Single store compatibility instance pid=\(app?.processIdentifier ?? 0)");exit(0)
}
RunLoop.main.run()
