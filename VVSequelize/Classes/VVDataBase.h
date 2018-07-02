//
//  VVDataBase.h
//  VVSequelize
//
//  Created by Jinbo Li on 2018/6/6.
//

#import <Foundation/Foundation.h>

@interface VVDataBase : NSObject
@property (nonatomic, strong) NSString *dbPath;
@property (nonatomic, strong) NSString *encryptKey;

//MARK: - 创建数据库
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

//MARK: - 原始SQL语句

/**
 原始SQL查询

 @param sql sql语句
 @return 查询结果,json数组
 */
- (NSArray *)executeQuery:(NSString *)sql;


/**
 原始SQL更新

 @param sql sql语句
 @return 是否更新成功
 */
- (BOOL)executeUpdate:(NSString *)sql;

//MARK: - 线程安全操作
/**
 将操作语句放入block中进行线程安全操作,参考FMDB用法.
 */
- (void)inQueue:(void (^)(void))block;


/**
 将操作语句放入block中可执行事务操作,参考FMDB的用法.
 */
- (void)inTransaction:(void(^)(BOOL *rollback))block;

//MARK: - 其他操作
/**
 关闭数据库
 */
- (BOOL)close;

/**
 打开数据库,每次init时已经open,当调用close后若进行db操作需重新open
 */
- (BOOL)open;

@end


