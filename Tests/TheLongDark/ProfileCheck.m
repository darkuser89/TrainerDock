// SPDX-License-Identifier: GPL-3.0-only
#import <Foundation/Foundation.h>
#import "GameProfile.h"
int main(int argc,const char *argv[]){@autoreleasepool{
 if(argc!=4){fprintf(stderr,"Aufruf: ProfileCheck Konfiguration Profilkennung Spiele-App\n");return 2;}
 NSError *error=nil;NSDictionary *c=MTLoadConfiguration(@(argv[1]),&error);
 NSDictionary *p=MTFindProfile(c,@(argv[2]));
 NSDictionary *r=MTInspectGame(@(argv[3]),p,&error);
 if(!r){fprintf(stderr,"%s\n",error.localizedDescription.UTF8String);return 1;}
 printf("Originalprofil geprüft: %s · %s. Kein Spiel gestartet.\n",argv[2],[r[@"uuid"] UTF8String]);return 0;
}}
