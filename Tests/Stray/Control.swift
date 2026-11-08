// SPDX-License-Identifier: GPL-3.0-only
// Client for the real module protocol. Never launches or closes a game.
import Foundation
let sessionURL=URL(fileURLWithPath:"/private/tmp/trainerdock-stray/Session.json")
let session=try JSONSerialization.jsonObject(with:Data(contentsOf:sessionURL)) as! [String:Any]
let arguments=CommandLine.arguments
let command=try JSONSerialization.jsonObject(with:Data((arguments.count>1 ? arguments[1] : "{}").utf8)) as! [String:Any]
let request=UUID().uuidString
var sent=false
let observer=DistributedNotificationCenter.default().addObserver(forName:NSNotification.Name("local.mht.state.v1"),object:nil,queue:.main){event in
 guard let text=event.object as? String,let bytes=text.data(using:.utf8),let message=(try? JSONSerialization.jsonObject(with:bytes)) as? [String:Any],
       message["module"] as? String=="stray",message["session"] as? String==session["token"] as? String,
       message["pid"] as? Int==session["pid"] as? Int,let state=message["state"] as? [String:Any] else{return}
 func finish(){
  var output:[String:Any]=["ready":state["ready"] ?? false,"context":state["context"] ?? 0,"message":state["message"] ?? "","error":message["error"] ?? ""]
  if let feature=command["feature"] as? Int,let rows=state["features"] as? [[String:Any]],feature<rows.count {output["feature"]=rows[feature]}
  if let overlay=state["overlay"] {output["overlay"]=overlay}
  if let data=try? JSONSerialization.data(withJSONObject:output,options:[.sortedKeys]),let text=String(data:data,encoding:.utf8){print(text)}
  exit((message["error"] as? String ?? "").isEmpty ? 0:1)
 }
 if command.isEmpty || command["observe"] as? Bool == true {finish();return}
 if !sent {
  guard state["ready"] as? Bool==true else{return}
  var payload=command;payload["version"]=1;payload["module"]="stray";payload["session"]=session["token"];payload["pid"]=session["pid"];payload["request"]=request;payload["context"]=state["context"];payload["deadline"]=Date().timeIntervalSince1970+4
  guard let data=try? JSONSerialization.data(withJSONObject:payload),let text=String(data:data,encoding:.utf8) else{return}
  sent=true;DistributedNotificationCenter.default().postNotificationName(NSNotification.Name("local.mht.command.v1"),object:text,userInfo:nil,deliverImmediately:true)
 } else if message["request"] as? String==request {finish()}
}
_ = observer
DispatchQueue.main.asyncAfter(deadline:.now()+12){fputs("No authenticated module response; no replacement start attempted.\n",stderr);exit(2)}
RunLoop.main.run()
