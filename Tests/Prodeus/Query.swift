// SPDX-License-Identifier: GPL-3.0-only
// Session-bound production protocol. Multiple command arguments run sequentially in one game instance.
import Foundation
let sessionURL=URL(fileURLWithPath:"/private/tmp/trainerdock-prodeus/Session.json")
let coordination=try JSONSerialization.jsonObject(with:Data(contentsOf:sessionURL)) as! [String:Any]
let token=coordination["token"] as! String,pid=coordination["pid"] as! Int
var commands=Array(CommandLine.arguments.dropFirst());if commands.isEmpty{commands=["state"]}
var index=0,latest:[String:Any]?,request:String?,acknowledged:Date?,replyError:String?,deadline=Date().addingTimeInterval(6)
func output(_ state:[String:Any],_ error:String?=nil){
 let value:[String:Any]=["command":commands[index],"state":state,"error":error ?? ""]
 if let data=try? JSONSerialization.data(withJSONObject:value,options:[.sortedKeys]),let text=String(data:data,encoding:.utf8){print(text)}
 index+=1;request=nil;acknowledged=nil;replyError=nil;deadline=Date().addingTimeInterval(6)
 if index==commands.count{exit(error==nil ? 0:1)}
}
let observer=DistributedNotificationCenter.default().addObserver(forName:NSNotification.Name("local.mht.state.v1"),object:nil,queue:.main){event in
 guard let raw=event.object as? String,let data=raw.data(using:.utf8),let message=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any],
 message["module"] as? String=="prodeus",message["session"] as? String==token,message["pid"] as? Int==pid,
 let state=message["state"] as? [String:Any] else{return}
 latest=state
 if let current=request,message["request"] as? String==current{acknowledged=Date();let error=message["error"] as? String;replyError=error?.isEmpty==false ? error:nil}
}
let probeObserver=DistributedNotificationCenter.default().addObserver(forName:NSNotification.Name("local.trainerdock.prodeus.probe.response"),object:nil,queue:.main){event in
 guard let raw=event.object as? String,let data=raw.data(using:.utf8),let message=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any],
 message["session"] as? String==token,message["pid"] as? Int==pid,let current=request,message["requestID"] as? String==current else{return}
 let error=message["error"] as? String
 output(["probe":message["values"] ?? [:]],error?.isEmpty==false ? error:nil)
}
let timer=Timer.scheduledTimer(withTimeInterval:0.05,repeats:true){_ in
 guard Date()<deadline else{fputs("Keine aktuelle Trainerantwort.\n",stderr);exit(1)}
 if request==nil,commands[index].hasPrefix("probe:"){
  let parts=commands[index].split(separator:":").map(String.init)
  guard parts.count>=2,["values","set-player"].contains(parts[1]) else{exit(2)}
  let identifier=UUID().uuidString;request=identifier
  var message:[String:Any]=["session":token,"pid":pid,"requestID":identifier,"deadline":Date().timeIntervalSince1970+3,"action":parts[1]]
  if parts[1]=="set-player"{
   guard parts.count==4,let health=Int(parts[2]),let armor=Int(parts[3]),(1...200).contains(health),(0...200).contains(armor) else{exit(2)}
   message["health"]=health;message["armor"]=armor
  }
  let data=try! JSONSerialization.data(withJSONObject:message)
  DistributedNotificationCenter.default().postNotificationName(NSNotification.Name("local.trainerdock.prodeus.probe.request"),object:String(data:data,encoding:.utf8)!,userInfo:nil,deliverImmediately:true)
  return
 }
 guard let state=latest else{return}
 if let received=acknowledged,Date().timeIntervalSince(received)>0.8{output(state,replyError);return}
 guard request==nil else{return}
 let parts=commands[index].split(separator:":",omittingEmptySubsequences:false).map(String.init),action=parts[0]
 if action=="state"{output(state);return}
 guard ["set","value","run","disableAll","overlay"].contains(action) else{fputs("Unbekannter Prüfauftrag.\n",stderr);exit(2)}
 let identifier=UUID().uuidString;request=identifier
 var message:[String:Any]=["version":1,"module":"prodeus","session":token,"pid":pid,"request":identifier,
 "deadline":Date().timeIntervalSince1970+1,"context":state["context"] ?? 0,"action":action]
 if action=="overlay"{
  guard parts.count==2,parts[1]=="0"||parts[1]=="1" else{exit(2)}
  message["options"]=["visible":parts[1]=="1"]
 }else if action != "disableAll"{
  guard parts.count>=2,let feature=Int(parts[1]),(0..<13).contains(feature) else{exit(2)}
  message["feature"]=feature
  if action=="set"{guard parts.count==3,parts[2]=="0"||parts[2]=="1" else{exit(2)};message["wanted"]=parts[2]=="1"}
  if action=="value"{guard parts.count==3,let value=Double(parts[2]),value.isFinite else{exit(2)};message["value"]=value}
 }
 let data=try! JSONSerialization.data(withJSONObject:message)
 DistributedNotificationCenter.default().postNotificationName(NSNotification.Name("local.mht.command.v1"),object:String(data:data,encoding:.utf8)!,userInfo:nil,deliverImmediately:true)
}
RunLoop.main.run()
