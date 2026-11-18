// SPDX-License-Identifier: GPL-3.0-only
#import "FrostpunkResources.h"
#import "TrainerFeatures.h"
#include <limits.h>
#include <math.h>
#include <string.h>

// Native x86_64 layout verified against build 15262773's own symbols, property
// registration and setter instructions. A map key is an EntryPtr (one pointer),
// not an EntryLink (a 16-byte GUID). The original setters own all notifications.
enum { FPResourceLimit = 64, FPResourceStride = 0x70, FPStorageTarget = 1000000 };
typedef void (*ChangeResource)(void *, const void *, int, int);
typedef void (*ChangeCapacity)(void *, const void *, int);
typedef void *(*ResolveEntry)(const void *);
typedef struct {
    void *entry, *record;
    int capacityBefore, capacityWritten, capacityDelta;
    BOOL leased, conflicted, storageTarget;
} ResourceSlot;
static struct {
    FPOwner owner;
    void *table;
    int count;
    ResourceSlot records[FPResourceLimit];
    int featureSlots[10];
    BOOL populated;
} cache;

static BOOL sameCurrent(FPOwner owner) {
    return owner.gameplay && owner.economy && owner.economyConfig &&
        FPSameOwner(owner, FPCaptureOwner());
}
static BOOL tableHeader(FPOwner owner, void **table, int *count) {
    return FPReadAt(owner.economy, 0x2240, table, sizeof(*table)) &&
        FPReadAt(owner.economy, 0x2248, count, sizeof(*count)) &&
        *table && *count > 0 && *count <= FPResourceLimit &&
        (uintptr_t)*table <= UINTPTR_MAX - (size_t)*count * FPResourceStride;
}
static BOOL fields(ResourceSlot *slot, int *amount, int *capacity, BOOL *visible) {
    void *entry = NULL;
    uint8_t shown = 0;
    if (!slot || !slot->entry || !FPReadAt(slot->record, 0, &entry, sizeof(entry)) ||
        entry != slot->entry || !FPReadAt(slot->record, 8, amount, sizeof(*amount)) ||
        !FPReadAt(slot->record, 12, capacity, sizeof(*capacity)) ||
        !FPReadAt(slot->record, 16, &shown, sizeof(shown)) || shown > 1 ||
        *amount < 0 || *capacity < 0) return NO;
    *visible = shown != 0;
    return YES;
}
static BOOL entryName(void *entry, const char *expected) {
    const char *name = NULL;
    if (!FPReadAt(entry, 0, &name, sizeof(name)) || !name) return NO;
    size_t length = strlen(expected);
    if (length >= 80) return NO;
    char bytes[80] = {0};
    return FPReadAt(name, 0, bytes, length + 1) && memcmp(bytes, expected, length + 1) == 0;
}
static BOOL prepare(FPOwner owner) {
    void *table = NULL;
    int count = 0;
    if (!sameCurrent(owner) || !tableHeader(owner, &table, &count)) return NO;
    if (cache.populated && FPSameOwner(cache.owner, owner) && cache.table == table && cache.count == count)
        return YES;
    // A replaced table/world must never cause a rollback through stale records.
    memset(&cache, 0, sizeof(cache));
    cache.owner = owner;
    cache.table = table;
    cache.count = count;
    for (int index = 0; index < 10; index++) cache.featureSlots[index] = -1;
    ResolveEntry resolve = (ResolveEntry)FPOriginalSymbol("_ZNK9EntryLinkI22FrostpunkResourceEntryE8GetEntryEv");
    if (!resolve) return NO;
    // Own engine configuration links, including the three Last Autumn resources.
    const size_t offsets[10] = {0xe8,0x128,0x118,0x138,0x108,0,0,0x148,0x168,0x158};
    void *entries[10] = {0};
    for (int feature = 0; feature < 10; feature++) {
        if (!offsets[feature]) continue;
        uint8_t guid[16];
        if (!FPReadAt(owner.economyConfig, offsets[feature], guid, sizeof(guid))) return NO;
        entries[feature] = resolve((const uint8_t *)owner.economyConfig + offsets[feature]);
    }
    uint8_t foodGuid[16];
    if (!FPReadAt(owner.economyConfig, 0xf8, foodGuid, sizeof(foodGuid))) return NO;
    void *foodRations = resolve((const uint8_t *)owner.economyConfig + 0xf8);
    for (int index = 0; index < count; index++) {
        ResourceSlot *slot = &cache.records[index];
        slot->record = (uint8_t *)table + (size_t)index * FPResourceStride;
        if (!FPReadAt(slot->record, 0, &slot->entry, sizeof(slot->entry)) || !slot->entry) return NO;
        slot->storageTarget = foodRations && foodRations == slot->entry;
        for (int feature = 0; feature < 10; feature++) {
            if (entries[feature] && entries[feature] == slot->entry) {
                cache.featureSlots[feature] = index;
                slot->storageTarget = YES;
            }
        }
        // Unlike the other resources this entry has no dedicated economy link.
        // Exact native entry names only; no label, fuzzy or ordinal fallback.
        // Original paused-city snapshot: this exact native entry is the
        // prosthesis resource. No translated labels or unobserved aliases.
        if (entryName(slot->entry, "Augmentation parts")) {
            cache.featureSlots[MTFeatureProstheses] = index;
            slot->storageTarget = YES;
        }
    }
    cache.populated = YES;
    return YES;
}
static ResourceSlot *featureSlot(NSInteger feature) {
    if (feature < 0 || feature >= 10 || feature == MTFeatureStorage) return NULL;
    int index = cache.featureSlots[feature];
    return index >= 0 && index < cache.count ? &cache.records[index] : NULL;
}
static NSDictionary *state(BOOL available, BOOL active, NSString *note) {
    return @{@"available":@(available), @"active":@(active), @"note":note};
}
static BOOL releaseSlot(FPOwner owner, ResourceSlot *slot, ChangeCapacity change) {
    if (!slot->leased) return !slot->conflicted;
    int amount = 0, capacity = 0;
    BOOL visible = NO;
    if (!change || !sameCurrent(owner) || !fields(slot, &amount, &capacity, &visible) ||
        capacity != slot->capacityWritten) {
        slot->leased = NO;
        slot->conflicted = YES;
        return NO;
    }
    change(owner.economy, slot->entry, -slot->capacityDelta);
    slot->leased = NO;
    BOOL restored = fields(slot, &amount, &capacity, &visible) && capacity == slot->capacityBefore;
    slot->conflicted = !restored;
    return restored;
}
NSDictionary *FPResourceEffect(FPOwner owner, NSInteger feature, BOOL wanted, double value) {
    (void)value;
    if (feature < 0 || feature >= 10 || !prepare(owner))
        return state(NO, NO, @"Keine gültige Ressourcenverwaltung der aktuellen Stadt.");
    if (feature != MTFeatureStorage) {
        int amount = 0, capacity = 0;
        BOOL visible = NO;
        ResourceSlot *slot = featureSlot(feature);
        if (!fields(slot, &amount, &capacity, &visible))
            return state(NO, NO, @"Kein gültiger Originaleintrag dieser Ressource in der aktuellen Stadt.");
        return state(YES, NO, visible ?
            [NSString stringWithFormat:@"Aktueller Bestand: %d · einmalig hinzufügen.",amount] :
            [NSString stringWithFormat:@"Bestand: %d · Rohstoff ausgeblendet; Anzeige und Nutzung erfordern den passenden Spielkontext.",amount]);
    }
    ChangeCapacity change = (ChangeCapacity)FPOriginalSymbol("_ZN16FrostpunkEconomy22ChangeResourceCapacityEPK22FrostpunkResourceEntryi");
    if (!change) return state(NO, NO, @"Der originale Lagerzugriff ist nicht gebunden.");
    BOOL any = NO, confirmed = YES, conflict = NO;
    for (int index = 0; index < cache.count; index++) {
        ResourceSlot *slot = &cache.records[index];
        // Expand only the nine identified trainer resources and food rations.
        // UI visibility does not restrict the original inventory setters. Bodies
        // and any unknown future resource are never trainer-owned capacity leases.
        if (!slot->storageTarget) continue;
        int amount = 0, capacity = 0;
        BOOL visible = NO;
        if (!wanted) {
            if (slot->leased) confirmed &= releaseSlot(owner, slot, change);
            conflict |= slot->conflicted;
            slot->conflicted = NO;
            continue;
        }
        if (!fields(slot, &amount, &capacity, &visible)) {confirmed = NO; continue;}
        any = YES;
        if (slot->leased && capacity != slot->capacityWritten) {
            slot->leased = NO;
            slot->conflicted = YES;
        }
        if (slot->conflicted) {confirmed = NO; conflict = YES; continue;}
        if (capacity < FPStorageTarget) {
            if (!sameCurrent(owner)) return state(NO, NO, @"Die Stadt hat während des Auftrags gewechselt.");
            int before = capacity, delta = FPStorageTarget - capacity;
            change(owner.economy, slot->entry, delta);
            if (!fields(slot, &amount, &capacity, &visible)) {confirmed = NO; continue;}
            if (capacity > before) {
                slot->capacityBefore = before;
                slot->capacityWritten = capacity;
                slot->capacityDelta = capacity - before;
                slot->leased = YES;
            }
        }
        confirmed &= capacity >= FPStorageTarget;
    }
    if (conflict) return state(YES, NO, @"Lager fremd geändert; fremde Werte bleiben erhalten.");
    if (!wanted) return state(YES, NO, confirmed ? @"Eigene Lagererweiterung zurückgenommen." : @"Lager-Rücknahme nicht bestätigt.");
    return state(any, any && confirmed, any && confirmed ? @"Lagergrenzen mindestens 1.000.000; nativ bestätigt." : @"Lagererweiterung noch nicht vollständig bestätigt.");
}
NSString *FPResourceAction(FPOwner owner, NSInteger feature, double value) {
    if (feature < 0 || feature >= 10 || feature == MTFeatureStorage)
        return @"Diese Funktion ist keine Ressourcen-Einmalaktion.";
    const MTFeatureInfo *info = MTFeatureInfoAt((MTFeature)feature);
    if (!info || !isfinite(value) || value != floor(value) || value < info->minimum || value > info->maximum || value > INT_MAX)
        return @"Ungültige Ressourcenmenge; nur ganze Werte innerhalb der angezeigten Grenzen.";
    if (!prepare(owner)) return @"Keine gültige Ressourcenverwaltung der aktuellen Stadt.";
    ResourceSlot *slot = featureSlot(feature);
    int before = 0, capacity = 0;
    BOOL visible = NO;
    if (!fields(slot, &before, &capacity, &visible))
        return @"Kein gültiger Originaleintrag dieser Ressource in der aktuellen Stadt.";
    int delta = (int)value;
    if (before > INT_MAX - delta) return @"Die Ressourcenmenge würde die native Zahlengrenze überschreiten.";
    ChangeResource change = (ChangeResource)FPOriginalSymbol("_ZN16FrostpunkEconomy14ChangeResourceEPK22FrostpunkResourceEntryi19eResourceChangeType");
    if (!change || !sameCurrent(owner)) return @"Der originale Ressourcenzugriff ist nicht verfügbar.";
    // Original starting-resource/debug callsites use enum value zero. The narrow
    // overload supplies null Vector and false itself; no invented context object.
    change(owner.economy, slot->entry, delta, 0);
    int after = 0;
    if (!sameCurrent(owner) || !fields(slot, &after, &capacity, &visible))
        return @"Ressourcenänderung nicht zurückgelesen; kein erneuter Auftrag ausgelöst.";
    if (after != before + delta)
        return [NSString stringWithFormat:@"Nur %d von %d hinzugefügt; native Lagergrenzen beachten.",after-before,delta];
    return visible ? [NSString stringWithFormat:@"%d hinzugefügt; Bestand %d nativ bestätigt.",delta,after] :
        [NSString stringWithFormat:@"%d hinzugefügt; Bestand %d nativ bestätigt. Rohstoff ausgeblendet; Szenarioanforderungen bleiben unverändert.",delta,after];
}
void FPResourceRelease(FPOwner owner) {
    if (!cache.populated) return;
    if (FPSameOwner(cache.owner, owner) && sameCurrent(owner)) {
        ChangeCapacity change = (ChangeCapacity)FPOriginalSymbol("_ZN16FrostpunkEconomy22ChangeResourceCapacityEPK22FrostpunkResourceEntryi");
        for (int index = 0; index < cache.count; index++)
            if (cache.records[index].leased) releaseSlot(owner, &cache.records[index], change);
    }
    memset(&cache, 0, sizeof(cache));
}
