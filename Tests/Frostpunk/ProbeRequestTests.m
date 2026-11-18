// SPDX-License-Identifier: GPL-3.0-only
// Exercise the exact private probe's acceptance boundary, without a game process.
#import "IngameProbe.m"
#include <stdlib.h>

static NSUInteger scheduledInitializations;
static dispatch_block_t pendingInitialization;
__attribute__((visibility("default"))) void FPOnGameThread(dispatch_block_t work) {
    scheduledInitializations++;
    pendingInitialization = [work copy];
}

static void require(BOOL condition, NSString *label) {
    if (!condition) { NSLog(@"Frostpunk-Prüfprotokoll fehlgeschlagen: %@", label); exit(1); }
}
int main(void) { @autoreleasepool {
    session = @"test-frostpunk-session-only";
    seen = [NSMutableOrderedSet new];
    NSMutableDictionary *request = [@{@"session":session,@"pid":@(getpid()),
        @"requestID":NSUUID.UUID.UUIDString,@"deadline":@(NSDate.date.timeIntervalSince1970 + 3),
        @"action":@"snapshot"} mutableCopy];
    require(validRequest(request), @"Gültiger expliziter Nur-Lese-Auftrag");
    NSArray *cases = @[
        @[@"session",@"other-session"], @[@"pid",@(getpid() + 1)],
        @[@"pid",@((double)getpid() + 0.5)], @[@"pid",@"123"],
        @[@"requestID",@"not-a-request-uuid"], @[@"action",@"set"],
        @[@"action",@"disableAll"], @[@"deadline",@"future"],
        @[@"deadline",@(NAN)], @[@"deadline",@(INFINITY)],
        @[@"deadline",@(NSDate.date.timeIntervalSince1970 - 1)],
        @[@"deadline",@(NSDate.date.timeIntervalSince1970 + 6)]
    ];
    for (NSArray *entry in cases) {
        NSMutableDictionary *invalid = [request mutableCopy];
        invalid[entry[0]] = entry[1];
        require(!validRequest(invalid), [NSString stringWithFormat:@"Ungültiges Feld: %@", entry[0]]);
    }
    for (NSString *key in @[@"session",@"pid",@"requestID",@"deadline",@"action"]) {
        NSMutableDictionary *missing = [request mutableCopy];
        [missing removeObjectForKey:key];
        require(!validRequest(missing), [@"Pflichtfeld fehlt: " stringByAppendingString:key]);
    }
    [seen addObject:request[@"requestID"]];
    require(!validRequest(request), @"Doppelte Zustellung ist gesperrt");
    [seen removeAllObjects];
    require(validRequest(request), @"Frische sitzungsgebundene Zustellung bleibt möglich");
    // The real startup path must only enqueue. In particular it must not read
    // bundle metadata or register distributed observers inside SDL's HID loop.
    session = nil;
    seen = nil;
    observer = nil;
    scheduledInitializations = 0;
    pendingInitialization = nil;
    setenv("MHT_FROSTPUNK_PROBE", "1", 1);
    startFrostpunkProbe();
    require(scheduledInitializations == 1 && pendingInitialization != nil,
            @"Initialisierung wartet auf den originalen SDL-Rückruf");
    require(session == nil && seen == nil && observer == nil,
            @"Keine vorzeitige Kontextprüfung oder Beobachterregistrierung");
    unsetenv("MHT_FROSTPUNK_PROBE");
    pendingInitialization = nil;
    NSLog(@"Frostpunk-Prüfprotokollgrenzen geprüft; kein Spiel gestartet.");
    return 0;
} }
