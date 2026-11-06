// SPDX-License-Identifier: GPL-3.0-only
import AppKit
import Foundation
guard CommandLine.arguments.count == 4 else { exit(2) }
let game = URL(fileURLWithPath: CommandLine.arguments[1])
let identifier = "uk.co.hellogames.nms"
guard !NSWorkspace.shared.runningApplications.contains(where: { $0.bundleIdentifier == identifier }) else {
    fputs("No Man’s Sky already running; no launch performed.\n", stderr); exit(2)
}
let settings = NSWorkspace.OpenConfiguration()
let token = UUID().uuidString
settings.createsNewApplicationInstance = false
settings.activates = true
settings.environment = ["DYLD_INSERT_LIBRARIES": CommandLine.arguments[2], "MHT_NMS_DEVELOPMENT":"1",
    "MHT_CONFIG":CommandLine.arguments[3],"MHT_PROFILE":"steam-arm64", "MHT_MODULE":"no-mans-sky",
    "MHT_SESSION":token,"MHT_TARGET":game.appendingPathComponent("Contents/MacOS/No Man's Sky").path,
    "SteamAppId":"275850","SteamGameId":"275850","MHT_OPTIONS":"{\"visible\":false,\"liquidGlass\":true}"]
NSWorkspace.shared.openApplication(at: game, configuration: settings) { app, error in
    if let error = error { fputs("Launch failed: \(error.localizedDescription)\n", stderr); exit(1) }
    do {
        let root=URL(fileURLWithPath:"/private/tmp/mht-no-mans-sky",isDirectory:true)
        try FileManager.default.setAttributes([.posixPermissions:0o700],ofItemAtPath:root.path)
        try JSONSerialization.data(withJSONObject:["pid":app?.processIdentifier ?? 0,"token":token]).write(to:root.appendingPathComponent("Session.json"),options:.atomic)
    } catch { fputs("Development coordination failed.\n", stderr); exit(1) }
    print("Single No Man’s Sky test instance pid=\(app?.processIdentifier ?? 0)"); exit(0)
}
RunLoop.main.run()
