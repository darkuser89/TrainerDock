// SPDX-License-Identifier: GPL-3.0-only
// Scoped test client; accepts only the current private session's notifications.
import Foundation
let root=URL(fileURLWithPath:"/private/tmp/trainerdock-house-flipper",isDirectory:true)
let coordination=try JSONSerialization.jsonObject(with:Data(contentsOf:root.appendingPathComponent("Session.json"))) as! [String:Any]
let token=coordination["token"] as! String,pid=coordination["pid"] as! Int
var commands=Array(CommandLine.arguments.dropFirst());if commands.isEmpty{commands=["state"]}
var index=0,latest:[String:Any]?,request:String?,replyError:String?,received:Date?
var serial=0,ackSerial=0,failed=false,deadline=Date().addingTimeInterval(8)
func output(_ state:[String:Any],_ error:String?=nil){
 failed=failed || error != nil
 let value:[String:Any]=["command":commands[index],"state":state,"error":error ?? ""]
 if let data=try? JSONSerialization.data(withJSONObject:value,options:[.sortedKeys]),let text=String(data:data,encoding:.utf8){print(text)}
 index+=1;request=nil;received=nil;replyError=nil;deadline=Date().addingTimeInterval(8)
 if index==commands.count{exit(failed ? 1:0)}
}
func observed(_ state:[String:Any])->Bool{
 let parts=commands[index].split(separator:":").map(String.init)
 let rows=state["features"] as? [[String:Any]] ?? []
 if parts[0]=="disableAll"{return rows.allSatisfy{!($0["wanted"] as? Bool ?? true)}}
 if parts[0]=="set",parts.count==3,let feature=Int(parts[1]),feature<rows.count{return rows[feature]["wanted"] as? Bool == (parts[2]=="1")}
 if parts[0]=="overlay",parts.count==2{return (state["overlay"] as? [String:Any])?["visible"] as? Bool == (parts[1]=="1")}
 return true
}
let observer=DistributedNotificationCenter.default().addObserver(forName:NSNotification.Name("local.mht.state.v1"),object:nil,queue:.main){event in
 guard let raw=event.object as? String,let data=raw.data(using:.utf8),let message=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any],
 message["module"] as? String=="house-flipper",message["session"] as? String==token,message["pid"] as? Int==pid,
 let state=message["state"] as? [String:Any] else{return}
 latest=state;serial+=1
 if let current=request,message["request"] as? String==current{received=Date();ackSerial=serial;let error=message["error"] as? String;replyError=error?.isEmpty==false ? error:nil}
}
let probeObserver=DistributedNotificationCenter.default().addObserver(forName:NSNotification.Name("local.trainerdock.house-flipper.probe.response"),object:nil,queue:.main){event in
 guard let raw=event.object as? String,let data=raw.data(using:.utf8),let message=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any],
 message["session"] as? String==token,message["pid"] as? Int==pid,let current=request,message["requestID"] as? String==current else{return}
 let error=message["error"] as? String
 output(["probe":message],error?.isEmpty==false ? error:nil)
}
let timer=Timer.scheduledTimer(withTimeInterval:0.05,repeats:true){_ in
 guard Date()<deadline else{fputs("Keine bestätigte aktuelle Trainerantwort.\n",stderr);exit(1)}
 if request==nil,commands[index].hasPrefix("probe:"){
  let parts=commands[index].split(separator:":").map(String.init)
  guard (parts.count==2 && parts[1]=="values") || (parts.count==3 && parts[1]=="spend-money") else{fputs("Unbekannter nativer Prüfauftrag.\n",stderr);exit(2)}
  let identifier=UUID().uuidString;request=identifier
  var message:[String:Any]=["session":token,"pid":pid,"requestID":identifier,"deadline":Date().timeIntervalSince1970+3,"action":parts[1]]
  if parts[1]=="spend-money"{
   guard let amount=Double(parts[2]),amount.isFinite,amount>0,amount<=1000 else{fputs("Prüfzahlung muss größer als null und höchstens 1.000 sein.\n",stderr);exit(2)}
   message["amount"]=amount
  }
  let data=try! JSONSerialization.data(withJSONObject:message)
  DistributedNotificationCenter.default().postNotificationName(NSNotification.Name("local.trainerdock.house-flipper.probe.request"),object:String(data:data,encoding:.utf8)!,userInfo:nil,deliverImmediately:true)
  return
 }
 guard let state=latest else{return}
 // Runtime acknowledgement can contain the previous state. Wait for a later
 // heartbeat and the requested selection before reporting an applied command.
 if let received=received {
  if let error=replyError{output(state,error);return}
  if serial>ackSerial && Date().timeIntervalSince(received)>0.3 && observed(state){output(state);return}
  return
 }
 guard request==nil else{return}
 let parts=commands[index].split(separator:":",omittingEmptySubsequences:false).map(String.init),action=parts[0]
 if action=="state"{output(state);return}
 guard ["set","disableAll","overlay"].contains(action) else{fputs("Unbekannter Prüfauftrag.\n",stderr);exit(2)}
 let identifier=UUID().uuidString;request=identifier
 var message:[String:Any]=["version":1,"module":"house-flipper","session":token,"pid":pid,"request":identifier,
 "deadline":Date().timeIntervalSince1970+1,"context":state["context"] ?? 0,"action":action]
 if action=="overlay"{
  guard parts.count==2,parts[1]=="0"||parts[1]=="1" else{exit(2)};message["options"]=["visible":parts[1]=="1"]
 }else if action=="set"{
  guard parts.count==3,let feature=Int(parts[1]),(0..<2).contains(feature),parts[2]=="0"||parts[2]=="1" else{exit(2)}
  message["feature"]=feature;message["wanted"]=parts[2]=="1"
 }
 let data=try! JSONSerialization.data(withJSONObject:message)
 DistributedNotificationCenter.default().postNotificationName(NSNotification.Name("local.mht.command.v1"),object:String(data:data,encoding:.utf8)!,userInfo:nil,deliverImmediately:true)
}
RunLoop.main.run()
