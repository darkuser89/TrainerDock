// SPDX-License-Identifier: GPL-3.0-only
#pragma once
#import <Foundation/Foundation.h>
#include <cstdint>
#include <stdexcept>
#include <string>
#include <vector>
namespace tr {
using Object=void *;using Klass=void *;using Field=void *;using Method=void *;
struct API {
 void *(*root)();void *(*attach)(void *);void *(*loaded)(const char *);const char *(*guid)(void *);
 Klass (*klass)(void *,const char *,const char *);Klass (*objectClass)(Object);Klass (*parent)(Klass);
 Method (*method)(Klass,const char *,int);void *(*signature)(Method);void *(*params)(void *,void **);uint32_t (*paramCount)(void *);
 Object (*invoke)(Method,Object,void **,Object *);void *(*unbox)(Object);void *(*classType)(Klass);Object (*typeObject)(void *,void *);
 Field (*field)(Klass,const char *);void *(*fieldType)(Field);int (*kind)(void *);char *(*typeName)(void *);uint32_t (*flags)(Field);
 Klass (*classFromType)(void *);int (*isEnum)(Klass);void *(*enumBase)(Klass);
 void *(*vtable)(void *,Klass);void (*read)(Object,Field,void *);void (*write)(Object,Field,void *);void (*readStatic)(void *,Field,void *);void (*writeStatic)(void *,Field,void *);
 uintptr_t (*arrayLength)(Object);char *(*arrayAddress)(Object,int,uintptr_t);uint32_t (*strong)(Object,int);uint32_t (*weak)(Object,int);Object (*target)(uint32_t);void (*freeHandle)(uint32_t);
 char *(*utf8)(Object);void (*free)(void *);
} ;
extern API api;
bool bind();void *image(const char *name);Klass type(const char *space,const char *name,const char *image="Terraria");Field field(Klass,const char *);Method method(Klass,const char *,int);
Object call(Method,Object=nullptr,std::vector<void * > args={});std::string text(Object);std::string typeName(void *);size_t size(Field);
std::vector<uint8_t> read(Object,Klass,Field);void write(Object,Klass,Field,const std::vector<uint8_t>&);
Object ref(Object,Klass,const char *);double number(Object,Klass,const char *);std::vector<uint8_t> numeric(Field,double);double unboxNumber(Object,int kind=8);
struct Root {uint32_t handle=0;Root()=default;Root(Object o,bool weak=false){reset(o,weak);}~Root(){reset();}Root(const Root&)=delete;Root& operator=(const Root&)=delete;Root(Root&& o)noexcept:handle(o.handle){o.handle=0;}Root& operator=(Root&& o)noexcept{reset();handle=o.handle;o.handle=0;return *this;}Object get()const{return handle?api.target(handle):nullptr;}void reset(Object o=nullptr,bool weak=false){if(handle)api.freeHandle(handle);handle=o?(weak?api.weak(o,0):api.strong(o,0)):0;}};
}
