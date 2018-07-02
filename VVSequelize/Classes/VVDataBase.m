//
//  VVDataBase.m
//  VVSequelize
//
//  Created by Jinbo Li on 2018/6/6.
//

#import "VVDataBase.h"
#import "VVSequelize.h"

@implementation VVDataBase

#pragma mark - 创建数据库
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
    BOOL ret = [VVSequelize.bridge db_initWithPath:dbPath];
    if (ret && [VVSequelize.bridge db_open]) {
        if(encryptKey && encryptKey.length > 0){
            if([VVSequelize.bridge respondsToSelector:@selector(db_setEncryptKey:)]){
                [VVSequelize.bridge db_setEncryptKey:self.encryptKey];
            }
        }
        self = [self init];
        if (self) {
            self.dbPath = dbPath;
            return self;
        }
    }
    NSAssert1(NO, @"Open or create the database (%@) failure!",dbPath);
    return nil;
}

#pragma mark - 原始SQL语句
- (NSArray *)vv_executeQuery:(NSString *)sql{
    VVLog(1,@"query: %@",sql);
    NSArray *array = VVSequelize.bridge ? @[] : [VVSequelize.bridge db_executeQuery:sql];
    VVLog(2, @"query result: %@",array);
    return array;
}

- (BOOL)vv_executeUpdate:(NSString *)sql{
    VVLog(1,@"execute: %@",sql);
    BOOL ret = [VVSequelize.bridge db_executeUpdate:sql];
    VVLog(2, @"execute result: %@",@(ret));
    return ret;
}


#pragma mark - 线程安全操作
- (void)vv_inDatabase:(void (^)(void))block{
    if([VVSequelize.bridge respondsToSelector:@selector(db_inSecureQueue:)]){
        [VVSequelize.bridge db_inSecureQueue:^(void) {
            block();
        }];
    }
}

- (void)vv_inTransaction:(void(^)(BOOL *rollback))block{
    if([VVSequelize.bridge respondsToSelector:@selector(db_inTransaction:)]){
        [VVSequelize.bridge db_inTransaction:^(BOOL *rollback) {
            block(rollback);
        }];
    }
}

#pragma mark - 其他操作
- (BOOL)close{
    return [VVSequelize.bridge db_close];
}

- (BOOL)open{
    BOOL ret = [VVSequelize.bridge db_open];
    if(ret && self.encryptKey.length > 0){
        if([VVSequelize.bridge respondsToSelector:@selector(db_setEncryptKey:)]){
            [VVSequelize.bridge db_setEncryptKey:self.encryptKey];
        }
    }
    return ret;
}

@end
