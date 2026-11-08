// SPDX-License-Identifier: GPL-3.0-only
import Foundation
guard CommandLine.arguments.count==3 else{exit(2)}
let session=try JSONSerialization.jsonObject(with:Data(contentsOf:URL(fileURLWithPath:CommandLine.arguments[1]))) as! [String:Any]
let id=UUID().uuidString,action=CommandLine.arguments[2],center=DistributedNotificationCenter.default()
var done=false
let observer=center.addObserver(forName:Notification.Name("local.trainerdock.kex.reply"),object:nil,queue:.main){event in
 guard let text=event.object as? String,let data=text.data(using:.utf8),let message=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any],message["id"] as? String==id,message["token"] as? String==session["token"] as? String else{return}
 print(text);done=true
}
let request:[String:Any] = ["token":session["token"]!,"pid":session["pid"]!,"id":id,"action":action,"deadline":Date().timeIntervalSince1970+5]
let data=try JSONSerialization.data(withJSONObject:request)
center.postNotificationName(Notification.Name("local.trainerdock.kex.test"),object:String(data:data,encoding:.utf8)!,userInfo:nil,deliverImmediately:true)
let end=Date().addingTimeInterval(6)
while !done && Date()<end{RunLoop.main.run(until:Date().addingTimeInterval(0.05))}
center.removeObserver(observer);if !done{fputs("Keine frische native Antwort.\n",stderr);exit(1)}
