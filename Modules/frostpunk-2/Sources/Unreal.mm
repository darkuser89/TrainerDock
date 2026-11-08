// SPDX-License-Identifier: GPL-3.0-only
#import "Unreal.hpp"
#import <AppKit/AppKit.h>
extern "C" {
#import "MemoryAccess.h"
}
#import "ReflectionBindings.h"
#import "ThreadInputBindings.h"
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <objc/message.h>
#include <atomic>
#include <algorithm>
#include <cmath>
#include <cstring>
#include <limits>
#include <set>
#include <array>
#include <map>
#include <string>
namespace fp {
namespace {
std::atomic<bool> bound{false}; intptr_t slide=0;
FP2WeakAssign assignFn=nullptr;FP2WeakGet getFn=nullptr;FP2ProcessEvent eventFn=nullptr;
using Schedule=void(*)(dispatch_block_t,NSArray *,bool);using ThreadCheck=BOOL(*)(id,SEL);using ThreadGet=NSThread *(*)(id,SEL);
Schedule scheduleFn=nullptr;ThreadCheck threadFn=nullptr;ThreadGet threadGetFn=nullptr;
[[noreturn]]void fail(const char *s){throw std::runtime_error(s);}
void requireThread(){if(!isGameThread())fail("Original Unreal GameThread required");}
bool matches(NSString *s,NSString *f){return !f.length || [s rangeOfString:f options:NSCaseInsensitiveSearch].location!=NSNotFound;}
uintptr_t add(uintptr_t a,size_t n){if(a<4096 || n>UINTPTR_MAX-a)fail("Unreal pointer overflow");return a+n;}
void validate(Object o){if(!o)fail("Missing Unreal object");int32_t i=read<int32_t>(add(o.address,FP2ObjectInternalIndexOffset));if(object(i).address!=o.address)fail("Stale Unreal object");}
NSString *fieldType(uintptr_t p){uintptr_t c=read<uintptr_t>(add(p,FP2FieldClassOffset));return fname(c);}
Property describe(uintptr_t p,Object owner){Property v;v.address=p;v.ownerClass=owner;v.ownerWeak=Weak(owner);v.name=fname(add(p,FP2FieldNameOffset));v.type=fieldType(p);v.offset=read<int32_t>(add(p,FP2PropertyOffsetOffset));v.size=read<int32_t>(add(p,FP2PropertyElementSizeOffset));v.count=read<int32_t>(add(p,FP2PropertyArrayDimOffset));v.flags=read<uint64_t>(add(p,FP2PropertyFlagsOffset));if(v.offset<0 || v.offset>1048576 || v.size<1 || v.size>65536 || v.count<1 || v.count>65536)fail("Ungültige ursprüngliche Feldanordnung.");if([v.type isEqual:@"BoolProperty"]){uint8_t d[4];if(!read(add(p,0x70),d,4) || d[0]!=1 || !d[2] || !d[3] || (d[2]&(d[2]-1)) || (d[3]!=255 && d[3]!=d[2]))fail("Invalid native bool layout");v.boolByteOffset=d[1];v.boolMask=d[3];if(v.boolByteOffset>=v.size)fail("Der Wahrheitswert liegt außerhalb des Feldbereichs.");}if([v.type isEqual:@"ObjectProperty"]){v.objectClass={read<uintptr_t>(add(p,0x70))};validate(v.objectClass);}return v;}
bool same(Property a,Property b){return a.address==b.address && a.ownerClass==b.ownerClass && a.ownerWeak.index==b.ownerWeak.index && a.ownerWeak.serial==b.ownerWeak.serial && a.offset==b.offset && a.size==b.size && a.count==b.count && a.flags==b.flags && [a.name isEqual:b.name] && [a.type isEqual:b.type] && a.boolByteOffset==b.boolByteOffset && a.boolMask==b.boolMask && a.objectClass==b.objectClass;}
// Caches contain metadata only. Every lookup remains on the original GameThread.
// Weak index+serial, never an unverified address, owns every cached descriptor.
using MetadataKey=std::pair<int32_t,int32_t>;
struct MetadataHeads {
    uintptr_t objectClass=0,super=0,children=0,fields=0;
    bool operator==(const MetadataHeads &b)const{return objectClass==b.objectClass&&super==b.super&&children==b.children&&fields==b.fields;}
};
MetadataHeads heads(Object o){
    MetadataHeads h;h.objectClass=read<uintptr_t>(add(o.address,FP2ObjectClassOffset));
    std::array<uintptr_t,3> chain=read<std::array<uintptr_t,3>>(add(o.address,FP2StructSuperOffset));
    h.super=chain[0];h.children=chain[1];h.fields=chain[2];return h;
}
struct PropertyStamp {
    std::array<uint8_t,0x50> core{};uint64_t fieldClassName=0;
    std::array<uint8_t,8> extra{};bool hasExtra=false;Weak objectClassWeak{};
};
PropertyStamp stamp(const Property &p){
    PropertyStamp s;if(!read(p.address,s.core.data(),s.core.size()))fail("Unreadable property metadata");
    uintptr_t cls=0;memcpy(&cls,s.core.data()+FP2FieldClassOffset,8);
    s.fieldClassName=read<uint64_t>(cls);
    s.hasExtra=[p.type isEqual:@"BoolProperty"]||[p.type isEqual:@"ObjectProperty"];
    if(s.hasExtra&&!read(add(p.address,0x70),s.extra.data(),s.extra.size()))fail("Unreadable typed property metadata");
    if(p.objectClass)s.objectClassWeak=Weak(p.objectClass);return s;
}
bool stampMatches(const Property &p,const PropertyStamp &s){
    std::array<uint8_t,0x50> bytes{};if(!read(p.address,bytes.data(),bytes.size())||bytes!=s.core)return false;
    uintptr_t cls=0;memcpy(&cls,bytes.data()+FP2FieldClassOffset,8);
    if(read<uint64_t>(cls)!=s.fieldClassName)return false;
    if(s.hasExtra){std::array<uint8_t,8> extra{};if(!read(add(p.address,0x70),extra.data(),extra.size())||extra!=s.extra)return false;}
    return !p.objectClass||s.objectClassWeak.get()==p.objectClass;
}
struct CachedProperty {Property value;PropertyStamp shape;};
struct Metadata {
    Object object{};Weak owner{};MetadataHeads shape{};bool populated=false;
    std::vector<CachedProperty> fields;
    std::map<std::string,size_t> byName;std::map<uintptr_t,size_t> byAddress;
};
std::map<MetadataKey,Metadata> metadataCache;
MetadataKey metadataKey(const Weak &w){return {w.index,w.serial};}
Metadata &metadata(Object o){
    requireThread();Weak w(o);if(!o||w.get()!=o)fail("Expired metadata owner");
    MetadataKey key=metadataKey(w);MetadataHeads h=heads(o);auto it=metadataCache.find(key);
    if(it!=metadataCache.end()&&it->second.owner.get()==o&&it->second.object==o&&it->second.shape==h)return it->second;
    if(it!=metadataCache.end())metadataCache.erase(it);
    NSString *t=className(o);
    if([t rangeOfString:@"Class"].location==NSNotFound&&[t rangeOfString:@"Function"].location==NSNotFound&&![t isEqual:@"ScriptStruct"])fail("Das Metadatenobjekt ist keine Datenstruktur.");
    if(metadataCache.size()>=1024)metadataCache.clear();
    Metadata m;m.object=o;m.owner=w;m.shape=h;
    return metadataCache.emplace(key,std::move(m)).first->second;
}
void populate(Metadata &m){
    if(m.populated)return;
    std::vector<CachedProperty> values;std::map<std::string,size_t> names;std::map<uintptr_t,size_t> addresses;
    std::set<uintptr_t> seen;uintptr_t p=m.shape.fields;
    for(size_t n=0;p;n++){
        if(n>=1024||!seen.insert(p).second)fail("Cyclic or oversized property chain");
        Property v=describe(p,m.object);v.ownerWeak=m.owner;PropertyStamp shape=stamp(v);
        if(!stampMatches(v,shape))fail("Die Feldmetadaten wurden während der Erfassung verändert.");
        const char *key=v.name.UTF8String;if(!key)fail("Ungültiger Feldmetadatenname.");
        if(!names.emplace(key,values.size()).second)fail("Duplicate original property name");
        addresses.emplace(p,values.size());values.push_back({v,shape});
        memcpy(&p,shape.core.data()+FP2FieldNextOffset,8);
    }
    if(m.owner.get()!=m.object||!(heads(m.object)==m.shape))fail("Der Metadatenbesitzer hat während der Erfassung gewechselt.");
    m.fields=std::move(values);m.byName=std::move(names);m.byAddress=std::move(addresses);m.populated=true;
}
void invalidate(Metadata &m){m.populated=false;m.fields.clear();m.byName.clear();m.byAddress.clear();}
bool fieldLinksMatch(const Metadata &m,size_t count){
    if(m.owner.get()!=m.object)return false;
    for(size_t i=0;i<count;i++){
        std::array<uint8_t,16> link{};
        if(!read(add(m.fields[i].value.address,FP2FieldNextOffset),link.data(),link.size())||memcmp(link.data(),m.fields[i].shape.core.data()+FP2FieldNextOffset,link.size()))return false;
    }
    return true;
}
Property cachedProperty(Metadata &m,size_t index,bool checkPrefix=true){
    if(m.owner.get()!=m.object||(checkPrefix&&!fieldLinksMatch(m,index))){invalidate(m);fail("Die gespeicherte Feldzuordnung oder der Besitzer hat gewechselt.");}
    const auto &p=m.fields.at(index);
    if(!stampMatches(p.value,p.shape)){invalidate(m);fail("Der gespeicherte Feldbesitzer oder seine Metadaten wurden verändert.");}
    return p.value;
}
Property verifyProperty(Object owner,const Property &p){
    validate(owner);
    if(!p.address||!p.ownerClass||p.ownerWeak.get()!=p.ownerClass||!isA(owner,p.ownerClass))fail("Der Feldbesitzer stimmt nicht überein oder ist nicht mehr gültig.");
    Metadata &m=metadata(p.ownerClass);populate(m);auto it=m.byAddress.find(p.address);
    if(it==m.byAddress.end())fail("Das Feld liegt außerhalb der Metadaten des aktuellen Besitzers.");
    Property fresh=cachedProperty(m,it->second);if(!same(fresh,p))fail("Die Feldmetadaten wurden verändert.");return fresh;
}
struct FunctionPath {Object object{};Weak owner{};MetadataHeads shape{};};
struct FunctionLink {Object object{};Weak owner{};std::array<uintptr_t,4> identity{};};
struct CachedFunction {
    Object object{},declaring{};Weak owner{},declaringWeak{};
    std::array<uintptr_t,3> identity{};std::vector<FunctionPath> path;std::vector<FunctionLink> links;
};
using FunctionKey=std::pair<MetadataKey,std::string>;
std::map<FunctionKey,CachedFunction> functionCache;
bool functionMatches(const CachedFunction &f){
    if(f.owner.get()!=f.object||f.declaringWeak.get()!=f.declaring)return false;
    if(read<std::array<uintptr_t,3>>(add(f.object.address,FP2ObjectClassOffset))!=f.identity)return false;
    for(const auto &p:f.path)if(p.owner.get()!=p.object||!(heads(p.object)==p.shape))return false;
    for(const auto &l:f.links)if(l.owner.get()!=l.object||read<std::array<uintptr_t,4>>(add(l.object.address,FP2ObjectClassOffset))!=l.identity)return false;
    return f.identity[2]==f.declaring.address;
}

bool scalarKind(const Property &p){return [p.type isEqual:@"BoolProperty"]||[p.type isEqual:@"ByteProperty"]||[p.type isEqual:@"Int8Property"]||[p.type isEqual:@"Int16Property"]||[p.type isEqual:@"UInt16Property"]||[p.type isEqual:@"IntProperty"]||[p.type isEqual:@"UInt32Property"]||[p.type isEqual:@"Int64Property"]||[p.type isEqual:@"UInt64Property"]||[p.type isEqual:@"FloatProperty"]||[p.type isEqual:@"DoubleProperty"];}
Object objectArgument(id v,Object expected){if(v==NSNull.null)return {};if(![v isKindOfClass:NSDictionary.class] || [v count]!=1 || ![v[@"object"] isKindOfClass:NSNumber.class])fail("Object parameter needs explicit object index");NSNumber *number=v[@"object"];double n=number.doubleValue;if(!std::isfinite(n)||std::floor(n)!=n||n<0||n>INT32_MAX)fail("Invalid object argument index");Object o=object(number.intValue);if(!expected || !isA(o,expected))fail("Object argument class mismatch");return o;}
id objectResult(uintptr_t a,Object expected){if(!a)return NSNull.null;Object o{a};validate(o);if(expected && !isA(o,expected))fail("Die Klasse des zurückgegebenen Objekts stimmt nicht überein.");return @{@"object":@(read<int32_t>(add(a,FP2ObjectInternalIndexOffset)))};}
bool pack(const Property &p,id v,void *out,size_t n){if(p.count!=1 || p.offset<0 || (size_t)p.offset>n || (size_t)p.size>n-(size_t)p.offset)return false;if([p.type isEqual:@"ObjectProperty"]){if(p.size!=8)return false;uintptr_t a=objectArgument(v,p.objectClass).address;std::memcpy((uint8_t*)out+p.offset,&a,8);return true;}return detail::packScalar(p,v,out,n);}
id unpack(const Property &p,const void *b,size_t n){if([p.type isEqual:@"ObjectProperty"]){if(p.size!=8 || p.count!=1 || p.offset<0 || (size_t)p.offset>n || 8>n-(size_t)p.offset)fail("Object return outside parameter block");uintptr_t a=0;std::memcpy(&a,(const uint8_t*)b+p.offset,8);return objectResult(a,p.objectClass);}return detail::unpackScalar(p,b,n);}
}
bool read(uintptr_t p,void *out,size_t n){return p>=4096 && n>0 && n<=2*1024*1024 && n<=UINTPTR_MAX-p && MTReadMemory((const void*)p,out,n);}
bool isBound(){return bound.load(std::memory_order_acquire);}
bool bind(){if(isBound())return true;if(![NSThread isMainThread])return false;NSString *bid=NSBundle.mainBundle.bundleIdentifier;NSString *version=[NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleVersion"];if(![bid isEqual:@"com.11bitstudios.frostpunk2"] || ![version isEqual:@"0.5.591"])return false;const mach_header_64 *h=nullptr;uint32_t image=0;for(uint32_t i=0;i<_dyld_image_count();i++){const auto *candidate=(const mach_header_64*)_dyld_get_image_header(i);if(candidate && candidate->magic==MH_MAGIC_64 && candidate->filetype==MH_EXECUTE){h=candidate;image=i;break;}}if(!h || h->magic!=MH_MAGIC_64 || h->cputype!=CPU_TYPE_ARM64 || h->ncmds>1024 || h->sizeofcmds>1024*1024)return false;bool exact=false;const uint8_t *p=(const uint8_t*)(h+1),*end=p+h->sizeofcmds;for(uint32_t i=0;i<h->ncmds;i++){if(p+sizeof(load_command)>end)return false;const load_command *c=(const load_command*)p;if(c->cmdsize<sizeof(*c) || c->cmdsize>(size_t)(end-p))return false;if(c->cmd==LC_UUID){if(c->cmdsize<sizeof(uuid_command))return false;exact=[[[NSUUID alloc]initWithUUIDBytes:((const uuid_command*)c)->uuid].UUIDString isEqual:@"10F7F2EA-0D13-337E-BF07-ABA47A4549CF"];}p+=c->cmdsize;}if(!exact)return false;intptr_t s=_dyld_get_image_vmaddr_slide(image);for(const auto &b:fp2ReflectionBindings){uint8_t bytes[16];if(!read(b.address+s,bytes,16)||memcmp(bytes,b.bytes,16))return false;}for(const auto &b:fpThreadBindings){uint8_t bytes[16];if(!read(b.address+s,bytes,16)||memcmp(bytes,b.bytes,16))return false;}slide=s;assignFn=(FP2WeakAssign)(0x100c2cf8c+s);getFn=(FP2WeakGet)(0x100c2d1e0+s);eventFn=(FP2ProcessEvent)(0x100be2e78+s);scheduleFn=(Schedule)(0x10087a854+s);threadFn=(ThreadCheck)(0x10087a274+s);threadGetFn=(ThreadGet)(0x10087a258+s);bound.store(true,std::memory_order_release);return true;}
bool isGameThread(){return isBound() && threadFn(NSThread.class,NSSelectorFromString(@"isGameThread"));}
bool onGameThread(dispatch_block_t block){if(!block||!isBound())return false;if(isGameThread()){block();return true;}if(!read<uintptr_t>(0x10c73d1e0+slide) || !threadGetFn(NSThread.class,NSSelectorFromString(@"gameThread")))return false;scheduleFn(^{if(isGameThread())block();},@[NSDefaultRunLoopMode,NSEventTrackingRunLoopMode,NSModalPanelRunLoopMode],false);return true;}
int32_t objectCount(){requireThread();int32_t n=read<int32_t>(FP2ObjectArrayAddress+slide+FP2ObjectArrayCountOffset);if(n<0||n>2000000)fail("Ungültige ursprüngliche Objektanzahl.");return n;}
Object object(int32_t i){requireThread();int32_t n=objectCount();if(i<0||i>=n)fail("Der Objektindex liegt außerhalb der ursprünglichen Liste.");uintptr_t chunks=read<uintptr_t>(FP2ObjectArrayAddress+slide+FP2ObjectArrayChunksOffset),chunk=read<uintptr_t>(add(chunks,((uint32_t)i>>16)*8)),item=add(chunk,((uint32_t)i&65535)*FP2ObjectItemSize);uintptr_t a=read<uintptr_t>(item);uint32_t flags=read<uint32_t>(add(item,8)),mask=read<uint32_t>(FP2UnreachableMaskAddress+slide)|0x200000;if(!a || (flags&mask) || read<int32_t>(add(a,FP2ObjectInternalIndexOffset))!=i)fail("Das ursprüngliche Objekt fehlt oder ist nicht mehr gültig.");return {a};}
Weak::Weak(Object o){requireThread();if(o){validate(o);FP2WeakObject w{};assignFn(&w,(const void*)o.address);index=w.index;serial=w.serial;if(!serial)fail("Der ursprünglichen schwachen Referenz fehlt die Serienkennung.");}}
Object Weak::get()const{requireThread();if(!serial)return {};FP2WeakObject w{index,serial};return {(uintptr_t)getFn(&w)};}
NSString *fname(uintptr_t at){requireThread();if(!(read<uint8_t>(FP2NamePoolInitializedAddress+slide)&1))fail("Die ursprüngliche Namensverwaltung ist noch nicht bereit.");uint32_t i=read<uint32_t>(at),number=read<uint32_t>(add(at,4));uintptr_t block=read<uintptr_t>(FP2NamePoolAddress+slide+FP2NamePoolChunksOffset+8*(i>>16)),entry=add(block,2*(i&65535));uint16_t h=read<uint16_t>(entry);size_t n=h>>6;if(n>1023)fail("Ungültige Länge des ursprünglichen Namens.");NSString *s=nil;if(h&1){unichar text[1024];if(n&&!read(add(entry,2),text,n*2))fail("Unreadable wide FName");s=[[NSString alloc]initWithCharacters:text length:n];}else{char text[1024];if(n&&!read(add(entry,2),text,n))fail("Unreadable narrow FName");s=[[NSString alloc]initWithBytes:text length:n encoding:NSUTF8StringEncoding];}if(!s)fail("Ungültiger ursprünglicher Namenstext.");return number?[s stringByAppendingFormat:@"_%u",number-1]:s;}
NSString *name(Object o){requireThread();validate(o);return fname(add(o.address,FP2ObjectNameOffset));}
Object objectClass(Object o){requireThread();validate(o);Object c{read<uintptr_t>(add(o.address,FP2ObjectClassOffset))};validate(c);return c;}
NSString *className(Object o){return name(objectClass(o));}
bool isA(Object o,Object c){requireThread();validate(o);validate(c);std::set<uintptr_t> seen;Object k=objectClass(o);for(size_t n=0;k&&n<64;n++){if(k==c)return true;if(!seen.insert(k.address).second)fail("Cyclic class hierarchy");validate(k);k={read<uintptr_t>(add(k.address,FP2StructSuperOffset))};}return false;}
std::vector<Object> find(NSString *cf,NSString *nf,size_t limit){requireThread();if(!limit||limit>2000000)fail("Ungültige Grenze der Objektsuche.");std::vector<Object> out;int32_t n=objectCount();for(int32_t i=0;i<n&&out.size()<limit;i++){try{Object o=object(i);if(matches(className(o),cf)&&matches(name(o),nf))out.push_back(o);}catch(const std::runtime_error &){}}return out;}
std::vector<Property> properties(Object structure,bool supers){
    requireThread();std::vector<Property> out;std::set<uintptr_t> seen;Object c=structure;
    for(size_t depth=0;c&&depth<64;depth++){
        if(!seen.insert(c.address).second)fail("Cyclic metadata superclass");
        Metadata &m=metadata(c);populate(m);uintptr_t super=m.shape.super;
        for(size_t i=0;i<m.fields.size();i++)out.push_back(cachedProperty(m,i,false));
        if(!supers)break;c={super};
    }
    return out;
}
std::vector<Property> fields(Object o){return properties(objectClass(o),true);}
Property property(Object o,NSString *wanted){
    requireThread();const char *text=wanted.UTF8String;if(!wanted.length||!text)fail("Der Feldname fehlt.");
    std::string key=text;std::set<uintptr_t> seen;Object c=objectClass(o);
    for(size_t depth=0;c&&depth<64;depth++){
        if(!seen.insert(c.address).second)fail("Cyclic metadata superclass");
        Metadata &m=metadata(c);populate(m);auto it=m.byName.find(key);
        if(it!=m.byName.end())return cachedProperty(m,it->second);
        // A miss must also observe insertions/renames below an unchanged head.
        if(!fieldLinksMatch(m,m.fields.size())){invalidate(m);populate(m);it=m.byName.find(key);if(it!=m.byName.end())return cachedProperty(m,it->second);}
        c={m.shape.super};
    }
    fail("Das ursprüngliche Feld wurde nicht gefunden.");
}
Object function(Object owner,NSString *wanted){
    requireThread();validate(owner);const char *text=wanted.UTF8String;
    if(!wanted.length||!text)fail("Der Funktionsname fehlt.");
    Object root=objectClass(owner);Weak rootWeak(root);FunctionKey key{metadataKey(rootWeak),text};
    auto hit=functionCache.find(key);
    if(hit!=functionCache.end()){
        if(functionMatches(hit->second))return hit->second.object;
        functionCache.erase(hit);
    }
    std::set<uintptr_t> seen,classes;std::vector<FunctionPath> path;std::vector<FunctionLink> links;Object c=root;
    for(size_t depth=0;c&&depth<64;depth++){
        if(!classes.insert(c.address).second)fail("Cyclic function metadata superclass");
        Metadata &m=metadata(c);path.push_back({c,m.owner,m.shape});uintptr_t nextClass=m.shape.super;
        uintptr_t f=m.shape.children;
        for(size_t n=0;f;n++){
            if(n>=4096||!seen.insert(f).second)fail("Cyclic native function chain");
            Object o{f};validate(o);
            if([className(o) rangeOfString:@"Function"].location==NSNotFound)fail("Unerwarteter ursprünglicher Feldtyp.");
            if([name(o) isEqual:wanted]){
                if(read<uintptr_t>(add(f,FP2ObjectOuterOffset))!=c.address)fail("Function outer differs from owner class");
                CachedFunction entry;entry.object=o;entry.declaring=c;entry.owner=Weak(o);entry.declaringWeak=Weak(c);
                entry.identity=read<std::array<uintptr_t,3>>(add(f,FP2ObjectClassOffset));entry.path=path;entry.links=links;
                if(!functionMatches(entry))fail("Die Funktionsmetadaten wurden während der Erfassung verändert.");
                if(functionCache.size()>=1024)functionCache.clear();
                functionCache.emplace(std::move(key),std::move(entry));return o;
            }
            auto prefix=read<std::array<uintptr_t,4>>(add(f,FP2ObjectClassOffset));links.push_back({o,Weak(o),prefix});f=prefix[3];
        }
        c={nextClass};
    }
    fail("Die ursprüngliche Funktion wurde nicht gefunden.");
}
id readValue(Object o,const Property &p){requireThread();Property v=verifyProperty(o,p);if(v.count!=1||v.size>8)fail("Nicht unterstütztes Format des Feldwerts.");uint8_t bytes[8]{};if(!read(add(o.address,v.offset),bytes,v.size))fail("Unreadable field value");v.offset=0;return unpack(v,bytes,v.size);}
bool writeValue(Object o,const Property &p,id value){requireThread();Property v=verifyProperty(o,p);if(v.count!=1||v.size>8||!scalarKind(v))fail("Nicht unterstützter beschreibbarer Feldtyp.");uint8_t bytes[8]{};if(!read(add(o.address,v.offset),bytes,v.size))return false;int32_t at=v.offset;v.offset=0;if(!detail::packScalar(v,value,bytes,v.size))return false;Weak w(o);if(w.get()!=o)return false;return MTWriteMemory((void*)add(o.address,at),bytes,v.size);}
id invoke(Object owner,NSString *fn,NSDictionary *args){requireThread();validate(owner);if(![args isKindOfClass:NSDictionary.class])fail("Die Funktionsargumente müssen ein Wörterbuch sein.");Object f=function(owner,fn);uint32_t flags=read<uint32_t>(add(f.address,FP2FunctionFlagsOffset));if(!(flags&0x400))fail("Nur ursprüngliche native Funktionen dürfen aufgerufen werden.");Object outer{read<uintptr_t>(add(f.address,FP2ObjectOuterOffset))};if(!isA(owner,outer))fail("Die Besitzerklasse der Funktion stimmt nicht überein.");uint16_t size=read<uint16_t>(add(f.address,FP2FunctionParameterSizeOffset));if(size>512)fail("Native parameter block exceeds bound");alignas(16) uint8_t params[512]{};std::vector<Property> ps=properties(f);std::set<size_t> used;NSMutableSet *keys=[NSMutableSet new];Property ret;bool hasReturn=false;std::vector<Weak> retained;Weak target(owner),functionWeak(f);for(const auto &p:ps){if(!(p.flags&0x80))fail("Non-parameter function metadata unsupported");if(p.count!=1 || p.offset<0 || p.size>8 || (size_t)p.offset>size || (size_t)p.size>size-(size_t)p.offset)fail("Nicht unterstützte Parameterdimensionen.");if(!scalarKind(p)&&![p.type isEqual:@"ObjectProperty"])fail("Nicht unterstützter nativer Parametertyp.");for(int i=0;i<p.size;i++)if(!used.insert((size_t)p.offset+i).second)fail("Overlapping native parameters");if(p.flags&0x400){if(hasReturn)fail("Multiple native return parameters");ret=p;hasReturn=true;continue;}if(p.flags&(0x100|0x8000000))fail("Native out/reference parameter unsupported");id v=args[p.name];if(!v)fail("Ein erforderliches natives Argument fehlt.");[keys addObject:p.name];if([p.type isEqual:@"ObjectProperty"]){Object a=objectArgument(v,p.objectClass);if(a)retained.emplace_back(a);}if(!pack(p,v,params,size))fail("Native argument value invalid");}if(keys.count!=args.count)fail("Unbekanntes natives Funktionsargument.");uint16_t ro=read<uint16_t>(add(f.address,FP2FunctionReturnOffsetOffset));if((hasReturn&&ro!=ret.offset)||(!hasReturn&&ro!=UINT16_MAX))fail("Native return metadata inconsistent");if(target.get()!=owner||functionWeak.get()!=f)fail("Der native Besitzer hat vor dem Aufruf gewechselt.");for(const auto &w:retained)if(!w.get())fail("Native argument owner expired");eventFn((void*)owner.address,(void*)f.address,params);if(target.get()!=owner)fail("Native owner expired during invocation");return hasReturn?unpack(ret,params,size):NSNull.null;}
namespace detail {
namespace {
bool location(const Property &p,size_t n){return p.count==1&&p.offset>=0&&p.size>0&&(size_t)p.offset<=n&&(size_t)p.size<=n-(size_t)p.offset;}
bool integer(id value,bool sign,unsigned bits,uint64_t &out){if(![value isKindOfClass:NSNumber.class])return false;const char *s=[[value stringValue] UTF8String];if(!s||!*s)return false;char *end=nullptr;errno=0;if(sign){long long v=strtoll(s,&end,10);if(errno||*end)return false;if(bits<64&&(v<-(1LL<<(bits-1))||v>((1LL<<(bits-1))-1)))return false;out=(uint64_t)v;return true;}if(*s=='-')return false;unsigned long long v=strtoull(s,&end,10);if(errno||*end||(bits<64&&v>((1ULL<<bits)-1)))return false;out=v;return true;}
}
bool packScalar(const Property &p,id value,void *buffer,size_t n){if(!buffer||!location(p,n)||![value isKindOfClass:NSNumber.class])return false;uint8_t *dest=(uint8_t*)buffer+p.offset;if([p.type isEqual:@"BoolProperty"]){if(!p.boolMask||p.boolByteOffset>=p.size)return false;double v=[value doubleValue];if(v!=0&&v!=1)return false;uint8_t &b=dest[p.boolByteOffset];b=(b&~p.boolMask)|(v?(p.boolMask==255?1:p.boolMask):0);return true;}if([p.type isEqual:@"FloatProperty"]&&p.size==4){double d=[value doubleValue];if(!std::isfinite(d)||std::abs(d)>std::numeric_limits<float>::max())return false;float v=(float)d;memcpy(dest,&v,4);return true;}if([p.type isEqual:@"DoubleProperty"]&&p.size==8){double v=[value doubleValue];if(!std::isfinite(v))return false;memcpy(dest,&v,8);return true;}bool sign=true;unsigned bits=0;if([p.type isEqual:@"Int8Property"])bits=8;else if([p.type isEqual:@"ByteProperty"]){bits=8;sign=false;}else if([p.type isEqual:@"Int16Property"])bits=16;else if([p.type isEqual:@"UInt16Property"]){bits=16;sign=false;}else if([p.type isEqual:@"IntProperty"])bits=32;else if([p.type isEqual:@"UInt32Property"]){bits=32;sign=false;}else if([p.type isEqual:@"Int64Property"])bits=64;else if([p.type isEqual:@"UInt64Property"]){bits=64;sign=false;}uint64_t v=0;if(!bits||p.size!=(int)bits/8||!integer(value,sign,bits,v))return false;memcpy(dest,&v,bits/8);return true;}
id unpackScalar(const Property &p,const void *buffer,size_t n){if(!buffer||!location(p,n))fail("Der Zahlenwert liegt außerhalb des gültigen Speicherbereichs.");const uint8_t *s=(const uint8_t*)buffer+p.offset;if([p.type isEqual:@"BoolProperty"]){if(!p.boolMask||p.boolByteOffset>=p.size)fail("Ungültiges Wahrheitswertformat.");return @((s[p.boolByteOffset]&p.boolMask)!=0);}if([p.type isEqual:@"FloatProperty"]&&p.size==4){float v;memcpy(&v,s,4);if(!std::isfinite(v))fail("Non-finite original scalar");return @(v);}if([p.type isEqual:@"DoubleProperty"]&&p.size==8){double v;memcpy(&v,s,8);if(!std::isfinite(v))fail("Non-finite original scalar");return @(v);}
#define FP_UNPACK(NAME,TYPE) if([p.type isEqual:@NAME]&&p.size==sizeof(TYPE)){TYPE v;memcpy(&v,s,sizeof(v));return @(v);}
FP_UNPACK("ByteProperty",uint8_t) FP_UNPACK("Int8Property",int8_t) FP_UNPACK("Int16Property",int16_t) FP_UNPACK("UInt16Property",uint16_t) FP_UNPACK("IntProperty",int32_t) FP_UNPACK("UInt32Property",uint32_t) FP_UNPACK("Int64Property",int64_t) FP_UNPACK("UInt64Property",uint64_t)
#undef FP_UNPACK
fail("Nicht unterstützter ursprünglicher Zahlentyp.");}
}
uintptr_t binding(const char *name){if(!isBound()||!name)return 0;if(!strcmp(name,"macApplicationSlot"))return FP_MAC_APPLICATION_SLOT+slide;if(!strcmp(name,"macCursorVTable"))return FP_MAC_CURSOR_VTABLE+slide;if(!strcmp(name,"slateSlot"))return FP_SLATE_SLOT+slide;for(const auto &b:fp2ReflectionBindings)if(!strcmp(name,b.name))return b.address+slide;for(const auto &b:fpThreadBindings)if(!strcmp(name,b.name))return b.address+slide;return 0;}
}
