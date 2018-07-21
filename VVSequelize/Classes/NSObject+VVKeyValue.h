//
//  NSObject+VVKeyValue.h
//  VVSequelize
//
//  Created by Jinbo Li on 2018/7/13.
//

#import <Foundation/Foundation.h>

@interface NSData (VVKeyValue)

/**
 将NSValue转换为NSData

 @param value NSValue对象
 @return NSData数据
 */
+ (NSData *)dataWithValue:(NSValue *)value;

/**
 将NSNumber转换为NSData
 
 @param number NSValue对象
 @return NSData数据
 */
+ (NSData *)dataWithNumber:(NSNumber *)number;

/**
 将NSData的打印字符串转换为NSData对象

 @param dataDescription NSData打印字符串`[data description]`
 @return NSData对象
 */
+ (NSData *)dataWithDescription:(NSString *)dataDescription;

@end

/**
 用于数据库存储的日期格式转换, 可用于SQL查询时作为比较条件
 */
@interface NSDate (VVKeyValue)

/**
 将日期转换为字符串,固定格式为"yyyy-MM-dd HH:mm:ss.SSS"
 
 @return 日期字符串
 */
- (NSString *)vv_dateString;

/**
 将日期字符串转换成日期,固定格式为"yyyy-MM-dd HH:mm:ss.SSS"
 
 @param dateString 日期字符串
 @return 日期
 */
+ (instancetype)vv_dateWithString:(NSString *)dateString;

@end

@protocol VVKeyValue <NSObject>
/**
 *  Array/Set中需要转换的模型类
 *
 *  @return 字典中的key是Array/Set属性名，value是数组中存放模型的Class（Class类型或者NSString类型）
 */
+ (nullable NSDictionary *)vv_collectionMapper;

@end

/**
 NSObject和NSDictionary/NSArray互转,主要应用于VVSequelize.
 
 @note 只支持基础转换,无(字段名映射,黑白名单等)高级功能,暂不考虑高效率问题.
 */
@interface NSObject (VVKeyValue)

/**
 将对象转换为字典

 @return 对象对应的字典
 @note 对象属性支持NSSelector,支持C语言类型的char, string, struct, union
 @attention C语言union类型总长度不能超过size_t长度.
 */
- (NSDictionary *)vv_keyValues;

/**
 将字典转换为对象

 @param keyValues 字典
 @return 对象
 @note 对象属性支持NSSelector,支持C语言类型的char, string, struct, union
 @attention C语言union类型总长度不能超过size_t长度.
 */
+ (instancetype)vv_objectWithKeyValues:(NSDictionary<NSString *, id> *)keyValues;

/**
 将对象数组转换为字典数组

 @param objects 对象数组
 @return 字典数组
 */
+ (NSArray *)vv_keyValuesArrayWithObjects:(NSArray *)objects;

/**
 将字典数组转换为对象数组

 @param keyValuesArray 字典数组
 @return 对象数组
 */
+ (NSArray *)vv_objectsWithKeyValuesArray:(id)keyValuesArray;

@end
