//
//  VVOrmConfig.m
//  VVSequelize
//
//  Created by Jinbo Li on 2018/9/10.
//

#import "VVOrmConfig.h"
#import "VVClassInfo.h"
#import "VVDataBase.h"

#define VVSqlTypeInteger @"INTEGER"
#define VVSqlTypeText    @"TEXT"
#define VVSqlTypeBlob    @"BLOB"
#define VVSqlTypeReal    @"REAL"

@interface VVOrmConfig ()
@property (nonatomic, strong) NSArray<VVOrmField *> *manuals;
@property (nonatomic, strong) NSArray<NSString *>   *excludes;
@property (nonatomic, strong) NSArray<NSString *>   *uniques;
@property (nonatomic, assign) BOOL fromTable; //是否是由数据表生成的配置
@end

@implementation VVOrmConfig{
    NSDictionary<NSString *,VVOrmField *> *_fields;
    NSArray<NSString *> *_fieldNames;
    NSMutableDictionary *_privateFields;
}

- (instancetype)init{
    self = [super init];
    if (self) {
        _logAt = YES;
        _privateFields = [NSMutableDictionary dictionaryWithCapacity:0];
    }
    return self;
}

+ (instancetype)configWithTable:(NSString *)tableName
                     inDatabase:(VVDataBase *)vvdb{
    VVOrmConfig *config = [[VVOrmConfig alloc] init];
    config.fromTable    = YES;

    NSString *sql   = [NSString stringWithFormat:@"SELECT count(*) as count FROM sqlite_sequence WHERE name = \"%@\"",tableName];
    NSArray *cols   = [vvdb executeQuery:sql];
    NSInteger count = 0;
    if (cols.count > 0) {
        NSDictionary *dic = cols.firstObject;
        count = [dic[@"count"] integerValue];
    }
    NSString *tableInfoSql      = [NSString stringWithFormat:@"PRAGMA table_info(\"%@\");",tableName];
    NSArray *infos              = [vvdb executeQuery:tableInfoSql];
    NSMutableDictionary *fields = [NSMutableDictionary dictionaryWithCapacity:0];
    NSMutableArray *uniques     = [NSMutableArray arrayWithCapacity:0];
    for (NSDictionary *dic in infos) {
        VVOrmField *field = [VVOrmField fieldWithDictionary:dic];
        if(field.pk) {
            config.primaryKey = field.name;
            if(count == 1) { field.pk = 2; } // 自增主键
        }
        fields[field.name] = field;
    }
    NSString *indexListSql = [NSString stringWithFormat:@"PRAGMA index_list(\"%@\");",tableName];
    NSArray *indexList = [vvdb executeQuery:indexListSql];
    for (NSDictionary *indexDic in indexList) {
        NSString *indexName    = indexDic[@"name"];
        NSString *indexInfoSql = [NSString stringWithFormat:@"PRAGMA index_info(\"%@\");",indexName];
        NSArray *indexInfos    = [vvdb executeQuery:indexInfoSql];
        for (NSDictionary *indexInfo in indexInfos) {
            NSString *name     = indexInfo[@"name"];
            VVOrmField *field  = fields[name];
            field.unique       = [indexDic[@"unique"] boolValue];
            field.indexed      = [indexName hasPrefix:@"sqlite_autoindex_"] ? NO : YES;
            if(field.unique) {[uniques addObject:field.name];}
        }
    }
    config->_fields = fields;
    config->_uniques = uniques.copy;
    return config;
}

+ (instancetype)prepareWithClass:(Class)cls{
    VVOrmConfig *config = [[VVOrmConfig alloc] init];
    config.cls = cls;
    return config;
}

- (BOOL)compareWithConfig:(VVOrmConfig *)config indexChanged:(BOOL *)indexChanged{
    // 比较fields
    if(self.fields.count != config.fields.count ||
       self.logAt        != config.logAt        ||
       (self.primaryKey.length   > 0 && ![self.primaryKey   isEqualToString:config.primaryKey]) ||
       (self.ftsModule.length    > 0 && ![self.ftsModule    isEqualToString:config.ftsModule])  ||
       (self.ftsTokenizer.length > 0 && ![self.ftsTokenizer isEqualToString:config.ftsTokenizer]))
    {
        *indexChanged = YES;
        return NO;
    }
    
    NSMutableArray *compared = [NSMutableArray arrayWithCapacity:0];
    for (NSString *name in self.fields) {
        VVOrmField *field1 = self.fields[name];
        VVOrmField *field2 = config.fields[name];
        if(![field1 isEqualToField:field2]) { return NO; }
        if(field1.indexed != field2.indexed) { *indexChanged = YES; }
        [compared addObject:name];
    }
    NSMutableDictionary *remained = config.fields.mutableCopy;
    [remained removeObjectsForKeys:compared];
    return remained.count == 0;
}

