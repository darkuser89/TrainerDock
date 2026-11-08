// SPDX-License-Identifier: GPL-3.0-only
// Synthetic API-boundary fixtures only. No game objects, gameplay or game startup.
#include "NativeFields.hpp"
#import "LongDarkBackend.h"
#include "SaveGuard.hpp"
#include <unistd.h>
#include <fcntl.h>
#include <cstdio>
#include <cstdlib>
namespace {
int ownerStorage,arrayStorage,targetStorage;
void *refType=(void *)1,*floatType=(void *)2,*arrayType=(void *)3,*structType=(void *)4,*intType=(void *)5;
void *refField=(void *)11,*floatField=(void *)12,*itemsField=(void *)13,*sizeField=(void *)14;
void *stored=nullptr;float storedFloat=0;unsigned referenceWrites=0,rawWrites=0;
void check(bool value,const char *why){if(!value){fprintf(stderr,"FAIL: %s\n",why);exit(1);}}
}
int main(){using namespace tld;
 check(![TLDInspect()[@"kind"] integerValue] && !TLDValues().count,"outside the engine callback no gameplay can be read");
 check(!TLDEffect(0,YES,0).count && !TLDMouse(YES),"outside the engine callback no effect or cursor lease is accepted");
 api.objectClass=[](Object o)->tld::Class{return o==&arrayStorage?arrayType:refType;};
 api.parent=[](tld::Class)->tld::Class{return nullptr;};
 api.findField=[](tld::Class,const char *name)->Field {if(!strcmp(name,"_items"))return itemsField;if(!strcmp(name,"_size"))return sizeField;return nullptr;};
 api.fieldType=[](Field f)->const void * {return f==sizeField?intType:f==floatField?floatType:f==itemsField?arrayType:refType;};
 api.fieldFlags=[](Field){return 0;};api.typeClass=[](const void *t)->tld::Class{return (void *)t;};
 api.enumType=[](tld::Class){return false;};api.typeKind=[](const void *t){return t==intType?8:t==floatType?12:18;};
 api.valueType=[](tld::Class c){return c==floatType || c==structType || c==intType;};
 api.fieldRead=[](Object,Field f,void *out){if(f==floatField)memcpy(out,&storedFloat,4);else{void *p=f==itemsField?&arrayStorage:stored;memcpy(out,&p,8);}};
 api.fieldWrite=[](Object,Field f,void *value){check(f==floatField,"reference must never reach the untyped setter");rawWrites++;memcpy(&storedFloat,value,4);};
 api.fieldWriteObject=[](Object,Field f,Object value){check(f==refField,"typed setter receives the exact reference field");referenceWrites++;stored=value;};
 std::vector<uint8_t> bytes(8);void *target=&targetStorage;memcpy(bytes.data(),&target,8);write(&ownerStorage,refField,bytes);
 check(referenceWrites==1 && !rawWrites && stored==target,"typed object setter receives the object, not a pointer to a stack slot");
 bytes.assign(8,0);write(&ownerStorage,refField,bytes);check(!stored,"null reference restores through the typed setter");
 float number=3.5f;bytes.resize(4);memcpy(bytes.data(),&number,4);write(&ownerStorage,floatField,bytes);
 check(rawWrites==1 && storedFloat==number,"primitive fields retain the original scalar ABI");
 api.elementClass=[](tld::Class)->tld::Class{return structType;};
 api.arrayLength=[](Object)->uintptr_t{check(false,"a value-element list must be rejected before reading its payload");return 0;};
 check(list(&ownerStorage).empty(),"List<GearItemObject> is not misread as a reference array");
 api={};
 char directory[]="/private/tmp/trainerdock-save-guard-XXXXXX";check(mkdtemp(directory),"isolated save-guard fixture");
 std::string protectedPath=std::string(directory)+"/fixture",otherPath=std::string(directory)+"/other";
 auto create=[](const std::string& path){int f=open(path.c_str(),O_CREAT|O_WRONLY|O_EXCL,0600);check(f>=0,"new disposable fixture file");check(write(f,"fixture",7)==7,"fixture contents");close(f);};
 float hp=100;create(protectedPath);create(otherPath);TLDProtectSaves({protectedPath},(uintptr_t)&hp);
 check(TLDGuardedUnlink(otherPath.c_str())==0 && access(otherPath.c_str(),F_OK)!=0,"unrelated file deletes normally while armed");
 check(TLDGuardedUnlink(protectedPath.c_str())==0 && access(protectedPath.c_str(),F_OK)!=0,"alive player does not block ordinary deletion");
 create(protectedPath);hp=0;
 check(TLDGuardedUnlink(protectedPath.c_str())==0 && access(protectedPath.c_str(),F_OK)==0 && TLDBlockedSaveDeletes()>0,"death preserves only the exact scoped fixture");
 TLDReleaseSaveGuard();check(TLDGuardedUnlink(protectedPath.c_str())==0 && access(protectedPath.c_str(),F_OK)==0,"queued death cleanup stays protected after owner release");
 TLDClearSaveGuard();check(TLDGuardedUnlink(protectedPath.c_str())==0,"explicit off returns normal deletion and cleans fixtures");
 hp=100;int mode=1;create(protectedPath);TLDProtectSaves({protectedPath},(uintptr_t)&hp,(uintptr_t)&mode);
 check(TLDGuardedUnlink(protectedPath.c_str())==0 && access(protectedPath.c_str(),F_OK)==0,"original dead control mode protects forced death with positive HP");
 TLDClearSaveGuard();check(unlink(protectedPath.c_str())==0 && rmdir(directory)==0,"dead-mode fixture cleanup");
 puts("PASS: engine-thread guard, typed reference/null writes, primitive ABI, value-list rejection and exact-path death-save protection/release. No game launched.");return 0;
}
