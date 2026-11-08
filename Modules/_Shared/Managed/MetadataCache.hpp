// SPDX-License-Identifier: GPL-3.0-only
#pragma once
#include <cstdint>
#include <map>
#include <mutex>

namespace mht::managed {
// Mono/IL2CPP class, method and field descriptors are immutable within their
// loaded domain. Never use this cache for objects, GC handles or gameplay values.
// Missing metadata is retried, and changing the domain or resolver invalidates
// all entries before a pointer can be returned to the caller.
template<class Key,class Value,size_t Limit=4096> class MetadataCache {
    std::mutex lock;
    void *domain=nullptr;
    uintptr_t resolver=0;
    std::map<Key,Value> entries;
public:
    template<class Lookup> Value get(void *current,uintptr_t authority,const Key& key,Lookup lookup) {
        std::lock_guard<std::mutex> guard(lock);
        if(!current || !authority){entries.clear();domain=nullptr;resolver=0;return lookup();}
        if(domain!=current || resolver!=authority){entries.clear();domain=current;resolver=authority;}
        auto found=entries.find(key);
        if(found!=entries.end())return found->second;
        Value value=lookup();
        if(value){if(entries.size()>=Limit)entries.clear();entries.emplace(key,value);}
        return value;
    }
};
}
