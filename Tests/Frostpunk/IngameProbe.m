// SPDX-License-Identifier: GPL-3.0-only
// Explicit, read-only local diagnostics. Never compile into a shipped trainer.
#import <Foundation/Foundation.h>
#include <dlfcn.h>
#include <limits.h>
#include <mach/mach.h>
#include <mach/mach_vm.h>
#include <mach-o/dyld.h>
#include <mach-o/loader.h>
#include <math.h>
#include <string.h>
#include <unistd.h>
#include <uuid/uuid.h>

typedef void (*FPProbeSchedule)(dispatch_block_t);
typedef NSDictionary *(*FPProbeInspect)(void);
static NSString *const requestName = @"local.trainerdock.frostpunk.probe.request";
static NSString *const responseName = @"local.trainerdock.frostpunk.probe.response";
static NSString *const originalUUID = @"381A9DB7-5849-39B1-85BC-208861544E41";
static NSString *session;
static id observer;
static NSMutableOrderedSet<NSString *> *seen;

static BOOL readAt(uintptr_t object, size_t offset, void *result, size_t length) {
    if (object < 4096 || !result || !length || offset > UINTPTR_MAX - object ||
        length > UINTPTR_MAX - object - offset) return NO;
    mach_vm_size_t received = 0;
    return mach_vm_read_overwrite(mach_task_self(), object + offset, length,
        (mach_vm_address_t)result, &received) == KERN_SUCCESS && received == length;
}
static NSString *pointerText(uintptr_t value) { return [NSString stringWithFormat:@"%p", (void *)value]; }
static NSString *entryName(uintptr_t entry) {
    uintptr_t characters = 0;
    if (!readAt(entry, 0, &characters, sizeof(characters))) return nil;
    char name[160];
    for (size_t index = 0; index < sizeof(name); index++) {
        if (!readAt(characters, index, &name[index], 1)) return nil;
        if (!name[index]) return [[NSString alloc] initWithBytes:name length:index encoding:NSUTF8StringEncoding];
        if ((unsigned char)name[index] < 0x20 || (unsigned char)name[index] > 0x7e) return nil;
    }
    return nil;
}
static NSDictionary *resourceSnapshot(NSDictionary *context) {
    if ([context[@"kind"] integerValue] != 2) return @{@"resources":@[]};
    uintptr_t slot = (uintptr_t)dlsym(RTLD_MAIN_ONLY, "gEconomy"), economy = 0, table = 0;
    int32_t count = 0;
    NSArray *identity = [context[@"identity"] componentsSeparatedByString:@":"];
    if (!readAt(slot, 0, &economy, sizeof(economy)) || identity.count != 5 ||
        ![identity[2] isEqual:pointerText(economy)] ||
        !readAt(economy, 0x2240, &table, sizeof(table)) ||
        !readAt(economy, 0x2248, &count, sizeof(count)) || count < 1 || count > 256)
        return @{@"resourcesError":@"Ressourcen gehören nicht zum bestätigten Stadtbesitzer."};
    NSMutableArray *records = [NSMutableArray new];
    for (int32_t index = 0; index < count; index++) {
        size_t offset = (size_t)index * 0x70;
        uintptr_t entry = 0;
        int32_t amount = 0, capacity = 0;
        uint8_t visible = 0;
        if (!readAt(table, offset, &entry, sizeof(entry)) ||
            !readAt(table, offset + 8, &amount, sizeof(amount)) ||
            !readAt(table, offset + 12, &capacity, sizeof(capacity)) ||
            !readAt(table, offset + 16, &visible, sizeof(visible)))
            return @{@"resourcesError":@"Originaler Ressourceneintrag ist nicht vollständig lesbar."};
        NSString *name = entryName(entry);
        NSMutableDictionary *record = [@{@"index":@(index),@"entry":pointerText(entry),
            @"record":pointerText(table + offset),@"amount":@(amount),
            @"capacity":@(capacity),@"visible":@(visible != 0)} mutableCopy];
        if (name) record[@"name"] = name; else record[@"nameReadable"] = @NO;
        [records addObject:record];
    }
    uintptr_t currentEconomy = 0, currentTable = 0;
    int32_t currentCount = 0;
    if (!readAt(slot, 0, &currentEconomy, sizeof(currentEconomy)) || currentEconomy != economy ||
        !readAt(economy, 0x2240, &currentTable, sizeof(currentTable)) || currentTable != table ||
        !readAt(economy, 0x2248, &currentCount, sizeof(currentCount)) || currentCount != count)
        return @{@"resourcesError":@"Stadtbesitzer wechselte während der Leseprüfung."};
    return @{@"resources":records,@"economy":pointerText(economy),@"resourceCount":@(count)};
}

