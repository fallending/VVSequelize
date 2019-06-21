//
//  VVDatabase+Additions.h
//  VVSequelize
//
//  Created by Valo on 2019/3/27.
//

#import "VVDatabase.h"

NS_ASSUME_NONNULL_BEGIN

@interface VVDatabase (Additions)
// MARK: - pool
/**
 打开/创建数据库.

 优先从数据库pool中读取,若不存在才会创建.保证一个数据库文件仅一个连接.

 @param path 数据库文件完整路径
 @return 数据库对象
 */
+ (instancetype)databaseInPoolWithPath:(nullable NSString *)path;

/**
 打开/创建数据库.

 优先从数据库pool中读取,若不存在才会创建.保证一个数据库文件仅一个连接.

 @param path 数据库文件完整路径
 @param flags sqlite3_open_v2第三个参数为 (flags | VVDBEssentialFlags)
 @return 数据库对象
 */
+ (instancetype)databaseInPoolWithPath:(nullable NSString *)path
                                 flags:(int)flags;

/**
 打开/创建数据库.

 优先从数据库pool中读取,若不存在才会创建.保证一个数据库文件仅一个连接.

 @param path 数据库文件完整路径
 @param flags sqlite3_open_v2第三个参数为 (flags | VVDBEssentialFlags)
 @param key 加密key
 @return 数据库对象
 */
+ (instancetype)databaseInPoolWithPath:(nullable NSString *)path
                                 flags:(int)flags
                               encrypt:(nullable NSString *)key;

// MARK: - queue
/**
 同步, 在<当前线程><串行>执行

 @param block 读取操作
 */
+ (void)sync:(void (^)(void))block;

/**
 异步操作
 
 @param serial 是否串行. YES-在<一个子线程>中<串行>执行, NO-在<多个子线程>中<并行>执行
 @param block 读取操作
 */
+ (void)async:(BOOL)serial block:(void (^)(void))block;

@end

NS_ASSUME_NONNULL_END
