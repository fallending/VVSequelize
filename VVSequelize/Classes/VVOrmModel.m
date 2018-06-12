//
//  VVOrmModel.m
//  Pods
//
//  Created by Jinbo Li on 2018/6/6.
//

#import "VVOrmModel.h"
#import <objc/runtime.h>
#import "VVSequelizeConst.h"

#define kTypeShift  8

typedef NS_ENUM(NSUInteger, SqliteType) {
    SqliteTypeInteger = 1,
    SqliteTypeText,
    SqliteTypeBlob,
    SqliteTypeReal,
};

NSString * const SqliteTypeString[] = {
    [SqliteTypeInteger] = @"INTEGER",
    [SqliteTypeText]    = @"TEXT",
    [SqliteTypeBlob]    = @"BLOB",
    [SqliteTypeReal]    = @"REAL"
};

NSString *sqlTypeStringOfType(SqliteType type){
    return (type >= SqliteTypeInteger && type <= SqliteTypeReal) ? SqliteTypeString[type] : nil;
}
SqliteType sqlTypeWithString(NSString *typeString){
    NSString *uppercaseTypeString = typeString.uppercaseString;
    for (SqliteType type = SqliteTypeInteger; type <= SqliteTypeReal; type ++) {
        NSString *tempString = sqlTypeStringOfType(type);
        if ([uppercaseTypeString hasPrefix:tempString]) {
            return type;
        }
    }
    return 0;
}

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
        _vvfmdb    = vvfmdb ? vvfmdb : VVFMDB.defalutDb;
        _tableName = tableName.length > 0 ?  tableName : NSStringFromClass(cls);
        _cls       = cls;
        NSDictionary *classFields = [self classFields];
        NSMutableDictionary *storeFields = [NSMutableDictionary dictionaryWithCapacity:0];
        // 1. 生成数据库fields
        for (NSString *key in classFields) {
            if([excludes containsObject:key]) continue;
            NSUInteger type = [classFields[key] integerValue];
            NSUInteger option = [fieldOptions[key] integerValue];
            if(option & VVOrmPrimaryKey) {option |= VVOrmNonnull;}
            storeFields[key] = @(type | option); //高8位为数据类型,低8位为数据选项
        }
        NSAssert1(storeFields.count > 0, @"无需创建表: %@", _tableName);
        
        // 2. 检查数据表是否存在
        BOOL exist = [self isTableExist];
        NSInteger changed = 0;
        // 3. 若存在,检查是否需要进行变更.如需变更,则将原数据表进行更名.
        NSString *tempTableName = [NSString stringWithFormat:@"%@_%@",_tableName, @((NSUInteger)[[NSDate date] timeIntervalSince1970])];
        if(exist){
            // 获取已存在字段
            NSDictionary *tableFields = [self tableFields];
            // 计算变化的字段数量
            NSArray *tableKeys = tableFields.allKeys;
            for (NSString *field in storeFields) {
                if(![tableKeys containsObject:field]){ changed ++; continue; }
                NSUInteger tableFieldOption = [tableFields[field] unsignedIntegerValue] | VVOrmUnique;
                NSUInteger storeFieldOption = [storeFields[field] unsignedIntegerValue] | VVOrmUnique;
                if(tableFieldOption != storeFieldOption) changed ++;
            }
            NSArray *storeKeys = storeFields.allKeys;
            for (NSString *field in tableFields) {
                if([field isEqualToString:@"vv_createAt"] || [field isEqualToString:@"vv_updateAt"]) continue;
                if(![storeKeys containsObject:field]){ changed ++; continue; }
                NSUInteger tableFieldOption = [tableFields[field] unsignedIntegerValue] | VVOrmUnique;
                NSUInteger storeFieldOption = [storeFields[field] unsignedIntegerValue] | VVOrmUnique;
                if(tableFieldOption != storeFieldOption) changed ++;
            }
            // 字段发生变更,对原数据表进行更名
            if(changed > 0){
                NSString *sql = [NSString stringWithFormat:@"ALTER TABLE \"%@\" RENAME TO \"%@\"", _tableName, tempTableName];
                VVLog(@"%i: %@",__LINE__,sql);
                BOOL ret = [_vvfmdb.db executeUpdate:sql];
                NSAssert1(ret, @"创建临时表失败: %@", tempTableName);
            }
        }
        
        //4. 表不存在或字段发生变更,需要创建新表
        if(!exist || changed > 0){
            NSString *primaryKey = nil;
            NSMutableString *fieldsString = [NSMutableString stringWithCapacity:0];
            for (NSString *field in storeFields) {
                NSUInteger option = [storeFields[field] unsignedIntegerValue];
                NSString *fieldStr = [self fieldSqlOf:field option:option];
                [fieldsString appendFormat:@"%@,",fieldStr];
                if(option & VVOrmPrimaryKey) primaryKey = field;
            }
            [fieldsString appendFormat:@"%@,",[self fieldSqlOf:@"vv_createAt" option:(SqliteTypeInteger << kTypeShift)]]; //创建时间
            [fieldsString appendFormat:@"%@,",[self fieldSqlOf:@"vv_updateAt" option:(SqliteTypeInteger << kTypeShift)]]; //修改时间
            if(!primaryKey){
                [fieldsString appendFormat:@"\"vv_pkid\" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,"];
            }
            for (NSString *field in storeFields) {
                NSUInteger option = [storeFields[field] unsignedIntegerValue];
                if(option & VVOrmUnique) {
                    [fieldsString appendFormat:@"CONSTRAINT \"%@\" UNIQUE (\"%@\") ON CONFLICT FAIL,", field, field];
                }
            }
            [fieldsString deleteCharactersInRange:NSMakeRange(fieldsString.length - 1, 1)];
            NSString *sql = [NSString stringWithFormat:@"CREATE TABLE IF NOT EXISTS \"%@\" (%@)  ", _tableName, fieldsString];
            VVLog(@"%i: %@",__LINE__,sql);
            BOOL ret = [_vvfmdb.db executeUpdate:sql];
            NSAssert1(ret, @"创建表失败: %@", _tableName);
        }
        //5. 如果字段发生变更,将原数据表的数据插入新表
        if(exist && changed > 0){
            NSMutableString *allfields = [NSMutableString stringWithCapacity:0];
            for (NSString *field in storeFields) {
                [allfields appendFormat:@"\"%@\",",field];
            }
            if(allfields.length > 1) {
                [allfields deleteCharactersInRange:NSMakeRange(allfields.length - 1, 1)];
            }
            [_vvfmdb vv_inDatabase:^{
                NSString *sql = [NSString stringWithFormat:@"INSERT INTO \"%@\" (%@) SELECT %@ FROM \"%@\"", _tableName, allfields, allfields, tempTableName];
                VVLog(@"%i: %@",__LINE__,sql);
                BOOL ret = [_vvfmdb.db executeUpdate:sql];
                sql = [NSString stringWithFormat:@"DROP TABLE \"%@\"", tempTableName];
                VVLog(@"%i: %@",__LINE__,sql);
                ret = [_vvfmdb.db executeUpdate:sql];
            }];
        }
    }
    return self;
}

