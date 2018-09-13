//
//  VVOrmCommonField.h
//  VVSequelize
//
//  Created by Jinbo Li on 2018/9/13.
//

#import "VVOrmField.h"

// 使用宏定义字段配置
#define VVFIELD_PK(name)               [[VVOrmCommonField alloc] initWithName:(name) pk:YES notnull:NO  unique:NO  indexed:NO  dflt_value:nil]
#define VVFIELD_PK_NOTNULL(name)       [[VVOrmCommonField alloc] initWithName:(name) pk:YES notnull:YES unique:NO  indexed:NO  dflt_value:nil]
#define VVFIELD(name)                  [[VVOrmCommonField alloc] initWithName:(name) pk:NO  notnull:NO  unique:NO  indexed:NO  dflt_value:nil]
#define VVFIELD_NOTNULL(name)          [[VVOrmCommonField alloc] initWithName:(name) pk:NO  notnull:YES unique:NO  indexed:NO  dflt_value:nil]
#define VVFIELD_UNIQUE(name)           [[VVOrmCommonField alloc] initWithName:(name) pk:NO  notnull:NO  unique:YES indexed:YES dflt_value:nil]
#define VVFIELD_INDEXED(name)          [[VVOrmCommonField alloc] initWithName:(name) pk:NO  notnull:NO  unique:NO  indexed:YES dflt_value:nil]
#define VVFIELD_UNIQUE_NOTNULL(name)   [[VVOrmCommonField alloc] initWithName:(name) pk:NO  notnull:YES unique:YES indexed:YES dflt_value:nil]
#define VVFIELD_INDEXED_NOTNULL(name)  [[VVOrmCommonField alloc] initWithName:(name) pk:NO  notnull:YES unique:NO  indexed:YES dflt_value:nil]
#define VVFIELD_UNIQUE_DFLV(name,dfl)  [[VVOrmCommonField alloc] initWithName:(name) pk:NO  notnull:NO  unique:YES indexed:YES dflt_value:(dfl)]
#define VVFIELD_INDEXED_DFLV(name,dfl) [[VVOrmCommonField alloc] initWithName:(name) pk:NO  notnull:NO  unique:NO  indexed:YES dflt_value:(dfl)]

@interface VVOrmCommonField : VVOrmField
@property (nonatomic, assign) VVOrmPkType pk;       ///< 0-不是主键,1-普通主键,2-自增主键
@property (nonatomic, assign) BOOL notnull;         ///< 是否不为空,默认为NO(可为空)
@property (nonatomic, assign) BOOL unique;          ///< 是否唯一
@property (nonatomic, assign) BOOL indexed;         ///< 是否建立索引
@property (nonatomic, copy  ) NSString *dflt_value; ///< 默认值

/**
 生成普通表字段配置. type默认由class属性生成,check约束默认为nil,若要自定义请单独赋值.
 
 @param name 字段名
 @param pk 主键类型,0-不是主键,1-普通主键,2-自增主键
 @param notnull 是否非空字段
 @param unique 是否唯一
 @param indexed 是否索引
 @param dflt_value 默认值
 @return 字段配置
 */
- (instancetype)initWithName:(NSString *)name
                          pk:(VVOrmPkType)pk
                     notnull:(BOOL)notnull
                      unique:(BOOL)unique
                     indexed:(BOOL)indexed
                  dflt_value:(nullable NSString *)dflt_value;

@end
