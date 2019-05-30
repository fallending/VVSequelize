//
//  NSObject+VVOrm.m
//  VVSequelize
//
//  Created by Valo on 2018/9/12.
//

#import "NSObject+VVOrm.h"
#import <objc/runtime.h>

@implementation NSObject (VVOrm)

- (NSString *)sqlWhere
{
    return @"";
}

- (NSString *)sqlJoin
{
    return @"";
}

- (NSString *)quotedStringValue
{
    return [[NSString stringWithFormat:@"%@", self] quote:@"\""];
}

@end

@implementation NSDictionary (VVOrm)
- (NSString *)sqlWhere
{
    NSMutableArray *array = [NSMutableArray arrayWithCapacity:0];
    for (NSString *key in self) {
        [array addObject:key.eq(self[key])];
    }
    return [array componentsJoinedByString:@" AND "];
}

- (NSDictionary *)vv_removeObjectsForKeys:(NSArray *)keys
{
    NSMutableDictionary *dic = [self mutableCopy];
    [dic removeObjectsForKeys:keys];
    return dic;
}

@end

@implementation NSArray (VVOrm)
- (NSString *)sqlWhere
{
    NSMutableArray *array = [NSMutableArray arrayWithCapacity:0];
    for (id val in self) {
        NSString *str = [val sqlWhere];
        if (str.length > 0) {
            [array addObject:str];
        }
    }
    return [array componentsJoinedByString:@" OR "];
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

- (NSString *)sqlJoin:(BOOL)quote
{
    NSString *mark = quote ? @"\"" : @"";
    NSMutableArray *array = [NSMutableArray arrayWithCapacity:0];
    for (id val in self) {
        NSString *tmp = [NSString stringWithFormat:@"%@", val];
        [array addObject:[tmp quote:mark]];
    }
    return [array componentsJoinedByString:@","];
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

// MARK: - where
- (NSString *(^)(id))and
{
    return ^(id value) {
               return [NSString stringWithFormat:@"%@ AND %@", self, [value sqlWhere]];
    };
}

- (NSString *(^)(id))or
{
    return ^(id value) {
               return [NSString stringWithFormat:@"(%@) OR (%@)", self, [value sqlWhere]];
    };
}

- (NSString *(^)(id))eq
{
    return ^(id value) {
        return [NSString stringWithFormat:@"%@ = %@", self, [value quotedStringValue]];
    };
}

- (NSString *(^)(id))ne
{
    return ^(id value) {
        return [NSString stringWithFormat:@"%@ != %@", self, [value quotedStringValue]];
    };
}

- (NSString *(^)(id))gt
{
    return ^(id value) {
        return [NSString stringWithFormat:@"%@ > %@", self, [value quotedStringValue]];
    };
}

- (NSString *(^)(id))gte
{
    return ^(id value) {
        return [NSString stringWithFormat:@"%@ >= %@", self, [value quotedStringValue]];
    };
}

- (NSString *(^)(id))lt
{
    return ^(id value) {
        return [NSString stringWithFormat:@"%@ < %@", self, [value quotedStringValue]];
    };
}

- (NSString *(^)(id))lte
{
    return ^(id value) {
        return [NSString stringWithFormat:@"%@ <= %@", self, [value quotedStringValue]];
    };
}

- (NSString *(^)(id))not
{
    return ^(id value) {
        return [NSString stringWithFormat:@"%@ IS NOT %@", self, [value quotedStringValue]];
    };
}

- (NSString *(^)(id, id))between
{
    return ^(id value1, id value2) {
        return [NSString stringWithFormat:@"%@ BETWEEN %@,%@", self, [value1 quotedStringValue], [value2 quotedStringValue]];
    };
}

- (NSString *(^)(id, id))notBetween
{
    return ^(id value1, id value2) {
        return [NSString stringWithFormat:@"%@ NOT BETWEEN %@,%@", self, [value1 quotedStringValue], [value2 quotedStringValue]];
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
        return [NSString stringWithFormat:@"%@ LIKE %@", self, [value quotedStringValue]];
    };
}

- (NSString *(^)(id))notLike
{
    return ^(id value) {
        return [NSString stringWithFormat:@"%@ NOT LIKE %@", self, [value quotedStringValue]];
    };
}

- (NSString *(^)(id))glob
{
    return ^(id value) {
        return [NSString stringWithFormat:@"%@ GLOB %@", self, [value quotedStringValue]];
    };
}

- (NSString *(^)(id))notGlob
{
    return ^(id value) {
        return [NSString stringWithFormat:@"%@ NOT GLOB %@", self, [value quotedStringValue]];
    };
}

- (NSString *(^)(id))match
{
    return ^(id value) {
        return [NSString stringWithFormat:@"%@ MATCH %@", self, [value quotedStringValue]];
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

- (NSString *)sqlWhere
{
    return self;
}

- (NSString *)sqlJoin
{
    return self;
}

// MARK: - other
- (NSString *)quote:(NSString *)quote
{
    if (quote.length == 0) return self;
    NSString *lquote = [self hasPrefix:quote] ? @"" : quote;
    NSString *rquote = [self hasSuffix:quote] ? @"" : quote;
    return [NSString stringWithFormat:@"%@%@%@", lquote, self, rquote];
}

- (NSString *)quoted
{
    return [self quote:@"\""];
}

- (NSString *)singleQuoted
{
    return [self quote:@"'"];
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
    return [NSString stringWithFormat:@"<span style=%@>", css.quoted];
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
