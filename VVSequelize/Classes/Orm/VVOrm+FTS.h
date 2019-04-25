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

/**
 对FTS结果进行高亮
 
 @param objects 搜索结果,objects
 @param field 要进行高亮处理的字段
 @param keyword 搜索时使用的关键词,去除通配符等
 @param attributes 高亮使用的文字属性
 @return 高亮结果,属性文本数组,顺序对应objects
 */
- (nullable NSArray<NSAttributedString *> *)highlight:(NSArray *)objects
                                                field:(NSString *)field
                                              keyword:(NSString *)keyword
                                           attributes:(NSDictionary<NSAttributedStringKey, id> *)attributes;

/**
 对FTS结果进行高亮
 
 @param objects 搜索结果,objects
 @param field 要进行高亮处理的字段
 @param keyword 搜索时使用的关键词,去除通配符等
 @param pinyinMaxLen 进行拼音分词的最大Unicode长度, `= 0`表示不进行拼音分词高亮, `< 0`则使用默认长度15
 @param attributes 高亮使用的文字属性
 @return 高亮结果,属性文本数组,顺序对应objects
 */
- (nullable NSArray<NSAttributedString *> *)highlight:(NSArray *)objects
                                                field:(NSString *)field
                                              keyword:(NSString *)keyword
                                         pinyinMaxLen:(int)pinyinMaxLen
                                           attributes:(NSDictionary<NSAttributedStringKey, id> *)attributes;

@end

NS_ASSUME_NONNULL_END
