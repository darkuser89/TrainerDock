// SPDX-License-Identifier: GPL-3.0-only
#import "RE2Ownership.h"
// RE7 borrows only data reached from live native Guid owners. Never change
// managed reference counts merely to inspect a loading scene or component list.
@interface RE7Owner : RE2Owner
@end
