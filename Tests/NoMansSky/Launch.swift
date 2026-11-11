// SPDX-License-Identifier: GPL-3.0-only
import AppKit
import Foundation
guard CommandLine.arguments.count == 5 else { exit(2) }
let game = URL(fileURLWithPath: CommandLine.arguments[1])
let library = URL(fileURLWithPath: CommandLine.arguments[2])
let profile = CommandLine.arguments[4]
let identifier = "uk.co.hellogames.nms"
guard !NSWorkspace.shared.runningApplications.contains(where: { $0.bundleIdentifier == identifier }) else {
    fputs("No Man’s Sky already running; no launch performed.\n", stderr); exit(2)
}
let check = Process()
check.executableURL = library.deletingLastPathComponent().appendingPathComponent("ProfileCheck")
check.arguments = [game.path, CommandLine.arguments[3], profile, "--require-not-running"]
try check.run(); check.waitUntilExit()
guard check.terminationStatus == 0 else { exit(1) }
let root=URL(fileURLWithPath:"/private/tmp/mht-no-mans-sky",isDirectory:true)
try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true,attributes:[.posixPermissions:0o700])
try FileManager.default.setAttributes([.posixPermissions:0o700],ofItemAtPath:root.path)
let settings = NSWorkspace.OpenConfiguration()
let token = UUID().uuidString
settings.createsNewApplicationInstance = false
settings.activates = true
settings.environment = ["DYLD_INSERT_LIBRARIES": CommandLine.arguments[2], "MHT_NMS_DEVELOPMENT":"1",
    "MHT_CONFIG":CommandLine.arguments[3],"MHT_PROFILE":profile, "MHT_MODULE":"no-mans-sky",
    "MHT_SESSION":token,"MHT_TARGET":game.appendingPathComponent("Contents/MacOS/No Man's Sky").path,
    "SteamAppId":"275850","SteamGameId":"275850","MHT_SELECTION":"{}","MHT_OPTIONS":"{\"visible\":false,\"glassIntensity\":0.5}"]
NSWorkspace.shared.openApplication(at: game, configuration: settings) { app, error in
    if let error = error { fputs("Launch failed: \(error.localizedDescription)\n", stderr); exit(1) }
    do {
        try JSONSerialization.data(withJSONObject:["pid":app?.processIdentifier ?? 0,"token":token]).write(to:root.appendingPathComponent("Session.json"),options:.atomic)
        try FileManager.default.setAttributes([.posixPermissions:0o600],ofItemAtPath:root.appendingPathComponent("Session.json").path)
    } catch { fputs("Development coordination failed.\n", stderr); exit(1) }
    print("Single No Man’s Sky test instance pid=\(app?.processIdentifier ?? 0)"); exit(0)
}
RunLoop.main.run()
