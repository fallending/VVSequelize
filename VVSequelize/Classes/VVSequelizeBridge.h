//
//  VVSequelizeBridge.h
//  Pods
//
//  Created by Jinbo Li on 2018/6/30.
//

#import <Foundation/Foundation.h>

@protocol VVSequelizeBridge <NSObject>

//MARK: - 数据库
@required

/**
 初始化数据库文件

 @param dbPath sqlite数据库文件路径
 @return 是否初始化成功
 */
- (BOOL)db_initWithPath:(NSString *)dbPath;

/**
 打开数据库

 @return 是都打开成功
 */
- (BOOL)db_open;

/**
 关闭数据库

 @return 是否关闭成功
 */
- (BOOL)db_close;

/**
 执行SQL查询语句

 @param sql 查询语句
 @return 查询结果
 */
- (NSArray *)db_executeQuery:(NSString*)sql;

/**
 执行SQL更新语句

 @param sql 更新语句
 @return 是否更新成功
 */
- (BOOL)db_executeUpdate:(NSString*)sql;

@optional

/**
 设置数据库加密Key(可选)

 @param encryptKey 加密Key
 */
- (void)db_setEncryptKey:(NSString *)encryptKey;

/**
 数据库线程安全操作

 @param block 具体操作
 */
- (void)db_inSecureQueue:(void (^)(void))block;

/**
 数据库事务操作

 @param block 具体操作
 */
- (void)db_inTransaction:(void (^)(BOOL *rollback))block;

//MAKR: - 模型对象互转

/**
 键值对字典-->对象

 @param keyValues 键值对字典
 @param cls 目标对象的类
 @return 对象
 */
- (id)model_objectWithkeyValues:(NSDictionary *)keyValues class:(Class)cls;

/**
 键值对字典数组-->对象数组

 @param keyValuesArray 键值对字典数组
 @param cls 目标对象的类
 @return 对象数组
 */
- (id)model_objectArrayWithkeyValuesArray:(NSArray<NSDictionary *> *)keyValuesArray class:(Class)cls;

/**
 对象-->键值对字典

 @param object 对象
 @return 键值对字典
 */
- (NSDictionary *)model_keyValuesOfObject:(id)object;

/**
 对象数组-->键值对字典数组

 @param objectArray 对象数组
 @param cls 对象数组的类
 @return 键值对字典数组
 */
- (NSArray<NSDictionary *> *)model_keyValuesArrayWithObjectArray:(NSArray *)objectArray class:(Class)cls;

@end
