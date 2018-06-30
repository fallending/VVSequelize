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
#import "VVSequelizeBridge.h"

typedef enum : NSUInteger {
    VVLogLevelNone          = 0,
    VVLogLevelSQL           = 1,
    VVLogLevelSQLAndResult  = 2,
} VVLogLevel;

#define VVLog(level, ...) [VVSequelize VVVerbose:(level) format:__VA_ARGS__]

@interface VVSequelize : NSObject

@property (nonatomic, strong, class) id<VVSequelizeBridge> bridge; ///< 和外部桥接的对象
@property (nonatomic, assign, class) VVLogLevel verbose; ///< 是否打印调试信息,0-不打印,1-仅打印sql,2-打印每次sql结果

/**
 打印调试信息,通过verbose控制
 
 @param level 调试层级
 @param fmt 调试信息格式及字符串
 */
+ (void)VVVerbose:(NSUInteger)level
           format:(NSString *)fmt, ...;


@end