#pragma mark - Private

- (NSString *)fieldSqlOf:(NSString *)column option:(VVOrmOption)option{
    NSMutableString *string = [NSMutableString stringWithFormat:@"\"%@\"",column];
    NSString *typeString = sqlTypeStringOfType(option >> kTypeShift);
    [string appendFormat:@" %@", typeString];
    if(option & VVOrmPrimaryKey){
        [string appendString:@" PRIMARY KEY NOT NULL"];
    }
    else if(option & VVOrmNonnull){
        [string appendString:@" NOT NULL"];
    }
    if(option & VVOrmAutoIncrement){ [string appendString:@" AUTOINCREMENT"];}
    return string;
}

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

- (NSDictionary *)tableFields{
    NSString *sql = [NSString stringWithFormat:@"PRAGMA table_info(\"%@\");",_tableName];
    VVLog(@"%i: %@",__LINE__,sql);
    FMResultSet *set = [_vvfmdb.db executeQuery:sql];
    NSMutableDictionary *resultDic = [NSMutableDictionary dictionaryWithCapacity:0];
    while ([set next]){
        NSDictionary *dic = set.resultDictionary;
        NSString *key = dic[@"name"];
        NSString *typeString = dic[@"type"];
        NSUInteger type = sqlTypeWithString(typeString);
        BOOL notnull = [dic[@"notnull"] boolValue];
        BOOL pk = [dic[@"pk"] boolValue];
        NSUInteger option = type << kTypeShift | (notnull ? VVOrmNonnull :0) | (pk ? VVOrmPrimaryKey : 0);
        resultDic[key] = @(option);
    }
    return resultDic;
}

- (NSDictionary *)classFields{
    NSMutableDictionary *dic = [NSMutableDictionary dictionaryWithCapacity:0];
    unsigned int count;
    objc_property_t *properties = class_copyPropertyList(_cls, &count);
    for (int i = 0; i < count; i++) {
        NSString *name = [NSString stringWithCString:property_getName(properties[i]) encoding:NSUTF8StringEncoding];
        NSString *type = [NSString stringWithCString:property_getAttributes(properties[i]) encoding:NSUTF8StringEncoding];
        SqliteType sqlDataType = [self sqliteTypeForPropertyType:type];
        dic[name] = @(sqlDataType << kTypeShift); // 高8位保存数据类型
    }
    free(properties);
    return dic;
}

- (SqliteType)sqliteTypeForPropertyType:(NSString *)properyType{
    // NSString,NSMutableString,NSDictionary,NSMutableDictionary,NSArray,NSSet,NSMutableSet,...
    SqliteType type = SqliteTypeText;
    // NSData,NSMutableData
    if ([properyType hasPrefix:@"T@\"NSData\""] ||
        [properyType hasPrefix:@"T@\"NSMutableData\""]){
        type = SqliteTypeBlob;
    }
    else if ([properyType hasPrefix:@"Ti"]
             ||[properyType hasPrefix:@"TI"]
             ||[properyType hasPrefix:@"Ts"]
             ||[properyType hasPrefix:@"TS"]
             ||[properyType hasPrefix:@"T@\"NSNumber\""]
             ||[properyType hasPrefix:@"T@\"NSDate\""]   // NSDate转换为timestamp存入数据库
             ||[properyType hasPrefix:@"TB"]
             ||[properyType hasPrefix:@"Tq"]
             ||[properyType hasPrefix:@"TQ"]) {
        type = SqliteTypeInteger;
    }
    else if ([properyType hasPrefix:@"Tf"]
             || [properyType hasPrefix:@"Td"]){
        type= SqliteTypeReal;
    }
    return type;
}


@end
