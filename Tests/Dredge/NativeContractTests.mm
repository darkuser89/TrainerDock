// SPDX-License-Identifier: GPL-3.0-only
// Synthetic embedding-ABI boundaries. No game or original Mono library is loaded.
#import "DredgeNative.h"
#include "DredgeMono.hpp"
#include "DredgeBuild.h"
#include "EquipmentLeaseTests.hpp"
#include <array>
#include <cstring>
#include <cstdlib>
#include <limits>
#include <map>
#import <AppKit/AppKit.h>
extern "C" {
#import "MHTProtocol.h"
#import "OverlaySettings.h"
#import "SelectionSettings.h"
#import "OverlayShortcuts.h"
}
#define MHT_OVERLAY_WINDOW_CHECKS_ONLY 1
#import "../OverlayRuntimeWindowTests.m"
using namespace dr;
namespace {
void check(bool ok,const char *message){if(!ok){fprintf(stderr,"FAIL: %s\n",message);exit(1);}}
void checkEarlyOverlay(NSUInteger expectedFrames){
 [NSApplication sharedApplication];[NSApp setActivationPolicy:NSApplicationActivationPolicyProhibited];
 runtimeLog=os_log_create("local.trainerdock.tests.dredge","early-overlay");
 roots=[NSMutableArray new];overlayHosts=[NSMutableArray new];
 overlayOptions=MTNormalizeOverlayOptions(@{@"visible":@YES,@"glassIntensity":@0.5});
 NSWindow *game=[[NSWindow alloc]initWithContentRect:NSMakeRect(100,100,1200,900)
  styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskResizable backing:NSBackingStoreBuffered defer:NO];
 game.releasedWhenClosed=NO;NSView *original=game.contentView;
 NSArray *views=original.subviews.copy,*constraints=original.constraints.copy;
 [game orderFront:nil];
 check([DRNativeObservation()[@"frames"] unsignedIntegerValue]==expectedFrames,"early-attach fixture has the expected original-frame count");
 attachToGameWindow();
 check(roots.count==0&&overlayHosts.count==0&&!game.childWindows.count,"real runtime must not create a trainer root or child panel during startup");
 check(game.contentView==original&&[views isEqual:original.subviews]&&[constraints isEqual:original.constraints],"early attachment leaves the original engine content and constraints unchanged");
 [game orderOut:nil];[game close];roots=nil;overlayHosts=nil;
}
struct Signature {const char *result;std::vector<const char *>params;bool isStatic;};
Signature thunk={"System.Delegate",{"System.IntPtr","System.Type"},true};
Signature callback={"System.Void",{},false};
Signature decimalSingle={"System.Decimal",{"System.Single"},true};
Signature decimalDouble={"System.Decimal",{"System.Double"},true};
Signature addCallback={"System.Void",{"UnityEngine.Events.UnityAction"},true};
std::map<uint32_t,Object> handles;uint32_t nextHandle=7;
static uintptr_t domainID=1;static bool alive=true;static size_t invocations=0,fieldReads=0,fieldWrites=0,rootHandles=0,frees=0;static bool raiseManaged=false;
static void *reflected=(void *)0x1234,*delegate=(void *)0x5678;static void (*captured)();
static std::array<uint8_t,16> bytes{};
void *root(){return (void *)domainID;}
int32_t domainId(void *d){check(d==root(),"only real synthetic domain inspected");return 12;}
void *domainById(int32_t id){check(id==12,"exact bound game domain identifier used");return alive?root():nullptr;}
void *signature(dr::Method m){return m;}
uint32_t count(void *s){return (uint32_t)((Signature *)s)->params.size();}
void *returnType(void *s){return (void *)((Signature *)s)->result;}
void *parameter(void *s,void **iter){size_t i=(size_t)*iter;auto *method=(Signature *)s;if(i>=method->params.size())return nullptr;*iter=(void *)(i+1);return (void *)method->params[i];}
char *typeName(void *t){return t?strdup((char *)t):nullptr;}
uint32_t methodFlags(dr::Method m,uint32_t *impl){*impl=0;return ((Signature *)m)->isStatic?16:0;}
dr::Method findMethod(Klass,const char *name,int n){if(!strcmp(name,"GetDelegateForFunctionPointer")&&n==2)return &thunk;if(!strcmp(name,"Invoke")&&n==0)return &callback;if(!strcmp(name,"add_onBeforeRender")&&n==1)return &addCallback;return nullptr;}
Klass parent(Klass){return nullptr;}
dr::Method findMethods(Klass,void **iter){dr::Method methods[]={&thunk,&callback,&addCallback,&decimalSingle,&decimalDouble};size_t i=(size_t)*iter;if(i>=5)return nullptr;*iter=(void *)(i+1);return methods[i];}
const char *methodName(dr::Method m){return m==&thunk?"GetDelegateForFunctionPointer":m==&callback?"Invoke":m==&addCallback?"add_onBeforeRender":"op_Explicit";}
Object invoke(dr::Method m,Object owner,void **args,Object *exception){invocations++;if(raiseManaged){*exception=(void *)1;return nullptr;}if(m==&thunk){check(!owner&&args&&args[0]&&args[1]==reflected,"managed reference argument is passed directly, not by address");memcpy(&captured,args[0],sizeof(captured));check(captured!=nullptr,"native IntPtr argument contains the actual callback address");return delegate;}if(m==&addCallback){check(!owner&&args&&args[0]==delegate,"original event receives the rooted callback object directly");return nullptr;}check(m==&callback&&owner==delegate&&!args,"zero-argument instance callback has no phantom parameter");return nullptr;}
void noop(){}
void domains(void (*visit)(void *,void *),void *arg){visit(root(),arg);}
void domainAssemblies(void *d,void (*visit)(void *,void *),void *arg){check(d==root(),"game domain chosen from exact original assembly identity");visit((void *)"Assembly-CSharp",arg);}
void *loaded(const char *name){return (void *)name;}
void *assemblyImage(void *assembly){return assembly;}
const char *guid(void *image){const char *name=(const char *)image;if(!strcmp(name,"Assembly-CSharp"))return DR_ASSEMBLY_MVID;if(!strcmp(name,"UnityEngine.CoreModule"))return "0f53f448-e779-4ef3-be38-7fd7af52f619";if(!strcmp(name,"mscorlib"))return "1fe4b731-1082-47d3-a7e5-7fad336611b9";return nullptr;}
void *attach(void *d){check(d==root(),"bootstrap attaches to actual game domain");return d;}
Klass findClass(void *,const char *,const char *name){return (void *)name;}
void *classType(Klass k){return k;}
Object typeObject(void *d,void *t){check(d==root()&&!strcmp((char *)t,"UnityAction"),"typeof delegate belongs to exact game domain");return reflected;}
int kind(void *t){if(!strcmp((char *)t,"System.Int32"))return 8;if(!strcmp((char *)t,"System.UInt32"))return 9;if(!strcmp((char *)t,"System.Single"))return 12;if(!strcmp((char *)t,"System.Decimal"))return 17;if(!strcmp((char *)t,"UnityEngine.CursorLockMode"))return 17;return 18;}
Klass fieldClassType(void *t){return t;}
int enumType(Klass k){return !strcmp((char *)k,"UnityEngine.CursorLockMode");}
void *enumBase(Klass){return (void *)"System.Int32";}
int valueSize(Klass k,uint32_t *alignment){*alignment=4;return !strcmp((char *)k,"System.Decimal")?16:1024;}
void *fieldType(Field f){return f;}
uint32_t fieldFlags(Field){return 0;}
void fieldRead(Object owner,Field field,void *out){check(owner==delegate,"synthetic instance owns the field");fieldReads++;memcpy(out,bytes.data(),size(field));}
void fieldWrite(Object owner,Field field,void *in){check(owner==delegate,"synthetic instance owns the field");fieldWrites++;memcpy(bytes.data(),in,size(field));}
uint32_t handle(Object owner,int){check(owner==delegate||owner==reflected,"only synthetic objects receive handles");rootHandles++;uint32_t id=nextHandle++;handles[id]=owner;return id;}
Object target(uint32_t h){check(handles.count(h)==1,"known handle only");return handles[h];}
void freeHandle(uint32_t h){check(handles.erase(h)==1,"known handle released");frees++;}
template<class F>void rejects(F work,const char *message){bool failed=false;try{work();}catch(const std::exception&){failed=true;}check(failed,message);}
}
int main(){@autoreleasepool{
 DREquipmentLeaseTests();
 check(!DRSupportedImage()&&!DRInFrame(),"unrelated test process never becomes a supported game or GameThread");
 check(!DREnqueue(^{check(false,"unsupported callback must never run");}),"queue rejects an unrelated executable before binding Mono");
 checkEarlyOverlay(0);
 api.root=root;api.domainGet=root;api.method=findMethod;api.methods=findMethods;api.methodName=methodName;api.parent=parent;api.signature=signature;api.paramCount=count;api.returnType=returnType;api.params=parameter;api.typeName=typeName;api.free=free;api.methodFlags=methodFlags;api.invoke=invoke;
 auto method=typedMethod((void *)1,"GetDelegateForFunctionPointer","System.Delegate",{"System.IntPtr","System.Type"},true);
 void *pointer=(void *)&noop;check(call(method,nullptr,{&pointer,reflected})==delegate&&captured==noop,"complete original delegate ABI preserves native callback and reflected type");
 check(typedMethod((void *)1,"Invoke","System.Void",{},false)==&callback,"UnityAction Invoke is exactly instance void with zero parameters");
 call(&callback,delegate);
 rejects([&]{call(&thunk,nullptr,{&pointer});},"truncated argument vector is rejected before native invocation");
 rejects([&]{call(&thunk,delegate,{&pointer,reflected});},"static/instance owner mismatch is rejected");
 rejects([&]{typedMethod((void *)1,"GetDelegateForFunctionPointer","System.Void",{"System.IntPtr","System.Type"},true);},"wrong delegate return type is rejected");
 rejects([&]{typedMethod((void *)1,"GetDelegateForFunctionPointer","System.Delegate",{"System.IntPtr","System.IntPtr"},true);},"wrong reference argument type is rejected");
 raiseManaged=true;rejects([&]{call(&callback,delegate);},"managed exceptions do not become fake success");raiseManaged=false;
 api.fieldType=fieldType;api.kind=kind;api.classFromType=fieldClassType;api.isEnum=enumType;api.enumBase=enumBase;api.valueSize=valueSize;api.flags=fieldFlags;api.read=fieldRead;api.write=fieldWrite;
 Field integer=(Field)"System.Int32",decimal=(Field)"System.Decimal",enumeration=(Field)"UnityEngine.CursorLockMode";
 check(size(decimal)==16&&size(enumeration)==4,"Decimal and enum use their actual native storage sizes");
 std::vector<uint8_t> value(16);for(size_t i=0;i<value.size();i++)value[i]=(uint8_t)(i+1);
 write(delegate,nullptr,decimal,value);check(read(delegate,nullptr,decimal)==value&&fieldReads==1&&fieldWrites==1,"complete Decimal bytes round-trip through the real typed field helper");
 rejects([&]{write(delegate,nullptr,decimal,std::vector<uint8_t>(8));},"truncated struct writes are rejected");
 rejects([&]{(void)size((Field)"System.Object");},"reference fields cannot enter the raw struct writer");
 rejects([&]{numeric(integer,std::numeric_limits<double>::infinity());},"nonfinite scalar is rejected");
 rejects([&]{numeric(integer,1.5);},"fractional integer is rejected");
 rejects([&]{numeric((Field)"System.UInt32",-1);},"unsigned underflow is rejected");
 api.strong=handle;api.weak=handle;api.target=target;api.freeHandle=freeHandle;
 {Root first(delegate),second;check(first.get()==delegate,"GC-rooted callback remains reachable");second=std::move(first);check(!first.handle&&second.get()==delegate,"delegate handle ownership is moved once");}
 check(rootHandles==1&&frees==1,"delegate handle is released exactly once");
 check(invocations==3,"invalid ABI attempts never reach mono_runtime_invoke");
 check(typedMethod((void *)1,"op_Explicit","System.Decimal",{"System.Double"},true)==&decimalDouble,"full overload resolver skips Single before the requested Double overload");
 api.domainID=domainId;api.domainByID=domainById;api.domains=domains;api.domainAssemblies=domainAssemblies;api.loaded=loaded;api.assemblyImage=assemblyImage;api.guid=guid;api.attach=attach;api.klass=findClass;api.classType=classType;api.typeObject=typeObject;
 __block NSUInteger jobs=0;
 check(DREnqueue(^{check(DRInFrame(),"queued work executes only inside original frame");jobs++;DRSetFrameHandler(^{throw std::runtime_error("synthetic effect failure");});}),"typed native bootstrap registers the real product frame callback");
 check(jobs==0&&!DRInFrame(),"registration does not execute gameplay on the bootstrap thread");
 check(captured&&captured!=noop,"delegate registration uses the actual product callback address");captured();
 check(jobs==1&&!DRInFrame(),"one callback drains one pending job and releases frame ownership");
 checkEarlyOverlay(1);
 check(DREnqueue(^{jobs++;DRSetFrameHandler(nil);}),"disable command can be queued after an effect failure");captured();
 check(jobs==2,"failed frame handler cannot strand a pending disable command");
 size_t callsBeforeIdle=invocations;captured();check(invocations==callsBeforeIdle,"idle native frame performs no managed metadata or gameplay calls");
 for(NSUInteger i=0;i<64;i++)check(DREnqueue(^{jobs++;}),"bounded queue accepts its documented capacity");
 check(!DREnqueue(^{jobs++;}),"queue overflow is rejected without executing work");captured();
 check(jobs==66&&[DRNativeObservation()[@"pending"] unsignedIntegerValue]==0,"accepted queue is drained exactly once");
 __block BOOL rejected=NO;
 check(DREnqueueChecked(^{check(false,"invalidated domain job must never execute");},^{check(!DRInFrame(),"rejection executes outside gameplay");rejected=YES;}),"queued native work retains an explicit rejection completion");
 alive=false;check(!DREnqueue(^{}),"ended domain prevents all new gameplay dispatch");
 NSDate *until=[NSDate dateWithTimeIntervalSinceNow:2];while(!rejected&&until.timeIntervalSinceNow>0)[NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.005]];
 check(rejected&&[DRNativeObservation()[@"invalidated"] boolValue]&&![DRNativeObservation()[@"callbackObserved"] boolValue],"domain invalidation clears observation and completes queued failures without stale handles");
 api={};MHTCheckRuntimeWindows();puts("PASS: DREDGE identity rejection, typed delegate/argument ABI, managed exception boundary, Decimal/enum field sizes, GC ownership, original-domain frame dispatch, idle path and failure-safe bounded queue. No games or original assemblies loaded.");
}return 0;}
