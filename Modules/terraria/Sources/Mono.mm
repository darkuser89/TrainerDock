// SPDX-License-Identifier: GPL-3.0-only
#include "Mono.hpp"
#include <dlfcn.h>
#include <cmath>
#include <cstring>
namespace tr {
API api={};
bool bind(){if(api.root)return true;API a={};
#define LOAD(member,name) a.member=reinterpret_cast<decltype(a.member)>(dlsym(RTLD_DEFAULT,name));if(!a.member)return false;
 LOAD(root,"mono_get_root_domain");LOAD(attach,"mono_thread_attach");LOAD(loaded,"mono_image_loaded");LOAD(guid,"mono_image_get_guid");LOAD(klass,"mono_class_from_name");LOAD(objectClass,"mono_object_get_class");LOAD(parent,"mono_class_get_parent");LOAD(method,"mono_class_get_method_from_name");LOAD(signature,"mono_method_signature");LOAD(params,"mono_signature_get_params");LOAD(paramCount,"mono_signature_get_param_count");LOAD(invoke,"mono_runtime_invoke");LOAD(unbox,"mono_object_unbox");LOAD(classType,"mono_class_get_type");LOAD(typeObject,"mono_type_get_object");LOAD(field,"mono_class_get_field_from_name");LOAD(fieldType,"mono_field_get_type");LOAD(kind,"mono_type_get_type");LOAD(typeName,"mono_type_get_name");LOAD(flags,"mono_field_get_flags");LOAD(vtable,"mono_class_vtable");LOAD(read,"mono_field_get_value");LOAD(write,"mono_field_set_value");LOAD(readStatic,"mono_field_static_get_value");LOAD(writeStatic,"mono_field_static_set_value");LOAD(arrayLength,"mono_array_length");LOAD(arrayAddress,"mono_array_addr_with_size");LOAD(strong,"mono_gchandle_new");LOAD(weak,"mono_gchandle_new_weakref");LOAD(target,"mono_gchandle_get_target");LOAD(freeHandle,"mono_gchandle_free");LOAD(utf8,"mono_string_to_utf8");LOAD(free,"mono_free");LOAD(classFromType,"mono_class_from_mono_type");LOAD(isEnum,"mono_class_is_enum");LOAD(enumBase,"mono_class_enum_basetype");
#undef LOAD
 if(!a.root())return false;api=a;return true;
}
void *image(const char *name){for(const char *suffix:{"",".dll",".exe"}){std::string n=std::string(name)+suffix;if(void *i=api.loaded(n.c_str()))return i;}return nullptr;}
Klass type(const char *space,const char *name,const char *imageName){void *i=image(imageName);Klass k=i?api.klass(i,space,name):nullptr;if(!k)throw std::runtime_error(std::string("Ursprünglicher Typ fehlt: ")+space+"."+name);return k;}
Field field(Klass k,const char *name){for(;k;k=api.parent(k))if(Field f=api.field(k,name))return f;throw std::runtime_error(std::string("Ursprüngliches Feld fehlt: ")+name);}
Method method(Klass k,const char *name,int count){for(;k;k=api.parent(k))if(Method m=api.method(k,name,count))return m;throw std::runtime_error(std::string("Ursprüngliche Methode fehlt: ")+name);}
Object call(Method m,Object o,std::vector<void *> args){Object exception=nullptr;Object result=api.invoke(m,o,args.empty()?nullptr:args.data(),&exception);if(exception)throw std::runtime_error("Der ursprüngliche Mono-Aufruf wurde abgelehnt.");return result;}
std::string text(Object o){if(!o)return {};char *s=api.utf8(o);std::string r=s?s:"";if(s)api.free(s);return r;}
std::string typeName(void *t){char *s=api.typeName(t);std::string r=s?s:"";if(s)api.free(s);return r;}
int scalarKind(Field f){auto t=api.fieldType(f);Klass k=api.classFromType?api.classFromType(t):nullptr;if(k && api.isEnum && api.isEnum(k))t=api.enumBase(k);return api.kind(t);}
size_t size(Field f){int k=scalarKind(f);if(k==2)return 1;if(k==8||k==9||k==12)return 4;if(k==10||k==11||k==13)return 8;if(typeName(api.fieldType(f))=="System.TimeSpan")return 8;throw std::runtime_error("Nicht unterstützte native Zahlenwertanbindung.");}
std::vector<uint8_t> read(Object o,Klass k,Field f){std::vector<uint8_t> b(size(f));if(api.flags(f)&16)api.readStatic(api.vtable(api.root(),k),f,b.data());else if(o)api.read(o,f,b.data());else throw std::runtime_error("Der ursprüngliche Besitzer fehlt.");return b;}
void write(Object o,Klass k,Field f,const std::vector<uint8_t>& b){if(b.size()!=size(f))throw std::runtime_error("Die native Zahlenwertanbindung stimmt nicht überein.");if(api.flags(f)&16)api.writeStatic(api.vtable(api.root(),k),f,(void *)b.data());else if(o)api.write(o,f,(void *)b.data());else throw std::runtime_error("Der ursprüngliche Besitzer fehlt.");}
Object ref(Object o,Klass k,const char *name){Field f=field(k,name);int kind=api.kind(api.fieldType(f));if(kind!=14 && kind!=18 && kind!=20 && kind!=21 && kind!=28 && kind!=29)throw std::runtime_error("Eine ursprüngliche Objektreferenz wurde erwartet.");Object value=nullptr;if(api.flags(f)&16)api.readStatic(api.vtable(api.root(),k),f,&value);else if(o)api.read(o,f,&value);return value;}
double number(Object o,Klass k,const char *name){Field f=field(k,name);auto b=read(o,k,f);switch(scalarKind(f)){case 2:return b[0]!=0;case 8:{int32_t n;memcpy(&n,b.data(),4);return n;}case 9:{uint32_t n;memcpy(&n,b.data(),4);return n;}case 12:{float n;memcpy(&n,b.data(),4);return n;}case 13:{double n;memcpy(&n,b.data(),8);return n;}default:throw std::runtime_error("Nicht unterstützte Zahlenwertabfrage.");}}
std::vector<uint8_t> numeric(Field f,double value){if(!std::isfinite(value))throw std::runtime_error("Ein endlicher Zahlenwert ist erforderlich.");std::vector<uint8_t>b(size(f));switch(scalarKind(f)){case 2:b[0]=value!=0;break;case 8:case 9:{if(value<INT32_MIN || value>INT32_MAX || floor(value)!=value)throw std::runtime_error("Die Ganzzahl liegt außerhalb des gültigen Bereichs.");int32_t n=(int32_t)value;memcpy(b.data(),&n,4);break;}case 12:{float n=(float)value;memcpy(b.data(),&n,4);break;}case 13:memcpy(b.data(),&value,8);break;default:throw std::runtime_error("Nicht unterstützte Zahlenwertänderung.");}return b;}
double unboxNumber(Object o,int kind){if(!o)throw std::runtime_error("Kein ursprünglicher Rückgabewert.");void *p=api.unbox(o);if(kind==2)return *(uint8_t *)p!=0;if(kind==12)return *(float *)p;if(kind==13)return *(double *)p;return *(int32_t *)p;}
}
