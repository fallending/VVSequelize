//
//  VVOrm+Update.m
//  VVSequelize
//
//  Created by Valo on 2018/9/12.
//

#import "VVOrm+Update.h"
#import "NSObject+VVKeyValue.h"
#import "NSObject+VVOrm.h"

@implementation VVOrm (Update)

- (BOOL)_update:(nullable VVExpr *)condition keyValues:(NSDictionary<NSString *, id> *)keyValues
{
    NSString *where = [NSString sqlWhere:condition];
    NSMutableString *setString = [NSMutableString stringWithCapacity:0];
    NSMutableArray *objs = [NSMutableArray arrayWithCapacity:0];
    [keyValues enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        if (key && obj && [self.config.columns containsObject:key]) {
            [setString appendFormat:@"\"%@\" = ?,", key];
            [objs addObject:[obj vv_dbStoreValue]];
        }
    }];
    if (setString.length > 1) {
        if (self.config.logAt) {
            NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
            [setString appendFormat:@"\"%@\" = ?,", kVVUpdateAt];
            [objs addObject:@(now)];
        }
        [setString deleteCharactersInRange:NSMakeRange(setString.length - 1, 1)];
        NSString *sql = [NSString stringWithFormat:@"UPDATE \"%@\" SET %@ %@", self.tableName, setString, where];
        return [self.vvdb run:sql bind:objs];
    }
    return NO;
}

- (BOOL)_updateOne:(id)object fields:(nullable NSArray<NSString *> *)fields
{
    NSDictionary *condition = [self uniqueConditionForObject:object];
    if (condition.count == 0) return NO;
    NSDictionary *dic = [object isKindOfClass:[NSDictionary class]] ? object : [object vv_keyValues];
    NSMutableDictionary *keyValues = nil;
    if (fields.count == 0) {
        keyValues = dic.mutableCopy;
    } else {
        keyValues = [NSMutableDictionary dictionaryWithCapacity:fields.count];
        for (NSString *field in fields) {
            keyValues[field] = dic[field];
        }
    }
    if (keyValues.count == 0) return NO;
    return [self _update:condition keyValues:keyValues];
}

- (BOOL)update:(nullable VVExpr *)condition keyValues:(NSDictionary<NSString *, id> *)keyValues
{
    return [self.vvdb transaction:VVDBTransactionImmediate block:^BOOL {
        return [self _update:condition keyValues:keyValues];
    }];
}

- (BOOL)updateOne:(id)object
{
    return [self _updateOne:object fields:nil];
}

- (BOOL)updateOne:(id)object fields:(nullable NSArray<NSString *> *)fields
{
    return [self _updateOne:object fields:fields];
}

- (NSUInteger)updateMulti:(NSArray *)objects
{
    return [self updateMulti:objects fields:nil];
}

- (NSUInteger)updateMulti:(NSArray *)objects fields:(nullable NSArray<NSString *> *)fields
{
    __block NSUInteger count = 0;
    [self.vvdb transaction:VVDBTransactionImmediate block:^BOOL {
        for (id object in objects) {
            if ([self _updateOne:object fields:fields]) { count++; }
        }
        return count > 0;
    }];
    return count;
}

- (BOOL)increase:(nullable VVExpr *)condition
           field:(NSString *)field
           value:(NSInteger)value
{
    if (value == 0) {
        return YES;
    }
    NSMutableString *setString = [NSMutableString stringWithFormat:@"\"%@\" = \"%@\"%@",
                                  field, field, @(value)];
    if (self.config.logAt) {
        NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
        [setString appendFormat:@",\"%@\" = \"%@\"", kVVUpdateAt, @(now)];
    }
    NSString *where = [NSString sqlWhere:condition];
    NSString *sql = [NSString stringWithFormat:@"UPDATE \"%@\" SET %@ %@", self.tableName, setString, where];
    return [self.vvdb transaction:VVDBTransactionImmediate block:^BOOL {
        return [self.vvdb excute:sql];
    }];
}

@end
