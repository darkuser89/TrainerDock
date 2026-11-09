// SPDX-License-Identifier: GPL-3.0-only
#import "../../Core/GameIdentity.h"
#include <string.h>
int main(int argc,const char **argv){@autoreleasepool{
 if(argc<3||argc>4)return 2;NSError *error=nil;
 NSDictionary *config=MTLoadConfiguration(@(argv[2]),&error);
 NSDictionary *profile=MTFindProfile(config,@"steam-arm64-1.0.2");
 NSDictionary *game=MTInspectGame(@(argv[1]),profile,&error);
 if(!game){fprintf(stderr,"Originalprüfung fehlgeschlagen: %s\n",error.localizedDescription.UTF8String);return 1;}
 if(argc==4 && !strcmp(argv[3],"--require-not-running") && MTExecutableIsRunning(game[@"executable"])){
  fputs("Prodeus läuft bereits; kein zweiter Start.\n",stderr);return 3;
 }
 printf("Originalprofil bestätigt: %s · %s\n",[game[@"uuid"] UTF8String],[game[@"integrityMode"] UTF8String]);return 0;
}}
