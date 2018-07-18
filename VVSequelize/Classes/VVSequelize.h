//
//  VVSequelize.h
//  VVSequelize
//
//  Created by Jinbo Li on 2018/6/6.
//

#import <Foundation/Foundation.h>
#import "VVDataBase.h"
#import "VVOrmModel.h"
#import "VVSqlGenerator.h"
#import "VVCipherHelper.h"
#import "NSObject+VVKeyValue.h"

#ifdef DEBUG
#define VVLog(level, ...) [VVSequelize VVVerbose:(level) format:__VA_ARGS__]
#else
#define VVLog(level, ...)
#endif

typedef id(^VVKeyValuesToObject)(Class,NSDictionary *);
typedef id(^VVKeyValuesArrayToObjects)(Class,NSArray<NSDictionary *> *);
typedef id(^VVObjectToKeyValues)(Class,id);
typedef id(^VVObjectsToKeyValuesArray)(Class,NSArray *);


/**
 基于FMDB的ORM封装
 @todo 目前`NSObject+VVKeyValue`尚不完善,建议对象模型互转使用其他稳定的第三方库,例如:YYModel,MJExtension
 @attention 若设置了对象模型互转Block,则使用设置的方法,否则使用`NSObject+VVKeyValue`中定义的方法.
 @warning 若项目中使用的对象模型互转定义了字典key和模型属性名的映射关系,则此处应设置另一个模型转对象的方式.
 
 例如:项目中使用MJExtension,且要存储数据的类里定义了`mj_replacedKeyFromPropertyName`,那么此处应设置YYModel作为模型转对象的方式
 */
@interface VVSequelize : NSObject

//MARK: - 调试信息打印
@property (nonatomic, assign, class) NSInteger loglevel; ///< 是否打印调试信息,0-不打印,1-仅打印sql,2-打印每次sql结果

/**
 打印调试信息,通过loglevel控制
 
 @param level 调试层级
 @param fmt 调试信息格式及字符串
 */
+ (void)VVVerbose:(NSUInteger)level
           format:(NSString *)fmt, ...;

//MARK: - 对象模型互转
@property (nonatomic, copy, class) VVKeyValuesToObject       keyValuesToObject;        ///< 字典转对象
@property (nonatomic, copy, class) VVKeyValuesArrayToObjects keyValuesArrayToObjects;  ///< 字典数组转对象数组
@property (nonatomic, copy, class) VVObjectToKeyValues       objectToKeyValues;        ///< 对象转字典
@property (nonatomic, copy, class) VVObjectsToKeyValuesArray objectsToKeyValuesArray;  ///< 对象数组转字典数组


/**
 设置使用NSObject+VVKeyValue
 */
+ (void)useVVKeyValue;

@end
