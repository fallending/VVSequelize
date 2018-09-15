//
//  NSArray+VVClause.m
//  VVSequelize
//
//  Created by Jinbo Li on 2018/9/15.
//

#import "NSArray+VVClause.h"
#import "NSDictionary+VVClause.h"

@implementation NSArray (VVClause)
- (NSString *)where{
    NSMutableString *where = [NSMutableString stringWithCapacity:0];
    for (id val in self) {
        if([val isKindOfClass:NSString.class]){
            [where appendFormat:@"(%@) OR ",val];
        }
        else if([val isKindOfClass:NSDictionary.class]){
            [where appendFormat:@"(%@) OR ",[(NSDictionary *)val where]];
        }
    }
    if(where.length >= 4){
        [where deleteCharactersInRange:NSMakeRange(where.length - 4, 4)];
    }
    return where;
}

- (NSString *)asc{
    return [[self sqlJoin:YES] stringByAppendingFormat:@" ASC"];
}

- (NSString *)desc{
    return [[self sqlJoin:YES] stringByAppendingFormat:@" DESC"];
}

- (NSString *)sqlJoin:(BOOL)quota{
    NSMutableString *joined = [NSMutableString stringWithCapacity:0];
    NSString *single = quota ? @"\"": @"";
    for (id val in self) {
        [joined appendFormat:@"%@%@%@,",single,val,single];
    }
    if (joined.length >= 1){
        [joined deleteCharactersInRange:NSMakeRange(joined.length - 1, 1)];
    }
    return joined;
}

@end
