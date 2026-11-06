// SPDX-License-Identifier: GPL-3.0-only
#import <Foundation/Foundation.h>
#include <math.h>
static inline NSDictionary *MTControlReadProbeRequest(NSData *data) {
    if (!data.length || data.length > 8192) return nil;
    id root=[NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
    if (![root isKindOfClass:NSDictionary.class]) return nil;
    id serial=root[@"serial"],wanted=root[@"wanted"];
    if (![serial isKindOfClass:NSNumber.class] || !isfinite([serial doubleValue]) || [serial doubleValue]<1
        || floor([serial doubleValue])!=[serial doubleValue] || [serial doubleValue]>9007199254740991.0) return nil;
    if (![wanted isKindOfClass:NSDictionary.class]) return nil;
    for(id key in wanted) if (![key isKindOfClass:NSString.class] || ![wanted[key] isKindOfClass:NSNumber.class]) return nil;
    id values=root[@"values"],actions=root[@"actions"],visible=root[@"visible"];
    if(values){if(![values isKindOfClass:NSDictionary.class]||[values count]>12)return nil;
        for(id key in values)if(![key isKindOfClass:NSString.class]||![values[key]isKindOfClass:NSNumber.class]||!isfinite([values[key]doubleValue]))return nil;}
    if(actions){if(![actions isKindOfClass:NSArray.class]||[actions count]>12)return nil;
        for(id n in actions)if(![n isKindOfClass:NSNumber.class]||!isfinite([n doubleValue])||[n doubleValue]<0||[n doubleValue]>11||floor([n doubleValue])!=[n doubleValue])return nil;}
    if(visible&&(![visible isKindOfClass:NSNumber.class]||([visible doubleValue]!=0&&[visible doubleValue]!=1)))return nil;
    for(NSString *key in @[@"money",@"skill"])if(root[key] && (![root[key]isKindOfClass:NSNumber.class]||!isfinite([root[key]doubleValue])))return nil;
    return root;
}
