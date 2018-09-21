//
//  VVOrmRoute.h
//  VVSequelize
//
//  Created by Jinbo Li on 2018/9/20.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface VVOrmRoute : NSObject <NSCopying>
@property (nonatomic, copy) NSString *dbPath;
@property (nonatomic, copy) NSString *tableName;
@end

@protocol VVOrmRoute <NSObject>

/**
 根据要插入/更新/删除的单个数据路由到对应的数据库文件和表.通常用于FTS写入数据.

 @param object 要插入/更新/删除的单个数据
 @return 数据库文件和表名的路由
 */
+ (VVOrmRoute *)routeOfObject:(id)object;

/**
 根据要插入/更新/删除的一组数据路由到对应的数据库文件和表.通常用于FTS写入数据.

 @param objects 要插入/更新/删除的一组数据
 @return 路由和数据组成的字典,格式:{route:[object]}
 */
+ (NSDictionary<VVOrmRoute *, id> *)routesOfObjects:(NSArray *)objects;

/**
 根据一个范围由到对应的数据库文件和表.通常用于FTS搜索数据.
 
 @param type 范围类型,可能是id,时间等
 @param start 范围的开始
 @param end 范围的结束
 @return 路由和数据组成的字典,格式:{route:[sub_start,sub_end]}
 */
+ (NSDictionary<VVOrmRoute *, NSArray *> *)routesOfRange:(NSUInteger)type
                                                   start:(id)start
                                                     end:(id)end;

@end

NS_ASSUME_NONNULL_END
