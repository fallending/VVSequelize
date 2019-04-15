//
//  NSObject+VVOrm.h
//  VVSequelize
//
//  Created by Valo on 2018/9/12.
//

#import <Foundation/Foundation.h>
#import "VVOrmDefs.h"

NS_ASSUME_NONNULL_BEGIN

@interface NSObject (VVOrm)

/**
 是否是where语句相关对象
 
 @return YES-是,NO-不是
 */
- (BOOL)isVVExpr;

/**
 是否字段相关对象
 
 @return YES-是,NO-不是
 */
- (BOOL)isVVFields;

/**
 是否是排序相关对象
 
 @return YES-是,NO-不是
 */
- (BOOL)isVVOrderBy;

/**
 是否是分组查询相关对象
 
 @return YES-是,NO-不是
 */
- (BOOL)isVVGroupBy;

@end

@interface NSDictionary (VVOrm)

/**
 删除部分key
 
 @param keys 要删除的keys
 @return 删除keys后的字典
 */
- (NSDictionary *)vv_removeObjectsForKeys:(NSArray *)keys;

@end

/**
 组装SQL语句各种子句的辅助分类
 */
@interface NSArray (VVOrm)

/**
 生成order by子句, 不含`order by`关键字
 
 array中的元素仅支持string.
 不同元素之间以逗号`,`连接, 最后加上` asc`
 
 @return order by 子句
 */
- (NSString *)asc;

/**
 生成order by子句, 不含`order by`关键字
 
 array中的元素仅支持string.
 不同元素之间以逗号`,`连接, 最后加上` desc`
 
 @return order by 子句
 */
- (NSString *)desc;

/**
 将array中的元素以逗号用双引号`"`括起来,并用`,`连接生成字符串
 
 @return 连接好的字符串
 */
- (NSString *)sqlJoin;

/**
 将array中的元素用逗号`,`连接生成字符串
 
 @param quota 每个元素是否用双引号`"`括起来
 @return 连接好的字符串
 */
- (NSString *)sqlJoin:(BOOL)quota;

/**
 数组去重
 
 @return 去重后的数据
 */
- (NSArray *)vv_distinctUnionOfObjects;

/**
 删除部分元素
 
 @param otherArray 要删除的元素
 @return 删除元素后的数组
 */
- (NSArray *)vv_removeObjectsInArray:(NSArray *)otherArray;

@end

/**
 组装SQL语句Where子句的辅助分类
 */
@interface NSString (VVOrm)

// MARK: - clause
/**
 根据传入的数据生成where子句
 
 @param condition 条件对象,NSString,NSArray,NSDictionary
 @return where子句,包含`where`关键字
 */
+ (NSString *)sqlWhere:(id)condition;

/**
 根据传入的数据生成FTS搜索的where子句
 
 @param condition 条件对象,NSString,NSArray,NSDictionary
 @return FTS搜索的where子句,包含`where`关键字
 */
+ (NSString *)sqlMatch:(id)condition;

/**
 根据传入的数据生成groupBy子句
 
 @param groupBy 条件对象,NSString,NSArray
 @return groupBy子句,包含`group by`关键字
 */
+ (NSString *)sqlGroupBy:(id)groupBy;

/**
 根据传入的数据生成having子句
 
 @param having 条件对象,NSString,NSArray,NSDictionary
 @return having子句,包含`having`关键字
 */
+ (NSString *)sqlHaving:(id)having;

/**
 根据传入的数据生成orderBy子句
 
 @param orderBy 条件对象,NSString,NSArray
 @return orderBy子句,包含`order by`关键字
 */
+ (NSString *)sqlOrderBy:(id)orderBy;

// MARK: - sql
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

// MARK: - other
/**
 为字符串前后添加引号
 
 @param quota 引号字符串
 @return 新字符串
 */
- (NSString *)quota:(NSString *)quota;

/**
 去除string首尾的空格和回车
 
 @return 剪裁后的string
 */
- (NSString *)trim;

/**
 去除重复的空格
 
 @return 去除重复空格的string
 */
- (NSString *)strip;

/**
 检查string是否匹配正则表达式
 
 @param regex 正则表达式
 @return 是否匹配
 */
- (BOOL)isMatch:(NSString *)regex;

/**
 准备解析SQL语句,去除语句中的单双引号,多余空格
 
 @return 整理后的SQL语句
 */
- (NSString *)prepareForParseSQL;

/**
 根据字符串的属性生成Html的`<span></span>`左侧标签内容, 用于fts3的offset(),fts5的highlight()函数
 
 @param attributes 字符串的属性
 @return `<span></span>`左侧标签内容
 */
+ (NSString *)leftSpanForAttributes:(NSDictionary<NSAttributedStringKey, id> *)attributes;

/**
 将字符串的属性转换为css语句, 用于fts3的offset(),fts5的highlight()函数
 
 @param attributes 字符串的属性
 @return css语句
 */
+ (NSString *)cssForAttributes:(NSDictionary<NSAttributedStringKey, id> *)attributes;

@end

NS_ASSUME_NONNULL_END