static uintptr_t originalSlot(const char *name) {
    uintptr_t slot = (uintptr_t)dlsym(RTLD_MAIN_ONLY, name), object = 0;
    return readAt(slot, 0, &object, sizeof(object)) ? object : 0;
}

static NSDictionary *workAndResearchSnapshot(NSDictionary *context) {
    if ([context[@"kind"] integerValue] != 2) return @{};
    NSMutableDictionary *result = [NSMutableDictionary new];
    uintptr_t building = originalSlot("gBuildingWorkSystem"), queue = 0;
    int32_t count = 0;
    if (readAt(building, 0x2060, &queue, sizeof(queue)) &&
        readAt(building, 0x2068, &count, sizeof(count)) && count >= 0 && count <= 4096) {
        NSMutableArray *entities = [NSMutableArray new];
        BOOL complete = YES;
        for (int32_t index = 0; index < count && index < 64; index++) {
            uintptr_t entity = 0;
            if (!readAt(queue, (size_t)index * sizeof(entity), &entity, sizeof(entity))) { complete = NO; break; }
            [entities addObject:pointerText(entity)];
        }
        uintptr_t afterQueue = 0;
        int32_t afterCount = -1;
        if (complete && originalSlot("gBuildingWorkSystem") == building &&
            readAt(building, 0x2060, &afterQueue, sizeof(afterQueue)) && afterQueue == queue &&
            readAt(building, 0x2068, &afterCount, sizeof(afterCount)) && afterCount == count) {
            result[@"buildingQueueCount"] = @(count);
            result[@"buildingQueueEntities"] = entities;
            result[@"buildingQueueTruncated"] = @(count > 64);
        } else result[@"buildingQueueError"] = @"Bauaufträge wechselten während der Leseprüfung.";
    } else result[@"buildingQueueError"] = @"Bauaufträge sind nicht begrenzt lesbar.";

    uintptr_t technology = originalSlot("gTechnologySystem"), map = 0, current = 0;
    count = 0;
    if (!readAt(technology, 0x2248, &map, sizeof(map)) ||
        !readAt(technology, 0x2250, &count, sizeof(count)) || count < 0 || count > 2048 ||
        !readAt(technology, 0x2260, &current, sizeof(current))) {
        result[@"researchError"] = @"Forschungszustand ist nicht begrenzt lesbar.";
        return result;
    }
    // Original 0x10081a43c: bool(this, const Entry*, ErrorList*). Static analysis
    // confirms nullable ErrorList. Only existing loaded state-0 entries are asked;
    // no Start/Finish/AddResearched function is ever called by this probe.
    BOOL (*canStart)(const void *, const void *, void *) = (void *)dlsym(RTLD_MAIN_ONLY,
        "_ZNK25FrostpunkTechnologySystem26CanStartTechnologyResearchEPK24FrostpunkTechnologyEntryP22FrostpunkGameErrorList");
    NSMutableArray *entries = [NSMutableArray new];
    BOOL complete = YES;
    NSUInteger checkedCandidates = 0;
    for (int32_t index = 0; index < count && index < 128; index++) {
        uintptr_t entry = 0;
        int32_t state = -1;
        uint8_t loaded = 0;
        if (!readAt(map, (size_t)index * 16, &entry, sizeof(entry)) ||
            !readAt(map, (size_t)index * 16 + 8, &state, sizeof(state)) ||
            !readAt(entry, 0x30, &loaded, sizeof(loaded))) { complete = NO; break; }
        NSMutableDictionary *item = [@{@"index":@(index),@"entry":pointerText(entry),
            @"state":@(state),@"loaded":@(loaded != 0),@"current":@(entry == current)} mutableCopy];
        NSString *name = entryName(entry);
        if (name) item[@"name"] = name;
        if (canStart && state == 0 && loaded && checkedCandidates < 16) {
            item[@"canStart"] = @(canStart((const void *)technology, (const void *)entry, NULL));
            checkedCandidates++;
        }
        [entries addObject:item];
    }
    uintptr_t afterMap = 0, afterCurrent = 0;
    int32_t afterCount = -1;
    if (!complete || originalSlot("gTechnologySystem") != technology ||
        !readAt(technology, 0x2248, &afterMap, sizeof(afterMap)) || afterMap != map ||
        !readAt(technology, 0x2250, &afterCount, sizeof(afterCount)) || afterCount != count ||
        !readAt(technology, 0x2260, &afterCurrent, sizeof(afterCurrent)) || afterCurrent != current) {
        result[@"researchError"] = @"Forschungsbesitzer wechselte während der Leseprüfung.";
        return result;
    }
    result[@"researchCount"] = @(count);
    result[@"researchCurrent"] = pointerText(current);
    result[@"researchEntries"] = entries;
    result[@"researchTruncated"] = @(count > 128);
    result[@"researchCanStartChecks"] = @(checkedCandidates);
    return result;
}

