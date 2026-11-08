// SPDX-License-Identifier: GPL-3.0-only
// Synthetic ABI fixtures only; never linked into the trainer.
#include "Mono.hpp"
#import "TerrariaBackend.h"
#include <cstring>
#include <cstdlib>
static void check(bool ok,const char *why){if(!ok){fprintf(stderr,"FAIL: %s\n",why);exit(1);}}
int main(){using namespace tr;
 check(!TRInFrame() && !TREffect(0,YES,0).count && !TRMouse(YES),"No effect/cursor access outside original callback");
 int kind=8;uint8_t storage[8]={};unsigned writes=0;api.fieldType=[](Field f){return f;};api.kind=+[](void *){return 8;};
 api.flags=[](Field){return 0u;};api.write=[](Object o,Field,void *v){memcpy(o,v,4);};api.read=[](Object o,Field,void *v){memcpy(v,o,4);};
 auto bytes=numeric((Field)&kind,42);write(storage,nullptr,(Field)&kind,bytes);check(read(storage,nullptr,(Field)&kind)==bytes,"Typed 32-bit field roundtrip");writes++;
 bool rejected=false;try{numeric((Field)&kind,1.5);}catch(...){rejected=true;}check(rejected,"No truncation of fractional integers");
 api.kind=[](void *){return 18;};api.typeName=[](void *){return strdup("System.Object");};api.free=[](void *v){free(v);};rejected=false;
 try{size((Field)&kind);}catch(...){rejected=true;}check(rejected,"Reference fields cannot use scalar raw-write API");
 api.kind=[](void *){return 17;};api.typeName=[](void *){return strdup("System.TimeSpan");};check(size((Field)&kind)==8,"Original FNA TimeSpan is exactly eight bytes");
 api.classFromType=[](void *t){return t;};api.isEnum=[](Klass){return 1;};api.enumBase=[](Klass){return (void *)8;};api.kind=[](void *t){return t==(void *)8?8:17;};
 auto enumBytes=numeric((Field)&kind,1);check(enumBytes.size()==4 && enumBytes[0]==1,"FrameSkip enum uses its original 32-bit underlying type");
 api={};check(writes==1,"Expected fixture writes");puts("PASS: game-thread boundary, scalar roundtrip, integer validation, reference rejection and FNA TimeSpan ABI. No game launched.");
}
