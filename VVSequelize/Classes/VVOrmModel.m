//
//  VVOrmModel.m
//  VVSequelize
//
//  Created by Jinbo Li on 2018/6/6.
//

#import "VVOrmModel.h"
#import <objc/runtime.h>
#import "VVSequelize.h"
#import "VVClassInfo.h"
#import "NSObject+VVKeyValue.h"

#define VVSqlTypeInteger @"INTEGER"
#define VVSqlTypeText    @"TEXT"
#define VVSqlTypeBlob    @"BLOB"
#define VVSqlTypeReal    @"REAL"

NSNotificationName const VVOrmModelDataChangeNotification   = @"VVOrmModelDataChangeNotification";
NSNotificationName const VVOrmModelDataInsertNotification   = @"VVOrmModelDataInsertNotification";
NSNotificationName const VVOrmModelDataUpdateNotification   = @"VVOrmModelDataUpdateNotification";
NSNotificationName const VVOrmModelDataDeleteNotification   = @"VVOrmModelDataDeleteNotification";
NSNotificationName const VVOrmModelTableCreatedNotification = @"VVOrmModelTableCreatedNotification";
NSNotificationName const VVOrmModelTableDeletedNotification = @"VVOrmModelTableDeletedNotification";

@interface VVOrmModel ()
@property (nonatomic, strong) NSCache    *cache;
@end

@implementation VVOrmModel

//MARK: - Private
- (NSString *)createSqlOfField:(VVOrmField *)field{
    NSMutableString *string = [NSMutableString stringWithFormat:@"\"%@\" \"%@\"", field.name, field.type];
    if(field.pk > 0)                 { [string appendString: field.pk == 1 ? @" PRIMARY KEY" : @" PRIMARY KEY AUTOINCREMENT"];}
    if(field.notnull)                { [string appendString:@" NOT NULL"];}
    if(field.pk == 0 && field.unique){ [string appendString:@" UNIQUE"];}
    if(field.dflt_value.length > 0)  { [string appendFormat:@" DEFAULT(%@)", field.dflt_value]; }
    return string;
}

- (void)handleInsertResult:(BOOL)result{
    if(result){
        [_cache removeAllObjects];
        [[NSNotificationCenter defaultCenter] postNotificationName:VVOrmModelDataChangeNotification object:self];
        [[NSNotificationCenter defaultCenter] postNotificationName:VVOrmModelDataInsertNotification object:self];
    }
}

- (void)handleUpdateResult:(BOOL)result{
    if(result){
        [_cache removeAllObjects];
        [[NSNotificationCenter defaultCenter] postNotificationName:VVOrmModelDataChangeNotification object:self];
        [[NSNotificationCenter defaultCenter] postNotificationName:VVOrmModelDataUpdateNotification object:self];
    }
}

- (void)handleDeleteResult:(BOOL)result{
    if(result){
        [_cache removeAllObjects];
        [[NSNotificationCenter defaultCenter] postNotificationName:VVOrmModelDataChangeNotification object:self];
        [[NSNotificationCenter defaultCenter] postNotificationName:VVOrmModelDataDeleteNotification object:self];
    }
}

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
        model.cache      = cache;
    }
    [model createOrModifyTable];
    return model;
}

/**
 根据参数,创建或修改表
 */
