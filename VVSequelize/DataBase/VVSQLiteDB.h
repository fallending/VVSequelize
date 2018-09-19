//
//  VVSQLiteDB.h
//  VVSequelize
//
//  Created by Jinbo Li on 2018/9/14.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol VVSQLiteDB <NSObject>

@required
/**
 初始化

 @param path 数据库文件路径
 @return 数据库对象
 */
+ (id<VVSQLiteDB>)dbWithPath:(NSString * _Nonnull)path;

/**
 打开数据库

 @return 是否打开成功
 @note 如果自定义了fts5分词器,请在open方法中调用注册分词器方法
 */
- (BOOL)open;

/**
 关闭数据库

 @return 是否关闭成功
 */
- (BOOL)close;

/**
 执行SQL查询语句
 
 @param sql sql语句
 @param error 执行sql语句发生的错误
 @return 查询结果,json数组,格式{field1:val1,field2:val2,...}
 */
- (NSArray * _Nullable)executeQuery:(NSString *)sql
                              error:(NSError * _Nullable __autoreleasing *)error;

/**
 执行SQL更新语句
 
 @param sql sql语句
 @param error 执行sql语句发生的错误
 @return 是否更新成功
 */
- (BOOL)executeUpdate:(NSString*)sql
                error:(NSError * _Nullable __autoreleasing *)error;

/**
 执行SQL更新语句
 
 @param sql sql语句
 @param values 对应sql语句中`?`的值
 @param error 执行sql语句发生的错误
 @return 是否更新成功
 @note 插入/更新数据时,防SQL主注入,sql语句会包含(?,?,?,..)格式,由`sqlite3_bind`处理
 */
- (BOOL)executeUpdate:(NSString*)sql
               values:(NSArray * _Nullable)values
                error:(NSError * _Nullable __autoreleasing *)error;

@optional

/**
 创建内存数据库

 @return 内存数据库
 */
+ (id<VVSQLiteDB>)createMemoryDb;

/**
 打开数据库
 
 @param flags 数据库打开参数,详见sqlite3头文件中的宏定义
 @return 是否打开成功
 @note 如果自定义了fts5分词器,请在open方法中调用注册分词器方法
 */
- (BOOL)openWithFlags:(int)flags;

/**
 设置sqlite3加密
 
 @param encryptKey 加密Key,nil表示不加密
 @return 是否设置成功
 */
- (BOOL)setEncryptKey:(NSString * _Nullable)encryptKey;

@end

NS_ASSUME_NONNULL_END
