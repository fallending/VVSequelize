//
//  VVOrmModel.m
//  VVSequelize
//
//  Created by Jinbo Li on 2018/6/6.
//

#import "VVOrmModel.h"
#import <objc/runtime.h>
#import "VVSequelize.h"
#import "VVSequelizeConst.h"
#import "VVSqlGenerator.h"

#define kTypeShift  8
#define kVsPkid  @"vv_pkid"
#define kVsCreateAt  @"vv_createAt"
#define kVsUpdateAt  @"vv_updateAt"

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
@property (nonatomic, copy  ) NSString *primaryKey;

@end

@implementation VVOrmModel

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

#pragma mark - Public
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
            if(option & VVOrmPrimaryKey) {
                _primaryKey = key;
                option |= VVOrmNonnull;
            }
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
                if([field isEqualToString:kVsCreateAt] || [field isEqualToString:kVsUpdateAt]) continue;
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
            NSMutableString *fieldsString = [NSMutableString stringWithCapacity:0];
            for (NSString *field in storeFields) {
                NSUInteger option = [storeFields[field] unsignedIntegerValue];
                NSString *fieldStr = [self fieldSqlOf:field option:option];
                [fieldsString appendFormat:@"%@,",fieldStr];
                if(option & VVOrmPrimaryKey) _primaryKey = field;
            }
            [fieldsString appendFormat:@"%@,",[self fieldSqlOf:kVsCreateAt option:(SqliteTypeInteger << kTypeShift)]]; //创建时间
            [fieldsString appendFormat:@"%@,",[self fieldSqlOf:kVsUpdateAt option:(SqliteTypeInteger << kTypeShift)]]; //修改时间
            if(!_primaryKey){
                [fieldsString appendFormat:@"\"%@\" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,",kVsPkid];
                _primaryKey = kVsPkid;
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

@end

#pragma mark - CURD(C)创建
@implementation VVOrmModel (Create)

-(BOOL)insertOne:(id)object{
    if(!_primaryKey || [_primaryKey isEqualToString:kVsPkid] || !VVSequelize.objectToDic) return NO;
    NSDictionary *dic = VVSequelize.objectToDic(object);
    NSMutableString *keyString = [NSMutableString stringWithCapacity:0];
    NSMutableString *valString = [NSMutableString stringWithCapacity:0];
    [dic enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        if(key && obj){
            [keyString appendFormat:@"\"%@\",",key];
            [valString appendFormat:@"\"%@\",",obj];
        }
    }];
    if(keyString.length > 1 && valString.length > 1){
        [keyString deleteCharactersInRange:NSMakeRange(keyString.length - 1, 1)];
        [valString deleteCharactersInRange:NSMakeRange(valString.length - 1, 1)];
        NSString *sql = [NSString stringWithFormat:@"INSERT INTO \"%@\" (%@) VALUES (%@)",_tableName,keyString,valString];
        return [_vvfmdb vv_executeQuery:sql];
    }
    return NO;
}

-(BOOL)insertMulti:(NSArray *)objects{
    NSInteger failCount = 0;
    for (id obj in objects) {
        if(![self insertOne:obj]){ failCount ++;}
    }
    return failCount == 0;
}

@end

#pragma mark - CURD(U)更新
@implementation VVOrmModel (Update)

- (BOOL)update:(NSDictionary *)condition
        values:(NSDictionary *)values{
    NSString *where = [VVSqlGenerator where:condition];
    NSMutableString *setString = [NSMutableString stringWithCapacity:0];
    [values enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        [setString appendFormat:@"\"%@\" = \"%@\",",key,obj];
    }];
    if (setString.length > 1) {
        [setString deleteCharactersInRange:NSMakeRange(setString.length - 1, 1)];
        NSString *sql = [NSString stringWithFormat:@"UPDATE %@ SET %@ WHERE %@",_tableName,setString,where];
        return [_vvfmdb vv_executeUpdate:sql];
    }
    return NO;
}

- (BOOL)updateOne:(id)object{
    if(!_primaryKey || [_primaryKey isEqualToString:kVsPkid] || !VVSequelize.objectToDic) return NO;
    NSDictionary *dic = VVSequelize.objectToDic(object);
    if(!dic[_primaryKey]) return NO;
    NSDictionary *condition = @{_primaryKey:dic[_primaryKey]};
    NSMutableDictionary *values = dic.mutableCopy;
    [values removeObjectForKey:_primaryKey];
    return [self update:condition values:values];
}

