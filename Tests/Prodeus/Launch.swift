// SPDX-License-Identifier: GPL-3.0-only
// One explicitly authorized original-game start; ProfileCheck also inspects unregistered native PIDs.
import AppKit
import Foundation
guard CommandLine.arguments.count == 4 else { exit(2) }
let game=URL(fileURLWithPath:CommandLine.arguments[1]).standardizedFileURL
let runtime=URL(fileURLWithPath:CommandLine.arguments[2]).standardizedFileURL
let configuration=URL(fileURLWithPath:CommandLine.arguments[3]).standardizedFileURL
let root=URL(fileURLWithPath:"/private/tmp/trainerdock-prodeus",isDirectory:true)
guard !NSWorkspace.shared.runningApplications.contains(where:{$0.bundleIdentifier=="com.BoundingBoxSoftware.Prodeus" || $0.bundleURL?.standardizedFileURL==game}) else {
 fputs("Prodeus läuft bereits; kein zweiter Start.\n",stderr);exit(3)
}
let check=Process();check.executableURL=runtime.deletingLastPathComponent().appendingPathComponent("ProfileCheck")
check.arguments=[game.path,configuration.path,"--require-not-running"]
try check.run();check.waitUntilExit();guard check.terminationStatus==0 else{exit(1)}
try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true,attributes:[.posixPermissions:0o700])
try FileManager.default.setAttributes([.posixPermissions:0o700],ofItemAtPath:root.path)
let token=UUID().uuidString
let settings=NSWorkspace.OpenConfiguration();settings.createsNewApplicationInstance=false;settings.activates=true
settings.environment=["DYLD_INSERT_LIBRARIES":runtime.path,"MHT_CONFIG":configuration.path,
 "MHT_PROFILE":"steam-arm64-1.0.2","MHT_MODULE":"prodeus","MHT_SESSION":token,
 "MHT_TARGET":game.appendingPathComponent("Contents/MacOS/Prodeus").path,"MHT_PRODEUS_DEVELOPMENT":"1",
 "SteamAppId":"964800","SteamGameId":"964800","MHT_SELECTION":"{}",
 "MHT_OPTIONS":"{\"visible\":false,\"glassIntensity\":0.5}"]
NSWorkspace.shared.openApplication(at:game,configuration:settings){application,error in
 guard error==nil,let application=application else{fputs("Spielstart fehlgeschlagen: \(error?.localizedDescription ?? "Kein Prozess")\n",stderr);exit(1)}
 do{
  let path=root.appendingPathComponent("Session.json")
  try JSONSerialization.data(withJSONObject:["pid":application.processIdentifier,"token":token]).write(to:path,options:.atomic)
  try FileManager.default.setAttributes([.posixPermissions:0o600],ofItemAtPath:path.path)
 }catch{fputs("Sitzungsgebundene Prüfkoordination fehlgeschlagen.\n",stderr);exit(1)}
 print("Genau eine Prodeus-Prüfinstanz gestartet, PID \(application.processIdentifier).");exit(0)
}
RunLoop.main.run()
