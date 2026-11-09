// SPDX-License-Identifier: GPL-3.0-only
// Read-only identity check using the exact host implementation. Never launches.
#import <Foundation/Foundation.h>
#import "GameIdentity.h"
int main(int argc,const char *argv[]){@autoreleasepool{
    BOOL development=argc==5 && !strcmp(argv[4],"--development-identity");
    if(argc!=4 && !development){
        fputs("Aufruf: ProfileCheck Module.json|TrainerConfig.json Profilkennung Spiele-App [--development-identity]\n",stderr);return 2;
    }
    NSError *error=nil;
    NSData *bytes=[NSData dataWithContentsOfFile:@(argv[1]) options:0 error:&error];
    NSDictionary *configuration=bytes ? [NSJSONSerialization JSONObjectWithData:bytes options:0 error:&error] : nil;
    if(![configuration isKindOfClass:NSDictionary.class] || ![configuration[@"profiles"] isKindOfClass:NSArray.class]){
        fputs("Profildatei fehlt oder ist ungültig.\n",stderr);return 1;
    }
    NSDictionary *profile=MTFindProfile(configuration,@(argv[2]));
    if(![profile isKindOfClass:NSDictionary.class]){fputs("Profilkennung nicht gefunden.\n",stderr);return 1;}
    if(development){
        // Identity-only inspection before native effects are implemented.
        // This never persists a change or enables a product profile.
        NSMutableDictionary *copy=[profile mutableCopy];copy[@"enabled"]=@YES;profile=copy;
    }
    NSDictionary *identity=MTInspectGame(@(argv[3]),profile,&error);
    if(!identity){fprintf(stderr,"%s\n",error.localizedDescription.UTF8String ?: "Originalidentität nicht bestätigt.");return 1;}
    printf("Originalidentität geprüft: %s · %s · %s. %s Kein Spiel gestartet.\n",argv[2],
        [identity[@"uuid"] UTF8String],[profile[@"signatureScope"] UTF8String],
        development?"Produktfreigabe unverändert.":"Freigegebenes Profil.");
    return 0;
}}
