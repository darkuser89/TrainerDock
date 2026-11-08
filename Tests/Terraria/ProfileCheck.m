// SPDX-License-Identifier: GPL-3.0-only
#import "GameProfile.h"
#import "../../Core/GameIdentity.h"
int main(int argc,const char **argv){@autoreleasepool{NSError *e=nil;NSDictionary *c=MTLoadConfiguration(@"/private/tmp/trainerdock-terraria/ProbeConfig.json",&e);NSDictionary *p=MTFindProfile(c,@"steam-arm64-1.4.5.8");NSDictionary *r=MTInspectGame(@"/Volumes/Mac Games/SteamLibrary/steamapps/common/Terraria/Terraria.app",p,&e);if(!r){fprintf(stderr,"%s\n",e.localizedDescription.UTF8String);return 1;}if(argc>1 && !strcmp(argv[1],"--require-not-running") && MTExecutableIsRunning(r[@"executable"])){fputs("Already running; no duplicate start.\n",stderr);return 2;}puts("Exact Terraria arm64 original, wrapper and complete hashes verified.");return 0;}}
