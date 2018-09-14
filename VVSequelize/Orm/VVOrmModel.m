//
//  VVOrmModel.m
//  VVSequelize
//
//  Created by Jinbo Li on 2018/6/6.
//

#import "VVOrmModel.h"
#import "VVSequelize.h"
#import "NSString+VVOrmModel.h"

NSNotificationName const VVOrmModelDataChangeNotification   = @"VVOrmModelDataChangeNotification";
NSNotificationName const VVOrmModelDataInsertNotification   = @"VVOrmModelDataInsertNotification";
NSNotificationName const VVOrmModelDataUpdateNotification   = @"VVOrmModelDataUpdateNotification";
NSNotificationName const VVOrmModelDataDeleteNotification   = @"VVOrmModelDataDeleteNotification";
NSNotificationName const VVOrmModelTableCreatedNotification = @"VVOrmModelTableCreatedNotification";
NSNotificationName const VVOrmModelTableDeletedNotification = @"VVOrmModelTableDeletedNotification";

@implementation VVOrmModel


//MARK: - Public
+ (instancetype)ormModelWithConfig:(VVOrmConfig *)config{
    return [self ormModelWithConfig:config tableName:nil dataBase:nil];
}

+ (instancetype)ormModelWithConfig:(VVOrmConfig *)config
                         tableName:(nullable NSString *)tableName
                          dataBase:(nullable VVDataBase *)vvdb{
    if(!config || !config.cls) return nil;
    NSString *tbname = tableName.length > 0 ?  tableName : NSStringFromClass(config.cls);
    VVDataBase   *db = vvdb ? vvdb : VVDataBase.defalutDb;
    VVOrmModel *model = [[VVOrmModel alloc] init];
    model->_config = config;
    model->_tableName = tbname;
    model->_vvdb = db;
    if(VVSequelize.useCache){
        NSCache *cache = [[NSCache alloc] init];
        cache.name       = tbname;
        cache.countLimit = 1000;
        model->_cache    = cache;
    }
    [model createOrModifyTable];
    return model;
}

- (void)handleResult:(BOOL)result action:(VVOrmAction)action{
    if(!result) return;
    [_cache removeAllObjects];
    [[NSNotificationCenter defaultCenter] postNotificationName:VVOrmModelDataChangeNotification object:self];
    switch (action) {
            case VVOrmActionInsert:
            [[NSNotificationCenter defaultCenter] postNotificationName:VVOrmModelDataInsertNotification object:self];
            break;
            case VVOrmActionUpdate:
            [[NSNotificationCenter defaultCenter] postNotificationName:VVOrmModelDataUpdateNotification object:self];
            break;
            case VVOrmActionDelete:
            [[NSNotificationCenter defaultCenter] postNotificationName:VVOrmModelDataDeleteNotification object:self];
            break;
        default:
            break;
    }
}

//Private

/**
 根据参数,创建或修改表
 */
- (void)createOrModifyTable{
    NSAssert1(_config.fields.count > 0, @"No need to create a table : %@", _tableName);
    VVOrmConfig *tableConfig = [VVOrmConfig configWithTable:_tableName database:_vvdb];
    //检查数据表是否存在
    BOOL exist        = [_vvdb isTableExist:_tableName];
    BOOL indexChanged = NO;
    BOOL changed      = NO;
    // 若表存在,检查是否需要进行变更.如需变更,则将原数据表进行更名.
    NSString *tempTableName = [NSString stringWithFormat:@"%@_%@",_tableName, @((NSUInteger)[[NSDate date] timeIntervalSince1970])];
    if(exist){
        changed = ![_config isEqualToConfig:tableConfig indexChanged:&indexChanged];
    }
    // 字段发生变更,对原数据表进行更名
    if(changed) {
        [self renameToTempTable:tempTableName];
    }
    // 若表不存在或字段发生变更,需要创建新表
    if(!exist || changed) {
        [self createTable];
    }
    // 如果字段发生变更,将原数据表的数据插入新表
    if(exist && changed) {
        [self migrationDataFormTempTable:tempTableName];
    }
    // 若索引发生变化,则重建索引
    if(indexChanged) {
        [self rebuildIndex];
    }
}

