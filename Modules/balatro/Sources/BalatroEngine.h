// SPDX-License-Identifier: GPL-3.0-only
#import <Foundation/Foundation.h>
typedef struct lua_State lua_State;
#ifdef __cplusplus
extern "C" {
#endif
void BAEnable(void);
void BASetInputHandler(BOOL (^handler)(NSInteger,double,double,NSString *,NSUInteger));
void BAObserveLua(lua_State *state);
void BAForgetLua(lua_State *state);
void BAEnqueue(dispatch_block_t work);
NSDictionary *BAInspect(void);
NSDictionary *BAEffect(NSInteger feature,BOOL wanted,double value);
NSString *BAOneShot(NSInteger feature,double value);
void BARelease(void);
BOOL BAMouse(BOOL wanted);

#ifdef __cplusplus
}
#endif
