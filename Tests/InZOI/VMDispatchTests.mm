// SPDX-License-Identifier: GPL-3.0-only
// Exercises the actual observer and queue with fake Lua states/APIs only.
// No game image, original VM, interposition or runtime mod is installed.
#define IZ_LUA_ENGINE_TESTING 1
#define lua_pcallk IZFixturePCall
#define lua_close IZFixtureClose
#import "../../Modules/inzoi/Sources/LuaEngine.mm"
#undef lua_pcallk
#undef lua_close
#import <objc/runtime.h>
#include <cassert>
extern std::atomic<unsigned> IZFixtureOriginalCalls,IZFixtureCloses;
extern int IZFixtureResult;
struct lua_State {int top=0;unsigned environment=0;bool original=true,closed=false;const void *registry=nullptr;};
namespace {
std::atomic<unsigned> queries{0},registryGuards{0};
int printFunction(lua_State *){return 0;}
int foreignPrint(lua_State *){return 0;}
int gettop(lua_State *L){assert(!L->closed);return L->top;}
void settop(lua_State *L,int top){assert(!L->closed);L->top=top;}
int getglobal(lua_State *L,const char *name){assert(!L->closed&&!strcmp(name,"print"));queries++;L->top++;return 6;}
LuaFunction cfunction(lua_State *L,int){assert(!L->closed);return L->original?printFunction:foreignPrint;}
const char *upvalue(lua_State *L,int,int index){assert(!L->closed&&index==1);if(!L->environment)return nullptr;L->top++;return "environment";}
const char *text(lua_State *L,int,size_t *n){assert(!L->closed);*n=2;return L->environment==1?"B1":"B2";}
const void *registry(lua_State *L,int index){assert(!L->closed&&index==-1001000);registryGuards++;return L->registry ?: L;}
void observe(lua_State &L){int top=L.top;assert(observePCall(&L,0,0,0,0,nullptr)==IZFixtureResult);assert(L.top==top);}
void wait(dispatch_semaphore_t done){assert(dispatch_semaphore_wait(done,dispatch_time(DISPATCH_TIME_NOW,5*NSEC_PER_SEC))==0);}
void schedule(dispatch_block_t work,bool,NSArray *){work();}
BOOL gameThread(id,SEL){return YES;}
}
void IZStartRuntimeMod(){}
NSString *IZMissionDefinition(NSString *){return nil;}
int main(){@autoreleasepool{
 api.gettop=gettop;api.settop=settop;api.getglobal=getglobal;api.tocfunction=cfunction;api.getupvalue=upvalue;api.tolstring=text;api.topointer=registry;
 originalPrint=(uintptr_t)printFunction;enabled.store(true);
 lua_State view{3,1},sim{7,2},unknown{2,0};
 observe(view);assert(presentation.load()==&view);
 observe(sim);unsigned initialQueries=queries.load(),initialCalls=IZFixtureOriginalCalls.load();
 for(int i=0;i<20000;i++)observe(sim);
 assert(queries.load()==initialQueries&&IZFixtureOriginalCalls.load()==initialCalls+20000);
 // Pending work always forces a fresh original-environment check. B1 cannot
 // consume simulation work, and a changed print binding cannot impersonate B2.
 __block unsigned ran=0;lua_State *simState=&sim;
 IZOnSimulationThread(^{assert(IZIsSimulationThread()&&current==simState);ran++;});
 observe(view);assert(ran==0&&pendingReady.load());
 sim.original=false;observe(sim);assert(ran==0&&pendingReady.load());
 sim.original=true;observe(sim);assert(ran==1&&!pendingReady.load()&&pending.empty());
 // Queueing from another thread after the consumer swaps its batch must leave
 // the ready flag set, rather than lose the next batch behind an idle fast path.
 __block unsigned later=0;dispatch_semaphore_t produced=dispatch_semaphore_create(0);
 IZOnSimulationThread(^{
  [NSThread detachNewThreadWithBlock:^{IZOnSimulationThread(^{assert(IZIsSimulationThread());later++;});dispatch_semaphore_signal(produced);}];
  wait(produced);
 });
 observe(sim);assert(later==0&&pendingReady.load()&&pending.size()==1);
 observe(sim);assert(later==1&&!pendingReady.load());
 // The queue bound and immediate nested simulation work remain unchanged.
 __block unsigned bounded=0;
 for(int i=0;i<129;i++)IZOnSimulationThread(^{bounded++;IZOnSimulationThread(^{bounded++;});});
 assert(pending.size()==128);observe(sim);assert(bounded==256&&!pendingReady.load());
 // Unknown states keep retrying while the original environment is initialized.
 observe(unknown);unsigned before=queries.load();observe(unknown);assert(queries.load()>before);
 unknown.environment=2;observe(unknown);before=queries.load();observe(unknown);assert(queries.load()==before);
 // A new VM is discovered even while another presentation state is still live.
 lua_State replacement{1,1};observe(replacement);assert(presentation.load()==&replacement);
 // A collected coroutine can reuse an address without lua_close. A different
 // live VM has a different registry and must not inherit the idle observation.
 lua_State coroutine{6,2};coroutine.registry=(void *)0x1234;observe(coroutine);before=queries.load();
 coroutine.environment=1;coroutine.registry=(void *)0x5678;observe(coroutine);
 assert(queries.load()>before&&presentation.load()==&coroutine);
 observe(replacement);
 observeClose(&view);view.closed=true;assert(presentation.load()==&replacement);
 // Closing invalidates every thread's idle observation. Reusing the same VM
 // address for a different environment requires fresh detection.
 observe(sim);states[&sim]={-2,123};before=queries.load();
 observeClose(&sim);sim.closed=true;assert(!states.count(&sim));
 sim={4,1};observe(sim);assert(queries.load()>before&&presentation.load()==&sim);
 // A VM moving to another thread is not recognized from another thread's TLS.
 sim.environment=2;dispatch_semaphore_t moved=dispatch_semaphore_create(0);before=queries.load();
 [NSThread detachNewThreadWithBlock:^{@autoreleasepool{observe(*simState);dispatch_semaphore_signal(moved);}}];
 wait(moved);assert(queries.load()>before);
 // Presentation work also rechecks the original tag at its execution boundary,
 // even after an idle pcall was permitted to skip environment introspection.
 gameThreadCall=schedule;SEL selector=NSSelectorFromString(@"isGameThread");
 class_addMethod(object_getClass(NSThread.class),selector,(IMP)gameThread,"c@:");
 observe(replacement);__block bool viewReady=false;lua_State *replacementState=&replacement;
 IZOnPresentationThread(^{viewReady=current==replacementState&&currentEnvironment==1;});assert(viewReady);
 replacement.original=false;observe(replacement);__block bool rejected=false;
 IZOnPresentationThread(^{rejected=!current&&currentEnvironment==0;});assert(rejected);
 assert(!current&&!currentEnvironment&&!inside&&IZFixtureCloses.load()==2);
 puts("PASS: 20,000 idle pcalls without environment traversal; registry identity, new VM/thread, root close, coroutine address reuse, bounded queues, producer-during-drain and B1/B2 execution checks. Synthetic only; no game started.");
}}
