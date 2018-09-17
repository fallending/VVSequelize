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
NSString * const VVOrmFtsOffsets = @"vvorm_fts_offsets";
NSString * const VVOrmFtsSnippet = @"vvorm_fts_snippet";

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
             range:(NSRange)range{
    NSString *where = [self clauseOf:pattern condition:condition];
    if(self.config.ftsVersion == 5){
        NSString *fields  = [NSString stringWithFormat:@"*,snippet(\"%@\",-1,'<b>','</b>','',2) as %@",self.tableName, VVOrmFtsSnippet];
        return [[[[[[VVSelect prepareWithOrm:self] where:where] fields:fields] orderBy:orderBy] limit:range] allJsons];
    }
    else{
        NSString *fields  = [NSString stringWithFormat:@"*,offsets(\"%@\") as %@",self.tableName, VVOrmFtsOffsets];
        NSArray *array = [[[[[[VVSelect prepareWithOrm:self] where:where] fields:fields] orderBy:orderBy] limit:range] allJsons];
        NSMutableArray *results = [NSMutableArray arrayWithCapacity:array.count];
        for (NSDictionary *dic in array) {
            NSMutableDictionary *result = dic.mutableCopy;
            NSString *offsetsStr = dic[VVOrmFtsOffsets];
            NSDictionary *multi  = [VVOrm cRangesWithOffsetString:offsetsStr];
            NSArray *columns     = self.config.columns;
            for (NSString *idx in multi) {
                NSInteger i      = [idx integerValue];
                NSString *col    = columns[i];
                NSArray  *ranges = multi[idx];
                NSString *text   = dic[col];
                NSString *key    = [col stringByAppendingString:@"_attrText"];
                result[key] = [VVOrm attrTextWith:text cRanges:ranges color:@{NSForegroundColorAttributeName: [UIColor redColor]}];
            }
            [results addObject:result];
        }
        return array;
    }
}

- (NSArray *)match:(NSString *)pattern
         condition:(id)condition
           groupBy:(id)groupBy
             range:(NSRange)range{
    NSString *where   = [self clauseOf:pattern condition:condition];
    NSString *fields  = [NSString stringWithFormat:@"rowid,count(*) as %@", VVOrmFtsCount];
    NSString *orderBy = @"rowid".desc;
    NSArray *array = [[[[[[[VVSelect prepareWithOrm:self] where:where] fields:fields] groupBy:groupBy] orderBy:orderBy] limit:range] allJsons];
    NSMutableArray *rowids = [NSMutableArray arrayWithCapacity:array.count];
    for(NSDictionary *dic in array){
        [rowids addObject:dic[@"rowid"]];
    }
    NSString *newWhere  = [where and:[@"rowid" in:rowids]];
    NSArray *objOffsets = [self match:pattern condition:newWhere orderBy:orderBy range:NSMakeRange(0, rowids.count)];
    NSMutableArray *results = [NSMutableArray arrayWithCapacity:objOffsets.count];
    for (NSUInteger i = 0; i < objOffsets.count; i ++) {
        NSMutableDictionary *one = [objOffsets[i] mutableCopy];
        NSNumber *count = [array[i] objectForKey:VVOrmFtsCount];
        one[VVOrmFtsCount] = count;
    }
    return results;
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
                          range:(NSRange)range{
    NSUInteger count = [self matchCount:pattern condition:condition];
    NSArray *array   = [self match:pattern condition:condition orderBy:orderBy range:range];
    return @{@"count":@(count), @"list":array};
}

- (NSArray *)match:(NSString *)pattern
         condition:(id)condition
          distinct:(BOOL)distinct
            fields:(id)fields
           groupBy:(id)groupBy
            having:(id)having
           orderBy:(id)orderBy
             range:(NSRange)range{
    NSString *where = [self clauseOf:pattern condition:condition];
    VVSelect *select = [[[[[[[[VVSelect prepareWithOrm:self] distinct:distinct] where:where] fields:fields] groupBy:groupBy] having:having] orderBy:orderBy] limit:range];
    return [select allJsons];
}

//MARK: - 处理FTS3,4的offsets()
+ (NSDictionary<NSString *, NSArray *> *)cRangesWithOffsetString:(NSString *)offsetsString{
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

+ (NSAttributedString *)attrTextWith:(NSString *)text
                             cRanges:(NSArray *)offsets
                               color:(NSDictionary<NSAttributedStringKey, id> *)attrs{
    NSMutableAttributedString *attrText = [[NSMutableAttributedString alloc] initWithString:text];
    const char *utf8str = text.UTF8String;
    for (NSArray *offset in offsets) {
        NSInteger loc = [offset[0] integerValue];
        NSInteger len = [offset[1] integerValue];
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
        [attrText addAttributes:attrs range:range];
    }
    return attrText;
}

@end
