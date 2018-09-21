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
@property (nonatomic, assign) BOOL isMemoryDb;           ///< 是否是内存数据库
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
        _vvdb = [[VVDataBase alloc] initWithPath:nil];
    });
    return _vvdb;
}

- (instancetype)initWithPath:(NSString *)path{
    return [self initWithPath:path encryptKey:nil];
}

- (instancetype)initWithPath:(NSString *)path
                  encryptKey:(NSString *)encryptKey{
    NSAssert(VVSequelize.dbClass, @"请先设置全局的sqlite3封装类: `VVSequelize.dbClass`");
    NSString *fullpath = nil;
    NSString *dir = nil;
    NSString *name = nil;
    if (path.length == 0) {
        path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
        name = @"vvsequlize.sqlite";
        fullpath = [path stringByAppendingPathComponent:name];
    }
    else{
        fullpath = path;
        name = path.lastPathComponent;
        dir  = [path stringByDeletingLastPathComponent];
    }
    BOOL isdir = NO;
    BOOL exist = [[NSFileManager defaultManager] fileExistsAtPath:dir isDirectory:&isdir];
    if(!(exist && isdir)){
        [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    }
    NSString *homePath = NSHomeDirectory();
    NSRange range = [fullpath rangeOfString:homePath];
    NSString *relativePath = range.location == NSNotFound ?
        fullpath : [fullpath substringFromIndex:range.location + range.length];
#if DEBUG
    NSLog(@"Open or create the database: %@", fullpath);
#endif
    id<VVSQLiteDB> sqlitedb = [VVSequelize.dbClass dbWithPath:fullpath];
    if (sqlitedb) {
        self = [self init];
        if (self) {
            _sqlitedb = sqlitedb;
            _name = name;
            _dir  = dir;
            _path = fullpath;
            _encryptStoreKey = [NSString stringWithFormat:@"VVDBEncryptStoreKey%@",relativePath];
            self.encryptKey = encryptKey;
            // 执行一些设置
            [self executeQuery:@"PRAGMA synchronous='NORMAL'"];
            [self executeQuery:@"PRAGMA journal_mode=wal"];
            return self;
        }
    }
    NSAssert1(sqlitedb, @"Open or create the database (%@) failure!",fullpath);
    return nil;
}

- (instancetype)initMemoryDb{
    BOOL supported = [VVSequelize.dbClass respondsToSelector:@selector(createMemoryDb)];
    if(!supported){ return nil; }
    id<VVSQLiteDB> sqlitedb = [VVSequelize.dbClass createMemoryDb];
    if(sqlitedb){
        self = [self init];
        if (self) {
            _sqlitedb   = sqlitedb;
            _isMemoryDb = YES;
        }
        return self;
    }
    NSAssert(sqlitedb, @"create sqlite in memory failure!");
    return nil;
}

- (void)dealloc{
    [self.sqlitedb close];
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
    BOOL cipherSupported = !self.isMemoryDb && VVSequelize.cipherSupported && [self.sqlitedb respondsToSelector:@selector(setEncryptKey:)];
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
    NSAssert1(ret, @"[encrypt] close the database (%@) failure!",_path);
    NSString *origin = [[NSUserDefaults standardUserDefaults] stringForKey:_encryptStoreKey];
    dispatch_semaphore_wait(lock, DISPATCH_TIME_FOREVER);
    ret = [VVCipherHelper changeKeyForDatabase:self.path originKey:origin newKey:encryptKey];
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
    NSAssert1(ret, @"[encrypt] set encrypt key for database (%@) failure!",_path);
    if(isOpen){
        ret = [self open];
        NSAssert1(ret, @"[encrypt] reopen the database (%@) failure!",_path);
    }
}

@end
