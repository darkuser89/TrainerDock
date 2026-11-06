// SPDX-License-Identifier: GPL-3.0-only
import Foundation
let root=URL(fileURLWithPath:"/private/tmp/mht-no-mans-sky")
let session=try JSONSerialization.jsonObject(with:Data(contentsOf:root.appendingPathComponent("Session.json"))) as! [String:Any]
var message=session
message["action"]=CommandLine.arguments.count>1 ? CommandLine.arguments[1] : "status"
let data=try JSONSerialization.data(withJSONObject:message)
DistributedNotificationCenter.default().postNotificationName(NSNotification.Name("local.mht.nms.development"),object:String(data:data,encoding:.utf8)!,userInfo:nil,deliverImmediately:true)
