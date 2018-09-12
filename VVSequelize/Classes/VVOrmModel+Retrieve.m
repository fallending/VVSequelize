//
//  VVOrmModel+Retrieve.m
//  VVSequelize
//
//  Created by Jinbo Li on 2018/9/12.
//

#import "VVOrmModel+Retrieve.h"
#import "VVSqlGenerator.h"
#import "NSObject+VVKeyValue.h"

@implementation VVOrmModel (Retrieve)

- (id)findOneByPKVal:(id)PKVal{
    if(!PKVal || self.config.primaryKey.length == 0) return nil;
    return [self findOne:@{self.config.primaryKey:PKVal}];
}

- (id)findOne:(id)condition{
    NSArray *array = [self findAll:condition orderBy:nil range:NSMakeRange(0, 1)];
    return array.count > 0 ? array.firstObject : nil;
}

- (id)findOne:(id)condition
      orderBy:(id)orderBy{
    NSArray *array = [self findAll:condition orderBy:orderBy range:NSMakeRange(0, 1)];
    return array.count > 0 ? array.firstObject : nil;
}

- (NSArray *)findAll:(id)condition{
    return [self findAll:condition orderBy:nil range:VVRangeAll];
}

- (NSArray *)findAll:(id)condition
             orderBy:(id)orderBy
               range:(NSRange)range{
    return [self findAll:condition fields:nil orderBy:orderBy range:range];
}

- (NSArray *)findAll:(id)condition
              fields:(NSArray<NSString *> *)fields
             orderBy:(id)orderBy
               range:(NSRange)range{
    return [self findAll:condition fields:fields orderBy:orderBy range:range jsonResult:NO];
}

- (NSArray *)findAll:(id)condition
              fields:(NSArray<NSString *> *)fields
             orderBy:(id)orderBy
               range:(NSRange)range
          jsonResult:(BOOL)jsonResult{
    NSString *fieldsStr = @"*";
    if(fields.count > 0){
        NSMutableString *tempStr = [NSMutableString stringWithCapacity:0];
        for (NSString *field in fields) {
            if(field.length > 0) [tempStr appendFormat:@"\"%@\",",field];
        }
        if(tempStr.length > 1) {
            [tempStr deleteCharactersInRange:NSMakeRange(tempStr.length - 1, 1)];
            fieldsStr = tempStr;
        }
    }
    NSString *where = [VVSqlGenerator where:condition];
    NSString *order = [VVSqlGenerator orderBy:orderBy];
    NSString *limit = [VVSqlGenerator limit:range];
    NSString *sql = [NSString stringWithFormat:@"SELECT %@ FROM \"%@\"%@%@%@ ", fieldsStr, self.tableName,where,order,limit];
    NSArray *results = [self.cache objectForKey:sql];
    if(!results){
        NSArray *jsonArray = [self.vvdb executeQuery:sql];
        results = jsonArray;
        if(!jsonResult && [fieldsStr isEqualToString:@"*"]){
            results = [self.config.cls vv_objectsWithKeyValuesArray:jsonArray];
        }
        [self.cache setObject:results forKey:sql];
    }
    return results;
}

- (NSInteger)count:(id)condition{
    NSString *where = [VVSqlGenerator where:condition];
    NSString *sql = [NSString stringWithFormat:@"SELECT count(*) as \"count\" FROM \"%@\"%@", self.tableName,where];
    NSArray *array = [self.cache objectForKey:sql];
    if(!array){
        array = [self.vvdb executeQuery:sql];
        [self.cache setObject:array forKey:sql];
    }
    NSInteger count = 0;
    if (array.count > 0) {
        NSDictionary *dic = array.firstObject;
        count = [dic[@"count"] integerValue];
    }
    return count;
}

- (BOOL)isExist:(id)object{
    NSString *primaryKey =self.config.primaryKey;
    if(primaryKey.length == 0) return NO;
    id pk = [object valueForKey:primaryKey];
    if(!pk) return NO;
    NSDictionary *condition = @{primaryKey:pk};
    return [self count:condition] > 0;
}

- (NSDictionary *)findAndCount:(id)condition
                       orderBy:(id)orderBy
                         range:(NSRange)range{
    NSUInteger count = [self count:condition];
    NSArray *array = [self findAll:condition orderBy:orderBy range:range];
    return @{@"count":@(count), @"list":array};
}

/**
 SQLite中每个表都默认包含一个隐藏列rowid，使用WITHOUT ROWID定义的表除外。通常情况下，rowid可以唯一的标记表中的每个记录。表中插入的第一个条记录的rowid为1，后续插入的记录的rowid依次递增1。即使插入失败，rowid也会被加一。所以，整个表中的rowid并不一定连续，即使用户没有删除过记录。
 由于唯一性，所以rowid在很多场合中当作主键使用。在使用的时候，select * from tablename 并不能获取rowid，必须显式的指定。例如，select rowid, * from tablename 才可以获取rowid列。查询rowid的效率非常高，所以直接使用rowid作为查询条件是一个优化查询的好方法。
 但是rowid列作为主键，在极端情况下存在隐患。由于rowid值会一直递增，如果达到所允许的最大值9223372036854775807后，它会自动搜索没有被使用的值，重新使用，并不会提示用户。这时，使用rowid排序记录，会产生乱序，并引入其他的逻辑问题。所以，如果用户的数据库存在这种可能的情况，就应该使用AUTOINCREMENT定义主键，从而避免这种问题。使用AUTOINCREMENT设置自增主键，虽然也会遇到9223372036854775807问题，但是它会报错，提示用户，避免产生rowid所引发的问题。
 通常iOS App内嵌数据库单表的数据量不会达到rowid最大值，此处取`max(rowid)`可以做唯一值, `max(rowid) + 1`为下一条将插入的数据的自动主键值.
 */
- (NSUInteger)maxRowid{
    return [[self max:@"rowid"] unsignedIntegerValue];
}

- (id)max:(NSString *)field{
    return [self calc:field method:@"max"];
}

- (id)min:(NSString *)field{
    return [self calc:field method:@"min"];
}

- (id)sum:(NSString *)field{
    return [self calc:field method:@"sum"];
}

- (id)calc:(NSString *)field method:(NSString *)method{
    if(!([method isEqualToString:@"max"]
         || [method isEqualToString:@"min"]
         || [method isEqualToString:@"sum"])) return nil;
    NSString *sql = [NSString stringWithFormat:@"SELECT %@(\"%@\") AS \"%@\" FROM \"%@\"", method, field, method, self.tableName];
    NSArray *array = [self.cache objectForKey:sql];
    if(!array){
        array = [self.vvdb executeQuery:sql];
        [self.cache setObject:array forKey:sql];
    }
    id result = nil;
    if(array.count > 0){
        NSDictionary *dic = array.firstObject;
        result = dic[method];
    }
    return [result isKindOfClass:NSNull.class] ? nil : result;
}

@end
