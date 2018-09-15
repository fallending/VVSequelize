//
//  VVOrm+Update.h
//  VVSequelize
//
//  Created by Jinbo Li on 2018/9/12.
//

#import "VVOrm.h"

@interface VVOrm (Update)
/**
 根据条件更新数据
 
 @param condition 查询条件
 1.支持原生sql,可传入`where`及之后的所有语句
 2.非套嵌的dictionary,key和value用`=`连接,不同的key value用`and`连接
 3.非套嵌的dictionary数组, 每个dictionary用`or`连接

 @param values 要设置的数据,格式为非套嵌的字典:{"field1":data1,"field2":data2,...}
 @return 是否更新成功
 */
- (BOOL)update:(nullable id)condition
        values:(nonnull NSDictionary *)values;

/**
 更新一条数据,更新不成功不会插入新数据.
 
 @param object 要更新的数据,对象或数组
 @return 是否更新成功
 */
- (BOOL)updateOne:(nonnull id)object;

/**
 更新一条数据,更新不成功不会插入新数据.
 
 @param object 要更新的数据,对象或数组
 @param fields 只更新某些字段
 @return 是否更新成功
 */
- (BOOL)updateOne:(nonnull id)object fields:(nullable NSArray<NSString *> *)fields;

/**
 更新多条数据,更新不成功不会插入新数据.
 
 @param objects 要更新的数据
 @param fields 只更新某些字段
 @return 更新成功的条数
 @note 每条数据依次更新
 @warning 若update大量数据,请放入事务中进行操作
 */
- (NSUInteger)updateMulti:(nullable NSArray *)objects fields:(nullable NSArray<NSString *> *)fields;
/**
 更新多条数据,更新不成功不会插入新数据.
 
 @param objects 要更新的数据
 @return 更新成功的条数
 @note 每条数据依次更新
 @warning 若update大量数据,请放入事务中进行操作
 */
- (NSUInteger)updateMulti:(nullable NSArray *)objects;

/**
 将某个字段的值增加某个数值
 
 @param condition 查询条件
 1.支持原生sql,可传入`where`及之后的所有语句
 2.非套嵌的dictionary,key和value用`=`连接,不同的key value用`and`连接
 3.非套嵌的dictionary数组, 每个dictionary用`or`连接
 
 @param field 要更新的指端
 @param value 要增加的值,可为负数
 @return 是否增加成功
 */
- (BOOL)increase:(nullable id)condition
           field:(nonnull NSString *)field
           value:(NSInteger)value;

@end
