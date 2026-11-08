// SPDX-License-Identifier: GPL-3.0-only
// Runs the actual module metadata resolvers against a counted embedding API.
#if defined(MHT_METADATA_VC)
#include "../../Modules/vampire-crawlers/Sources/IL2CPP.hpp"
namespace runtime=vc;
#else
#include "../../Modules/the-long-dark/Sources/IL2CPP.hpp"
namespace runtime=tld;
#endif
#include <cstdio>
#include <cstdlib>
#include <cstring>
namespace {
void *domain=(void *)1;unsigned classQueries=0,methodQueries=0,fieldQueries=0,typeQueries=0,typeFrees=0;
bool loaded=true,duplicate=false;
void check(bool ok,const char *why){if(!ok){fprintf(stderr,"FAIL: %s\n",why);exit(1);}}
}
int main(){using namespace runtime;
 api.domainGet=[](){return domain;};
 api.assemblies=[](void *,size_t *n)->const void **{static const void *a[]={(void *)2};*n=1;return a;};
 api.assemblyImage=[](const void *){return (void *)3;};api.imageName=[](void *){return "Original.dll";};
 api.classFromName=[](void *,const char *,const char *)->runtime::Class{classQueries++;return loaded?(void *)4:nullptr;};
 api.parent=[](runtime::Class)->runtime::Class{return nullptr;};
 api.methods=[](runtime::Class,void **iterator)->Method{methodQueries++;uintptr_t n=(uintptr_t)*iterator;*iterator=(void *)(n+1);return n<(duplicate?2u:1u)?(void *)(8+n):nullptr;};
 api.methodName=[](Method){return "Run";};api.parameterCount=[](Method){return 0u;};
 api.findField=[](runtime::Class,const char *)->Field{fieldQueries++;return loaded?(void *)12:nullptr;};
 api.typeName=[](const void *){typeQueries++;return strdup("System.IntPtr");};api.freeMemory=[](void *p){typeFrees++;free(p);};
 for(unsigned n=0;n<20000;n++){
  check(klass("Original.dll","Native","Player")== (void *)4,"original class identity");
  check(method((void *)4,"Run",0)==(void *)8,"original method identity");
  check(field((void *)4,"value")== (void *)12,"original field identity");
  check(typeName((void *)30)=="System.IntPtr","original ABI type name");
 }
 check(classQueries==1&&methodQueries==2&&fieldQueries==1,"20,000 calls require one class/field lookup and one full method scan");
 check(typeQueries==1&&typeFrees==1,"immutable ABI names allocate/free native text only once across 20,000 lookups");
 domain=(void *)20;typeName((void *)30);check(typeQueries==2&&typeFrees==2,"domain change also revalidates original ABI names");klass("Original.dll","Native","Player");method((void *)4,"Run",0);field((void *)4,"value");
 check(classQueries==2&&methodQueries==4&&fieldQueries==2,"a replacement domain freshly resolves every descriptor");
 domain=nullptr;check(!klass("Original.dll","Native","Player"),"a missing domain cannot resolve cached class pointers");domain=(void *)20;
 unsigned beforeABA=classQueries;check(klass("Original.dll","Native","Player")== (void *)4&&classQueries==beforeABA+1,"A-null-A freshly resolves classes after a domain disappears");
 loaded=false;check(!klass("Original.dll","Native","Late")&&!field((void *)4,"late"),"not-yet-loaded metadata returns missing");
 loaded=true;check(klass("Original.dll","Native","Late")&&field((void *)4,"late"),"late-loaded metadata is not poisoned by a negative cache");
 domain=(void *)21;duplicate=true;bool rejected=false;
 try{method((void *)4,"Run",0);}catch(const std::runtime_error&){rejected=true;}
 check(rejected,"ambiguous original overload is still rejected");
 duplicate=false;check(method((void *)4,"Run",0)==(void *)8,"a rejected lookup is retried rather than cached");
 api={};puts("PASS: actual IL2CPP resolver counts, fresh domain binding, late loading and original ambiguity rejection. No game launched.");
}
