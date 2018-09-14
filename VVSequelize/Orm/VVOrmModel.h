//
//  VVOrmModel.h
//  VVSequelize
//
//  Created by Jinbo Li on 2018/6/6.
//

#import <Foundation/Foundation.h>
#import "VVDataBase.h"
#import "VVOrmConfig.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, VVOrmAction) {
    VVOrmActionInsert,
    VVOrmActionUpdate,
    VVOrmActionDelete,
};

#define VVRangeAll      NSMakeRange(0, 0)   ///< 数据查询时不限定范围

FOUNDATION_EXPORT NSNotificationName const VVOrmModelDataChangeNotification;    ///< 数据发生变化通知
FOUNDATION_EXPORT NSNotificationName const VVOrmModelDataInsertNotification;    ///< 数据插入成功通知
FOUNDATION_EXPORT NSNotificationName const VVOrmModelDataUpdateNotification;    ///< 数据更新成功通知
FOUNDATION_EXPORT NSNotificationName const VVOrmModelDataDeleteNotification;    ///< 数据删除成功通知
FOUNDATION_EXPORT NSNotificationName const VVOrmModelTableCreatedNotification;  ///< 数据表创建成功通知
FOUNDATION_EXPORT NSNotificationName const VVOrmModelTableDeletedNotification;  ///< 数据表删除成功通知

@interface VVOrmModel : NSObject

@property (nonatomic, strong, readonly) VVOrmConfig *config;    ///< ORM配置
@property (nonatomic, strong, readonly) VVDataBase  *vvdb;      ///< 数据库,可执行某些自定义查询/更新
@property (nonatomic, copy  , readonly) NSString    *tableName; ///< 表名
@property (nonatomic, strong, readonly) NSCache     *cache;     ///< 查询缓存

/**
 定义ORM模型,使用默认数据库,默认表名.
 
 @param config ORM配置
 @return ORM模型
 @discussion 生成的模型将使用dbPath+tableName作为Key,存放至一个模型池中,若下次使用相同的数据库和表名创建模型,将先从模型池中查找.
 */
+ (instancetype)ormModelWithConfig:(VVOrmConfig *)config;

/**
 定义ORM模型,可指定表名和数据库.
 
 @param config ORM配置
 @param tableName 表名,nil表示使用cls类名
 @param vvdb 数据库,nil表示使用默认数据库
 @return ORM模型
 @discussion 生成的模型将使用dbPath+tableName作为Key,存放至一个模型池中,若下次使用相同的数据库和表名创建模型,将先从模型池中查找.
 */
+ (instancetype)ormModelWithConfig:(VVOrmConfig *)config
                         tableName:(nullable NSString *)tableName
                          dataBase:(nullable VVDataBase *)vvdb;

- (void)handleResult:(BOOL)result action:(VVOrmAction)action;

- (NSDictionary *)uniqueConditionForObject:(id)object;
@end

NS_ASSUME_NONNULL_END

