// SPDX-License-Identifier: GPL-3.0-only
#import "MHTLocalization.h"

static NSString *const appleLanguages = @"AppleLanguages";

static NSString *supportedLanguage(id identifier) {
    if (![identifier isKindOfClass:NSString.class] || ![identifier length]) return nil;
    NSString *code = [[NSLocale componentsFromLocaleIdentifier:identifier][NSLocaleLanguageCode] lowercaseString];
    if ([code isEqualToString:@"de"] || [code isEqualToString:@"ro"] || [code isEqualToString:@"en"]) return code;
    return nil;
}

NSString *MHTInterfaceLanguage(void) {
    static NSString *language;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSArray *preferred = [NSUserDefaults.standardUserDefaults arrayForKey:appleLanguages];
        id primary = preferred.firstObject ?: NSLocale.preferredLanguages.firstObject;
        language = supportedLanguage(primary) ?: @"en";
        // Normalize the native AppKit/NSBundle language too, without changing
        // the user's saved System/override choice or global OS preferences.
        NSMutableDictionary *arguments = [[NSUserDefaults.standardUserDefaults volatileDomainForName:NSArgumentDomain] mutableCopy];
        if (!arguments) arguments = [NSMutableDictionary new];
        arguments[appleLanguages] = @[language];
        [NSUserDefaults.standardUserDefaults setVolatileDomain:arguments forName:NSArgumentDomain];
    });
    return language;
}

NSString *MHTLanguageOverride(void) {
    NSString *identifier = NSBundle.mainBundle.bundleIdentifier;
    if (!identifier.length) return nil;
    // Look only in this app's domain so an inherited preference is shown as System.
    id languages = [NSUserDefaults.standardUserDefaults persistentDomainForName:identifier][appleLanguages];
    return [languages isKindOfClass:NSArray.class] ? supportedLanguage([languages firstObject]) : nil;
}

void MHTSetLanguageOverride(NSString *language) {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    if (!language) {
        [defaults removeObjectForKey:appleLanguages];
    } else {
        NSString *code = supportedLanguage(language);
        if (code) [defaults setObject:@[code] forKey:appleLanguages];
    }
}

NSString *MHTLocalized(NSString *key) {
    NSString *language = MHTInterfaceLanguage();
    NSBundle *bundle = NSBundle.mainBundle;
    if (![language isEqualToString:@"en"]) {
        NSString *missing = @"\001";
        NSString *translation = [bundle localizedStringForKey:key value:missing table:nil localizations:@[language]];
        if (![translation isEqualToString:missing]) return translation;
    }
    return [bundle localizedStringForKey:key value:key table:nil localizations:@[@"en"]];
}

NSError *MHTLocalizedError(NSError *error) {
    // GameIdentity is also compiled into unchanged trainer runtimes. Translate
    // its host-facing errors here, keeping the shared verifier byte-for-byte.
    NSString *reason = error.localizedDescription;
    NSString *translated = MHTLocalized(reason);
    NSScanner *scanner = [NSScanner scannerWithString:reason];
    scanner.charactersToBeSkipped = nil;
    int status = 0;
    if ([scanner scanString:@"Originalsignatur nicht bestätigt (" intoString:NULL] &&
        [scanner scanInt:&status] && [scanner scanString:@")." intoString:NULL] && scanner.isAtEnd) {
        translated = [NSString stringWithFormat:MHTLocalized(@"Originalsignatur nicht bestätigt (%d)."), status];
    }
    if ([reason isEqualToString:translated]) return error;
    NSMutableDictionary *info = [error.userInfo mutableCopy];
    info[NSLocalizedDescriptionKey] = translated;
    return [NSError errorWithDomain:error.domain code:error.code userInfo:info];
}
