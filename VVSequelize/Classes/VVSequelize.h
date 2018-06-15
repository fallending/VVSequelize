//
//  VVSequelize.h
//  VVSequelize
//
//  Created by Jinbo Li on 2018/6/6.
//

#import <Foundation/Foundation.h>
#import "VVFMDB.h"
#import "VVOrmModel.h"
#import "VVSqlGenerator.h"

#define VVLog(...) [VVSequelize VVVerbose:__VA_ARGS__]

typedef id(^VVKeyValuesToObject)(Class,NSDictionary *);
typedef id(^VVKeyValuesArrayToObjects)(Class,NSArray<NSDictionary *> *);
typedef id(^VVObjectToKeyValues)(Class,id);
typedef id(^VVObjectsToKeyValuesArray)(Class,NSArray *);

@interface VVSequelize : NSObject

@property (nonatomic, assign, class) BOOL verbose; ///< 是否打印调试信息

/**
 打印调试信息,通过verbose控制

 @param fmt 调试信息格式及字符串
 */
+ (void)VVVerbose:(NSString *)fmt, ...;

@property (nonatomic, copy, class) VVKeyValuesToObject       keyValuesToObject;        ///< 字典转对象
@property (nonatomic, copy, class) VVKeyValuesArrayToObjects keyValuesArrayToObjects;  ///< 字典数组转对象数组
@property (nonatomic, copy, class) VVObjectToKeyValues       objectToKeyValues;        ///< 对象转字典
@property (nonatomic, copy, class) VVObjectsToKeyValuesArray objectsToKeyValuesArray;  ///< 对象数组转字典数组

@end
