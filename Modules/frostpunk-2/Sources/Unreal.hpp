// SPDX-License-Identifier: GPL-3.0-only
#pragma once
#import <Foundation/Foundation.h>
#include <cstdint>
#include <cstddef>
#include <stdexcept>
#include <vector>
namespace fp {
struct Object { uintptr_t address=0; explicit operator bool() const { return address!=0; } bool operator==(Object b) const { return address==b.address; } bool operator!=(Object b) const { return address!=b.address; } };
struct Weak { int32_t index=0,serial=0; Weak()=default; explicit Weak(Object); Object get() const; };
struct Property {
    uintptr_t address=0; Object ownerClass{}; NSString *name=nil,*type=nil;
    Weak ownerWeak{};
    int32_t offset=0,size=0,count=0; uint64_t flags=0;
    uint8_t boolByteOffset=0,boolMask=0; Object objectClass{};
};
bool bind(); bool isBound(); bool isGameThread();
uintptr_t binding(const char *name);
// Returns false while native GameThread registration is not ready; caller retries on main.
// No fallback queue ever runs engine work.
bool onGameThread(dispatch_block_t);
bool read(uintptr_t,void *,size_t);
template<class T>T read(uintptr_t p){ T v{}; if(!read(p,&v,sizeof(v)))throw std::runtime_error("Unreadable Unreal memory");return v; }
NSString *fname(uintptr_t); NSString *name(Object); NSString *className(Object);
Object object(int32_t); int32_t objectCount(); Object objectClass(Object); bool isA(Object,Object);
std::vector<Object> find(NSString *classFilter=nil,NSString *nameFilter=nil,size_t limit=256);
std::vector<Property> properties(Object structure,bool includeSuper=false);
std::vector<Property> fields(Object owner);
Property property(Object owner,NSString *fieldName);
Object function(Object owner,NSString *functionName);
id readValue(Object owner,const Property &); bool writeValue(Object owner,const Property &,id);
// Exact input parameter names, no extra/missing values. Objects use {object:index};
// NSNull means null object. Only verified scalar/native bool/ObjectProperty forms.
// Rejects arrays/structs/delegates/strings/names, by-reference or extra out parameters.
// Void returns NSNull; scalar NSNumber; object {object:index}. Throws on rejection.
id invoke(Object owner,NSString *functionName,NSDictionary *arguments);
namespace detail {
// Pure bounded packing, also used by synthetic contract tests; object values resolve
// only through object()/Weak on the actual native GameThread.
bool packScalar(const Property &,id,void *,size_t);
id unpackScalar(const Property &,const void *,size_t);
}
}
