//
//  VVOrmModel+Update.m
//  VVSequelize
//
//  Created by Jinbo Li on 2018/9/12.
//

#import "VVOrmModel+Update.h"
#import "NSObject+VVKeyValue.h"
#import "VVSqlGenerator.h"

@implementation VVOrmModel (Update)

- (BOOL)innerUpdate:(id)condition
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

- (BOOL)innerUpdateOne:(id)object fields:(nullable NSArray<NSString *> *)fields{
    NSString *primaryKey = self.config.primaryKey;
    if(primaryKey.length == 0 || ![object valueForKey:primaryKey]) return NO;
    NSDictionary *dic = [object isKindOfClass:[NSDictionary class]] ? object : [object vv_keyValues];
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
    return [self innerUpdate:condition values:values];
}

- (BOOL)update:(id)condition
        values:(NSDictionary *)values{
    BOOL ret = [self innerUpdate:condition values:values];
    [self handleResult:ret action:VVOrmActionUpdate];
    return ret;
}

- (BOOL)updateOne:(id)object{
    BOOL ret = [self innerUpdateOne:object fields:nil];
    [self handleResult:ret action:VVOrmActionUpdate];
    return ret;
}

- (BOOL)updateOne:(id)object fields:(nullable NSArray<NSString *> *)fields{
    BOOL ret = [self innerUpdateOne:object fields:fields];
    [self handleResult:ret action:VVOrmActionUpdate];
    return ret;
}

- (NSUInteger)updateMulti:(NSArray *)objects{
    return [self updateMulti:objects fields:nil];
}

- (NSUInteger)updateMulti:(NSArray *)objects fields:(nullable NSArray<NSString *> *)fields{
    NSUInteger succCount = 0;
    for (id object in objects) {
        if([self innerUpdateOne:object fields:fields]) {succCount ++;}
    }
    [self handleResult:succCount > 0 action:VVOrmActionUpdate];
    return succCount;
}

- (BOOL)increase:(id)condition
           field:(NSString *)field
           value:(NSInteger)value{
    if (value == 0) { return YES; }
    NSMutableString *setString = [NSMutableString stringWithFormat:@"\"%@\" = \"%@\"%@",
                                  field, field, @(value)];
    if(self.config.logAt){
        NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
        [setString appendFormat:@",\"%@\" = \"%@\"",kVsUpdateAt,@(now)];
    }
    NSString *where = [VVSqlGenerator where:condition];
    NSString *sql = [NSString stringWithFormat:@"UPDATE \"%@\" SET %@ %@",self.tableName,setString,where];
    BOOL ret = [self.vvdb executeUpdate:sql];
    [self handleResult:ret action:VVOrmActionUpdate];
    return ret;
}

@end
