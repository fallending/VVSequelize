//
//  VVDataBase.h
//  VVSequelize
//
//  Created by Jinbo Li on 2018/6/6.
//

#import <Foundation/Foundation.h>
#import "VVSequelizeBridge.h"

@interface VVDataBase : NSObject

@property (nonatomic, strong) NSString *dbPath;
@property (nonatomic, strong) NSString *encryptKey;

#pragma mark - 创建数据库
/**
 创建数据库单例
 
 @return 数据库单例对象
 */
+ (instancetype)defalutDb;

/**
 初始化数据库
 
 @param dbName 数据库文件名,如:abc.sqlite, abc.db
 @return 数据库对象
 */
- (instancetype)initWithDBName:(nullable NSString *)dbName;

/**
 初始化数据库
 
 @param dbName 数据库文件名,如:abc.sqlite, abc.db
 @param dirPath 数据库存储路径,若为nil,则路径默认为NSDocumentDirectory
 @param encryptKey 数据库密码,使用SQLCipher加密的密码.若为nil,则不加密.
 @return 数据库对象
 */
- (instancetype)initWithDBName:(nullable NSString *)dbName
                       dirPath:(nullable NSString *)dirPath
                    encryptKey:(nullable NSString *)encryptKey;

#pragma mark - 原始SQL语句

/**
 原始SQL查询

 @param sql sql语句
 @return 查询结果,json数组
 */
- (NSArray *)vv_executeQuery:(NSString *)sql;


/**
 原始SQL更新

 @param sql sql语句
 @return 是否更新成功
 */
- (BOOL)vv_executeUpdate:(NSString *)sql;

#pragma mark - 线程安全操作
/**
 将操作语句放入block中即可保证线程安全, 如:
 Person *p = [[Person alloc] init];
 p.name = @"小李";
 [jqdb vv_inDatabase:^{
 [jqdb vv_insertTable:@"users" dicOrModel:p];
 }];
 */
- (void)vv_inDatabase:(void (^)(void))block;


/**
 将操作语句放入block中可执行回滚操作(*rollback = YES;)
 Person *p = [[Person alloc] init];
 p.name = @"小李";
 for (int i=0,i < 1000,i++) {
 [jq vv_inTransaction:^(BOOL *rollback) {
 BOOL flag = [jq vv_insertTable:@"users" dicOrModel:p];
 if (!flag) {
 *rollback = YES; //只要有一次不成功,则进行回滚操作
 return;
 }
 }];
 }
 */
- (void)vv_inTransaction:(void(^)(BOOL *rollback))block;

#pragma mark - 其他操作
/**
 关闭数据库
 */
- (void)close;

/**
 打开数据库,每次init时已经open,当调用close后若进行db操作需重新open
 */
- (void)open;

@end
