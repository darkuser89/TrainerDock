// SPDX-License-Identifier: GPL-3.0-only
// Exercises the actual module/bridge/overlay in the authorized running game.
#import "ControlEngine.h"
#import "NativeAdapter.h"
#import "Overlay.h"
#import "MHTOverlayHost.h"
#import "ProbeRequest.h"
static MTGameBridge *bridge;
static MTOverlayRoot *root;
static MHTOverlayHost *host;
static NSTimer *poll,*input;
static unsigned long serial;
static id monitor;
extern void MTControlDiagnosticFrame(void);
static void setup(){NSCAssert(NSThread.isMainThread,@"Main-thread overlay host");
 bridge=[[MTGameBridge alloc]initWithAdapter:[MHTNativeAdapter new]];
 NSWindow *game=nil;for(NSWindow *w in NSApp.windows)if(w.isVisible&&![w isKindOfClass:NSPanel.class]&&w.contentView.bounds.size.width>=640){game=w;break;}if(!game)return;
 root=[[MTOverlayRoot alloc]initWithFrame:game.contentView.bounds version:@"1.34 · Steam"];
 [root applyOverlayOptions:@{@"visible":@YES,@"liquidGlass":@YES,@"glassIntensity":@.5}];
 root.featureHandler=^(MTFeature f){[bridge performFeature:f];};root.valueHandler=^(MTFeature f,double value){[bridge setValue:value forFeature:f];};root.actionHandler=^(MTTrainerAction a){[bridge performAction:a];};
 host=[[MHTOverlayHost alloc]initWithGameWindow:game overlay:root];__weak MTOverlayRoot *weak=root;host.mouseHandler=^BOOL(NSEvent *e){return [weak handleMouseEvent:e];};
 bridge.stateChanged=^(MTTrainerState *state){[root updateState:state];NSMutableArray *features=[NSMutableArray new];for(NSInteger i=0;i<MTFeatureCount;i++){MTFeatureState *f=state.features[i];[features addObject:@{@"id":@(i),@"available":@(f.available),@"wanted":@(f.wanted),@"active":@(f.active),@"value":@(f.value),@"note":f.note?:@""}];}NSDictionary *d=@{@"pid":@(getpid()),@"ready":@(state.ready),@"status":state.status,@"message":state.message,@"mouse":@(state.overlayMouseActive),@"features":features};[[NSJSONSerialization dataWithJSONObject:d options:NSJSONWritingPrettyPrinted error:NULL]writeToFile:@"/private/tmp/mht-control/ModuleState.json" options:NSDataWritingAtomic error:NULL];};
 monitor=[NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskKeyDown|NSEventMaskLeftMouseDown|NSEventMaskLeftMouseUp|NSEventMaskLeftMouseDragged handler:^NSEvent*(NSEvent *e){return [root handleEvent:e]?nil:e;}];
 poll=[NSTimer scheduledTimerWithTimeInterval:.25 repeats:YES block:^(NSTimer *t){(void)t;[bridge poll];
  NSDictionary *q=MTControlReadProbeRequest([NSData dataWithContentsOfFile:@"/private/tmp/mht-control/ModuleRequest.json"]);if([q[@"serial"]unsignedLongValue]<=serial)return;serial=[q[@"serial"]unsignedLongValue];
  for(NSString *k in q[@"values"]){NSInteger f=k.integerValue;if(f>=0&&f<MTFeatureCount)[bridge setValue:[q[@"values"][k]doubleValue] forFeature:(MTFeature)f];}
  for(NSString *k in q[@"wanted"]){NSInteger f=k.integerValue;if(f>=0&&f<MTFeatureCount)[bridge setWanted:[q[@"wanted"][k]boolValue]forFeature:(MTFeature)f];}
  for(NSNumber *n in q[@"actions"]){NSInteger f=n.integerValue;if(f>=0&&f<MTFeatureCount)[bridge performFeature:(MTFeature)f];}
  if(q[@"visible"])[root applyOverlayOptions:@{@"visible":q[@"visible"],@"liquidGlass":@YES,@"glassIntensity":@.5}];
 }];
 input=[NSTimer scheduledTimerWithTimeInterval:.1 repeats:YES block:^(NSTimer *t){(void)t;[bridge setOverlayInteraction:root.wantsMouseInteraction&&NSApp.isActive];host.mouseInteractionEnabled=bridge.state.overlayMouseActive;[host synchronize];}];
 [bridge poll];
 MHTControlSetTestObserver(^{MTControlDiagnosticFrame();});
}
__attribute__((constructor))static void directStart(){if(![NSProcessInfo.processInfo.environment[@"MHT_CONTROL_DIRECT"]isEqual:@"1"])return;dispatch_async(dispatch_get_main_queue(),^{[NSTimer scheduledTimerWithTimeInterval:1 repeats:YES block:^(NSTimer *timer){for(NSWindow *window in NSApp.windows)if(window.isVisible&&![window isKindOfClass:NSPanel.class]&&window.contentView.bounds.size.width>=640){[timer invalidate];setup();break;}}];});}
extern "C" void MHTControlProbeFrame(uintptr_t core,uintptr_t main,void *server,unsigned long f){(void)f;static bool started=false;if(!started){started=true;dispatch_async(dispatch_get_main_queue(),^{setup();});}MHTControlExternalFrame(main,core,server);}
extern "C" void MHTControlProbeStop(){MHTControlSetMaintenance(nil);dispatch_async(dispatch_get_main_queue(),^{[bridge performAction:MTTrainerDisableAll];[bridge setOverlayInteraction:NO];[poll invalidate];[input invalidate];[NSEvent removeMonitor:monitor];[host close];});}
