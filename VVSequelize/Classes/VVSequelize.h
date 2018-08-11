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
#import "VVDataBaseHelper.h"
#import "NSObject+VVKeyValue.h"

#ifndef VVLog
#define VVLog(level, ...) [VVSequelize VVVerbose:(level) format:__VA_ARGS__]
#endif

typedef id(^VVKeyValuesToObject)(Class,NSDictionary *);
typedef id(^VVKeyValuesArrayToObjects)(Class,NSArray<NSDictionary *> *);
typedef id(^VVObjectToKeyValues)(Class,id);
typedef id(^VVObjectsToKeyValuesArray)(Class,NSArray *);


/**
 基于FMDB的ORM封装
 @todo `NSObject+VVKeyValue`正在完善中,建议对象/字典互转工具使用其他稳定的第三方库,例如:YYModel,MJExtension
 @attention 调用`+useVVKeyValue`方法设置使用自带的对象/字典互转工具, 或者依次设置对象/字典互转的4个Block.
            多次设置,只会使用最后设置的方法.若不设置,查询结果为字典[数组],且某些直接操作对象的方法会直接返回NO.
 @warning 若项目中使用的对象/字典互转工具定义了字典key和模型属性名的映射关系,则此处应设置另一个对象/字典互转工具.
          例如:项目中使用MJExtension,且要存储数据的类里定义了`mj_replacedKeyFromPropertyName`,
              那么此处应调用`+useVVKeyValue`或设置YYModel作为对象/字典互转工具
 */
@interface VVSequelize : NSObject

//MARK: - 全局设置

/**
 设置调试信息打印等级
 
 @brief 0-不打印,1-仅打印sql,2-打印每次sql结果
 @attention 若外部定义了VVLog, 则本设置无效.
 */
@property (nonatomic, assign, class) NSInteger loglevel;

@property (nonatomic, assign, class) BOOL useCache; ///< 是否使用缓存

//MARK: - 对象/字典互转
@property (nonatomic, copy, class) VVKeyValuesToObject       keyValuesToObject;        ///< 字典转对象
@property (nonatomic, copy, class) VVKeyValuesArrayToObjects keyValuesArrayToObjects;  ///< 字典数组转对象数组
@property (nonatomic, copy, class) VVObjectToKeyValues       objectToKeyValues;        ///< 对象转字典
@property (nonatomic, copy, class) VVObjectsToKeyValuesArray objectsToKeyValuesArray;  ///< 对象数组转字典数组

//MARK: - 全局方法

/**
 打印调试信息,通过loglevel控制
 
 @param level 调试层级
 @param fmt 调试信息格式及字符串
 */
+ (void)VVVerbose:(NSUInteger)level
           format:(NSString *)fmt, ...;



/**
 设置使用NSObject+VVKeyValue
 */
+ (void)useVVKeyValue;

@end
