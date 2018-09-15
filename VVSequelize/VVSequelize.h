//
//  VVSequelize.h
//  VVSequelize
//
//  Created by Jinbo Li on 2018/6/6.
//

#import <Foundation/Foundation.h>
#import "VVSQLiteDB.h"
#import "VVDataBase.h"

#import "VVOrmField.h"
#import "VVOrmConfig.h"

#import "VVOrm.h"
#import "VVOrm+Create.h"
#import "VVOrm+Update.h"
#import "VVOrm+Retrieve.h"
#import "VVOrm+Delete.h"
#import "VVSelect.h"

#import "VVDataBaseHelper.h"
#import "NSObject+VVKeyValue.h"
#import "NSString+VVClause.h"
#import "NSArray+VVClause.h"
#import "NSDictionary+VVClause.h"

/**
 基于FMDB的ORM封装
 */
@interface VVSequelize : NSObject

@property (nonatomic, strong, class) Class<VVSQLiteDB> dbClass; ///< 设置sqlite3封装类

@property (nonatomic, assign, class) BOOL useCache; ///< 是否使用缓存

/**
 跟踪SQL语句执行情况.
 sql: SQL语句;
 values: 插入/更新时`sql3_bind`的数据;
 results: 语句执行结果;
 error: 执行失败的错误;
 */
@property (nonatomic, copy, class) void (^trace)(NSString *sql, NSArray *values, id results, NSError *error);

@end