static NSDictionary *gameSpeedSnapshot(NSDictionary *context) {
    if ([context[@"kind"] integerValue] != 2) return @{};
    uintptr_t game = (uintptr_t)dlsym(RTLD_MAIN_ONLY, "gFrostpunkGame");
    uintptr_t config = (uintptr_t)dlsym(RTLD_MAIN_ONLY, "gFrostpunkGameConfig");
    uintptr_t time = originalSlot("gTimeSystem"), gameplayTimer = 0;
    NSArray *identity = [context[@"identity"] componentsSeparatedByString:@":"];
    float multiplier = 0, speeds[3] = {0};
    if (identity.count != 5 || ![identity[0] isEqual:pointerText(game)] || !time ||
        !readAt(game, 0x3f0, &gameplayTimer, sizeof(gameplayTimer)) ||
        !readAt(gameplayTimer, 0xd0, &multiplier, sizeof(multiplier)) || !isfinite(multiplier) ||
        !readAt(config, 0x204, speeds, sizeof(speeds))) return @{};
    for (NSUInteger index = 0; index < 3; index++)
        if (!isfinite(speeds[index]) || speeds[index] < 0 || speeds[index] > 1000) return @{};
    // Original 0x10053a70e is a pure int getter: compares GameplayTimer +0xd0
    // against the three original config multipliers and returns 0..2 or -1.
    // This enum alone does not prove the user's separate pause state.
    int (*getSpeed)(const void *) = (void *)dlsym(RTLD_MAIN_ONLY,
        "_ZNK19FrostpunkTimeSystem19GetCurrentGameSpeedEv");
    if (!getSpeed) return @{};
    int speed = getSpeed((const void *)time);
    if (speed < -1 || speed > 2) return @{};
    return @{@"gameSpeedEnum":@(speed),@"gameplayTimerMultiplier":@(multiplier),
        @"gameSpeedMultipliers":@[@(speeds[0]),@(speeds[1]),@(speeds[2])]};
}

static BOOL exactOriginal(void) {
    const struct mach_header *header = _dyld_get_image_header(0);
    if (!header || header->magic != MH_MAGIC_64 || header->cputype != CPU_TYPE_X86_64) return NO;
    const struct mach_header_64 *image = (const struct mach_header_64 *)header;
    const uint8_t *cursor = (const uint8_t *)(image + 1);
    const uint8_t *end = cursor + image->sizeofcmds;
    BOOL matchedUUID = NO;
    if (image->sizeofcmds > 1024 * 1024 || image->ncmds > 4096) return NO;
    for (uint32_t index = 0; index < image->ncmds; index++) {
        if ((size_t)(end - cursor) < sizeof(struct load_command)) return NO;
        const struct load_command *command = (const struct load_command *)cursor;
        if (command->cmdsize < sizeof(*command) || command->cmdsize > (size_t)(end - cursor)) return NO;
        if (command->cmd == LC_UUID) {
            if (command->cmdsize < sizeof(struct uuid_command)) return NO;
            uuid_string_t text;
            uuid_unparse_upper(((const struct uuid_command *)command)->uuid, text);
            matchedUUID = [originalUUID isEqualToString:@(text)];
        }
        cursor += command->cmdsize;
    }
    NSBundle *bundle = NSBundle.mainBundle;
    if (!matchedUUID || ![bundle.bundleIdentifier isEqual:@"com.11bitstudios.frostpunk"] ||
        ![[bundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"] isEqual:@"1.1.1"] ||
        ![[bundle objectForInfoDictionaryKey:@"CFBundleVersion"] isEqual:@"20201216.0"] ||
        ![bundle.executablePath.lastPathComponent isEqual:@"Frostpunk"]) return NO;
    // The launch helper fully verifies original files and the Steam build before
    // launch. Reopening Steam's manifest here can block during SDL's nested HID
    // startup runloop. Bind only the already loaded identity inside the process.
    return YES;
}

static void reply(NSDictionary *request, NSDictionary *result) {
    NSMutableDictionary *response = [result mutableCopy];
    response[@"module"] = @"frostpunk";
    response[@"session"] = session;
    response[@"pid"] = @(getpid());
    response[@"requestID"] = request[@"requestID"];
    response[@"steamBuild"] = @"15262773";
    response[@"uuid"] = originalUUID;
    NSData *data = [NSJSONSerialization dataWithJSONObject:response options:0 error:NULL];
    if (!data || data.length > 65536) {
        [response removeObjectForKey:@"snapshot"];
        response[@"error"] = @"Native Leseantwort überschreitet die erlaubte Nachrichtengröße.";
        data = [NSJSONSerialization dataWithJSONObject:response options:0 error:NULL];
    }
    if (!data || data.length > 65536) return;
    NSString *payload = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSDistributedNotificationCenter.defaultCenter postNotificationName:responseName
            object:payload userInfo:nil deliverImmediately:YES];
    });
}

