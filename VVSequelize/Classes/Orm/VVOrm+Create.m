//
//  VVOrm+Create.m
//  VVSequelize
//
//  Created by Valo on 2018/9/12.
//

#import "VVOrm+Create.h"
#import "NSObject+VVKeyValue.h"

@implementation VVOrm (Create)

- (BOOL)_insertOne:(nonnull id)object upsert:(BOOL)upsert
{
    NSDictionary *dic = [object isKindOfClass:[NSDictionary class]] ? object : [object vv_keyValues];
    NSMutableString *keyString = [NSMutableString stringWithCapacity:0];
    NSMutableString *valString = [NSMutableString stringWithCapacity:0];
    NSMutableArray *values = [NSMutableArray arrayWithCapacity:0];
    [dic enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        if (key && obj && [self.config.columns containsObject:key]) {
            [keyString appendFormat:@"\"%@\",", key];
            [valString appendString:@"?,"];
            [values addObject:[obj vv_dbStoreValue]];
        }
    }];
    if (keyString.length > 1 && valString.length > 1) {
        if (self.config.logAt) {
            NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
            [keyString appendFormat:@"\"%@\",", kVVCreateAt];
            [valString appendString:@"?,"];
            [values addObject:@(now)];
            [keyString appendFormat:@"\"%@\",", kVVUpdateAt];
            [valString appendString:@"?,"];
            [values addObject:@(now)];
        }
        [keyString deleteCharactersInRange:NSMakeRange(keyString.length - 1, 1)];
        [valString deleteCharactersInRange:NSMakeRange(valString.length - 1, 1)];
        NSString *sql = [NSString stringWithFormat:@"%@ INTO \"%@\" (%@) VALUES (%@)",
                         (upsert ? @"INSERT OR REPLACE" : @"INSERT"), self.tableName, keyString, valString];
        return [self.vvdb run:sql bind:values];
    }
    return NO;
}

- (BOOL)insertOne:(nonnull id)object
{
    return [self _insertOne:object upsert:NO];
}

- (NSUInteger)insertMulti:(nullable NSArray *)objects
{
    __block NSUInteger count = 0;
    [self.vvdb transaction:VVDBTransactionImmediate block:^BOOL {
        for (id obj in objects) {
            if ([self _insertOne:obj upsert:NO]) { count++; }
        }
        return count > 0;
    }];
    return count;
}

- (BOOL)upsertOne:(nonnull id)object
{
    return [self _insertOne:object upsert:YES];
}

- (NSUInteger)upsertMulti:(NSArray *)objects
{
    __block NSUInteger count = 0;
    [self.vvdb transaction:VVDBTransactionImmediate block:^BOOL {
        for (id obj in objects) {
            if ([self _insertOne:obj upsert:YES]) { count++; }
        }
        return count > 0;
    }];
    return count;
}

@end
