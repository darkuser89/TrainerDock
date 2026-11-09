// SPDX-License-Identifier: GPL-3.0-only
#include "HouseFlipperMono.hpp"
#import "HouseFlipperLoop.h"
#include "../../_Shared/Managed/MetadataCache.hpp"
#include <dlfcn.h>
#include <atomic>
#include <tuple>
#include <memory>
#include <cmath>
#include <cstring>
#include <cfloat>
namespace hf {
API api={};
static std::atomic<void *> gameDomain{nullptr};
void *domain(){return gameDomain.load() ?: (api.domainGet ? api.domainGet() : nullptr);}
void setDomain(void *value){gameDomain=value;}
bool bind(){if(api.root)return true;if(!HFSupportedImages())return false;API a={};
#define LOAD(member,name) a.member=reinterpret_cast<decltype(a.member)>(dlsym(RTLD_DEFAULT,name));if(!a.member)return false;
 LOAD(getMethod,"mono_get_method");LOAD(methodClass,"mono_method_get_class");LOAD(virtualMethod,"mono_object_get_virtual_method");LOAD(root,"mono_get_root_domain");LOAD(domainGet,"mono_domain_get");LOAD(domainID,"mono_domain_get_id");LOAD(domainByID,"mono_domain_get_by_id");LOAD(domains,"mono_domain_foreach");LOAD(domainAssemblies,"mono_domain_assembly_foreach");LOAD(assemblyImage,"mono_assembly_get_image");LOAD(attach,"mono_thread_attach");LOAD(loaded,"mono_image_loaded");LOAD(guid,"mono_image_get_guid");LOAD(klass,"mono_class_from_name");LOAD(objectClass,"mono_object_get_class");LOAD(parent,"mono_class_get_parent");LOAD(method,"mono_class_get_method_from_name");LOAD(methods,"mono_class_get_methods");LOAD(methodName,"mono_method_get_name");LOAD(signature,"mono_method_signature");LOAD(params,"mono_signature_get_params");LOAD(paramCount,"mono_signature_get_param_count");LOAD(returnType,"mono_signature_get_return_type");LOAD(methodFlags,"mono_method_get_flags");LOAD(invoke,"mono_runtime_invoke");LOAD(unbox,"mono_object_unbox");LOAD(classType,"mono_class_get_type");LOAD(typeObject,"mono_type_get_object");LOAD(field,"mono_class_get_field_from_name");LOAD(fieldType,"mono_field_get_type");LOAD(kind,"mono_type_get_type");LOAD(typeName,"mono_type_get_name");LOAD(flags,"mono_field_get_flags");LOAD(vtable,"mono_class_vtable");LOAD(read,"mono_field_get_value");LOAD(write,"mono_field_set_value");LOAD(readStatic,"mono_field_static_get_value");LOAD(writeStatic,"mono_field_static_set_value");LOAD(arrayLength,"mono_array_length");LOAD(arrayAddress,"mono_array_addr_with_size");LOAD(strong,"mono_gchandle_new");LOAD(weak,"mono_gchandle_new_weakref");LOAD(target,"mono_gchandle_get_target");LOAD(freeHandle,"mono_gchandle_free");LOAD(utf8,"mono_string_to_utf8");LOAD(free,"mono_free");LOAD(classFromType,"mono_class_from_mono_type");LOAD(isEnum,"mono_class_is_enum");LOAD(enumBase,"mono_class_enum_basetype");LOAD(valueSize,"mono_class_value_size");
#undef LOAD
 Dl_info provider={};if(!dladdr((void *)a.root,&provider)||!provider.dli_fname||![[[NSString stringWithUTF8String:provider.dli_fname] stringByResolvingSymlinksInPath] isEqualToString:[[NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:@"Contents/Frameworks/libmonobdwgc-2.0.dylib"] stringByResolvingSymlinksInPath]])return false;
 if(!a.root())return false;api=a;return true;
}
void *image(const char *name){for(const char *suffix:{"",".dll",".exe"}){std::string n=std::string(name)+suffix;if(void *i=api.loaded(n.c_str()))return i;}return nullptr;}
Klass type(const char *space,const char *name,const char *imageName){using Key=std::tuple<std::string,std::string,std::string>;static mht::managed::MetadataCache<Key,Klass,256> cache;return cache.get(domain(),(uintptr_t)api.klass,Key{imageName,space,name},[&]()->Klass{void *i=image(imageName);Klass k=i?api.klass(i,space,name):nullptr;if(!k)throw std::runtime_error(std::string("Ursprünglicher Typ fehlt: ")+space+"."+name);return k;});}
Field field(Klass k,const char *name){using Key=std::pair<Klass,std::string>;static mht::managed::MetadataCache<Key,Field> cache;return cache.get(domain(),(uintptr_t)api.field,Key{k,name},[&]()->Field{for(;k;k=api.parent(k))if(Field f=api.field(k,name))return f;throw std::runtime_error(std::string("Ursprüngliches Feld fehlt: ")+name);});}
Method method(Klass k,const char *name,int count){using Key=std::tuple<Klass,std::string,int>;static mht::managed::MetadataCache<Key,Method> cache;return cache.get(domain(),(uintptr_t)api.method,Key{k,name,count},[&]()->Method{for(;k;k=api.parent(k))if(Method m=api.method(k,name,count)){if(api.paramCount(api.signature(m))!=(uint32_t)count)throw std::runtime_error("Die ursprüngliche Aufrufsignatur weicht ab.");return m;}throw std::runtime_error(std::string("Ursprüngliche Methode fehlt: ")+name);});}
std::string typeName(void *t){if(!t)return {};static mht::managed::MetadataCache<void *,std::shared_ptr<std::string>> cache;auto result=cache.get(domain(),(uintptr_t)api.typeName,t,[&]()->std::shared_ptr<std::string>{char *name=api.typeName(t);if(!name)return {};auto value=std::make_shared<std::string>(name);api.free(name);return value;});return result?*result:std::string{};}
Method typedMethod(Klass k,const char *name,const char *result,std::initializer_list<const char *> parameters,bool isStatic){
 using Key=std::tuple<Klass,std::string,std::string,std::string,bool>;static mht::managed::MetadataCache<Key,Method,512>cache;
 std::string parameterKey;for(const char *parameter:parameters){parameterKey+=parameter;parameterKey+='\n';}
 return cache.get(domain(),(uintptr_t)api.methods,Key{k,name,result,parameterKey,isStatic},[&]()->Method{
  for(Klass owner=k;owner;owner=api.parent(owner)){void *iterator=nullptr;
   while(Method m=api.methods(owner,&iterator)){
    const char *methodName=api.methodName(m);if(!methodName||strcmp(methodName,name))continue;
    void *s=api.signature(m);uint32_t impl=0;
    if(api.paramCount(s)!=parameters.size()||typeName(api.returnType(s))!=result||bool(api.methodFlags(m,&impl)&16)!=isStatic)continue;
    void *iter=nullptr;bool matches=true;for(const char *parameter:parameters)if(typeName(api.params(s,&iter))!=parameter){matches=false;break;}
    if(matches)return m;
   }
  }throw std::runtime_error(std::string("Die ursprüngliche vollständige Methodensignatur fehlt: ")+name);
 });
}
Method tokenMethod(Klass expected,uint32_t token,const char *result,std::initializer_list<const char *>parameters,bool isStatic){
 using Key=std::tuple<Klass,uint32_t,std::string,std::string,bool>;static mht::managed::MetadataCache<Key,Method,128>cache;
 std::string parameterKey;for(const char *parameter:parameters){parameterKey+=parameter;parameterKey+='\n';}
 return cache.get(domain(),(uintptr_t)api.getMethod,Key{expected,token,result,parameterKey,isStatic},[&]()->Method{
  void *source=image("Assembly-CSharp");const char *guid=source?api.guid(source):nullptr;
  if(!guid||strcasecmp(guid,"67e7164a-b528-41e2-95db-3865ad4627f4")||(token>>24)!=6)throw std::runtime_error("Die ursprüngliche Methodenkennung ist nicht gebunden.");
  Method m=api.getMethod(source,token,nullptr);if(!m||api.methodClass(m)!=expected)throw std::runtime_error("Der ursprüngliche Tokenbesitzer weicht ab.");
  void *signature=api.signature(m);uint32_t impl=0;
  if(!signature||api.paramCount(signature)!=parameters.size()||typeName(api.returnType(signature))!=result||bool(api.methodFlags(m,&impl)&16)!=isStatic)throw std::runtime_error("Die ursprüngliche Tokensignatur weicht ab.");
  void *iterator=nullptr;for(const char *parameter:parameters)if(typeName(api.params(signature,&iterator))!=parameter)throw std::runtime_error("Die ursprünglichen Tokenparameter weichen ab.");return m;
 });
}

Object call(Method m,Object o,std::vector<void *> args){if(!m||api.paramCount(api.signature(m))!=args.size())throw std::runtime_error("Die ursprüngliche Argumentanzahl weicht ab.");uint32_t impl=0;if(bool(api.methodFlags(m,&impl)&16)==bool(o))throw std::runtime_error("Der ursprüngliche Methodenbesitzer weicht ab.");Object exception=nullptr;Object result=api.invoke(m,o,args.empty()?nullptr:args.data(),&exception);if(exception)throw std::runtime_error("Der ursprüngliche Mono-Aufruf wurde abgelehnt.");return result;}
std::string text(Object o){if(!o)return {};char *s=api.utf8(o);std::string r=s?s:"";if(s)api.free(s);return r;}
int scalarKind(Field f){auto t=api.fieldType(f);Klass k=api.classFromType(t);if(k&&api.isEnum(k))t=api.enumBase(k);return api.kind(t);}
size_t size(Field f){int k=scalarKind(f);switch(k){case 2:case 4:case 5:return 1;case 3:case 6:case 7:return 2;case 8:case 9:case 12:return 4;case 10:case 11:case 13:return 8;case 17:{Klass c=api.classFromType(api.fieldType(f));uint32_t alignment=0;int n=api.valueSize(c,&alignment);if(n>0&&n<=256)return (size_t)n;break;}}throw std::runtime_error("Nicht unterstützte native Wertanbindung.");}
std::vector<uint8_t> read(Object o,Klass k,Field f){std::vector<uint8_t>b(size(f));if(api.flags(f)&16){void *v=api.vtable(domain(),k);if(!v)throw std::runtime_error("Die ursprüngliche statische Tabelle fehlt.");api.readStatic(v,f,b.data());}else if(o)api.read(o,f,b.data());else throw std::runtime_error("Der ursprüngliche Besitzer fehlt.");return b;}
void write(Object o,Klass k,Field f,const std::vector<uint8_t>& b){if(b.size()!=size(f))throw std::runtime_error("Die native Wertgröße weicht ab.");if(api.flags(f)&16){void *v=api.vtable(domain(),k);if(!v)throw std::runtime_error("Die ursprüngliche statische Tabelle fehlt.");api.writeStatic(v,f,(void *)b.data());}else if(o)api.write(o,f,(void *)b.data());else throw std::runtime_error("Der ursprüngliche Besitzer fehlt.");}
Object ref(Object o,Klass k,const char *name){Field f=field(k,name);int kind=api.kind(api.fieldType(f));if(kind!=14&&kind!=18&&kind!=20&&kind!=21&&kind!=28&&kind!=29)throw std::runtime_error("Eine ursprüngliche Objektreferenz wurde erwartet.");Object value=nullptr;if(api.flags(f)&16){void *v=api.vtable(domain(),k);if(v)api.readStatic(v,f,&value);}else if(o)api.read(o,f,&value);return value;}
double number(Object o,Klass k,const char *name){Field f=field(k,name);auto b=read(o,k,f);switch(scalarKind(f)){case 2:return b[0]!=0;case 4:return *(int8_t *)b.data();case 5:return b[0];case 6:{int16_t n;memcpy(&n,b.data(),2);return n;}case 7:{uint16_t n;memcpy(&n,b.data(),2);return n;}case 8:{int32_t n;memcpy(&n,b.data(),4);return n;}case 9:{uint32_t n;memcpy(&n,b.data(),4);return n;}case 12:{float n;memcpy(&n,b.data(),4);return n;}case 13:{double n;memcpy(&n,b.data(),8);return n;}default:throw std::runtime_error("Nicht unterstützte Zahlenwertabfrage.");}}
std::vector<uint8_t> numeric(Field f,double value){if(!std::isfinite(value))throw std::runtime_error("Ein endlicher Zahlenwert ist erforderlich.");std::vector<uint8_t>b(size(f));switch(scalarKind(f)){case 2:b[0]=value!=0;break;case 8:{if(value<INT32_MIN||value>INT32_MAX||floor(value)!=value)throw std::runtime_error("Die Ganzzahl liegt außerhalb des gültigen Bereichs.");int32_t n=(int32_t)value;memcpy(b.data(),&n,4);break;}case 9:{if(value<0||value>UINT32_MAX||floor(value)!=value)throw std::runtime_error("Die Ganzzahl liegt außerhalb des gültigen Bereichs.");uint32_t n=(uint32_t)value;memcpy(b.data(),&n,4);break;}case 12:{if(value>FLT_MAX||value<-FLT_MAX)throw std::runtime_error("Die Fließkommazahl liegt außerhalb des gültigen Bereichs.");float n=(float)value;memcpy(b.data(),&n,4);break;}case 13:memcpy(b.data(),&value,8);break;default:throw std::runtime_error("Nicht unterstützte Zahlenwertänderung.");}return b;}
double unboxNumber(Object o,int kind){if(!o)throw std::runtime_error("Kein ursprünglicher Rückgabewert.");void *p=api.unbox(o);if(!p)throw std::runtime_error("Kein ursprünglicher Zahlenwert.");if(kind==2)return *(uint8_t *)p!=0;if(kind==12){float n;memcpy(&n,p,4);return n;}if(kind==13){double n;memcpy(&n,p,8);return n;}int32_t n;memcpy(&n,p,4);return n;}
}