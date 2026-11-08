// SPDX-License-Identifier: GPL-3.0-only
// Uses the same scoped launcher protocol; does not launch games or expose tokens.
import Foundation
let coordination=try JSONSerialization.jsonObject(with:Data(contentsOf:URL(fileURLWithPath:"/private/tmp/trainerdock-terraria/Session.json"))) as! [String:Any]
let token=coordination["token"] as! String
let pid=coordination["pid"] as! Int
let parts=(CommandLine.arguments.count>1 ? CommandLine.arguments[1] : "state").split(separator:":").map(String.init)
var latest:[String:Any]?
var sent:Date?
var responseError:String?
let start=Date(),request=UUID().uuidString
let observer=DistributedNotificationCenter.default().addObserver(forName:NSNotification.Name("local.mht.state.v1"),object:nil,queue:.main){ event in
    guard let raw=event.object as? String,let data=raw.data(using:.utf8),let message=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any],
          message["module"] as? String == "terraria",message["session"] as? String == token,message["pid"] as? Int == pid else{return}
    latest=message["state"] as? [String:Any]
    if message["request"] as? String == request {responseError=message["error"] as? String}
}
let timer=Timer.scheduledTimer(withTimeInterval:0.05,repeats:true){ _ in
    if Date().timeIntervalSince(start)>20 {fputs("No current trainer reply.\n",stderr);exit(1)}
    guard let state=latest else{return}
    var reflected=true
    if parts[0]=="set",parts.count>2,let rows=state["features"] as? [[String:Any]],let id=Int(parts[1]),let row=rows.first(where:{$0["id"] as? Int==id}) {reflected=(row["wanted"] as? Bool)==(parts[2]=="1") && (parts[2] != "1" || row["active"] as? Bool==true || row["available"] as? Bool==false)}
    if parts[0]=="disableAll",let rows=state["features"] as? [[String:Any]] {reflected = !rows.contains(where:{$0["wanted"] as? Bool==true})}
    if parts[0] == "state" || (sent != nil && responseError != nil && (reflected || responseError != "") && Date().timeIntervalSince(sent!)>1.5){
        let result:[String:Any] = ["state":state,"error":responseError ?? ""]
        let data=try! JSONSerialization.data(withJSONObject:result,options:[.sortedKeys]);print(String(data:data,encoding:.utf8)!);exit(0)
    }
    if sent != nil{return}
    var message:[String:Any] = ["version":1,"module":"terraria","session":token,"pid":pid,"request":request,"deadline":Date().timeIntervalSince1970+4.5,"context":state["context"] ?? 0,"action":parts[0]]
    if parts[0] == "overlay" {message["options"]=["visible":parts.count>1 && parts[1]=="1","liquidGlass":true]}
    else if parts.count>1 {message["feature"]=Int(parts[1])!}
    if parts.count>2 {message[parts[0]=="set" ? "wanted" : "value"] = parts[0]=="set" ? (parts[2]=="1" ? 1.0 : 0.0) : Double(parts[2])!}
    let data=try! JSONSerialization.data(withJSONObject:message)
    DistributedNotificationCenter.default().postNotificationName(NSNotification.Name("local.mht.command.v1"),object:String(data:data,encoding:.utf8)!,userInfo:nil,deliverImmediately:true)
    sent=Date()
}
RunLoop.main.run()
