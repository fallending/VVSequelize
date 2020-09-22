//
//  VVOrm.m
//  VVSequelize
//
//  Created by Valo on 2018/6/6.
//

#import "VVOrm.h"
#import "NSObject+VVOrm.h"

#define VV_NO_WARNING(exp) if (exp) {}

typedef NS_OPTIONS (NSUInteger, VVOrmInspection) {
    VVOrmTableExist   = 1 << 0,
    VVOrmTableChanged = 1 << 1,
    VVOrmIndexChanged = 1 << 2,
};

@interface VVOrm ()
@property (nonatomic, assign) BOOL created;
@property (nonatomic, copy) NSString *content_table;
@property (nonatomic, copy) NSString *content_rowid;
@property (nonatomic, strong) NSArray<NSString *> *existingIndexes;
@end

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
    return [self ormWithConfig:config name:name database:vvdb setup:VVOrmSetupCreate];
}

+ (nullable instancetype)ormWithConfig:(VVOrmConfig *)config
                                  name:(nullable NSString *)name
                              database:(nullable VVDatabase *)vvdb
                                 setup:(VVOrmSetup)setup
{
    VVOrm *orm = [vvdb.orms objectForKey:name];
    if (orm) return orm;

    orm = [[VVOrm alloc] initWithConfig:config name:name database:vvdb];
    if (setup == VVOrmSetupCreate) [orm createTableAndIndexes];
    else if (setup == VVOrmSetupRebuild) [orm rebuildTableAndIndexes];
    [vvdb.orms setObject:orm forKey:name];
    return orm;
}

+ (nullable instancetype)ormWithConfig:(VVOrmConfig *)config
                                  name:(nullable NSString *)name
                              database:(nullable VVDatabase *)vvdb
                         content_table:(nullable NSString *)content_table
                         content_rowid:(nullable NSString *)content_rowid
                                 setup:(VVOrmSetup)setup
{
    VVOrm *orm = [vvdb.orms objectForKey:name];
    if (orm) return orm;

    orm = [[VVOrm alloc] initWithConfig:config name:name database:vvdb];
    orm.content_table = content_table;
    orm.content_rowid = content_rowid;
    if (setup == VVOrmSetupCreate) [orm createTableAndIndexes];
    else if (setup == VVOrmSetupRebuild) [orm rebuildTableAndIndexes];
    [vvdb.orms setObject:orm forKey:name];
    return orm;
}

