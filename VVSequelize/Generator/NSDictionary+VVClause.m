//
//  NSDictionary+VVClause.m
//  VVSequelize
//
//  Created by Jinbo Li on 2018/9/15.
//

#import "NSDictionary+VVClause.h"
#import "NSString+VVClause.h"

@implementation NSDictionary (VVClause)
- (NSString *)where{
    NSMutableString *where = [NSMutableString stringWithCapacity:0];
    for (NSString *key in self) {
        [where appendFormat:@"%@ AND ",[key eq:self[key]]];
    }
    if(where.length >= 5){
        [where deleteCharactersInRange:NSMakeRange(where.length - 5, 5)];
    }
    return where;
}

@end
