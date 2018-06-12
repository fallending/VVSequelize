//
//  VVOrmModel.m
//  Pods
//
//  Created by Jinbo Li on 2018/6/6.
//

#import "VVOrmModel.h"
#import <objc/runtime.h>
#import "VVSequelizeConst.h"

#define SQL_TEXT     @"TEXT" //文本
#define SQL_INTEGER  @"INTEGER" //int long integer ...
#define SQL_REAL     @"REAL" //浮点
#define SQL_BLOB     @"BLOB" //data

@interface VVOrmModel ()

@property (nonatomic, strong) VVFMDB *vvfmdb;
@property (nonatomic, copy  ) NSString *tableName;
@property (nonatomic, copy  ) NSArray *fields;
@property (nonatomic        ) Class cls;

@end

@implementation VVOrmModel

- (instancetype)initWithClass:(Class)cls{
    return [self initWithClass:cls fieldOptions:nil excludes:nil tableName:nil dataBase:nil];
}

- (instancetype)initWithClass:(Class)cls tableName:(NSString *)tableName dataBase:(VVFMDB *)db{
    return [self initWithClass:cls fieldOptions:nil excludes:nil tableName:tableName dataBase:db];
}

- (instancetype)initWithClass:(Class)cls
                 fieldOptions:(NSDictionary *)fieldOptions
                     excludes:(NSArray *)excludes
                    tableName:(NSString *)tableName
                     dataBase:(VVFMDB *)vvfmdb{
    self = [super init];
    if (self) {
        _vvfmdb    = vvfmdb;
        _tableName = tableName;
        _cls       = cls;
        
        NSDictionary *classFields = [self classFields];
        // 1. 生成数据库fields
        for (NSString *key in classFields) {
            if([excludes containsObject:key]) continue;
            NSString *type = classFields[key];
            NSUInteger option = [fieldOptions[key] integerValue];
            
        }
        
        // 2. 检查数据表是否存在
        BOOL exist = [self isTableExist];
        // 2.若存在
        if(exist){
            // 获取已存在字段
            NSArray *tableFields = [self tableFields];
            NSMutableArray *willModifies = [NSMutableArray arrayWithCapacity:0];
            NSMutableArray *willDeletes = [NSMutableArray arrayWithCapacity:0];
            
            
            // 计算需要修改的字段
            
            // 计算需要删除的字段
        }
        // 3.若不存在,计算需要新建的字段
        else{
            
        }
        
        // 生成SQL语句并执行
        
    }
    return self;
    /*
    NSDictionary *dic = nil;
    if ([dicOrModel isKindOfClass:[NSDictionary class]]) {
        dic = [self dictionary:dicOrModel exclude:excludeFields];
    } else {
        dic = [self sqliteMapOfClass:dicOrModel exclude:excludeFields];
    }
    if(!dic) {return NO;}
    
    NSMutableString *tableSql = [NSMutableString stringWithCapacity:0];
    if(!primaryKey || primaryKey.length == 0) {
        [tableSql appendFormat:@"\"vv_pkid\" integer NOT NULL PRIMARY KEY AUTOINCREMENT,"];
    }
    [dic enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *type, BOOL *stop) {
        if([key isEqualToString:primaryKey]){
            [tableSql appendFormat:@" \"%@\" %@ NOT NULL,",key, type];
        }
        else{
            [tableSql appendFormat:@" \"%@\" %@,",key, type];
        }
    }];
    if(primaryKey && primaryKey.length > 0){
        [tableSql appendFormat:@"  PRIMARY KEY (\"%@\"),", primaryKey];
    }
    if(uniqueFields && uniqueFields.count > 0){
        [uniqueFields enumerateObjectsUsingBlock:^(NSString *field, NSUInteger idx, BOOL *stop) {
            [tableSql appendFormat:@"CONSTRAINT \"%@\" UNIQUE (\"%@\") ON CONFLICT IGNORE,",field,field];
        }];
    }
    if(tableSql.length > 1){
        [tableSql deleteCharactersInRange:NSMakeRange(tableSql.length - 1, 1)];
        NSString *sql = [NSString stringWithFormat:@"CREATE TABLE IF NOT EXISTS \"%@\" (%@)",tableName,tableSql];
        VVLog(@"%i: %@",__LINE__,sql);
        return [_db executeUpdate:sql];
    }
    return NO;
     */
}

#pragma mark - Private
- (BOOL)isTableExist{
    NSString *sql = [NSString stringWithFormat:@"SELECT count(*) as 'count' FROM sqlite_master WHERE type ='table' and name = \"%@\"",_tableName];
    VVLog(@"%i: %@",__LINE__,sql);
    FMResultSet *set = [_vvfmdb.db executeQuery:sql];
    while ([set next]){
        NSInteger count = [set intForColumn:@"count"];
        return count > 0;
    }
    return NO;
}

- (NSArray *)tableFields{
    NSString *sql = [NSString stringWithFormat:@"PRAGMA table_info(\"%@\");",_tableName];
    VVLog(@"%i: %@",__LINE__,sql);
    FMResultSet *set = [_vvfmdb.db executeQuery:sql];
    NSMutableArray *array = [NSMutableArray arrayWithCapacity:0];
    while ([set next]){
        [array addObject:set.resultDictionary];
    }
    return array;
}

- (NSDictionary *)classFields{
    NSMutableDictionary *dic = [NSMutableDictionary dictionaryWithCapacity:0];
    unsigned int count;
    objc_property_t *properties = class_copyPropertyList(_cls, &count);
    for (int i = 0; i < count; i++) {
        NSString *name = [NSString stringWithCString:property_getName(properties[i]) encoding:NSUTF8StringEncoding];
        NSString *type = [NSString stringWithCString:property_getAttributes(properties[i]) encoding:NSUTF8StringEncoding];
        id sqliteType = [self sqliteTypeForPropertyType:type];
        if (sqliteType) {
            [dic setObject:sqliteType forKey:name];
        }
    }
    free(properties);
    return dic;
}

- (NSString *)sqliteTypeForPropertyType:(NSString *)properyType{
    NSString *resultStr = nil;
    if ([properyType hasPrefix:@"T@\"NSString\""]) {
        resultStr = SQL_TEXT;
    }
    else if ([properyType hasPrefix:@"T@\"NSData\""]) {
        resultStr = SQL_BLOB;
    }
    else if ([properyType hasPrefix:@"Ti"]
             ||[properyType hasPrefix:@"TI"]
             ||[properyType hasPrefix:@"Ts"]
             ||[properyType hasPrefix:@"TS"]
             ||[properyType hasPrefix:@"T@\"NSNumber\""]
             ||[properyType hasPrefix:@"TB"]
             ||[properyType hasPrefix:@"Tq"]
             ||[properyType hasPrefix:@"TQ"]) {
        resultStr = SQL_INTEGER;
    }
    else if ([properyType hasPrefix:@"Tf"]
             || [properyType hasPrefix:@"Td"]){
        resultStr= SQL_REAL;
    }
    return resultStr;
}


@end
