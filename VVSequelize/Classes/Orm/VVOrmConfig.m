//
//  VVOrmConfig.m
//  VVSequelize
//
//  Created by Valo on 2018/9/10.
//

#import "VVOrmConfig.h"
#import "VVDatabase.h"
#import "VVClassInfo.h"
#import "NSObject+VVOrm.h"

NSString *const kVVCreateAt = @"vv_createAt";
NSString *const kVVUpdateAt = @"vv_updateAt";

NSString *const VVSqlTypeInteger = @"INTEGER";
NSString *const VVSqlTypeText = @"TEXT";
NSString *const VVSqlTypeBlob = @"BLOB";
NSString *const VVSqlTypeReal = @"REAL";

@interface VVPropertyInfo (VVOrmConfig)
- (NSString *)sqlType;
@end

@implementation VVPropertyInfo (VVOrmConfig)
- (NSString *)sqlType
{
    NSString *type = VVSqlTypeText;
    switch (self.type) {
        case VVEncodingTypeCNumber:
            type = VVSqlTypeInteger;
            break;
        case VVEncodingTypeCRealNumber:
            type = VVSqlTypeReal;
            break;
        case VVEncodingTypeObject: {
            switch (self.nsType) {
                case VVEncodingTypeNSNumber:
                case VVEncodingTypeNSDecimalNumber:
                    type = VVSqlTypeReal;
                    break;
                case VVEncodingTypeNSData:
                case VVEncodingTypeNSMutableData:
                    type = VVSqlTypeBlob;
                    break;
                default:
                    break;
            }
        }   break;
        default:
            break;
    }
    return type;
}

@end

@interface VVOrmConfig ()
@property (nonatomic, assign) NSUInteger ftsVersion;
@property (nonatomic, assign) BOOL fromTable;
@property (nonatomic, strong) NSArray<NSString *> *columns;

@end

@implementation VVOrmConfig

+ (BOOL)isFtsTable:(NSString *)tableName database:(VVDatabase *)vvdb
{
    NSString *sql = [NSString stringWithFormat:@"SELECT * FROM sqlite_master WHERE tbl_name = \"%@\" AND type = \"table\"", tableName];
    NSArray *cols = [vvdb query:sql];
    if (cols.count != 1) return NO;
    NSDictionary *dic = cols.firstObject;
    NSString *tableSQL = dic[@"sql"];
    return [tableSQL isMatch:@"CREATE +VIRTUAL +TABLE"];
}

+ (instancetype)configFromTable:(NSString *)tableName
                       database:(VVDatabase *)vvdb
{
    if (![vvdb isExist:tableName]) return nil;
    VVOrmConfig *config = nil;
    BOOL isFtsTable = [self isFtsTable:tableName database:vvdb];
    if (isFtsTable) {
        config = [self configWithFtsTable:tableName database:vvdb];
    } else {
        config = [self configWithNormalTable:tableName database:vvdb];
    }
    return config;
}

//TODO: 可优化
+ (instancetype)configWithNormalTable:(NSString *)tableName database:(VVDatabase *)vvdb
{
    VVOrmConfig *config = [[VVOrmConfig alloc] init];
    config.fromTable = YES;
    
    // 获取表的配置
    NSMutableDictionary *types = [NSMutableDictionary dictionaryWithCapacity:0];
    NSMutableDictionary *defaultValues = [NSMutableDictionary dictionaryWithCapacity:0];
    NSMutableArray *colmuns = [NSMutableArray arrayWithCapacity:0];
    NSMutableArray *primaries = [NSMutableArray arrayWithCapacity:0];
    NSMutableArray *notnulls = [NSMutableArray arrayWithCapacity:0];
    NSMutableArray *uniques = [NSMutableArray arrayWithCapacity:0];
    NSMutableArray *indexes = [NSMutableArray arrayWithCapacity:0];
    
    NSString *tableInfoSql = [NSString stringWithFormat:@"PRAGMA table_info(\"%@\");", tableName];
    NSArray *infos = [vvdb query:tableInfoSql];
    
    for (NSDictionary *dic in infos) {
        NSString *name =  dic[@"name"];
        NSString *type =  dic[@"type"];
        BOOL notnull = [dic[@"notnull"] boolValue];
        id dflt_value =  dic[@"dflt_value"];
        BOOL pk = [dic[@"pk"] integerValue] > 0;
        
        if ([dflt_value isKindOfClass:[NSNull class]]) {
            dflt_value = nil;
        }
        
        [colmuns addObject:name];
        types[name] = type;
        defaultValues[name] = dflt_value;
        if (pk) [primaries addObject:name];
        if (notnull) [notnulls addObject:name];
    }
    
    // 获取表的索引字段
    NSString *indexListSql = [NSString stringWithFormat:@"PRAGMA index_list(\"%@\");", tableName];
    NSArray *indexList =  [vvdb query:indexListSql];
    for (NSDictionary *indexDic in indexList) {
        NSString *indexName =  indexDic[@"name"];
        BOOL unique = [indexDic[@"unique"] boolValue];
        
        NSString *indexInfoSql = [NSString stringWithFormat:@"PRAGMA index_info(\"%@\");", indexName];
        NSArray *indexInfos = [vvdb query:indexInfoSql];
        for (NSDictionary *indexInfo in indexInfos) {
            NSString *name = indexInfo[@"name"];
            if (unique) {
                [uniques addObject:name];
            } else {
                [indexes addObject:name];
            }
        }
    }
    BOOL pkAutoIncrement = NO;
    if (primaries.count == 1) {
        NSString *sql = [NSString stringWithFormat:@"SELECT * FROM sqlite_master WHERE tbl_name = \"%@\" AND type = \"table\"", tableName];
        NSArray *cols = [vvdb query:sql];
        NSDictionary *tableInfo = cols.firstObject;
        NSString *tableSql = tableInfo[@"sql"];
        if ([tableSql isMatch:@"AUTOINCREMENT"]) {
            pkAutoIncrement = YES;
        }
    }
    
    config.pkAutoIncrement = pkAutoIncrement;
    config.columns = colmuns;
    config.primaries = primaries.copy;
    config.notnulls = notnulls.copy;
    config.uniques = uniques.copy;
    config.indexes = indexes.copy;
    config.types = types.copy;
    config.defaultValues = defaultValues.copy;
    
    config.logAt = [colmuns containsObject:kVVCreateAt] && [colmuns containsObject:kVVUpdateAt];
    return config;
}

