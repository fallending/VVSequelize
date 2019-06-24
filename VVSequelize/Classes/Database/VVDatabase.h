//
//  VVDatabase.h
//  VVSequelize
//
//  Created by Valo on 2019/3/19.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef struct sqlite3 sqlite3;

FOUNDATION_EXPORT NSString *const VVDBPathInMemory;   ///< 创建m内存数据库的路径
FOUNDATION_EXPORT NSString *const VVDBPathTemporary;  ///< 创建临时数据库的路径
FOUNDATION_EXPORT int VVDBEssentialFlags; ///< SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX

/**
 sqlite3事务类型

 - VVDBTransactionDeferred: `BEGIN DEFERRED TRANSACTION`
 - VVDBTransactionImmediate: `BEGIN IMMEDIATE TRANSACTION`
 - VVDBTransactionExclusive: `BEGIN EXCLUSIVE TRANSACTION`
 */
typedef NS_ENUM (NSUInteger, VVDBTransaction) {
    VVDBTransactionDeferred,
    VVDBTransactionImmediate,
    VVDBTransactionExclusive,
};

/**
 重试处理

 @param times 重试次数
 @return 返回0表示不重试,>0则继续重试.
 */
typedef int (^VVDBBusyHandler)(int times);

/**
 跟踪sql语句执行

 @param mask [SQLITE_TRACE]:`SQLITE_TRACE_STMT, SQLITE_TRACE_PROFILE, SQLITE_TRACE_ROW, SQLITE_TRACE_CLOSE`
 @param stmt 依赖上下文,通常为sqlite3_stmt结构体指针
 @param sql 依赖上下文,通常为sql语句
 @return 跟踪结果 SQLITE_OK,SQLITE_DONE, etc..
 */
typedef int (^VVDBTraceHook)(unsigned mask, void *stmt, void *sql);

/**
 更新操作钩子函数

 @param op 更新类型`SQLITE_INSERT,SQLITE_DELETE,SQLITE_UPDATE`
 @param db sqlite3_db结构体
 @param table 表名
 @param rowid 作用于表的某一行的行号
 */
typedef void (^VVDBUpdateHook)(int op, char const *db, char const *table, int64_t rowid);

/**
 事务提交操作钩子函数

 @return 0-将commit成功, 非0-将执行rollback
 */
typedef int (^VVDBCommitHook)(void);

/**
 事务回滚操作钩子函数
 */
typedef void (^VVDBRollbackHook)(void);

@class VVDBStatement;

/**
 Valo database
 */
@interface VVDatabase : NSObject

/**
 数据库完整路径
 */
@property (nonatomic, copy)   NSString *path;
/**
 加密Key,nil表示不加密
 */
@property (nonatomic, copy, nullable) NSString *encryptKey;
/**
 sqlite3_open_v2第三个参数为 (flags | VVDBEssentialFlags)
 */
@property (nonatomic, assign) int flags;
/**
 数据库是否打开
 */
@property (nonatomic, assign, readonly) BOOL isOpen;
/**
 最近一次sqlite3_exec()导致的变更数量
 */
@property (nonatomic, assign, readonly) int changes;
/**
 打开数据库后的变更数量
 */
@property (nonatomic, assign, readonly) int totalChanges;
/**
 最近一次插入操作的rowid
 */
@property (nonatomic, assign, readonly) int64_t lastInsertRowid;

/**
 更新间隔,默认为0

 @note 若间隔时间内有多次更新操作, 将合并成一次事务操作. 默认间隔为0,将不会合并操作.
 */
@property (nonatomic, assign) CFAbsoluteTime updateInterval;

/**
 初始化数据库

 @param path 数据库文件完整路径
 @return 数据库对象
 */
- (instancetype)initWithPath:(nullable NSString *)path;

/**
 打开/创建数据库, 使用默认`VVDBEssentialFlags`

 @param path 数据库文件完整路径
 @return 数据库对象
 */
+ (instancetype)databaseWithPath:(nullable NSString *)path;

/**
 打开/创建数据库,不进行加密

 @param path 数据库文件完整路径
 @param flags sqlite3_open_v2第三个参数为 (flags | VVDBEssentialFlags)
 @return 数据库对象
 */
+ (instancetype)databaseWithPath:(nullable NSString *)path flags:(BOOL)flags;

/**
 打开/创建数据库

 @param path 数据库文件完整路径
 @param flags sqlite3_open_v2第三个参数为 (flags | VVDBEssentialFlags)
 @param key 加密key
 @return 数据库对象
 */
+ (instancetype)databaseWithPath:(nullable NSString *)path flags:(int)flags encrypt:(nullable NSString *)key;

//MARK: - open and close
/**
 打开数据库

 @return 是否成功打开
 @note 已加入懒加载机制,可不手动调用
 */
- (BOOL)open;

/**
 关闭数据库

 @return 是否成功关闭
 */
- (BOOL)close;

