//
//  VVDatabase+Additions.m
//  VVSequelize
//
//  Created by Valo on 2019/3/27.
//

#import "VVDatabase+Additions.h"

static const char *const VVDBSerialKey = "com.valo.database.serial";
static const char *const VVDBConcurrentKey = "com.valo.database.concurrent";

@implementation VVDatabase (Additions)
// MARK: - pool
+ (instancetype)databaseInPoolWithPath:(nullable NSString *)path
{
    return [self databaseInPoolWithPath:path flags:0 encrypt:nil];
}

+ (instancetype)databaseInPoolWithPath:(nullable NSString *)path
                                 flags:(int)flags
{
    return [self databaseInPoolWithPath:path flags:flags encrypt:nil];
}

+ (instancetype)databaseInPoolWithPath:(nullable NSString *)path
                                 flags:(int)flags
                               encrypt:(nullable NSString *)key
{
    static NSMapTable *_pool;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _pool = [NSMapTable strongToWeakObjectsMapTable];
    });
    NSString *udid = [self udidWithPath:path flags:flags encryptKey:key];
    VVDatabase *db = [_pool objectForKey:udid];
    if (!db) {
        db = [self databaseWithPath:path flags:flags encrypt:key];
        [_pool setObject:db forKey:udid];
    }
    return db;
}

+ (NSString *)udidWithPath:(NSString *)path flags:(int)flags encryptKey:(NSString *)key
{
    NSString *aPath = path ? : VVDBPathTemporary;
    int aFlags = flags | VVDBEssentialFlags;
    NSString *aKey = key ? : @"";
    return [NSString stringWithFormat:@"%@|%@|%@", aPath, @(aFlags), aKey];
}

// MARK: - queue
+ (dispatch_queue_t)serialQueue
{
    static dispatch_queue_t _serialQueue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _serialQueue = dispatch_queue_create(VVDBSerialKey, DISPATCH_QUEUE_SERIAL);
        dispatch_queue_set_specific(_serialQueue, VVDBSerialKey, (void *)VVDBSerialKey, NULL);
    });
    return _serialQueue;
}

+ (dispatch_queue_t)concurrentQueue
{
    static dispatch_queue_t _concurrentQueue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _concurrentQueue = dispatch_queue_create(VVDBConcurrentKey, DISPATCH_QUEUE_CONCURRENT);
        dispatch_queue_set_specific(_concurrentQueue, VVDBConcurrentKey, (void *)VVDBConcurrentKey, NULL);
    });
    return _concurrentQueue;
}

+ (void)sync:(void (^)(void))block
{
    if (dispatch_get_specific(VVDBSerialKey)) {
        block();
    } else {
        dispatch_sync([self serialQueue], block);
    }
}

+ (void)serialAsync:(void (^)(void))block
{
    dispatch_async([self serialQueue], block);
}

+ (void)concurrentAsync:(void (^)(void))block
{
    dispatch_async([self concurrentQueue], block);
}

@end
