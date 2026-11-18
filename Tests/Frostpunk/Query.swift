// SPDX-License-Identifier: GPL-3.0-only
// Snapshot probe is read-only. Other commands use the existing production protocol.
import Foundation

func fail(_ text: String, _ status: Int32 = 1) -> Never {
    fputs(text + "\n", stderr)
    exit(status)
}
var arguments = Array(CommandLine.arguments.dropFirst())
var sessionURL = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("Library/Developer/TrainerDock/Tests/Frostpunk/Session.json")
if arguments.first == "--session-file" {
    guard arguments.count >= 2 else { fail("--session-file benötigt einen Dateipfad.", 2) }
    sessionURL = URL(fileURLWithPath: arguments[1])
    arguments.removeFirst(2)
}
var commands = arguments
if commands.isEmpty { commands = ["snapshot"] }
guard let data = try? Data(contentsOf: sessionURL), data.count <= 4096,
      let coordination = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
      let session = (coordination["token"] ?? coordination["session"]) as? String,
      (16...256).contains(session.count), let number = coordination["pid"] as? NSNumber,
      number.doubleValue.isFinite, number.doubleValue.rounded() == number.doubleValue,
      number.doubleValue > 0, number.doubleValue <= Double(Int32.max) else {
    fail("Keine gültige sitzungsgebundene Session.json.", 2)
}
let pid = number.intValue
var index = 0
var latest: [String: Any]?
var requestID: String?
var received: Date?
var replyError: String?
var serial = 0
var ackSerial = 0
var failed = false
var deadline = Date().addingTimeInterval(6)
func output(_ state: [String: Any], _ error: String? = nil) {
    failed = failed || error != nil
    let value: [String: Any] = ["command": commands[index], "state": state, "error": error ?? ""]
    if let data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]),
       let text = String(data: data, encoding: .utf8) { print(text) }
    index += 1
    requestID = nil
    received = nil
    replyError = nil
    deadline = Date().addingTimeInterval(6)
    if index == commands.count { exit(failed ? 1 : 0) }
}
func observed(_ state: [String: Any]) -> Bool {
    let parts = commands[index].split(separator: ":").map(String.init)
    let rows = state["features"] as? [[String: Any]] ?? []
    if parts[0] == "disableAll" { return rows.count == 15 && rows.allSatisfy { !($0["wanted"] as? Bool ?? true) } }
    if ["set", "toggle"].contains(parts[0]), parts.count == 3,
       let feature = Int(parts[1]), feature < rows.count {
        return rows[feature]["wanted"] as? Bool == (parts[2] == "1")
    }
    if parts[0] == "value", parts.count == 3, let feature = Int(parts[1]), feature < rows.count,
       let expected = Double(parts[2]), let actual = rows[feature]["value"] as? Double {
        return abs(actual - expected) < 0.000001
    }
    if parts[0] == "overlay", parts.count == 2 {
        return (state["overlay"] as? [String: Any])?["visible"] as? Bool == (parts[1] == "1")
    }
    return true
}
let stateObserver = DistributedNotificationCenter.default().addObserver(
    forName: NSNotification.Name("local.mht.state.v1"), object: nil, queue: .main
) { event in
    guard let raw = event.object as? String, let data = raw.data(using: .utf8), data.count <= 65536,
          let message = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
          message["module"] as? String == "frostpunk", message["session"] as? String == session,
          let process = message["pid"] as? NSNumber, process.doubleValue == Double(pid),
          let state = message["state"] as? [String: Any] else { return }
    latest = state
    serial += 1
    if let current = requestID, message["request"] as? String == current {
        received = Date()
        ackSerial = serial
        let error = message["error"] as? String
        replyError = error?.isEmpty == false ? error : nil
    }
}
let probeObserver = DistributedNotificationCenter.default().addObserver(
    forName: NSNotification.Name("local.trainerdock.frostpunk.probe.response"), object: nil, queue: .main
) { event in
    guard let raw = event.object as? String, let data = raw.data(using: .utf8), data.count <= 65536,
          let response = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
          response["module"] as? String == "frostpunk", response["session"] as? String == session,
          let process = response["pid"] as? NSNumber, process.doubleValue == Double(pid),
          let current = requestID, response["requestID"] as? String == current,
          commands[index] == "snapshot", response["steamBuild"] as? String == "15262773",
          response["uuid"] as? String == "381A9DB7-5849-39B1-85BC-208861544E41" else { return }
    // Do not print the local binding token or any launch environment.
    var values = response
    values.removeValue(forKey: "session")
    let error = response["error"] as? String
    output(values, error?.isEmpty == false ? error : nil)
}
let timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
    guard Date() < deadline else { fail("Keine bestätigte aktuelle Frostpunk-Antwort.") }
    if requestID == nil, commands[index] == "snapshot" {
        let identifier = UUID().uuidString
        requestID = identifier
        let message: [String: Any] = ["session": session, "pid": pid, "requestID": identifier,
            "deadline": Date().timeIntervalSince1970 + 3, "action": "snapshot"]
        guard let data = try? JSONSerialization.data(withJSONObject: message),
              let text = String(data: data, encoding: .utf8) else { fail("Leseauftrag kann nicht kodiert werden.") }
        DistributedNotificationCenter.default().postNotificationName(
            NSNotification.Name("local.trainerdock.frostpunk.probe.request"), object: text,
            userInfo: nil, deliverImmediately: true)
        return
    }
    guard let state = latest else { return }
    if let received = received {
        if let error = replyError { output(state, error); return }
        if serial > ackSerial && Date().timeIntervalSince(received) > 0.3 && observed(state) {
            output(state)
        }
        return
    }
    guard requestID == nil else { return }
    let parts = commands[index].split(separator: ":", omittingEmptySubsequences: false).map(String.init)
    let rawAction = parts[0]
    if rawAction == "state", parts.count == 1 { output(state); return }
    let action = rawAction == "toggle" ? "set" : rawAction == "feature" ? "run" : rawAction
    guard ["set", "value", "run", "disableAll", "overlay"].contains(action) else {
        fail("Unbekannter Prüfauftrag. Erlaubt: snapshot, state, set/toggle, value, run/feature, overlay, disableAll.", 2)
    }
    let identifier = UUID().uuidString
    var message: [String: Any] = ["version": 1, "module": "frostpunk", "session": session,
        "pid": pid, "request": identifier, "deadline": Date().timeIntervalSince1970 + 1,
        "context": state["context"] ?? 0, "action": action]
    if action == "overlay" {
        guard parts.count == 2, ["0", "1"].contains(parts[1]) else { fail("overlay:0 oder overlay:1 angeben.", 2) }
        guard var options = state["overlay"] as? [String: Any] else {
            fail("Kein aktueller vollständiger Overlayzustand; keine Einstellungen überschrieben.")
        }
        options["visible"] = parts[1] == "1"
        message["options"] = options
    } else if action == "disableAll" {
        guard parts.count == 1 else { fail("disableAll erwartet keine weiteren Argumente.", 2) }
    } else {
        guard parts.count >= 2, let feature = Int(parts[1]), (0..<15).contains(feature) else {
            fail("Funktions-ID muss zwischen 0 und 14 liegen.", 2)
        }
        message["feature"] = feature
        if action == "set" {
            guard parts.count == 3, ["0", "1"].contains(parts[2]) else { fail("set:<id>:0 oder set:<id>:1 angeben.", 2) }
            message["wanted"] = parts[2] == "1"
        } else if action == "value" {
            guard parts.count == 3, let value = Double(parts[2]), value.isFinite else { fail("Endlichen Zahlenwert angeben.", 2) }
            message["value"] = value
        } else {
            guard parts.count == 2 else { fail("run:<id> angeben.", 2) }
        }
    }
    guard let data = try? JSONSerialization.data(withJSONObject: message),
          let text = String(data: data, encoding: .utf8) else { fail("Produktauftrag kann nicht kodiert werden.") }
    requestID = identifier
    DistributedNotificationCenter.default().postNotificationName(
        NSNotification.Name("local.mht.command.v1"), object: text, userInfo: nil, deliverImmediately: true)
}
RunLoop.main.run()
