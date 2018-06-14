//
//  VVSqlGenerator.m
//  VVSequelize
//
//  Created by Jinbo Li on 2018/6/13.
//

#import "VVSqlGenerator.h"

@interface NSString (VVCountString)
- (NSInteger)vv_countOccurencesOfString:(NSString*)searchString;
@end

@implementation NSString (VVCountString)
- (NSInteger)vv_countOccurencesOfString:(NSString*)searchString {
    NSInteger strCount = [self length] - [[self stringByReplacingOccurrencesOfString:searchString withString:@""] length];
    return strCount / [searchString length];
}
@end

@implementation VVSqlGenerator

#pragma mark - Where语句

+ (NSString *)where:(NSDictionary *)condition{
    NSString *where = [[self class] key:nil _and:condition];
    return where.length > 0 ? [NSString stringWithFormat:@" WHERE %@", where] : @"";
}

+ (NSString *)key:(NSString *)key _operation:(NSString *)op value:(id)val{
    NSMutableString *string = [NSMutableString stringWithCapacity:0];
    if([op isEqualToString:kVsOpAnd]){
        [string appendString:[[self class] key:key _and:val]];
    }
    else if([op isEqualToString:kVsOpOr]) {
        [string appendString:[[self class] key:nil _or:val]];
    }
    else if([op isEqualToString:kVsOpGt]) {
        [string appendString:[[self class] key:key _gt:val]];
    }
    else if([op isEqualToString:kVsOpGte]) {
        [string appendString:[[self class] key:key _gte:val]];
    }
    else if([op isEqualToString:kVsOpLt]) {
        [string appendString:[[self class] key:key _lt:val]];
    }
    else if([op isEqualToString:kVsOpLte]) {
        [string appendString:[[self class] key:key _lte:val]];
    }
    else if([op isEqualToString:kVsOpNe]) {
        [string appendString:[[self class] key:key _ne:val]];
    }
    else if([op isEqualToString:kVsOpNot]) {
        [string appendString:[[self class] key:key _not:val]];
    }
    else if([op isEqualToString:kVsOpBetween]) {
        [string appendString:[[self class] key:key _between:val]];
    }
    else if([op isEqualToString:kVsOpNotBetween]) {
        [string appendString:[[self class] key:key _notBetween:val]];
    }
    else if([op isEqualToString:kVsOpIn]) {
        [string appendString:[[self class] key:key _in:val]];
    }
    else if([op isEqualToString:kVsOpNotIn]) {
        [string appendString:[[self class] key:key _notIn:val]];
    }
    else if([op isEqualToString:kVsOpLike]) {
        [string appendString:[[self class] key:key _like:val]];
    }
    else if([op isEqualToString:kVsOpNotLike]) {
        [string appendString:[[self class] key:key _notLike:val]];
    }
    else{
        [string appendString:[[self class] key:key _eq:val]];
    }
    return string;
}

+ (NSString *)key:(NSString *)key _and:(NSDictionary *)dic{
    if(![dic isKindOfClass:[NSDictionary class]]) return @"";
    NSMutableString *string = [NSMutableString stringWithCapacity:0];
    [dic enumerateKeysAndObjectsUsingBlock:^(NSString *subkey, id val, BOOL *stop) {
        if(([subkey hasPrefix:@"$"] && key.length > 0) || [subkey isEqualToString:kVsOpOr]) {
            [string appendFormat:@"%@ AND ", [[self class] key:key _operation:subkey value:val]];
        }
        else{
            [string appendFormat:@"%@ AND ", [[self class] key:subkey _eq:val]];
        }
    }];
    if([string hasSuffix:@" AND "]){
        [string deleteCharactersInRange:NSMakeRange(string.length - 5, 5)];
    }
    NSInteger countAnd = [string vv_countOccurencesOfString:@"AND"];
    NSInteger countOr = [string vv_countOccurencesOfString:@"OR"];
    NSInteger countBrackets = [string vv_countOccurencesOfString:@")"];
    if(countAnd + countOr <= countBrackets) return string;
    return [NSString stringWithFormat:@"(%@)", string];
}

+ (NSString *)key:(NSString *)key _or:(NSArray *)array{
    if(![array isKindOfClass:[array class]]) return @"";
    NSMutableString *string = [NSMutableString stringWithCapacity:0];
    [array enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        [string appendFormat:@"%@ OR ",[[self class] key:key _and:obj]];
    }];
    if([string hasSuffix:@" OR "]){
        [string deleteCharactersInRange:NSMakeRange(string.length - 4, 4)];
    }
    NSInteger countAnd = [string vv_countOccurencesOfString:@"AND"];
    NSInteger countOr = [string vv_countOccurencesOfString:@"OR"];
    NSInteger countBrackets = [string vv_countOccurencesOfString:@")"];
    if(countAnd + countOr <= countBrackets) return string;
    return [NSString stringWithFormat:@"(%@)", string];
}

