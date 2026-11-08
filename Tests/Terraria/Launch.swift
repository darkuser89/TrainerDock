// SPDX-License-Identifier: GPL-3.0-only
// Starts exactly one expressly authorized local candidate through the original native entry.
import AppKit
let root=URL(fileURLWithPath:"/private/tmp/trainerdock-terraria")
let game=URL(fileURLWithPath:"/Volumes/Mac Games/SteamLibrary/steamapps/common/Terraria/Terraria.app")
guard !NSWorkspace.shared.runningApplications.contains(where:{$0.bundleIdentifier=="org.Terraria"}) else {fputs("Already running. No second start.\n",stderr);exit(2)}
let check=Process();check.executableURL=root.appendingPathComponent("ProfileCheck");check.arguments=["--require-not-running"];try check.run();check.waitUntilExit();guard check.terminationStatus==0 else {exit(1)}
let token=UUID().uuidString
let p=Process();p.executableURL=game.appendingPathComponent("Contents/MacOS/Terraria.bin.osx");p.currentDirectoryURL=game.appendingPathComponent("Contents/MacOS")
var env=ProcessInfo.processInfo.environment
env.merge(["DYLD_INSERT_LIBRARIES":root.appendingPathComponent("Trainer.dylib").path,"DYLD_LIBRARY_PATH":game.appendingPathComponent("Contents/MacOS/osx").path,"MHT_TERRARIA_DEVELOPMENT":"1","MHT_SESSION":token,"MHT_MODULE":"terraria","MHT_CONFIG":root.appendingPathComponent("ProbeConfig.json").path,"MHT_PROFILE":"steam-arm64-1.4.5.8","MHT_TARGET":p.executableURL!.path,"SteamAppId":"105600","SteamGameId":"105600","MHT_OPTIONS":"{\"visible\":false}"]){_,new in new};p.environment=env
p.standardOutput=FileHandle.nullDevice;p.standardError=FileHandle.nullDevice
try p.run()
try JSONSerialization.data(withJSONObject:["pid":p.processIdentifier,"token":token]).write(to:root.appendingPathComponent("Session.json"),options:.atomic)
print("Single Terraria test instance pid=\(p.processIdentifier)")