//TODO: 可优化
+ (instancetype)configWithFtsTable:(NSString *)tableName database:(VVDatabase *)vvdb
{
    NSString *sql = [NSString stringWithFormat:@"SELECT * FROM sqlite_master WHERE tbl_name = \"%@\" AND type = \"table\"", tableName];
    NSArray *cols = [vvdb query:sql];
    if (cols.count != 1) return nil;
    
    VVOrmConfig *config = [[VVOrmConfig alloc] init];
    config.fromTable = YES;
    config.fts = YES;
    
    NSDictionary *dic = cols.firstObject;
    NSString *tableSQL = dic[@"sql"];
    
    // 获取fts模块名/版本号
    NSInteger ftsVersion = 3;
    NSString *ftsModule = @"fts3";
    NSStringCompareOptions options = NSRegularExpressionSearch | NSCaseInsensitiveSearch;
    NSRange range = [tableSQL rangeOfString:@" +fts.*\\(" options:options];
    if (range.location != NSNotFound) {
        ftsModule = [tableSQL substringWithRange:NSMakeRange(range.location, range.length - 1)].trim;
        ftsVersion = [[ftsModule substringWithRange:NSMakeRange(3, 1)] integerValue];
    }
    config.ftsVersion = ftsVersion;
    config.ftsModule = ftsModule;
    
    // 获取FTS分词器
    range = [tableSQL rangeOfString:@"\\(.*\\)" options:options];
    if (range.location == NSNotFound) return nil;
    NSString *ftsOptionsString = [tableSQL substringWithRange:range];
    NSArray *ftsOptions = [ftsOptionsString componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@",)"]];
    for (NSString *optionStr in ftsOptions) {
        if ([optionStr isMatch:@"tokenize *=.*"]) {
            range = [optionStr rangeOfString:@"=.*" options:options];
            NSString *tokenizer = [optionStr substringWithRange:NSMakeRange(range.location + 1, range.length - 1)].trim;
            config.ftsTokenizer = [tokenizer stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"'\""]];
            break;
        }
    }
    
    // 获取表的配置
    NSMutableArray *colmuns = [NSMutableArray arrayWithCapacity:0];
    NSMutableArray *indexes = [NSMutableArray arrayWithCapacity:0];
    
    NSString *tableInfoSql = [NSString stringWithFormat:@"PRAGMA table_info(\"%@\");", tableName];
    NSArray *infos = [vvdb query:tableInfoSql];
    
    for (NSDictionary *dic in infos) {
        NSString *name = dic[@"name"];
        NSString *regex = ftsVersion == 5 ? [NSString stringWithFormat:@"\"%@\" +UNINDEXED", name] : [NSString stringWithFormat:@"notindexed *= *\"%@\"", name];
        if (![tableSQL isMatch:regex]) {
            [indexes addObject:name];
        }
        [colmuns addObject:name];
    }
    config.indexes = indexes;
    config.columns = colmuns;
    return config;
}