+ (nullable instancetype)ormWithConfig:(VVOrmConfig *)config
                              relative:(VVOrm *)relativeORM
                         content_rowid:(nullable NSString *)content_rowid
{
    NSString *fts_table = [NSString stringWithFormat:@"fts_%@", relativeORM.name];
    VVOrm *orm = [relativeORM.vvdb.orms objectForKey:fts_table];
    if (orm) return orm;

    config.blackList = config.blackList ? [config.blackList arrayByAddingObject:content_rowid] : @[content_rowid];
    [config treate];
    VVOrmConfig *cfg = relativeORM.config;
    NSSet *cfgColsSet = [NSSet setWithArray:cfg.columns];
    NSSet *colsSet = [NSSet setWithArray:config.columns];
    BOOL valid = (config.fts && !cfg.fts) &&
        ((cfg.primaries.count == 1 && [cfg.primaries.firstObject isEqualToString:content_rowid]) ||
         [cfg.uniques containsObject:content_rowid]) &&
        [colsSet isSubsetOfSet:cfgColsSet] &&
        [cfg.columns containsObject:content_rowid];
    if (!valid) {
        NSAssert(NO, @"The following conditions must be met:\n"
                 "1. The relative ORM is the universal ORM\n"
                 "2. The relative ORM has uniqueness constraints\n"
                 "3. The relative ORM contains all fields of this ORM\n"
                 "4. The relative ORM contains the content_rowid\n");
    }

    orm = [[VVOrm alloc] initWithConfig:config name:fts_table database:relativeORM.vvdb];
    orm.content_table = relativeORM.name;
    orm.content_rowid = content_rowid;

    if (!relativeORM.created) [relativeORM rebuildTableAndIndexes];
    [orm rebuildTableAndIndexes];

    NSArray * (^ map)(NSArray<NSString *> *, NSString *) = ^(NSArray<NSString *> *array, NSString *prefix) {
        NSMutableArray *results = [NSMutableArray arrayWithCapacity:array.count];
        for (NSString *string in array) {
            [results addObject:[NSString stringWithFormat:@"%@.%@", prefix, string]];
        }
        return results.copy;
    };

    NSString *ins_rows = [[@[@"rowid"] arrayByAddingObjectsFromArray:config.columns] componentsJoinedByString:@","];
    NSString *ins_vals = [map([@[content_rowid] arrayByAddingObjectsFromArray:config.columns], @"new") componentsJoinedByString:@","];
    NSString *del_rows = [[@[fts_table, @"rowid"] arrayByAddingObjectsFromArray:config.columns] componentsJoinedByString:@","];
    NSString *del_vals = [[@[@"'delete'"] arrayByAddingObjectsFromArray:map([@[content_rowid] arrayByAddingObjectsFromArray:config.columns], @"old")] componentsJoinedByString:@","];

    NSString *ins_tri_name = [fts_table stringByAppendingString:@"_insert"];
    NSString *del_tri_name = [fts_table stringByAppendingString:@"_delete"];
    NSString *upd_tri_name = [fts_table stringByAppendingString:@"_update"];

    NSString *ins_trigger = [NSString stringWithFormat:@""
                             "CREATE TRIGGER IF NOT EXISTS %@ AFTER INSERT ON %@ BEGIN \n"
                             "INSERT INTO %@ (%@) VALUES (%@); \n"
                             "END;",
                             ins_tri_name, relativeORM.name,
                             fts_table, ins_rows, ins_vals];
    NSString *del_trigger = [NSString stringWithFormat:@""
                             "CREATE TRIGGER IF NOT EXISTS %@ AFTER DELETE ON %@ BEGIN \n"
                             "INSERT INTO %@ (%@) VALUES (%@); \n"
                             "END;",
                             del_tri_name, relativeORM.name,
                             fts_table, del_rows, del_vals];
    NSString *upd_trigger = [NSString stringWithFormat:@""
                             "CREATE TRIGGER IF NOT EXISTS %@ AFTER UPDATE ON %@ BEGIN \n"
                             "INSERT INTO %@ (%@) VALUES (%@); \n"
                             "INSERT INTO %@ (%@) VALUES (%@); \n"
                             "END;",
                             upd_tri_name, relativeORM.name,
                             fts_table, del_rows, del_vals,
                             fts_table, ins_rows, ins_vals];

    [relativeORM.vvdb run:ins_trigger];
    [relativeORM.vvdb run:del_trigger];
    [relativeORM.vvdb run:upd_trigger];

    [relativeORM.vvdb.orms setObject:orm forKey:fts_table];
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

- (BOOL)createTableAndIndexes
{
    if (_created) return YES;
    [_config treate];
    BOOL ret = [self createTable];
    if (ret) _created = YES;
    if (!ret || _config.fts || _config.indexes.count == 0) return ret;
    NSString *indexName = [NSString stringWithFormat:@"vvdb_index_%@", _name];
    BOOL exist = [self.existingIndexes containsObject:indexName];
    if (!exist) {
        ret = [self createIndexes];
    }
    return ret;
}

- (BOOL)createTable
{
    if ([self.vvdb isExist:_name]) {
        return YES;
    }
    NSString *sql = nil;
    // create fts table
    if (_config.fts) {
        sql = [_config createFtsSQLWith:_name content_table:_content_table content_rowid:_content_rowid];
    }
    // create nomarl table
    else {
        sql = [_config createSQLWith:_name];
    }
    // execute create sql
    BOOL ret = [self.vvdb run:sql];
    //NSAssert1(ret, @"Failure to create a table: %@", _name);
    return ret;
}

- (BOOL)createIndexes
{
    _existingIndexes = nil;

    /// fts table do not need this indexes
    if (_config.fts || _config.indexes.count == 0) return YES;

    // create new indexes
    NSString *indexName = [NSString stringWithFormat:@"vvdb_index_%@", _name];

    NSString *indexSQL = [_config.indexes sqlJoin];
    NSString *createIdxSQL = [NSString stringWithFormat:@"CREATE INDEX IF NOT EXISTS %@ on %@ (%@);", indexName.quoted, _name.quoted, indexSQL];
    BOOL ret = [self.vvdb run:createIdxSQL];
    if (!ret) {
#if DEBUG
        printf("[VVDB][WARN] Failed create index for table (%s)!", self.name.UTF8String);
#endif
    }
    return ret;
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

- (void)rebuildTableAndIndexes {
    _created = NO;
    VVOrmInspection comparison = [self inspectExistingTable];
    BOOL ret = [self setupTableWith:comparison];
    if (ret) _created = YES;
}

- (VVOrmInspection)inspectExistingTable
{
    VVOrmInspection inspection = 0x0;
    VVOrmConfig *tableConfig = [VVOrmConfig configFromTable:_name database:self.vvdb];
    // check if table exists
    if (!tableConfig) return inspection;
    inspection |= VVOrmTableExist;
    // check table and indexes for updates
    BOOL ret = [_config isEqualToConfig:tableConfig];
    if (!ret) inspection |= VVOrmTableChanged;
    ret = [_config isInedexesEqual:tableConfig];
    if (!ret) inspection |= VVOrmIndexChanged;
    return inspection;
}

- (BOOL)setupTableWith:(VVOrmInspection)inspection
{
    // if table exists, check for updates. if need, rename original table
    NSString *tempTableName = [NSString stringWithFormat:@"%@_%@", _name, @((NSUInteger)[[NSDate date] timeIntervalSince1970])];
    BOOL exist = inspection & VVOrmTableExist;
    BOOL changed = inspection & VVOrmTableChanged;
    BOOL indexChanged = inspection & VVOrmIndexChanged;
    BOOL ret = YES;
    // rename original table
    if (exist && changed) {
        ret = [self renameToTempTable:tempTableName];
    }
    if (!ret) return ret;
    // create new table
    if (!exist || changed) {
        ret = [self createTable];
    }
    if (!ret) return ret;
    // migrate data to new table
    if (exist && changed && !_config.fts) {
        //MARK: FTS table must migrate data manually
        [self migrationDataFormTempTable:tempTableName];
    }
    // rebuild indexes
    if (indexChanged || !exist) {
        [self rebuildIndex];
    }
    return ret;
}

- (BOOL)renameToTempTable:(NSString *)tempTableName
{
    NSString *sql = [NSString stringWithFormat:@"ALTER TABLE %@ RENAME TO %@", _name.quoted, tempTableName.quoted];
    BOOL ret = [self.vvdb run:sql];
    //NSAssert1(ret, @"Failure to create a temporary table: %@", tempTableName);
    return ret;
}

//MARK: - getter

- (NSArray<NSString *> *)existingIndexes
{
    if (!_existingIndexes) {
        NSString *sql = [NSString stringWithFormat:@"PRAGMA index_list = %@;", _name];
        NSArray *indexes =  [self.vvdb query:sql];
        NSMutableArray *results = [NSMutableArray arrayWithCapacity:indexes.count];
        for (NSDictionary *dic in indexes) {
            NSString *index = dic[@"name"];
            if (index) [results addObject:index];
        }
        _existingIndexes = results;
    }
    return _existingIndexes;
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
        printf("[VVDB][WARN] copying data from old table (%s) to new table (%s) failed!", tempTableName.UTF8String, self.name.UTF8String);
#endif
    }
}

- (BOOL)dropOldIndexes {
    if (self.existingIndexes.count == 0) return YES;

    NSMutableString *dropIdxSQL = [NSMutableString stringWithCapacity:0];
    for (NSDictionary *dic in self.existingIndexes) {
        NSString *idxName = dic[@"name"];
        if ([idxName hasPrefix:@"sqlite_autoindex_"]) continue;
        [dropIdxSQL appendFormat:@"DROP INDEX IF EXISTS %@;", idxName.quoted];
    }
    BOOL ret = [self.vvdb run:dropIdxSQL];
    return ret;
}

- (void)rebuildIndex
{
    /// fts table do not need this indexes
    if (_config.fts || _config.indexes.count == 0) return;

    /// drop old indexes
    BOOL ret1 = [self dropOldIndexes];
    BOOL ret2 = [self createIndexes];
    if (ret2) _existingIndexes = nil;

    if (!ret1) {
#if DEBUG
        printf("[VVDB][WARN] Failed create index for table (%s)!", self.name.UTF8String);
#endif
    }

    if (!ret2) {
#if DEBUG
        printf("[VVDB][WARN] Failed create index for table (%s)!", self.name.UTF8String);
#endif
    }
}

@end
