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

#define VVLog(level, ...) [VVSequelize VVVerbose:(level) format:__VA_ARGS__]

typedef id(^VVKeyValuesToObject)(Class,NSDictionary *);
typedef id(^VVKeyValuesArrayToObjects)(Class,NSArray<NSDictionary *> *);
typedef id(^VVObjectToKeyValues)(Class,id);
typedef id(^VVObjectsToKeyValuesArray)(Class,NSArray *);

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

@end
