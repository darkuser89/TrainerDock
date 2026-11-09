// SPDX-License-Identifier: GPL-3.0-only
// Explicit local installation through the real package validator; no publication.
#import "MHTTrainerStore.h"
int main(int argc,const char **argv){@autoreleasepool{
 if(argc!=2)return 2;
 NSString *directory=[@(argv[1]) stringByStandardizingPath];
 NSMutableArray *errors=[NSMutableArray new];MHTModule *selected=nil;
 for(MHTModule *module in [MHTModule loadModules:directory.stringByDeletingLastPathComponent errors:errors])if([module.directory isEqual:directory])selected=module;
 if(!selected){fprintf(stderr,"Trainermodul nicht bestätigt.\n");return 1;}
 MHTTrainerStore *store=[[MHTTrainerStore alloc]initWithRootDirectory:[NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support/TrainerDock/Modules"] catalogURL:nil bundledCatalogURL:nil];
 NSError *error=nil;MHTModule *installed=[store importLegacyModule:selected error:&error];
 if(!installed){fprintf(stderr,"%s\n",error.localizedDescription.UTF8String);return 1;}
 printf("Geprüfter lokaler Trainer installiert: %s · Version %s · %s\n",installed.name.UTF8String,installed.version.UTF8String,installed.directory.UTF8String);
 return 0;
}}
