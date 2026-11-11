// SPDX-License-Identifier: GPL-3.0-only
#import <Foundation/Foundation.h>
#import "GameProfile.h"
#import "../../Core/GameIdentity.h"
int main(int argc,const char **argv){@autoreleasepool{
    if(argc<4 || argc>5)return 2;NSError *error=nil;
    NSDictionary *config=MTLoadConfiguration(@(argv[2]),&error);
    NSDictionary *profile=MTFindProfile(config,@(argv[3]));
    NSDictionary *result=MTInspectGame(@(argv[1]),profile,&error);
    if(!result){fprintf(stderr,"Originalprüfung fehlgeschlagen: %s\n",error.localizedDescription.UTF8String);return 1;}
    if(argc==5 && !strcmp(argv[4],"--require-not-running") && MTExecutableIsRunning(result[@"executable"])){
        fputs("No Man’s Sky läuft bereits; kein zweiter Start.\n",stderr);return 3;
    }
    printf("Originalprüfung bestätigt: %s · %s\n",[result[@"uuid"] UTF8String],[result[@"integrityMode"] UTF8String]);return 0;
}}
