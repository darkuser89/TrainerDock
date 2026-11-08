// SPDX-License-Identifier: GPL-3.0-only
#import <AppKit/AppKit.h>
@class MHTOverlayHost;
// inZOI can hide its system cursor independently of its capture flag. Display the
// vector arrow in our own panel, without touching global hide counters. Standard
// system cursors can expose an empty NSImage on current macOS versions.
@interface MHTStrayCursorView : NSView
@property(nonatomic,readonly) NSPoint pointerHotspot;
@property(nonatomic,readonly) NSSize pointerSize;
- (void)updateAtScreenPoint:(NSPoint)point enabled:(BOOL)enabled;
@end
void MHTStrayUpdateCursor(MHTOverlayHost *host,BOOL enabled);
