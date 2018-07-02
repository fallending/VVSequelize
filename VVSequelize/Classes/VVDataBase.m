//
//  VVDataBase.m
//  VVSequelize
//
//  Created by Jinbo Li on 2018/6/6.
//

#import "VVDataBase.h"
#import "VVSequelize.h"

#if __has_include(<VVSequelize/VVSequelize.h>)
#import <fmdb/FMDB.h>
#else
#import "FMDB.h"
#endif

@interface VVDataBase ()
@property (nonatomic, strong) FMDatabase *fmdb;
@property (nonatomic, strong) FMDatabaseQueue *fmdbQueue;
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
    VVLog(1,@"Open or create the database: %@", dbPath);
    FMDatabase *fmdb = [FMDatabase databaseWithPath:dbPath];
    if ([fmdb open]) {
        if(encryptKey.length > 0){
            [fmdb setKey:encryptKey];
        }
        self = [self init];
        if (self) {
            _fmdb = fmdb;
            _dbPath = dbPath;
            _encryptKey = encryptKey;
            return self;
        }
    }
    NSAssert1(NO, @"Open or create the database (%@) failure!",dbPath);
    return nil;
}

//MARK: - 原始SQL语句
- (NSArray *)executeQuery:(NSString *)sql{
    VVLog(1,@"query: %@",sql);
    FMResultSet *set = [self.fmdb executeQuery:sql];
    NSMutableArray *array = [NSMutableArray arrayWithCapacity:0];
    while ([set next]) {
        [array addObject:set.resultDictionary];
    }
    VVLog(2, @"query result: %@",array);
    return array;
}

- (BOOL)executeUpdate:(NSString *)sql{
    VVLog(1,@"execute: %@",sql);
    BOOL ret = [self.fmdb executeUpdate:sql];
    VVLog(2, @"execute result: %@",@(ret));
    return ret;
}


//MARK: - 线程安全操作
- (void)inQueue:(void (^)(void))block{
    if(!block) return;
    [self.fmdbQueue inDatabase:^(FMDatabase * _Nonnull db) {
        block();
    }];
}

- (void)inTransaction:(void(^)(BOOL *rollback))block{
    if(!block) return;
    [self.fmdbQueue inTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
        block(rollback);
    }];
}

//MARK: - 其他操作
- (BOOL)close{
    return [self.fmdb close];
}

- (BOOL)open{
    BOOL ret = [self.fmdb open];
    if(ret && self.encryptKey.length > 0){
        [self.fmdb setKey:self.encryptKey];
    }
    return ret;
}

//MARK: - Private
- (FMDatabaseQueue *)fmdbQueue{
    if(_fmdbQueue){
        // 数据库可能被手动关闭
        void *sqlite3db = (__bridge void *)([_fmdb valueForKey:@"_db"]);
        if(!sqlite3db) _fmdbQueue = nil;
    }
    if(!_fmdbQueue){
        [_fmdb close];
        _fmdbQueue = [FMDatabaseQueue databaseQueueWithPath:_dbPath];
        _fmdb = [_fmdbQueue valueForKey:@"_db"];
        if(_encryptKey.length > 0){
            [_fmdb setKey:_encryptKey];
        }
    }
    return _fmdbQueue;
}
@end