- (void)createOrModifyTable{
    NSAssert1(_config.fields.count > 0, @"No need to create a table : %@", _tableName);
    VVOrmConfig *tableConfig = [VVOrmConfig configWithTable:_tableName inDatabase:_vvdb];
    //MARK: 检查数据表是否存在
    BOOL exist        = [_vvdb isTableExist:_tableName];
    BOOL indexChanged = NO;
    BOOL changed      = NO;
    // 若表存在,检查是否需要进行变更.如需变更,则将原数据表进行更名.
    NSString *tempTableName = [NSString stringWithFormat:@"%@_%@",_tableName, @((NSUInteger)[[NSDate date] timeIntervalSince1970])];
    if(exist){
        changed = [_config compareWithConfig:tableConfig indexChanged:&indexChanged];
        // 字段发生变更,对原数据表进行更名
        if(changed){
            NSString *sql = [NSString stringWithFormat:@"ALTER TABLE \"%@\" RENAME TO \"%@\"", _tableName, tempTableName];
            NSNumber *ret = [_vvdb inQueue:^id{
                return @([self->_vvdb executeUpdate:sql]);
            }];
            NSAssert1(ret.boolValue, @"Failure to create a temporary table: %@", tempTableName);
        }
    }
    
    //MARK: 若表不存在或字段发生变更,需要创建新表
    if(!exist || changed > 0){
        NSMutableString *fieldsSQL = [NSMutableString stringWithCapacity:0];
        for (VVOrmField *field in _config.fields) {
            [fieldsSQL appendFormat:@"%@,", [self createSqlOfField:field]];
        }
        [fieldsSQL deleteCharactersInRange:NSMakeRange(fieldsSQL.length - 1, 1)];
        NSString *sql = [NSString stringWithFormat:@"CREATE TABLE IF NOT EXISTS \"%@\" (%@)  ", _tableName, fieldsSQL];
        NSNumber *ret = [_vvdb inQueue:^id{
            return @([self->_vvdb executeUpdate:sql]);
        }];
        NSAssert1(ret.boolValue, @"Failure to create a table: %@", _tableName);
        [[NSNotificationCenter defaultCenter] postNotificationName:VVOrmModelTableCreatedNotification object:self];
    }
    //MARK: 如果字段发生变更,将原数据表的数据插入新表
    if(exist && changed > 0){
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
    //MARK: 若索引发生变化,则重建索引
    if(indexChanged){
        NSString *indexName = [NSString stringWithFormat:@"vvorm_index_%@",_tableName];
        // 删除原索引
        NSString *dropIdxSQL = [NSString stringWithFormat:@"DROP INDEX \"%@\";",indexName];
        // 建立新索引
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
            BOOL r = [self->_vvdb executeUpdate:dropIdxSQL];
            if(r) r = [self->_vvdb executeUpdate:createIdxSQL];
            return @(r);
        }];
        if(!ret.boolValue){
            VVLog(2, @"Warning: Failed create index for table (%@)!",self->_tableName);
        }
    }
}

@end

@implementation VVOrmModel (Create)
-(BOOL)insertOne:(id)object{
    BOOL ret = [self insertOneWithoutNotification:object];
    [self handleInsertResult:ret];
    return ret;
}

-(BOOL)insertOneWithoutNotification:(id)object{
    NSDictionary *dic = [object isKindOfClass:[NSDictionary class]] ? object : [object vv_keyValues];
    NSMutableString *keyString = [NSMutableString stringWithCapacity:0];
    NSMutableString *valString = [NSMutableString stringWithCapacity:0];
    NSMutableArray *values = [NSMutableArray arrayWithCapacity:0];
    [dic enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        if(key && obj && [self.config.fieldNames containsObject:key]){
            [keyString appendFormat:@"\"%@\",",key];
            [valString appendFormat:@"?,"];
            [values addObject:[obj vv_dbStoreValue]];
        }
    }];
    if(keyString.length > 1 && valString.length > 1){
        if(_config.logAt){
            NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
            [keyString appendFormat:@"\"%@\",",kVsCreateAt];
            [valString appendFormat:@"?,"];
            [values addObject:@(now)];
            [keyString appendFormat:@"\"%@\",",kVsUpdateAt];
            [valString appendFormat:@"?,"];
            [values addObject:@(now)];
        }
        [keyString deleteCharactersInRange:NSMakeRange(keyString.length - 1, 1)];
        [valString deleteCharactersInRange:NSMakeRange(valString.length - 1, 1)];
        NSString *sql = [NSString stringWithFormat:@"INSERT INTO \"%@\" (%@) VALUES (%@)",_tableName,keyString,valString];
        return [_vvdb executeUpdate:sql values:values];
    }
    return NO;
}

-(NSUInteger)insertMulti:(NSArray *)objects{
    NSUInteger succCount = 0;
    for (id obj in objects) {
        if([self insertOneWithoutNotification:obj]){ succCount ++;}
    }
    [self handleInsertResult:succCount > 0];
    return succCount;
}

@end

@implementation VVOrmModel (Update)

- (BOOL)update:(id)condition
        values:(NSDictionary *)values{
    BOOL ret = [self updateWithoutNotification:condition values:values];
    [self handleUpdateResult:ret];
    return ret;
}

