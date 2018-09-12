//
//  VVOrmField.m
//  VVSequelize
//
//  Created by Jinbo Li on 2018/9/10.
//

#import "VVOrmField.h"


@implementation VVOrmField
- (BOOL)notnull{
    return _pk ? YES : _notnull; // 如果是主键,则不能为空值
}

- (BOOL)indexed{
    return (!_pk && _unique) ? YES : _indexed;  // 唯一约束会被索引
}

+ (instancetype)fieldWithDictionary:(NSDictionary *)dictionary{
    NSString *name = dictionary[@"name"];
    if(!name || name.length == 0) return nil;
    VVOrmField *field = [[VVOrmField alloc] initWithName:name
                                                      pk:[dictionary[@"pk"] integerValue]
                                                 notnull:[dictionary[@"notnull"] boolValue]
                                                  unique:[dictionary[@"unique"] boolValue]
                                                 indexed:[dictionary[@"indexed"] boolValue]
                                              dflt_value:dictionary[@"dflt_value"]];
    field.type  = dictionary[@"type"];
    return field;
}

- (instancetype)init{
    self = [super init];
    if (self) {
        _fts_unindexed = YES;
    }
    return self;
}

- (instancetype)initWithName:(NSString *)name
                          pk:(BOOL)pk
                     notnull:(BOOL)notnull
                      unique:(BOOL)unique
                     indexed:(BOOL)indexed
                  dflt_value:(NSString *)dflt_value
{
    self = [self init];
    if (self) {
        _name       = name;
        _pk         = pk;
        _notnull    = notnull;
        _unique     = _pk ? YES : unique;
        _dflt_value = !dflt_value || [dflt_value isKindOfClass:NSNull.class] ? nil : [NSString stringWithFormat:@"%@",dflt_value];
        _indexed    = (!_pk && _unique) ? YES : indexed;
    }
    return self;
}

- (instancetype)initWithName:(NSString *)name
               fts_unindexed:(BOOL)fts_unindexed{
    self = [self init];
    if (self) {
        _name          = name;
        _fts_unindexed = fts_unindexed;
    }
    return self;
}

/**
 比较字段配置.不比较indexed,check,因为索引可以单独创建和删除,不影响表结构,而check暂未找到方法从表结构中获取.
 
 @param field 用于比较的字段配置
 @return 配置是否相同
 */
- (BOOL)isEqualToField:(VVOrmField *)field{
    return [self.name isEqualToString:field.name]
    && [self.type.uppercaseString isEqualToString:field.type.uppercaseString]
    && [self.dflt_value isEqualToString:field.dflt_value]
    && self.pk      == field.pk
    && self.notnull == field.notnull
    && self.unique  == field.unique
    && self.fts_unindexed  == field.fts_unindexed;
}

@end
