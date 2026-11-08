// SPDX-License-Identifier: GPL-3.0-only
import AppKit
let root=URL(fileURLWithPath:NSHomeDirectory()+"/Library/Developer/TrainerDock/StrayTest")
let data=URL(fileURLWithPath:"/private/tmp/trainerdock-stray")
let game=URL(fileURLWithPath:"/Volumes/Mac Games/SteamLibrary/steamapps/common/Stray/Stray.app")
guard !NSWorkspace.shared.runningApplications.contains(where:{$0.bundleIdentifier=="com.annapurnainteractive.Stray"}) else {fputs("Already running; no duplicate launch.\n",stderr);exit(2)}
let check=Process();check.executableURL=root.appendingPathComponent("ProfileCheck");check.arguments=[root.appendingPathComponent("ProbeConfig.json").path,"steam-arm64-12863654",game.path];try check.run();check.waitUntilExit();guard check.terminationStatus==0 else {exit(1)}
// Include native processes not yet registered with NSWorkspace.
let processes=Process();processes.executableURL=URL(fileURLWithPath:"/usr/bin/pgrep");processes.arguments=["-f","^"+game.appendingPathComponent("Contents/MacOS/Stray-Mac-Shipping").path+"$"];let pipe=Pipe();processes.standardOutput=pipe;try processes.run();processes.waitUntilExit();guard processes.terminationStatus==1 else {fputs("Native game process already exists.\n",stderr);exit(2)}
let token=UUID().uuidString
let full=true
let configuration=NSWorkspace.OpenConfiguration();configuration.createsNewApplicationInstance=false
configuration.environment=["DYLD_INSERT_LIBRARIES":root.appendingPathComponent(full ? "Trainer.dylib" : "Probe.dylib").path,"MHT_SESSION":token,"SteamAppId":"1332010","SteamGameId":"1332010"]
if full {configuration.environment.merge(["STRAY_PRIVATE_SESSION":"1","MHT_MODULE":"stray","MHT_CONFIG":root.appendingPathComponent("ProbeConfig.json").path,"MHT_PROFILE":"steam-arm64-12863654","MHT_TARGET":game.appendingPathComponent("Contents/MacOS/Stray-Mac-Shipping").path,"MHT_OPTIONS":"{\"visible\":false}"]){_,new in new}}
NSWorkspace.shared.openApplication(at:game,configuration:configuration){app,error in
 guard let app=app else {fputs("Original launch failed: \(error?.localizedDescription ?? "unknown")\n",stderr);exit(1)}
 do{let file=data.appendingPathComponent("Session.json");try JSONSerialization.data(withJSONObject:["pid":app.processIdentifier,"token":token]).write(to:file,options:.atomic);try FileManager.default.setAttributes([.posixPermissions:0o600],ofItemAtPath:file.path);print("Single Stray candidate PID=\(app.processIdentifier)");exit(0)}catch{fputs("Session coordination failed.\n",stderr);exit(1)}
}
RunLoop.main.run()
