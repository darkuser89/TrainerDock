// SPDX-License-Identifier: GPL-3.0-only
// Own memory/API fixtures only. Never linked into a product or an original game.
#define STRAY_INPUT_TESTING 1
#import "../../Modules/stray/Sources/StrayInput.mm"
#include <algorithm>
namespace {
bool inputFixtureActive=true;
bool fixtureBound=true,fixtureThread=true,fixtureSchema=true;
int fixtureSerial=1;NSUInteger calls=0,physicalCaptures=0,nativeQueries=0;
std::array<uint8_t,4096> pcBytes{},worldBytes{},viewportBytes{},applicationBytes{},cursorBytes{},slateBytes{},usersBytes{};
uintptr_t appSlot=0,slateSlot=0;constexpr uintptr_t fixtureVTable=0x12345678;
uintptr_t at(std::array<uint8_t,4096> &b){return reinterpret_cast<uintptr_t>(b.data());}
template<class T>void put(uintptr_t address,T value){memcpy(reinterpret_cast<void *>(address),&value,sizeof(value));}
template<class T>T get(uintptr_t address){T value;memcpy(&value,reinterpret_cast<void *>(address),sizeof(value));return value;}
bool valid(uintptr_t p,size_t n){
 for(auto *b:{&pcBytes,&worldBytes,&viewportBytes,&applicationBytes,&cursorBytes,&slateBytes,&usersBytes}){uintptr_t start=at(*b);if(p>=start&&p-start<=b->size()&&n<=b->size()-(p-start))return true;}
 for(auto *s:{&appSlot,&slateSlot}){uintptr_t start=reinterpret_cast<uintptr_t>(s);if(p>=start&&p-start<=sizeof(*s)&&n<=sizeof(*s)-(p-start))return true;}
 return false;
}
void *viewportFixture(void *w){calls++;return w==(void *)at(worldBytes)?viewportBytes.data():nullptr;}
void captureFixture(void *p,uint8_t value){calls++;put<uint8_t>((uintptr_t)p+0x352,value);}
void lockFixture(void *p,uint8_t value){calls++;put<uint8_t>((uintptr_t)p+0x354,value);}
void hideFixture(void *p,bool value){calls++;put<uint8_t>((uintptr_t)p+0x353,value);}
void precisionFixture(void *p,bool value,const void *){calls++;physicalCaptures+=value;put<uint8_t>((uintptr_t)p+0x88,value);put<uint8_t>(at(cursorBytes)+0x111,value);}
void showFixture(void *p,bool value){calls++;put<uint8_t>((uintptr_t)p+0x110,value);}
void typeFixture(void *p,int32_t value){calls++;put<int32_t>((uintptr_t)p+8,value);}
void clipFixture(void *p,const int32_t *value){calls++;std::array<int32_t,4> rect{};if(value){std::copy(value,value+4,rect.begin());rect[2]--;rect[3]--;}put((uintptr_t)p+0x100,rect);}
void releaseFixture(void *,int32_t user){calls++;NSCAssert(user==0,@"Only the validated local pointer user is released");}
void reset(){
 inputFixtureActive=true;fixtureBound=true;fixtureThread=true;STSetOverlayInteraction(false);fixtureSerial++;fixtureSchema=true;
 for(auto *b:{&pcBytes,&worldBytes,&viewportBytes,&applicationBytes,&cursorBytes,&slateBytes,&usersBytes})b->fill(0);
 appSlot=at(applicationBytes);slateSlot=at(slateBytes);
 put(at(applicationBytes)+8,at(cursorBytes));put(at(cursorBytes),fixtureVTable);put<int32_t>(at(cursorBytes)+0x120,-1);
 put<int32_t>(at(slateBytes)+0x2d8,1);put(at(slateBytes)+0x2d0,at(usersBytes));put(at(usersBytes),at(pcBytes));
 put(at(viewportBytes)+0x70,at(worldBytes));put<uint8_t>(at(viewportBytes)+0x352,2);put<uint8_t>(at(viewportBytes)+0x353,1);put<uint8_t>(at(viewportBytes)+0x354,2);
 put<uint8_t>(at(pcBytes)+0x440,0xa4);put<uint8_t>(at(applicationBytes)+0x88,1);put<uint8_t>(at(cursorBytes)+0x111,1);
 put<uint8_t>(at(cursorBytes)+0x110,0);put<int32_t>(at(cursorBytes)+8,0);put(at(cursorBytes)+0x100,std::array<int32_t,4>{10,20,30,40});
 calls=0;physicalCaptures=0;nativeQueries=0;
}
void check(bool value,const char *why){if(!value){fprintf(stderr,"FAIL: %s\n",why);exit(1);}}
}
namespace st {
bool isBound(){nativeQueries++;return fixtureBound;}bool isGameThread(){nativeQueries++;return fixtureThread;}
bool read(uintptr_t address,void *out,size_t n){nativeQueries++;if(!valid(address,n))return false;memcpy(out,(const void *)address,n);return true;}
bool write(uintptr_t address,const void *value,size_t n){if(!valid(address,n))return false;memcpy((void *)address,value,n);return true;}
Object world(){nativeQueries++;return Object{at(worldBytes)};}Object playerController(){nativeQueries++;return Object{at(pcBytes)};}
Weak::Weak(Object o){nativeQueries++;index=o.address==at(pcBytes)?1:o.address==at(worldBytes)?2:o.address==at(viewportBytes)?3:-1;serial=fixtureSerial;}
Object Weak::get()const{nativeQueries++;return serial==fixtureSerial?Object{index==1?at(pcBytes):index==2?at(worldBytes):index==3?at(viewportBytes):0}:Object{};}
Property property(Object,NSString *){nativeQueries++;Property p;p.type=@"BoolProperty";p.offset=fixtureSchema?0x440:0x441;p.boolMask=1;return p;}
uintptr_t binding(const char *name){
 nativeQueries++;
 if(!strcmp(name,"inputWorldViewport"))return (uintptr_t)viewportFixture;
 if(!strcmp(name,"inputSetCapture"))return (uintptr_t)captureFixture;
 if(!strcmp(name,"inputSetLock"))return (uintptr_t)lockFixture;
 if(!strcmp(name,"inputSetHide"))return (uintptr_t)hideFixture;
 if(!strcmp(name,"inputSetPrecision"))return (uintptr_t)precisionFixture;
 if(!strcmp(name,"inputCursorShow"))return (uintptr_t)showFixture;
 if(!strcmp(name,"inputCursorType"))return (uintptr_t)typeFixture;
 if(!strcmp(name,"inputCursorLock"))return (uintptr_t)clipFixture;
 if(!strcmp(name,"inputReleaseCapture"))return (uintptr_t)releaseFixture;
 if(!strcmp(name,"inputMacApplication"))return (uintptr_t)&appSlot;
 if(!strcmp(name,"inputSlate"))return (uintptr_t)&slateSlot;
 if(!strcmp(name,"inputMacCursorVTable"))return fixtureVTable;
 return 0;
}
}
int main(){@autoreleasepool{
 reset();for(int i=0;i<10000;i++)check(!STSetOverlayInteraction(false),"Closed overlay stays inactive");
 check(nativeQueries==0&&calls==0,"10,000 idle closed-overlay polls perform zero native queries or calls");
 reset();fixtureBound=false;check(!STSetOverlayInteraction(true)&&calls==0,"Unbound originals never reach an input API");
 reset();fixtureThread=false;check(!STSetOverlayInteraction(true)&&calls==0,"An unrelated thread never reaches the native input API");
 reset();inputFixtureActive=false;check(!STSetOverlayInteraction(true)&&calls==0,"No background acquisition");
 reset();fixtureSchema=false;check(!STSetOverlayInteraction(true)&&calls==0,"A changed reflected cursor bit rejects before mutation");
 reset();put(at(viewportBytes)+0x70,at(pcBytes));check(!STSetOverlayInteraction(true)&&get<uint8_t>(at(pcBytes)+0x440)==0xa4,"Wrong viewport world rejects before mutation");
 reset();check(STSetOverlayInteraction(true),"Native free-state readback confirms acquisition");
 check(get<uint8_t>(at(pcBytes)+0x440)==0xa5,"Only the exact owned show-cursor bit changes");
 check(STSetOverlayInteraction(true),"Repeated opening preserves the original baseline");
 STSetOverlayInteraction(false);
 check(get<uint8_t>(at(pcBytes)+0x440)==0xa4&&get<uint8_t>(at(viewportBytes)+0x352)==2&&get<uint8_t>(at(viewportBytes)+0x354)==2&&get<uint8_t>(at(viewportBytes)+0x353)==1,"Closing restores native intent and preserves unrelated bits");
 check(get<uint8_t>(at(applicationBytes)+0x88)==1&&get<uint8_t>(at(cursorBytes)+0x111)==1&&get<uint8_t>(at(cursorBytes)+0x110)==0&&get<int32_t>(at(cursorBytes)+8)==0&&get<std::array<int32_t,4>>(at(cursorBytes)+0x100)==std::array<int32_t,4>{10,20,30,40},"Original precision, visibility, cursor type and inclusive lock rectangle are restored");
 nativeQueries=0;calls=0;for(int i=0;i<10000;i++)STSetOverlayInteraction(false);
 check(nativeQueries==0&&calls==0,"After one proper release, idle overlay polls never revisit native state");
 reset();check(STSetOverlayInteraction(true),"Acquire for foreign-intent test");put<uint8_t>(at(viewportBytes)+0x354,1);STSetOverlayInteraction(false);
 check(get<uint8_t>(at(viewportBytes)+0x354)==1&&physicalCaptures==0,"A newly established menu lock is preserved");
 reset();check(STSetOverlayInteraction(true),"Acquire for lifetime test");fixtureSerial++;NSUInteger before=calls;STSetOverlayInteraction(false);check(calls==before,"An expired UObject serial never reaches a restore API");
 reset();check(STSetOverlayInteraction(true),"Acquire for focus-loss test");inputFixtureActive=false;STSetOverlayInteraction(false);check(physicalCaptures==0&&get<uint8_t>(at(applicationBytes)+0x88)==0,"Focus loss never physically recaptures the mouse");
 puts("PASS: native input lease gates/readback/restoration and 20,000 closed-overlay polls with zero native queries/calls. Fixture APIs only; no game started.");
}}
