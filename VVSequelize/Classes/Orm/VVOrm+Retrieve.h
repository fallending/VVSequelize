//
//  VVOrm+Retrieve.h
//  VVSequelize
//
//  Created by Valo on 2018/9/12.
//

#import "VVOrm.h"

NS_ASSUME_NONNULL_BEGIN

@interface VVOrm (Retrieve)

/**
 查询一条数据
 
 @param condition 查询条件
 @return 查询结果,对象
 @see findAll:distinct:fields:groupBy:having:orderBy:limit:offset:
 */
- (nullable id)findOne:(nullable VVExpr *)condition;

/**
 查询一条数据
 
 @param condition 查询条件
 @param orderBy 排序条件
 @return 查询结果,对象
 @see findAll:distinct:fields:groupBy:having:orderBy:limit:offset:
 */
- (nullable id)findOne:(nullable VVExpr *)condition
               orderBy:(nullable VVOrderBy *)orderBy;

/**
 根据条件查询所有数据
 
 @param condition 查询条件
 @return 查询结果,对象数组
 @see findAll:distinct:fields:groupBy:having:orderBy:limit:offset:
 */
- (NSArray *)findAll:(nullable VVExpr *)condition;

/**
 根据条件查询数据
 
 @param condition 查询条件
 @param orderBy 排序条件
 @param limit 数据条数,为0时不做限制
 @param offset 数据起始位置
 @return 查询结果,对象数组
 @see findAll:distinct:fields:groupBy:having:orderBy:limit:offset:
 */
- (NSArray *)findAll:(nullable VVExpr *)condition
             orderBy:(nullable VVOrderBy *)orderBy
               limit:(NSUInteger)limit
              offset:(NSUInteger)offset;

/**
 根据条件查询数据
 
 @param condition 查询条件
 @param groupBy 分组条件
 @param limit 数据条数,为0时不做限制
 @param offset 数据起始位置
 @see findAll:distinct:fields:groupBy:having:orderBy:limit:offset:
 */
- (NSArray *)findAll:(nullable VVExpr *)condition
             groupBy:(nullable VVGroupBy *)groupBy
               limit:(NSUInteger)limit
              offset:(NSUInteger)offset;

/**
 根据条件查询数据
 
 @param condition 查询条件.
 1.NSString,原生sql,可传入`where`及之后的所有语句
 2.NSDictionary,非套嵌,key和value用`=`连接,不同的key value用`and`连接
 3.NSArray,非套嵌的dictionary数组, 每个dictionary用`or`连接
 
 @param distinct 是否过滤重复结果
 
 @param fields 指定查询的字段.
 1. string: `"field1","field2",...`, `count(*) as count`, ...
 2. array: ["field1","field2",...]
 
 @param groupBy 分组条件
 1. string: "field1","field2",...
 2. array: ["field1","field2",...]
 
 @param having 分组过滤条件, 和condition一致
 
 @param orderBy 排序条件
 1. string: "field1 asc","field1,field2 desc","field1 asc,field2,field3 desc",...
 2. array: ["field1 asc","field2,field3 desc",...]
 
 @param limit 数据条数,为0时不做限制
 @param offset 数据起始位置
 
 @return 查询结果,对象数组.若指定了fields,则可能返回字典数组
 
 @note 定义ORM时允许记录时间,则字典数组可能会包含vv_createAt, vv_updateAt
 */
- (NSArray *)findAll:(nullable VVExpr *)condition
            distinct:(BOOL)distinct
              fields:(nullable VVFields *)fields
             groupBy:(nullable VVGroupBy *)groupBy
              having:(nullable VVExpr *)having
             orderBy:(nullable VVOrderBy *)orderBy
               limit:(NSUInteger)limit
              offset:(NSUInteger)offset;

/**
 根据条件统计数据条数
 
 @param condition 查询条件
 @return 数据条数
 @see findAll:distinct:fields:groupBy:having:orderBy:limit:offset:
 */
- (NSInteger)count:(nullable VVExpr *)condition;

/**
 检查数据库中是否保存有某个数据
 
 @param object 数据对象
 @return 是否存在
 */
- (BOOL)isExist:(nonnull id)object;

/**
 根据条件查询数据和数据数量.数量只根据查询条件获取,不受range限制.
 
 @param condition 查询条件
 @param orderBy 排序方式
 @param limit 数据条数,为0时不做限制
 @param offset 数据起始位置
 @return 数据(对象数组)和数据数量,格式:{"count":100,list:[object]}
 @see findAll:distinct:fields:groupBy:having:orderBy:limit:offset:
 */
- (NSDictionary *)findAndCount:(nullable VVExpr *)condition
                       orderBy:(nullable VVOrderBy *)orderBy
                         limit:(NSUInteger)limit
                        offset:(NSUInteger)offset;

/**
 最大行号`max(rowid)`
 
 @return 最大行号
 @discussion 此处取`max(rowid)`可以做唯一值, `max(rowid) + 1`为下一条将插入的数据的自动主键值.
 */
- (NSUInteger)maxRowid;

/**
 获取某个字段的最大值
 
 @param field 字段名
 @param condition 查询条件
 @return 最大值.因Text也可以计算最大值,故返回值为id类型
 @see findAll:distinct:fields:groupBy:having:orderBy:limit:offset:
 */
- (id)max:(nonnull NSString *)field condition:(nullable VVExpr *)condition;

/**
 获取某个字段的最小值
 
 @param field 字段名
 @param condition 查询条件
 @return 最小值.因Text也可以计算最小值,故返回值为id类型
 @see findAll:distinct:fields:groupBy:having:orderBy:limit:offset:
 */
- (id)min:(nonnull NSString *)field condition:(nullable VVExpr *)condition;

/**
 获取某个字段的求和
 
 @param field 字段名
 @param condition 查询条件
 @return 求和
 @see findAll:distinct:fields:groupBy:having:orderBy:limit:offset:
 */
- (id)sum:(nonnull NSString *)field condition:(nullable VVExpr *)condition;

@end

NS_ASSUME_NONNULL_END
