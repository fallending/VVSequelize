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

typedef NS_ENUM(NSUInteger, SqlDataType) {
    SqlDataTypeInteger = 1,
    SqlDataTypeText,
    SqlDataTypeBlob,
    SqlDataTypeReal,
    SqlDataTypeNumeric,
};

NSString * const SqlDataTypeString[] = {
    [SqlDataTypeInteger] = @"INTEGER",
    [SqlDataTypeText]    = @"TEXT",
    [SqlDataTypeBlob]    = @"BLOB",
    [SqlDataTypeReal]    = @"REAL",
    [SqlDataTypeNumeric] = @"NUMERIC"
};

NSString *sqlTypeStringOfType(SqlDataType type){
    return (type >= SqlDataTypeInteger && type <= SqlDataTypeNumeric) ? SqlDataTypeString[type] : nil;
}
SqlDataType sqlTypeWithString(NSString *typeString){
    NSString *uppercaseTypeString = typeString.uppercaseString;
    for (SqlDataType type = SqlDataTypeInteger; type <= SqlDataTypeNumeric; type ++) {
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
            storeFields[key] = @(type | option); //高8位为数据类型,低8位为数据选项
        }
        
        // 2. 检查数据表是否存在
        BOOL exist = [self isTableExist];
        // 2.若存在
        if(exist){
            // 获取已存在字段
            NSDictionary *tableFields = [self tableFields];
            // 计算需要添加的字段
            NSArray *tableKeys = tableFields.allKeys;
            NSInteger count = 0,failCount = 0;
            BOOL ret = YES;
            for (NSString *field in storeFields) {
                if([tableKeys containsObject:field]) continue;
                NSUInteger option = [storeFields[field] unsignedIntegerValue];
                NSString *fieldString = [self fieldSqlOf:field option:option];
                NSString *sql = [NSString stringWithFormat:@"ALERT TABLE \"%@\" %@", _tableName, fieldString];
                VVLog(@"%i: %@",__LINE__,sql);
                count ++;
                ret = [_vvfmdb.db executeUpdate:sql];
                if(!ret) failCount ++;
                if(option & VVOrmUnique){
                    sql = [NSString stringWithFormat:@"ALERT TABLE \"%@\" CONSTRAINT \"%@\" UNIQUE (\"%@\") ON CONFLICT FAIL ",_tableName, field, field];
                    VVLog(@"%i: %@",__LINE__,sql);
                    count ++;
                    ret = [_vvfmdb.db executeUpdate:sql];
                    if(!ret) failCount ++;
                }
            }
            NSAssert1(failCount == 0, @"插入字段失败: %@", @(count));
        }
        // 3.若不存在,计算需要新建的字段
        else{
            NSAssert1(storeFields.count > 0, @"无需创建表: %@", _tableName);
            NSString *primaryKey = nil;
            NSMutableString *fieldsString = [NSMutableString stringWithCapacity:0];
            for (NSString *field in storeFields) {
                NSUInteger option = [storeFields[field] unsignedIntegerValue];
                NSString *fieldStr = [self fieldSqlOf:field option:option];
                [fieldsString appendFormat:@"%@,",fieldStr];
                if(option & VVOrmPrimaryKey) primaryKey = field;
            }
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
    }
    return self;
}

#pragma mark - Private

- (NSString *)fieldSqlOf:(NSString *)column option:(VVOrmOption)option{
    NSMutableString *string = [NSMutableString stringWithFormat:@"\"%@\"",column];
    NSString *typeString = sqlTypeStringOfType(option >> 8);
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
        NSUInteger option = type << 8 | (notnull ? VVOrmNonnull :0) | (pk ? VVOrmPrimaryKey : 0);
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
        SqlDataType sqlDataType = [self sqliteTypeForPropertyType:type];
        dic[name] = @(sqlDataType << 8); // 高8位保存数据类型
    }
    free(properties);
    return dic;
}

- (SqlDataType)sqliteTypeForPropertyType:(NSString *)properyType{
    SqlDataType type = SqlDataTypeText;
    if ([properyType hasPrefix:@"T@\"NSString\""]) {
        type = SqlDataTypeText;
    }
    else if ([properyType hasPrefix:@"T@\"NSData\""]) {
        type = SqlDataTypeBlob;
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
        type = SqlDataTypeInteger;
    }
    else if ([properyType hasPrefix:@"Tf"]
             || [properyType hasPrefix:@"Td"]){
        type= SqlDataTypeReal;
    }
    return type;
}


@end
