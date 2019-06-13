//
//  VVOrm+FTS.m
//  VVSequelize
//
//  Created by Valo on 2018/9/15.
//

#import "VVOrm+FTS.h"
#import "VVSelect.h"
#import "NSObject+VVOrm.h"
#import "VVDatabase+FTS.h"
#import "VVFtsTokenizer.h"
#import "VVDBStatement.h"

NSString *const VVOrmFtsCount = @"vvdb_fts_count";

@implementation VVOrm (FTS)

//MARK: - Public
- (NSArray *)match:(nullable VVExpr *)condition
           orderBy:(nullable VVOrderBy *)orderBy
             limit:(NSUInteger)limit
            offset:(NSUInteger)offset
{
    VVSelect *select = [VVSelect makeSelect:^(VVSelect *make) {
        make.orm(self).where(condition).orderBy(orderBy).offset(offset).limit(limit);
    }];
    return [select allObjects];
}

/**
 全文搜索

 @param condition match匹配表达式,比如:"name:zhan*","zhan*",具体的表达请查看sqlite官方文档
 @param field 需要进行高亮处理的字段
 @param attributes 高亮使用的属性
 @param orderBy 排序方式
 @param limit 数据条数,为0时不做限制
 @param offset 数据起始位置
 @return 匹配结果,对象数组,格式:[object]
 @bug fts3: snippet函数获取的文本不正确,重复多次.
 @bug fts5: 添加文本属性的位置错误.
 @note 请使用`highlight:field:keyword:attributes:`进行高亮处理
 */
- (NSArray *)match:(nullable VVExpr *)condition
         highlight:(NSString *)field
        attributes:(NSDictionary<NSAttributedStringKey, id> *)attributes
           orderBy:(nullable VVOrderBy *)orderBy
             limit:(NSUInteger)limit
            offset:(NSUInteger)offset
{
    VVSelect *select = [VVSelect makeSelect:^(VVSelect *make) {
        make.orm(self).where(condition).orderBy(orderBy).offset(offset).limit(limit);
    }];
    VVDBStatement *statement = [VVDBStatement statementWithDatabase:self.vvdb sql:select.sql];
    NSMutableArray *columns = [[statement columnNames] mutableCopy];
    NSUInteger idx = [columns indexOfObject:field];
    NSAssert(idx < columns.count, @"Invalid field!");

    NSString *lspan = [NSString leftSpanForAttributes:attributes];
    NSString *rspan = @"</span>";
    NSString *highlight = nil;
    if (self.config.ftsVersion >= 5) {
        highlight = [NSString stringWithFormat:@"highlight(%@,%@,'%@','%@') AS %@", self.tableName, @(idx), lspan, rspan, field];
    } else {
        highlight = [NSString stringWithFormat:@"snippet(%@,'%@','%@','...',%@) AS %@", self.tableName, lspan, rspan, @(idx), field];
    }
    [columns replaceObjectAtIndex:idx withObject:highlight];
    NSString *fields = [columns componentsJoinedByString:@","];
    select.fields(fields);

    return [select allObjects];
}

- (NSArray *)match:(nullable VVExpr *)condition
           groupBy:(nullable VVGroupBy *)groupBy
             limit:(NSUInteger)limit
            offset:(NSUInteger)offset
{
    NSString *fields = [NSString stringWithFormat:@"*,count(*) as %@", VVOrmFtsCount];
    NSString *orderBy = @"rowid".desc;
    VVSelect *select = [VVSelect makeSelect:^(VVSelect *make) {
        make.orm(self).where(condition).fields(fields).groupBy(groupBy).orderBy(orderBy).offset(offset).limit(limit);
    }];
    return [select allKeyValues];
}

- (NSUInteger)matchCount:(nullable VVExpr *)condition
{
    NSString *fields = @"count(*) as count";
    VVSelect *select = [VVSelect makeSelect:^(VVSelect *make) {
        make.orm(self).where(condition).fields(fields);
    }];
    NSDictionary *dic = [select allKeyValues].firstObject;
    return [dic[@"count"] integerValue];
}

- (NSDictionary *)matchAndCount:(nullable VVExpr *)condition
                        orderBy:(nullable VVOrderBy *)orderBy
                          limit:(NSUInteger)limit
                         offset:(NSUInteger)offset
{
    NSUInteger count = [self matchCount:condition];
    NSArray *array = [self match:condition orderBy:orderBy limit:limit offset:offset];
    return @{ @"count": @(count), @"list": array };
}

//MARK: - 对FTS搜索结果进行高亮
- (NSArray<NSAttributedString *> *)highlight:(NSArray *)objects
                                       field:(NSString *)field
                                     keyword:(NSString *)keyword
                                  attributes:(NSDictionary<NSAttributedStringKey, id> *)attributes
{
    return [self highlight:objects field:field keyword:keyword pinyinMaxLen:-1 attributes:attributes];
}