//MARK: - 懒加载
- (NSDictionary<NSString *,VVOrmField *> *)fields{
    if(_fields){
        VVClassInfo *classInfo = [VVClassInfo classInfoWithClass:_cls];
        for (NSString *propertyName in classInfo.propertyInfos) {
            if([_excludes containsObject:propertyName]) continue;
            VVOrmField *field = _privateFields[propertyName] ? _privateFields[propertyName] : [VVOrmField new];
            field.name = propertyName;
            field.type = field.type.length > 0 ? field.type : [self sqliteTypeForPropertyInfo:classInfo.propertyInfos[propertyName]];
            _privateFields[field.name] = field;
        }
        if(_logAt){
            VVOrmField *createAt = VVFIELD_PK(kVsCreateAt); createAt.type = @"REAL";
            VVOrmField *updateAt = VVFIELD_PK(kVsUpdateAt); updateAt.type = @"REAL";
            _privateFields[kVsCreateAt] = createAt;
            _privateFields[kVsUpdateAt] = updateAt;
        }
        [_privateFields removeObjectsForKeys:_excludes];
        _fields = _privateFields.copy;
    }
    return _fields;
}

- (NSArray<NSString *> *)fieldNames{
    if(!_fieldNames){
        _fieldNames = self.fields.allKeys;
    }
    return _fieldNames;
}

//MARK: - setter
- (void)setCls:(Class)cls{
    _cls = cls;
    if(!_fromTable){
        _privateFields = [NSMutableDictionary dictionaryWithCapacity:0];
        [self resetFields];
    }
}

- (void)setPrimaryKey:(NSString *)primaryKey{
    _primaryKey = primaryKey;
    _privateFields[primaryKey] = VVFIELD_PK(primaryKey);
    [self resetFields];
}

- (void)setUniques:(NSArray *)uniques{
    _uniques = uniques;
    for (NSString *field in uniques) {
        _privateFields[field] = VVFIELD_UNIQUE(field);
    }
    [self resetFields];
}

- (void)setExcludes:(NSArray *)excludes{
    _excludes = excludes;
    [self resetFields];
}

- (void)setManuals:(NSArray *)manuals{
    _manuals = manuals;
    for (VVOrmField *field in manuals) {
        _privateFields[field.name] = field;
    }
    [self resetFields];
}

- (void)setLogAt:(BOOL)logAt{
    _logAt = logAt;
    [self resetFields];
}

//MARK: - 链式调用
- (instancetype)primaryKey:(NSString *)primaryKey{
    self.primaryKey = primaryKey;
    return self;
}

- (instancetype)uniques:(NSArray<NSString *> *)uniques{
    self.uniques = uniques;
    return self;
}

- (instancetype)excludes:(NSArray<NSString *> *)excludes{
    self.excludes = excludes;
    return self;
}

- (instancetype)manuals:(NSArray<VVOrmField *> *)manuals{
    self.manuals = manuals;
    return self;
}

- (instancetype)logAt:(BOOL)logAt{
    self.logAt = logAt;
    return self;
}

- (instancetype)ftsModule:(NSString *)ftsModule tokenizer:(NSString *)tokenizer{
    self.ftsModule = ftsModule;
    self.ftsTokenizer = tokenizer;
    return self;
}

//MARK: - Private
- (void)resetFields{
    if(!_fromTable){
        _fields = nil;
        _fieldNames = nil;
    }
}

- (NSString *)sqliteTypeForPropertyInfo:(VVPropertyInfo *)propertyInfo{
    NSString *type = VVSqlTypeText;
    switch (propertyInfo.type) {
            case VVEncodingTypeCNumber:
            type = VVSqlTypeInteger;
            break;
            case VVEncodingTypeCRealNumber:
            type = VVSqlTypeReal;
            break;
            case VVEncodingTypeObject:{
                switch (propertyInfo.nsType) {
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
