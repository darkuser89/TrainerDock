// SPDX-License-Identifier: GPL-3.0-only
// Run only with the user's explicit game-start authorization.
import AppKit
import Foundation
guard CommandLine.arguments.count == 2 else { exit(2) }
let game=URL(fileURLWithPath:CommandLine.arguments[1]).standardizedFileURL
let root=FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Developer/TrainerDock/Tests/Frostpunk",isDirectory:true)
let runtime=root.appendingPathComponent("Trainer.dylib")
let probe=root.appendingPathComponent("IngameProbe.dylib")
let configuration=root.appendingPathComponent("TrainerConfig.json")
guard !NSWorkspace.shared.runningApplications.contains(where:{$0.bundleIdentifier=="com.11bitstudios.frostpunk" || $0.bundleURL?.standardizedFileURL==game}) else {
    fputs("Frostpunk läuft bereits; kein zweiter Start.\n",stderr);exit(3)
}
guard FileManager.default.fileExists(atPath:probe.path) else {
    fputs("Sitzungsgebundener Nur-Lese-Prüfer fehlt.\n",stderr);exit(2)
}
let check=Process();check.executableURL=root.appendingPathComponent("ProfileCheck")
check.arguments=[game.path,configuration.path,"--require-not-running"]
try check.run();check.waitUntilExit();guard check.terminationStatus==0 else{exit(1)}
let token=UUID().uuidString
let settings=NSWorkspace.OpenConfiguration();settings.createsNewApplicationInstance=false;settings.activates=true
settings.environment=["DYLD_INSERT_LIBRARIES":runtime.path+":"+probe.path,"MHT_CONFIG":configuration.path,
    "MHT_PROFILE":"steam-x86_64-15262773","MHT_MODULE":"frostpunk","MHT_SESSION":token,"MHT_FROSTPUNK_PROBE":"1",
    "MHT_TARGET":game.appendingPathComponent("Contents/MacOS/Frostpunk").path,
    "SteamAppId":"323190","SteamGameId":"323190","MHT_SELECTION":"{}",
    "MHT_OPTIONS":"{\"visible\":false,\"glassIntensity\":0.5}"]
NSWorkspace.shared.openApplication(at:game,configuration:settings){application,error in
    guard error==nil,let application=application else{
        fputs("Spielstart fehlgeschlagen: \(error?.localizedDescription ?? "Kein Prozess")\n",stderr);exit(1)
    }
    do{
        let session=root.appendingPathComponent("Session.json")
        try JSONSerialization.data(withJSONObject:["pid":application.processIdentifier,"token":token]).write(to:session,options:.atomic)
        try FileManager.default.setAttributes([.posixPermissions:0o600],ofItemAtPath:session.path)
    }catch{fputs("Sitzungsgebundene Prüfkoordination fehlgeschlagen.\n",stderr);exit(1)}
    print("Genau eine Frostpunk-Prüfinstanz gestartet, PID \(application.processIdentifier).");exit(0)
}
RunLoop.main.run()
