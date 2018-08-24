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
#import "VVDataBaseHelper.h"
#import "NSObject+VVKeyValue.h"

#ifndef VVLog
#define VVLog(level, ...) [VVSequelize VVVerbose:(level) format:__VA_ARGS__]
#endif

/**
 基于FMDB的ORM封装
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

//MARK: - 全局方法

/**
 打印调试信息,通过loglevel控制
 
 @param level 调试层级
 @param fmt 调试信息格式及字符串
 */
+ (void)VVVerbose:(NSUInteger)level
           format:(NSString *)fmt, ...;

@end
