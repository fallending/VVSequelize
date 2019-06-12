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
 生成where子句
 
 @return where子句,不含where关键字
 */
- (NSString *)sqlWhere;

/**
 array: 将所有元素以逗号用双引号`"`括起来,并用`,`连接生成字符串;
 string: 返回原值
 
 @return 连接好的字符串
 */
- (NSString *)sqlJoin;

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
 将array中的元素用逗号`,`连接生成字符串
 
 @note 字符串或其他非数字元素,转换为string后将会用双引号"括起来
 @return 连接好的字符串
 */
- (NSString *)sqlJoin;

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

// MARK: - where
/**
 使用`and`连接
 
 @note value 要连接的字符串或值
 @return 连接后的语句,如: `(field1 = val1) AND (field2 = val2)`
 */
- (NSString *(^)(id value))and;

/**
 使用`or`连接
 
 @note value 要连接的字符串或值
 @return 连接后的语句,如: `(field1 = val1) OR (field2 = val2)`
 */
- (NSString *(^)(id value))or;

/**
 使用`on`连接, 用于JOIN条件
 
 @note value 连接条件,如`table1.field == table2.field`
 @return 连接后的语句,如: `table1 INNER JOIN table2 ON table1.field == table2.field`
 */
- (NSString *(^)(id value))on;

/**
 使用`=`连接
 
 @note value 等于的值
 @return 连接后的语句,如: `field1 = value`
 */
- (NSString *(^)(id value))eq;

/**
 使用`!=`连接
 
 @note value 不等于的值
 @return 连接后的语句,如: `field1 != value`
 */
- (NSString *(^)(id value))ne;

/**
 使用`>`连接
 
 @note value 大于的值
 @return 连接后的语句,如: `field1 > value`
 */
- (NSString *(^)(id value))gt;

/**
 使用`>=`连接
 
 @note value 大于等于的值
 @return 连接后的语句,如: `field1 >= value`
 */
- (NSString *(^)(id value))gte;

/**
 使用`<`连接
 
 @note value 小于的值
 @return 连接后的语句,如: `field1 < value`
 */
- (NSString *(^)(id value))lt;

/**
 使用`<=`连接
 
 @note value 小于等于的值
 @return 连接后的语句,如: `field1 <= value`
 */
- (NSString *(^)(id value))lte;

/**
 使用`is not`连接
 
 @note value 不等同的值
 @return 连接后的语句,如: `field1 IS NOT value`
 */
- (NSString *(^)(id value))not;

/**
 使用`between`连接
 
 @note value1 between的前值
 @note value2 between的后值
 @return 连接后的语句,如: `field1 BETWEEN value1,value2`
 */
- (NSString *(^)(id value, id value2))between;

/**
 使用`not between`连接
 
 @note value1 not between的前值
 @note value2 not between的后值
 @return 连接后的语句,如: `field1 NOT BETWEEN value1,value2`
 */
- (NSString *(^)(id value1, id value2))notBetween;

/**
 使用`in`连接
 
 @note array 包含的值
 @return 连接后的语句,如: `field1 IN (value1,value2,...)`
 */
- (NSString *(^)(NSArray *array))in;

/**
 使用`not in`连接
 
 @note array 不包含的值
 @return 连接后的语句,如: `field1 NOT IN (value1,value2,...)`
 */
- (NSString *(^)(NSArray *array))notIn;

/**
 使用`like`连接
 
 @note value 模糊匹配的值,支持 % 和 _
 @return 连接后的语句,如: `field1 LIKE "value"`
 */
- (NSString *(^)(id value))like;

/**
 使用`not like`连接
 
 @note value 模糊不匹配的值,支持 % 和 _
 @return 连接后的语句,如: `field1 NOT LIKE "value"`
 */
- (NSString *(^)(id value))notLike;

/**
 使用`glob`连接
 
 @note value 模糊匹配的值,支持 * 和 ?
 @return 连接后的语句,如: `field1 GLOB "value"`
 */
- (NSString *(^)(id value))glob;

/**
 使用`not glob`连接
 
 @note value 模糊不匹配的值,支持 * 和 ?
 @return 连接后的语句,如: `field1 NOT GLOB "value"`
 */
- (NSString *(^)(id value))notGlob;

/**
 使用`match`连接
 
 @note value FTS全文搜索匹配的值,支持 * 和 ?
 @return 连接后的语句,如: `tableName match "value"`
 */
- (NSString *(^)(id value))match;

/**
 联表查询,内连接,self为表名;
 
 @note right 要连接的表
 @return 连接后的表语句,如: `table1 JOIN table2`
 */
- (NSString *(^)(NSString *right))innerJoin;

/**
 联表查询,外连接,self为表名;sqlite仅支持`LEFT OUTER JOIN`
 
 @note right 要连接的表
 @return 连接后的表语句,如: `table1 LEFT OUTER JOIN table2`
 */
- (NSString *(^)(NSString *right))outerJoin;

/**
 联表查询,交叉连接,self为表名;
 
 @note right 要连接的表
 @return 连接后的表语句,如: `table1 CROSS JOIN table2`
 */
- (NSString *(^)(NSString *right))crossJoin;

/**
 联表查询,联表后制定表的字段,self为表名
 
 @note column 字段名
 @return 连接后的表语句,如: `table1.column1`
 */
- (NSString *(^)(NSString *column))column;

/**
 连接字符串,用空格分隔,用于某些特殊场合
 
 @note concat 连接字符串, value 要连接的的值
 @return 连接后的表语句,如: A.concat(@"=", B) -> `A = B`
 */
- (NSString *(^)(NSString *concat, id value))concat;

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
 
 @param quote 引号字符串
 @return 括起来的字符串
 */
- (NSString *)quote:(NSString *)quote;

/**
 使用双引号括起来
 
 @return 括起来的字符串
 */
- (NSString *)quoted;

/**
 使用单引号括起来
 
 @return 括起来的字符串
 */
- (NSString *)singleQuoted;

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
