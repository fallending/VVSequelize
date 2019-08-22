//
//  VVSelect.h
//  VVSequelize
//
//  Created by Valo on 2018/9/14.
//

#import "VVOrm.h"

@interface VVSelect : NSObject

@property (nonatomic, copy, readonly) NSString *sql; //根据条件生成SQL语句

/**
 查询结果

 @return 查询结果,对象数组.
 @note 必须设置orm
 */
- (NSArray *)allObjects;

/**
 查询结果

 @return 查询结果,字典数组
 @note 必须设置orm
 */
- (NSArray *)allKeyValues;

//MARK: - 链式调用
/**
 创建VVSelect对象

 @param block 链式调用方式赋值
 @return VVSelect对象
 */
+ (instancetype)makeSelect:(void (^)(VVSelect *make))block;

- (VVSelect *(^)(VVOrm *orm))orm;

- (VVSelect *(^)(NSString *table))table;

- (VVSelect *(^)(BOOL distinct))distinct;

- (VVSelect *(^)(VVFields *fields))fields;

- (VVSelect *(^)(VVExpr *where))where;

- (VVSelect *(^)(VVOrderBy *orderBy))orderBy;

- (VVSelect *(^)(VVGroupBy *groupBy))groupBy;

- (VVSelect *(^)(VVExpr *having))having;

- (VVSelect *(^)(NSUInteger offset))offset;

- (VVSelect *(^)(NSUInteger limit))limit;

@end
