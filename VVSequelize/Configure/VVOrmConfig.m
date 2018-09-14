//
//  VVOrmConfig.m
//  VVSequelize
//
//  Created by Jinbo Li on 2018/9/10.
//

#import "VVOrmConfig.h"
#import "VVSequelize.h"
#import "VVClassInfo.h"
#import "NSString+VVOrmModel.h"

#define VVSqlTypeInteger @"INTEGER"
#define VVSqlTypeText    @"TEXT"
#define VVSqlTypeBlob    @"BLOB"
#define VVSqlTypeReal    @"REAL"

@interface VVPropertyInfo (VVOrmConfig)
- (NSString *)sqlType;
@end

@implementation VVPropertyInfo (VVOrmConfig)
- (NSString *)sqlType{
    NSString *type = VVSqlTypeText;
    switch (self.type) {
            case VVEncodingTypeCNumber:
            type = VVSqlTypeInteger;
            break;
            case VVEncodingTypeCRealNumber:
            type = VVSqlTypeReal;
            break;
            case VVEncodingTypeObject:{
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
@property (nonatomic, strong) NSArray<VVOrmField *> *manuals;
@property (nonatomic, strong) NSArray<NSString *>   *whiteList;
@property (nonatomic, strong) NSArray<NSString *>   *blackList;
@property (nonatomic, assign) BOOL fromTable; //是否是由数据表生成的配置

@end

@implementation VVOrmConfig{
    NSDictionary<NSString *,VVOrmField *> *_fields;
    NSArray<NSString *> *_fieldNames;
    NSMutableDictionary *_privateFields;
    NSString *_ftsModule; // FTS模块名
}

- (instancetype)init{
    self = [super init];
    if (self) {
        _privateFields = [NSMutableDictionary dictionaryWithCapacity:0];
    }
    return self;
}

+ (BOOL)isFtsTable:(NSString *)tableName database:(VVDataBase *)vvdb{
    NSString *sql = [NSString stringWithFormat:@"SELECT * as count FROM sqlite_master WHERE tbl_name = \"%@\" AND type = \"table\"",tableName];
    NSArray *cols = [vvdb executeQuery:sql];
    if(cols.count != 1) return nil;
    NSDictionary *dic = cols.firstObject;
    NSString *tableSQL = dic[@"sql"];
    return [tableSQL isMatchRegex:@"CREATE +VIRTUAL +TABLE"];
}

+ (instancetype)configWithTable:(NSString *)tableName
                       database:(VVDataBase *)vvdb{
    if(![vvdb isTableExist:tableName]) return nil;
    VVOrmConfig *config = nil;
    BOOL isFtsTable = [self isFtsTable:tableName database:vvdb];
    if(isFtsTable){
        config = [self configWithNormalTable:tableName database:vvdb];
    }
    else{
        config = [self configWithFtsTable:tableName database:vvdb];
    }
    return config;
}

+ (instancetype)configWithNormalTable:(NSString *)tableName database:(VVDataBase *)vvdb{
    VVOrmConfig *config = [[VVOrmConfig alloc] init];
    config.fromTable = YES;

    // count > 1 时,表示主键为自增类型主键
    NSInteger count = 0;
    if([vvdb isTableExist:@"sqlite_sequence"]){
        NSString *sql   = [NSString stringWithFormat:@"SELECT count(*) as count FROM sqlite_sequence WHERE name = \"%@\"",tableName];
        NSArray *cols   = [vvdb executeQuery:sql];
        if (cols.count > 0) {
            NSDictionary *dic = cols.firstObject;
            count = [dic[@"count"] integerValue];
        }
    }
    
    // 获取表的每个字段配置
    NSString *tableInfoSql      = [NSString stringWithFormat:@"PRAGMA table_info(\"%@\");",tableName];
    NSArray *infos              = [vvdb executeQuery:tableInfoSql];
    NSMutableDictionary *fields = [NSMutableDictionary dictionaryWithCapacity:0];
    NSMutableArray *uniques     = [NSMutableArray arrayWithCapacity:0];
    for (NSDictionary *dic in infos) {
        VVOrmField *field = [VVOrmField fieldWithDictionary:dic];
        if(field.pk) {
            config.primaryKey = field.name;
            if(count == 1) { field.pk = VVOrmPkAutoincrement; } // 自增主键
        }
        fields[field.name] = field;
    }
    // 获取表的索引字段
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
    config.uniques = uniques.copy;
    config->_fields  = fields;
    config->_logAt   = [fields.allKeys containsObject:kVsCreateAt] && [fields.allKeys containsObject:kVsUpdateAt];
    return config;
}

+ (instancetype)configWithFtsTable:(NSString *)tableName database:(VVDataBase *)vvdb{
    NSString *sql = [NSString stringWithFormat:@"SELECT * as count FROM sqlite_master WHERE tbl_name = \"%@\" AND type = \"table\"",tableName];
    NSArray *cols = [vvdb executeQuery:sql];
    if(cols.count != 1) return nil;
    NSDictionary *dic = cols.firstObject;
    NSString *tableSQL = dic[@"sql"];
    
    NSInteger ftsType = 3;
    if([tableSQL isMatchRegex:@" +fts4"]) ftsType = 4;
    if([tableSQL isMatchRegex:@" +fts5"]) ftsType = 5;
    
    VVOrmConfig *config = [[VVOrmConfig alloc] init];
    config.fromTable = YES;
    
    // 获取表的每个字段配置
    NSString *tableInfoSql      = [NSString stringWithFormat:@"PRAGMA table_info(\"%@\");",tableName];
    NSArray *infos              = [vvdb executeQuery:tableInfoSql];
    NSMutableDictionary *fields = [NSMutableDictionary dictionaryWithCapacity:0];
    NSMutableArray *notindexds  = [NSMutableArray arrayWithCapacity:0];
    for (NSDictionary *dic in infos) {
        VVOrmField *field = [VVOrmField fieldWithDictionary:dic];
        fields[field.name] = field;
        NSString *regex = ftsType == 5 ? [NSString stringWithFormat:@"%@ +UNINDEXED",field.name] : [NSString stringWithFormat:@"UNINDEXED +%@",field.name];
        if([tableSQL isMatchRegex:regex]) {
            field.fts_notindexed = NO;
            [notindexds addObject:field.name];
        }
    }
    config.ftsNotindexeds = notindexds;
    config->_fields      = fields;
    return config;
}

+ (instancetype)configWithClass:(Class)cls{
    VVOrmConfig *config = [[VVOrmConfig alloc] init];
    config.cls = cls;
    return config;
}

- (BOOL)isEqualToConfig:(VVOrmConfig *)config indexChanged:(BOOL *)indexChanged{
    if(self.fts != config.fts) {
        *indexChanged = self.fts;
        return NO;
    }
    if(self.fts){
        *indexChanged = NO;
        if(self.fields.count != config.fields.count ||
           ![self.ftsModule isEqualToString:config.ftsModule] ||
           ![self.ftsTokenizer isEqualToString:config.ftsTokenizer]){
            return NO;
        }
        NSMutableArray *compared = [NSMutableArray arrayWithCapacity:0];
        for (NSString *name in self.fields) {
            VVOrmField *field1 = self.fields[name];
            VVOrmField *field2 = config.fields[name];
            if(field1.fts_notindexed != field2.fts_notindexed ) { return NO; }
            [compared addObject:name];
        }
        NSMutableDictionary *remained = config.fields.mutableCopy;
        [remained removeObjectsForKeys:compared];
        return remained.count == 0;
    }
    else{
        if(self.fields.count != config.fields.count || self.logAt != config.logAt ){
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
}

//MARK: - 懒加载
- (NSDictionary<NSString *,VVOrmField *> *)fields{
    if(!_fields){
        VVClassInfo *classInfo = [VVClassInfo classInfoWithClass:_cls];
        for (NSString *propertyName in classInfo.propertyInfos) {
            VVOrmField *field = _privateFields[propertyName] ? _privateFields[propertyName] : [VVOrmField new];
            field.name = propertyName;
            field.type = field.type.length > 0 ? field.type : [classInfo.propertyInfos[propertyName] sqlType];
            _privateFields[field.name] = field;
        }
        // 处理白名单
        if(_whiteList.count > 0){
            NSMutableDictionary *tmpFields = _privateFields.mutableCopy;
            for(NSString *name in _whiteList){
                tmpFields[name] = _privateFields[name];
            }
            _privateFields = tmpFields;
        }
        // 处理黑名单
        else if(_blackList.count > 0){
            [_privateFields removeObjectsForKeys:_blackList];
        }
        // 是否记录时间
        if(_logAt){
            VVOrmField *createAt = VVFIELD(kVsCreateAt); createAt.type = @"REAL";
            VVOrmField *updateAt = VVFIELD(kVsUpdateAt); updateAt.type = @"REAL";
            _privateFields[kVsCreateAt] = createAt;
            _privateFields[kVsUpdateAt] = updateAt;
        }
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
//MARK: public properties
- (void)setCls:(Class)cls{
    _cls = cls;
    if(_fromTable) return;
    _privateFields = [NSMutableDictionary dictionaryWithCapacity:0];
    [self resetFields];
}

- (void)setFts:(BOOL)fts{
    if(_fromTable) return;
    _fts = fts;
    [self resetFields];
}

- (void)setPrimaryKey:(NSString *)primaryKey{
    if(_fromTable) return;
    _primaryKey = primaryKey;
    _privateFields[primaryKey] = VVFIELD_PK(primaryKey);
    [self resetFields];
}

- (void)setLogAt:(BOOL)logAt{
    if(_fromTable) return;
    _logAt = logAt;
    [self resetFields];
}

//MARK: private properties
- (void)setManuals:(NSArray<VVOrmField *> *)manuals{
    if(_fromTable) return;
    _manuals = manuals;
    for (VVOrmField *field in manuals) {
        _privateFields[field.name] = field;
    }
    [self resetFields];
}

- (void)setWhiteList:(NSArray<NSString *> *)whiteList{
    if(_fromTable) return;
    _whiteList = whiteList;
    [self resetFields];
}

- (void)setBlackList:(NSArray<NSString *> *)blackList{
    if(_fromTable) return;
    _blackList = blackList;
    [self resetFields];
}

//MARK: - 链式调用
- (instancetype)primaryKey:(NSString *)primaryKey{
    self.primaryKey = primaryKey;
    return self;
}

- (instancetype)fts:(BOOL)fts{
    self.fts = fts;
    return self;
}

- (instancetype)whiteList:(NSArray<NSString *> *)whiteList{
    self.whiteList = whiteList;
    return self;
}

- (instancetype)blackList:(NSArray<NSString *> *)blackList{
    self.blackList = blackList;
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

//MARK: - Private
- (void)resetFields{
    _fields = nil;
    _fieldNames = nil;
}

//MARK: - Common
- (void)setUniques:(NSArray<NSString *> *)uniques{
    if(_fromTable) return;
    _uniques = uniques;
    for (NSString *field in uniques) {
        _privateFields[field] = VVFIELD_UNIQUE(field);
    }
    [self resetFields];
}

- (instancetype)uniques:(NSArray<NSString *> *)uniques{
    self.uniques = uniques;
    return self;
}

//MARK: - FTS
-(void)setFtsModule:(NSString *)ftsModule{
    if(_fromTable) return;
    _ftsModule = ftsModule;
}

- (NSString *)ftsModule{
    return _ftsModule.length == 0 ? @"fts4" : _ftsModule;
}

- (void)setFtsTokenizer:(NSString *)ftsTokenizer{
    if(_fromTable) return;
    _ftsTokenizer = ftsTokenizer;
}

- (void)setFtsNotindexeds:(NSArray<NSString *> *)ftsNotindexeds{
    if(_fromTable) return;
    _ftsNotindexeds = ftsNotindexeds;
    [self resetFields];
}

- (instancetype)ftsModule:(NSString *)ftsModule{
    self.ftsModule = ftsModule;
    return self;
}

- (instancetype)ftsTokenizer:(NSString *)ftsTokenizer{
    self.ftsTokenizer = ftsTokenizer;
    return self;
}

- (instancetype)ftsNotindexeds:(NSArray<NSString *> *)ftsNotindexeds{
    self.ftsNotindexeds = ftsNotindexeds;
    return self;
}

@end
