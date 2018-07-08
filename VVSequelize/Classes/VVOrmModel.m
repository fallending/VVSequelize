//
//  VVOrmModel.m
//  VVSequelize
//
//  Created by Jinbo Li on 2018/6/6.
//

#import "VVOrmModel.h"
#import <objc/runtime.h>
#import "VVSequelize.h"

#define kVsPkid         @"vv_pkid"
#define kVsCreateAt     @"vv_createAt"
#define kVsUpdateAt     @"vv_updateAt"

#define VVSqlTypeInteger @"INTEGER"
#define VVSqlTypeText    @"TEXT"
#define VVSqlTypeBlob    @"BLOB"
#define VVSqlTypeReal    @"REAL"


@implementation VVOrmSchemaItem
- (BOOL)notnull{
    if(_pk) return YES; // 如果是主键,则不能为空值
    return _pk;
}

+ (instancetype)schemaItemWithDic:(NSDictionary *)dic{
    NSString *name = dic[@"name"];
    if(!name || name.length == 0) return nil;
    VVOrmSchemaItem *column = [VVOrmSchemaItem new];
    column.name = name;
    column.type = dic[@"type"];
    column.pk   = [dic[@"pk"] boolValue];
    column.notnull = [dic[@"notnull"] boolValue];
    column.unique  = [dic[@"unique"] boolValue];
    column.dflt_value = dic[@"dflt_value"];
    return column;
}

- (BOOL)isEqualToItem:(VVOrmSchemaItem *)item{
    id dflt_val1 = [self.dflt_value isKindOfClass:[NSNull class]] ? nil : self.dflt_value;
    id dflt_val2 = [item.dflt_value isKindOfClass:[NSNull class]] ? nil : item.dflt_value;
    BOOL dflt_equal = (!dflt_val1 && !dflt_val2) ? YES : [dflt_val1 isEqual:dflt_val2];
    NSString *type1 = [self.type containsString:@"("] ? [self.type componentsSeparatedByString:@"("].firstObject : self.type;
    NSString *type2 = [item.type containsString:@"("] ? [item.type componentsSeparatedByString:@"("].firstObject : item.type;
    return [self.name isEqualToString:item.name]
    && [type1.uppercaseString isEqualToString:type2.uppercaseString]
    && dflt_equal
    && self.pk == item.pk
    && self.notnull == item.notnull
    && self.unique == item.unique;
}
@end

@interface VVOrmModel ()

@property (nonatomic, strong) VVDataBase *vvdb;
@property (nonatomic, copy  ) NSString *tableName;
@property (nonatomic, copy  ) NSArray *fields;
@property (nonatomic, copy  ) NSArray *manuals;
@property (nonatomic, copy  ) NSArray *excludes;
@property (nonatomic        ) Class cls;
@property (nonatomic, copy  ) NSString *primaryKey;
@property (nonatomic, assign) BOOL atTime;

@property (nonatomic, assign) BOOL isDropped; ///< ormModel对应的表是否被drop

@end

@implementation VVOrmModel

//MARK: - Private

- (NSString *)columnSqlOf:(VVOrmSchemaItem *)column{
    if ([column.name isEqualToString:kVsPkid]) {
        return [NSString stringWithFormat:@"\"%@\" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT", kVsPkid];
    }
    NSMutableString *string = [NSMutableString stringWithFormat:@"\"%@\" \"%@\"", column.name,column.type];
    if(column.pk) { [string appendString:@" PRIMARY KEY"];}
    if(column.notnull) { [string appendString:@" NOT NULL"];}
    if(column.dflt_value) { [string appendFormat:@" DEFAULT(\"%@\")", column.dflt_value]; }
    return string;
}