- (NSArray<NSAttributedString *> *)highlight:(NSArray *)objects
                                       field:(NSString *)field
                                     keyword:(NSString *)keyword
                                pinyinMaxLen:(int)pinyinMaxLen
                                  attributes:(NSDictionary<NSAttributedStringKey, id> *)attributes
{
    NSAssert(self.config.fts && self.config.ftsTokenizer.length > 0, @"Invalid fts orm!");
    NSString *tokenizer = [self.config.ftsTokenizer componentsSeparatedByString:@" "].firstObject;
    VVFtsXEnumerator enumerator = [self.vvdb enumeratorForFtsTokenizer:tokenizer];
    NSArray *keywordTokens = !enumerator ? @[keyword] : [self tokenize:keyword pinyin:NO enumerator:enumerator];
    int pymlen = pinyinMaxLen >= 0 ? : TOKEN_PINYIN_MAX_LENGTH;

    NSMutableArray *results = [NSMutableArray arrayWithCapacity:objects.count];
    for (NSObject *obj in objects) {
        NSString *source = [obj valueForKey:field];
        NSAttributedString *attrText = [self highlight:source pyMaxLen:pymlen enumerator:enumerator keywordTokens:keywordTokens attributes:attributes];
        [results addObject:attrText];
    }
    return results;
}

- (NSArray<VVFtsToken *> *)tokenize:(NSString *)source
                             pinyin:(BOOL)pinyin
                         enumerator:(VVFtsXEnumerator)enumerator
{
    const char *pText = source.UTF8String;
    
    if (!pText) {
        return @[];
    }
    
    int nText = (int)strlen(pText);
    if (!enumerator) {
        VVFtsToken *vvToken = [VVFtsToken new];
        vvToken.token = pText;
        vvToken.len = nText;
        vvToken.start = 0;
        vvToken.end = nText;
        return @[vvToken];
    }

    __block NSMutableArray<VVFtsToken *> *results = [NSMutableArray arrayWithCapacity:0];

    VVFtsXTokenHandler handler = ^(const char *token, int len, int start, int end, BOOL *stop) {
        char *_token = (char *)malloc(len + 1);
        memcpy(_token, token, len);
        _token[len] = 0;
        VVFtsToken *vvToken = [VVFtsToken new];
        vvToken.token = _token;
        vvToken.len = len;
        vvToken.start = start;
        vvToken.end = end;
        [results addObject:vvToken];
    };
    !enumerator ? : enumerator(pText, nText, nil, pinyin, handler);
    return results;
}

- (NSAttributedString *)highlight:(NSString *)source
                         pyMaxLen:(int)pyMaxLen
                       enumerator:(VVFtsXEnumerator)enumerator
                    keywordTokens:(NSArray<VVFtsToken *> *)keywordTokens
                       attributes:(NSDictionary<NSAttributedStringKey, id> *)attributes
{
    const char *pText = source.UTF8String;

    if (!pText) {
        return [[NSAttributedString alloc] init];
    }
    
    if (!enumerator) {
        return [[NSAttributedString alloc] initWithString:source];
    }
    
    int nText = (int)strlen(pText);
    __block char *tokenized = (char *)malloc(nText + 1);
    memset(tokenized, 0x0, nText + 1);

    VVFtsXTokenHandler handler = ^(const char *token, int len, int start, int end, BOOL *stop) {
        for (VVFtsToken *kwToken in keywordTokens) {
            if (strncmp(token, kwToken.token, kwToken.len) != 0) continue;
            memcpy(tokenized + start, pText + start, end - start);
        }
    };

    enumerator(pText, nText, nil, nText < pyMaxLen, handler);

    char *remained = (char *)malloc(nText + 1);
    strncpy(remained, pText, nText);
    remained[nText] = 0x0;
    for (int i = 0; i < nText + 1; i++) {
        if (tokenized[i] != 0) {
            memset(remained + i, 0x0, 1);
        }
    }
    NSMutableAttributedString *attrText = [[NSMutableAttributedString alloc] init];
    int pos = 0;
    while (pos < nText) {
        if (remained[pos] != 0x0) {
            NSString *str = [NSString stringWithUTF8String:(remained + pos)];
            [attrText appendAttributedString:[[NSAttributedString alloc] initWithString:str]];
            pos += strlen(remained + pos);
        } else {
            NSString *str = [NSString stringWithUTF8String:(tokenized + pos)];
            [attrText appendAttributedString:[[NSAttributedString alloc] initWithString:str attributes:attributes]];
            pos += strlen(tokenized + pos);
        }
    }
    free(remained);

    return attrText;
}

@end
