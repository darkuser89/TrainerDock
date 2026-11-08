// SPDX-License-Identifier: GPL-3.0-only
import AppKit
let root="/private/tmp/trainerdock-the-long-dark"
let game=URL(fileURLWithPath:"/Volumes/Mac Games/SteamLibrary/steamapps/common/TheLongDark/tld.app")
guard !NSWorkspace.shared.runningApplications.contains(where:{$0.bundleIdentifier=="com.Hinterland.The-Long-Dark"}) else {fputs("Already running; no second start.\n",stderr);exit(2)}
let token=UUID().uuidString
let config=NSWorkspace.OpenConfiguration()
config.createsNewApplicationInstance=false
config.activates=true
config.environment=["DYLD_INSERT_LIBRARIES":root+"/Trainer.dylib","MHT_TLD_DEVELOPMENT":"1","MHT_SESSION":token,"MHT_CONFIG":root+"/ProbeConfig.json","MHT_PROFILE":"steam-arm64-2.60","MHT_MODULE":"the-long-dark","MHT_TARGET":game.appendingPathComponent("Contents/MacOS/tld").path,"SteamAppId":"305620","SteamGameId":"305620","MHT_OPTIONS":"{\"visible\":false}"]
NSWorkspace.shared.openApplication(at:game,configuration:config){app,error in
 if let error=error {fputs(error.localizedDescription+"\n",stderr);exit(1)}
 do{try JSONSerialization.data(withJSONObject:["pid":app?.processIdentifier ?? 0,"token":token]).write(to:URL(fileURLWithPath:root+"/Session.json"),options:.atomic)}catch{exit(1)}
 print("Single TLD test instance pid=\(app?.processIdentifier ?? 0)");exit(0)
}
RunLoop.main.run()
