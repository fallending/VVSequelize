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

- (NSString *)join
{
    return @"";
}

- (NSString *)match
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
        [where appendFormat:@"%@ AND ", [key eq:self[key]]];
    }
    if (where.length >= 5) {
        [where deleteCharactersInRange:NSMakeRange(where.length - 5, 5)];
    }
    return where;
}

- (NSString *)match
{
    NSMutableString *where = [NSMutableString stringWithCapacity:0];
    for (NSString *key in self) {
        [where appendFormat:@"%@ AND ", [key match:self[key]]];
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
    if ([clause isMatch:@"^ +WHERE "]) return clause;
    return [NSString stringWithFormat:@" WHERE %@", clause];
}

+ (NSString *)sqlMatch:(id)condition
{
    NSString *clause = [condition match];
    if (clause.length == 0) return @"";
    if ([clause isMatch:@"^ +WHERE "]) return clause;
    return [NSString stringWithFormat:@" WHERE %@", clause];
}

+ (NSString *)sqlGroupBy:(id)groupBy
{
    NSString *clause = [groupBy sqlJoin];
    if (clause.length == 0) return @"";
    if ([clause isMatch:@"^ +GROUP +BY "]) return clause;
    return [NSString stringWithFormat:@" GROUP BY %@", clause];
}

+ (NSString *)sqlHaving:(id)having
{
    NSString *clause = [having vv_condition];
    if (clause.length == 0) return @"";
    if ([clause isMatch:@"^ +HAVING "]) return clause;
    return [NSString stringWithFormat:@" HAVING %@", clause];
}

+ (NSString *)sqlOrderBy:(id)orderBy
{
    NSString *clause = [orderBy sqlJoin];
    if (clause.length == 0) return @"";
    if (![clause isMatch:@"( +ASC *$)|( +DESC *$)"]) clause = clause.asc;
    if ([clause isMatch:@"^ +ORDER +BY "]) return clause;
    return [NSString stringWithFormat:@" ORDER BY %@", clause];
}

// MARK: - where
- (NSString *)and:(NSString *)andstr
{
    return [NSString stringWithFormat:@"%@ AND %@", self, andstr];
}

- (NSString *)or:(NSString *)orstr
{
    return [NSString stringWithFormat:@"(%@) OR (%@)", self, orstr];
}

- (NSString *)eq:(id)eq
{
    return [self stringByAppendingFormat:@" = \"%@\"", eq];
}

- (NSString *)ne:(id)ne
{
    return [self stringByAppendingFormat:@" != \"%@\"", ne];
}

- (NSString *)gt:(id)gt
{
    return [self stringByAppendingFormat:@" > \"%@\"", gt];
}

- (NSString *)gte:(id)gte
{
    return [self stringByAppendingFormat:@" >= \"%@\"", gte];
}

- (NSString *)lt:(id)lt
{
    return [self stringByAppendingFormat:@" < \"%@\"", lt];
}

- (NSString *)lte:(id)lte
{
    return [self stringByAppendingFormat:@" <= \"%@\"", lte];
}

- (NSString *)not:(id)notval
{
    return [self stringByAppendingFormat:@" IS NOT \"%@\"", notval];
}

- (NSString *)between:(id)val1 _:(id)val2
{
    return [self stringByAppendingFormat:@" BETWEEN \"%@\",\"%@\"", val1, val2];
}

- (NSString *)notBetween:(id)val1 _:(id)val2
{
    return [self stringByAppendingFormat:@" NOT BETWEEN \"%@\",\"%@\"", val1, val2];
}

- (NSString *)in:(NSArray *)array
{
    return [self stringByAppendingFormat:@" IN (%@)", [array sqlJoin]];
}

- (NSString *)notIn:(NSArray *)array
{
    return [self stringByAppendingFormat:@" NOT IN (%@)", [array sqlJoin]];
}

- (NSString *)like:(id)like
{
    return [self stringByAppendingFormat:@" LIKE \"%@\"", like];
}

- (NSString *)notLike:(id)notLike
{
    return [self stringByAppendingFormat:@" NOT LIKE \"%@\"", notLike];
}

- (NSString *)glob:(id)glob
{
    return [self stringByAppendingFormat:@" GLOB \"%@\"", glob];
}

- (NSString *)notGlob:(id)notGlob
{
    return [self stringByAppendingFormat:@" NOT GLOB \"%@\"", notGlob];
}

- (NSString *)match:(id)match
{
    return [self stringByAppendingFormat:@" MATCH \"%@\"", match];
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

- (NSString *)match
{
    return self;
}

- (NSString *)join
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