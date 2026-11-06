// SPDX-License-Identifier: GPL-3.0-only
// Explicit single-instance development launch, with the unchanged product runtime.
import AppKit
import Foundation
guard CommandLine.arguments.count == 2 else { exit(2) }
let root = URL(fileURLWithPath: CommandLine.arguments[1])
let game = URL(fileURLWithPath: "/Volumes/Mac Games/SteamLibrary/steamapps/common/Control/Game.app")
guard !NSWorkspace.shared.runningApplications.contains(where: { $0.bundleIdentifier == "com.remedygames.control-ue-steam" }) else {
    fputs("Control is already running; no second instance started.\n", stderr); exit(2)
}
let module = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Developer/TrainerDock/Modules/control.mhtmodule")
let settings = NSWorkspace.OpenConfiguration()
settings.createsNewApplicationInstance = false
settings.activates = true
settings.environment = ["DYLD_INSERT_LIBRARIES":module.appendingPathComponent("Trainer.dylib").path + ":" + root.appendingPathComponent("MaterialProbe.dylib").path,
    "MHT_MODULE":"control", "MHT_CONFIG":module.appendingPathComponent("TrainerConfig.json").path,
    "MHT_PROFILE":"control-steam-arm64", "MHT_TARGET":"Game", "SteamAppId":"870780", "SteamGameId":"870780"]
NSWorkspace.shared.openApplication(at:game,configuration:settings) { app,error in
    if let error = error { fputs("Launch failed: \(error.localizedDescription)\n", stderr); exit(1) }
    print("Single material check pid=\(app?.processIdentifier ?? 0)");exit(0)
}
RunLoop.main.run()