- (NSDictionary *)tableColumns{
    NSString *tableInfoSql = [NSString stringWithFormat:@"PRAGMA table_info(\"%@\");",_tableName];
    NSArray *columns = [_vvdb executeQuery:tableInfoSql];
    NSMutableDictionary *resultDic = [NSMutableDictionary dictionaryWithCapacity:0];
    for (NSDictionary *dic in columns) {
        VVOrmSchemaItem *column = [VVOrmSchemaItem new];
        column.name = dic[@"name"];
        column.type = dic[@"type"];
        column.pk = [dic[@"pk"] boolValue];
        column.notnull =[dic[@"notnull"] boolValue];
        column.dflt_value = dic[@"dflt_value"];
        resultDic[column.name] = column;
    }
    NSString *indexListSql = [NSString stringWithFormat:@"PRAGMA index_list(\"%@\");",_tableName];
    NSArray *indexList = [_vvdb executeQuery:indexListSql];
    for (NSDictionary *indexDic in indexList) {
        if([indexDic[@"origin"] isEqualToString:@"u"] && [indexDic[@"unique"] integerValue] == 1){
            NSString *indexName = indexDic[@"name"];
            NSString *indexInfoSql = [NSString stringWithFormat:@"PRAGMA index_info(\"%@\");",indexName];
            NSArray *indexInfos = [_vvdb executeQuery:indexInfoSql];
            if(indexInfos.count > 0) {
                NSDictionary *indexInfo = indexInfos.firstObject;
                NSString *columnName = indexInfo[@"name"];
                VVOrmSchemaItem *column = resultDic[columnName];
                column.unique = YES;
            }
        }
    }
    return resultDic;
}

- (NSDictionary *)classColumnsWithManuals:(NSArray<VVOrmSchemaItem *> *)manuals{
    NSMutableDictionary *manualColumns = [NSMutableDictionary dictionaryWithCapacity:0];
    for (VVOrmSchemaItem *column in manuals) {
        if(column.name) {manualColumns[column.name] = column; }
    }
    NSMutableDictionary *dic = [NSMutableDictionary dictionaryWithCapacity:0];
    unsigned int count;
    objc_property_t *properties = class_copyPropertyList(_cls, &count);
    for (int i = 0; i < count; i++) {
        NSString *name = [NSString stringWithCString:property_getName(properties[i]) encoding:NSUTF8StringEncoding];
        VVOrmSchemaItem *column = manualColumns[name] ? manualColumns[name] : [VVOrmSchemaItem new];
        column.name = name;
        if(column.type.length <= 0){
            NSString *type = [NSString stringWithCString:property_getAttributes(properties[i]) encoding:NSUTF8StringEncoding];
            column.type = [self sqliteTypeForPropertyType:type];
        }
        dic[column.name] = column;
    }
    free(properties);
    return dic;
}

- (NSInteger)compareSchemaItems:(NSDictionary<NSString *,VVOrmSchemaItem *> *)columns1
                           with:(NSDictionary<NSString *,VVOrmSchemaItem *> *)columns2{
    NSArray *allKeys1 = columns1.allKeys;
    NSArray *allKeys2 = columns2.allKeys;
    NSInteger different = 0;
    for (NSString *key in allKeys1) {
        if([key isEqualToString:kVsPkid]
           || [key isEqualToString:kVsCreateAt]
           || [key isEqualToString:kVsUpdateAt]){
            continue;
        }
        if ([allKeys2 containsObject:key]) {
            if(![columns1[key] isEqualToItem:columns2[key]]) different ++;
        }
        else{
            different ++;
        }
    }
    for (NSString *key in allKeys2) {
        if([key isEqualToString:kVsPkid]
           || [key isEqualToString:kVsCreateAt]
           || [key isEqualToString:kVsUpdateAt]){
            continue;
        }
        if(![allKeys1 containsObject:key]) different ++;
    }
    return different;
}

- (NSString *)sqliteTypeForPropertyType:(NSString *)properyType{
    // NSString,NSMutableString,NSDictionary,NSMutableDictionary,NSArray,NSSet,NSMutableSet,...
    NSString * type = VVSqlTypeText;
    // NSData,NSMutableData
    if ([properyType hasPrefix:@"T@\"NSData\""]
        ||[properyType hasPrefix:@"T@\"NSMutableData\""]){
        type = VVSqlTypeBlob;
    }
    else if ([properyType hasPrefix:@"Ti"]
             ||[properyType hasPrefix:@"TI"]
             ||[properyType hasPrefix:@"Ts"]
             ||[properyType hasPrefix:@"TS"]
             ||[properyType hasPrefix:@"T@\"NSNumber\""]
             ||[properyType hasPrefix:@"TB"]
             ||[properyType hasPrefix:@"Tq"]
             ||[properyType hasPrefix:@"TQ"]) {
        type = VVSqlTypeInteger;
    }
    else if ([properyType hasPrefix:@"Tf"]
             || [properyType hasPrefix:@"Td"]){
        type= VVSqlTypeReal;
    }
    // 其他数据类型都用Text的方式保存,再将对象转Json的时候请转为NSString形式
    return type;
}

