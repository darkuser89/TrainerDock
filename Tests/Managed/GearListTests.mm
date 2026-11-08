// SPDX-License-Identifier: GPL-3.0-only
// Typed synthetic List<GearItemObject> storage; no game object or asset scan.
#include "../../Modules/the-long-dark/Sources/NativeFields.hpp"
#include <cstdlib>
namespace {
using tld::Object;using tld::Field;
alignas(8) uint8_t arrayStorage[32+3*24]={};int gearA,gearB;
Object array=arrayStorage;int32_t count=2;int32_t stride=24;size_t memberOffset=24;bool changed=false;
int listStorage;void *listClass=(void *)1,*arrayClass=(void *)2,*elementClass=(void *)3,*gearClass=(void *)4,*intType=(void *)5;
Field itemsField=(void *)10,sizeField=(void *)11,gearField=(void *)12;
void check(bool ok,const char *why){if(!ok){fprintf(stderr,"FAIL: %s\n",why);exit(1);}}
}
int main(){using namespace tld;
 api.objectClass=[](Object o)->tld::Class{return o==&listStorage?listClass:o==arrayStorage?arrayClass:gearClass;};
 api.findField=[](tld::Class k,const char *n)->Field{if(k==listClass){if(!strcmp(n,"_items"))return itemsField;if(!strcmp(n,"_size"))return sizeField;}if(k==elementClass&&!strcmp(n,"m_GearItem"))return gearField;return nullptr;};
 api.parent=[](tld::Class)->tld::Class{return nullptr;};
 api.fieldType=[](Field f)->const void *{return f==itemsField?arrayClass:f==sizeField?intType:gearClass;};
 api.typeClass=[](const void *t)->tld::Class{return (void *)t;};api.valueType=[](tld::Class k){return k==elementClass||k==intType;};
 api.enumType=[](tld::Class){return false;};api.typeKind=[](const void *t){return t==intType?8:18;};api.fieldFlags=[](Field){return 0;};
 api.fieldRead=[](Object o,Field f,void *out){check(o==&listStorage,"inline values must not be passed as fake boxed objects");if(f==itemsField)memcpy(out,&array,8);else if(f==sizeField){int32_t value=count;if(changed)value++;memcpy(out,&value,4);changed=true;}else check(false,"unexpected field access");};
 api.strong=[](Object o,bool)->Handle{return (uintptr_t)o;};api.target=[](Handle h)->Object{return (void *)h;};api.freeHandle=[](Handle){};
 api.elementClass=[](tld::Class k)->tld::Class{return k==arrayClass?elementClass:nullptr;};api.arrayLength=[](Object)->uintptr_t{return 3;};
 api.valueSize=[](tld::Class,uint32_t *a){*a=8;return stride;};api.objectHeader=[](){return 16u;};api.arrayHeader=[](){return 32u;};api.fieldOffset=[](Field){return memberOffset;};
 Object a=&gearA,b=&gearB;memcpy(arrayStorage+32+8,&a,8);memcpy(arrayStorage+32+24+8,&b,8);
 // Keep stable counts until the explicit mutation test below.
 api.fieldRead=[](Object o,Field f,void *out){check(o==&listStorage,"no fabricated boxed struct access");if(f==itemsField)memcpy(out,&array,8);else memcpy(out,&count,4);};
 auto result=gearItemList(&listStorage,elementClass,gearClass);check(result.size()==2&&result[0]==a&&result[1]==b,"only owned inline elements are resolved using the original stride/field offset");
 count=0;check(gearItemList(&listStorage,elementClass,gearClass).empty(),"empty local inventory is valid and never requests a global fallback scan");
 auto reject=[&](const char *why){bool failed=false;try{gearItemList(&listStorage,elementClass,gearClass);}catch(const std::runtime_error&){failed=true;}check(failed,why);};
 count=4;reject("list count cannot exceed original array capacity");count=2;
 memberOffset=40;reject("reference offset cannot escape original value size");memberOffset=24;
 stride=4;reject("bad original value stride rejected");stride=24;
 changed=false;api.fieldRead=[](Object,Field f,void *out){if(f==itemsField)memcpy(out,&array,8);else{int32_t v=count+(changed?1:0);memcpy(out,&v,4);changed=true;}};
 reject("a list mutation during reading invalidates the snapshot");
 api={};puts("PASS: original-ABI inline gear-list extraction, empty inventory, capacity/stride/field boundaries and mutation rejection. No global scene scan or game launched.");
}
