// SPDX-License-Identifier: GPL-3.0-only
#import <Foundation/Foundation.h>
// Native script callback transport for the exact verified Cyberpunk build.
typedef void (^CPScriptObservation)(uintptr_t context,NSArray<NSData *> *arguments,NSData *result);
@interface CPNativeBridge : NSObject
- (BOOL)install:(NSError **)error;
- (void)enqueue:(dispatch_block_t)work;
- (void)detach;
@property(nonatomic,readonly) BOOL insideEngineCallback;
@property(nonatomic,readonly) NSData *currentGameInstance;
@property(nonatomic,readonly) uintptr_t currentCallbackContext;
- (NSDictionary *)resolveClass:(NSString *)className method:(NSString *)method
                   parameters:(NSArray<NSString *> *)parameters result:(NSString *)result;
- (NSData *)invoke:(NSDictionary *)binding context:(uintptr_t)context
         arguments:(NSArray<NSData *> *)arguments resultSize:(NSUInteger)resultSize error:(NSError **)error;
- (void)destroyValue:(NSData *)value type:(NSString *)typeName;
- (NSNumber *)hackingTimerPaused:(NSData *)object;
- (BOOL)object:(NSData *)object isKindOf:(NSString *)className;
- (NSData *)weakForCallbackObject:(uintptr_t)object className:(NSString *)className;
- (NSData *)readProperty:(NSString *)property className:(NSString *)className object:(NSData *)object type:(NSString *)typeName;
- (NSData *)weakFromStrong:(NSData *)value className:(NSString *)className;
- (NSData *)lockWeak:(NSData *)value;
- (NSNumber *)weakIsExpired:(NSData *)value;
- (BOOL)supportsHandleClass:(NSString *)className weak:(BOOL)weak;
- (NSNumber *)enumType:(NSString *)typeName member:(NSString *)member;
- (NSDictionary *)resolveScriptClass:(NSString *)className method:(NSString *)method
                         parameters:(NSArray<NSString *> *)parameters result:(NSString *)result;
- (NSData *)invokeScript:(NSDictionary *)binding context:(uintptr_t)context
               arguments:(NSArray<NSData *> *)arguments resultSize:(NSUInteger)size error:(NSError **)error;
- (BOOL)setFrameWork:(dispatch_block_t)work world:(NSData *)world player:(NSData *)player;
- (void)clearFrameWork;
- (BOOL)setScriptObserver:(NSString *)name binding:(NSDictionary *)binding methodName:(NSString *)method handler:(CPScriptObservation)handler;
- (void)removeScriptObserver:(NSString *)name;
- (void)clearScriptObservers;
- (BOOL)configureProgressionOwner:(NSData *)owner binding:(NSDictionary *)binding settings:(NSDictionary *)settings;
- (void)clearProgression;
- (void)withoutProgression:(dispatch_block_t)work;
- (NSDictionary *)progressionObservation;
- (NSArray<NSData *> *)copyItemWeakArray:(NSData *)array;
- (NSData *)createInstance:(NSString *)className error:(NSError **)error;
- (BOOL)writeScalarProperty:(NSString *)property className:(NSString *)className
                    object:(NSData *)object type:(NSString *)typeName value:(NSData *)value;
@end
