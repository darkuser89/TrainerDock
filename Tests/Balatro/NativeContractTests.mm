// SPDX-License-Identifier: GPL-3.0-only
// Real original LuaJIT ABI, synthetic gameplay fixture: not an in-game test.
#import <Foundation/Foundation.h>
#import <dlfcn.h>
#import <AppKit/AppKit.h>
#import "BalatroEngine.h"
#import "BalatroScript.h"
#import "Overlay.h"
#import "TrainerMaterial.h"
static void check(BOOL condition,NSString *message){if(!condition){fprintf(stderr,"FAIL: %s\n",message.UTF8String);exit(1);}}
static int noop(lua_State *L){(void)L;return 0;}
int main(void){@autoreleasepool{
 check([BAInspect()[@"kind"] intValue]==0 && ![BAEffect(0,YES,0)[@"active"] boolValue],@"No gameplay operations outside confirmed engine frame");
 NSString *bundle=NSProcessInfo.processInfo.environment[@"TRAINERDOCK_REFERENCE_BUNDLE"] ?: NSProcessInfo.processInfo.environment[@"MHT_REFERENCE_BUNDLE"];
 if(!bundle.length)bundle=[[[NSUserDefaults alloc]initWithSuiteName:@"local.trainerdock.launcher"] stringForKey:@"MHT.balatro.path.steam-arm64"];
 if(!bundle.length)bundle=[[[NSUserDefaults alloc]initWithSuiteName:@"local.mht.launcher"] stringForKey:@"MHT.balatro.path.steam-arm64"];
 if(!bundle.length)bundle=[NSWorkspace.sharedWorkspace URLForApplicationWithBundleIdentifier:@"com.Balatro.localthunk"].path;
 check(bundle.length>0,@"Original Balatro bundle required for real Lua ABI tests");
 void *h=dlopen([[bundle stringByAppendingPathComponent:@"Contents/Frameworks/Lua.framework/Versions/A/Lua"] fileSystemRepresentation],RTLD_NOW|RTLD_LOCAL);
 check(h!=NULL,@"Original LuaJIT library loads");
 #define FN(ret,name,args) auto name=(ret (*)args)dlsym(h,#name);check(name!=NULL,@#name)
 FN(lua_State *,luaL_newstate,(void));FN(void,luaL_openlibs,(lua_State *));FN(int,luaL_loadbuffer,(lua_State *,const char *,size_t,const char *));
 FN(int,lua_pcall,(lua_State *,int,int,int));FN(void,lua_pushcclosure,(lua_State *,int (*)(lua_State *),int));
 FN(const char *,lua_tolstring,(lua_State *,int,size_t *));FN(void,lua_setfield,(lua_State *,int,const char *));FN(void,lua_close,(lua_State *));
 lua_State *L=luaL_newstate();check(L!=NULL,@"Lua state");luaL_openlibs(L);
 auto execute=[&](NSData *data,const char *name){int result=luaL_loadbuffer(L,(const char *)data.bytes,data.length,name);if(!result)result=lua_pcall(L,0,0,0);check(!result,[NSString stringWithUTF8String:result ? lua_tolstring(L,-1,NULL) : "OK"]);};
 NSString *fixture=@"G={VERSION='1.0.1o-FULL',STAGE=2,STAGES={RUN=2},STATE=1,STATES={GAME_OVER=9},SETTINGS={paused=false},GAME={dollars=4,chips=0,round=1,round_resets={ante=1},current_round={hands_left=4,discards_left=3,current_hand={}}},HUD={get_UIE_by_ID=function() return nil end,recalculate=function() end},hand={},deck={}};Back={trigger_effect=function(self,args) return args.chips,args.mult end};G.GAME.selected_back=setmetatable({},{__index=Back});love={update=function(dt) last_dt=dt end,mouse={isVisible=function() return visible or false end,setVisible=function(v) visible=v end}}";
 execute([fixture dataUsingEncoding:NSUTF8StringEncoding],"fixture");
 check(!luaL_loadbuffer(L,BAScript,sizeof(BAScript)-1,"@MHT/balatro.lua"),@"Trainer script compiles with original LuaJIT");lua_pushcclosure(L,noop,0);lua_pushcclosure(L,noop,0);
 int result=lua_pcall(L,2,1,0);check(!result,[NSString stringWithUTF8String:result ? lua_tolstring(L,-1,NULL) : "Factory"]);lua_setfield(L,-10002,"trainer");
 NSData *tests=[NSData dataWithContentsOfFile:@"Tests/Balatro/PolicyTests.lua"];check(tests!=nil,@"Policy tests exist");execute(tests,"policy-tests");lua_close(L);dlclose(h);
 [NSApplication sharedApplication];
 NSWindow *window=[[NSWindow alloc]initWithContentRect:NSMakeRect(0,0,1100,700) styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:NO];
 MTOverlayRoot *root=[[MTOverlayRoot alloc]initWithFrame:window.contentView.bounds version:@"1.0.1o-FULL"];[window.contentView addSubview:root];
 MTTrainerState *state=[MTTrainerState new];state.ready=YES;for(MTFeatureState *f in state.features){f.available=YES;}[root updateState:state];
 __block NSInteger activated=-1;root.featureHandler=^(MTFeature f){activated=f;};
 for(NSNumber *glass in @[@NO,@YES])for(NSNumber *scale in @[@0.7,@1.3]){
  [root applyOverlayOptions:@{@"visible":@YES,@"liquidGlass":glass,@"scale":scale}];[root layoutSubtreeIfNeeded];
  NSView *content=((MTTrainerMaterial *)root.panel).contentView;
  NSPoint point=[content convertPoint:NSMakePoint(249,58) toView:nil];
  NSEvent *click=[NSEvent mouseEventWithType:NSEventTypeLeftMouseDown location:point modifierFlags:0 timestamp:0 windowNumber:window.windowNumber context:nil eventNumber:0 clickCount:1 pressure:1];
  activated=-1;check([root handleMouseEvent:click] && activated==0,@"Mouse reaches the actual row at both zooms with/without glass");
  point=[content convertPoint:NSMakePoint(524,15) toView:nil];
  click=[NSEvent mouseEventWithType:NSEventTypeLeftMouseDown location:point modifierFlags:0 timestamp:0 windowNumber:window.windowNumber context:nil eventNumber:0 clickCount:1 pressure:1];
  check([root handleMouseEvent:click] && !root.panelVisible,@"Mouse closes the actual overlay");
 }
 puts("PASS: original LuaJIT ABI; native frame guard; owned values, scoring callback, time factor, readback, edits, owner changes, loading/network and mouse restore.");
}return 0;}
