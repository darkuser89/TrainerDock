// SPDX-License-Identifier: GPL-3.0-only
#import "NativeAdapter.h"
#import "LuaEngine.hpp"
#import "GameInput.hpp"
#import "Movement.h"
#import "MissionData.h"
#include <exception>
static NSString *finishAmbition(){
 NSDictionary *initial=IZCall(@"ambitionPlan",@[]);
 if(![initial[@"ready"] boolValue])return @"Keine aktive Ambition verfügbar.";
 NSString *owner=initial[@"owner"],*item=initial[@"item"];
 for(NSUInteger step=0;step<32;step++){
  NSDictionary *plan=IZCall(@"ambitionPlan",@[]);
  if(![plan[@"owner"] isEqual:owner]||![plan[@"item"] isEqual:item])return @"Der lokale Ambitionskontext hat gewechselt.";
  if([plan[@"completed"] boolValue])return @"Ambition im Spiel abgeschlossen.";
  NSArray *missions=plan[@"missions"];
  if(![missions isKindOfClass:NSArray.class]||!missions.count||missions.count>32)return @"Keine offenen Missionsbedingungen verfügbar.";
  NSMutableDictionary *definitions=[NSMutableDictionary new];
  for(NSDictionary *mission in missions){
   NSString *row=mission[@"row"],*text=IZCall(@"missionDefinition",@[row]);
   if(![text isKindOfClass:NSString.class]||text.length>65536)return @"Missionsdefinition nicht verfügbar.";
   id definition=[NSJSONSerialization JSONObjectWithData:[text dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
   if(![definition isKindOfClass:NSDictionary.class])return @"Ungültige native Missionsdefinition.";
   definitions[row]=definition;
  }
  NSDictionary *result=IZCall(@"advanceAmbition",@[plan,definitions]);
  if([result[@"completed"] boolValue])return @"Ambition im Spiel abgeschlossen.";
  if([result[@"step"] isEqual:plan[@"step"]])return @"Das Spiel hat den Ambitionsfortschritt noch nicht bestätigt.";
 }
 return @"Die Ambition hat zu viele Schritte für eine einzelne Aktion.";
}
@interface MHTNativeAdapter ()
@property(nonatomic,copy) NSString *localOwner;
@end
@implementation MHTNativeAdapter
- (instancetype)init {if((self=[super init]))IZEnableLuaEngine();return self;}
- (void)onGameThread:(dispatch_block_t)work {IZOnSimulationThread(work);}
- (MTGameContext *)captureContext {
 MTGameContext *c=[MTGameContext new];c.kind=MTSessionLoading;c.identity=@"";c.note=@"Auf den lokalen Spielstand warten.";
 try {NSDictionary *d=IZCall(@"context",@[]);if([d isKindOfClass:NSDictionary.class]){c.kind=[d[@"ready"] boolValue]?MTSessionSolo:MTSessionLoading;c.identity=d[@"identity"] ?: @"";c.note=d[@"note"] ?: c.note;}}catch(const std::exception &){c.note=@"Die native Spielanbindung ist noch nicht bereit.";}
 self.localOwner=c.kind==MTSessionSolo?c.identity:nil;IZMovementSetOwner(self.localOwner);return c;
}
- (void)releaseEffects {IZMovementSetOwner(nil);self.localOwner=nil;try{IZCall(@"release",@[]);}catch(const std::exception &){} }
- (MTFeatureState *)applyFeature:(MTFeature)feature wanted:(BOOL)wanted value:(double)value {
 MTFeatureState *s=[MTFeatureState new];s.wanted=wanted;s.value=value;s.note=@"Native Wirkung noch nicht bestätigt.";
 try {NSDictionary *d=feature==18?IZMovementApply(self.localOwner,wanted,value):IZCall(@"feature",@[@(feature),@(wanted),@(value)]);s.available=[d[@"available"] boolValue];s.active=wanted&&[d[@"active"] boolValue];s.note=d[@"note"] ?: s.note;if(feature==11&&!IZMissionDataReady()){s.available=NO;s.note=@"Originale Missionsdefinitionen werden geladen.";}}catch(const std::exception &){s.note=@"Die Spielanbindung hat den Auftrag abgelehnt.";}
 return s;
}
- (NSString *)performOneShot:(MTFeature)feature value:(double)value {try{id r=feature==11?finishAmbition():IZCall(@"perform",@[@(feature),@(value)]);return [r isKindOfClass:NSString.class]?r:@"Keine bestätigte Spielrückmeldung.";}catch(const std::exception &){return @"Die Aktion wurde nicht bestätigt.";}}
- (BOOL)setOverlayInteraction:(BOOL)wanted {return wanted&&IZMouseIsFree();}
@end
