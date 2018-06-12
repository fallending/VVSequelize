//
//  VVOrmModel.h
//  Pods
//
//  Created by Jinbo Li on 2018/6/6.
//

#import <Foundation/Foundation.h>
#import "VVFMDB.h"

typedef NS_OPTIONS(NSUInteger, VVOrmOption) {
    VVOrmPrimaryKey = 1 << 0,
    VVOrmUnique = 1 << 1,
    VVOrmNonnull = 1 << 2,
    VVOrmAutoIncrement = 1 << 3,
};


#pragma mark - 定义ORM

@interface VVOrmModel : NSObject

/**
 定义ORM模型.使用默认数据库,默认表名,自动主键.
 
 @param cls 模型(Class)
 @return ORM模型
 */
- (instancetype)initWithClass:(Class)cls;


/**
 定义ORM模型.使用自动主键,无额外选项.
 
 @param cls 模型(Class)
 @param tableName 表名,nil表示使用cls类名
 @param vvfmdb 数据库,nil表示使用默认数据库
 @return ORM模型
 */
- (instancetype)initWithClass:(Class)cls
                    tableName:(nullable NSString *)tableName
                     dataBase:(nullable VVFMDB *)vvfmdb;

/**
 定义ORM模型
 
 @param cls 模型(Class)
 @param fields 自定义各个字段的配置,格式@{@"field1":@(VVOrmOption),@"field2":@(VVOrmOption),...}}
 @param excludes 不存入数据表的字段名
 @param tableName 表名,nil表示使用cls类名
 @param vvfmdb 数据库,nil表示使用默认数据库
 @return ORM模型
 */
- (instancetype)initWithClass:(Class)cls
                 fieldOptions:(nullable NSDictionary *)fieldOptions
                     excludes:(nullable NSArray *)excludes
                    tableName:(nullable NSString *)tableName
                     dataBase:(nullable VVFMDB *)vvfmdb;

/**
 删除表
 
 @return 是否删除成功
 */
- (BOOL)dropTable;

/**
 检查数据表是否存在
 
 @return 是否存在
 */
- (BOOL)isTableExist;

/**
 为数据表添加不存在的字段
 
 @param dicOrClass 字典或模型(Class),只添加不存在的字段
 @param options 其他选项:{unique:[field],nonnull:[field],exclude:[field]...}
 @return 是否添加成功
 */
- (BOOL)alterWithDicOrClass:(id)dicOrClass
                    options:(NSDictionary *)options;
@end

#pragma mark - CURD - 创建
@interface VVOrmModel (Create)

@end

#pragma mark - CURD - 更新
@interface VVOrmModel (Update)

@end

#pragma mark - CURD - 读取
@interface VVOrmModel (Retrieve)

- (NSArray *)findAll:(id)where;
- (NSArray *)countAll:(id)where;

@end

#pragma mark - CURD - 删除
@interface VVOrmModel (Delete)

@end

