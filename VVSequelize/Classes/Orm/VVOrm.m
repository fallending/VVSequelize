//
//  VVOrm.m
//  VVSequelize
//
//  Created by Valo on 2018/6/6.
//

#import "VVOrm.h"
#import "NSObject+VVOrm.h"

#define VV_NO_WARNING(exp) if (exp) {}

@interface VVOrm ()
@property (nonatomic, assign) BOOL created;
@property (nonatomic, copy) NSString *content_table;
@property (nonatomic, copy) NSString *content_rowid;
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
    return [self ormWithConfig:config name:name database:vvdb setup:YES];
}

+ (nullable instancetype)ormWithConfig:(VVOrmConfig *)config
                                  name:(nullable NSString *)name
                              database:(nullable VVDatabase *)vvdb
                                 setup:(BOOL)setup
{
    VVOrm *orm = [[VVOrm alloc] initWithConfig:config name:name database:vvdb];
    if (setup) {
        VVOrmInspection comparison = [orm inspectExistingTable];
        [orm setupTableWith:comparison];
    }
    return orm;
}

+ (nullable instancetype)ormWithConfig:(VVOrmConfig *)config
                                  name:(nullable NSString *)name
                              database:(nullable VVDatabase *)vvdb
                         content_table:(nullable NSString *)content_table
                         content_rowid:(nullable NSString *)content_rowid
                                 setup:(BOOL)setup
{
    VVOrm *orm = [[VVOrm alloc] initWithConfig:config name:name database:vvdb];
    orm.content_table = content_table;
    orm.content_rowid = content_rowid;
    if (setup) {
        VVOrmInspection comparison = [orm inspectExistingTable];
        [orm setupTableWith:comparison];
    }
    return orm;
}

+ (nullable instancetype)ormWithConfig:(VVOrmConfig *)config
                              relative:(VVOrm *)relativeORM
                         content_rowid:(nullable NSString *)content_rowid
{
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

    NSString *fts_table = [NSString stringWithFormat:@"fts_%@", relativeORM.name];
    VVOrm *orm = [[VVOrm alloc] initWithConfig:config name:fts_table database:relativeORM.vvdb];
    orm.content_table = relativeORM.name;
    orm.content_rowid = content_rowid;

    if (!relativeORM.created) {
        VVOrmInspection comparison1 = [relativeORM inspectExistingTable];
        [relativeORM setupTableWith:comparison1];
    }

    VVOrmInspection comparison2 = [orm inspectExistingTable];
    [orm setupTableWith:comparison2];

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
    if (_created) return;

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
    _created = YES;
}

- (void)createTable
{
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
