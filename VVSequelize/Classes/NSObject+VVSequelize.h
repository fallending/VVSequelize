//
//  NSObject+VVSequelize.h
//  VVSequelize
//
//  Created by Jinbo Li on 2018/7/13.
//

#import <Foundation/Foundation.h>

/**
 NSObject和NSDictionary/NSArray互转
 
 @note 只支持基础转换,无(字段名映射,黑白名单等)高级功能.
 */
@interface NSObject (VVSequelize)

/**
 将对象转换为字典

 @return 对象对应的字典
 */
- (NSDictionary *)vv_keyValues;

/**
 将字典转换为对象

 @param keyValues 字典
 @return 对象
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
