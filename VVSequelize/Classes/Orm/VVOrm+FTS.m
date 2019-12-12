//
//  VVOrm+FTS.m
//  VVDB
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

/// full text search
/// @bug fts3: snippet() does not match correctly, repeat many times
/// @bug fts5: Inaccurate highlight
/// @note use `VVFtsHighlighter` to highlight
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
