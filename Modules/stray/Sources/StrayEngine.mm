// SPDX-License-Identifier: GPL-3.0-only
#import "StrayEngine.hpp"
#import "StrayFieldSearch.hpp"
#import "StrayMetadataGuard.hpp"
#import <AppKit/AppKit.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <objc/message.h>
extern "C" {
#import "MemoryAccess.h"
}
#include <atomic>
#include <cmath>
#include <cstring>
#include <set>
#include <limits>
#include <map>
#include <string>
namespace st {
namespace {
std::atomic<bool> ready{false};intptr_t slide=0;
using Schedule=void(*)(dispatch_block_t,NSArray *,bool);
using WeakAssign=void(*)(Weak *,const void *);using WeakGet=void *(*)(const Weak *);
Schedule schedule=nullptr;WeakAssign assign=nullptr;WeakGet weakGet=nullptr;
[[noreturn]]void fail(const char *why){throw std::runtime_error(why);}
void requireThread(){if(!isGameThread())fail("Der originale Spielthread ist nicht bestätigt.");}
uintptr_t add(uintptr_t a,size_t n){if(a<4096||n>UINTPTR_MAX-a)fail("Ungültiger nativer Zeiger.");return a+n;}
void validate(Object o){if(!o||object(read<int32_t>(add(o.address,0xc)))!=o)fail("Der native Objektbesitzer ist abgelaufen.");}
bool matches(NSString *s,NSString *filter){return !filter.length||[s rangeOfString:filter options:NSCaseInsensitiveSearch].location!=NSNotFound;}
struct Entry {const char *name;uintptr_t address;uint8_t prefix[16];};
// Every code entry is bound to its original UUID and prologue, never another game.
#include "StrayBindings.inc"
Property describe(uintptr_t at,Object owner){
 Property p;p.address=at;p.ownerClass=owner;p.ownerWeak=Weak(owner);p.name=fname(add(at,0x28));p.type=fname(read<uintptr_t>(add(at,8)));
 p.count=read<int32_t>(add(at,0x34));p.size=read<int32_t>(add(at,0x38));p.flags=read<uint64_t>(add(at,0x40));p.offset=read<int32_t>(add(at,0x4c));
 if(p.count<1||p.count>65536||p.size<1||p.size>65536||p.offset<0||p.offset>1048576)fail("Die nativen Feldgrenzen sind ungültig.");
 if([p.type isEqual:@"BoolProperty"]){uint8_t b[4];if(!read(add(at,0x78),b,4)||b[0]!=1||b[1]>=p.size||!b[2]||(b[2]&(b[2]-1))||!b[3]||(b[3]!=255&&b[3]!=b[2]))fail("Das ursprüngliche Bool-Format stimmt nicht überein.");p.boolByteOffset=b[1];p.boolMask=b[3];}
 if([p.type isEqual:@"ObjectProperty"]){p.objectClass={read<uintptr_t>(add(at,0x78))};validate(p.objectClass);}
 return p;
}
bool same(const Property &a,const Property &b){return a.address==b.address&&a.ownerClass==b.ownerClass&&a.offset==b.offset&&a.size==b.size&&a.count==b.count&&a.flags==b.flags&&[a.name isEqual:b.name]&&[a.type isEqual:b.type]&&a.boolByteOffset==b.boolByteOffset&&a.boolMask==b.boolMask&&a.objectClass==b.objectClass;}
bool memoryRead(uintptr_t at,void *out,size_t n){return read(at,out,n);}
struct CachedProperty {
 Property value;detail::MetadataGuard<0x50> descriptor;detail::MetadataGuard<8> fieldType,extra;Weak objectType;
 bool current()const{return descriptor.matches(memoryRead)&&fieldType.matches(memoryRead)&&(!extra.address||extra.matches(memoryRead))&&(!value.objectClass||objectType.get()==value.objectClass);}
};
struct CachedStructure {
 Object owner;Weak weak;detail::MetadataGuard<24> heads;Object super;
 std::vector<CachedProperty> values;std::map<std::string,size_t> names;
 bool current()const{return weak.get()==owner&&heads.matches(memoryRead);}
};
std::map<uintptr_t,CachedStructure> structures;
CachedStructure &metadata(Object owner){
 auto key=owner.address;auto found=structures.find(key);
 if(found!=structures.end()&&found->second.current())return found->second;
 if(found!=structures.end())structures.erase(found);
 CachedStructure item;item.owner=owner;item.weak=Weak(owner);
 if(!item.heads.capture(owner.address+0x40,memoryRead))fail("Die nativen Metadatenköpfe sind unlesbar.");
 memcpy(&item.super.address,item.heads.expected.data(),8);uintptr_t at=0;memcpy(&at,item.heads.expected.data()+16,8);std::set<uintptr_t> seen;
 for(size_t n=0;at;n++){
  if(n>=2048||!seen.insert(at).second)fail("Zyklische native Feldliste.");
  CachedProperty field;field.value=describe(at,owner);
  if(!field.descriptor.capture(at,memoryRead)||!field.fieldType.capture(read<uintptr_t>(at+8),memoryRead))fail("Die nativen Felddeskriptoren sind unlesbar.");
  if([field.value.type isEqual:@"BoolProperty"]||field.value.objectClass)if(!field.extra.capture(at+0x78,memoryRead))fail("Die native Feldzuordnung ist unlesbar.");
  if(field.value.objectClass)field.objectType=Weak(field.value.objectClass);
  std::string name(field.value.name.UTF8String);if(!item.names.emplace(name,item.values.size()).second)fail("Mehrdeutige native Feldnamen.");
  item.values.push_back(field);memcpy(&at,field.descriptor.expected.data()+0x20,8);
 }
 // Cache size is bounded and stores no live gameplay values or object owners.
 if(structures.size()>=256)structures.clear();return structures.emplace(key,std::move(item)).first->second;
}
struct ClassGuard {Object owner;Weak weak;detail::MetadataGuard<24> heads;bool current()const{return weak.get()==owner&&heads.matches(memoryRead);}};
struct CachedFunction {Object value;Weak weak;detail::MetadataGuard<32> identity;std::vector<ClassGuard> path;bool current()const{if(weak.get()!=value||!identity.matches(memoryRead))return false;for(const auto &c:path)if(!c.current())return false;return true;}};
std::map<std::pair<uintptr_t,std::string>,CachedFunction> functions;
std::map<uint64_t,NSString *> names;
void verify(Object owner,const Property &p){
 validate(owner);if(!p.name.length||p.ownerWeak.get()!=p.ownerClass||!isA(owner,p.ownerClass))fail("Die ursprüngliche Feldzuordnung hat gewechselt.");
 // Verify the exact declaring owner, without repeating the caller's complete
 // derived-class search. Weak serial, descriptor and field type still match.
 auto &entry=metadata(p.ownerClass);auto hit=entry.names.find(std::string(p.name.UTF8String));
 if(hit==entry.names.end())fail("Das ursprüngliche Feld fehlt beim Besitzer.");const auto &field=entry.values[hit->second];
 if(!field.current()||!same(p,field.value)||p.ownerWeak.index!=entry.weak.index||p.ownerWeak.serial!=entry.weak.serial)fail("Der ursprüngliche Felddeskriptor hat gewechselt.");
}
bool numeric(const Property &p){return [@[@"BoolProperty",@"FloatProperty",@"DoubleProperty",@"ByteProperty",@"EnumProperty",@"Int8Property",@"Int16Property",@"UInt16Property",@"IntProperty",@"UInt32Property",@"Int64Property",@"UInt64Property"] containsObject:p.type];}
bool pack(const Property &p,id value,uint8_t *out,size_t n){
 if(p.count!=1||p.offset<0||p.size<1||(size_t)p.offset>n||(size_t)p.size>n-p.offset)return false;uint8_t *dest=out+p.offset;
 if([p.type isEqual:@"ObjectProperty"]){if(p.size!=8)return false;uintptr_t ptr=0;if(value!=NSNull.null){if(![value isKindOfClass:NSDictionary.class]||[value count]!=1||![value[@"object"] isKindOfClass:NSNumber.class])return false;double i=[value[@"object"] doubleValue];if(!std::isfinite(i)||std::floor(i)!=i||i<0||i>INT32_MAX)return false;Object o=object((int32_t)i);if(!isA(o,p.objectClass))return false;ptr=o.address;}memcpy(dest,&ptr,8);return true;}
 if([p.type isEqual:@"NameProperty"]){
  if(p.size!=8||![value isKindOfClass:NSString.class]||![value length]||[value length]>128)return false;
  NSData *ascii=[value dataUsingEncoding:NSASCIIStringEncoding];if(!ascii||ascii.length!=[value length]||memchr(ascii.bytes,0,ascii.length))return false;
  uint64_t name=0;((void(*)(uint64_t *,const char *,int))binding("makeName"))(&name,[value UTF8String],1);
  if(![fname((uintptr_t)&name) isEqual:value])return false;memcpy(dest,&name,8);return true;
 }
 if(!numeric(p)||![value isKindOfClass:NSNumber.class])return false;
 double d=[value doubleValue];if(!std::isfinite(d))return false;
 if([p.type isEqual:@"BoolProperty"]){if((d!=0&&d!=1)||!p.boolMask||p.boolByteOffset>=p.size)return false;dest[p.boolByteOffset]=(dest[p.boolByteOffset]&~p.boolMask)|(d?(p.boolMask==255?1:p.boolMask):0);return true;}
 if([p.type isEqual:@"FloatProperty"]&&p.size==4){if(std::abs(d)>std::numeric_limits<float>::max())return false;float f=(float)d;memcpy(dest,&f,4);return true;}
 if([p.type isEqual:@"DoubleProperty"]&&p.size==8){memcpy(dest,&d,8);return true;}
 int bits=8*p.size;if(bits!=8&&bits!=16&&bits!=32&&bits!=64)return false;
 bool sign=[p.type hasPrefix:@"Int"];
 const char *s=[[value stringValue] UTF8String];char *end=nullptr;errno=0;
 uint64_t raw=0;if(sign){long long v=strtoll(s,&end,10);if(errno||!end||*end||(bits<64&&(v<-(1LL<<(bits-1))||v>((1LL<<(bits-1))-1))))return false;raw=(uint64_t)v;}
 else{if(!s||*s=='-')return false;raw=strtoull(s,&end,10);if(errno||!end||*end||(bits<64&&raw>((1ULL<<bits)-1)))return false;}
 memcpy(dest,&raw,p.size);return true;
}
id unpack(const Property &p,const uint8_t *bytes,size_t n){
 if(p.count!=1||p.offset<0||p.size<1||(size_t)p.offset>n||(size_t)p.size>(size_t)n-(size_t)p.offset)fail("Der native Rückgabewert liegt außerhalb seiner Grenzen.");const uint8_t *v=bytes+p.offset;
 if([p.type isEqual:@"ObjectProperty"]){if(p.size!=8)fail("Ungültiger Objektparameter.");uintptr_t ptr=0;memcpy(&ptr,v,8);if(!ptr)return NSNull.null;Object o{ptr};validate(o);if(!isA(o,p.objectClass))fail("Die native Objektklasse stimmt nicht überein.");return @{@"object":@(read<int32_t>(ptr+0xc))};}
 if([p.type isEqual:@"BoolProperty"]){if(p.boolByteOffset>=p.size)fail("Ungültiger Bool-Rückgabewert.");return @((v[p.boolByteOffset]&p.boolMask)!=0);}
 if([p.type isEqual:@"FloatProperty"]&&p.size==4){float f;memcpy(&f,v,4);if(!std::isfinite(f))fail("Ungültiger nativer Zahlenwert.");return @(f);}
 if([p.type isEqual:@"DoubleProperty"]&&p.size==8){double f;memcpy(&f,v,8);if(!std::isfinite(f))fail("Ungültiger nativer Zahlenwert.");return @(f);}
 if([p.type isEqual:@"NameProperty"]&&p.size==8)return fname((uintptr_t)v);
 if(!numeric(p))fail("Nicht unterstützter nativer Feldtyp.");
 #define ST_UNPACK(NAME,TYPE) if([p.type isEqual:@NAME]&&p.size==sizeof(TYPE)){TYPE x;memcpy(&x,v,sizeof(x));return @(x);}
 ST_UNPACK("Int8Property",int8_t) ST_UNPACK("Int16Property",int16_t) ST_UNPACK("UInt16Property",uint16_t) ST_UNPACK("IntProperty",int32_t) ST_UNPACK("UInt32Property",uint32_t) ST_UNPACK("Int64Property",int64_t) ST_UNPACK("UInt64Property",uint64_t)
 #undef ST_UNPACK
 if(([p.type isEqual:@"ByteProperty"]||[p.type isEqual:@"EnumProperty"])&&p.size==1)return @(*v);
 fail("Nicht unterstützter nativer Zahlenwert.");
}
}
bool read(uintptr_t p,void *out,size_t n){return p>=4096&&n>0&&n<=2097152&&n<=UINTPTR_MAX-p&&MTReadMemory((const void *)p,out,n);}
bool write(uintptr_t p,const void *bytes,size_t n){requireThread();return p>=4096&&bytes&&n>0&&n<=4096&&n<=UINTPTR_MAX-p&&MTWriteMemory((void *)p,bytes,n);}
bool isBound(){return ready.load(std::memory_order_acquire);}
bool bind(){
 if(isBound())return true;if(!NSThread.isMainThread)return false;
 if(![NSBundle.mainBundle.bundleIdentifier isEqual:@"com.annapurnainteractive.Stray"]||![[NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleVersion"] isEqual:@"100"])return false;
 const mach_header_64 *h=nullptr;uint32_t image=0;for(uint32_t i=0;i<_dyld_image_count();i++){auto q=(const mach_header_64 *)_dyld_get_image_header(i);if(q&&q->magic==MH_MAGIC_64&&q->filetype==MH_EXECUTE){h=q;image=i;break;}}
 if(!h||h->cputype!=CPU_TYPE_ARM64||h->sizeofcmds>1048576||h->ncmds>4096)return false;
 bool exact=false;const uint8_t *p=(const uint8_t *)(h+1),*end=p+h->sizeofcmds;
 for(uint32_t i=0;i<h->ncmds;i++){if(p+sizeof(load_command)>end)return false;auto c=(const load_command *)p;if(c->cmdsize<sizeof(*c)||c->cmdsize>(size_t)(end-p))return false;if(c->cmd==LC_UUID&&c->cmdsize==sizeof(uuid_command))exact=[[[NSUUID alloc]initWithUUIDBytes:((const uuid_command *)c)->uuid].UUIDString isEqual:@"C72D3F73-25F4-333B-9108-83432E09E687"];p+=c->cmdsize;}
 if(!exact)return false;intptr_t candidate=_dyld_get_image_vmaddr_slide(image);
 for(const auto &b:entries){uint8_t bytes[16];if(!read(b.address+candidate,bytes,16)||memcmp(bytes,b.prefix,16))return false;}
 slide=candidate;schedule=(Schedule)(0x101356660+slide);assign=(WeakAssign)(0x1016333e8+slide);weakGet=(WeakGet)(0x1016335cc+slide);ready.store(true,std::memory_order_release);return true;
}
bool isGameThread(){if(!isBound())return false;SEL s=NSSelectorFromString(@"isGameThread");return [NSThread respondsToSelector:s]&&((BOOL(*)(id,SEL))objc_msgSend)(NSThread.class,s);}
bool onGameThread(dispatch_block_t work){
 if(!work)return false;
 // Startup callers are on AppKit's main thread. Retry exact-build binding there
 // until the original Unreal thread is registered; never run work as a fallback.
 if(!isBound()&&(!NSThread.isMainThread||!bind()))return false;
 if(isGameThread()){work();return true;}
 SEL s=NSSelectorFromString(@"gameThread");if(![NSThread respondsToSelector:s]||!((id(*)(id,SEL))objc_msgSend)(NSThread.class,s))return false;
 schedule(^{if(isGameThread())work();},@[NSDefaultRunLoopMode,NSEventTrackingRunLoopMode,NSModalPanelRunLoopMode],false);return true;
}
uintptr_t binding(const char *key){if(!isBound()||!key)return 0;for(const auto &e:entries)if(!strcmp(e.name,key))return e.address+slide;for(const auto &e:dataEntries)if(!strcmp(e.name,key))return e.address+slide;return 0;}
int32_t objectCount(){requireThread();int32_t n=read<int32_t>(0x1054618d8+slide+0x24);if(n<0||n>2000000)fail("Die native Objektanzahl ist ungültig.");return n;}
Object object(int32_t index){requireThread();if(index<0||index>=objectCount())fail("Ungültiger nativer Objektindex.");uintptr_t chunks=read<uintptr_t>(0x1054618d8+slide+0x10),chunk=read<uintptr_t>(add(chunks,((uint32_t)index>>16)*8)),at=add(chunk,((uint32_t)index&65535)*0x18);uintptr_t ptr=read<uintptr_t>(at);if(!ptr||(read<uint8_t>(at+0xb)&0x30)||read<int32_t>(add(ptr,0xc))!=index)fail("Das native Objekt ist nicht mehr gültig.");return {ptr};}
Weak::Weak(Object o){requireThread();if(o){validate(o);assign(this,(const void *)o.address);if(!serial)fail("Der nativen Referenz fehlt die Serienkennung.");}}
Object Weak::get()const{requireThread();return serial?Object{(uintptr_t)weakGet(this)}:Object{};}
NSString *fname(uintptr_t at){requireThread();if(!(read<uint8_t>(0x1052c0080+slide)&1))fail("Die ursprüngliche Namensverwaltung ist noch nicht bereit.");uint64_t key=read<uint64_t>(at);auto cached=names.find(key);if(cached!=names.end())return cached->second;uint32_t id=(uint32_t)key,number=(uint32_t)(key>>32);uintptr_t block=read<uintptr_t>(0x10529d000+slide+0xd0+8*(id>>16)),entry=add(block,2*(id&65535));uint16_t header=read<uint16_t>(entry);size_t n=header>>6;if(n>1023)fail("Ungültige native Namenslänge.");NSString *s=nil;if(header&1){unichar bytes[1024];if(n&&!read(entry+2,bytes,n*2))fail("Unlesbarer nativer Name.");s=[[NSString alloc]initWithCharacters:bytes length:n];}else{char bytes[1024];if(n&&!read(entry+2,bytes,n))fail("Unlesbarer nativer Name.");s=[[NSString alloc]initWithBytes:bytes length:n encoding:NSUTF8StringEncoding];}if(!s)fail("Ungültiger nativer Namenstext.");NSString *result=number?[s stringByAppendingFormat:@"_%u",number-1]:s;if(names.size()>=8192)names.clear();names.emplace(key,result);return result;}
NSString *name(Object o){requireThread();validate(o);return fname(o.address+0x18);}
Object objectClass(Object o){requireThread();validate(o);Object c{read<uintptr_t>(o.address+0x10)};validate(c);return c;}
NSString *className(Object o){return name(objectClass(o));}
bool isA(Object o,Object cls){requireThread();validate(o);validate(cls);std::set<uintptr_t> seen;Object c=objectClass(o);for(size_t depth=0;c&&depth<64;depth++){if(c==cls)return true;if(!seen.insert(c.address).second)fail("Zyklische native Klassenhierarchie.");validate(c);c={read<uintptr_t>(c.address+0x40)};}return false;}
Object world(){requireThread();Object w{read<uintptr_t>(0x1054e0810+slide)};validate(w);if(![className(w) isEqual:@"World"])fail("Die native Spielwelt fehlt.");return w;}
Object playerPawn(){Object w=world();Object p{(uintptr_t)((void *(*)(void *,int32_t))binding("getPlayerPawn"))((void *)w.address,0)};validate(p);return p;}
Object playerController(){Object w=world();Object p{(uintptr_t)((void *(*)(void *))binding("getPlayerController"))((void *)w.address)};validate(p);return p;}
std::vector<Object> find(NSString *cf,NSString *nf,size_t limit){requireThread();if(!limit||limit>2000000)fail("Ungültige Objektgrenze.");std::vector<Object> result;int32_t n=objectCount();for(int32_t i=0;i<n&&result.size()<limit;i++)try{Object o=object(i);if(matches(className(o),cf)&&matches(name(o),nf))result.push_back(o);}catch(const std::exception &){}return result;}
std::vector<Property> properties(Object structure,bool supers){requireThread();std::vector<Property> out;std::set<uintptr_t> classes;for(size_t depth=0;structure&&depth<64;depth++){if(!classes.insert(structure.address).second)fail("Zyklische native Metadaten.");auto &entry=metadata(structure);for(const auto &p:entry.values){if(!p.current())fail("Der ursprüngliche Felddeskriptor hat gewechselt.");out.push_back(p.value);}if(!supers)break;structure=entry.super;}return out;}
std::vector<Property> fields(Object o){return properties(objectClass(o),true);}
Property property(Object owner,NSString *wanted){requireThread();if(!wanted.length)fail("Der native Feldname fehlt.");std::set<uintptr_t> seen;Object cls=objectClass(owner);std::string key(wanted.UTF8String);for(size_t depth=0;cls&&depth<64;depth++){if(!seen.insert(cls.address).second)fail("Zyklische native Metadaten.");auto &entry=metadata(cls);auto f=entry.names.find(key);if(f!=entry.names.end()){const auto &p=entry.values[f->second];if(!p.current())fail("Der ursprüngliche Felddeskriptor hat gewechselt.");return p.value;}cls=entry.super;}fail("Das ursprüngliche Feld fehlt.");}
Object function(Object owner,NSString *wanted){
 requireThread();validate(owner);if(!wanted.length)fail("Der native Funktionsname fehlt.");Object root=objectClass(owner);auto key=std::make_pair(root.address,std::string(wanted.UTF8String));auto hit=functions.find(key);if(hit!=functions.end()){if(hit->second.current())return hit->second.value;functions.erase(hit);}
 auto nativeClass=[](const char *key,NSString *expected){Object cls{(uintptr_t)((void *(*)())binding(key))()};validate(cls);if(![name(cls) isEqual:expected]||![className(cls) isEqual:@"Class"])fail("Die ursprüngliche Metadatenklasse stimmt nicht überein.");return cls;};
 struct Reader {
  Object fieldClass,functionClass;
  void validate(Object o){st::validate(o);}
  Object children(Object c){return {read<uintptr_t>(c.address+0x48)};}
  Object super(Object c){return {read<uintptr_t>(c.address+0x40)};}
  Object next(Object f){return {read<uintptr_t>(f.address+0x28)};}
  Object outer(Object f){return {read<uintptr_t>(f.address+0x20)};}
  bool isField(Object f){return st::isA(f,fieldClass);}
  bool isFunction(Object f){return st::isA(f,functionClass);}
  NSString *name(Object f){return st::name(f);}
 } reader{nativeClass("fieldClass",@"Field"),nativeClass("functionClass",@"Function")};
 Object result=detail::findFunction(root,wanted,reader);CachedFunction item;item.value=result;item.weak=Weak(result);if(!item.identity.capture(result.address+0x10,memoryRead))fail("Die native Funktionszuordnung ist unlesbar.");Object declaring{read<uintptr_t>(result.address+0x20)};Object cls=root;std::set<uintptr_t> seen;
 for(size_t depth=0;cls&&depth<64;depth++){if(!seen.insert(cls.address).second)fail("Zyklische native Metadaten.");ClassGuard guard;guard.owner=cls;guard.weak=Weak(cls);if(!guard.heads.capture(cls.address+0x40,memoryRead))fail("Die native Klassenanordnung ist unlesbar.");item.path.push_back(guard);if(cls==declaring)break;memcpy(&cls.address,guard.heads.expected.data(),8);}
 if(item.path.empty()||item.path.back().owner!=declaring)fail("Die native Funktion hat keinen bestätigten Besitzer.");if(functions.size()>=512)functions.clear();functions.emplace(std::move(key),std::move(item));return result;
}
id readValue(Object o,const Property &p){requireThread();verify(o,p);if(p.count!=1||p.size>8)fail("Nicht unterstütztes natives Wertformat.");uint8_t bytes[8]{};if(!read(o.address+p.offset,bytes,p.size))fail("Der native Feldwert ist unlesbar.");Property local=p;local.offset=0;return unpack(local,bytes,p.size);}
bool writeValue(Object o,const Property &p,id value){requireThread();verify(o,p);if(!numeric(p)||p.count!=1||p.size>8)fail("Nicht unterstützter beschreibbarer Feldtyp.");uint8_t bytes[8];if(!read(o.address+p.offset,bytes,p.size))return false;Property local=p;local.offset=0;if(!pack(local,value,bytes,p.size))return false;Weak hold(o);return hold.get()==o&&write(o.address+p.offset,bytes,p.size);}
id invoke(Object owner,NSString *wanted,NSDictionary *args){requireThread();validate(owner);if(![args isKindOfClass:NSDictionary.class])fail("Ungültige native Argumente.");Object f=function(owner,wanted);if(!(read<uint32_t>(f.address+0xb0)&0x400))fail("Nur native ursprüngliche Funktionen sind freigegeben.");uint16_t n=read<uint16_t>(f.address+0xb6);if(n>512)fail("Zu großer nativer Parameterblock.");alignas(16) uint8_t bytes[512]{};NSMutableSet *keys=[NSMutableSet new];std::set<size_t> occupied;Property ret;bool hasReturn=false;std::vector<Weak> keep;
 for(const auto &p:properties(f)){if(!(p.flags&0x80)||p.count!=1||p.size>8||(!numeric(p)&&![p.type isEqual:@"ObjectProperty"]&&![p.type isEqual:@"NameProperty"])||p.offset<0||(size_t)p.offset>n||(size_t)p.size>(size_t)n-(size_t)p.offset)fail("Nicht unterstützte native Parameteranordnung.");for(int i=0;i<p.size;i++)if(!occupied.insert(p.offset+i).second)fail("Überlappende native Parameter.");if(p.flags&0x400){if(hasReturn)fail("Mehrdeutige native Rückgabe.");ret=p;hasReturn=true;continue;}if(p.flags&(0x100|0x8000000))fail("Native Referenzparameter sind nicht freigegeben.");id value=args[p.name];if(!value||!pack(p,value,bytes,n))fail("Ein natives Argument fehlt oder ist ungültig.");[keys addObject:p.name];if([p.type isEqual:@"ObjectProperty"]&&value!=NSNull.null)keep.emplace_back(object([value[@"object"] intValue]));}
 if(keys.count!=args.count)fail("Unbekanntes natives Funktionsargument.");uint16_t ro=read<uint16_t>(f.address+0xb8);if((hasReturn&&ro!=ret.offset)||(!hasReturn&&ro!=UINT16_MAX))fail("Ungültige native Rückgabeanordnung.");Weak target(owner),fn(f);for(const auto &w:keep)if(!w.get())fail("Der Argumentbesitzer ist abgelaufen.");if(target.get()!=owner||fn.get()!=f)fail("Der Funktionsbesitzer ist abgelaufen.");((void(*)(void *,void *,void *))binding("processEvent"))((void *)owner.address,(void *)f.address,bytes);if(target.get()!=owner)fail("Der native Besitzer hat im Aufruf gewechselt.");return hasReturn?unpack(ret,bytes,n):NSNull.null;
}
}
