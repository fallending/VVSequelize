//
//  VVClause.m
//  VVSequelize
//
//  Created by Jinbo Li on 2018/9/15.
//

#import "VVClause.h"
#import "NSString+VVClause.h"
#import "NSArray+VVClause.h"
#import "NSDictionary+VVClause.h"

typedef NS_ENUM(NSUInteger, VVClauseType) {
    VVClauseTypeString,
    VVClauseTypeDictionary,
    VVClauseTypeArray,
    VVClauseTypeUnkown,
};

@interface VVClause ()
@property (nonatomic, strong) id clause;
@end

@implementation VVClause

+ (instancetype)prepare:(id)value{
    VVClause *clause = [[VVClause alloc] init];
    clause.clause = value;
    return clause;
}

- (NSString *)clause1{
    if(!_clause) return @"";
    NSString *sub = nil;
    VVClauseType type = [VVClause clauseTypeOf:_clause];
    switch (type) {
            case VVClauseTypeString:     if([_clause length] > 0) sub = _clause; break;
            case VVClauseTypeDictionary: if([_clause count] > 0)  sub = [_clause where]; break;
            case VVClauseTypeArray:      if([_clause count] > 0)  sub = [_clause where]; break;
        default: break;
    }
    return sub.length > 0 ? sub : @"";
}

- (NSString *)clause2{
    if(!_clause) return @"";
    NSString *sub = nil;
    VVClauseType type = [VVClause clauseTypeOf:_clause];
    switch (type) {
            case VVClauseTypeString:     if([_clause length] > 0) sub = _clause; break;
            case VVClauseTypeArray:      if([_clause count] > 0)  sub = [_clause sqlJoin:YES]; break;
        default: break;
    }
    return sub.length > 0 ? sub : @"";
}

- (NSString *)where{
    NSString *clause = [self clause1];
    return clause.length == 0 ? @"" : [NSString stringWithFormat:@" WHERE %@", clause];
}

- (NSString *)groupBy{
    NSString *clause = [self clause2];
    return clause.length == 0 ? @"" : [NSString stringWithFormat:@" GROUP BY %@", clause];
}

- (NSString *)having{
    NSString *clause = [self clause1];
    return clause.length == 0 ? @"" : [NSString stringWithFormat:@" HAVING %@", clause];
}

- (NSString *)orderBy{
    NSString *clause = [self clause2];
    return clause.length == 0 ? @"" : [NSString stringWithFormat:@" ORDER BY %@", clause];
}

+ (VVClauseType)clauseTypeOf:(id)val{
    if([val isKindOfClass:NSString.class])          return VVClauseTypeString;
    else if([val isKindOfClass:NSDictionary.class]) return VVClauseTypeDictionary;
    else if([val isKindOfClass:NSArray.class])      return VVClauseTypeArray;
    return VVClauseTypeUnkown;
}

@end
