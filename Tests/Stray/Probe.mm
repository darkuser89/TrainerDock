// SPDX-License-Identifier: GPL-3.0-only
// Private diagnostics only; never linked into the released trainer.
#import <AppKit/AppKit.h>
#import "StrayEngine.hpp"
#include <exception>
#include <cstdlib>
#include <cstring>
#include <stdexcept>
#include <unistd.h>
#include <vector>
#import "PlayerEffects.hpp"
#import "Defluxor.hpp"
#import "EnemyEffects.hpp"
extern "C" {
#import "TrainerFeatures.h"
}
#import "NativeAdapter.h"
#include <chrono>
namespace {
NSMutableSet *consumed;NSString *token;bool busy=false;uint64_t callbacks=0;
NSDictionary *describe(st::Object o){if(!o)return @{};st::Weak w(o);return @{@"index":@(w.index),@"serial":@(w.serial),@"name":st::name(o),@"class":st::className(o),@"address":[NSString stringWithFormat:@"0x%llx",(unsigned long long)o.address]};}
NSDictionary *property(const st::Property &p){return @{@"name":p.name,@"type":p.type,@"offset":@(p.offset),@"size":@(p.size),@"count":@(p.count),@"flags":@(p.flags),@"mask":@(p.boolMask),@"byte":@(p.boolByteOffset)};}
id execute(NSDictionary *a){
 if(!st::isGameThread())throw std::runtime_error("Originaler GameThread fehlt.");callbacks++;
 NSString *op=a[@"op"] ?: @"status";
 if([op isEqual:@"timing"]){
  // Explicit, bounded test only. Call after disableAll; no background benchmark.
  MHTNativeAdapter *adapter=[MHTNativeAdapter new];NSMutableArray *milliseconds=[NSMutableArray new];
  for(int i=0;i<8;i++){
   auto began=std::chrono::steady_clock::now();MTGameContext *c=[adapter captureContext];
   if(c.kind!=MTSessionSolo)throw std::runtime_error("Für die Messung fehlt die lokale Katze.");
   [adapter setOverlayInteraction:NO];
   for(NSInteger f=0;f<MTFeatureCount;f++)[adapter applyFeature:(MTFeature)f wanted:NO value:MTFeatureInfoAt((MTFeature)f)->initial];
   double elapsed=std::chrono::duration<double,std::milli>(std::chrono::steady_clock::now()-began).count();[milliseconds addObject:@(elapsed)];
   if(elapsed>100)break;
  }
  return @{@"idlePollMilliseconds":milliseconds,@"gameThread":@YES};
 }
 if([op isEqual:@"context"]){auto c=st::playerContext();return @{@"ready":@(c.ready),@"note":c.note ?: @"",@"world":describe(c.world),@"pawn":describe(c.pawn),@"controller":describe(c.controller),@"life":describe(c.life)};}
 if([op isEqual:@"asset"]){
  NSString *leaf=a[@"name"];
  if(![@[@"BTS_Sentinel_Vision.uasset",@"BTS_Sentinel_Vision.uexp",@"BTS_Sentinel_UpdateLogic.uasset",@"BTS_Sentinel_UpdateLogic.uexp"] containsObject:leaf])throw std::runtime_error("Originaldatei nicht für diese Diagnose freigegeben.");
  intptr_t slide=st::binding("processEvent")-0x1015f656cULL;
  uint8_t actual[16];const uint8_t loader[]={0xf6,0x57,0xbd,0xa9,0xf4,0x4f,0x01,0xa9,0xfd,0x7b,0x02,0xa9,0xfd,0x83,0x00,0x91},release[]={0xf4,0x4f,0xbe,0xa9,0xfd,0x7b,0x01,0xa9,0xfd,0x43,0x00,0x91,0x80,0x01,0x00,0xb4};
  if(!st::read(0x1013c9c48+slide,actual,16)||memcmp(actual,loader,16)||!st::read(0x1012b7a84+slide,actual,16)||memcmp(actual,release,16))throw std::runtime_error("Originale Datei-API stimmt nicht überein.");
  NSString *path=[@"../../../Hk_project/Content/Character/Sentinel/AI/Services/" stringByAppendingString:leaf];std::vector<unichar> utf16(path.length+1);[path getCharacters:utf16.data() range:NSMakeRange(0,path.length)];
  struct Array{void *data;int32_t count,capacity;};Array array{};
  bool ok=((bool(*)(Array *,const unichar *,uint32_t))(0x1013c9c48+slide))(&array,utf16.data(),0);
  NSData *bytes=ok&&array.data&&array.count>0&&array.count<=65536&&array.capacity>=array.count?[NSData dataWithBytes:array.data length:array.count]:nil;
  if(array.data)((void(*)(void *))(0x1012b7a84+slide))(array.data);
  if(!bytes)throw std::runtime_error("Kleine Originaldatei nicht verfügbar.");return @{@"base64":[bytes base64EncodedStringWithOptions:0],@"size":@(bytes.length)};
 }
 if([op isEqual:@"effects"]){auto c=st::playerContext();return @{@"player":st::playerDiagnostics(c),@"enemies":STEnemyDiagnostics(),@"defluxor":STDefluxorDiagnostics()};}
 if([op isEqual:@"feature"]){auto c=st::playerContext();NSInteger f=[a[@"feature"] integerValue];BOOL wanted=[a[@"wanted"] boolValue];double value=[a[@"value"] doubleValue];return f==5?STDefluxorApply(wanted):(f==2||f==3||f==4)?STEnemyApply(f,wanted):st::playerFeature(c,f,wanted,value);}
 if([op isEqual:@"status"])return @{@"pid":@(getpid()),@"callbacks":@(callbacks),@"world":describe(st::world()),@"pawn":describe(st::playerPawn()),@"controller":describe(st::playerController()),@"count":@(st::objectCount())};
 if([op isEqual:@"find"]){NSMutableArray *rows=[NSMutableArray new];for(auto o:st::find(a[@"class"],a[@"name"],MIN(512,MAX(1,[a[@"limit"] unsignedIntegerValue] ?: 64))))[rows addObject:describe(o)];return rows;}
 if([op isEqual:@"read"]){uintptr_t at=strtoull([a[@"address"] UTF8String],nullptr,0);NSUInteger n=[a[@"length"] unsignedIntegerValue];if(!n||n>4096)throw std::runtime_error("Diagnosegrenze überschritten.");NSMutableData *data=[NSMutableData dataWithLength:n];if(!st::read(at,data.mutableBytes,n))throw std::runtime_error("Speicher nicht lesbar.");NSMutableString *hex=[NSMutableString new];for(NSUInteger i=0;i<n;i++)[hex appendFormat:@"%02x",((uint8_t *)data.bytes)[i]];return @{@"hex":hex};}
 st::Object o=st::object([a[@"index"] intValue]);if(!o)throw std::runtime_error("Originalobjekt fehlt.");
 if([op isEqual:@"describe"]){NSMutableDictionary *d=[describe(o) mutableCopy];NSMutableArray *props=[NSMutableArray new];for(auto p:st::fields(o))[props addObject:property(p)];d[@"fields"]=props;return d;}
 if([op isEqual:@"function"]){auto f=st::function(o,a[@"name"]);NSMutableDictionary *d=[describe(f) mutableCopy];NSMutableArray *props=[NSMutableArray new];for(auto p:st::properties(f))[props addObject:property(p)];d[@"parameters"]=props;return d;}
 if([op isEqual:@"get"])return st::readValue(o,st::property(o,a[@"field"]));
 if([op isEqual:@"set"]){auto p=st::property(o,a[@"field"]);if(!st::writeValue(o,p,a[@"value"]))throw std::runtime_error("Originalfeld lehnt Wert ab.");return st::readValue(o,p);}
 if([op isEqual:@"invoke"])return st::invoke(o,a[@"name"],a[@"arguments"] ?: @{});
 throw std::runtime_error("Unbekannter Diagnoseauftrag.");
}
}
__attribute__((constructor))static void startProbe(){dispatch_async(dispatch_get_main_queue(),^{
 if(strcmp(getenv("STRAY_PRIVATE_SESSION") ?: "","1"))return;
 token=getenv("MHT_SESSION")?@(getenv("MHT_SESSION")):nil;if(!token.length)return;consumed=[NSMutableSet new];
 NSTimer *timer=[NSTimer timerWithTimeInterval:.1 repeats:YES block:^(NSTimer *){
  if(!st::isBound())st::bind();
  // Main-thread bootstrap diagnostics stay available even before GameThread registration.
  if(busy||consumed.count>=4096)return;
  NSData *bytes=[NSData dataWithContentsOfFile:@"/private/tmp/trainerdock-stray/Request.json"];if(!bytes||bytes.length>65536)return;
  id r=[NSJSONSerialization JSONObjectWithData:bytes options:0 error:nil];if(![r isKindOfClass:NSDictionary.class]||![r[@"token"] isEqual:token]||![r[@"id"] isKindOfClass:NSString.class]||[consumed containsObject:r[@"id"]])return;
  if([r[@"action"][@"op"] isEqual:@"engine"]){[consumed addObject:r[@"id"]];NSDictionary *reply=@{@"id":r[@"id"],@"result":@{@"bound":@(st::isBound()),@"callbacks":@(callbacks),@"pid":@(getpid())}};[[NSJSONSerialization dataWithJSONObject:reply options:0 error:nil] writeToFile:@"/private/tmp/trainerdock-stray/Reply.json" atomically:YES];return;}
  NSTimeInterval submitted=NSDate.date.timeIntervalSince1970;busy=true;
  bool queued=st::onGameThread(^{@autoreleasepool{
   NSMutableDictionary *reply=[@{@"id":r[@"id"]} mutableCopy];@try{try{
    if(NSDate.date.timeIntervalSince1970-submitted>20)throw std::runtime_error("Diagnoseauftrag abgelaufen.");
    reply[@"result"]=execute(r[@"action"]) ?: NSNull.null;
   }catch(const std::exception &e){reply[@"error"]=@(e.what());}}@catch(NSException *e){reply[@"error"]=e.reason;}
   NSData *data=[NSJSONSerialization dataWithJSONObject:reply options:0 error:nil];[data writeToFile:@"/private/tmp/trainerdock-stray/Reply.json" atomically:YES];
   dispatch_async(dispatch_get_main_queue(),^{busy=false;});
  }});
  if(queued)[consumed addObject:r[@"id"]];else busy=false;
 }];[NSRunLoop.mainRunLoop addTimer:timer forMode:NSRunLoopCommonModes];
});}