+ (NSMutableDictionary *)modelPool{
    static NSMutableDictionary *_modelPool;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _modelPool = [NSMutableDictionary dictionaryWithCapacity:0];
    });
    return _modelPool;
}

//MARK: - Public
+ (instancetype)ormModelWithClass:(Class)cls
                       primaryKey:(NSString *)primaryKey{
    return [self ormModelWithClass:cls primaryKey:primaryKey tableName:nil dataBase:nil];
}

+ (instancetype)ormModelWithClass:(Class)cls
                       primaryKey:(NSString *)primaryKey
                        tableName:(NSString *)tableName
                         dataBase:(VVDataBase *)db{
    NSMutableArray *manuals = [NSMutableArray arrayWithCapacity:0];
    if(primaryKey && primaryKey.length > 0){
        VVOrmSchemaItem *column = [VVOrmSchemaItem schemaItemWithDic:@{@"name":primaryKey,@"pk":@(YES)}];
        [manuals addObject:column];
    }
    return [self ormModelWithClass:cls manuals:manuals excludes:nil tableName:tableName dataBase:db atTime:YES];
}

+ (instancetype)ormModelWithClass:(Class)cls
                          manuals:(NSArray *)manuals
                         excludes:(NSArray *)excludes
                        tableName:(NSString *)tableName
                         dataBase:(VVDataBase *)vvdb
                           atTime:(BOOL)atTime{
    if(!cls) return nil;
    NSString *tbname = tableName.length > 0 ?  tableName : NSStringFromClass(cls);
    VVDataBase   *db = vvdb ? vvdb : VVDataBase.defalutDb;
    NSString *poolKey = [db.dbPath stringByAppendingString:tbname];
    NSRange range = [poolKey rangeOfString:NSHomeDirectory()];
    if(range.location != NSNotFound){
        // 使用相对路径作为Key
        poolKey = [poolKey substringFromIndex:range.location + range.length];
    }
    VVOrmModel *model = [[VVOrmModel modelPool] objectForKey:poolKey];
    if(!model){
        model = [[VVOrmModel alloc] init];
    }
    model.cls = cls;
    model.tableName = tbname;
    model.vvdb = db;
    model.manuals = manuals;
    model.excludes = excludes;
    model.atTime = atTime;
    [model createOrModifyTable];
    [[VVOrmModel modelPool] setObject:model forKey:poolKey];
    return model;
}

/**
 根据参数,创建或修改表
 */
