// SPDX-License-Identifier: GPL-3.0-only
// Exercises the real startup gate in a non-game process. No fixture enters a product.
#import "StrayEngine.hpp"
#import <objc/runtime.h>
#include <atomic>
namespace {
std::atomic<unsigned> identityQueries{0};
NSString *fixtureIdentity(id,SEL){identityQueries++;return @"local.trainerdock.stray.bootstrap-fixture";}
void check(bool ok,const char *why){if(!ok){fprintf(stderr,"FAIL: %s\n",why);exit(1);}}
}
int main(){@autoreleasepool{
 check(NSThread.isMainThread&&!st::isBound(),"bootstrap begins on main without a game binding");
 Method method=class_getInstanceMethod(NSBundle.class,@selector(bundleIdentifier));
 IMP original=method_setImplementation(method,(IMP)fixtureIdentity);
 __block bool executed=false;
 bool accepted=st::onGameThread(^{executed=true;});
 unsigned afterMain=identityQueries.load();
 check(afterMain>0,"main-thread scheduling attempts exact-build binding before rejecting");
 check(!accepted&&!executed&&!st::isBound(),"a rejected identity never executes a game-thread fallback");
 __block bool backgroundAccepted=true,wasMain=true;
 __block unsigned beforeBackground=0,afterBackground=0;
 dispatch_semaphore_t done=dispatch_semaphore_create(0);
 [NSThread detachNewThreadWithBlock:^{@autoreleasepool{
  wasMain=NSThread.isMainThread;beforeBackground=identityQueries.load();
  backgroundAccepted=st::onGameThread(^{executed=true;});
  afterBackground=identityQueries.load();dispatch_semaphore_signal(done);
 }}];
 check(dispatch_semaphore_wait(done,dispatch_time(DISPATCH_TIME_NOW,5*NSEC_PER_SEC))==0,"background thread completes without main-thread work");
 check(!wasMain&&afterBackground==beforeBackground,"background scheduling never attempts main-thread binding");
 check(!backgroundAccepted&&!executed&&!st::isBound(),"background scheduling cannot masquerade as the original GameThread");
 unsigned beforeRetry=identityQueries.load();accepted=st::onGameThread(^{executed=true;});
 check(identityQueries.load()>beforeRetry&&!accepted&&!executed,"later main-thread startup polls retry safely");
 method_setImplementation(method,original);
 puts("PASS: actual startup binding retry, main-thread-only identity checks and no fallback execution. No game started.");
}}
