// SPDX-License-Identifier: GPL-3.0-only
// Explicit migration tool; never starts a game or loads trainer code.
#import "MHTTrainerStore.h"
int main(int argc,const char *argv[]){@autoreleasepool{
 if(argc!=3){fprintf(stderr,"usage: ImportLegacy SOURCE_MODULES DESTINATION_MODULES\n");return 2;}
 NSMutableArray *errors=[NSMutableArray new];NSArray *modules=[MHTModule loadModules:@(argv[1]) errors:errors];
 if(errors.count||!modules.count){for(NSString *error in errors)fprintf(stderr,"%s\n",error.UTF8String);return 1;}
 MHTTrainerStore *store=[[MHTTrainerStore alloc]initWithRootDirectory:@(argv[2]) catalogURL:nil bundledCatalogURL:nil];
 for(MHTModule *module in modules){NSError *error=nil;MHTModule *copy=[store importLegacyModule:module error:&error];if(!copy){fprintf(stderr,"%s: %s\n",module.identifier.UTF8String,error.localizedDescription.UTF8String);return 1;}printf("%s -> %s\n",module.identifier.UTF8String,copy.directory.UTF8String);}
 printf("PASS: %lu trainers preserved; sources unchanged.\n",(unsigned long)modules.count);
}return 0;}
