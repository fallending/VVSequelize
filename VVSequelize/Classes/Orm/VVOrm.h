//
//  VVOrm.h
//  VVSequelize
//
//  Created by Valo on 2018/6/6.
//

#import <Foundation/Foundation.h>
#import "VVOrmDefs.h"
#import "VVDatabase.h"
#import "VVOrmConfig.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_OPTIONS (NSUInteger, VVOrmInspection) {
    VVOrmTableExist   = 1 << 0,
    VVOrmTableChanged = 1 << 1,
    VVOrmIndexChanged = 1 << 2,
};

@interface VVOrm : NSObject

@property (nonatomic, strong, readonly) VVOrmConfig *config;    ///< ORM配置
@property (nonatomic, strong, readonly) VVDatabase *vvdb;       ///< 数据库,可执行某些自定义查询/更新
@property (nonatomic, copy, readonly) NSString *tableName;      ///< 表名

- (instancetype)init __attribute__((unavailable("use initWithConfig:tableName:dataBase: instead.")));
+ (instancetype)new __attribute__((unavailable("use initWithConfig:tableName:dataBase: instead.")));

/**
 定义ORM模型,自动创建/修改表和索引,使用临时数据库,默认表名.

 @param config ORM配置
 @return ORM模型
 */
+ (nullable instancetype)ormWithConfig:(VVOrmConfig *)config;

/**
 定义ORM模型,自动创建/修改表和索引,可指定表名和数据库.

 @param config ORM配置
 @param tableName 表名,nil表示使用cls类名
 @param vvdb 数据库,nil表示使用默认数据库
 @return ORM模型
 */
+ (nullable instancetype)ormWithConfig:(VVOrmConfig *)config
                             tableName:(nullable NSString *)tableName
                              dataBase:(nullable VVDatabase *)vvdb;

/**
 定义ORM模型,可指定表名和数据库.

 @param config ORM配置
 @param tableName 表名,nil表示使用cls类名
 @param vvdb 数据库,nil表示使用默认数据库
 @return ORM模型
 @attention 请依次调用`inspectExistingTable`和`setupTableWith:`来创建/修改表和索引.
 */
- (nullable instancetype)initWithConfig:(VVOrmConfig *)config
                              tableName:(nullable NSString *)tableName
                               dataBase:(nullable VVDatabase *)vvdb NS_DESIGNATED_INITIALIZER;

/**
 检查数据库中已存在的表.

 @return 检查结果
 */
- (VVOrmInspection)inspectExistingTable;

/**
 根据检查结果来创建/修改表和索引

 @param inspection 检查结果
 */
- (void)setupTableWith:(VVOrmInspection)inspection;

/**
 获取待处理对象的唯一性约束条件,常用于更新/删除操作

 @param object 传入对象
 @return 唯一性约束条件
 */
- (nullable NSDictionary *)uniqueConditionForObject:(id)object;
@end

NS_ASSUME_NONNULL_END
