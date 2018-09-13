//
//  VVOrmModel+Retrieve.h
//  VVSequelize
//
//  Created by Jinbo Li on 2018/9/12.
//

#import "VVOrmModel.h"

@interface VVOrmModel (Retrieve)
/**
 根据主键的值,查询一条数据
 
 @param PKVal 主键的值
 @return 查询结果,对象
 */
- (nullable id)findOneByPKVal:(nonnull id)PKVal;

/**
 查询一条数据
 
 @param condition 查询条件,格式详见VVSqlGenerator
 @return 查询结果,对象
 */
- (nullable id)findOne:(nullable id)condition;

/**
 查询一条数据
 
 @param condition 查询条件,格式详见VVSqlGenerator
 @param orderBy 排序方式
 @return 查询结果,对象
 */
- (nullable id)findOne:(nullable id)condition
               orderBy:(nullable id)orderBy;

/**
 根据条件查询所有数据
 
 @param condition 查询条件,格式详见VVSqlGenerator
 @return 查询结果,对象数组
 */
- (NSArray *)findAll:(nullable id)condition;

/**
 根据条件查询数据
 
 @param condition 查询条件,格式详见VVSqlGenerator
 @param orderBy 排序方式
 @param range 数据范围,用于翻页,range.length为0时,查询所有数据
 @return 查询结果,对象数组
 */
- (NSArray *)findAll:(nullable id)condition
             orderBy:(nullable id)orderBy
               range:(NSRange)range;

/**
 根据条件查询数据
 
 @param condition 查询条件,格式详见VVSqlGenerator
 @param fields 指定查询的字段
 @param orderBy 排序方式
 @param range 数据范围,用于翻页,range.length为0时,查询所有数据
 @return 查询结果,若指定了fields,则返回字典数组,否则返回对象数组
 */
- (NSArray *)findAll:(nullable id)condition
              fields:(nullable NSArray<NSString *> *)fields
             orderBy:(nullable id)orderBy
               range:(NSRange)range;

/**
 根据条件查询数据
 
 @param condition 查询条件,格式详见VVSqlGenerator
 @param fields 指定查询的字段
 @param orderBy 排序方式
 @param range 数据范围,用于翻页,range.length为0时,查询所有数据
 @param jsonResult 是否强制返回JsonOjbects.YES-强制返回JsonObject,NO-根据fields参数确定返回结果
 @return 查询结果,若指定了fields,则返回字典数组,否则返回对象数组
 @note 定义ORM时允许记录时间,则jsonResult可能会包含vv_createAt, vv_updateAt
 @attention 若使用VVKeyValue作为对象/字典互转工具,某些数据转成字典后为NSData的描述字符串,不能直接使用.
 */
- (NSArray *)findAll:(nullable id)condition
              fields:(nullable NSArray<NSString *> *)fields
             orderBy:(nullable id)orderBy
               range:(NSRange)range
          jsonResult:(BOOL)jsonResult;

/**
 根据条件统计数据条数
 
 @param condition 查询条件,格式详见VVSqlGenerator
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
 
 @param condition 查询条件,格式详见VVSqlGenerator
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
