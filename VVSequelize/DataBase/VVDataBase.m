//
//  VVDataBase.m
//  VVSequelize
//
//  Created by Jinbo Li on 2018/6/6.
//

#import "VVDataBase.h"
#import "VVSequelize.h"
#import "VVCipherHelper.h"

@interface VVDataBase ()
@property (nonatomic, strong) id<VVSQLiteDB> sqlitedb;
@property (nonatomic, copy  ) NSString *encryptStoreKey; ///< 保存密码的Key
@end

@implementation VVDataBase

//MARK: - 创建数据库
/**
 创建数据库单例
 
 @return 数据库单例对象
 */
+ (instancetype)defalutDb{
    static VVDataBase *_vvdb;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _vvdb = [[self alloc] initWithDBName:nil];
    });
    return _vvdb;
}

- (instancetype)initWithDBName:(NSString *)dbName{
    return [self initWithDBName:dbName dirPath:nil encryptKey:nil];
}

- (instancetype)initWithDBName:(NSString *)dbName
                      dirPath:(NSString *)dirPath
                   encryptKey:(NSString *)encryptKey{
    NSAssert(VVSequelize.dbClass, @"请先设置全局的sqlite3封装类: `VVSequelize.dbClass`");
    if (dbName.length == 0) {
        dbName = @"vvsequlize.sqlite";
    }
    NSString *path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
    if(dirPath && dirPath.length > 0){
        BOOL isDir = NO;
        BOOL exist = [[NSFileManager defaultManager] fileExistsAtPath:dirPath isDirectory:&isDir];
        BOOL valid = exist && isDir;
        if(!valid){
            valid = [[NSFileManager defaultManager] createDirectoryAtPath:dirPath withIntermediateDirectories:YES attributes:nil error:nil];
        }
        if(valid){
            path = dirPath;
        }
    }
    NSString *dbPath =  [path stringByAppendingPathComponent:dbName];
    NSString *homePath = NSHomeDirectory();
    NSRange range = [dbPath rangeOfString:homePath];
    NSString *relativePath = range.location == NSNotFound ?
        dbPath : [dbPath substringFromIndex:range.location + range.length];
#if DEBUG
    NSLog(@"Open or create the database: %@", dbPath);
#endif
    id<VVSQLiteDB> sqlitedb = [VVSequelize.dbClass dbWithPath:dbPath];
    if (sqlitedb) {
        self = [self init];
        if (self) {
            _sqlitedb = sqlitedb;
            _dbName = dbName;
            _dbDir  = dirPath;
            _dbPath = dbPath;
            _encryptStoreKey = [NSString stringWithFormat:@"VVDBEncryptStoreKey%@",relativePath];
            self.encryptKey = encryptKey;
            // 执行一些设置
            [self executeQuery:@"PRAGMA synchronous='NORMAL'"];
            [self executeQuery:@"PRAGMA journal_mode=wal"];
            return self;
        }
    }
    NSAssert1(sqlitedb, @"Open or create the database (%@) failure!",dbPath);
    return nil;
}

//MARK: - 原始SQL语句
- (NSArray *)executeQuery:(NSString *)sql{
    NSError *error = nil;
    NSArray *array = [self.sqlitedb executeQuery:sql error:&error];
    if(VVSequelize.trace) VVSequelize.trace(sql, nil, array, error);
    return array;
}

- (BOOL)executeUpdate:(NSString *)sql{
    NSError *error = nil;
    BOOL ret = [self.sqlitedb executeUpdate:sql error:&error];
    if(VVSequelize.trace) VVSequelize.trace(sql, nil, @(ret), error);
    return ret;
}

- (BOOL)executeUpdate:(NSString *)sql
               values:(nonnull NSArray *)values{
    NSError *error = nil;
    BOOL ret = [self.sqlitedb executeUpdate:sql values:values error:&error];
    if(VVSequelize.trace) VVSequelize.trace(sql, values, @(ret), error);
    return ret;
}

- (BOOL)isTableExist:(NSString *)tableName{
    NSString *sql = [NSString stringWithFormat:@"SELECT count(*) as 'count' FROM sqlite_master WHERE type ='table' and tbl_name = \"%@\"",tableName];
    NSArray *array = [self executeQuery:sql];
    for (NSDictionary *dic in array) {
        NSInteger count = [dic[@"count"] integerValue];
        return count > 0;
    }
    return NO;
}

//MARK: 事务操作
- (BOOL)beginTransaction {
    return [self executeUpdate:@"begin exclusive transaction"];
}

- (BOOL)beginDeferredTransaction {
    return [self executeUpdate:@"begin deferred transaction"];
}

- (BOOL)rollback {
    return [self executeUpdate:@"rollback transaction"];
}

- (BOOL)commit {
    return [self executeUpdate:@"commit transaction"];
}

//MARK: - 其他操作
- (BOOL)close{
    return [self.sqlitedb close];
}

- (BOOL)open{
    BOOL ret = [self.sqlitedb open];
    BOOL cipherSupported = VVSequelize.cipherSupported && [self.sqlitedb respondsToSelector:@selector(setEncryptKey:)];
    if(ret && cipherSupported){
        [self.sqlitedb setEncryptKey:self.encryptKey];
    }
    return ret;
}

- (void)setEncryptKey:(NSString *)encryptKey{
    BOOL cipherSupported = VVSequelize.cipherSupported && [self.sqlitedb respondsToSelector:@selector(setEncryptKey:)];
    if(!cipherSupported) return;
    
    static dispatch_semaphore_t lock;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        lock = dispatch_semaphore_create(1);
    });
    BOOL ret = YES;
    BOOL isOpen = self.sqlitedb.isOpen;
    if(isOpen){
        ret = [self close];
    }
    NSAssert1(ret, @"[encrypt] close the database (%@) failure!",_dbPath);
    NSString *origin = [[NSUserDefaults standardUserDefaults] stringForKey:_encryptStoreKey];
    dispatch_semaphore_wait(lock, DISPATCH_TIME_FOREVER);
    ret = [VVCipherHelper changeKeyForDatabase:self.dbPath originKey:origin newKey:encryptKey];
    dispatch_semaphore_signal(lock);
    if(ret){
        if(encryptKey == nil){
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:_encryptStoreKey];
        }
        else{
            [[NSUserDefaults standardUserDefaults] setObject:encryptKey forKey:_encryptStoreKey];
        }
        [[NSUserDefaults standardUserDefaults] synchronize];
        _encryptKey = encryptKey;
    }
    NSAssert1(ret, @"[encrypt] set encrypt key for database (%@) failure!",_dbPath);
    if(isOpen){
        ret = [self open];
        NSAssert1(ret, @"[encrypt] reopen the database (%@) failure!",_dbPath);
    }
}

@end
