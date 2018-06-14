//
//  VVFMDB.m
//  Pods
//
//  Created by Jinbo Li on 2018/6/6.
//

#import "VVFMDB.h"
#import <objc/runtime.h>
#import "VVSequelizeConst.h"

@interface VVFMDB ()

@property (nonatomic, strong) NSString *dbPath;

@end


@implementation VVFMDB

#pragma mark - Private

- (FMDatabaseQueue *)dbQueue{
    if (!_dbQueue) {
        [_db close];
        _dbQueue = [FMDatabaseQueue databaseQueueWithPath:_dbPath];
        _db = [_dbQueue valueForKey:@"_db"];
        if(_encryptKey && _encryptKey.length > 0){
            [_db setKey:_encryptKey];
        }
    }
    return _dbQueue;
}

#pragma mark - 创建数据库
/**
 创建数据库单例
 
 @return 数据库单例对象
 */
+ (instancetype)defalutDb{
    static VVFMDB *_vvfmdb;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _vvfmdb = [[self alloc] initWithDBName:nil];
    });
    return _vvfmdb;
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
    VVLog(@"打开或创建数据库: %@", dbPath);
    FMDatabase *fmdb = [FMDatabase databaseWithPath:dbPath];
    if ([fmdb open]) {
        if(encryptKey && encryptKey.length > 0){
            [fmdb setKey:encryptKey];
        }
        self = [self init];
        if (self) {
            self.db = fmdb;
            self.dbPath = dbPath;
            return self;
        }
    }
    NSAssert1(NO, @"创建/打开数据库(%@)失败!",dbPath);
    return nil;
}

#pragma mark - 原始SQL语句
- (NSArray *)vv_executeQuery:(NSString *)sql{
    FMResultSet *set = [self.db executeQuery:sql];
    NSMutableArray *array = [NSMutableArray arrayWithCapacity:0];
    while ([set next]) {
        [array addObject:set.resultDictionary];
    }
    return array;
}

- (BOOL)vv_executeUpdate:(NSString *)sql{
    return [self.db executeUpdate:sql];
}


#pragma mark - 线程安全操作
- (void)vv_inDatabase:(void (^)(void))block{
    [[self dbQueue] inDatabase:^(FMDatabase *db) {
        block();
    }];
}

- (void)vv_inTransaction:(void(^)(BOOL *rollback))block{
    [[self dbQueue] inTransaction:^(FMDatabase *db, BOOL *rollback) {
        block(rollback);
    }];
}

#pragma mark - 其他操作
- (void)close{
    [_db close];
}

- (void)open{
    [_db open];
    if(self.encryptKey && self.encryptKey.length > 0){
        [_db setKey:self.encryptKey];
    }
}

@end
