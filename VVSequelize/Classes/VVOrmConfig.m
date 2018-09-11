//
//  VVOrmConfig.m
//  VVSequelize
//
//  Created by Jinbo Li on 2018/9/10.
//

#import "VVOrmConfig.h"
#import "VVClassInfo.h"

#define VVSqlTypeInteger @"INTEGER"
#define VVSqlTypeText    @"TEXT"
#define VVSqlTypeBlob    @"BLOB"
#define VVSqlTypeReal    @"REAL"

@interface VVOrmConfig ()
@property (nonatomic, strong) NSArray *manuals;
@property (nonatomic, strong) NSArray *excludes;
@property (nonatomic, strong) NSArray *uniques;

@end

@implementation VVOrmConfig{
    NSDictionary<NSString *,VVOrmField *> *_fields;
    NSArray<NSString *> *_fieldNames;
    NSMutableDictionary *_tmpFields;
}

- (instancetype)init{
    self = [super init];
    if (self) {
        _logAt = YES;
        _tmpFields = [NSMutableDictionary dictionaryWithCapacity:0];
    }
    return self;
}

+ (instancetype)prepareWithClass:(Class)cls{
    VVOrmConfig *config = [[VVOrmConfig alloc] init];
    config.cls = cls;
    return config;
}

//MARK: - 懒加载
- (NSDictionary<NSString *,VVOrmField *> *)fields{
    if(_fields){
        VVClassInfo *classInfo = [VVClassInfo classInfoWithClass:_cls];
        for (NSString *propertyName in classInfo.propertyInfos) {
            if([_excludes containsObject:propertyName]) continue;
            VVOrmField *field = _tmpFields[propertyName] ? _tmpFields[propertyName] : [VVOrmField new];
            field.name = propertyName;
            field.type = field.type.length > 0 ? field.type : [self sqliteTypeForPropertyInfo:classInfo.propertyInfos[propertyName]];
            _tmpFields[field.name] = field;
        }
        [_tmpFields removeObjectsForKeys:_excludes];
        _fields = _tmpFields.copy;
    }
    return _fields;
}

- (NSArray<NSString *> *)fieldNames{
    if(!_fieldNames){
        _fieldNames = _fields.allKeys;
    }
    return _fieldNames;
}

//MARK: - setter
- (void)setCls:(Class)cls{
    _cls = cls;
    _tmpFields = [NSMutableDictionary dictionaryWithCapacity:0];
    [self resetFields];
}

- (void)setPrimaryKey:(NSString *)primaryKey{
    _primaryKey = primaryKey;
    _tmpFields[primaryKey] = VVFIELD_PK(primaryKey);
    [self resetFields];
}

- (void)setUniques:(NSArray *)uniques{
    _uniques = uniques;
    for (NSString *field in uniques) {
        _tmpFields[field] = VVFIELD_UNIQUE(field);
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
        _tmpFields[field.name] = field;
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
    _fields = nil;
    _fieldNames = nil;
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
