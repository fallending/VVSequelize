//
//  VVOrmModel+Create.h
//  VVSequelize
//
//  Created by Jinbo Li on 2018/9/12.
//

#import "VVOrmModel.h"

@interface VVOrmModel (Create)
/**
 新增一条数据,对象或字典
 
 @param object 要新增的数据对象,对象或字典
 @return 是否新增成功
 */
-(BOOL)insertOne:(nonnull id)object;

/**
 新增多条数据
 
 @param objects 要新增的数据,数据/字典/混合数组
 @return 新增成功的条数
 @note 每条数据依次插入
 @warning 若insert大量数据,请放入事务中进行操作
 */
-(NSUInteger)insertMulti:(nullable NSArray *)objects;

@end
