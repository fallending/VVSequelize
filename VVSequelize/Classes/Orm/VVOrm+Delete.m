//
//  VVOrm+Delete.m
//  VVSequelize
//
//  Created by Valo on 2018/9/12.
//

#import "VVOrm+Delete.h"
#import "NSObject+VVOrm.h"
#import "VVOrmView.h"

@implementation VVOrm (Delete)
- (BOOL)drop
{
    VVORMVIEW_CUD_CHECK(self);
    NSString *sql = [NSString stringWithFormat:@"DROP TABLE IF EXISTS %@", self.name.quoted];
    return [self.vvdb run:sql];
}

- (BOOL)deleteOne:(nonnull id)object
{
    VVORMVIEW_CUD_CHECK(self);
    NSDictionary *condition = [self uniqueConditionForObject:object];
    if (condition.count == 0) return NO;
    return [self deleteWhere:condition];
}

- (NSUInteger)deleteMulti:(nullable NSArray *)objects
{
    VVORMVIEW_CUD_CHECK(self);
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
    VVORMVIEW_CUD_CHECK(self);
    NSString *where = [condition sqlWhere];
    where = where.length == 0 ? @"" : [NSString stringWithFormat:@" WHERE %@", where];

    NSString *sql = [NSString stringWithFormat:@"DELETE FROM %@ %@", self.name.quoted, where];
    return [self.vvdb run:sql];
}

@end
