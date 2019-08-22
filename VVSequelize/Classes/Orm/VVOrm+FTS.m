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

@end
