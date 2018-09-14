//
//  VVSequelize.h
//  VVSequelize
//
//  Created by Jinbo Li on 2018/6/6.
//

#import <Foundation/Foundation.h>
#import "VVDataBase.h"

#import "VVOrmField.h"
#import "VVOrmConfig.h"

#import "VVOrmModel.h"
#import "VVOrmModel+Create.h"
#import "VVOrmModel+Update.h"
#import "VVOrmModel+Retrieve.h"
#import "VVOrmModel+Delete.h"

#import "VVSqlGenerator.h"
#import "VVDataBaseHelper.h"
#import "NSObject+VVKeyValue.h"

/**
 基于FMDB的ORM封装
 */
@interface VVSequelize : NSObject

@property (nonatomic, assign, class) BOOL useCache; ///< 是否使用缓存

/**
 跟踪SQL语句执行情况.
 sql: SQL语句;
 values: 插入/更新时`sql3_bind`的数据;
 results: 语句执行结果;
 */
@property (nonatomic, copy, class) void (^trace)(NSString *sql, NSArray *values, id results);

@end