- (BOOL)updateWithoutNotification:(id)condition
                           values:(NSDictionary *)values{
    NSString *where = [VVSqlGenerator where:condition];
    NSMutableString *setString = [NSMutableString stringWithCapacity:0];
    NSMutableArray *objs = [NSMutableArray arrayWithCapacity:0];
    [values enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        if(key && obj && [self.config.fieldNames containsObject:key]){
            [setString appendFormat:@"\"%@\" = ?,",key];
            [objs addObject:[obj vv_dbStoreValue]];
        }
    }];
    if (setString.length > 1) {
        if(_config.logAt){
            NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
            [setString appendFormat:@"\"%@\" = ?,",kVsUpdateAt];
            [objs addObject:@(now)];
        }
        [setString deleteCharactersInRange:NSMakeRange(setString.length - 1, 1)];
        NSString *sql = [NSString stringWithFormat:@"UPDATE \"%@\" SET %@ %@",_tableName,setString,where];
        return [_vvdb executeUpdate:sql values:objs];
    }
    return NO;
}

- (BOOL)updateOne:(id)object{
    BOOL ret = [self updateOneWithoutNotification:object fields:nil];
    [self handleUpdateResult:ret];
    return ret;
}

- (BOOL)updateOne:(id)object fields:(nullable NSArray<NSString *> *)fields{
    BOOL ret = [self updateOneWithoutNotification:object fields:fields];
    [self handleUpdateResult:ret];
    return ret;
}

- (BOOL)updateOneWithoutNotification:(id)object fields:(nullable NSArray<NSString *> *)fields{
    NSDictionary *dic = [object isKindOfClass:[NSDictionary class]] ? object : [object vv_keyValues];
    NSString *primaryKey = _config.primaryKey;
    if(primaryKey.length == 0 || !dic[primaryKey]) return NO;
    NSDictionary *condition = @{primaryKey:dic[primaryKey]};
    NSMutableDictionary *values = nil;
    if(fields.count == 0){
        values = dic.mutableCopy;
        [values removeObjectForKey:primaryKey];
    }
    else{
        values = [NSMutableDictionary dictionaryWithCapacity:fields.count];
        for (NSString *field in fields) {
            values[field] = dic[field];
        }
    }
    if(values.count == 0) return NO;
    return [self update:condition values:values];
}

- (BOOL)upsertOne:(id)object{
    if([self isExist:object]){
        return [self updateOne:object];
    }
    else{
        return [self insertOne:object];
    }
}


/**
 更新或插入一条数据
 
 @param object 要更新或插入的数据
 @return 0-失败,1-更新成功,2-插入成功
 */
- (NSUInteger)upsertOneWithoutNotification:(id)object{
    if([self isExist:object]){
        BOOL ret = [self updateOneWithoutNotification:object fields:nil];
        return ret ? 1 : 0;
    }
    else{
        BOOL ret = [self insertOneWithoutNotification:object];
        return ret ? 2 : 0;
    }
}

- (NSUInteger)updateMulti:(NSArray *)objects{
    return [self updateMulti:objects fields:nil];
}

- (NSUInteger)updateMulti:(NSArray *)objects fields:(nullable NSArray<NSString *> *)fields{
    NSUInteger succCount = 0;
    for (id object in objects) {
        if([self updateOneWithoutNotification:object fields:fields]) {succCount ++;}
    }
    [self handleUpdateResult:succCount > 0];
    return succCount;
}

- (NSUInteger)upsertMulti:(NSArray *)objects{
    NSUInteger updateCount = 0;
    NSUInteger insertCount = 0;
    for (id object in objects) {
        NSUInteger ret = [self upsertOneWithoutNotification:object];
        if(ret == 1) updateCount ++;
        else if(ret == 2) insertCount ++;
    }
    if(updateCount + insertCount > 0){
        [_cache removeAllObjects];
        [[NSNotificationCenter defaultCenter] postNotificationName:VVOrmModelDataChangeNotification object:self];
        if(updateCount > 0)
        [[NSNotificationCenter defaultCenter] postNotificationName:VVOrmModelDataUpdateNotification object:self];
        if(insertCount > 0)
        [[NSNotificationCenter defaultCenter] postNotificationName:VVOrmModelDataInsertNotification object:self];
    }
    return updateCount + insertCount;
}

