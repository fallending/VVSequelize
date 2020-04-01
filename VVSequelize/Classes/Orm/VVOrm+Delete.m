//
//  VVOrm+Delete.m
//  VVSequelize
//
//  Created by Valo on 2018/9/12.
//

#import "VVOrm+Delete.h"
#import "NSObject+VVOrm.h"

@implementation VVOrm (Delete)
- (BOOL)drop
{
    NSString *sql = [NSString stringWithFormat:@"DROP TABLE IF EXISTS %@", self.tableName.quoted];
    return [self.vvdb run:sql];
}

- (BOOL)deleteOne:(nonnull id)object
{
    NSDictionary *condition = [self uniqueConditionForObject:object];
    if (condition.count == 0) return NO;
    return [self deleteWhere:condition];
}

- (NSUInteger)deleteMulti:(nullable NSArray *)objects
{
    __block NSUInteger count = 0;
    [self.vvdb transaction:VVDBTransactionImmediate block:^BOOL {
        for (id object in objects) {
            BOOL ret = [self deleteOne:object];
            if (ret) count++;
        }
        return count > 0;
    }];
    return count;
}

- (BOOL)deleteWhere:(nullable VVExpr *)condition
{
    NSString *where = [condition sqlWhere];
    where = where.length == 0 ? @"" : [NSString stringWithFormat:@" WHERE %@", where];

    NSString *sql = [NSString stringWithFormat:@"DELETE FROM %@ %@", self.tableName.quoted, where];
    return [self.vvdb run:sql];
}

@end