+ (instancetype)configWithClass:(Class)cls
{
    if (!cls) return nil;
    VVOrmConfig *config = [[VVOrmConfig alloc] init];
    config.cls = cls;
    
    NSMutableDictionary *types = [NSMutableDictionary dictionaryWithCapacity:0];
    VVClassInfo *classInfo = [VVClassInfo classInfoWithClass:cls];
    [classInfo.propertyInfos enumerateKeysAndObjectsUsingBlock:^(NSString *name, VVPropertyInfo *propertyInfo, BOOL *stop) {
        types[name] = [propertyInfo sqlType];
    }];
    config.columns = classInfo.propertyInfos.allKeys.copy;
    config.types = types;
    return config;
}

+ (instancetype)ftsConfigWithClass:(Class)cls
                            module:(NSString *)module
                         tokenizer:(NSString *)tokenizer
                           indexes:(NSArray<NSString *> *)indexes
{
    VVOrmConfig *config = [VVOrmConfig configWithClass:cls];
    config.fts = YES;
    config.ftsModule = module;
    config.ftsTokenizer = tokenizer;
    config.indexes = indexes;
    return config;
}

//MARK: - setter/geter
- (NSUInteger)ftsVersion
{
    if (_ftsVersion <= 3) {
        _ftsVersion = 3;
        if ([self.ftsModule isMatch:@"fts4"]) _ftsVersion = 4;
        if ([self.ftsModule isMatch:@"fts5"]) _ftsVersion = 5;
    }
    return _ftsVersion;
}

- (NSString *)ftsModule
{
    if (!_ftsModule) {
        _ftsModule = @"fts5";
    }
    return _ftsModule;
}

//MAKR: - public
- (void)dispose
{
    _columns = [_columns vv_distinctUnionOfObjects];
    _indexes = [_indexes vv_distinctUnionOfObjects];
    _uniques = [_uniques vv_distinctUnionOfObjects];
    _notnulls = [_notnulls vv_distinctUnionOfObjects];
    _primaries = [_primaries vv_distinctUnionOfObjects];
    _notnulls = [_notnulls vv_removeObjectsInArray:_primaries];
    _indexes = [_indexes vv_removeObjectsInArray:_uniques];
    
    if (_whiteList.count > 0) {
        _columns = [_whiteList vv_removeObjectsInArray:_columns];
        _indexes = [_whiteList vv_removeObjectsInArray:_indexes];
        _uniques = [_whiteList vv_removeObjectsInArray:_uniques];
        _notnulls = [_whiteList vv_removeObjectsInArray:_notnulls];
        _primaries = [_whiteList vv_removeObjectsInArray:_primaries];
        
        NSArray *typeTrash = [_types.allKeys vv_removeObjectsInArray:_columns];
        _types = [_types vv_removeObjectsForKeys:typeTrash];
        
        NSArray *dfltTrash = [_defaultValues.allKeys vv_removeObjectsInArray:_columns];
        _defaultValues = [_defaultValues vv_removeObjectsForKeys:dfltTrash];
    } else if (_blackList.count > 0) {
        _columns = [_columns vv_removeObjectsInArray:_blackList];
        _indexes = [_indexes vv_removeObjectsInArray:_blackList];
        _uniques = [_uniques vv_removeObjectsInArray:_blackList];
        _notnulls = [_notnulls vv_removeObjectsInArray:_blackList];
        _primaries = [_primaries vv_removeObjectsInArray:_blackList];
        _types = [_types vv_removeObjectsForKeys:_blackList];
        _defaultValues = [_defaultValues vv_removeObjectsForKeys:_blackList];
    }
}

- (BOOL)isEqualToConfig:(VVOrmConfig *)config
{
    NSAssert(self.fts == config.fts, @"FTS and normal config cannot be compared with each other");
    [self dispose];
    [config dispose];
    if (self.fts) {
        BOOL ret1 = [VVOrmConfig ormString:self.ftsModule.lowercaseString isEqual:config.ftsModule.lowercaseString];
        BOOL ret2 = [VVOrmConfig ormString:self.ftsTokenizer isEqual:config.ftsTokenizer];
        BOOL ret3 = [VVOrmConfig ormArray:self.columns isEqual:config.columns];
        BOOL ret4 = self.ftsVersion == 3 && config.ftsVersion == 3;
        if (!ret4) {
            ret4 = [VVOrmConfig ormArray:self.indexes isEqual:config.indexes];
        }
        return ret1 && ret2 && ret3 && ret4;
    } else {
        BOOL ret1 = self.pkAutoIncrement == config.pkAutoIncrement;
        BOOL ret2 = [VVOrmConfig ormArray:self.columns isEqual:config.columns];
        BOOL ret3 = [VVOrmConfig ormDictionary:self.types isEqual:config.types];
        BOOL ret4 = [VVOrmConfig ormArray:self.primaries isEqual:config.primaries];
        BOOL ret5 = [VVOrmConfig ormArray:self.notnulls isEqual:config.notnulls];
        BOOL ret6 = [VVOrmConfig ormDictionary:self.defaultValues isEqual:config.defaultValues];
        return ret1 && ret2 && ret3 && ret4 && ret5 && ret6;
    }
}

