// SPDX-License-Identifier: GPL-3.0-only
// Real native resource reduction and a known test-only currency gain.
#import "ControlEngine.h"
template<class T>static T r(uintptr_t p){T v{};MHTControlRead(p,&v,sizeof(v));return v;}
extern "C" NSDictionary *MHTControlNativeDiagnostic(uintptr_t core,uintptr_t main,void *server,uintptr_t avatar){
 (void)core;(void)server;static NSDictionary *result;if(result||!avatar)return result;
 uintptr_t resource=0,player=0,list=r<uintptr_t>(avatar+0x60);uint32_t count=r<uint32_t>(avatar+0x68);if(count>128)return @{};
 for(uint32_t i=0;i<count;i++){uintptr_t c=r<uintptr_t>(list+i*8);if(r<uintptr_t>(c+0x20)!=avatar)continue;if(r<uintptr_t>(c)==main+0xdd0438)resource=c;if(r<uintptr_t>(c)==main+0xe2f748)player=c;}
 if(!resource||!player)return @{};
 auto infinite=(void(*)(void*,bool))(main+0xf1c30);auto change=(void(*)(void*,float))(main+0xf1cac);
 bool beforeFlag=r<uint8_t>(resource+0x139);float before=r<float>(resource+0x38);
 infinite((void*)resource,false);change((void*)resource,-.25f);float unprotected=r<float>(resource+0x38);
 infinite((void*)resource,true);change((void*)resource,-.25f);float protectedValue=r<float>(resource+0x38);
 infinite((void*)resource,beforeFlag);MHTControlWrite(resource+0x38,&before,4);
 uint64_t money=r<uint64_t>(player+0x38),gain=money+10;bool wrote=money<999999980&&MHTControlWrite(player+0x38,&gain,8);
 result=@{@"resourceBefore":@(before),@"resourceWithoutProtection":@(unprotected),@"resourceWithProtection":@(protectedValue),@"resourceRestored":@(r<float>(resource+0x38)),@"flagRestored":@(r<uint8_t>(resource+0x139)==beforeFlag),@"currencyBefore":@(money),@"knownTestGain":@(wrote?10:0)};return result;
}
