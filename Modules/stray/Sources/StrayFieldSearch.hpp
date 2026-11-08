// SPDX-License-Identifier: GPL-3.0-only
#pragma once
#import "StrayEngine.hpp"
#include <set>
namespace st::detail {
// Shares the bounded UField traversal with boundary tests. Production readers
// validate every object and derive both type checks from original native classes.
template<class Reader> Object findFunction(Object cls,NSString *wanted,Reader &reader){
 std::set<uintptr_t> classes,links;
 for(size_t depth=0;cls&&depth<64;depth++){
  reader.validate(cls);
  if(!classes.insert(cls.address).second)throw std::runtime_error("Zyklische native Funktionstabelle.");
  Object field=reader.children(cls);
  for(size_t count=0;field;count++){
   if(count>=8192||!links.insert(field.address).second)throw std::runtime_error("Zyklische native Funktionskette.");
   reader.validate(field);
   if(!reader.isField(field))throw std::runtime_error("Ungültige native Feldmetadaten.");
   if(reader.outer(field)!=cls)throw std::runtime_error("Der native Feldbesitzer stimmt nicht überein.");
   // DelegateFunction and SparseDelegateFunction derive from UFunction and may
   // precede an unrelated target. Other valid UField subclasses are not callable.
   if(reader.isFunction(field)&&[reader.name(field) isEqual:wanted])return field;
   field=reader.next(field);
  }
  cls=reader.super(cls);
 }
 throw std::runtime_error("Die ursprüngliche Funktion fehlt.");
}
}
