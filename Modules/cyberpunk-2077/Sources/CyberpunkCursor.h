// SPDX-License-Identifier: GPL-3.0-only
#import <AppKit/AppKit.h>
// AppKit/main-thread platform input, independent of the gameplay callback.
BOOL CPUpdateOverlayCursor(NSView *gameView,BOOL wanted);
BOOL CPOverlayCursorActive(void);
