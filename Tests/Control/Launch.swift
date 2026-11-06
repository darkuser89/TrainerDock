// SPDX-License-Identifier: GPL-3.0-only
import AppKit
import Foundation
guard CommandLine.arguments.count == 3 else { exit(2) }
let game = URL(fileURLWithPath: CommandLine.arguments[1])
let identifier = "com.remedygames.control-ue-steam"
guard !NSWorkspace.shared.runningApplications.contains(where: { $0.bundleIdentifier == identifier }) else {
    fputs("Control already running; no launch performed.\n", stderr); exit(2)
}
let settings = NSWorkspace.OpenConfiguration()
settings.createsNewApplicationInstance = false
settings.activates = true
settings.environment = ["DYLD_INSERT_LIBRARIES":CommandLine.arguments[2],"MHT_CONTROL_PROBE":"1", "MHT_CONTROL_DIRECT":"1", "SteamAppId":"870780","SteamGameId":"870780"]
NSWorkspace.shared.openApplication(at:game,configuration:settings) { app,error in
 if let error = error { fputs("Launch failed: \(error.localizedDescription)\n",stderr);exit(1) }
 print("Single Control probe instance pid=\(app?.processIdentifier ?? 0)");exit(0)
}
RunLoop.main.run()