/**
 设置一些数据库配置

 @param options 数据库配置,比如
 ```
 @[@"PRAGMA synchronous='NORMAL'",
 @"PRAGMA journal_mode=wal"]
 ```

 @note 未封装`pragma`,请执行原生语句
 */
- (void)setOptions:(NSArray<NSString *> *)options;

// MARK: - Execute

/**
 使用sqlite3_exec()执行原生sql语句

 @param sql 原生sql语句
 @return 是否执行成功
 */
- (BOOL)excute:(NSString *)sql;

// MARK: - Prepare
- (VVDBStatement *)prepare:(NSString *)sql;

- (VVDBStatement *)prepare:(NSString *)sql bind:(nullable NSArray *)values;

// MARK: - Run

/**
 执行原生sql查询语句

 @param sql 原生sql语句
 @return 查询结果
 @attention 会根据sql语句缓存查询结果. 当update/insert/delete/commit时,会清除缓存.
 */
- (NSArray *)query:(NSString *)sql;

/**
 数据表是否存在

 @param table 表名
 @return 是否存在
 */
- (BOOL)isExist:(NSString *)table;

/**
 使用sqlite3_step的方式执行原生sql语句

 @param sql 原生sql语句
 @return 是否执行成功
 */
- (BOOL)run:(NSString *)sql;

- (BOOL)run:(NSString *)sql bind:(nullable NSArray *)values;

// MARK: - Scalar
- (id)scalar:(NSString *)sql bind:(nullable NSArray *)values;

// MARK: - Transactions

/**
 开始事务

 @param mode 事务类型
 @return 事务是否开始成功
 */
- (BOOL)begin:(VVDBTransaction)mode;

/**
 提交事务

 @return 是否提交成功
 */
- (BOOL)commit;

/**
 回滚事务

 @return 是否回滚成功
 */
- (BOOL)rollback;

/**
 保存点机制, 用于回滚部分事务.比如:

 1.设置保存点 savepoint a
 2.取消保存点a之后事务 rollback to a
 3.取消全部事务 rollback

 commit将会删除所有保存点

 @param name 保存点名称
 @param block 使用保存点机制进行的操作
 @return 是否操作成功
 */
- (BOOL)savepoint:(NSString *)name block:(BOOL (^)(void))block;

/**
 事务操作

 @param mode 事务模式
 @param block 具体操作
 @return 事务是否执行成功
 */
- (BOOL)transaction:(VVDBTransaction)mode block:(BOOL (^)(void))block;

/**
 手动终止某些操作
 */
- (void)interrupt;

// MARK: - Handlers
/**
 数据库忙的超时时间
 */
@property (nonatomic, assign) NSTimeInterval timeout;

/**
 数据库忙时的回调
 */
@property (nonatomic, copy) VVDBBusyHandler busyHandler;
/**
 跟踪sql语句
 */
@property (nonatomic, copy) VVDBTraceHook traceHook;
/**
 更新操作钩子函数
 */
@property (nonatomic, copy) VVDBUpdateHook updateHook;
/**
 事务提交操作钩子函数
 */
@property (nonatomic, copy) VVDBCommitHook commitHook;
/**
 事务回滚操作钩子函数
 */
@property (nonatomic, copy) VVDBRollbackHook rollbackHook;

// MARK: - Error Handling
/**
 检查sqlite3返回值

 @param resultCode sqlite3返回值
 @param sql 当前执行的sql语句
 @return 该返回值对应的操作是否成功
 */
- (BOOL)check:(int)resultCode sql:(NSString *)sql;

/**
 最后一次错误的z错误码

 @return 错误码
 */
- (int)lastErrorCode;

/**
 最后一次错误的信息

 @return 错误信息
 */
- (NSError *)lastError;

// MARK: - cipher
#ifdef SQLITE_HAS_CODEC
/**
 sqlite3 cipher 版本号
 */
@property (nonatomic, copy) NSString *cipherVersion;

/**
 设置数据库加密Key

 @param key 加密Key
 @param db 数据库名称,默认为`main`,可指定attach的数据库名
 @return 是否设置成功
 */
- (BOOL)key:(NSString *)key db:(nullable NSString *)db;

/**
 修改数据库加密Key

 @param key 加密key
 @param db 数据库名称,默认为`main`,可指定attach的数据库名
 @return 是否修改成功
 */
- (BOOL)rekey:(NSString *)key db:(nullable NSString *)db;

/**
 检查数据库是否加密成功, 通常在打开数据库但未设置加密key时调用

 @return 是否加密成功
 */
- (BOOL)cipherKeyCheck;
#endif

//MARK: - private
/**
 数据库查询缓存
 */
@property (nonatomic, strong, readonly) NSCache *cache;
/**
 sqlite3数据库结构体指针
 */
@property (nonatomic, assign, readonly) sqlite3 *db;
@end

NS_ASSUME_NONNULL_END
