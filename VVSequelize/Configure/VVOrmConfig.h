//
//  VVOrmConfig.h
//  VVSequelize
//
//  Created by Jinbo Li on 2018/9/10.
//

#import <Foundation/Foundation.h>
#import "VVOrmField.h"

#define kVsCreateAt     @"vv_createAt"      ///< 数据库字段,数据创建时间
#define kVsUpdateAt     @"vv_updateAt"      ///< 数据库字段,数据更新时间

@class VVDataBase;
@interface VVOrmConfig : NSObject

@property (nonatomic, strong) Class    cls;            ///< 对应的模型(Class)
@property (nonatomic, copy  ) NSString *primaryKey;    ///< 主键名
@property (nonatomic, assign) BOOL     logAt;          ///< 是否自动记录时间,默认为YES
@property (nonatomic, strong, readonly) NSArray *fieldNames;  ///< 所有字段名,格式:[字段名]
@property (nonatomic, strong, readonly) NSDictionary *fields; ///< 字段配置,格式:{字段名:配置}

/**
 从数据表获取配置

 @param tableName 表名
 @param vvdb 数据库
 @return ORM配置
 */
+ (instancetype)configWithTable:(NSString *)tableName
                       database:(VVDataBase *)vvdb;

/**
 初始化ORM配置

 @param cls 数据表要存储的类
 @return ORM配置
 */
+ (instancetype)configWithClass:(Class)cls;

/**
 是否和相比较的ORM配置一致

 @param config 作对比的ORM配置
 @param indexChanged 是否需要更新索引
 @return 是否一致
 */
- (BOOL)isEqualToConfig:(VVOrmConfig *)config indexChanged:(BOOL *)indexChanged;

//MARK: - 链式调用

/**
 设置主键

 @param primaryKey 主键名
 @return ORM配置
 */
- (instancetype)primaryKey:(NSString *)primaryKey;

/**
 配置白名单,数据表中需要保存的字段
 
 @param whiteList 需要保存的字段
 @return ORM配置
 */
- (instancetype)whiteList:(NSArray<NSString *> *)whiteList;

/**
 配置黑名单,数据表中不需要保存的字段.白名单存在时,以白名单为准

 @param blackList 不保存的字段
 @return ORM配置
 */
- (instancetype)blackList:(NSArray<NSString *> *)blackList;

/**
 配置自定义的字段

 @param manuals 配置自定义字段
 @return ORM配置
 */
- (instancetype)manuals:(NSArray<VVOrmField *> *)manuals;

/**
 配置是否记录插入/更新时间

 @param logAt 是否记录插入/更新时间
 @return ORM配置
 */
- (instancetype)logAt:(BOOL)logAt;

@end
