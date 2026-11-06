// SPDX-License-Identifier: GPL-3.0-only
#import "ControlEngine.h"
#import <AppKit/AppKit.h>
#include <mach/mach.h>
#include <mach/mach_vm.h>
#include <mach-o/dyld.h>
#include <mach-o/loader.h>
#include <dlfcn.h>
#include <cxxabi.h>
#include <mutex>
#include <vector>
#include <atomic>
#include <cmath>
static uintptr_t mainImage,coreImage;
static bool inputImage,aiImage,resourceImage;
static unsigned store; // 1 Steam, 2 MAS 1.33.1, 3 MAS 1.371; zero is unsupported.
struct NativeAddress {uintptr_t steam,mas,mas1371;bool core;};
static constexpr NativeAddress addresses[MHTControlSymbolCount]={
 // Both exported value pins use a connection handle at +8. The native MAS
 // GameInventory::setInfiniteAmmo tails into 0x1036c in MAS 1.33.1,
 // and 0xad38 in MAS 1.371. The old 0x20efc belongs
 // to a different signal-pin layout and must not receive the ammo value pin.
 {0xad9c,0x1036c,0xad38,false},{0xad9c,0x1036c,0xad38,false},
 {0xe094a8,0xf55468,0xde55a0,false},{0xdd0438,0xf1c3f8,0xdac478,false},
 {0xe0a6e0,0xf566a0,0xde67d8,false},{0xe2f748,0xf7b708,0xe0b858,false},
 {0xe2c698,0xf78658,0xe087a8,false},{0xe224a0,0xf6e460,0xdfe5c0,false},
 {0xdd73e8,0xf233a8,0xdb3458,false},{0xe190e8,0xf650a8,0xdf51f0,false},
 {0xe1e900,0xf6a8c0,0xdfaa08,false},{0xe0de70,0xf59e30,0xde9f68,false},
 {0x57897c,0x642c90,0x5703a8,false},{0x4c0ef8,0x582ff0,0x4bbddc,false},
 {0x605be8,0x6df7c4,0x5fd80c,false},{0xe6fd00,0xfbc200,0xe4bd00,false},
 {0xb85dd8,0xcf5dd8,0xc95dd8,true},{0x19c478,0x1d536c,0x19e9e0,true},
 {0x2c0c10,0x322140,0x2c3da4,true},{0xb85960,0xcf5960,0xc95960,true},
 {0x19f1e0,0x1d81a0,0x1a16b4,true}
};
static std::once_flag initialized;
static std::mutex queueLock;
static NSMutableArray *queue;
static dispatch_block_t maintenance;
#if defined(MHT_CONTROL_TESTING)
static dispatch_block_t testObserver;
void MHTControlSetTestObserver(dispatch_block_t work){std::lock_guard<std::mutex> lock(queueLock);testObserver=[work copy];}
#endif
static thread_local bool onFrame;
static thread_local void *currentServer;
static std::atomic<float> simulationRate{1.f};
BOOL MHTControlSetSimulationRate(float rate){if(!onFrame||!MHTControlEngineIdentity()||!std::isfinite(rate)||rate<.1f||rate>1)return NO;simulationRate=rate;return YES;}
float MHTControlSimulationRate(void){return simulationRate.load();}
struct Hook {void *owner;void **before;void (*update)(void*,float);std::vector<void*> storage;};
// A server is normally process-long. Keep installed tables alive until process exit.
static std::vector<Hook*> hooks;
static std::mutex hooksLock;
BOOL MHTControlRead(uintptr_t p,void *value,size_t n){if(!value||!n||p<0x10000||p>UINTPTR_MAX-n)return NO;mach_vm_size_t done=0;return mach_vm_read_overwrite(mach_task_self(),p,n,(mach_vm_address_t)value,&done)==KERN_SUCCESS&&done==n;}
BOOL MHTControlWrite(uintptr_t p,const void *v,size_t n){if(!v||!n||p<0x10000||p>UINTPTR_MAX-n)return NO;mach_vm_address_t a=p;mach_vm_size_t size=0;vm_region_basic_info_data_64_t info={};mach_msg_type_number_t count=VM_REGION_BASIC_INFO_COUNT_64;mach_port_t object=0;auto k=mach_vm_region(mach_task_self(),&a,&size,VM_REGION_BASIC_INFO_64,(vm_region_info_t)&info,&count,&object);if(object)mach_port_deallocate(mach_task_self(),object);if(k||p<a||n>size||p-a>size-n||!(info.protection&VM_PROT_WRITE)||(info.protection&VM_PROT_EXECUTE))return NO;memcpy((void*)p,v,n);return YES;}
template<class T>static T read(uintptr_t p){T v{};MHTControlRead(p,&v,sizeof(v));return v;}
NSString *MHTControlType(uintptr_t p){uintptr_t vt=read<uintptr_t>(p),ti=read<uintptr_t>(vt-8),nm=read<uintptr_t>(ti+8);char s[256]={};if(!MHTControlRead(nm,s,255))return @"";int status=0;char *out=abi::__cxa_demangle(s,nullptr,nullptr,&status);NSString *name=[NSString stringWithUTF8String:out?:s]?:@"";free(out);return name;}
static NSString *imageUUID(const mach_header_64 *h){if(!h||h->magic!=MH_MAGIC_64)return @"";const auto *cmd=(const load_command*)(h+1);for(uint32_t i=0;i<h->ncmds;i++){if(cmd->cmdsize<sizeof(load_command))return @"";if(cmd->cmd==LC_UUID)return [[NSUUID alloc]initWithUUIDBytes:((const uuid_command*)cmd)->uuid].UUIDString;cmd=(const load_command*)((const char*)cmd+cmd->cmdsize);}return @"";}
static void identify(){
 const char * const ids[3][5]={
  {"CF65DC88-F5CE-38A4-8A2A-21FD5F43F14B","741C61A5-962D-33AA-9AC7-06713AFFC389","874502E0-38B5-3CD6-BC43-1851C0DB2F24","1075C229-C5E9-35F1-8BE4-8FBAFD338ACF","59D60AC7-B0AB-352C-ABC1-1B7F093CAD23"},
  {"CF9FCD9D-B85A-3AB7-8C3E-55A060D8B260","77290B03-8E1E-3393-973C-F1B8C649B9E2","CC875566-567B-39C0-9421-EEEEF98E909B","810DD75C-7BFA-31CD-AE90-393FC09132A4","86B9E9C0-7C6E-3A12-8920-9EC12D5F2F41"},
  {"DB36B7EC-1D93-3FF4-9737-46E9D6F7082F","4A3DF4E6-269E-3603-BFE3-62017FE33B4B","459E81A6-E3B5-347B-A287-94247A678E4D","D6074A0B-5B60-3C32-8A64-0EB4D8A680D7","8F10F489-537E-3D64-A8D9-406C50C534B1"}
 };
 for(uint32_t i=0;i<_dyld_image_count();i++){
  const auto *h=(const mach_header_64*)_dyld_get_image_header(i);if(!h||h->filetype!=MH_EXECUTE)continue;
  NSString *uuid=imageUUID(h);
  for(unsigned variant=0;variant<3;variant++)if([uuid isEqual:@(ids[variant][0])]){store=variant+1;mainImage=(uintptr_t)h;}
 }
 if(!store)return;
 NSString *bundle=store==1?@"com.remedygames.control-ue-steam":@"com.remedygames.control-ue";
 if(![NSBundle.mainBundle.bundleIdentifier isEqual:bundle]){store=0;mainImage=0;return;}
 for(uint32_t i=0;i<_dyld_image_count();i++){
  const auto *h=(const mach_header_64*)_dyld_get_image_header(i);NSString *uuid=imageUUID(h),*name=@(_dyld_get_image_name(i)).lastPathComponent;
  if([name isEqual:@"coregame.dylib"]&&[uuid isEqual:@(ids[store-1][1])])coreImage=(uintptr_t)h;
  if([name isEqual:@"app.dylib"]&&[uuid isEqual:@(ids[store-1][2])])inputImage=true;
  if([name isEqual:@"bonsai.dylib"]&&[uuid isEqual:@(ids[store-1][3])])aiImage=true;
  if([name isEqual:@"rl.dylib"]&&[uuid isEqual:@(ids[store-1][4])])resourceImage=true;
 }
}
BOOL MHTControlEngineIdentity(void){std::call_once(initialized,identify);return mainImage&&coreImage&&inputImage&&aiImage&&resourceImage;}
uintptr_t MHTControlMainImage(void){return MHTControlEngineIdentity()?mainImage:0;}
uintptr_t MHTControlCoreImage(void){return MHTControlEngineIdentity()?coreImage:0;}
uintptr_t MHTControlAddress(MHTControlSymbol symbol){if(!MHTControlEngineIdentity()||symbol>=MHTControlSymbolCount)return 0;const NativeAddress &a=addresses[symbol];return (a.core?coreImage:mainImage)+(store==1?a.steam:store==2?a.mas:a.mas1371);}
NSString *MHTControlBuildLabel(void){return !MHTControlEngineIdentity()?@"Control · nicht unterstützt":store==1?@"Control Steam 1.34":store==2?@"Control Mac App Store 1.33.1":@"Control Mac App Store 1.371";}
BOOL MHTControlOnEngineFrame(void){return onFrame;}
void *MHTControlServer(void){return onFrame?currentServer:nullptr;}
static void drain(void *server){@autoreleasepool{onFrame=true;currentServer=server;NSArray *jobs;dispatch_block_t frameWork;
#if defined(MHT_CONTROL_TESTING)
dispatch_block_t observer;
#endif
{std::lock_guard<std::mutex> lock(queueLock);jobs=[queue copy];[queue removeAllObjects];frameWork=[maintenance copy];
#if defined(MHT_CONTROL_TESTING)
observer=[testObserver copy];
#endif
}for(dispatch_block_t work in jobs)work();if(frameWork)frameWork();
#if defined(MHT_CONTROL_TESTING)
if(observer)observer();
#endif
currentServer=nullptr;onFrame=false;}}
#if defined(MHT_CONTROL_TESTING)
void MHTControlExternalFrame(uintptr_t main,uintptr_t core,void *server){if(MHTControlEngineIdentity()&&main==mainImage&&core==coreImage&&[MHTControlType((uintptr_t)server)isEqual:@"GameServer"])drain(server);}
#endif
static void hookedUpdate(void *server,float dt){Hook *h=nullptr;{std::lock_guard<std::mutex> lock(hooksLock);for(Hook *entry:hooks)if(entry->owner==server){h=entry;break;}}if(!h)return;h->update(server,dt*simulationRate.load());drain(server);}
static void install(){std::lock_guard<std::mutex> lock(hooksLock);if(!MHTControlEngineIdentity()||hooks.size()>=8)return;uintptr_t runner=read<uintptr_t>(MHTControlAddress(MHTControlRunner));uintptr_t server=read<uintptr_t>(runner+0x10),vt=read<uintptr_t>(server);if(!server||![MHTControlType(server)isEqual:@"GameServer"])return;for(Hook *h:hooks)if(h->owner==(void*)server)return;
 // The pinned GameServer has exactly ten primary slots; slot seven is update(float).
 // No text pages or original files are patched.
 if(vt!=MHTControlAddress(MHTControlServerVT))return;
 Hook *h=new Hook{(void*)server,(void**)vt,nullptr,{}};h->storage.resize(12);
 if(!MHTControlRead(vt-16,h->storage.data(),96)){delete h;return;}
 h->update=(void(*)(void*,float))h->storage[9];if((uintptr_t)h->update!=MHTControlAddress(MHTControlServerUpdate)){delete h;return;}h->storage[9]=(void*)&hookedUpdate;
 hooks.push_back(h);void **expected=h->before;if(!__atomic_compare_exchange_n((void***)server,&expected,h->storage.data()+2,false,__ATOMIC_RELEASE,__ATOMIC_RELAXED)){hooks.pop_back();delete h;}
}
void MHTControlSetMaintenance(dispatch_block_t work){std::lock_guard<std::mutex> lock(queueLock);maintenance=[work copy];}
void MHTControlSchedule(dispatch_block_t work){if(!work)return;if(onFrame){work();return;}if(!MHTControlEngineIdentity()){dispatch_async(dispatch_get_main_queue(),work);return;}{std::lock_guard<std::mutex> lock(queueLock);if(!queue)queue=[NSMutableArray new];[queue addObject:[work copy]];}
 static dispatch_once_t once;dispatch_once(&once,^{
#if defined(MHT_CONTROL_TESTING)
if([NSProcessInfo.processInfo.environment[@"MHT_CONTROL_PROBE"]isEqual:@"1"]&&![NSProcessInfo.processInfo.environment[@"MHT_CONTROL_DIRECT"]isEqual:@"1"])return;
#endif
dispatch_async(dispatch_get_main_queue(),^{[NSTimer scheduledTimerWithTimeInterval:.25 repeats:YES block:^(NSTimer *t){(void)t;install();}];install();});});
}
