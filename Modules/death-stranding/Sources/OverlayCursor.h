// SPDX-License-Identifier: GPL-3.0-only
#import <AppKit/AppKit.h>
@class MHTOverlayHost;
// The engine can hide its system cursor while the overlay is open. Display the
// vector arrow in our own panel, without touching global hide counters. Standard
// system cursors can expose an empty NSImage on current macOS versions.
@interface MHTDSCursorView : NSView
@property(nonatomic,readonly) NSPoint pointerHotspot;
@property(nonatomic,readonly) NSSize pointerSize;
- (void)updateAtScreenPoint:(NSPoint)point enabled:(BOOL)enabled;
@end
void MHTDSUpdateCursor(MHTOverlayHost *host,BOOL enabled);
