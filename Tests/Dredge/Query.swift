// SPDX-License-Identifier: GPL-3.0-only
// Candidate observation or explicitly requested own-item probe, session-bound.
import Foundation
let action=CommandLine.arguments.count>1 ? CommandLine.arguments[1] : "observe"
guard ["observe","equipment-setup","equipment-check","equipment-reset"].contains(action),CommandLine.arguments.count<=2 else {
 fputs("Erlaubt: observe, equipment-setup, equipment-check, equipment-reset.\n",stderr);exit(2)
}
let root=URL(fileURLWithPath:"/private/tmp/trainerdock-dredge")
let session=try JSONSerialization.jsonObject(with:Data(contentsOf:root.appendingPathComponent("Session.json"))) as! [String:Any]
let id=UUID().uuidString
var request:[String:Any]=["token":session["token"]!,"id":id,"pid":session["pid"]!,"action":action]
if action=="equipment-setup" {request["ownEquipmentOnly"]=true}
let path=root.appendingPathComponent("Request.json")
try JSONSerialization.data(withJSONObject:request).write(to:path,options:.atomic)
try FileManager.default.setAttributes([.posixPermissions:0o600],ofItemAtPath:path.path)
let deadline=Date().addingTimeInterval(20)
while Date()<deadline {
 if let data=try? Data(contentsOf:root.appendingPathComponent("CandidateReply.json")),let reply=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any],reply["id"] as? String==id {
  print(String(data:data,encoding:.utf8)!);exit(0)
 }
 RunLoop.main.run(until:Date().addingTimeInterval(0.05))
}
fputs("Keine aktuelle Rückmeldung aus dem Originalrückruf.\n",stderr);exit(1)
