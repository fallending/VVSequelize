//
//  VVOrm+Retrieve.h
//  VVSequelize
//
//  Created by Jinbo Li on 2018/9/12.
//

#import "VVOrm.h"

@interface VVOrm (Retrieve)
/**
 根据主键的值,查询一条数据
 
 @param PKVal 主键的值
 @return 查询结果,对象
 */
- (nullable id)findOneByPKVal:(nonnull id)PKVal;

/**
 查询一条数据
 
 @param condition 查询条件,见`-findAll:fields:groupBy:having:orderBy:range:useJson:`
 @return 查询结果,对象
 */
- (nullable id)findOne:(nullable id)condition;

/**
 查询一条数据
 
 @param condition 查询条件,见`-findAll:fields:groupBy:having:orderBy:range:useJson:`
 @param orderBy 排序条件
 @return 查询结果,对象
 */
- (nullable id)findOne:(nullable id)condition
               orderBy:(nullable id)orderBy;

/**
 根据条件查询所有数据
 
 @param condition 查询条件,见`-findAll:fields:groupBy:having:orderBy:range:useJson:`
 @return 查询结果,对象数组
 */
- (NSArray *)findAll:(nullable id)condition;

/**
 根据条件查询数据
 
 @param condition 查询条件,见`-findAll:fields:groupBy:having:orderBy:range:useJson:`
 @param orderBy 排序条件
 @param range 数据范围
 @return 查询结果,对象数组
 */
- (NSArray *)findAll:(nullable id)condition
             orderBy:(nullable id)orderBy
               range:(NSRange)range;

/**
 根据条件查询数据
 
 @param condition 查询条件,见`-findAll:fields:groupBy:having:orderBy:range:useJson:`
 @param groupBy 分组条件
 @param range 数据范围
 */
- (NSArray *)findAll:(nullable id)condition
             groupBy:(nullable id)groupBy
               range:(NSRange)range;

/**
 根据条件查询数据
 
 @param condition 查询条件.
 1.支持原生sql,可传入`where`及之后的所有语句
 2.非套嵌的dictionary,key和value用`=`连接,不同的key value用`and`连接
 3.非套嵌的dictionary数组, 每个dictionary用`or`连接

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

 @param range 数据范围,用于翻页.`range.location == NSNotFound`或`range.length == 0`时,查询所有数据
 
 @param useJson 是否强制返回JsonOjbects.YES-强制返回JsonObject,NO-根据fields参数确定返回结果
 
 @return 查询结果,若指定了fields,则返回字典数组,否则返回对象数组
 
 @note 定义ORM时允许记录时间,则字典数组可能会包含vv_createAt, vv_updateAt
 */
- (NSArray *)findAll:(nullable id)condition
            distinct:(BOOL)distinct
              fields:(nullable NSArray<NSString *> *)fields
             groupBy:(nullable id)groupBy
              having:(nullable id)having
             orderBy:(nullable id)orderBy
               range:(NSRange)range
             useJson:(BOOL)useJson;

/**
 根据条件统计数据条数
 
 @param condition 查询条件,见`-findAll:fields:groupBy:having:orderBy:range:useJson:`
 @return 数据条数
 */
- (NSInteger)count:(nullable id)condition;

/**
 检查数据库中是否保存有某个数据
 
 @param object 数据对象
 @return 是否存在
 */
- (BOOL)isExist:(nonnull id)object;

/**
 根据条件查询数据和数据数量.数量只根据查询条件获取,不受range限制.
 
 @param condition 查询条件,见`-findAll:fields:groupBy:having:orderBy:range:useJson:`
 @param orderBy 排序方式
 @param range 数据范围,用于翻页,range.length为0时,查询所有数据
 @return 数据(对象数组)和数据数量,格式为{"count":100,list:[object]}
 */
- (NSDictionary *)findAndCount:(nullable id)condition
                       orderBy:(nullable id)orderBy
                         range:(NSRange)range;

/**
 最大行号`max(rowid)`
 
 @return 最大行号
 @discussion 此处取`max(rowid)`可以做唯一值, `max(rowid) + 1`为下一条将插入的数据的自动主键值.
 */
- (NSUInteger)maxRowid;

/**
 获取某个字段的最大值
 
 @param field 字段名
 @return 最大值.因Text也可以计算最大值,故返回值为id类型
 */
- (id)max:(nonnull NSString *)field;

/**
 获取某个字段的最小值
 
 @param field 字段名
 @return 最小值.因Text也可以计算最小值,故返回值为id类型
 */
- (id)min:(nonnull NSString *)field;

/**
 获取某个字段的求和
 
 @param field 字段名
 @return 求和
 */
- (id)sum:(nonnull NSString *)field;

@end