- (BOOL)increase:(id)condition
           field:(NSString *)field
           value:(NSInteger)value{
    if (value == 0) { return YES; }
    NSMutableString *setString = [NSMutableString stringWithFormat:@"\"%@\" = \"%@\" %@ %@",
                                  field, field, value > 0 ? @"+": @"-", @(ABS(value))];
    if(_config.logAt){
        NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
        [setString appendFormat:@",\"%@\" = \"%@\",",kVsUpdateAt,@(now)];
    }
    [setString deleteCharactersInRange:NSMakeRange(setString.length - 1, 1)];
    NSString *where = [VVSqlGenerator where:condition];
    NSString *sql = [NSString stringWithFormat:@"UPDATE \"%@\" SET %@ %@",_tableName,setString,where];
    BOOL ret = [_vvdb executeUpdate:sql];
    [self handleUpdateResult:ret];
    return ret;
}

@end

@implementation VVOrmModel (Retrieve)

- (id)findOneByPKVal:(id)PKVal{
    if(!PKVal || _config.primaryKey.length == 0) return nil;
    return [self findOne:@{_config.primaryKey:PKVal}];
}

- (id)findOne:(id)condition{
    NSArray *array = [self findAll:condition orderBy:nil range:NSMakeRange(0, 1)];
    return array.count > 0 ? array.firstObject : nil;
}

- (id)findOne:(id)condition
      orderBy:(id)orderBy{
    NSArray *array = [self findAll:condition orderBy:orderBy range:NSMakeRange(0, 1)];
    return array.count > 0 ? array.firstObject : nil;
}

- (NSArray *)findAll:(id)condition{
    return [self findAll:condition orderBy:nil range:VVRangeAll];
}

- (NSArray *)findAll:(id)condition
             orderBy:(id)orderBy
               range:(NSRange)range{
    return [self findAll:condition fields:nil orderBy:orderBy range:range];
}

- (NSArray *)findAll:(id)condition
              fields:(NSArray<NSString *> *)fields
             orderBy:(id)orderBy
               range:(NSRange)range{
    return [self findAll:condition fields:fields orderBy:orderBy range:range jsonResult:NO];
}

- (NSArray *)findAll:(id)condition
              fields:(NSArray<NSString *> *)fields
             orderBy:(id)orderBy
               range:(NSRange)range
          jsonResult:(BOOL)jsonResult{
    NSString *fieldsStr = @"*";
    if(fields.count > 0){
        NSMutableString *tempStr = [NSMutableString stringWithCapacity:0];
        for (NSString *field in fields) {
            if(field.length > 0) [tempStr appendFormat:@"\"%@\",",field];
        }
        if(tempStr.length > 1) {
            [tempStr deleteCharactersInRange:NSMakeRange(tempStr.length - 1, 1)];
            fieldsStr = tempStr;
        }
    }
    NSString *where = [VVSqlGenerator where:condition];
    NSString *order = [VVSqlGenerator orderBy:orderBy];
    NSString *limit = [VVSqlGenerator limit:range];
    NSString *sql = [NSString stringWithFormat:@"SELECT %@ FROM \"%@\"%@%@%@ ", fieldsStr, _tableName,where,order,limit];
    NSArray *results = [_cache objectForKey:sql];
    if(!results){
        NSArray *jsonArray = [_vvdb executeQuery:sql];
        results = jsonArray;
        if(!jsonResult && [fieldsStr isEqualToString:@"*"]){
            results = [_config.cls vv_objectsWithKeyValuesArray:jsonArray];
        }
        [_cache setObject:results forKey:sql];
    }
    return results;
}

- (NSInteger)count:(id)condition{
    NSString *where = [VVSqlGenerator where:condition];
    NSString *sql = [NSString stringWithFormat:@"SELECT count(*) as \"count\" FROM \"%@\"%@", _tableName,where];
    NSArray *array = [_cache objectForKey:sql];
    if(!array){
        array = [_vvdb executeQuery:sql];
        [_cache setObject:array forKey:sql];
    }
    NSInteger count = 0;
    if (array.count > 0) {
        NSDictionary *dic = array.firstObject;
        count = [dic[@"count"] integerValue];
    }
    return count;
}

- (BOOL)isExist:(id)object{
    NSString *primaryKey =_config.primaryKey;
    if(primaryKey.length == 0) return NO;
    id pk = [object valueForKey:primaryKey];
    if(!pk) return NO;
    NSDictionary *condition = @{primaryKey:pk};
    return [self count:condition] > 0;
}

- (NSDictionary *)findAndCount:(id)condition
                       orderBy:(id)orderBy
                         range:(NSRange)range{
    NSUInteger count = [self count:condition];
    NSArray *array = [self findAll:condition orderBy:orderBy range:range];
    return @{@"count":@(count), @"list":array};
}