- (void)createOrModifyTable{
    _isDropped = NO;
    // 处理自定义字段配置
    NSMutableArray *temps = [NSMutableArray arrayWithCapacity:0];
    for (id obj in _manuals) {
        if ([obj isKindOfClass:[NSDictionary class]]) {
            [temps addObject:[VVOrmSchemaItem schemaItemWithDic:obj]];
        }
        else if([obj isKindOfClass:[VVOrmSchemaItem class]]){
            [temps addObject:obj];
        }
    }
    // 根据要存储的类生成字段配置列表
    NSMutableDictionary *classColumns = [self classColumnsWithManuals:temps].mutableCopy;
    for (NSString *column in _excludes) {
        [classColumns removeObjectForKey:column];
    }
    // 定义的数据库类可能使用vv_pkid作为主键,并且需要在外部使用
    [classColumns removeObjectForKey:kVsPkid];
    self.fields = classColumns.allKeys;
    NSAssert1(classColumns.count > 0, @"No need to create a table : %@", _tableName);
    
    // 检查数据表是否存在
    BOOL exist = [self isTableExist];
    NSInteger changed = 0;
    // 若表存在,检查是否需要进行变更.如需变更,则将原数据表进行更名.
    NSString *tempTableName = [NSString stringWithFormat:@"%@_%@",_tableName, @((NSUInteger)[[NSDate date] timeIntervalSince1970])];
    if(exist){
        // 获取已存在字段
        NSDictionary *tableColumns = [self tableColumns];
        for (VVOrmSchemaItem *column in tableColumns.allValues) {
            if (column.pk) {
                _primaryKey = column.name;
                break;
            }
        }
        // 计算变化的字段数量
        changed = [self compareSchemaItems:classColumns with:tableColumns];
        // 字段发生变更,对原数据表进行更名
        if(changed > 0){
            NSString *sql = [NSString stringWithFormat:@"ALTER TABLE \"%@\" RENAME TO \"%@\"", _tableName, tempTableName];
            BOOL ret = [_vvdb executeUpdate:sql];
            NSAssert1(ret, @"Failure to create a temporary table: %@", tempTableName);
        }
    }
    
    // 若表不存在或字段发生变更,需要创建新表
    if(!exist || changed > 0){
        NSMutableString *columnsString = [NSMutableString stringWithCapacity:0];
        NSArray *allColumns = classColumns.allValues;
        NSMutableArray *uniqueColumns = [NSMutableArray arrayWithCapacity:0];
        for (VVOrmSchemaItem *column in allColumns) {
            [columnsString appendFormat:@"%@,", [self columnSqlOf:column]];
            if(column.unique) [uniqueColumns addObject:column];
            if(column.pk) _primaryKey = column.name;
        }
        if(_atTime){
            [columnsString appendFormat:@"\"%@\" REAL,",kVsCreateAt]; //创建时间
            [columnsString appendFormat:@"\"%@\" REAL,",kVsUpdateAt]; //修改时间
        }
        if(!_primaryKey){
            [columnsString appendFormat:@"\"%@\" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,",kVsPkid];
            _primaryKey = kVsPkid;
        }
        for (VVOrmSchemaItem *column in uniqueColumns) {
            [columnsString appendFormat:@"CONSTRAINT \"%@\" UNIQUE (\"%@\") ON CONFLICT FAIL,", column.name, column.name];
        }
        [columnsString deleteCharactersInRange:NSMakeRange(columnsString.length - 1, 1)];
        NSString *sql = [NSString stringWithFormat:@"CREATE TABLE IF NOT EXISTS \"%@\" (%@)  ", _tableName, columnsString];
        BOOL ret = [_vvdb executeUpdate:sql];
        NSAssert1(ret, @"Failure to create a table: %@", _tableName);
    }
    // 如果字段发生变更,将原数据表的数据插入新表
    if(exist && changed > 0){
        NSMutableString *allColumns = [NSMutableString stringWithCapacity:0];
        for (NSString *column in classColumns.allKeys) {
            [allColumns appendFormat:@"\"%@\",",column];
        }
        if(allColumns.length > 1) {
            [allColumns deleteCharactersInRange:NSMakeRange(allColumns.length - 1, 1)];
            [_vvdb inQueue:^id{
                // 将旧表数据复制至新表
                NSString *sql = [NSString stringWithFormat:@"INSERT INTO \"%@\" (%@) SELECT %@ FROM \"%@\"", self->_tableName, allColumns, allColumns, tempTableName];
                BOOL ret = [self->_vvdb executeUpdate:sql];
                // 数据复制成功则删除旧表
                if(ret){
                    sql = [NSString stringWithFormat:@"DROP TABLE \"%@\"", tempTableName];
                    ret = [self->_vvdb executeUpdate:sql];
                }
                else{
                    VVLog(2, @"Warning: copying data from old table (%@) to new table (%@) failed!",tempTableName,self->_tableName);
                }
                return @(ret);
            } completion:nil];
        }
    }
}

- (BOOL)isTableExist{
    NSString *sql = [NSString stringWithFormat:@"SELECT count(*) as 'count' FROM sqlite_master WHERE type ='table' and name = \"%@\"",_tableName];
    NSArray *array = [_vvdb executeQuery:sql];
    for (NSDictionary *dic in array) {
        NSInteger count = [dic[@"count"] integerValue];
        return count > 0;
    }
    return NO;
}

@end

@implementation VVOrmModel (Create)

