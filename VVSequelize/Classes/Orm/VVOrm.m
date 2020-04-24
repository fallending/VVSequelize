//
//  VVOrm.m
//  VVSequelize
//
//  Created by Valo on 2018/6/6.
//

#import "VVOrm.h"
#import "NSObject+VVOrm.h"

#define VV_NO_WARNING(exp) if (exp) {}

@implementation VVOrm

//MARK: - Public
+ (nullable instancetype)ormWithConfig:(VVOrmConfig *)config
{
    return [self ormWithConfig:config name:nil database:nil];
}

+ (nullable instancetype)ormWithConfig:(VVOrmConfig *)config
                                  name:(nullable NSString *)name
                              database:(nullable VVDatabase *)vvdb
{
    VVOrm *orm = [[VVOrm alloc] initWithConfig:config name:name database:vvdb];
    VVOrmInspection comparison = [orm inspectExistingTable];
    [orm setupTableWith:comparison];
    return orm;
}

- (nullable instancetype)initWithConfig:(VVOrmConfig *)config
                                   name:(nullable NSString *)name
                               database:(nullable VVDatabase *)vvdb
{
    BOOL valid = config && config.cls && config.columns.count > 0;
    NSAssert(valid, @"Invalid orm config.");
    if (!valid) return nil;
    self = [super init];
    if (self) {
        NSString *tblName = name.length > 0 ? name : NSStringFromClass(config.cls);
        VVDatabase *db = vvdb ? vvdb : [VVDatabase databaseWithPath:nil];
        _config = config;
        _name = tblName;
        _vvdb = db;
    }
    return self;
}

- (nullable NSDictionary *)uniqueConditionForObject:(id)object
{
    if (_config.primaries.count > 0) {
        NSMutableDictionary *dic = [NSMutableDictionary dictionaryWithCapacity:0];
        for (NSString *key in _config.primaries) {
            id val = [object valueForKey:key];
            dic[key] = val;
        }
        if (dic.count == _config.primaries.count) {
            return dic;
        }
    }
    for (NSString *key in _config.uniques) {
        id val = [object valueForKey:key];
        if (val) return @{ key: val };
    }
    return nil;
}

- (VVOrmInspection)inspectExistingTable
{
    VVOrmInspection inspection = 0x0;
    VVOrmConfig *tableConfig = [VVOrmConfig configFromTable:_name database:_vvdb];
    // check if table exists
    BOOL ret = [_vvdb isExist:_name];
    if (!ret) return inspection;
    inspection |= VVOrmTableExist;
    // check table and indexes for updates
    ret = [_config isEqualToConfig:tableConfig];
    if (!ret) inspection |= VVOrmTableChanged;
    ret = [_config isInedexesEqual:tableConfig];
    if (!ret) inspection |= VVOrmIndexChanged;
    return inspection;
}

- (void)setupTableWith:(VVOrmInspection)inspection
{
    // if table exists, check for updates. if need, rename original table
    NSString *tempTableName = [NSString stringWithFormat:@"%@_%@", _name, @((NSUInteger)[[NSDate date] timeIntervalSince1970])];
    BOOL exist = inspection & VVOrmTableExist;
    BOOL changed = inspection & VVOrmTableChanged;
    BOOL indexChanged = inspection & VVOrmIndexChanged;
    // rename original table
    if (exist && changed) {
        [self renameToTempTable:tempTableName];
    }
    // create new table
    if (!exist || changed) {
        [self createTable];
    }
    // migrate data to new table
    if (exist && changed && !_config.fts) {
        //MARK: FTS table must migrate data manually
        [self migrationDataFormTempTable:tempTableName];
    }
    // rebuild indexes
    if (indexChanged || !exist) {
        [self rebuildIndex];
    }
}

- (void)createTable
{
    NSString *sql = nil;
    // create fts table
    if (_config.fts) {
        sql = [_config createFtsSQLWith:_name];
    }
    // create nomarl table
    else {
        sql = [_config createSQLWith:_name];
    }
    // execute create sql
    BOOL ret = [self.vvdb run:sql];
    VV_NO_WARNING(ret);
    NSAssert1(ret, @"Failure to create a table: %@", _name);
}

- (void)renameToTempTable:(NSString *)tempTableName
{
    NSString *sql = [NSString stringWithFormat:@"ALTER TABLE %@ RENAME TO %@", _name.quoted, tempTableName.quoted];
    BOOL ret = [self.vvdb run:sql];
    VV_NO_WARNING(ret);
    NSAssert1(ret, @"Failure to create a temporary table: %@", tempTableName);
}

//MARK: - Private
- (void)migrationDataFormTempTable:(NSString *)tempTableName
{
    NSString *allFields = [_config.columns sqlJoin];
    if (allFields.length == 0) {
        return;
    }
    NSString *sql = [NSString stringWithFormat:@"INSERT INTO %@ (%@) SELECT %@ FROM %@", self.name.quoted, allFields, allFields, tempTableName.quoted];
    __block BOOL ret = YES;
    [self.vvdb transaction:VVDBTransactionDeferred block:^BOOL {
        ret = [self.vvdb run:sql];
        return ret;
    }];

    if (ret) {
        sql = [NSString stringWithFormat:@"DROP TABLE IF EXISTS %@", tempTableName.quoted];
        ret = [self.vvdb run:sql];
    }

    if (!ret) {
#if DEBUG
        NSLog(@"Warning: copying data from old table (%@) to new table (%@) failed!", tempTableName, self.name);
#endif
    }
}

- (void)rebuildIndex
{
    /// fts table do not need this indexes
    if (_config.fts) return;
    NSString *indexesSQL = [NSString stringWithFormat:@"SELECT name FROM sqlite_master WHERE type ='index' and tbl_name = %@", _name.quoted];
    NSArray *array = [_vvdb query:indexesSQL];
    NSMutableString *dropIdxSQL = [NSMutableString stringWithCapacity:0];
    for (NSDictionary *dic  in array) {
        NSString *idxName = dic[@"name"];
        if ([idxName hasPrefix:@"sqlite_autoindex_"]) continue;
        [dropIdxSQL appendFormat:@"DROP INDEX IF EXISTS %@;", idxName.quoted];
    }

    if (self.config.indexes.count == 0) return;

    // create new indexes
    NSString *indexName = [NSString stringWithFormat:@"vvdb_index_%@", _name];
    NSString *indexSQL = [_config.indexes sqlJoin];
    NSString *createIdxSQL = nil;
    if (indexSQL.length > 0) {
        createIdxSQL = [NSString stringWithFormat:@"CREATE INDEX IF NOT EXISTS %@ on %@ (%@);", indexName.quoted, _name.quoted, indexSQL];
    }
    BOOL ret = YES;
    if (dropIdxSQL.length > 0) {
        ret = [self.vvdb run:dropIdxSQL];
    }
    if (ret && createIdxSQL.length > 0) {
        ret = [self.vvdb run:createIdxSQL];
    }

    if (!ret) {
#if DEBUG
        NSLog(@"Warning: Failed create index for table (%@)!", self.name);
#endif
    }
}

@end
