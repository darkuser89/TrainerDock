// SPDX-License-Identifier: GPL-3.0-only
#import <Foundation/Foundation.h>
#import "GameProfile.h"
int main(int argc,const char **argv){@autoreleasepool{
    if(argc!=3)return 2;NSError *error=nil;
    NSDictionary *config=MTLoadConfiguration(@(argv[2]),&error);
    NSDictionary *profile=MTFindProfile(config,@"steam-arm64-1.6.1");
    NSDictionary *result=MTInspectGame(@(argv[1]),profile,&error);
    if(!result){fprintf(stderr,"Originalprüfung fehlgeschlagen: %s\n",error.localizedDescription.UTF8String);return 1;}
    printf("Originalprüfung bestätigt: %s · %s\n",[result[@"uuid"] UTF8String],[result[@"integrityMode"] UTF8String]);return 0;
}}