-(BOOL)insertOne:(id)object{
    if(self.isDropped) {[self createOrModifyTable];}
    NSDictionary *dic = nil;
    if([object isKindOfClass:[NSDictionary class]]) {
        dic = object;
    }
    else if(VVSequelize.objectToKeyValues){
        dic = VVSequelize.objectToKeyValues(_cls,object);
    }
    else {
        return NO;
    }
    if([_primaryKey isEqualToString:kVsPkid] && [dic[_primaryKey] integerValue] != 0) return NO;
    NSMutableString *keyString = [NSMutableString stringWithCapacity:0];
    NSMutableString *valString = [NSMutableString stringWithCapacity:0];
    [dic enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        if(key && obj && [self.fields containsObject:key]){
            [keyString appendFormat:@"\"%@\",",key];
            [valString appendFormat:@"\"%@\",",obj];
        }
    }];
    if(keyString.length > 1 && valString.length > 1){
        if(_atTime){
            NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
            [keyString appendFormat:@"\"%@\",",kVsCreateAt];
            [valString appendFormat:@"\"%@\",",@(now)];
            [keyString appendFormat:@"\"%@\",",kVsUpdateAt];
            [valString appendFormat:@"\"%@\",",@(now)];
        }
        [keyString deleteCharactersInRange:NSMakeRange(keyString.length - 1, 1)];
        [valString deleteCharactersInRange:NSMakeRange(valString.length - 1, 1)];
        NSString *sql = [NSString stringWithFormat:@"INSERT INTO \"%@\" (%@) VALUES (%@)",_tableName,keyString,valString];
        return [_vvdb executeUpdate:sql];
    }
    return NO;
}

-(NSUInteger)insertMulti:(NSArray *)objects{
    NSUInteger succCount = 0;
    for (id obj in objects) {
        if([self insertOne:obj]){ succCount ++;}
    }
    return succCount;
}

@end

@implementation VVOrmModel (Update)

- (BOOL)update:(NSDictionary *)condition
        values:(NSDictionary *)values{
    if(self.isDropped) {[self createOrModifyTable];}
    NSString *where = [VVSqlGenerator where:condition];
    NSMutableString *setString = [NSMutableString stringWithCapacity:0];
    [values enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        if(key && obj && [self.fields containsObject:key]){
            [setString appendFormat:@"\"%@\" = \"%@\",",key,obj];
        }
    }];
    if (setString.length > 1) {
        if(_atTime){
            NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
            [setString appendFormat:@"\"%@\" = \"%@\",",kVsUpdateAt,@(now)];
        }
        [setString deleteCharactersInRange:NSMakeRange(setString.length - 1, 1)];
        NSString *sql = [NSString stringWithFormat:@"UPDATE %@ SET %@ %@",_tableName,setString,where];
        return [_vvdb executeUpdate:sql];
    }
    return NO;
}

- (BOOL)updateOne:(id)object{
    NSDictionary *dic = nil;
    if([object isKindOfClass:[NSDictionary class]]) {
        dic = object;
    }
    else if(VVSequelize.objectToKeyValues){
        dic = VVSequelize.objectToKeyValues(_cls,object);
    }
    else {
        return NO;
    }
    if(!dic[_primaryKey]) return NO;
    if([_primaryKey isEqualToString:kVsPkid] && [dic[_primaryKey] integerValue] == 0) return NO;
    NSDictionary *condition = @{_primaryKey:dic[_primaryKey]};
    NSMutableDictionary *values = dic.mutableCopy;
    [values removeObjectForKey:_primaryKey];
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

- (NSUInteger)updateMulti:(NSArray *)objects{
    NSUInteger succCount = 0;
    for (id object in objects) {
        if([self updateOne:object]) {succCount ++;}
    }
    return succCount;
}

- (NSUInteger)upsertMulti:(NSArray *)objects{
    NSUInteger succCount = 0;
    for (id object in objects) {
        if([self upsertOne:object]) {succCount ++;}
    }
    return succCount;
}

- (BOOL)increase:(NSDictionary *)condition
           field:(NSString *)field
           value:(NSInteger)value{
    if (value == 0) { return YES; }
    if(self.isDropped) {[self createOrModifyTable];}
    NSMutableString *setString = [NSMutableString stringWithFormat:@"\"%@\" = \"%@\" %@ %@",
                                  field, field, value > 0 ? @"+": @"-", @(ABS(value))];
    if(_atTime){
        NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
        [setString appendFormat:@",\"%@\" = \"%@\",",kVsUpdateAt,@(now)];
    }
    [setString deleteCharactersInRange:NSMakeRange(setString.length - 1, 1)];
    NSString *where = [VVSqlGenerator where:condition];
    NSString *sql = [NSString stringWithFormat:@"UPDATE \"%@\" SET %@ %@",_tableName,setString,where];
    return [_vvdb executeUpdate:sql];
}

@end

@implementation VVOrmModel (Retrieve)

- (id)findOneByPKVal:(id)PKVal{
    if(!PKVal) return nil;
    return [self findOne:@{_primaryKey:PKVal}];
}

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
    return [self findAll:condition fields:nil orderBy:orderBy range:range];
}

