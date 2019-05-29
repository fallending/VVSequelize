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
    return [self.vvdb transaction:VVDBTransactionImmediate block:^BOOL {
        return [self.vvdb excute:sql];
    }];
}

- (BOOL)deleteOne:(nonnull id)object
{
    NSDictionary *condition = [self uniqueConditionForObject:object];
    if (condition.count == 0) return NO;
    NSString *where = [NSString sqlWhere:condition];
    NSString *sql = [NSString stringWithFormat:@"DELETE FROM %@ %@", self.tableName.quoted, where];
    return [self.vvdb excute:sql];
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
    NSString *where = [NSString sqlWhere:condition];
    NSString *sql = [NSString stringWithFormat:@"DELETE FROM %@ %@", self.tableName.quoted, where];
    return [self.vvdb transaction:VVDBTransactionImmediate block:^BOOL {
        return [self.vvdb excute:sql];
    }];
}

@end