- (void)createTable{
    NSString *sql = nil;
    // 创建FTS表
    if(_config.fts){
        sql = [self ftsTableCreateSQL];
    }
    // 创建普通表
    else{
        sql = [self commonTableCreateSQL];
    }
    // 执行建表SQL
    NSNumber *ret = [_vvdb inQueue:^id{
        return @([self->_vvdb executeUpdate:sql]);
    }];
    NSAssert1(ret.boolValue, @"Failure to create a table: %@", _tableName);
    [[NSNotificationCenter defaultCenter] postNotificationName:VVOrmModelTableCreatedNotification object:self];
}

- (NSString *)commonFieldCreateSQL:(VVOrmField *)field{
    NSMutableString *string = [NSMutableString stringWithFormat:@"\"%@\" \"%@\"", field.name, field.type];
    if(field.pk > 0)                 { [string appendString: field.pk == 1 ? @" PRIMARY KEY" : @" PRIMARY KEY AUTOINCREMENT"];}
    if(field.notnull)                { [string appendString:@" NOT NULL"];}
    if(field.pk == 0 && field.unique){ [string appendString:@" UNIQUE"];}
    if(field.dflt_value.length > 0)  { [string appendFormat:@" DEFAULT(%@)", field.dflt_value]; }
    return string;
}

- (NSString *)commonTableCreateSQL{
    NSMutableString *fieldsSQL = [NSMutableString stringWithCapacity:0];
    for (NSString *name in _config.fields) {
        [fieldsSQL appendFormat:@"%@,", [self commonFieldCreateSQL:_config.fields[name]]];
    }
    [fieldsSQL deleteCharactersInRange:NSMakeRange(fieldsSQL.length - 1, 1)];
    return [NSString stringWithFormat:@"CREATE TABLE IF NOT EXISTS \"%@\" (%@)", _tableName, fieldsSQL];
}

- (NSString *)ftsTableCreateSQL{
    NSMutableString *fieldsSQL  = [NSMutableString stringWithCapacity:0];
    NSMutableString *notIndexed = [NSMutableString stringWithCapacity:0];
    NSInteger ftsType = 3;
    if([_config.ftsModule isMatchRegex:@"fts4"]) ftsType = 4;
    if([_config.ftsModule isMatchRegex:@"fts5"]) ftsType = 5;

    for (NSString *name in _config.fields) {
        VVOrmField *field = _config.fields[name];
        if(ftsType == 5){
            [fieldsSQL appendFormat:@"%@%@,", name , field.fts_notindexed ? @" NOTINDEXED" : @""];
        }
        else{
            [fieldsSQL appendFormat:@"%@ %@,", name, field.type];
        }
        if(ftsType != 5 && field.fts_notindexed){
            [notIndexed appendFormat:@"notindexed = %@,",name];
        }
    }
    NSAssert(fieldsSQL.length > 1, @"无效的FTS表配置");
    [fieldsSQL deleteCharactersInRange:NSMakeRange(fieldsSQL.length - 1, 1)];
    if(notIndexed.length > 1) [notIndexed deleteCharactersInRange:NSMakeRange(notIndexed.length - 1, 1)];
    NSString *tokenizer = _config.ftsTokenizer.length == 0 ? @"" : [NSString stringWithFormat:@",tokenizer = %@", _config.ftsTokenizer];
    [fieldsSQL deleteCharactersInRange:NSMakeRange(fieldsSQL.length - 1, 1)];
    return [NSString stringWithFormat:@"CREATE VIRTUAL TABLE IF NOT EXISTS \"%@\" USING %@(%@ %@ %@)",
           _tableName, _config.ftsModule, fieldsSQL, notIndexed, tokenizer];
}

