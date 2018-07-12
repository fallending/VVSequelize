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
@property (nonatomic, copy  ) NSString *userDefaultsKey;
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
    NSString *homePath = NSHomeDirectory();
    NSRange range = [dbPath rangeOfString:homePath];
    NSString *relativePath = range.location == NSNotFound ?
        dbPath : [dbPath substringFromIndex:range.location + range.length];
    VVLog(1,@"Open or create the database: %@", dbPath);
    FMDatabaseQueue *fmdbQueue = [FMDatabaseQueue databaseQueueWithPath:dbPath];
    if (fmdbQueue) {
        self = [self init];
        if (self) {
            _fmdbQueue = fmdbQueue;
            _fmdb = [fmdbQueue valueForKey:@"_db"];
            _dbPath = dbPath;
            _userDefaultsKey = [NSString stringWithFormat:@"VVDBEncryptKey%@",relativePath];
            self.encryptKey = encryptKey;
            return self;
        }
    }
    NSAssert1(NO, @"Open or create the database (%@) failure!",dbPath);
    return nil;
}

//MARK: - 原始SQL语句
- (NSArray *)executeQuery:(NSString *)sql{
    return [self executeQuery:sql blobFields:nil];
}

- (NSArray *)executeQuery:(NSString *)sql
               blobFields:(nullable NSArray<NSString *> *)blobFields{
    VVLog(1,@"query: %@",sql);
    FMResultSet *set = [self.fmdb executeQuery:sql];
    NSMutableArray *array = [NSMutableArray arrayWithCapacity:0];
    while ([set next]) {
        NSMutableDictionary *dic = set.resultDictionary.mutableCopy;
        for (NSString *field in blobFields) {
            dic[field] = [set dataForColumn:field];
        }
        [array addObject:dic];
    }
    VVLog(2, @"query result: %@",[self descriptionsOfDictionryArray:array]);
    return array;
}

- (BOOL)executeUpdate:(NSString *)sql{
    VVLog(1,@"execute: %@",sql);
    BOOL ret = [self.fmdb executeUpdate:sql];
    VVLog(2, @"execute result: %@",@(ret));
    return ret;
}

- (BOOL)executeUpdate:(NSString *)sql
               values:(nonnull NSArray *)values{
    VVLog(1,@"execute: %@\nvalues: %@",sql,[self descriptionsOfArray:values]);
    BOOL ret = [self.fmdb executeUpdate:sql withArgumentsInArray:values];
    VVLog(2, @"execute result: %@",@(ret));
    return ret;
}

//MARK: - 线程安全操作
- (id)inQueue:(id (^)(void))block{
    __block id ret = nil;
    [self.fmdbQueue inDatabase:^(FMDatabase *db) {
        ret = block();
    }];
    return ret;
}

- (id)inTransaction:(id (^)(BOOL * rollback))block{
    __block id ret = nil;
    [self.fmdbQueue inTransaction:^(FMDatabase * db, BOOL * rollback) {
        ret = block(rollback);
    }];
    return ret;
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

//MARK: - Getter/Setter
- (void)setEncryptKey:(NSString *)encryptKey{
    static dispatch_semaphore_t lock;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        lock = dispatch_semaphore_create(1);
    });
    NSString *origin = [[NSUserDefaults standardUserDefaults] stringForKey:_userDefaultsKey];
    [self close];
    dispatch_semaphore_wait(lock, DISPATCH_TIME_FOREVER);
    BOOL ret = [VVCipherHelper changeKeyForDatabase:_dbPath originKey:origin newKey:encryptKey];
    dispatch_semaphore_signal(lock);
    if(ret){
        if(encryptKey == nil){
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:_userDefaultsKey];
        }
        else{
            [[NSUserDefaults standardUserDefaults] setObject:encryptKey forKey:_userDefaultsKey];
        }
        [[NSUserDefaults standardUserDefaults] synchronize];
        _encryptKey = encryptKey;
    }
    [self open];
}

//MARK: - Private
- (NSArray *)descriptionsOfArray:(NSArray *)array{
    if(VVSequelize.loglevel < 1) return nil;
    NSMutableArray *descriptions = [NSMutableArray arrayWithCapacity:0];
    for (id val in array) {
        NSString *description = nil;
        if([val isKindOfClass:NSData.class]){
            NSData *data = val;
            description =[NSString stringWithFormat:@"Data<%@ bytes>",@(data.length)];
        }
        else{
            description = [val description];
        }
        if(description.length > 100) description = [description substringToIndex:100];
        [descriptions addObject:description];
    }
    return descriptions;
}

- (NSArray *)descriptionsOfDictionryArray:(NSArray<NSDictionary *> *)array{
    if(VVSequelize.loglevel < 2) return nil;
    NSMutableArray *descriptions = [NSMutableArray arrayWithCapacity:0];
    for (NSDictionary *dic in array) {
        NSMutableDictionary *descDic = [NSMutableDictionary dictionaryWithCapacity:0];
        for (NSString *key in dic.allKeys) {
            id val = dic[key];
            NSString *description = nil;
            if([val isKindOfClass:NSData.class]){
                NSData *data = val;
                description =[NSString stringWithFormat:@"Data<%@ bytes>",@(data.length)];
            }
            else{
                description = [val description];
            }
            if(description.length > 100) description = [description substringToIndex:100];
            descDic[key] = description;
        }
        [descriptions addObject:descDic];
    }
    return descriptions;
}


@end