- (BOOL)isInedexesEqual:(VVOrmConfig *)config
{
    BOOL ret1 = [VVOrmConfig ormArray:self.uniques isEqual:config.uniques];
    BOOL ret2 = [VVOrmConfig ormArray:self.indexes isEqual:config.indexes];
    return ret1 && ret2;
}

- (NSString *)createSQLOfColumn:(NSString *)column
{
    NSString *typeString = _types[column];
    NSString *pkString = @"";
    if (_primaries.count == 1 && [_primaries containsObject:column]) {
        pkString = _pkAutoIncrement ? @" NOT NULL PRIMARY KEY AUTOINCREMENT" : @" NOT NULL PRIMARY KEY";
    }
    
    NSString *nullString = [_notnulls containsObject:column] ? @" NOT NULL" : @"";
    NSString *uniqueString = [_uniques containsObject:column] ? @" UNIQUE" : @"";
    id defaultValue = _defaultValues[column];
    NSString *dfltString = defaultValue ? [NSString stringWithFormat:@" DEFAULT(%@)", defaultValue] : @"";
    return [NSString stringWithFormat:@"\"%@\" %@%@%@%@%@", column, typeString, pkString, nullString, uniqueString, dfltString];
}

- (NSString *)createSQLWith:(NSString *)tableName
{
    [self dispose];
    NSMutableString *sql = [NSMutableString stringWithCapacity:0];
    for (NSString *column in _columns) {
        [sql appendFormat:@"%@,", [self createSQLOfColumn:column]];
    }
    if (sql.length == 0) return sql;
    [sql deleteCharactersInRange:NSMakeRange(sql.length - 1, 1)];
    return [NSString stringWithFormat:@"CREATE TABLE IF NOT EXISTS \"%@\" (%@)", tableName, sql].strip;
}

- (NSString *)createFtsSQLWith:(NSString *)tableName
{
    [self dispose];
    NSArray *notindexeds = [_columns vv_removeObjectsInArray:_indexes];
    NSMutableString *sql = [NSMutableString stringWithCapacity:0];
    for (NSString *column in _columns) {
        [sql appendFormat:@", \"%@\"", column];
        if ([notindexeds containsObject:column] && self.ftsVersion == 5) {
            [sql appendString:@" UNINDEXED"];
        }
    }
    if (self.ftsVersion == 4 && notindexeds.count > 0) {
        for (NSString *column in notindexeds) {
            [sql appendFormat:@", notindexed=\"%@\"", column];
        }
    }
    if (sql.length < 2) return @"";
    [sql deleteCharactersInRange:NSMakeRange(0, 2)];
    NSString *format = self.ftsVersion < 5 ? @", tokenize=%@" : @", tokenize='%@'";
    NSString *tokenize = _ftsTokenizer.length > 0 ? [NSString stringWithFormat:format, _ftsTokenizer] : @"";
    return [NSString stringWithFormat:@"CREATE VIRTUAL TABLE IF NOT EXISTS \"%@\" USING %@(%@ %@)",
            tableName, self.ftsModule, sql, tokenize].strip;
}

// MARK: - Utils

+ (BOOL)ormArray:(NSArray *)array isEqual:(NSArray *)otherArray
{
    if (array.count == 0 && otherArray.count == 0) {
        return YES;
    }
    NSSet *set1 = [NSSet setWithArray:array];
    NSSet *set2 = [NSSet setWithArray:otherArray];
    BOOL ret =  [set1 isEqualToSet:set2];
    return ret;
}

+ (BOOL)ormDictionary:(NSDictionary *)dictionary isEqual:(NSDictionary *)otherDictionary
{
    if (dictionary.count == 0 && otherDictionary.count == 0) {
        return YES;
    }
    return [dictionary isEqualToDictionary:otherDictionary];
}

+ (BOOL)ormString:(NSString *)string isEqual:(NSString *)otherString
{
    if (string.length == 0 && otherString.length == 0) {
        return YES;
    }
    static NSCharacterSet *_charset = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _charset = [NSCharacterSet characterSetWithCharactersInString:@"\"'"];
    });
    
    NSString *str = [string stringByTrimmingCharactersInSet:_charset].strip;
    NSString *other = [otherString stringByTrimmingCharactersInSet:_charset].strip;
    return [str isEqualToString:other];
}

@end