- (void)renameToTempTable:(NSString *)tempTableName{
    NSString *sql = [NSString stringWithFormat:@"ALTER TABLE \"%@\" RENAME TO \"%@\"", _tableName, tempTableName];
    NSNumber *ret = [_vvdb inQueue:^id{
        return @([self->_vvdb executeUpdate:sql]);
    }];
    NSAssert1(ret.boolValue, @"Failure to create a temporary table: %@", tempTableName);
}

- (void)migrationDataFormTempTable:(NSString *)tempTableName{
    NSMutableString *allFields = [NSMutableString stringWithCapacity:0];
    for (NSString *column in _config.fields) {
        [allFields appendFormat:@"\"%@\",",column];
    }
    if(allFields.length > 1) {
        [allFields deleteCharactersInRange:NSMakeRange(allFields.length - 1, 1)];
        NSNumber *result = [_vvdb inTransaction:^id(BOOL *rollback) {
            // 将旧表数据复制至新表
            NSString *sql = [NSString stringWithFormat:@"INSERT INTO \"%@\" (%@) SELECT %@ FROM \"%@\"", self->_tableName, allFields, allFields, tempTableName];
            BOOL ret = [self->_vvdb executeUpdate:sql];
            // 数据复制成功则删除旧表
            if(ret){
                sql = [NSString stringWithFormat:@"DROP TABLE \"%@\"", tempTableName];
                ret = [self->_vvdb executeUpdate:sql];
            }
            if(!ret){
                *rollback = YES;
                VVLog(2, @"Warning: copying data from old table (%@) to new table (%@) failed!",tempTableName,self->_tableName);
            }
            return @(ret);
        }];
        if(result.boolValue){
            [[NSNotificationCenter defaultCenter] postNotificationName:VVOrmModelDataChangeNotification object:self];
        }
    }
}

- (void)rebuildIndex{
    // FTS表无需创建索引
    if(_config.fts) return;
    NSString *indexesSQL = [NSString stringWithFormat:@"SELECT name FROM sqlite_master WHERE type ='index' and tbl_name = \"%@\"",_tableName];
    NSArray *array = [_vvdb executeQuery:indexesSQL];
    NSMutableString *dropIdxSQL = [NSMutableString stringWithCapacity:0];
    for (NSDictionary *dic  in array) {
        NSString *idxName = dic[@"name"];
        if([idxName hasPrefix:@"sqlite_autoindex_"]) continue;
        [dropIdxSQL appendFormat:@"DROP INDEX IF EXISTS \"%@\";", idxName];
    }
    
    // 建立新索引
    NSString *indexName = [NSString stringWithFormat:@"vvorm_index_%@",_tableName];
    NSMutableString *indexFields = [NSMutableString stringWithCapacity:0];
    for (NSString *name in _config.fields) {
        VVOrmField *field = _config.fields[name];
        if(field.indexed && !field.unique){ // sqlite3会对unique约束自动建立索引
            [indexFields appendFormat:@"\"%@\",", field.name];
        }
    }
    if(indexFields.length > 1) [indexFields deleteCharactersInRange:NSMakeRange(indexFields.length - 1, 1)];
    NSString *createIdxSQL = nil;
    if(indexFields.length > 0) createIdxSQL = [NSString stringWithFormat:@"CREATE INDEX \"%@\" on \"%@\" (%@);",indexName,_tableName,indexFields];
    NSNumber *ret = [_vvdb inQueue:^id{
        BOOL r = YES;
        if(dropIdxSQL.length > 0)        {r = [self->_vvdb executeUpdate:dropIdxSQL];}
        if(r && createIdxSQL.length > 0) {r = [self->_vvdb executeUpdate:createIdxSQL];}
        return @(r);
    }];
    if(!ret.boolValue){
        VVLog(2, @"Warning: Failed create index for table (%@)!",self->_tableName);
    }
}

@end
