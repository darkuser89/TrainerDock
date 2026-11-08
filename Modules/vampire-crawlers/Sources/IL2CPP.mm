// SPDX-License-Identifier: GPL-3.0-only
#include "IL2CPP.hpp"
#import <Foundation/Foundation.h>
#import <dlfcn.h>
#import <mach-o/loader.h>
#include <cstring>
#include <cmath>
#include <limits>
#include <algorithm>
namespace vc {
API api={};
bool knownImage(const void *symbol,const uint8_t uuid[16]) {
    Dl_info info={};if(!symbol || !dladdr(symbol,&info))return false;
    auto h=(const mach_header_64 *)info.dli_fbase;
    if(!h || h->magic!=MH_MAGIC_64 || h->cputype!=CPU_TYPE_ARM64 || h->sizeofcmds>1048576)return false;
    auto p=(const uint8_t *)(h+1);size_t remaining=h->sizeofcmds;bool matched=false;
    for(uint32_t i=0;i<h->ncmds;i++){
        if(remaining<8)return false;auto c=(const load_command *)p;
        if(c->cmdsize<8 || c->cmdsize>remaining)return false;
        if(c->cmd==LC_UUID){if(matched || c->cmdsize!=sizeof(uuid_command) || memcmp(((const uuid_command *)c)->uuid,uuid,16))return false;matched=true;}
        p+=c->cmdsize;remaining-=c->cmdsize;
    }
    return matched && !remaining;
}
bool bindAPI() {
    if(api.invoke)return true;
    NSString *path=[NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:@"Contents/Frameworks/GameAssembly.dylib"];
    void *library=dlopen(path.fileSystemRepresentation,RTLD_NOW|RTLD_NOLOAD);
    if(!library)return false;
    API next={};bool valid=true;
#define LOAD(member,symbol) next.member=(decltype(next.member))dlsym(library,symbol);valid=valid && next.member
    LOAD(domainGet,"il2cpp_domain_get");LOAD(assemblies,"il2cpp_domain_get_assemblies");
    LOAD(assemblyImage,"il2cpp_assembly_get_image");LOAD(imageName,"il2cpp_image_get_name");LOAD(classFromName,"il2cpp_class_from_name");
    LOAD(objectClass,"il2cpp_object_get_class");LOAD(parent,"il2cpp_class_get_parent");LOAD(methods,"il2cpp_class_get_methods");
    LOAD(methodName,"il2cpp_method_get_name");LOAD(parameterCount,"il2cpp_method_get_param_count");LOAD(parameterType,"il2cpp_method_get_param");
    LOAD(returnType,"il2cpp_method_get_return_type");LOAD(methodFlags,"il2cpp_method_get_flags");
    LOAD(fields,"il2cpp_class_get_fields");LOAD(findField,"il2cpp_class_get_field_from_name");LOAD(fieldName,"il2cpp_field_get_name");
    LOAD(fieldType,"il2cpp_field_get_type");LOAD(fieldFlags,"il2cpp_field_get_flags");LOAD(fieldOffset,"il2cpp_field_get_offset");
    LOAD(fieldRead,"il2cpp_field_get_value");LOAD(fieldWrite,"il2cpp_field_set_value");LOAD(staticRead,"il2cpp_field_static_get_value");
    LOAD(classType,"il2cpp_class_get_type");LOAD(typeClass,"il2cpp_class_from_type");LOAD(typeName,"il2cpp_type_get_name");LOAD(typeKind,"il2cpp_type_get_type");
    LOAD(enumType,"il2cpp_class_is_enum");LOAD(enumBase,"il2cpp_class_enum_basetype");
    LOAD(valueType,"il2cpp_class_is_valuetype");LOAD(valueSize,"il2cpp_class_value_size");LOAD(typeObject,"il2cpp_type_get_object");
    LOAD(box,"il2cpp_value_box");LOAD(unbox,"il2cpp_object_unbox");LOAD(invoke,"il2cpp_runtime_invoke_convert_args");
    LOAD(arrayNew,"il2cpp_array_new");LOAD(arrayLength,"il2cpp_array_length");LOAD(arrayHeader,"il2cpp_array_object_header_size");LOAD(objectHeader,"il2cpp_object_header_size");
    LOAD(strong,"il2cpp_gchandle_new");LOAD(weak,"il2cpp_gchandle_new_weakref");LOAD(target,"il2cpp_gchandle_get_target");LOAD(freeHandle,"il2cpp_gchandle_free");
    LOAD(barrier,"il2cpp_gc_wbarrier_set_field");LOAD(freeMemory,"il2cpp_free");LOAD(currentThread,"il2cpp_thread_current");LOAD(attach,"il2cpp_thread_attach");LOAD(icall,"il2cpp_resolve_icall");
    LOAD(stringLength,"il2cpp_string_length");LOAD(stringChars,"il2cpp_string_chars");
#undef LOAD
    const uint8_t uuid[16]={0x11,0x47,0xa3,0x76,0x2f,0x50,0x37,0x78,0x8c,0x94,0xeb,0x03,0xcd,0xe7,0xc4,0x01};
    valid=valid && knownImage((const void *)next.domainGet,uuid);
    dlclose(library);if(valid)api=next;return valid;
}
Class klass(const char *assembly,const char *space,const char *name) {
    void *domain=api.domainGet();if(!domain)return nullptr;
    size_t count=0;auto assemblies=api.assemblies(domain,&count);if(count>1024)return nullptr;
    for(size_t i=0;i<count;i++){
        void *image=api.assemblyImage(assemblies[i]);const char *label=image ? api.imageName(image) : nullptr;
        if(label && !strcmp(label,assembly))return api.classFromName(image,space,name);
    }
    return nullptr;
}
Method method(Class type,const char *name,int count) {
    for(unsigned depth=0;type && depth<32;depth++,type=api.parent(type)){
        void *iterator=nullptr;Method result=nullptr;
        while(Method m=api.methods(type,&iterator))if(!strcmp(api.methodName(m),name) && (int)api.parameterCount(m)==count){
            if(result)throw std::runtime_error(std::string("Ursprüngliche Methode nicht eindeutig: ")+name);
            result=m;
        }
        if(result)return result;
    }
    return nullptr;
}
Field field(Class type,const char *name) {
    for(unsigned n=0;type && n<32;n++,type=api.parent(type))if(Field f=api.findField(type,name))return f;
    return nullptr;
}
std::string typeName(const void *type){char *name=type ? api.typeName(type) : nullptr;std::string result=name ? name : "";if(name)api.freeMemory(name);return result;}
Object reference(Object object,const char *name){
    if(!object)return nullptr;Field f=field(api.objectClass(object),name);
    Class member=f ? api.typeClass(api.fieldType(f)) : nullptr;
    if(!member || api.valueType(member))return nullptr;
    Object value=nullptr;api.fieldRead(object,f,&value);return value;
}
bool boolean(Object object,const char *name){Field f=object ? field(api.objectClass(object),name) : nullptr;if(!f || api.typeKind(api.fieldType(f))!=2)throw std::runtime_error("Das ursprüngliche Wahrheitswertfeld ist nicht verfügbar.");bool value=false;api.fieldRead(object,f,&value);return value;}
void boolean(Object object,const char *name,bool value){Field f=object ? field(api.objectClass(object),name) : nullptr;if(!f || api.typeKind(api.fieldType(f))!=2)throw std::runtime_error("Das ursprüngliche Wahrheitswertfeld ist nicht verfügbar.");api.fieldWrite(object,f,&value);}
Object call(Method m,Object target,const std::vector<Object>& args){
    if(!m || api.parameterCount(m)!=args.size())throw std::runtime_error("Die ursprüngliche Methoden- oder Argumentanbindung ist nicht verfügbar.");
    std::vector<Root> roots;roots.reserve(args.size()+1);if(target)roots.emplace_back(target);
    for(Object object:args)if(object)roots.emplace_back(object);
    Object exception=nullptr;Object result=api.invoke(m,target,const_cast<Object *>(args.data()),(int)args.size(),&exception);
    if(exception)throw std::runtime_error("Die ursprüngliche verwaltete Methode hat den Aufruf abgelehnt.");return result;
}
template<class T> double decode(const void *p){T value={};memcpy(&value,p,sizeof(value));return (double)value;}
double number(Object object){
    if(!object)throw std::runtime_error("Der native Zahlenrückgabewert fehlt.");
    Class k=api.objectClass(object);const void *type=api.enumType(k) ? api.enumBase(k) : api.classType(k);void *p=api.unbox(object);
    switch(api.typeKind(type)){
        case 2:return decode<uint8_t>(p);case 4:return decode<int8_t>(p);case 5:return decode<uint8_t>(p);
        case 6:return decode<int16_t>(p);case 7:return decode<uint16_t>(p);case 8:return decode<int32_t>(p);case 9:return decode<uint32_t>(p);
        case 10:return decode<int64_t>(p);case 11:return decode<uint64_t>(p);case 12:return decode<float>(p);case 13:return decode<double>(p);
        default:throw std::runtime_error("Unerwarteter nativer Zahlentyp: "+typeName(type));
    }
}
template<class T> Object boxAs(Class type,double value){
    if(!std::isfinite(value) || value<(double)std::numeric_limits<T>::lowest() || value>(double)std::numeric_limits<T>::max()
       || (std::numeric_limits<T>::is_integer && std::floor(value)!=value))throw std::runtime_error("Das Zahlenargument liegt außerhalb des nativen Wertebereichs.");
    T native=(T)value;return api.box(type,&native);
}
Object boxNumber(const void *type,double value){
    Class k=api.typeClass(type);std::string name=typeName(type);
    if(!k)throw std::runtime_error("Die ursprüngliche Parameterklasse fehlt.");
    // Reflection conversion accepts the boxed underlying value for Nullable<T>.
    if(name.find("System.Nullable")!=std::string::npos){Field underlying=field(k,"value");if(!underlying)underlying=field(k,"value_");if(!underlying)throw std::runtime_error("Die Datenanordnung des optionalen Werts ist nicht verfügbar.");type=api.fieldType(underlying);k=api.typeClass(type);}
    int kind=api.typeKind(api.enumType(k) ? api.enumBase(k) : type);
    switch(kind){
        case 2:{if(value!=0 && value!=1)throw std::runtime_error("Ungültiges Wahrheitswertargument.");bool v=value!=0;return api.box(k,&v);}
        case 8:return boxAs<int32_t>(k,value);case 9:return boxAs<uint32_t>(k,value);
        case 10:return boxAs<int64_t>(k,value);case 11:return boxAs<uint64_t>(k,value);
        case 12:return boxAs<float>(k,value);case 13:return boxAs<double>(k,value);
        default:throw std::runtime_error("Nicht unterstützter ursprünglicher Parametertyp: "+name);
    }
}
Object numericCall(Method m,Object target,const std::vector<double>& values){
    if(!m || api.parameterCount(m)!=values.size())throw std::runtime_error("Die ursprüngliche Zahlenwertmethode ist nicht verfügbar.");
    std::vector<Root> roots;std::vector<Object> args;roots.reserve(values.size());args.reserve(values.size());
    for(size_t i=0;i<values.size();i++){roots.emplace_back(boxNumber(api.parameterType(m,(uint32_t)i),values[i]));args.push_back(roots.back().get());}
    return call(m,target,args);
}
double getNumber(Object object,const char *getter){if(!object)throw std::runtime_error("Besitzer fehlt für "+std::string(getter));Method m=method(api.objectClass(object),getter,0);if(!m)throw std::runtime_error("Ursprüngliche Abfrage fehlt: "+std::string(getter)+" on "+typeName(api.classType(api.objectClass(object))));return number(call(m,object));}
void invokeNumber(Object object,const char *name,double value,bool notify){numericCall(method(api.objectClass(object),name,2),object,{value,notify ? 1.0 : 0.0});}
bool alive(Object object){
    if(!object)return false;Field cached=field(api.objectClass(object),"m_CachedPtr");if(!cached)return true;
    if(typeName(api.fieldType(cached))!="System.IntPtr")return false;
    uintptr_t pointer=0;api.fieldRead(object,cached,&pointer);return pointer!=0;
}
std::vector<Object> findObjects(Class type,bool assets){
    if(!type)return {};
    Class owner=klass("UnityEngine.CoreModule.dll","UnityEngine",assets ? "Resources" : "Object");
    Method find=method(owner,assets ? "FindObjectsOfTypeAll" : "FindObjectsOfType",assets ? 1 : 2);
    if(!find)return {};
    Root reflection(api.typeObject(api.classType(type)));std::vector<Object> args={reflection.get()};Root inactive;
    if(!assets){inactive.reset(boxNumber(api.parameterType(find,1),0));args.push_back(inactive.get());}
    Root found(call(find,nullptr,args));if(!found.get())return {};
    size_t count=api.arrayLength(found.get()),header=api.arrayHeader();if(count>4096 || header<16 || header>128)return {};
    std::vector<Object> result;
    for(size_t i=0;i<count;i++){Object object=nullptr;memcpy(&object,(char *)found.get()+header+i*sizeof(Object),sizeof(Object));if(alive(object))result.push_back(object);}
    return result;
}
std::vector<Object> list(Object object,size_t maximum){
    if(!object)return {};Field size=field(api.objectClass(object),"_size");Object array=reference(object,"_items");
    if(!size || api.typeKind(api.fieldType(size))!=8 || !array)return {};
    int32_t count=0;api.fieldRead(object,size,&count);if(count<0 || (size_t)count>maximum || (uintptr_t)count>api.arrayLength(array))return {};
    std::vector<Object> result;
    for(int i=0;i<count;i++){Object entry=nullptr;memcpy(&entry,(char *)array+api.arrayHeader()+i*sizeof(Object),sizeof(Object));if(entry)result.push_back(entry);}
    return result;
}
std::string text(Object object){
    if(!object || typeName(api.classType(api.objectClass(object)))!="System.String")return "";
    int32_t size=api.stringLength(object);if(size<0 || size>2048)return "";
    NSString *s=[[NSString alloc] initWithCharacters:(const unichar *)api.stringChars(object) length:(NSUInteger)size];
    return s.UTF8String ?: "";
}
Root::Root(Object object,bool weak){reset(object,weak);}
Root::~Root(){reset();}
Root::Root(Root&& other) noexcept:handle(other.handle){other.handle=0;}
Root& Root::operator=(Root&& other) noexcept{if(this!=&other){reset();handle=other.handle;other.handle=0;}return *this;}
Object Root::get()const{return handle ? api.target(handle) : nullptr;}
void Root::reset(Object object,bool weak){if(handle)api.freeHandle(handle);handle=object ? (weak ? api.weak(object,false) : api.strong(object,false)) : 0;}
}
