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
    NSString *match = [NSString sqlMatch:condition];
    VVSelect *select = [VVSelect makeSelect:^(VVSelect *make) {
        make.orm(self).where(match).orderBy(orderBy).offset(offset).limit(limit);
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
    NSString *match = [NSString sqlMatch:condition];
    VVSelect *select = [VVSelect makeSelect:^(VVSelect *make) {
        make.orm(self).where(match).orderBy(orderBy).offset(offset).limit(limit);
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
    NSString *fields = [columns sqlJoin:NO];
    select.fields(fields);
    
    return [select allObjects];
}

- (NSArray *)match:(nullable VVExpr *)condition
           groupBy:(nullable VVGroupBy *)groupBy
             limit:(NSUInteger)limit
            offset:(NSUInteger)offset
{
    NSString *match = [NSString sqlMatch:condition];
    NSString *fields = [NSString stringWithFormat:@"*,count(*) as %@", VVOrmFtsCount];
    NSString *orderBy = @"rowid".desc;
    VVSelect *select = [VVSelect makeSelect:^(VVSelect *make) {
        make.orm(self).where(match).fields(fields).groupBy(groupBy).orderBy(orderBy).offset(offset).limit(limit);
    }];
    return [select allKeyValues];
}

- (NSUInteger)matchCount:(nullable VVExpr *)condition
{
    NSString *match = [NSString sqlMatch:condition];
    NSString *fields = @"count(*) as count";
    VVSelect *select = [VVSelect makeSelect:^(VVSelect *make) {
        make.orm(self).where(match).fields(fields);
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
    Class<VVFtsTokenizer> cls = nil;
    if (self.config.ftsVersion >= 5) {
        cls = [self.vvdb ftsFiveTokenizerClassForName:self.config.ftsTokenizer];
    } else {
        cls = [self.vvdb ftsThreeFourTokenizerClassForName:self.config.ftsTokenizer];
    }
    if (!cls) return nil;
    
    const char *pKw = keyword.UTF8String;
    int nKw = (int)strlen(pKw);
    
    NSMutableArray *results = [NSMutableArray arrayWithCapacity:objects.count];
    for (NSObject *obj in objects) {
        NSString *sourceString = [obj valueForKey:field];
        if (!sourceString || ![sourceString isKindOfClass:NSString.class]) continue;
        
        const char *pText = sourceString.UTF8String;
        int nText = (int)strlen(pText);
        BOOL tokenPinyin = nText <= TOKEN_PINYIN_MAX_LENGTH;
        
        __block char *tokenized = (char *)malloc(nText + 1);
        memset(tokenized, 0x0, nText + 1);
        
        __block NSMutableArray *kwTokens = [NSMutableArray arrayWithCapacity:0];
        [cls enumerateTokens:pKw len:nKw locale:nil pinyin:NO usingBlock:^(const char *token, int len, int start, int end, BOOL *stop) {
            char *_token = (char *)malloc(len + 1);
            memcpy(_token, token, len);
            _token[len] = 0;
            VVFts3Token *kwToken = [VVFts3Token new];
            kwToken.token = _token;
            kwToken.len   = len;
            kwToken.start = start;
            kwToken.end   = end;
            [kwTokens addObject:kwToken];
        }];
        
        [cls enumerateTokens:pText len:nText locale:nil pinyin:tokenPinyin usingBlock:^(const char *token, int len, int start, int end, BOOL *stop) {
            for (VVFts3Token *kwToken in kwTokens) {
                if (strncmp(token, kwToken.token, kwToken.len) != 0) continue;
                memcpy(tokenized + start, pText + start, end - start);
            }
        }];
        
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
        [results addObject:attrText];
    }
    return results;
}

@end