static BOOL validRequest(NSDictionary *request) {
    id identifier = request[@"requestID"], process = request[@"pid"], deadline = request[@"deadline"];
    double now = NSDate.date.timeIntervalSince1970;
    return [request[@"session"] isEqual:session] && [request[@"action"] isEqual:@"snapshot"] &&
        [process isKindOfClass:NSNumber.class] && [process doubleValue] == getpid() &&
        [identifier isKindOfClass:NSString.class] && [identifier length] == 36 &&
        [[NSUUID alloc] initWithUUIDString:identifier] != nil &&
        [deadline isKindOfClass:NSNumber.class] && isfinite([deadline doubleValue]) &&
        [deadline doubleValue] >= now && [deadline doubleValue] <= now + 5 &&
        ![seen containsObject:identifier];
}

__attribute__((constructor)) static void startFrostpunkProbe(void) { @autoreleasepool {
    if (strcmp(getenv("MHT_FROSTPUNK_PROBE") ?: "", "1")) return;
    // Do not use an eager dispatch-main block: SDL can drain it inside HID
    // initialization before the application's launch is complete. Enqueue once
    // and register only at the trainer's verified original SDL_PollEvent boundary.
    FPProbeSchedule scheduleInitialization = (FPProbeSchedule)dlsym(RTLD_DEFAULT, "FPOnGameThread");
    if (!scheduleInitialization) return;
    scheduleInitialization(^{ @autoreleasepool {
        NSDictionary *environment = NSProcessInfo.processInfo.environment;
        session = environment[@"MHT_SESSION"];
        if (![environment[@"MHT_MODULE"] isEqual:@"frostpunk"] ||
            ![environment[@"MHT_PROFILE"] isEqual:@"steam-x86_64-15262773"] ||
            session.length < 16 || session.length > 256 || !exactOriginal()) return;
        seen = [NSMutableOrderedSet new];
        observer = [NSDistributedNotificationCenter.defaultCenter addObserverForName:requestName
            object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *event) {
                if (![event.object isKindOfClass:NSString.class] || [event.object length] > 4096) return;
                NSData *data = [event.object dataUsingEncoding:NSUTF8StringEncoding];
                id parsed = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
                if (![parsed isKindOfClass:NSDictionary.class] || !validRequest(parsed)) return;
                NSDictionary *request = parsed;
                [seen addObject:request[@"requestID"]];
                if (seen.count > 64) [seen removeObjectAtIndex:0];
                FPProbeSchedule schedule = (FPProbeSchedule)dlsym(RTLD_DEFAULT, "FPOnGameThread");
                FPProbeInspect inspect = (FPProbeInspect)dlsym(RTLD_DEFAULT, "FPInspect");
                if (!schedule || !inspect) {
                    reply(request, @{@"error":@"Originale Trainer-Rückrufexports fehlen."}); return;
                }
                schedule(^{ @autoreleasepool {
                    if ([request[@"deadline"] doubleValue] < NSDate.date.timeIntervalSince1970) {
                        reply(request, @{@"error":@"Leseauftrag ist abgelaufen."}); return;
                    }
                    @try {
                        NSDictionary *snapshot = inspect();
                        if (![snapshot isKindOfClass:NSDictionary.class]) {
                            reply(request, @{@"error":@"Keine native Leseantwort."}); return;
                        }
                        NSMutableDictionary *values = [snapshot mutableCopy];
                        [values addEntriesFromDictionary:resourceSnapshot(snapshot)];
                        [values addEntriesFromDictionary:workAndResearchSnapshot(snapshot)];
                        [values addEntriesFromDictionary:gameSpeedSnapshot(snapshot)];
                        reply(request, @{@"snapshot":values,@"readOnly":@YES});
                    } @catch (NSException *exception) {
                        (void)exception;
                        reply(request, @{@"error":@"Native Leseprüfung wurde abgebrochen."});
                    }
                }});
            }];
    }});
}}
