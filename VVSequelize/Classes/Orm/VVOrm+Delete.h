//
//  VVOrm+Delete.h
//  VVSequelize
//
//  Created by Valo on 2018/9/12.
//

#import "VVOrm.h"

@interface VVOrm (Delete)
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

 @param condition 查询条件
 1.支持原生sql,可传入`where`及之后的所有语句
 2.非套嵌的dictionary,key和value用`=`连接,不同的key value用`and`连接
 3.非套嵌的dictionary数组, 每个dictionary用`or`连接

 @return 是否删除成功
 */
- (BOOL)deleteWhere:(nullable VVExpr *)condition;

@end
