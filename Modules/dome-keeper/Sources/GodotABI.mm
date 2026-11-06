// SPDX-License-Identifier: GPL-3.0-only
// Minimal binder for Godot's public 4.3 C extension ABI. ABI signatures verified
// against https://github.com/godotengine/godot/blob/4.3/core/extension/gdextension_interface.h
// No engine code, vtables, executable pages or protection settings are patched.
#import "GodotABI.h"
#import "DomeScript.hpp"
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <dlfcn.h>
#import <os/log.h>
#include <initializer_list>
#include <vector>
#include <cstring>
#include <memory>
#include <cstdint>
#include "GodotBindings.h"
namespace {
using Constructor=void (*)(void *,const void *);
using Destructor=void (*)(void *);
struct CallError {int32_t error,argument,expected;};
struct CustomCallable {
    void *userdata,*token;uint64_t objectID;
    void (*call)(void *,const void *const *,int64_t,void *,CallError *);
    uint8_t (*valid)(void *);void (*free)(void *);
    uint32_t (*hash)(void *);uint8_t (*equal)(void *,void *);uint8_t (*less)(void *,void *);
    void (*toString)(void *,uint8_t *,void *);int64_t (*argumentCount)(void *,uint8_t *);
};
struct API {
    void (*newNil)(void *);void (*copy)(void *,const void *);void (*destroy)(void *);
    void (*call)(void *,const void *,const void *const *,int64_t,void *,CallError *);
    int32_t (*type)(const void *);Constructor (*from)(int32_t);Constructor (*to)(int32_t);
    void (*stringNew)(void *,const char *);int64_t (*stringUTF8)(const void *,char *,int64_t);
    void (*nameNew)(void *,const char *,uint8_t);Destructor (*destructor)(int32_t);
    void *(*construct)(const void *);void *(*singleton)(const void *);
    void (*callable)(void *,CustomCallable *);
} api={};
uintptr_t imageBase;
bool attempted=false,bound=false;
NSString *failure=@"Warte auf die native Godot-Anbindung.";
void *address(const char *name) {
    for(const auto &binding:bindings)if(!strcmp(binding.name,name))return (void *)(imageBase+binding.rva);
    return nullptr;
}
bool bind() {
    if(attempted)return bound;attempted=true;
    const mach_header_64 *header=nullptr;
    for(uint32_t i=0;i<_dyld_image_count();i++){
        const auto *candidate=(const mach_header_64 *)_dyld_get_image_header(i);
        if(candidate && candidate->magic==MH_MAGIC_64 && candidate->cputype==CPU_TYPE_ARM64 && candidate->filetype==MH_EXECUTE){header=candidate;break;}
    }
    if(!header){os_log_error(OS_LOG_DEFAULT,"TrainerDock Dome: no native executable image found");return false;}
    const uint8_t *cursor=(const uint8_t *)(header+1);bool matches=false;
    const uint8_t uuid[]={0x65,0x16,0xab,0x35,0xbd,0xeb,0x3c,0xcc,0x84,0xdf,0x29,0xd4,0x4a,0x76,0xc5,0xd5};
    if(header->sizeofcmds>1024*1024 || header->ncmds>4096)return false;
    const uint8_t *end=cursor+header->sizeofcmds;
    for(uint32_t i=0;i<header->ncmds;i++){
        if(cursor+sizeof(load_command)>end)return false;
        const auto *command=(const load_command *)cursor;
        if(command->cmdsize<sizeof(load_command) || command->cmdsize>(uintptr_t)(end-cursor))return false;
        if(command->cmd==LC_UUID && command->cmdsize==sizeof(uuid_command))matches=!memcmp(((const uuid_command *)cursor)->uuid,uuid,16);
        cursor+=command->cmdsize;
    }
    if(!matches){os_log_error(OS_LOG_DEFAULT,"TrainerDock Dome: loaded main image identity mismatch");return false;}
    imageBase=(uintptr_t)header;
    for(const auto &binding:bindings)if(memcmp((void *)(imageBase+binding.rva),binding.prefix,16)){
        failure=@"Godot-ABI-Prüfung fehlgeschlagen. Trainer gesperrt.";os_log_error(OS_LOG_DEFAULT,"TrainerDock Dome: ABI prefix mismatch %{public}s",binding.name);return false;
    }
#define DK_LOAD(field,name) api.field=reinterpret_cast<decltype(api.field)>(address(name))
    DK_LOAD(newNil,"variant_new_nil");DK_LOAD(copy,"variant_new_copy");DK_LOAD(destroy,"variant_destroy");
    DK_LOAD(call,"variant_call");DK_LOAD(type,"variant_get_type");DK_LOAD(from,"get_variant_from_type_constructor");DK_LOAD(to,"get_variant_to_type_constructor");
    DK_LOAD(stringNew,"string_new_with_utf8_chars");DK_LOAD(stringUTF8,"string_to_utf8_chars");DK_LOAD(nameNew,"string_name_new_with_latin1_chars");
    DK_LOAD(destructor,"variant_get_ptr_destructor");DK_LOAD(construct,"classdb_construct_object");DK_LOAD(singleton,"global_get_singleton");DK_LOAD(callable,"callable_custom_create2");
#undef DK_LOAD
    bound=true;os_log(OS_LOG_DEFAULT,"TrainerDock Dome: native ABI verified");return true;
}
struct Name {
    alignas(8) uint8_t bytes[8]={};
    explicit Name(const char *name){api.nameNew(bytes,name,0);}
    ~Name(){api.destructor(21)(bytes);}
};
struct Value {
    alignas(8) uint8_t bytes[32]={};
    Value(){api.newNil(bytes);}
    Value(Value &&other){api.copy(bytes,other.bytes);}
    Value(const Value &other){api.copy(bytes,other.bytes);}
    Value &operator=(const Value &)=delete;
    ~Value(){api.destroy(bytes);}
    explicit Value(int64_t value):Value(){api.from(2)(bytes,&value);}
    explicit Value(double value):Value(){api.from(3)(bytes,&value);}
    explicit Value(bool value):Value(){uint8_t b=value;api.from(1)(bytes,&b);}
    explicit Value(const char *text):Value(){
        alignas(8) uint8_t string[8]={};api.stringNew(string,text);api.from(4)(bytes,string);api.destructor(4)(string);
    }
    static Value object(void *object){Value v;api.from(24)(v.bytes,&object);return v;}
    int64_t integer()const {int64_t v=0;if(api.type(bytes)==2)api.to(2)(&v,bytes);return v;}
    bool boolean()const {uint8_t v=0;if(api.type(bytes)==1)api.to(1)(&v,bytes);return v;}
    NSString *text()const {
        if(api.type(bytes)!=4)return nil;
        alignas(8) uint8_t string[8]={};api.to(4)(string,bytes);int64_t length=api.stringUTF8(string,nullptr,0);
        NSString *result=nil;
        if(length>=0 && length<=65536){std::vector<char> buffer(length+1);api.stringUTF8(string,buffer.data(),length);result=[[NSString alloc]initWithBytes:buffer.data() length:length encoding:NSUTF8StringEncoding];}
        api.destructor(4)(string);return result;
    }
};
Value call(Value &object,const char *method,std::initializer_list<const Value *> args={},bool *ok=nullptr) {
    Name name(method);std::vector<const void *> pointers;for(auto *value:args)pointers.push_back(value->bytes);
    Value result;api.destroy(result.bytes);CallError error={};
    api.call(object.bytes,name.bytes,pointers.data(),pointers.size(),result.bytes,&error);
    if(ok)*ok=error.error==0;
    return result;
}
// Process-lifetime resource: Godot tears down Variant dispatch before dylib exit.
// Do not call engine destructors from C++ static destruction after shutdown.
Value *script=nullptr;
bool ensureScript() {
    if(script)return true;
    Name name("GDScript");void *raw=api.construct(name.bytes);if(!raw){failure=@"Godot-Scriptklasse nicht verfügbar.";return false;}
    Value resource=Value::object(raw),source(DKScriptSource);bool ok=false;
    call(resource,"set_source_code",{&source},&ok);if(!ok){failure=@"Trainer-Script konnte nicht eingebunden werden.";return false;}
    Value reload=call(resource,"reload",{},&ok);
    if(!ok || api.type(reload.bytes)!=2 || reload.integer()!=0){failure=@"Trainer-Script wird von Godot nicht akzeptiert.";return false;}
    Value instance=call(resource,"new",{},&ok);
    if(!ok || api.type(instance.bytes)!=24){failure=@"Trainer-Scriptinstanz fehlt.";return false;}
    script=new Value(std::move(instance));return true;
}
NSDictionary *json(Value &value){NSString *text=value.text();NSData *data=[text dataUsingEncoding:NSUTF8StringEncoding];id result=data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL] : nil;return [result isKindOfClass:NSDictionary.class] ? result : @{};}
void callback(void *data,const void *const *args,int64_t count,void *result,CallError *error) {
    (void)args;(void)count;api.destroy(result);api.newNil(result);*error={0,0,0};
    static bool reported=false;if(!reported){reported=true;os_log(OS_LOG_DEFAULT,"TrainerDock Dome: callback reached Godot MessageQueue");}
    @autoreleasepool {dispatch_block_t work=(__bridge dispatch_block_t)data;work();}
}
void freeCallback(void *data){(void)CFBridgingRelease(data);}
uint8_t validCallback(void *data){return data!=nullptr;}
int token;
}
BOOL DKSupportedImage(void){return bind();}
BOOL DKEnqueue(dispatch_block_t work) {
    if(!bind())return NO;
    const bool *configured=(const bool *)dlsym(RTLD_DEFAULT,"_ZN10StringName10configuredE");
    if(!configured || !*configured || !api.from(25) || !api.destructor(25)){
        static bool reported=false;if(!reported){reported=true;os_log(OS_LOG_DEFAULT,"TrainerDock Dome: awaiting Godot callable registration configured=%{public}p",configured);}return NO;
    }
    CustomCallable info={};info.userdata=(__bridge_retained void *)[work copy];info.token=&token;
    info.call=callback;info.valid=validCallback;info.free=freeCallback;
    alignas(8) uint8_t raw[32]={};api.callable(raw,&info);
    Value callable;api.from(25)(callable.bytes,raw);api.destructor(25)(raw);
    bool ok=false;call(callable,"call_deferred",{},&ok);
    static bool reported=false;if(!reported){reported=true;os_log(OS_LOG_DEFAULT,"TrainerDock Dome: deferred call accepted=%{public}d",ok);}return ok;
}
NSDictionary *DKInspect(void) {
    if(!bind() || !ensureScript())return @{@"kind":@0,@"identity":@"unavailable",@"note":failure};
    Value result=call(*script,"inspect");NSDictionary *state=json(result);
    return state.count ? state : @{@"kind":@0,@"identity":@"unavailable",@"note":@"Keine native Kontextbestätigung."};
}
NSDictionary *DKEffect(NSInteger feature,BOOL wanted,double value) {
    if(!script)return @{};Value f((int64_t)feature),w((bool)wanted),v(value);Value result=call(*script,"effect",{&f,&w,&v});return json(result);
}
NSString *DKOneShot(NSInteger feature,double value) {
    if(!script)return @"Keine native Spielanbindung.";
    Value f((int64_t)feature),v(value);Value result=call(*script,"one_shot",{&f,&v});return result.text() ?: @"Keine native Aktionsbestätigung.";
}
void DKRelease(void){if(script)call(*script,"release");}
BOOL DKMouse(BOOL enabled){if(!script)return NO;Value flag((bool)enabled);Value result=call(*script,"mouse",{&flag});return result.boolean();}
