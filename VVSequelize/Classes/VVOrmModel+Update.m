//
//  VVOrmModel+Update.m
//  VVSequelize
//
//  Created by Jinbo Li on 2018/9/12.
//

#import "VVOrmModel+Update.h"
#import "VVOrmModel+Create.h"
#import "VVOrmModel+Retrieve.h"
#import "NSObject+VVKeyValue.h"
#import "VVSqlGenerator.h"

@implementation VVOrmModel (Update)

- (BOOL)update:(id)condition
        values:(NSDictionary *)values{
    BOOL ret = [self updateWithoutNotification:condition values:values];
    [self handleResult:ret action:VVOrmActionUpdate];
    return ret;
}

- (BOOL)updateWithoutNotification:(id)condition
                           values:(NSDictionary *)values{
    NSString *where = [VVSqlGenerator where:condition];
    NSMutableString *setString = [NSMutableString stringWithCapacity:0];
    NSMutableArray *objs = [NSMutableArray arrayWithCapacity:0];
    [values enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        if(key && obj && [self.config.fieldNames containsObject:key]){
            [setString appendFormat:@"\"%@\" = ?,",key];
            [objs addObject:[obj vv_dbStoreValue]];
        }
    }];
    if (setString.length > 1) {
        if(self.config.logAt){
            NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
            [setString appendFormat:@"\"%@\" = ?,",kVsUpdateAt];
            [objs addObject:@(now)];
        }
        [setString deleteCharactersInRange:NSMakeRange(setString.length - 1, 1)];
        NSString *sql = [NSString stringWithFormat:@"UPDATE \"%@\" SET %@ %@",self.tableName,setString,where];
        return [self.vvdb executeUpdate:sql values:objs];
    }
    return NO;
}

- (BOOL)updateOne:(id)object{
    BOOL ret = [self updateOneWithoutNotification:object fields:nil];
    [self handleResult:ret action:VVOrmActionUpdate];
    return ret;
}

- (BOOL)updateOne:(id)object fields:(nullable NSArray<NSString *> *)fields{
    BOOL ret = [self updateOneWithoutNotification:object fields:fields];
    [self handleResult:ret action:VVOrmActionUpdate];
    return ret;
}

- (BOOL)updateOneWithoutNotification:(id)object fields:(nullable NSArray<NSString *> *)fields{
    NSDictionary *dic = [object isKindOfClass:[NSDictionary class]] ? object : [object vv_keyValues];
    NSString *primaryKey = self.config.primaryKey;
    if(primaryKey.length == 0 || !dic[primaryKey]) return NO;
    NSDictionary *condition = @{primaryKey:dic[primaryKey]};
    NSMutableDictionary *values = nil;
    if(fields.count == 0){
        values = dic.mutableCopy;
        [values removeObjectForKey:primaryKey];
    }
    else{
        values = [NSMutableDictionary dictionaryWithCapacity:fields.count];
        for (NSString *field in fields) {
            values[field] = dic[field];
        }
    }
    if(values.count == 0) return NO;
    return [self update:condition values:values];
}

- (BOOL)upsertOne:(id)object{
    if([self isExist:object]){
        return [self updateOne:object];
    }
    else{
        return [self insertOne:object];
    }
}


/**
 更新或插入一条数据
 
 @param object 要更新或插入的数据
 @return 0-失败,1-更新成功,2-插入成功
 */
- (NSUInteger)upsertOneWithoutNotification:(id)object{
    if([self isExist:object]){
        BOOL ret = [self updateOneWithoutNotification:object fields:nil];
        return ret ? 1 : 0;
    }
    else{
        BOOL ret = NO;//FIXME: [self insertOneWithoutNotification:object];
        return ret ? 2 : 0;
    }
}

- (NSUInteger)updateMulti:(NSArray *)objects{
    return [self updateMulti:objects fields:nil];
}

- (NSUInteger)updateMulti:(NSArray *)objects fields:(nullable NSArray<NSString *> *)fields{
    NSUInteger succCount = 0;
    for (id object in objects) {
        if([self updateOneWithoutNotification:object fields:fields]) {succCount ++;}
    }
    [self handleResult:succCount > 0 action:VVOrmActionUpdate];
    return succCount;
}

- (NSUInteger)upsertMulti:(NSArray *)objects{
    NSUInteger updateCount = 0;
    NSUInteger insertCount = 0;
    for (id object in objects) {
        NSUInteger ret = [self upsertOneWithoutNotification:object];
        if(ret == 1) updateCount ++;
        else if(ret == 2) insertCount ++;
    }
    if(updateCount + insertCount > 0){
        [self.cache removeAllObjects];
        [[NSNotificationCenter defaultCenter] postNotificationName:VVOrmModelDataChangeNotification object:self];
        if(updateCount > 0)
        [[NSNotificationCenter defaultCenter] postNotificationName:VVOrmModelDataUpdateNotification object:self];
        if(insertCount > 0)
        [[NSNotificationCenter defaultCenter] postNotificationName:VVOrmModelDataInsertNotification object:self];
    }
    return updateCount + insertCount;
}

- (BOOL)increase:(id)condition
           field:(NSString *)field
           value:(NSInteger)value{
    if (value == 0) { return YES; }
    NSMutableString *setString = [NSMutableString stringWithFormat:@"\"%@\" = \"%@\" %@ %@",
                                  field, field, value > 0 ? @"+": @"-", @(ABS(value))];
    if(self.config.logAt){
        NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
        [setString appendFormat:@",\"%@\" = \"%@\",",kVsUpdateAt,@(now)];
    }
    [setString deleteCharactersInRange:NSMakeRange(setString.length - 1, 1)];
    NSString *where = [VVSqlGenerator where:condition];
    NSString *sql = [NSString stringWithFormat:@"UPDATE \"%@\" SET %@ %@",self.tableName,setString,where];
    BOOL ret = [self.vvdb executeUpdate:sql];
    [self handleResult:ret action:VVOrmActionUpdate];
    return ret;
}

@end
