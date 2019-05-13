//
//  NSObject+VVOrm.m
//  VVSequelize
//
//  Created by Valo on 2018/9/12.
//

#import "NSObject+VVOrm.h"
#import <objc/runtime.h>

@implementation NSObject (VVOrm)

- (NSString *)vv_condition
{
    return @"";
}

- (NSString *)vv_join
{
    return @"";
}

- (NSString *)vv_match
{
    return @"";
}

- (BOOL)isVVExpr
{
    return [NSString sqlWhere:self].length > 0;
}

- (BOOL)isVVFields
{
    return [self isKindOfClass:NSString.class] || ([self isKindOfClass:NSArray.class] && [(NSArray *)self count] > 0);
}

- (BOOL)isVVOrderBy
{
    return [NSString sqlOrderBy:self].length > 0;
}

- (BOOL)isVVGroupBy
{
    return [NSString sqlGroupBy:self].length > 0;
}

@end

@implementation NSDictionary (VVOrm)
- (NSString *)vv_condition
{
    NSMutableString *where = [NSMutableString stringWithCapacity:0];
    for (NSString *key in self) {
        [where appendFormat:@"%@ AND ", key.eq(self[key])];
    }
    if (where.length >= 5) {
        [where deleteCharactersInRange:NSMakeRange(where.length - 5, 5)];
    }
    return where;
}

- (NSString *)vv_match
{
    NSMutableString *where = [NSMutableString stringWithCapacity:0];
    for (NSString *key in self) {
        [where appendFormat:@"%@ AND ", key.match(self[key])];
    }
    if (where.length >= 5) {
        [where deleteCharactersInRange:NSMakeRange(where.length - 5, 5)];
    }
    return where;
}

- (NSDictionary *)vv_removeObjectsForKeys:(NSArray *)keys
{
    NSMutableDictionary *dic = [self mutableCopy];
    [dic removeObjectsForKeys:keys];
    return dic;
}

@end

@implementation NSArray (VVOrm)
- (NSString *)vv_condition
{
    NSMutableString *where = [NSMutableString stringWithCapacity:0];
    for (id val in self) {
        [where appendFormat:@"(%@) OR ", [val vv_condition]];
    }
    if (where.length >= 4) {
        [where deleteCharactersInRange:NSMakeRange(where.length - 4, 4)];
    }
    return where;
}

- (NSString *)asc
{
    return [[self sqlJoin] stringByAppendingString:@" ASC"];
}

- (NSString *)desc
{
    return [[self sqlJoin] stringByAppendingString:@" DESC"];
}

- (NSString *)sqlJoin
{
    return [self sqlJoin:YES];
}

- (NSString *)sqlJoin:(BOOL)quota
{
    NSMutableString *joined = [NSMutableString stringWithCapacity:0];
    NSString *mark = quota ? @"\"" : @"";
    for (id val in self) {
        [joined appendFormat:@"%@%@%@,", mark, val, mark];
    }
    if (joined.length >= 1) {
        [joined deleteCharactersInRange:NSMakeRange(joined.length - 1, 1)];
    }
    return joined;
}

- (NSString *)vv_join{
    return [self sqlJoin];
}

- (NSArray *)vv_distinctUnionOfObjects
{
    return [self valueForKeyPath:@"@distinctUnionOfObjects.self"];
}

- (NSArray *)vv_removeObjectsInArray:(NSArray *)otherArray
{
    NSMutableArray *array = [self mutableCopy];
    [array removeObjectsInArray:otherArray];
    return array;
}

@end

@implementation NSString (VVOrm)

// MARK: - clause
+ (NSString *)sqlWhere:(id)condition
{
    NSString *clause = [condition vv_condition];
    if (clause.length == 0) return @"";
    return [NSString stringWithFormat:@" WHERE %@", clause];
}

+ (NSString *)sqlMatch:(id)condition
{
    NSString *clause = [condition vv_match];
    if (clause.length == 0) return @"";
    return [NSString stringWithFormat:@" WHERE %@", clause];
}

+ (NSString *)sqlGroupBy:(id)groupBy
{
    NSString *clause = [groupBy vv_join];
    if (clause.length == 0) return @"";
    return [NSString stringWithFormat:@" GROUP BY %@", clause];
}

+ (NSString *)sqlHaving:(id)having
{
    NSString *clause = [having vv_condition];
    if (clause.length == 0) return @"";
    return [NSString stringWithFormat:@" HAVING %@", clause];
}

+ (NSString *)sqlOrderBy:(id)orderBy
{
    NSString *clause = [orderBy vv_join];
    if (clause.length == 0) return @"";
    if (![clause isMatch:@"( +ASC *$)|( +DESC *$)"]) clause = clause.asc;
    return [NSString stringWithFormat:@" ORDER BY %@", clause];
}

// MARK: - where
- (NSString *(^)(id))and
{
    return ^(id value) {
        return [NSString stringWithFormat:@"%@ AND %@", self, value];
    };
}

- (NSString *(^)(id))or
{
    return ^(id value) {
        return [NSString stringWithFormat:@"(%@) OR (%@)", self, value];
    };
}

- (NSString *(^)(id))eq
{
    return ^(id value) {
        return [NSString stringWithFormat:@"%@ = \"%@\"", self, value];
    };
}

- (NSString *(^)(id))ne
{
    return ^(id value) {
        return [NSString stringWithFormat:@"%@ != \"%@\"", self, value];
    };
}

- (NSString *(^)(id))gt
{
    return ^(id value) {
        return [NSString stringWithFormat:@"%@ > \"%@\"", self, value];
    };
}

