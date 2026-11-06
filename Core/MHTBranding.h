// SPDX-License-Identifier: GPL-3.0-only
#import <Foundation/Foundation.h>

// Old SDK names and preference keys remain stable for existing trainermodules.
NSDictionary *MHTMergedLegacyPreferences(NSDictionary *legacy, NSDictionary *current);
void MHTMigrateLegacyPreferences(void);
