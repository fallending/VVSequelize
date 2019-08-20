//
//  VVOrm+FTS.h
//  VVSequelize
//
//  Created by Valo on 2018/9/15.
//

#import "VVOrm.h"

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString *const VVOrmFtsCount;

@interface VVOrm (FTS)

/**
 全文搜索
 
 @param condition match匹配表达式,比如:"name:zhan*","zhan*",具体的表达请查看sqlite官方文档
 @param orderBy 排序方式
 @param limit 数据条数,为0时不做限制
 @param offset 数据起始位置
 @return 匹配结果,对象数组,格式:[object]
 */
- (NSArray *)match:(nullable VVExpr *)condition
           orderBy:(nullable VVOrderBy *)orderBy
             limit:(NSUInteger)limit
            offset:(NSUInteger)offset;

/**
 分组全文搜索
 
 @param condition match匹配表达式,比如:"name:zhan*","zhan*",具体的表达请查看sqlite官方文档
 @param groupBy 分组方式
 @param limit 数据条数,为0时不做限制
 @param offset 数据起始位置
 @return 匹配结果,含分组的匹配数量"vvdb_fts_count",格式:[json]
 @note 使用`+vv_objectsWithKeyValuesArray:`获取对象数组,`dic[VVOrmFtsCount]`获取分组匹配数量
 */
- (NSArray *)match:(nullable VVExpr *)condition
           groupBy:(nullable VVGroupBy *)groupBy
             limit:(NSUInteger)limit
            offset:(NSUInteger)offset;

/**
 获取匹配数量
 
 @param condition match匹配表达式,比如:"name:zhan*","zhan*",具体的表达请查看sqlite官方文档
 @return 匹配数量
 */
- (NSUInteger)matchCount:(nullable VVExpr *)condition;

/**
 全文搜索
 
 @param condition match匹配表达式,比如:"name:zhan*","zhan*",具体的表达请查看sqlite官方文档
 @param orderBy 排序方式
 @param limit 数据条数,为0时不做限制
 @param offset 数据起始位置
 @return 匹配结果,数据(对象数组)和数据数量,格式:{"count":100,list:[object]}
 */
- (NSDictionary *)matchAndCount:(nullable VVExpr *)condition
                        orderBy:(nullable VVOrderBy *)orderBy
                          limit:(NSUInteger)limit
                         offset:(NSUInteger)offset;

@end

NS_ASSUME_NONNULL_END
