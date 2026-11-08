// SPDX-License-Identifier: GPL-3.0-only
#pragma once
#import <Foundation/Foundation.h>
#include <cstdint>
#include <cstddef>
#include <stdexcept>
#include <vector>
namespace st {
struct Object {uintptr_t address=0;explicit operator bool()const{return address!=0;}bool operator==(Object b)const{return address==b.address;}bool operator!=(Object b)const{return address!=b.address;}};
struct Weak {int32_t index=-1,serial=0;Weak()=default;explicit Weak(Object);Object get()const;};
struct Property {uintptr_t address=0;Object ownerClass{};Weak ownerWeak{};NSString *name=nil,*type=nil;int32_t offset=0,size=0,count=0;uint64_t flags=0;uint8_t boolByteOffset=0,boolMask=0;Object objectClass{};};
bool bind();bool isBound();bool isGameThread();bool onGameThread(dispatch_block_t);
uintptr_t binding(const char *);
bool read(uintptr_t,void *,size_t);bool write(uintptr_t,const void *,size_t);
template<class T>T read(uintptr_t at){T value{};if(!read(at,&value,sizeof(value)))throw std::runtime_error("Unlesbarer nativer Spielspeicher.");return value;}
NSString *fname(uintptr_t);NSString *name(Object);NSString *className(Object);
Object object(int32_t);int32_t objectCount();Object objectClass(Object);bool isA(Object,Object);
Object world();Object playerPawn();Object playerController();
std::vector<Object> find(NSString *classFilter=nil,NSString *nameFilter=nil,size_t limit=256);
std::vector<Property> properties(Object structure,bool includeSuper=false);
std::vector<Property> fields(Object owner);Property property(Object owner,NSString *fieldName);Object function(Object owner,NSString *functionName);
id readValue(Object,const Property &);bool writeValue(Object,const Property &,id);
// Scalar, bool, bounded ASCII names and explicit object-index arguments; exact reflected schema.
id invoke(Object,NSString *,NSDictionary *);
}
