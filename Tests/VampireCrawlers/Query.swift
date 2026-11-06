// SPDX-License-Identifier: GPL-3.0-only
import Foundation
guard CommandLine.arguments.count == 2 else { exit(2) }
let session=try JSONSerialization.jsonObject(with:Data(contentsOf:URL(fileURLWithPath:"/private/tmp/mht-vampire-crawlers/Session.json"))) as! [String:Any]
let raw=CommandLine.arguments[1]
let candidate=raw.hasPrefix("candidate:")
let action=candidate ? String(raw.dropFirst(10)) : raw
let message=try JSONSerialization.data(withJSONObject:["action":action,"token":session["token"] as! String])
DistributedNotificationCenter.default().postNotificationName(NSNotification.Name(candidate ? "local.mht.vampire-crawlers.candidate" : "local.mht.vampire-crawlers.development"),object:String(data:message,encoding:.utf8)!,userInfo:nil,deliverImmediately:true)
