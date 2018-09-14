//
//  VVOrmModel+Delete.h
//  VVSequelize
//
//  Created by Jinbo Li on 2018/9/12.
//

#import "VVOrmModel.h"

@interface VVOrmModel (Delete)
/**
 删除表
 
 @return 是否删除成功
 @warning 删除表后请将ORM置为nil.通常情况下,请不要进行删除表操作.
 */
- (BOOL)drop;

/**
 删除一条数据
 
 @param object 要删除的数据
 @return 是否删除成功
 */
- (BOOL)deleteOne:(nonnull id)object;

/**
 删除多条数据
 
 @param objects 要删除的数据
 @return 成功删除的数量
 */
- (NSUInteger)deleteMulti:(nullable NSArray *)objects;

/**
 根据条件删除数据
 
 @param condition 查询条件,格式详见VVSqlGenerator
 @return 是否删除成功
 */
- (BOOL)delete:(nullable id)condition;

@end
