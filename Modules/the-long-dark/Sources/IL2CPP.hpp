// SPDX-License-Identifier: GPL-3.0-only
#pragma once
#include <cstdint>
#include <string>
#include <vector>
#include <stdexcept>
namespace tld {
using Object=void *;
using Class=void *;
using Method=const void *;
using Field=void *;
using Handle=uintptr_t;
struct API {
    void *(*domainGet)(); const void **(*assemblies)(void *,size_t *);
    void *(*assemblyImage)(const void *); const char *(*imageName)(void *);
    Class (*classFromName)(void *,const char *,const char *);
    Class (*objectClass)(Object); Class (*parent)(Class);
    Method (*methods)(Class,void **); const char *(*methodName)(Method);
    uint32_t (*parameterCount)(Method); const void *(*parameterType)(Method,uint32_t);
    const void *(*returnType)(Method); uint32_t (*methodFlags)(Method,uint32_t *);
    Field (*fields)(Class,void **); Field (*findField)(Class,const char *);
    const char *(*fieldName)(Field); const void *(*fieldType)(Field);
    int (*fieldFlags)(Field); size_t (*fieldOffset)(Field);
    void (*fieldRead)(Object,Field,void *); void (*fieldWrite)(Object,Field,void *);
    void (*staticRead)(Field,void *); void (*staticWrite)(Field,void *);
    const void *(*classType)(Class); Class (*typeClass)(const void *);
    bool (*enumType)(Class); const void *(*enumBase)(Class);
    char *(*typeName)(const void *); int (*typeKind)(const void *);
    bool (*valueType)(Class); int32_t (*valueSize)(Class,uint32_t *);
    Object (*typeObject)(const void *); Object (*box)(Class,void *); void *(*unbox)(Object);
    Object (*invoke)(Method,Object,Object *,int,Object *);
    Object (*arrayNew)(Class,uintptr_t); uintptr_t (*arrayLength)(Object);
    uint32_t (*arrayHeader)(); uint32_t (*objectHeader)();
    Handle (*strong)(Object,bool); Handle (*weak)(Object,bool);
    Object (*target)(Handle); void (*freeHandle)(Handle);
    void (*barrier)(Object,void **,Object); void (*freeMemory)(void *);
    void *(*currentThread)(); void *(*attach)(void *); const void *(*icall)(const char *);
    int32_t (*stringLength)(Object); const uint16_t *(*stringChars)(Object);
    Class (*elementClass)(Class);Object (*stringNew)(const char *);
    void (*fieldWriteObject)(Object,Field,Object);
};
extern API api;
bool bindAPI();
bool knownImage(const void *,const uint8_t[16]);
bool runtimeImagesMatch(const char *profile,const uint8_t main[16],const uint8_t game[16],const uint8_t unity[16]);
bool runtimeMainImageMatches(uint32_t fileType,const char *loadedPath,const char *targetPath);
Class klass(const char *assembly,const char *space,const char *name);
Method method(Class,const char *name,int count);
Field field(Class,const char *name);
std::string typeName(const void *type);
Object reference(Object,const char *name);
bool boolean(Object,const char *name);
void boolean(Object,const char *name,bool);
Object call(Method,Object,const std::vector<Object>& args={});
double number(Object);
Object boxNumber(const void *type,double value);
Object numericCall(Method,Object,const std::vector<double>& args);
double getNumber(Object,const char *getter);
void invokeNumber(Object,const char *name,double,bool notify=true);
bool alive(Object);
std::vector<Object> findObjects(Class,bool assets=false);
std::vector<Object> list(Object,size_t maximum=4096);
std::string text(Object);
struct Root {
    Handle handle=0;
    Root()=default;
    explicit Root(Object object,bool weak=false);
    ~Root(); Root(const Root&)=delete; Root& operator=(const Root&)=delete;
    Root(Root&&) noexcept; Root& operator=(Root&&) noexcept;
    Object get() const; void reset(Object object=nullptr,bool weak=false);
};
}