/**
 SQLite中每个表都默认包含一个隐藏列rowid，使用WITHOUT ROWID定义的表除外。通常情况下，rowid可以唯一的标记表中的每个记录。表中插入的第一个条记录的rowid为1，后续插入的记录的rowid依次递增1。即使插入失败，rowid也会被加一。所以，整个表中的rowid并不一定连续，即使用户没有删除过记录。
 由于唯一性，所以rowid在很多场合中当作主键使用。在使用的时候，select * from tablename 并不能获取rowid，必须显式的指定。例如，select rowid, * from tablename 才可以获取rowid列。查询rowid的效率非常高，所以直接使用rowid作为查询条件是一个优化查询的好方法。
 但是rowid列作为主键，在极端情况下存在隐患。由于rowid值会一直递增，如果达到所允许的最大值9223372036854775807后，它会自动搜索没有被使用的值，重新使用，并不会提示用户。这时，使用rowid排序记录，会产生乱序，并引入其他的逻辑问题。所以，如果用户的数据库存在这种可能的情况，就应该使用AUTOINCREMENT定义主键，从而避免这种问题。使用AUTOINCREMENT设置自增主键，虽然也会遇到9223372036854775807问题，但是它会报错，提示用户，避免产生rowid所引发的问题。
 通常iOS App内嵌数据库单表的数据量不会达到rowid最大值，此处取`max(rowid)`可以做唯一值, `max(rowid) + 1`为下一条将插入的数据的自动主键值.
 */
- (NSUInteger)maxRowid{
    return [[self max:@"rowid"] unsignedIntegerValue];
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
    NSString *sql = [NSString stringWithFormat:@"SELECT %@(\"%@\") AS \"%@\" FROM \"%@\"", method, field, method, _tableName];
    NSArray *array = [_cache objectForKey:sql];
    if(!array){
        array = [_vvdb executeQuery:sql];
        [_cache setObject:array forKey:sql];
    }
    id result = nil;
    if(array.count > 0){
        NSDictionary *dic = array.firstObject;
        result = dic[method];
    }
    return [result isKindOfClass:NSNull.class] ? nil : result;
}

@end

@implementation VVOrmModel (Delete)

- (BOOL)drop{
    NSString *sql = [NSString stringWithFormat:@"DROP TABLE IF EXISTS \"%@\"",_tableName];
    BOOL ret = [_vvdb executeUpdate:sql];
    [self handleDeleteResult:ret];
    if(ret){
        // 此处还需发送表删除通知
        [[NSNotificationCenter defaultCenter] postNotificationName:VVOrmModelTableDeletedNotification object:self];
    }
    return ret;
}

- (BOOL)deleteOne:(id)object{
    NSString *primaryKey =_config.primaryKey;
    if(primaryKey.length == 0) return NO;
    id pk = [object valueForKey:primaryKey];
    if(!pk) return NO;
    NSString *where = [VVSqlGenerator where:@{primaryKey:pk}];
    NSString *sql = [NSString stringWithFormat:@"DELETE FROM \"%@\" %@",_tableName, where];
    BOOL ret = [_vvdb executeUpdate:sql];
    [self handleDeleteResult:ret];
    return ret;
}

- (BOOL)deleteMulti:(NSArray *)objects{
    NSString *primaryKey =_config.primaryKey;
    if(primaryKey.length == 0) return NO;
    NSMutableArray *pks = [NSMutableArray arrayWithCapacity:0];
    for (id object in objects) {
        id pk = [object valueForKey:primaryKey];
        if(pk) [pks addObject:pk];
    }
    if(pks.count == 0) return YES;
    NSString *where = [VVSqlGenerator where:@{primaryKey:@{kVsOpIn:pks}}];
    NSString *sql = [NSString stringWithFormat:@"DELETE FROM \"%@\" %@",_tableName, where];
    BOOL ret = [_vvdb executeUpdate:sql];
    [self handleDeleteResult:ret];
    return ret;
}

- (BOOL)delete:(id)condition{
    NSString *where = [VVSqlGenerator where:condition];
    NSString *sql = [NSString stringWithFormat:@"DELETE FROM \"%@\" %@",_tableName, where];
    BOOL ret = [_vvdb executeUpdate:sql];
    [self handleDeleteResult:ret];
    return ret;
}

@end
