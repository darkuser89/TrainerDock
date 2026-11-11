// SPDX-License-Identifier: GPL-3.0-only
import Foundation
let root=URL(fileURLWithPath:"/private/tmp/mht-no-mans-sky")
let session=try JSONSerialization.jsonObject(with:Data(contentsOf:root.appendingPathComponent("Session.json"))) as! [String:Any]
var message=session
let request=UUID().uuidString
message["request"]=request
message["deadline"]=Date().timeIntervalSince1970+3
message["action"]=CommandLine.arguments.count>1 ? CommandLine.arguments[1] : "status"
let data=try JSONSerialization.data(withJSONObject:message)
DistributedNotificationCenter.default().postNotificationName(NSNotification.Name("local.mht.nms.development"),object:String(data:data,encoding:.utf8)!,userInfo:nil,deliverImmediately:true)
let start=Date()
while Date().timeIntervalSince(start)<5 {
    if let data=try? Data(contentsOf:root.appendingPathComponent("Result.json")),
       let result=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any],
       result["request"] as? String==request,result["pid"] as? Int==session["pid"] as? Int {
        print(String(data:data,encoding:.utf8)!);exit(result["error"] == nil ? 0:1)
    }
    RunLoop.main.run(until:Date().addingTimeInterval(0.05))
}
fputs("Keine aktuelle sitzungsgebundene Prüfantwort.\n",stderr);exit(1)
