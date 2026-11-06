// SPDX-License-Identifier: GPL-3.0-only
#import <Foundation/Foundation.h>
#import <mach-o/loader.h>
// Read-only development tools. Metadata presence never enables an effect.
uint64_t CPNameHash(NSString *name);
NSDictionary *CPReadClassMetadata(uintptr_t typesMap,NSString *name,NSArray<NSString *> *methods);
NSDictionary *CPReadCyberpunkMetadata(const struct mach_header_64 *image);
NSDictionary *CPReadCyberpunkTargets(const struct mach_header_64 *image,NSDictionary<NSString *,NSArray<NSString *> *> *targets);
// Internal bindings only; callers must validate exact signatures and engine scope.
NSDictionary *CPResolveNativeBinding(const struct mach_header_64 *image,NSString *className,NSString *method);
NSDictionary *CPResolveScriptBinding(const struct mach_header_64 *image,NSString *className,NSString *method);
NSDictionary *CPReadTypeSchema(const struct mach_header_64 *image,NSString *typeName);
uintptr_t CPFindNativeType(const struct mach_header_64 *image,NSString *typeName);
NSNumber *CPFindEnumValue(const struct mach_header_64 *image,NSString *typeName,NSString *member);
BOOL CPNativeClassIsA(const struct mach_header_64 *image,NSString *className,NSString *baseName);

uintptr_t CPFindProperty(const struct mach_header_64 *image,NSString *className,NSString *name,NSString *typeName);
