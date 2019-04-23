//
//  VVOrm+Retrieve.m
//  VVSequelize
//
//  Created by Valo on 2018/9/12.
//

#import "VVOrm+Retrieve.h"
#import "VVSelect.h"

@implementation VVOrm (Retrieve)

- (id)findOne:(nullable VVExpr *)condition
{
    VVSelect *select = [VVSelect makeSelect:^(VVSelect *make) {
        make.orm(self).where(condition).limit(1);
    }];
    return [select allObjects].firstObject;
}

- (id)findOne:(nullable VVExpr *)condition
      orderBy:(nullable VVOrderBy *)orderBy
{
    VVSelect *select = [VVSelect makeSelect:^(VVSelect *make) {
        make.orm(self).where(condition).orderBy(orderBy).limit(1);
    }];
    return [select allObjects].firstObject;
}

- (NSArray *)findAll:(nullable VVExpr *)condition
{
    VVSelect *select = [VVSelect makeSelect:^(VVSelect *make) {
        make.orm(self).where(condition);
    }];
    return [select allObjects];
}

- (NSArray *)findAll:(nullable VVExpr *)condition
             orderBy:(nullable VVOrderBy *)orderBy
               limit:(NSUInteger)limit
              offset:(NSUInteger)offset
{
    VVSelect *select = [VVSelect makeSelect:^(VVSelect *make) {
        make.orm(self).where(condition).orderBy(orderBy).offset(offset).limit(limit);
    }];
    return [select allObjects];
}

- (NSArray *)findAll:(nullable VVExpr *)condition
             groupBy:(nullable VVGroupBy *)groupBy
               limit:(NSUInteger)limit
              offset:(NSUInteger)offset
{
    VVSelect *select = [VVSelect makeSelect:^(VVSelect *make) {
        make.orm(self).where(condition).groupBy(groupBy).offset(offset).limit(limit);
    }];
    return [select allObjects];
}

- (NSArray *)findAll:(nullable VVExpr *)condition
            distinct:(BOOL)distinct
              fields:(nullable VVFields *)fields
             groupBy:(nullable VVGroupBy *)groupBy
              having:(nullable VVExpr *)having
             orderBy:(nullable VVOrderBy *)orderBy
               limit:(NSUInteger)limit
              offset:(NSUInteger)offset
{
    VVSelect *select = [VVSelect makeSelect:^(VVSelect *make) {
        make.orm(self).where(condition).distinct(distinct).fields(fields)
        .groupBy(groupBy).having(having).orderBy(orderBy)
        .offset(offset).limit(limit);
    }];
    return [select allObjects];
}

- (NSInteger)count:(nullable VVExpr *)condition
{
    return [[self calc:@"*" method:@"count" condition:condition] unsignedIntegerValue];
}

- (BOOL)isExist:(id)object
{
    NSDictionary *condition = [self uniqueConditionForObject:object];
    if (condition.count == 0) return NO;
    return [self count:condition] > 0;
}

- (NSDictionary *)findAndCount:(nullable VVExpr *)condition
                       orderBy:(nullable VVOrderBy *)orderBy
                         limit:(NSUInteger)limit
                        offset:(NSUInteger)offset
{
    NSUInteger count = [self count:condition];
    NSArray *array = [self findAll:condition orderBy:orderBy limit:limit offset:offset];
    return @{ @"count": @(count), @"list": array };
}

/**
 SQLite中每个表都默认包含一个隐藏列rowid，使用WITHOUT ROWID定义的表除外。通常情况下，rowid可以唯一的标记表中的每个记录。表中插入的第一个条记录的rowid为1，后续插入的记录的rowid依次递增1。即使插入失败，rowid也会被加一。所以，整个表中的rowid并不一定连续，即使用户没有删除过记录。
 由于唯一性，所以rowid在很多场合中当作主键使用。在使用的时候，select * from tablename 并不能获取rowid，必须显式的指定。例如，select rowid, * from tablename 才可以获取rowid列。查询rowid的效率非常高，所以直接使用rowid作为查询条件是一个优化查询的好方法。
 但是rowid列作为主键，在极端情况下存在隐患。由于rowid值会一直递增，如果达到所允许的最大值9223372036854775807后，它会自动搜索没有被使用的值，重新使用，并不会提示用户。这时，使用rowid排序记录，会产生乱序，并引入其他的逻辑问题。所以，如果用户的数据库存在这种可能的情况，就应该使用AUTOINCREMENT定义主键，从而避免这种问题。使用AUTOINCREMENT设置自增主键，虽然也会遇到9223372036854775807问题，但是它会报错，提示用户，避免产生rowid所引发的问题。
 通常iOS App内嵌数据库单表的数据量不会达到rowid最大值，此处取`max(rowid)`可以做唯一值, `max(rowid) + 1`为下一条将插入的数据的自动主键值.
 */
- (NSUInteger)maxRowid
{
    return [[self max:@"rowid" condition:nil] unsignedIntegerValue];
}

- (id)max:(NSString *)field condition:(nullable VVExpr *)condition
{
    return [self calc:field method:@"max" condition:condition];
}

- (id)min:(NSString *)field condition:(nullable VVExpr *)condition
{
    return [self calc:field method:@"min" condition:condition];
}

- (id)sum:(NSString *)field condition:(nullable VVExpr *)condition
{
    return [self calc:field method:@"sum" condition:condition];
}

- (id)calc:(NSString *)field method:(NSString *)method condition:(nullable VVExpr *)condition
{
    if (!([method isEqualToString:@"max"]
          || [method isEqualToString:@"min"]
          || [method isEqualToString:@"sum"]
          || [method isEqualToString:@"count"])) return nil;
    NSString *fields = [NSString stringWithFormat:@"%@(\"%@\") AS %@", method, field, method];
    VVSelect *select = [VVSelect makeSelect:^(VVSelect *make) {
        make.orm(self).where(condition).fields(fields);
    }];
    NSArray *array = [select allKeyValues];
    NSDictionary *dic = array.firstObject;
    id result = dic[method];
    return [result isKindOfClass:NSNull.class] ? nil : result;
}

@end
