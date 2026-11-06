// SPDX-License-Identifier: GPL-3.0-only
#import "MHTApp.h"
#import "MHTModule.h"
#import "MHTDiscovery.h"
#import "MHTBranding.h"
int main(int argc,const char *argv[]) {@autoreleasepool {
    if(![NSProcessInfo.processInfo isOperatingSystemAtLeastVersion:(NSOperatingSystemVersion){27,0,0}]){
        fprintf(stderr,"TrainerDock benötigt macOS 27 oder neuer.\n");return 1;
    }
    MHTMigrateLegacyPreferences();
    if(argc==2 && (!strcmp(argv[1],"--check") || !strcmp(argv[1],"--validate-installed"))) {
        NSMutableArray *errors=[NSMutableArray new];
        NSArray *modules=[MHTModule availableModules:errors];
        for(NSString *error in errors)fprintf(stderr,"%s\n",error.UTF8String);
        printf("%lu trainers loaded; %lu errors. No games launched.\n",(unsigned long)modules.count,(unsigned long)errors.count);
        if(!strcmp(argv[1],"--validate-installed")){
            MHTDiscoverInstallations(modules);
            for(MHTModule *module in modules)for(NSDictionary *profile in module.profiles){
                if(!MHTIsInstalled(module,profile))continue;
                NSError *failure=nil;BOOL valid=[module inspectPath:[module pathForProfile:profile] profile:profile error:&failure]!=nil;
                printf("%s / %s: %s\n",module.name.UTF8String,[profile[@"store"] UTF8String],valid ? "identity and signature confirmed" : failure.localizedDescription.UTF8String);
                if(!valid)[errors addObject:failure.localizedDescription ?: @"Identity check failed."];
            }
        }
        return modules.count && !errors.count ? 0 : 1;
    }
    if(argc>2 || (argc==2 && strcmp(argv[1],"--smoke")))return 2;
    [NSApplication sharedApplication];[NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
    MHTApp *delegate=[MHTApp new];delegate.smokeTest=argc==2;NSApp.delegate=delegate;[NSApp run];
}return 0;}
