//
//  VVOrmField.h
//  VVSequelize
//
//  Created by Jinbo Li on 2018/9/10.
//

#import <Foundation/Foundation.h>

// 使用宏定义字段配置
#define VVFIELD_PK(name)               [[VVOrmField alloc] initWithName:(name) pk:YES notnull:NO  unique:NO  indexed:NO  dflt_value:nil]
#define VVFIELD_PK_NOTNULL(name)       [[VVOrmField alloc] initWithName:(name) pk:YES notnull:YES unique:NO  indexed:NO  dflt_value:nil]
#define VVFIELD(name)                  [[VVOrmField alloc] initWithName:(name) pk:NO  notnull:NO  unique:NO  indexed:NO  dflt_value:nil]
#define VVFIELD_NOTNULL(name)          [[VVOrmField alloc] initWithName:(name) pk:NO  notnull:YES unique:NO  indexed:NO  dflt_value:nil]
#define VVFIELD_UNIQUE(name)           [[VVOrmField alloc] initWithName:(name) pk:NO  notnull:NO  unique:YES indexed:YES dflt_value:nil]
#define VVFIELD_INDEXED(name)          [[VVOrmField alloc] initWithName:(name) pk:NO  notnull:NO  unique:NO  indexed:YES dflt_value:nil]
#define VVFIELD_UNIQUE_NOTNULL(name)   [[VVOrmField alloc] initWithName:(name) pk:NO  notnull:YES unique:YES indexed:YES dflt_value:nil]
#define VVFIELD_INDEXED_NOTNULL(name)  [[VVOrmField alloc] initWithName:(name) pk:NO  notnull:YES unique:NO  indexed:YES dflt_value:nil]
#define VVFIELD_UNIQUE_DFLV(name,dfl)  [[VVOrmField alloc] initWithName:(name) pk:NO  notnull:NO  unique:YES indexed:YES dflt_value:(dfl)]
#define VVFIELD_INDEXED_DFLV(name,dfl) [[VVOrmField alloc] initWithName:(name) pk:NO  notnull:NO  unique:NO  indexed:YES dflt_value:(dfl)]
#define VVFIELD_FTS_UNINDEXED(name)    [[VVOrmField alloc] initWithName:(name) fts_unindexed:NO]

/**
 数据表每个字段的配置. 
 */
@interface VVOrmField: NSObject
@property (nonatomic, copy  ) NSString *name;     ///< 字段名
@property (nonatomic, assign) NSUInteger pk;      ///< 0-不是主键,1-普通主键,2-自增主键
@property (nonatomic, assign) BOOL notnull;       ///< 是否不为空,默认为NO(可为空)
@property (nonatomic, assign) BOOL unique;        ///< 是否唯一
@property (nonatomic, assign) BOOL indexed;       ///< 是否建立索引
@property (nonatomic, assign) BOOL fts_unindexed; ///< 在FTS表中不进行索引,仅在FTS表中有效,默认为YES
@property (nonatomic, copy  , nullable) NSString *type;       ///< 字段类型: TEXT,INTEGER,REAL,BLOB,可加长度限制
@property (nonatomic, strong, nullable) NSString *dflt_value; ///< 默认值

/**
 生成字段配置
 
 @param dictionary 格式:{"name":"xxx","type":"TEXT","unique":@(YES),"notnull":@(YES),....}
 @return 字段配置
 */
+ (instancetype)fieldWithDictionary:(NSDictionary *)dictionary;

/**
 生成字段配置. type默认由class属性生成,check约束默认为nil,若要自定义请单独赋值.
 
 @param name 字段名
 @param pk 是否主键
 @param notnull 是否非空字段
 @param unique 是否唯一
 @param indexed 是否索引
 @param dflt_value 默认值
 @return 字段配置
 */
- (instancetype)initWithName:(NSString *)name
                          pk:(BOOL)pk
                     notnull:(BOOL)notnull
                      unique:(BOOL)unique
                     indexed:(BOOL)indexed
                  dflt_value:(nullable NSString *)dflt_value;

- (instancetype)initWithName:(NSString *)name
               fts_unindexed:(BOOL)fts_unindexed;

/**
 比较两个字段配置是否相同
 
 @param field 要比较的字段配置
 @return 是否相同
 */
- (BOOL)isEqualToField:(VVOrmField *)field;
@end
