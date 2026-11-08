// SPDX-License-Identifier: GPL-3.0-only
#import <Foundation/Foundation.h>
#import "GameProfile.h"
int main(void){@autoreleasepool{
 NSError *error=nil;NSDictionary *c=MTLoadConfiguration(@"/private/tmp/trainerdock-the-long-dark/ProbeConfig.json",&error);
 NSDictionary *p=MTFindProfile(c,@"steam-arm64-2.60");
 NSDictionary *r=MTInspectGame(@"/Volumes/Mac Games/SteamLibrary/steamapps/common/TheLongDark/tld.app",p,&error);
 if(!r){fprintf(stderr,"%s\n",error.localizedDescription.UTF8String);return 1;}
 printf("Exact Steam original verified: %s\n",[r[@"uuid"] UTF8String]);return 0;
}}
