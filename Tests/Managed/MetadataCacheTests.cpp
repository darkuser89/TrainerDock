// SPDX-License-Identifier: GPL-3.0-only
// Synthetic metadata only; no game process, API or runtime objects.
#include "../../Modules/_Shared/Managed/MetadataCache.hpp"
#include <cstdio>
#include <cstdlib>
#include <stdexcept>
#include <string>
static void check(bool ok,const char *why){if(!ok){fprintf(stderr,"FAIL: %s\n",why);exit(1);}}
int main(){
 mht::managed::MetadataCache<std::string,void *,2> cache;
 unsigned calls=0;void *domain=(void *)1,*value=(void *)3;
 auto read=[&]{calls++;return value;};
 for(unsigned i=0;i<20000;i++)check(cache.get(domain,1,"field",read)==value,"stable descriptor returned");
 check(calls==1,"20,000 repeated lookups traverse immutable metadata only once");
 check(cache.get((void *)2,1,"field",read)==value && calls==2,"domain changes invalidate descriptors");
 check(cache.get((void *)2,2,"field",read)==value && calls==3,"resolver changes invalidate descriptors");
 value=nullptr;cache.get((void *)2,2,"missing",read);value=(void *)4;
 check(cache.get((void *)2,2,"missing",read)==value && calls==5,"missing metadata is retried after assembly/class load");
 bool rejected=false;try{cache.get((void *)2,2,"ambiguous",[]()->void *{throw std::runtime_error("ambiguous");});}catch(const std::runtime_error&){rejected=true;}
 check(rejected,"ambiguous resolver failures are not cached or suppressed");
 cache.get((void *)2,2,"overflow",read);unsigned before=calls;
 cache.get((void *)2,2,"field",read);check(calls==before+1,"capacity evicts bounded metadata rather than growing forever");
 before=calls;cache.get(nullptr,2,"field",read);cache.get(nullptr,2,"field",read);
 check(calls==before+2,"no unconfirmed domain can cache a descriptor");
 before=calls;cache.get((void *)2,2,"field",read);
 check(calls==before+1,"domain loss invalidates old pointers even when a replacement reuses the same address");
 puts("PASS: 20,000 metadata hits, bounded capacity, domain/resolver changes, late loads and ambiguity propagation. No game launched.");
}
