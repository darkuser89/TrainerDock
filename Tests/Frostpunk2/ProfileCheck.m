// SPDX-License-Identifier: GPL-3.0-only
#import <Foundation/Foundation.h>
#import "GameProfile.h"
#import "../../Core/GameIdentity.h"
int main(int argc,const char *argv[]){@autoreleasepool{NSError *error=nil;NSDictionary *c=MTLoadConfiguration(@"/private/tmp/trainerdock-frostpunk2/ProbeConfig.json",&error);NSDictionary *p=MTFindProfile(c,@"steam-arm64-24037022");NSDictionary *g=MTInspectGame(@"/Volumes/Mac Games/SteamLibrary/steamapps/common/Frostpunk2/Frostpunk2.app",p,&error);if(!g){fprintf(stderr,"%s\n",error.localizedDescription.UTF8String);return 1;}if(argc>1 && !strcmp(argv[1],"--require-not-running") && MTExecutableIsRunning(g[@"executable"])){fprintf(stderr,"Already running; no duplicate start.\n");return 2;}puts("Exact Frostpunk2 original and full hashes verified.");return 0;}}