- (NSString *(^)(id))gte
{
    return ^(id value) {
        return [NSString stringWithFormat:@"%@ >= \"%@\"", self, value];
    };
}

- (NSString *(^)(id))lt
{
    return ^(id value) {
        return [NSString stringWithFormat:@"%@ < \"%@\"", self, value];
    };
}

- (NSString *(^)(id))lte
{
    return ^(id value) {
        return [NSString stringWithFormat:@"%@ <= \"%@\"", self, value];
    };
}

- (NSString *(^)(id))not
{
    return ^(id value) {
        return [NSString stringWithFormat:@"%@ IS NOT \"%@\"", self, value];
    };
}

- (NSString *(^)(id, id))between
{
    return ^(id value1, id value2) {
        return [NSString stringWithFormat:@"%@ BETWEEN \"%@\",\"%@\"", self, value1, value2];
    };
}

- (NSString *(^)(id, id))notBetween
{
    return ^(id value1, id value2) {
        return [NSString stringWithFormat:@"%@ NOT BETWEEN \"%@\",\"%@\"", self, value1, value2];
    };
}

- (NSString *(^)(NSArray *))in
{
    return ^(NSArray *array) {
        return [NSString stringWithFormat:@"%@ IN (%@)", self, [array sqlJoin]];
    };
}

- (NSString *(^)(NSArray *))notIn
{
    return ^(NSArray *array) {
        return [NSString stringWithFormat:@"%@ NOT IN (%@)", self, [array sqlJoin]];
    };
}

- (NSString *(^)(id))like
{
    return ^(id value) {
        return [NSString stringWithFormat:@"%@ LIKE \"%@\"", self, value];
    };
}

- (NSString *(^)(id))notLike
{
    return ^(id value) {
        return [NSString stringWithFormat:@"%@ NOT LIKE \"%@\"", self, value];
    };
}

- (NSString *(^)(id))glob
{
    return ^(id value) {
        return [NSString stringWithFormat:@"%@ GLOB \"%@\"", self, value];
    };
}

- (NSString *(^)(id))notGlob
{
    return ^(id value) {
        return [NSString stringWithFormat:@"%@ NOT GLOB \"%@\"", self, value];
    };
}

- (NSString *(^)(id))match
{
    return ^(id value) {
        return [NSString stringWithFormat:@"%@ MATCH \"%@\"", self, value];
    };
}

- (NSString *)asc
{
    return [self stringByAppendingString:@" ASC"];
}

- (NSString *)desc
{
    return [self stringByAppendingString:@" DESC"];
}

- (NSString *)vv_condition
{
    return self;
}

- (NSString *)vv_match
{
    return self;
}

- (NSString *)vv_join
{
    return self;
}

// MARK: - other
- (NSString *)quota:(NSString *)quota
{
    NSString *lquota = [self hasPrefix:quota] ? @"" : quota;
    NSString *rquota = [self hasSuffix:quota] ? @"" : quota;
    return [NSString stringWithFormat:@"%@%@%@", lquota, self, rquota];
}

- (NSString *)trim
{
    return [self stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (NSString *)strip
{
    return [self stringByReplacingOccurrencesOfString:@" +" withString:@" " options:NSRegularExpressionSearch range:NSMakeRange(0, self.length)];
}

- (BOOL)isMatch:(NSString *)regex
{
    NSStringCompareOptions options = NSRegularExpressionSearch | NSCaseInsensitiveSearch;
    NSRange range = [self rangeOfString:regex options:options];
    return range.location != NSNotFound;
}

- (NSString *)prepareForParseSQL
{
    NSString *tmp = self.trim.strip;
    tmp = [tmp stringByReplacingOccurrencesOfString:@"'|\"" withString:@"" options:NSRegularExpressionSearch range:NSMakeRange(0, tmp.length)];
    return tmp;
}

+ (NSString *)leftSpanForAttributes:(NSDictionary<NSAttributedStringKey, id> *)attributes
{
    NSString *css = [NSString cssForAttributes:attributes];
    return [NSString stringWithFormat:@"<span style=\"%@\">", css];
}

+ (NSString *)cssForAttributes:(NSDictionary<NSAttributedStringKey, id> *)attributes
{
    NSMutableAttributedString *attrText = [[NSMutableAttributedString alloc] initWithString:@"X" attributes:attributes];
    NSDictionary *documentAttributes = @{ NSDocumentTypeDocumentAttribute: NSHTMLTextDocumentType };
    NSData *htmlData = [attrText dataFromRange:NSMakeRange(0, attrText.length) documentAttributes:documentAttributes error:NULL];
    NSString *htmlString = [[NSString alloc] initWithData:htmlData encoding:NSUTF8StringEncoding];
    NSStringCompareOptions options = NSRegularExpressionSearch | NSCaseInsensitiveSearch;
    NSRange range = [htmlString rangeOfString:@"span\\.s1 *\\{.*\\}" options:options];
    if (range.location == NSNotFound) {
        return @"";
    }
    NSString *css = [htmlString substringWithRange:range];
    css = [css stringByReplacingOccurrencesOfString:@"span\\.s1 *\\{" withString:@"" options:options range:NSMakeRange(0, css.length)];
    css = [css stringByReplacingOccurrencesOfString:@"\\}.*" withString:@"" options:options range:NSMakeRange(0, css.length)];
    css = [css stringByReplacingOccurrencesOfString:@"'" withString:@""];
    return css;
}

@end
