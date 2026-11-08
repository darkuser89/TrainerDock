// SPDX-License-Identifier: GPL-3.0-only
#pragma once
#include "IL2CPP.hpp"
#include <cstring>
namespace tld {
inline size_t fieldSize(Field f){if(!f)throw std::runtime_error("Original field missing");auto t=api.fieldType(f);auto k=api.typeClass(t);int kind=api.typeKind(api.enumType(k)?api.enumBase(k):t);size_t size=kind==2?1:kind==8 || kind==9 || kind==12?4:kind==10 || kind==11 || kind==13?8:0;
 if(!size && !api.valueType(k))size=sizeof(Object);
 if(!size && (typeName(t)=="TLD.IntBackedUnit.ItemWeight" || typeName(t)=="TLD.IntBackedUnit.ItemLiquidVolume")){uint32_t a=0;auto k=api.typeClass(t);if(api.valueType(k) && api.valueSize(k,&a)==8)size=8;}
 if(!size)throw std::runtime_error("Unsupported original field type: "+typeName(t));return size;}
inline std::vector<uint8_t> read(Object o,Field f){std::vector<uint8_t> data(fieldSize(f));if(api.fieldFlags(f)&0x10)api.staticRead(f,data.data());else{if(!alive(o))throw std::runtime_error("Owner no longer alive");api.fieldRead(o,f,data.data());}return data;}
inline void write(Object o,Field f,const std::vector<uint8_t>& bytes){if(fieldSize(f)!=bytes.size())throw std::runtime_error("Field size differs");if(api.fieldFlags(f)&0x10){if(!api.valueType(api.typeClass(api.fieldType(f))))throw std::runtime_error("Static reference writes are not part of this binding");api.staticWrite(f,(void *)bytes.data());}else if(alive(o)){
 if(!api.valueType(api.typeClass(api.fieldType(f)))){Object value=nullptr;memcpy(&value,bytes.data(),sizeof(value));api.fieldWriteObject(o,f,value);}
 else api.fieldWrite(o,f,(void *)bytes.data());
 }else throw std::runtime_error("Owner no longer alive");}
}