+ (NSString *)key:(NSString *)key _eq:(id)val{
    if([val isKindOfClass:[NSDictionary class]]){
        return [[self class] key:key _and:val];
    }
    return [NSString stringWithFormat:@"\"%@\" = \"%@\"", key, val];
}

+ (NSString *)key:(NSString *)key _gt:(id)val{
    return [NSString stringWithFormat:@"\"%@\" > \"%@\"", key, val];
}

+ (NSString *)key:(NSString *)key _gte:(id)val{
    return [NSString stringWithFormat:@"\"%@\" >= \"%@\"", key, val];
}

+ (NSString *)key:(NSString *)key _lt:(id)val{
    return [NSString stringWithFormat:@"\"%@\" < \"%@\"", key, val];
}

+ (NSString *)key:(NSString *)key _lte:(id)val{
    return [NSString stringWithFormat:@"\"%@\" <= \"%@\"", key, val];
}

+ (NSString *)key:(NSString *)key _ne:(id)val{
    return [NSString stringWithFormat:@"\"%@\" != \"%@\"", key, val];
}

+ (NSString *)key:(NSString *)key _not:(id)val{
    return [NSString stringWithFormat:@"\"%@\" IS NOT \"%@\"", key, val];
}

+ (NSString *)key:(NSString *)key _between:(NSArray *)array{
    if(![array isKindOfClass:[array class]] || array.count != 2) return @"";
    return [NSString stringWithFormat:@"\"%@\" BETWEEN \"%@\" AND \"%@\"", key, array[0], array[1]];
}

+ (NSString *)key:(NSString *)key _notBetween:(NSArray *)array{
    if(![array isKindOfClass:[array class]] || array.count != 2) return @"";
    return [NSString stringWithFormat:@"\"%@\" NOT BETWEEN \"%@\" AND \"%@\"", key, array[0], array[1]];
}

+ (NSString *)key:(NSString *)key _in:(NSArray *)array{
    if(![array isKindOfClass:[array class]]) return @"";
    NSMutableString *inString = [NSMutableString stringWithCapacity:0];
    for (id val in array) {
        [inString appendFormat:@"\"%@\",",val];
    }
    if (inString.length <= 1) return @"";
    [inString deleteCharactersInRange:NSMakeRange(inString.length - 1, 1)];
    return [NSString stringWithFormat:@"\"%@\" IN (%@)", key, inString];
}

+ (NSString *)key:(NSString *)key _notIn:(NSArray *)array{
    if(![array isKindOfClass:[array class]]) return @"";
    NSMutableString *inString = [NSMutableString stringWithCapacity:0];
    for (id val in array) {
        [inString appendFormat:@"\"%@\",",val];
    }
    if (inString.length <= 1) return @"";
    [inString deleteCharactersInRange:NSMakeRange(inString.length - 1, 1)];
    return [NSString stringWithFormat:@"\"%@\" NOT IN (%@)", key, inString];
}

+ (NSString *)key:(NSString *)key _like:(id)val{
    return [NSString stringWithFormat:@"\"%@\" LIKE \"%@\"", key, val];
}

+ (NSString *)key:(NSString *)key _notLike:(id)val{
    return [NSString stringWithFormat:@"\"%@\" NOT LIKE \"%@\"", key, val];
}

#pragma mark - Order语句
+ (NSString *)orderBy:(NSDictionary *)orderBy{
    NSMutableString *orderString = [NSMutableString stringWithCapacity:0];
    [orderBy enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *order, BOOL * _Nonnull stop) {
        if ([order isEqualToString:kVsOrderAsc] || [order isEqualToString:kVsOrderAsc]) {
            [orderString appendFormat:@"%@ %@,", key, order];
        }
    }];
    if(orderString.length > 1){
        [orderString deleteCharactersInRange:NSMakeRange(orderString.length - 1, 1)];
        return [NSString stringWithFormat:@" ORDER BY %@",orderString];
    }
    return @"";
}

#pragma mark - Limit语句
+ (NSString *)limit:(NSRange)range{
    return range.length == 0 ? @"" : [NSString stringWithFormat:@" LIMIT %@,%@",@(range.location),@(range.length)];
}

@end