- (BOOL)upsertOne:(id)object{
    if(!_primaryKey || [_primaryKey isEqualToString:kVsPkid] || !VVSequelize.objectToDic) return NO;
    NSDictionary *dic = VVSequelize.objectToDic(object);
    if(!dic[_primaryKey]) return NO;
    NSDictionary *condition = @{_primaryKey:dic[_primaryKey]};
    NSString *where = [VVSqlGenerator where:condition];
    NSString *sql = [NSString stringWithFormat:@"SELECT count AS count(*) FROM \"%@\"%@", _tableName,where];
    NSArray *array = [_vvfmdb vv_executeQuery:sql];
    NSInteger count = 0;
    if (array.count > 0) {
        NSDictionary *dic = array.firstObject;
        count = [dic[@"count"] integerValue];
    }
    if(count > 0){
        NSMutableDictionary *values = dic.mutableCopy;
        [values removeObjectForKey:_primaryKey];
        return [self update:condition values:values];
    }
    else{
        NSMutableString *keyString = [NSMutableString stringWithCapacity:0];
        NSMutableString *valString = [NSMutableString stringWithCapacity:0];
        [dic enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
            if(key && obj){
                [keyString appendFormat:@"\"%@\",",key];
                [valString appendFormat:@"\"%@\",",obj];
            }
        }];
        if(keyString.length > 1 && valString.length > 1){
            [keyString deleteCharactersInRange:NSMakeRange(keyString.length - 1, 1)];
            [valString deleteCharactersInRange:NSMakeRange(valString.length - 1, 1)];
            NSString *sql = [NSString stringWithFormat:@"INSERT INTO \"%@\" (%@) VALUES (%@)",_tableName,keyString,valString];
            return [_vvfmdb vv_executeQuery:sql];
        }
        return NO;
    }
}

- (BOOL)updateMulti:(NSArray *)objects{
    if(!_primaryKey || [_primaryKey isEqualToString:kVsPkid] || !VVSequelize.objectsToDicArray) return NO;
    NSArray *array = VVSequelize.objectsToDicArray(objects);
    NSInteger failCount = 0;
    for (NSDictionary *dic in array) {
        if(!dic[_primaryKey]){ failCount ++;  continue;}
        NSDictionary *condition = @{_primaryKey:dic[_primaryKey]};
        NSMutableDictionary *values = dic.mutableCopy;
        [values removeObjectForKey:_primaryKey];
        if(![self update:condition values:values]) {failCount ++;}
    }
    return failCount == 0;
}

- (BOOL)upsertMulti:(NSArray *)objects{
    NSInteger failCount = 0;
    for (id object in objects) {
        if(![self upsertOne:object]) {failCount ++;}
    }
    return failCount == 0;
}

- (BOOL)increase:(NSDictionary *)condition
           field:(NSString *)field
           value:(NSInteger)value{
    if (value == 0) { return YES; }
    NSString *setString = value > 0 ?
    [NSString stringWithFormat:@"\"%@\" = \"%@\" + \"%@\"",field,field,@(value)]:
    [NSString stringWithFormat:@"\"%@\" = \"%@\" - \"%@\"",field,field,@(ABS(value))];
    NSString *where = [VVSqlGenerator where:condition];
    NSString *sql = [NSString stringWithFormat:@"UPDATE \"%@\" SET %@ WHERE %@",_tableName,setString, where];
    return [_vvfmdb vv_executeUpdate:sql];
}

@end

#pragma mark - CURD(R)读取
@implementation VVOrmModel (Retrieve)

- (id)findOne:(NSDictionary *)condition{
    NSArray *array = [self findAll:condition orderBy:nil range:NSMakeRange(0, 1)];
    return array.count > 0 ? array.firstObject : nil;
}

- (NSArray *)findAll:(NSDictionary *)condition{
    return [self findAll:condition orderBy:nil range:VVRangeAll];
}

