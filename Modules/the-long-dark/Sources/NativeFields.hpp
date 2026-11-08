// SPDX-License-Identifier: GPL-3.0-only
#pragma once
#include "IL2CPP.hpp"
#include <cstring>
#include <cmath>
#include <limits>
namespace tld {
inline size_t fieldSize(Field f){if(!f)throw std::runtime_error("Original field missing");auto t=api.fieldType(f);auto k=api.typeClass(t);int kind=api.typeKind(api.enumType(k)?api.enumBase(k):t);size_t size=kind==2?1:kind==8 || kind==9 || kind==12?4:kind==10 || kind==11 || kind==13?8:0;
 if(!size && !api.valueType(k))size=sizeof(Object);
 if(!size && (typeName(t)=="TLD.IntBackedUnit.ItemWeight" || typeName(t)=="TLD.IntBackedUnit.ItemLiquidVolume")){uint32_t a=0;auto k=api.typeClass(t);if(api.valueType(k) && api.valueSize(k,&a)==8)size=8;}
 if(!size)throw std::runtime_error("Unsupported original field type: "+typeName(t));return size;}
inline std::vector<uint8_t> read(Object o,Field f){std::vector<uint8_t> data(fieldSize(f));if(api.fieldFlags(f)&0x10)api.staticRead(f,data.data());else{if(!alive(o))throw std::runtime_error("Owner no longer alive");api.fieldRead(o,f,data.data());}return data;}
inline int scalarFieldKind(Field f){auto t=api.fieldType(f);auto k=api.typeClass(t);if(!k)throw std::runtime_error("Original scalar class missing");return api.typeKind(api.enumType(k)?api.enumBase(k):t);}
template<class T> inline double decodeFieldScalar(const std::vector<uint8_t>& bytes){if(bytes.size()!=sizeof(T))throw std::runtime_error("Original scalar size differs");T value;memcpy(&value,bytes.data(),sizeof(value));return (double)value;}
inline double numberField(Field f,const std::vector<uint8_t>& bytes){
 if(bytes.size()!=fieldSize(f))throw std::runtime_error("Original scalar size differs");
 switch(scalarFieldKind(f)){
  case 2:return decodeFieldScalar<uint8_t>(bytes);case 8:return decodeFieldScalar<int32_t>(bytes);case 9:return decodeFieldScalar<uint32_t>(bytes);
  case 10:return decodeFieldScalar<int64_t>(bytes);case 11:return decodeFieldScalar<uint64_t>(bytes);case 12:return decodeFieldScalar<float>(bytes);case 13:return decodeFieldScalar<double>(bytes);
  default:throw std::runtime_error("Unsupported original scalar field");
 }
}
template<class T> inline std::vector<uint8_t> encodeFieldScalar(double value){
 if(!std::isfinite(value)||(long double)value<(long double)std::numeric_limits<T>::lowest()||(long double)value>(long double)std::numeric_limits<T>::max()
    ||(std::numeric_limits<T>::is_integer&&sizeof(T)==8&&value>=std::ldexp(1.0,std::numeric_limits<T>::is_signed?63:64))
    ||(std::numeric_limits<T>::is_integer&&floor(value)!=value))throw std::runtime_error("Original scalar value out of range");
 T native=(T)value;std::vector<uint8_t> bytes(sizeof(T));memcpy(bytes.data(),&native,sizeof(native));return bytes;
}
inline std::vector<uint8_t> numericField(Field f,double value){
 std::vector<uint8_t> bytes;
 switch(scalarFieldKind(f)){
  case 2:if(value!=0&&value!=1)throw std::runtime_error("Original boolean value out of range");bytes=encodeFieldScalar<uint8_t>(value);break;
  case 8:bytes=encodeFieldScalar<int32_t>(value);break;case 9:bytes=encodeFieldScalar<uint32_t>(value);break;
  case 10:bytes=encodeFieldScalar<int64_t>(value);break;case 11:bytes=encodeFieldScalar<uint64_t>(value);break;
  case 12:bytes=encodeFieldScalar<float>(value);break;case 13:bytes=encodeFieldScalar<double>(value);break;
  default:throw std::runtime_error("Unsupported original scalar field");
 }
 if(bytes.size()!=fieldSize(f))throw std::runtime_error("Original scalar size differs");return bytes;
}
// Inventory.m_Items is List<GearItemObject>, not a reference array. Resolve its
// value stride and embedded GearItem reference from the original IL2CPP schema.
// No global Resources.FindObjectsOfTypeAll scan is needed for local inventory.
inline std::vector<Object> gearItemList(Object listObject,Class element,Class gear,size_t maximum=4096){
 if(!alive(listObject)||!element||!gear||!api.valueType(element))throw std::runtime_error("Original gear list unavailable");
 Root listOwner(listObject),array(reference(listObject,"_items"));
 Field size=field(api.objectClass(listObject),"_size"),member=field(element,"m_GearItem");
 if(!size||scalarFieldKind(size)!=8||!member||(api.fieldFlags(member)&0x10)||api.valueType(api.typeClass(api.fieldType(member)))||api.typeClass(api.fieldType(member))!=gear)
  throw std::runtime_error("Original inline gear list schema differs");
 int32_t count=0;api.fieldRead(listObject,size,&count);Object items=array.get();
 if(!items||api.elementClass(api.objectClass(items))!=element)throw std::runtime_error("Original inline gear array type differs");
 size_t capacity=api.arrayLength(items);uint32_t alignment=0;int32_t stride=api.valueSize(element,&alignment);
 size_t header=api.objectHeader(),offset=api.fieldOffset(member),arrayHeader=api.arrayHeader();
 if(count<0||(size_t)count>maximum||capacity<(size_t)count||capacity>65536||stride<8||stride>256||alignment>16
    ||header<8||header>64||offset<header||offset-header+sizeof(Object)>(size_t)stride||arrayHeader<16||arrayHeader>64)
  throw std::runtime_error("Original inline gear list bounds differ");
 uintptr_t payload=(uintptr_t)items+arrayHeader;
 if(payload<(uintptr_t)items||capacity>(UINTPTR_MAX-payload)/(size_t)stride)throw std::runtime_error("Original inline gear array overflows");
 std::vector<Object> result;result.reserve((size_t)count);
 for(int32_t i=0;i<count;i++){Object value=nullptr;memcpy(&value,(const void *)(payload+(size_t)i*stride+offset-header),sizeof(value));if(value)result.push_back(value);}
 int32_t after=0;Object current=listOwner.get();if(current!=listObject)throw std::runtime_error("Original gear list owner changed");
 api.fieldRead(current,size,&after);
 if(after!=count||reference(current,"_items")!=array.get())throw std::runtime_error("Original gear list changed during read");
 return result;
}
inline void write(Object o,Field f,const std::vector<uint8_t>& bytes){if(fieldSize(f)!=bytes.size())throw std::runtime_error("Field size differs");if(api.fieldFlags(f)&0x10){if(!api.valueType(api.typeClass(api.fieldType(f))))throw std::runtime_error("Static reference writes are not part of this binding");api.staticWrite(f,(void *)bytes.data());}else if(alive(o)){
 if(!api.valueType(api.typeClass(api.fieldType(f)))){Object value=nullptr;memcpy(&value,bytes.data(),sizeof(value));api.fieldWriteObject(o,f,value);}
 else api.fieldWrite(o,f,(void *)bytes.data());
 }else throw std::runtime_error("Owner no longer alive");}
}
