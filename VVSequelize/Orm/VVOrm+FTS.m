//
//  VVOrm+FTS.m
//  VVSequelize
//
//  Created by Jinbo Li on 2018/9/15.
//

#import "VVOrm+FTS.h"
#import "VVSelect.h"
#import "VVClause.h"
#import "VVOrm+Retrieve.h"
#import "NSString+VVClause.h"
#import "NSArray+VVClause.h"
#import "NSDictionary+VVClause.h"
#import "NSString+VVOrm.h"

NSString * const VVOrmFtsCount   = @"vvorm_fts_count";

@implementation VVOrm (FTS)

//MARK: - Private
- (NSString *)clauseOf:(NSString *)pattern
             condition:(id)condition{
    NSAssert(self.config.fts, @"仅支持FTS数据表");
    NSString *where = [[VVClause prepare:condition] condition];
    NSString *match = [self.tableName match:pattern];
    where = where.length > 0 ? [where and:match] : match;
    return where;
}

//MARK: - Public
- (NSArray *)match:(NSString *)pattern
         condition:(id)condition
           orderBy:(id)orderBy
             range:(NSRange)range
{
    NSString *where = [self clauseOf:pattern condition:condition];
    return [[[[[VVSelect prepareWithOrm:self] where:where] orderBy:orderBy] limit:range] allObjects];
}

- (NSArray *)match:(NSString *)pattern
         condition:(id)condition
           groupBy:(id)groupBy
             range:(NSRange)range
{
    NSString *where   = [self clauseOf:pattern condition:condition];
    NSString *fields  = [NSString stringWithFormat:@"*,count(*) as %@", VVOrmFtsCount];
    NSString *orderBy = @"rowid".desc;
    return [[[[[[[VVSelect prepareWithOrm:self] where:where] fields:fields] groupBy:groupBy] orderBy:orderBy] limit:range] allJsons];
}

- (NSUInteger)matchCount:(NSString *)pattern
               condition:(id)condition{
    NSString *where = [self clauseOf:pattern condition:condition];
    NSString *fields = @"count(*) as count";
    NSArray *array = [[[[VVSelect prepareWithOrm:self] where:where] fields:fields] allJsons];
    NSDictionary *dic = array.firstObject;
    return [dic[@"count"] integerValue];
}

- (NSDictionary *)matchAndCount:(NSString *)pattern
                      condition:(id)condition
                        orderBy:(id)orderBy
                          range:(NSRange)range
{
    NSUInteger count = [self matchCount:pattern condition:condition];
    NSArray *array   = [self match:pattern condition:condition orderBy:orderBy range:range];
    return @{@"count":@(count), @"list":array};
}

//MARK: - 对FTS搜索结果进行处理

//MARK: 使用C语言方式处理FTS3,4的offsets()
+ (NSDictionary<NSString *, NSArray *> *)cRangesWithOffsetsString:(NSString *)offsetsString{
    NSArray *temp = [offsetsString componentsSeparatedByString:@" "];
    NSMutableDictionary *ranges = [NSMutableDictionary dictionaryWithCapacity:0];
    if(temp.count % 4 != 0) return nil;
    for (NSUInteger j = 0; j < temp.count / 4; j ++) {
        NSString *fieldIdx = temp[j * 4];
        // NSString *keywordIdx = temp[j * 4 + 1]; // 此处不使用
        NSString *loc = temp[j * 4 + 2];
        NSString *len = temp[j * 4 + 3];
        NSMutableArray *array = ranges[fieldIdx];
        if(!array) {
            array = [NSMutableArray arrayWithCapacity:0];
            ranges[fieldIdx] = array;
        }
        [array addObject:@[loc,len]];
    }
    return ranges;
}

+ (NSAttributedString *)attributedStringWith:(NSString *)string
                                     cRanges:(NSArray *)cRanges
                                  attributes:(NSDictionary<NSAttributedStringKey, id> *)attrs{
    NSMutableAttributedString *attrString = [[NSMutableAttributedString alloc] initWithString:string];
    const char *utf8str = string.UTF8String;
    for (NSArray *cRange in cRanges) {
        NSInteger loc = [cRange[0] integerValue];
        NSInteger len = [cRange[1] integerValue];
        char *lstr = (char *)malloc(loc + 1);
        strncpy(lstr, utf8str, loc);
        lstr[loc] = '\0';
        const char *rstr = utf8str + loc;
        char *matchstr = (char *)malloc(len + 1);
        strncpy(matchstr, rstr, len);
        matchstr[len] = '\0';
        NSString *ltext = [NSString stringWithUTF8String:lstr];
        NSString *word = [NSString stringWithUTF8String:matchstr];
        NSRange range = NSMakeRange(ltext.length, word.length);
        [attrString addAttributes:attrs range:range];
    }
    return attrString;
}

//MARK: 使用Objective-C处理
+ (NSString *)regularExpressionForKeyword:(NSString *)keyword{
    NSString *temp = [keyword stringByReplacingOccurrencesOfString:@"*" withString:@".*"];
    return [temp stringByReplacingOccurrencesOfString:@"?" withString:@"."];
}

+ (NSAttributedString *)attributedStringWith:(NSString *)string
                                      prefix:(NSString *)prefix
                                       match:(NSString *)regex
                                  attributes:(NSDictionary<NSAttributedStringKey, id> *)attrs{
    if(string.length == 0) return nil;
    
    NSRange range = [string rangeOfString:regex options:NSRegularExpressionSearch | NSCaseInsensitiveSearch];
    if(range.location == NSNotFound || range.length == 0) return nil;
    
    NSMutableAttributedString *attrString = [[NSMutableAttributedString alloc] initWithString:string];
    [attrString addAttributes:attrs range:range];
    
    if(prefix.length > 0){
        NSAttributedString *attrPrefix = [[NSAttributedString alloc] initWithString:prefix];
        [attrString insertAttributedString:attrPrefix atIndex:0];
    }
    return attrString;
}

@end
