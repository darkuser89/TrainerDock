// SPDX-License-Identifier: GPL-3.0-only
// Synthetic ABI memory fixtures exist only in this test translation unit.
// Include the real implementation so its private cache and native-binding seams
// can be exercised without exporting test hooks or loading any game library.
#import "../../Modules/frostpunk-2/Sources/Unreal.mm"
#include <cassert>
#include <iostream>
namespace fixture {
std::map<uintptr_t,std::vector<uint8_t>> memory;
std::map<int32_t,uintptr_t> objects;
std::map<int32_t,int32_t> serials;
constexpr uintptr_t chunks=0x500000000ULL,items=0x500001000ULL,names=0x500002000ULL;
constexpr uintptr_t metaClass=0x500010000ULL,ownerClass=0x500011000ULL,functionClass=0x500012000ULL;
constexpr uintptr_t instance=0x500013000ULL,functionA=0x500014000ULL,functionB=0x500015000ULL;
constexpr uintptr_t fieldClass=0x500020000ULL,fieldA=0x500030000ULL,fieldB=0x500031000ULL;
size_t nameCursor=2,nameReads=0;
void block(uintptr_t p,size_t size){memory[p]=std::vector<uint8_t>(size);}
bool copy(uintptr_t p,void *out,size_t n){auto i=memory.upper_bound(p);if(i==memory.begin())return false;--i;if(p<i->first||p-i->first>i->second.size()||n>i->second.size()-(p-i->first))return false;if(p>=names&&p<names+4096)nameReads++;memcpy(out,i->second.data()+p-i->first,n);return true;}
template<class T>void put(uintptr_t p,T value){auto i=memory.upper_bound(p);assert(i!=memory.begin());--i;assert(p>=i->first&&p-i->first+sizeof(T)<=i->second.size());memcpy(i->second.data()+p-i->first,&value,sizeof(T));}
uint64_t fname(const char *s){size_t n=strlen(s),at=nameCursor;assert(at+2+n<4096);put<uint16_t>(names+at,(uint16_t)(n<<6));for(size_t i=0;i<n;i++)put<uint8_t>(names+at+2+i,s[i]);nameCursor=(at+2+n+1)&~size_t(1);return at/2;}
void object(int index,uintptr_t p,uintptr_t cls,const char *name){block(p,0x200);objects[index]=p;serials[index]=100+index;put<uintptr_t>(items+index*20,p);put<int32_t>(items+index*20+16,serials[index]);put<int32_t>(p+12,index);put<uintptr_t>(p+16,cls);put<uint64_t>(p+24,fname(name));}
BOOL gameThread(id,SEL){return YES;}
void assign(FP2WeakObject *w,const void *p){int32_t index=0;assert(copy((uintptr_t)p+12,&index,4));w->index=index;w->serial=serials.at(index);}
void *get(const FP2WeakObject *w){auto s=serials.find(w->index);auto o=objects.find(w->index);return s!=serials.end()&&o!=objects.end()&&s->second==w->serial?(void*)o->second:nullptr;}
void property(uintptr_t p,const char *name,int32_t offset,uintptr_t next){block(p,0x80);put<uintptr_t>(p+8,fieldClass);put<uintptr_t>(p+16,ownerClass|1);put<uintptr_t>(p+24,next);put<uint64_t>(p+32,fname(name));put<int32_t>(p+44,1);put<int32_t>(p+48,4);put<int32_t>(p+68,offset);}
void setup(){
 block(FP2ObjectArrayAddress,0x100);block(FP2UnreachableMaskAddress,4);block(chunks,8);block(items,20*16);block(FP2NamePoolInitializedAddress,1);block(FP2NamePoolAddress,0x200);block(names,4096);
 put<uintptr_t>(FP2ObjectArrayAddress+16,chunks);put<int32_t>(FP2ObjectArrayAddress+36,16);put<uintptr_t>(chunks,items);put<uint8_t>(FP2NamePoolInitializedAddress,1);put<uintptr_t>(FP2NamePoolAddress+0xd0,names);
 object(0,metaClass,metaClass,"Class");object(1,ownerClass,metaClass,"FixtureOwner");object(2,functionClass,metaClass,"Function");object(3,instance,ownerClass,"FixtureInstance");object(4,functionA,functionClass,"Run");object(5,functionB,functionClass,"Run");
 put<uintptr_t>(functionA+32,ownerClass);put<uintptr_t>(functionB+32,ownerClass);put<uintptr_t>(ownerClass+72,functionA);
 block(fieldClass,0x40);put<uint64_t>(fieldClass,fname("IntProperty"));property(fieldA,"Value",0x80,fieldB);property(fieldB,"Other",0x84,0);put<uintptr_t>(ownerClass+80,fieldA);put<int32_t>(instance+0x80,7);put<int32_t>(instance+0x84,11);
 fp::slide=0;fp::assignFn=assign;fp::getFn=get;fp::threadFn=gameThread;fp::bound.store(true);
}
template<class F>void rejected(F f){bool threw=false;try{f();}catch(const std::runtime_error &){threw=true;}assert(threw);}
}
extern "C" BOOL MTReadMemory(const void *p,void *out,size_t n){return fixture::copy((uintptr_t)p,out,n);}
extern "C" BOOL MTWriteMemory(void *,const void *,size_t){return NO;}
int main(){@autoreleasepool{
 using namespace fixture;setup();fp::Object o{instance};
 nameReads=0;auto p=fp::property(o,@"Value");assert([fp::readValue(o,p) intValue]==7);size_t cold=nameReads;assert(cold>0);
 nameReads=0;auto warm=fp::property(o,@"Value");assert([fp::readValue(o,warm) intValue]==7);assert(nameReads==0);
 // Native values are not cached, even when their metadata is cached.
 put<int32_t>(instance+0x80,19);assert([fp::readValue(o,warm) intValue]==19);
 auto other=fp::property(o,@"Other");assert([fp::readValue(o,other) intValue]==11);
 // Interior list edits must invalidate cached reachability with an unchanged head.
 put<uintptr_t>(fieldA+24,0);rejected([&]{fp::property(o,@"Other");});rejected([&]{fp::property(o,@"Other");});
 put<uintptr_t>(fieldA+24,fieldB);assert(fp::property(o,@"Other").address==fieldB);
 // Reusing an owner's index AND address with a new serial must not resurrect old
 // field descriptors. Fresh metadata at that same address is resolved anew.
 auto old=fp::property(o,@"Value");serials[1]++;put<int32_t>(items+20+16,serials[1]);put<int32_t>(fieldA+68,0x84);
 rejected([&]{fp::readValue(o,old);});auto replacement=fp::property(o,@"Value");assert(replacement.offset==0x84);assert([fp::readValue(o,replacement) intValue]==11);
 assert(fp::function(o,@"Run").address==functionA);nameReads=0;assert(fp::function(o,@"Run").address==functionA);assert(nameReads==0);
 // An interior function can be renamed without changing the class head. The
 // cached result must observe changed predecessor identity and search again.
 put<uint64_t>(functionA+24,fname("Other"));put<uintptr_t>(functionA+40,functionB);
 assert(fp::function(o,@"Run").address==functionB);
 put<uint64_t>(functionA+24,fname("Run"));assert(fp::function(o,@"Run").address==functionA);
 // An expired UFunction is rejected even while its class and list head survive.
 objects.erase(4);put<uintptr_t>(items+4*20,0);rejected([&]{fp::function(o,@"Run");});
 put<uintptr_t>(ownerClass+72,functionB);assert(fp::function(o,@"Run").address==functionB);
 // A dead class rejects its cached functions before dereferencing descriptors.
 objects.erase(1);put<uintptr_t>(items+20,0);rejected([&]{fp::function(o,@"Run");});
 std::cout<<"Reflection metadata caches: cold/warm reuse, fresh values, chain edits, owner serial replacement and expired UFunction/class passed.\n";
}}
