// SPDX-License-Identifier: GPL-3.0-only
import AppKit
import Foundation
// The caller supplies an already inspected original, exact candidate and private session.
guard CommandLine.arguments.count == 5 else { exit(2) }
let game=URL(fileURLWithPath:CommandLine.arguments[1])
let folder=URL(fileURLWithPath:CommandLine.arguments[2])
let module=CommandLine.arguments[3],identifier=CommandLine.arguments[4]
guard !NSWorkspace.shared.runningApplications.contains(where:{$0.bundleIdentifier==identifier}) else {fputs("Spiel läuft bereits; kein Doppelstart.\n",stderr);exit(2)}
let config=try JSONSerialization.jsonObject(with:Data(contentsOf:folder.appendingPathComponent("TrainerConfig.json"))) as! [String:Any]
let profile=(config["profiles"] as! [[String:Any]])[0],token=UUID().uuidString
let options=NSWorkspace.OpenConfiguration();options.activates=true;options.createsNewApplicationInstance=false
options.environment=["DYLD_INSERT_LIBRARIES":folder.appendingPathComponent("Trainer.dylib").path+":"+folder.deletingLastPathComponent().appendingPathComponent("Probe.dylib").path,"MHT_MODULE":module,"MHT_SESSION":token,"MHT_TARGET":game.appendingPathComponent("Contents/MacOS/"+(profile["executable"] as! String)).path,"MHT_PROFILE":profile["id"] as! String,"MHT_CONFIG":folder.appendingPathComponent("TrainerConfig.json").path,"MHT_OPTIONS":"{\"liquidGlass\":true}","MHT_SELECTION":"{}","SteamAppId":profile["steamAppId"] as! String,"SteamGameId":profile["steamAppId"] as! String]
NSWorkspace.shared.openApplication(at:game,configuration:options){app,error in
 if let error=error{fputs("Start fehlgeschlagen: \(error.localizedDescription)\n",stderr);exit(1)}
 let session:[String:Any] = ["module":module,"token":token,"pid":Int(app?.processIdentifier ?? 0)]
 do{try JSONSerialization.data(withJSONObject:session).write(to:folder.appendingPathComponent("Session.json"),options:.atomic)}catch{fputs("Sitzung nicht gespeichert.\n",stderr);exit(1)}
 print("Genau eine Testinstanz gestartet, PID \(app?.processIdentifier ?? 0).");exit(0)
}
RunLoop.main.run()
