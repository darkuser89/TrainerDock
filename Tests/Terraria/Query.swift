// SPDX-License-Identifier: GPL-3.0-only
import Foundation
let root=URL(fileURLWithPath:"/private/tmp/trainerdock-terraria")
guard CommandLine.arguments.count==2 else {exit(2)}
let session=try JSONSerialization.jsonObject(with:Data(contentsOf:root.appendingPathComponent("Session.json"))) as! [String:Any]
let id=UUID().uuidString
let raw=CommandLine.arguments[1]
var action:Any = raw
if raw.first=="{" {action=try JSONSerialization.jsonObject(with:Data(raw.utf8))}
let request:[String:Any] = ["token":session["token"]!,"id":id,"action":action]
let path=root.appendingPathComponent("Request.json")
try JSONSerialization.data(withJSONObject:request).write(to:path,options:.atomic)
try FileManager.default.setAttributes([.posixPermissions:0o600],ofItemAtPath:path.path)
let start=Date()
while Date().timeIntervalSince(start)<20 {
 if let data=try? Data(contentsOf:root.appendingPathComponent("CandidateReply.json")),let reply=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any],reply["id"] as? String==id {
  print(String(data:data,encoding:.utf8)!);exit(0)
 }
 RunLoop.main.run(until:Date().addingTimeInterval(0.1))
}
fputs("No fresh scoped candidate reply.\n",stderr);exit(1)
