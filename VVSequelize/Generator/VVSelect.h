//
//  VVSelect.h
//  VVSequelize
//
//  Created by Jinbo Li on 2018/9/14.
//

#import <Foundation/Foundation.h>
@class VVOrm;

@interface VVSelect : NSObject
@property (nonatomic, copy, readonly) NSString *sql; //根据条件生成SQL语句

/**
 创建Select对象
 
 @return VVSelect对象
 */
+ (instancetype)prepare;

/**
 创建Select对象

 @param orm 数据表模型
 @return VVSelect对象
 */
+ (instancetype)prepareWithOrm:(VVOrm *)orm;

/**
 从数据库查询结果

 @param useJson 是否使用json格式结果
 @return 查询结果,字典数组或对象数组
 @note 仅支持由`+prepareWithOrm:`创建的VVSelect对象
 */
- (NSArray *)findAll:(BOOL)useJson;

//MARK: 链式调用

/**
 设置表名

 @param table 表名
 @return self
 */
- (instancetype)table:(NSString *)table;

/**
 设置要查询的字段
 
 @param fields 要查询的字段,默认为`*`所有字段
 @return self
 */
- (instancetype)fields:(id)fields;

/**
 设置是否去除重复数据
 
 @param distinct 是否去除重复数据
 @return self
 */
- (instancetype)distinct:(BOOL)distinct;

/**
 设置查询条件
 
 @param where 查询条件,用于生成where子句.格式: NSString, NSDictionary, NSArray
 @return self
 */
- (instancetype)where:(id)where;

/**
 设置查询范围
 
 @param limit 查询范围,用于生成limit,offset
 @return self
 */
- (instancetype)limit:(NSRange)limit;

/**
 设置排序方式
 
 @param orderBy 排序方式. 格式: NSString, NSArray
 @return self
 */
- (instancetype)orderBy:(id)orderBy;

/**
 设置分组方式
 
 @param groupBy 分组方式. 格式: NSString, NSArray
 @return self
 */
- (instancetype)groupBy:(id)groupBy;

/**
 设置分组过滤条件
 
 @param having 分组过滤条件,仅在分组有效时使用,格式同`where`
 @return self
 */
- (instancetype)having:(id)having;

@end