- (NSArray *)findAll:(NSDictionary *)condition
             orderBy:(NSDictionary *)orderBy
               range:(NSRange)range{
    NSString *where = [VVSqlGenerator where:condition];
    NSString *order = [VVSqlGenerator orderBy:orderBy];
    NSString *limit = [VVSqlGenerator limit:range];
    NSString *sql = [NSString stringWithFormat:@"SELECT * FROM \"%@\"%@%@%@ ", _tableName,where,order,limit];
    NSArray *jsonArray = [_vvfmdb vv_executeQuery:sql];
    if (VVSequelize.dicArrayToObjects) {
        return VVSequelize.dicArrayToObjects(jsonArray);
    }
    return jsonArray;
}

- (NSInteger)count:(NSDictionary *)condition{
    NSString *where = [VVSqlGenerator where:condition];
    NSString *sql = [NSString stringWithFormat:@"SELECT count AS count(*) FROM \"%@\"%@", _tableName,where];
    NSArray *array = [_vvfmdb vv_executeQuery:sql];
    NSInteger count = 0;
    if (array.count > 0) {
        NSDictionary *dic = array.firstObject;
        count = [dic[@"count"] integerValue];
    }
    return count;
}

- (BOOL)isExist:(id)object{
    if(!_primaryKey || [_primaryKey isEqualToString:kVsPkid] || !VVSequelize.objectToDic) return NO;
    NSDictionary *dic = VVSequelize.objectToDic(object);
    if(!dic[_primaryKey]) return NO;
    NSDictionary *condition = @{_primaryKey:dic[_primaryKey]};
    return [self count:condition] > 0;
}

- (NSDictionary *)findAndCount:(NSDictionary *)condition
                       orderBy:(NSDictionary *)orderBy
                         range:(NSRange)range{
    NSUInteger count = [self count:condition];
    NSArray *array = [self findAll:condition orderBy:orderBy range:range];
    return @{@"count":@(count), @"list":array};
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
    NSString *sql = [NSString stringWithFormat:@"SELECT %@ AS %@(\"%@\") FROM \"%@\"", method, method, field, _tableName];
    NSArray *array = [_vvfmdb vv_executeQuery:sql];
    id result = nil;
    if(array.count > 0){
        NSDictionary *dic = array.firstObject;
        result = dic[method];
    }
    return result;
}

@end

#pragma mark - CURD(D)删除
@implementation VVOrmModel (Delete)

- (BOOL)drop{
    NSString *sql = [NSString stringWithFormat:@"DROP TABLE \"%@\"",_tableName];
    return [_vvfmdb vv_executeUpdate:sql];
}

- (BOOL)deleteOne:(id)object{
    if(!_primaryKey || [_primaryKey isEqualToString:kVsPkid] || !VVSequelize.objectToDic) return NO;
    NSDictionary *dic = VVSequelize.objectToDic(object);
    id pkid = dic[_primaryKey];
    if(!pkid) return NO;
    NSString *where = [VVSqlGenerator where:@{_primaryKey:pkid}];
    NSString *sql = [NSString stringWithFormat:@"DELETE FROM \"%@\" WHERE %@",_tableName, where];
    return [_vvfmdb vv_executeUpdate:sql];
}

- (BOOL)deleteMulti:(NSArray *)objects{
    if(!_primaryKey || [_primaryKey isEqualToString:kVsPkid] || !VVSequelize.objectsToDicArray) return NO;
    NSArray *array = VVSequelize.objectsToDicArray(objects);
    NSMutableArray *pkids = [NSMutableArray arrayWithCapacity:0];
    for (NSDictionary *dic in array) {
        id pkid = dic[_primaryKey];
        if(pkid){ [pkids addObject:pkid];}
    }
    NSString *where = [VVSqlGenerator where:@{_primaryKey:@{kVsOpIn:pkids}}];
    NSString *sql = [NSString stringWithFormat:@"DELETE FROM \"%@\" WHERE %@",_tableName, where];
    return [_vvfmdb vv_executeUpdate:sql];
}

- (BOOL)delete:(NSDictionary *)condition{
    NSString *where = [VVSqlGenerator where:condition];
    NSString *sql = [NSString stringWithFormat:@"DELETE FROM \"%@\" WHERE %@",_tableName, where];
    return [_vvfmdb vv_executeUpdate:sql];
}

@end
