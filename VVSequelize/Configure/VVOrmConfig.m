//
//  VVOrmConfig.m
//  VVSequelize
//
//  Created by Jinbo Li on 2018/9/10.
//

#import "VVOrmConfig.h"
#import "VVClassInfo.h"
#import "VVDataBase.h"
#import "VVOrmCommonConfig.h"
#import "VVOrmFtsConfig.h"
#import "NSString+VVOrmModel.h"

#define VVSqlTypeInteger @"INTEGER"
#define VVSqlTypeText    @"TEXT"
#define VVSqlTypeBlob    @"BLOB"
#define VVSqlTypeReal    @"REAL"

@interface VVOrmConfig ()
@property (nonatomic, strong) NSArray<VVOrmField *> *manuals;
@property (nonatomic, strong) NSArray<NSString *>   *whiteList;
@property (nonatomic, strong) NSArray<NSString *>   *blackList;
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
    VVOrmConfig *config = nil;
    BOOL isFtsTable = [self isFtsTable:tableName database:vvdb];
    if(isFtsTable){
        config = [VVOrmFtsConfig configWithTable:tableName database:vvdb];
    }
    else{
        config = [VVOrmCommonConfig configWithTable:tableName database:vvdb];
    }
    config.fromTable    = YES;
    return config;
}

+ (instancetype)configWithClass:(Class)cls{
    VVOrmConfig *config = [[VVOrmConfig alloc] init];
    config.cls = cls;
    return config;
}

- (BOOL)isEqualToConfig:(VVOrmConfig *)config indexChanged:(BOOL *)indexChanged{
    return NO; // 由子类实现
}

//MARK: - 懒加载
- (NSDictionary<NSString *,VVOrmField *> *)fields{
    if(!_fields){
        VVClassInfo *classInfo = [VVClassInfo classInfoWithClass:_cls];
        for (NSString *propertyName in classInfo.propertyInfos) {
            if([_blackList containsObject:propertyName]) continue;
            VVOrmField *field = _privateFields[propertyName] ? _privateFields[propertyName] : [VVOrmField new];
            field.name = propertyName;
            field.type = field.type.length > 0 ? field.type : [self sqlTypeForProperty:classInfo.propertyInfos[propertyName]];
            _privateFields[field.name] = field;
        }
        if(_logAt){
            VVOrmField *createAt = VVFIELD(kVsCreateAt); createAt.type = @"REAL";
            VVOrmField *updateAt = VVFIELD(kVsUpdateAt); updateAt.type = @"REAL";
            _privateFields[kVsCreateAt] = createAt;
            _privateFields[kVsUpdateAt] = updateAt;
        }
        [_privateFields removeObjectsForKeys:_blackList];
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

- (void)setExcludes:(NSArray *)blackList{
    _blackList = blackList;
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
    if(!_fromTable){
        _fields = nil;
        _fieldNames = nil;
    }
}

- (NSString *)sqlTypeForProperty:(VVPropertyInfo *)property{
    NSString *type = VVSqlTypeText;
    switch (property.type) {
            case VVEncodingTypeCNumber:
            type = VVSqlTypeInteger;
            break;
            case VVEncodingTypeCRealNumber:
            type = VVSqlTypeReal;
            break;
            case VVEncodingTypeObject:{
                switch (property.nsType) {
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
