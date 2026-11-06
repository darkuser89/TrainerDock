// SPDX-License-Identifier: GPL-3.0-only
#import "GameAdapter.h"
#import "NativeAdapter.h"
@implementation MTGameContext
- (instancetype)init{if((self=[super init])){_kind=MTSessionUnsupported;_identity=@"unimplemented";_note=@"Keine native Spielanbindung implementiert.";}return self;}
@end
id<MTGameAdapter> MTCreateGameAdapter(void){return [MHTNativeAdapter new];}
