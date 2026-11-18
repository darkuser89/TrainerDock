// SPDX-License-Identifier: GPL-3.0-only
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

#if defined(MHT_LAUNCHER_LOCALIZATION)
NSString *MHTLocalized(NSString *key) NS_FORMAT_ARGUMENT(1);
NSError *MHTLocalizedError(NSError *error);
#else
// Standalone developer tools share Core, but have no launcher resources.
static inline NSString *MHTLocalized(NSString *key) NS_FORMAT_ARGUMENT(1);
static inline NSString *MHTLocalized(NSString *key) {return key;}
static inline NSError *MHTLocalizedError(NSError *error) {return error;}
#endif

NSString *MHTInterfaceLanguage(void);
NSString * _Nullable MHTLanguageOverride(void);
void MHTSetLanguageOverride(NSString * _Nullable language);

NS_ASSUME_NONNULL_END
