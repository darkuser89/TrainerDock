// SPDX-License-Identifier: GPL-3.0-only
#include "SaveGuard.hpp"
#import <Foundation/Foundation.h>
#include <mach/mach.h>
#include <mach/mach_vm.h>
#include <unistd.h>
#include <mutex>
#include <atomic>
#include <cmath>
#include <chrono>
#include <algorithm>
#include <stdexcept>
#include <cstring>
namespace {
struct Protection {std::vector<std::string> paths;uintptr_t health=0,mode=0;int deadMode=1;bool death=false;double expires=0;};
// Leaked process-lifetime storage avoids C++ destruction during engine teardown.
Protection& protection(){static auto p=new Protection;return *p;}
std::mutex& mutex(){static auto m=new std::mutex;return *m;}
std::atomic_uint64_t blocked{0};
double now(){return std::chrono::duration<double>(std::chrono::steady_clock::now().time_since_epoch()).count();}
bool dead(uintptr_t address){
 float health=0;mach_vm_size_t read=0;
 return address && mach_vm_read_overwrite(mach_task_self(),address,sizeof(health),(mach_vm_address_t)&health,&read)==KERN_SUCCESS && read==sizeof(health) && std::isfinite(health) && health<=0;
}
bool dead(const Protection& p){
 if(dead(p.health))return true;int mode=0;mach_vm_size_t count=0;
 return p.mode && mach_vm_read_overwrite(mach_task_self(),p.mode,sizeof(mode),(mach_vm_address_t)&mode,&count)==KERN_SUCCESS && count==sizeof(mode) && mode==p.deadMode;
}
std::string canonical(const char *path){
 if(!path || strnlen(path,4097)>4096)return {};
 NSString *s=[[NSString alloc] initWithUTF8String:path];
 if(!s || !s.isAbsolutePath)return {};
 return s.stringByStandardizingPath.stringByResolvingSymlinksInPath.fileSystemRepresentation ?: "";
}
bool preserve(const char *path){
 // No filesystem or Foundation work in the common, unarmed path.
 std::lock_guard<std::mutex> lock(mutex());auto &p=protection();if(p.paths.empty())return false;
 if(!p.death && dead(p)){p.death=true;p.expires=now()+120;}
 if(!p.death || now()>p.expires)return false;
 @autoreleasepool {auto file=canonical(path);if(file.empty() || std::find(p.paths.begin(),p.paths.end(),file)==p.paths.end())return false;}
 blocked.fetch_add(1);return true;
}
}
int TLDGuardedUnlink(const char *path){return preserve(path)?0:unlink(path);}
void TLDProtectSaves(const std::vector<std::string>& paths,uintptr_t healthAddress,uintptr_t modeAddress,int deadMode){
 std::vector<std::string> safe;
 for(auto &path:paths){auto file=canonical(path.c_str());if(file.empty() || file=="/" || file.size()<8)throw std::runtime_error("Invalid original save path");if(std::find(safe.begin(),safe.end(),file)==safe.end())safe.push_back(file);}
 if(safe.empty() || safe.size()>32 || !healthAddress)throw std::runtime_error("Original save guard scope missing");
 std::lock_guard<std::mutex> lock(mutex());auto &p=protection();
 if(p.paths!=safe || p.health!=healthAddress){p={std::move(safe),healthAddress,modeAddress,deadMode,false,0};}
}
void TLDObserveSaveGuard(){std::lock_guard<std::mutex> lock(mutex());auto &p=protection();if(!p.death && dead(p)){p.death=true;p.expires=now()+120;}}
void TLDReleaseSaveGuard(){TLDObserveSaveGuard();std::lock_guard<std::mutex> lock(mutex());auto &p=protection();if(p.death && now()<=p.expires){p.health=0;p.mode=0;}else p={};}
void TLDClearSaveGuard(){std::lock_guard<std::mutex> lock(mutex());protection()={};}
uint64_t TLDBlockedSaveDeletes(){return blocked.load();}
size_t TLDProtectedSaveCount(){std::lock_guard<std::mutex> lock(mutex());auto &p=protection();return p.death && now()>p.expires?0:p.paths.size();}
__attribute__((used,section("__DATA,__interpose"))) static const struct {const void *replacement,*original;} interpose[]={
 {(const void *)TLDGuardedUnlink,(const void *)unlink}
};
