//
//  NSString+VVClause.h
//  VVSequelize
//
//  Created by Jinbo Li on 2018/9/15.
//

#import <Foundation/Foundation.h>

/**
 组装SQL语句Where子句的辅助分类
 */
@interface NSString (VVClause)

/**
 使用`and`连接

 @param andstr 要连接的字符串
 @return 连接后的语句,如: `(field1 = val1) AND (field2 = val2)`
 */
- (NSString *)and:(NSString *)andstr;

/**
 使用`or`连接
 
 @param orstr 要连接的字符串
 @return 连接后的语句,如: `(field1 = val1) OR (field2 = val2)`
 */
- (NSString *)or:(NSString *)orstr;

/**
 使用`=`连接

 @param eq 等于的值
 @return 连接后的语句,如: `field1 = val1`
 */
- (NSString *)eq:(id)eq;

/**
 使用`!=`连接
 
 @param ne 不等于的值
 @return 连接后的语句,如: `field1 != val1`
 */
- (NSString *)ne:(id)ne;

/**
 使用`>`连接
 
 @param gt 大于的值
 @return 连接后的语句,如: `field1 > val1`
 */
- (NSString *)gt:(id)gt;

/**
 使用`>=`连接
 
 @param gte 大于等于的值
 @return 连接后的语句,如: `field1 >= val1`
 */
- (NSString *)gte:(id)gte;

/**
 使用`<`连接
 
 @param lt 小于的值
 @return 连接后的语句,如: `field1 < val1`
 */
- (NSString *)lt:(id)lt;

/**
 使用`<=`连接
 
 @param lte 小于等于的值
 @return 连接后的语句,如: `field1 <= val1`
 */
- (NSString *)lte:(id)lte;

/**
 使用`is not`连接
 
 @param notval 不等同的值
 @return 连接后的语句,如: `field1 IS NOT val1`
 */
- (NSString *)not:(id)notval;

/**
 使用`between`连接
 
 @param val1 between的前值
 @param val2 between的后值
 @return 连接后的语句,如: `field1 BETWEEN val1,val2`
 */
- (NSString *)between:(id)val1 _:(id)val2;

/**
 使用`not between`连接
 
 @param val1 not between的前值
 @param val2 not between的后值
 @return 连接后的语句,如: `field1 NOT BETWEEN val1,val2`
 */
- (NSString *)notBetween:(id)val1 _:(id)val2;

/**
 使用`in`连接
 
 @param array 包含的值
 @return 连接后的语句,如: `field1 IN (val1,val2,...)`
 */
- (NSString *)in:(id)array;

/**
 使用`not in`连接
 
 @param array 不包含的值
 @return 连接后的语句,如: `field1 NOT IN (val1,val2,...)`
 */
- (NSString *)notIn:(NSArray *)array;

/**
 使用`like`连接
 
 @param like 模糊匹配的值,支持 % 和 _
 @return 连接后的语句,如: `field1 LIKE "val1"`
 */
- (NSString *)like:(id)like;

/**
 使用`not like`连接
 
 @param notLike 模糊不匹配的值,支持 % 和 _
 @return 连接后的语句,如: `field1 NOT LIKE "val1"`
 */
- (NSString *)notLike:(id)notLike;

/**
 使用`glob`连接
 
 @param glob 模糊匹配的值,支持 * 和 ?
 @return 连接后的语句,如: `field1 GLOB "val1"`
 */
- (NSString *)glob:(id)glob;

/**
 使用`not glob`连接
 
 @param notGlob 模糊不匹配的值,支持 * 和 ?
 @return 连接后的语句,如: `field1 NOT GLOB "val1"`
 */
- (NSString *)notGlob:(id)notGlob;

/**
 使用`match`连接
 
 @param match FTS全文搜索匹配的值,支持 * 和 ?
 @return 连接后的语句,如: `tableName match "val1"`
 */
- (NSString *)match:(id)match;

/**
 生成order by子句, 不含`order by`关键字
 
 @return order by 子句,如: `field1 ASC`
 */
- (NSString *)asc;

/**
 生成order by子句, 不含`order by`关键字
 
 @return order by 子句,如: `field1 DESC`
 */
- (NSString *)desc;

@end
