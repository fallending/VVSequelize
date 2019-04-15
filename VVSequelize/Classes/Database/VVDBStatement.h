//
//  VVSequelizeStatement.h
//  VVSequelize
//
//  Created by Valo on 2019/3/19.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class VVDatabase, VVDBStatement;

/**
 sqlit3_stmt游标,用于绑定数据,读取数据
 */
@interface VVDBCursor : NSObject
- (instancetype)initWithStatement:(VVDBStatement *)statement;

- (id)objectAtIndexedSubscript:(NSUInteger)idx;
- (void)setObject:(id)obj atIndexedSubscript:(NSUInteger)idx;

- (id)objectForKeyedSubscript:(NSString *)key;
- (void)setObject:(id)obj forKeyedSubscript:(NSString *)key;

@end

/**
 sqlite3_stmt封装类
 */
@interface VVDBStatement : NSObject
/**
 查询/绑定数据的行数
 */
@property (nonatomic, assign, readonly) int columnCount;
/**
 查询/绑定数据的字段名称
 */
@property (nonatomic, strong, readonly) NSArray<NSString *> *columnNames;
/**
 游标
 */
@property (nonatomic, strong, readonly) VVDBCursor *cursor;

/**
 生成VVDBStatement对象,有缓存机制
 
 @param vvdb 数据库
 @param sql 原生sql语句
 @return VVDBStatement对象
 */
+ (instancetype)statementWithDatabase:(VVDatabase *)vvdb sql:(NSString *)sql;

/**
 初始化VVDBStatement对象
 
 @param vvdb 数据库
 @param sql 原生sql语句
 @return VVDBStatement对象
 */
- (instancetype)initWithDatabase:(VVDatabase *)vvdb sql:(NSString *)sql;

/**
 绑定数据
 
 @param values 数据数组,和`columnNames`一一对应
 @return 当前VVDBStatement对象
 */
- (VVDBStatement *)bind:(nullable NSArray *)values;

/**
 绑定数据
 
 @param keyValues 键值对数据
 @return 当前VVDBStatement对象
 */
- (VVDBStatement *)bindKeyValues:(nullable NSDictionary<NSString *, id> *)keyValues;

- (id)scalar:(nullable NSArray *)values;

- (id)scalarKeyValues:(nullable NSDictionary<NSString *, id> *)keyValues;

/**
 执行sqlite3_stmt
 
 @return 是否执行成功
 */
- (BOOL)run;

/**
 执行sqlite3_stmt查询操作
 
 @return 查询结果
 */
- (nullable NSArray<NSDictionary *> *)query;

/**
 执行sqlite3_step()
 
 @return 是否执行成功
 */
- (BOOL)step;

/**
 重置sqlite3_stmt,并重置绑定数据
 */
- (void)reset;

/**
 重置sqlite3_stmt
 
 @param shouldClear 是否重置绑定数据
 */
- (void)reset:(BOOL)shouldClear;

@end

NS_ASSUME_NONNULL_END
