// SPDX-License-Identifier: GPL-3.0-only
// One explicitly authorized original-app launch with a private read-only probe.
import AppKit
let root=URL(fileURLWithPath:"/private/tmp/trainerdock-frostpunk2")
let game=URL(fileURLWithPath:"/Volumes/Mac Games/SteamLibrary/steamapps/common/Frostpunk2/Frostpunk2.app")
guard !NSWorkspace.shared.runningApplications.contains(where:{$0.bundleIdentifier=="com.11bitstudios.frostpunk2"}) else {fputs("Already running; no duplicate start.\n",stderr);exit(2)}
let check=Process();check.executableURL=root.appendingPathComponent("ProfileCheck");check.arguments=["--require-not-running"];try check.run();check.waitUntilExit();guard check.terminationStatus==0 else {exit(1)}
let token=UUID().uuidString
let full=CommandLine.arguments.contains("--trainer")
let configuration=NSWorkspace.OpenConfiguration();configuration.createsNewApplicationInstance=false
configuration.environment=["DYLD_INSERT_LIBRARIES":root.appendingPathComponent(full ? "Trainer.dylib" : "Probe.dylib").path,"MHT_FROSTPUNK_DEVELOPMENT":"1","MHT_SESSION":token,"SteamAppId":"1601580","SteamGameId":"1601580"]
if full {configuration.environment.merge(["MHT_MODULE":"frostpunk-2","MHT_CONFIG":root.appendingPathComponent("ProbeConfig.json").path,"MHT_PROFILE":"steam-arm64-24037022","MHT_TARGET":game.appendingPathComponent("Contents/MacOS/Frostpunk2").path,"MHT_OPTIONS":"{\"visible\":false}"]){_,new in new}}
NSWorkspace.shared.openApplication(at:game,configuration:configuration){app,error in
 guard let app=app else {fputs("Original app launch failed: \(error?.localizedDescription ?? "unknown")\n",stderr);exit(1)}
 do{let file=root.appendingPathComponent("Session.json");try JSONSerialization.data(withJSONObject:["pid":app.processIdentifier,"token":token]).write(to:file,options:.atomic);try FileManager.default.setAttributes([.posixPermissions:0o600],ofItemAtPath:file.path);print("Single Frostpunk 2 probe instance pid=\(app.processIdentifier)");exit(0)}catch{fputs("Session coordination failed.\n",stderr);exit(1)}
}
RunLoop.main.run()