- (NSArray *)findAll:(NSDictionary *)condition
              fields:(NSArray<NSString *> *)fields
             orderBy:(NSDictionary *)orderBy
               range:(NSRange)range{
    if(self.isDropped) {[self createOrModifyTable];}
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
    NSArray *jsonArray = [_vvdb executeQuery:sql];
    if ([fieldsStr isEqualToString:@"*"] && VVSequelize.keyValuesArrayToObjects) {
        return VVSequelize.keyValuesArrayToObjects(_cls,jsonArray);
    }
    return jsonArray;
}


- (NSInteger)count:(NSDictionary *)condition{
    if(self.isDropped) {[self createOrModifyTable];}
    NSString *where = [VVSqlGenerator where:condition];
    NSString *sql = [NSString stringWithFormat:@"SELECT count(*) as \"count\" FROM \"%@\"%@", _tableName,where];
    NSArray *array = [_vvdb executeQuery:sql];
    NSInteger count = 0;
    if (array.count > 0) {
        NSDictionary *dic = array.firstObject;
        count = [dic[@"count"] integerValue];
    }
    return count;
}

- (BOOL)isExist:(id)object{
    if(self.isDropped) {[self createOrModifyTable];}
    NSDictionary *dic = nil;
    if([object isKindOfClass:[NSDictionary class]]) {
        dic = object;
    }
    else if(VVSequelize.objectToKeyValues){
        dic = VVSequelize.objectToKeyValues(_cls,object);
    }
    else {
        return NO;
    }
    if(!dic[_primaryKey]) return NO;
    if([_primaryKey isEqualToString:kVsPkid] && [dic[_primaryKey] integerValue] == 0) return NO;
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
    if(self.isDropped) {[self createOrModifyTable];}
    if(!([method isEqualToString:@"max"]
         || [method isEqualToString:@"min"]
         || [method isEqualToString:@"sum"])) return nil;
    NSString *sql = [NSString stringWithFormat:@"SELECT %@(\"%@\") AS \"%@\" FROM \"%@\"", method, field, method, _tableName];
    NSArray *array = [_vvdb executeQuery:sql];
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
    _isDropped = [_vvdb executeUpdate:sql];
    return _isDropped;
}

- (BOOL)deleteOne:(id)object{
    if(self.isDropped) {[self createOrModifyTable];}
    NSDictionary *dic = nil;
    if([object isKindOfClass:[NSDictionary class]]) {
        dic = object;
    }
    else if(VVSequelize.objectToKeyValues){
        dic = VVSequelize.objectToKeyValues(_cls,object);
    }
    else {
        return NO;
    }
    id pkid = dic[_primaryKey];
    if(!pkid) return NO;
    if([_primaryKey isEqualToString:kVsPkid] && [pkid integerValue] == 0) return NO;
    NSString *where = [VVSqlGenerator where:@{_primaryKey:pkid}];
    NSString *sql = [NSString stringWithFormat:@"DELETE FROM \"%@\" %@",_tableName, where];
    return [_vvdb executeUpdate:sql];
}

- (BOOL)deleteMulti:(NSArray *)objects{
    if(self.isDropped) {[self createOrModifyTable];}
    if(!VVSequelize.objectsToKeyValuesArray) return NO;
    NSArray *array = VVSequelize.objectsToKeyValuesArray(_cls,objects);
    NSMutableArray *pkids = [NSMutableArray arrayWithCapacity:0];
    for (NSDictionary *dic in array) {
        id pkid = dic[_primaryKey];
        if(pkid){ [pkids addObject:pkid];}
    }
    NSString *where = [VVSqlGenerator where:@{_primaryKey:@{kVsOpIn:pkids}}];
    NSString *sql = [NSString stringWithFormat:@"DELETE FROM \"%@\" %@",_tableName, where];
    return [_vvdb executeUpdate:sql];
}

- (BOOL)delete:(NSDictionary *)condition{
    if(self.isDropped) {[self createOrModifyTable];}
    NSString *where = [VVSqlGenerator where:condition];
    NSString *sql = [NSString stringWithFormat:@"DELETE FROM \"%@\" %@",_tableName, where];
    return [_vvdb executeUpdate:sql];
}

@end
