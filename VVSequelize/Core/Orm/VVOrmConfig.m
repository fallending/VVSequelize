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
NSString *const VVSqlTypeJson = @"JSON";

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
                case VVEncodingTypeNSString:
                case VVEncodingTypeNSMutableString:
                    type = VVSqlTypeText;
                    break;
                case VVEncodingTypeNSNumber:
                case VVEncodingTypeNSDecimalNumber:
                    type = VVSqlTypeReal;
                    break;
                case VVEncodingTypeNSData:
                case VVEncodingTypeNSMutableData:
                    type = VVSqlTypeBlob;
                    break;
                default:
                    type = VVSqlTypeJson;
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
@property (nonatomic, strong) NSArray<NSString *> *allColumns;
@property (nonatomic, strong) NSDictionary<NSString *, NSString *> *allTypes;
@property (nonatomic, strong) NSDictionary<NSString *, id> *allDefaultValues;
@end

@implementation VVOrmConfig

+ (BOOL)isFtsTable:(NSString *)tableName database:(VVDatabase *)vvdb
{
    NSString *sql = [NSString stringWithFormat:@"SELECT * FROM sqlite_master WHERE tbl_name = %@ AND type = \"table\"", tableName.quoted];
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

//TODO: optimizable
+ (instancetype)configWithNormalTable:(NSString *)tableName database:(VVDatabase *)vvdb
{
    VVOrmConfig *config = [[VVOrmConfig alloc] init];
    config.fromTable = YES;

    // get table configuration
    NSMutableDictionary *types = [NSMutableDictionary dictionaryWithCapacity:0];
    NSMutableDictionary *defaultValues = [NSMutableDictionary dictionaryWithCapacity:0];
    NSMutableArray *colmuns = [NSMutableArray arrayWithCapacity:0];
    NSMutableArray *primaries = [NSMutableArray arrayWithCapacity:0];
    NSMutableArray *notnulls = [NSMutableArray arrayWithCapacity:0];
    NSMutableArray *uniques = [NSMutableArray arrayWithCapacity:0];
    NSMutableArray *indexes = [NSMutableArray arrayWithCapacity:0];

    NSString *tableInfoSql = [NSString stringWithFormat:@"PRAGMA table_info = %@;", tableName.quoted];
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

    // get indexes
    NSString *indexListSql = [NSString stringWithFormat:@"PRAGMA index_list = %@;", tableName.quoted];
    NSArray *indexList =  [vvdb query:indexListSql];
    for (NSDictionary *indexDic in indexList) {
        NSString *indexName =  indexDic[@"name"];
        BOOL unique = [indexDic[@"unique"] boolValue];

        NSString *indexInfoSql = [NSString stringWithFormat:@"PRAGMA index_info = %@;", indexName.quoted];
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
        NSString *sql = [NSString stringWithFormat:@"SELECT * FROM sqlite_master WHERE tbl_name = %@ AND type = \"table\"", tableName.quoted];
        NSArray *cols = [vvdb query:sql];
        NSDictionary *tableInfo = cols.firstObject;
        NSString *tableSql = tableInfo[@"sql"];
        if ([tableSql isMatch:@"AUTOINCREMENT"]) {
            pkAutoIncrement = YES;
        }
    }

    config.pkAutoIncrement = pkAutoIncrement;
    config.columns = colmuns.copy;
    config.primaries = primaries.copy;
    config.notnulls = notnulls.copy;
    config.uniques = uniques.copy;
    config.indexes = indexes.copy;
    config.types = types.copy;
    config.defaultValues = defaultValues.copy;

    config.logAt = [colmuns containsObject:kVVCreateAt] && [colmuns containsObject:kVVUpdateAt];
    return config;
}

//TODO: optimizable
+ (instancetype)configWithFtsTable:(NSString *)tableName database:(VVDatabase *)vvdb
{
    NSString *sql = [NSString stringWithFormat:@"SELECT * FROM sqlite_master WHERE tbl_name = %@ AND type = \"table\"", tableName.quoted];
    NSArray *cols = [vvdb query:sql];
    if (cols.count != 1) return nil;

    VVOrmConfig *config = [[VVOrmConfig alloc] init];
    config.fromTable = YES;
    config.fts = YES;

    NSDictionary *dic = cols.firstObject;
    NSString *tableSQL = dic[@"sql"];

    // get fts module/version
    NSInteger ftsVersion = 3;
    NSString *ftsModule = @"fts3";
    NSStringCompareOptions options = NSRegularExpressionSearch | NSCaseInsensitiveSearch;
    NSRange range = [tableSQL rangeOfString:@" +fts.*\\(" options:options];
    if (range.location != NSNotFound) {
        ftsModule = [tableSQL substringWithRange:NSMakeRange(range.location, range.length - 1)].vv_trim;
        ftsVersion = [[ftsModule substringWithRange:NSMakeRange(3, 1)] integerValue];
    }
    config.ftsVersion = ftsVersion;
    config.ftsModule = ftsModule;

    // get tokenizer
    range = [tableSQL rangeOfString:@"\\(.*\\)" options:options];
    if (range.location == NSNotFound) return nil;
    NSString *ftsOptionsString = [tableSQL substringWithRange:range];
    NSArray *ftsOptions = [ftsOptionsString componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@",)"]];
    for (NSString *optionStr in ftsOptions) {
        if ([optionStr isMatch:@"tokenize *=.*"]) {
            range = [optionStr rangeOfString:@"=.*" options:options];
            NSString *tokenizer = [optionStr substringWithRange:NSMakeRange(range.location + 1, range.length - 1)].vv_trim;
            config.ftsTokenizer = [tokenizer stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"'\""]];
            break;
        }
    }

    // get table configuration
    NSMutableArray *colmuns = [NSMutableArray arrayWithCapacity:0];
    NSMutableArray *indexes = [NSMutableArray arrayWithCapacity:0];

    NSString *tableInfoSql = [NSString stringWithFormat:@"PRAGMA table_info = %@;", tableName.quoted];
    NSArray *infos = [vvdb query:tableInfoSql];

    for (NSDictionary *info in infos) {
        NSString *name = info[@"name"];
        NSString *regex = ftsVersion == 5 ? [NSString stringWithFormat:@"%@ +UNINDEXED", name.quoted] : [NSString stringWithFormat:@"notindexed *= *%@", name.quoted];
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

    VVClassInfo *classInfo = [VVClassInfo classInfoWithClass:cls];
    NSMutableDictionary *types = [NSMutableDictionary dictionaryWithCapacity:classInfo.properties.count];
    NSMutableArray *columns = [NSMutableArray arrayWithCapacity:classInfo.properties.count];
    for (VVPropertyInfo *propertyInfo in classInfo.properties) {
        types[propertyInfo.name] = [propertyInfo sqlType];
        [columns addObject:propertyInfo.name];
    }
    config.columns = columns.copy;
    config.types = types.copy;
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
- (void)setColumns:(NSArray<NSString *> *)columns
{
    _allColumns = columns.copy;
    _columns = columns;
}

- (void)setTypes:(NSDictionary<NSString *, NSString *> *)types {
    _allTypes = types.copy;
    _types = types;
}

- (void)setDefaultValues:(NSDictionary<NSString *, id> *)defaultValues
{
    _allDefaultValues = defaultValues.copy;
    _defaultValues = defaultValues;
}

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
- (void)treate
{
    NSMutableOrderedSet *columnsSet = [NSMutableOrderedSet orderedSetWithArray:(_allColumns ? : @[])];
    NSMutableSet *whitesSet = [NSMutableSet setWithArray:(_whiteList ? : @[])];
    NSMutableSet *blacksSet = [NSMutableSet setWithArray:(_blackList ? : @[])];
    if (whitesSet.count > 0) {
        [columnsSet intersectSet:whitesSet];
    } else if (blacksSet.count > 0) {
        [columnsSet minusSet:blacksSet];
    }
    _columns = columnsSet.array.copy;

    NSSet *rowsSet = [NSSet setWithArray:_columns];
    NSMutableSet *indexesSet = [NSMutableSet setWithArray:(_indexes ? : @[])];
    NSMutableSet *uniquesSet = [NSMutableSet setWithArray:(_uniques ? : @[])];
    NSMutableSet *notnullsSet = [NSMutableSet setWithArray:(_notnulls ? : @[])];
    NSMutableSet *primariesSet = [NSMutableSet setWithArray:(_primaries ? : @[])];
    NSMutableSet *typeTrashKeysSet = [NSMutableSet setWithArray:(_allTypes.allKeys ? : @[])];
    NSMutableSet *defValTrashKeysSet = [NSMutableSet setWithArray:(_allDefaultValues.allKeys ? : @[])];

    [indexesSet intersectSet:rowsSet];
    [uniquesSet intersectSet:rowsSet];
    [notnullsSet intersectSet:rowsSet];
    [primariesSet intersectSet:rowsSet];

    [indexesSet minusSet:uniquesSet];
    [notnullsSet minusSet:primariesSet];
    [uniquesSet minusSet:primariesSet];

    [typeTrashKeysSet minusSet:rowsSet];
    [defValTrashKeysSet minusSet:rowsSet];

    NSMutableOrderedSet *tempSet = [NSMutableOrderedSet orderedSetWithArray:_columns];
    [tempSet intersectSet:primariesSet];
    _primaries = tempSet.array.copy;

    tempSet = [NSMutableOrderedSet orderedSetWithArray:_columns];
    [tempSet intersectSet:indexesSet];
    _indexes = tempSet.array.copy;

    tempSet = [NSMutableOrderedSet orderedSetWithArray:_columns];
    [tempSet intersectSet:uniquesSet];
    _uniques = tempSet.array.copy;

    tempSet = [NSMutableOrderedSet orderedSetWithArray:_columns];
    [tempSet intersectSet:notnullsSet];
    _notnulls = tempSet.array.copy;

    _types = [_allTypes vv_removeObjectsForKeys:typeTrashKeysSet.allObjects];
    _defaultValues = [_allDefaultValues vv_removeObjectsForKeys:defValTrashKeysSet.allObjects];
}

- (BOOL)isEqualToConfig:(VVOrmConfig *)config
{
    NSAssert(self.fts == config.fts, @"FTS and normal config cannot be compared with each other");
    [self treate];
    [config treate];
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

- (NSString *)alertSQLOfColumn:(NSString *)column table:(NSString *)tableName
{
    NSString *columnSQL = [self createSQLOfColumn:column];
    return [NSString stringWithFormat:@"ALTER TABLE %@ ADD COLUMN %@", tableName.quoted, columnSQL];
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
    return [NSString stringWithFormat:@"%@ %@%@%@%@%@", column.quoted, typeString, pkString, nullString, uniqueString, dfltString];
}

- (NSString *)createSQLWith:(NSString *)tableName
{
    [self treate];
    NSMutableArray *array = [NSMutableArray arrayWithCapacity:_columns.count];
    for (NSString *column in _columns) {
        [array addObject:[self createSQLOfColumn:column]];
    }
    if (_primaries.count > 1) {
        NSString *pri = [NSString stringWithFormat:@"PRIMARY KEY (%@)", [_primaries componentsJoinedByString:@","]];
        [array addObject:pri];
    }
    NSString *sql = [array componentsJoinedByString:@","];
    if (sql.length == 0) return @"";
    return [NSString stringWithFormat:@"CREATE TABLE IF NOT EXISTS %@ (%@)", tableName.quoted, sql].vv_strip;
}

- (NSString *)createFtsSQLWith:(NSString *)tableName
                 content_table:(NSString *)content_table
                 content_rowid:(NSString *)content_rowid
{
    if (self.indexes.count == 0) {
        self.indexes = self.columns;
    }
    [self treate];
    NSArray *notindexeds = [_columns vv_removeObjectsInArray:_indexes];

    BOOL fts5 = self.ftsVersion == 5;
    BOOL fts4 = self.ftsVersion == 4;

    NSMutableArray *array = [NSMutableArray arrayWithCapacity:_columns.count];
    for (NSString *column in _columns) {
        BOOL flag = [notindexeds containsObject:column] && fts5;
        NSString *unindexed = flag ? @" UNINDEXED" : @"";
        [array addObject:[column.quoted stringByAppendingString:unindexed]];
    }

    if (fts4 && notindexeds.count > 0) {
        for (NSString *column in notindexeds) {
            NSString *unindexed = [NSString stringWithFormat:@"notindexed=%@", column.quoted];
            [array addObject:unindexed];
        }
    }

    if (array.count == 0) return @"";
    if (_ftsTokenizer.length) {
        NSString *format = self.ftsVersion < 5 ? @"tokenize=%@" : @"tokenize='%@'";
        NSString *tokenize = [NSString stringWithFormat:format, _ftsTokenizer];
        [array addObject:tokenize];
    }
    if (content_table.length) {
        [array addObject:[NSString stringWithFormat:@"content='%@'", content_table]];
        if (content_rowid.length) {
            [array addObject:[NSString stringWithFormat:@"content_rowid='%@'", content_rowid]];
        }
    }

    NSString *sql = [array componentsJoinedByString:@","];
    return [NSString stringWithFormat:@"CREATE VIRTUAL TABLE IF NOT EXISTS %@ USING %@(%@)",
            tableName.quoted, self.ftsModule, sql].vv_strip;
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
    if (dictionary.count != otherDictionary.count) return NO;

    NSMutableDictionary *lhs = [NSMutableDictionary dictionaryWithCapacity:dictionary.count];
    NSMutableDictionary *rhs = [NSMutableDictionary dictionaryWithCapacity:otherDictionary.count];
    [dictionary enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        lhs[key] = [obj description];
    }];
    [otherDictionary enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        rhs[key] = [obj description];
    }];

    return [lhs isEqualToDictionary:rhs];
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

    NSString *str = [string stringByTrimmingCharactersInSet:_charset].vv_strip;
    NSString *other = [otherString stringByTrimmingCharactersInSet:_charset].vv_strip;
    return [str isEqualToString:other];
}

@end
